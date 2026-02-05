# Settings-Share: Technical Architecture & Data Flow

## Overview

Settings-Share is a library mod that enables safe cross-mod settings access in Factorio by leveraging the three-stage settings loading system.

## Three-Stage Settings System

Factorio loads settings in three sequential stages. **ALL mods** go through each stage before moving to the next:

```
┌────────────────────────────────────────────────────────────────┐
│                    SETTINGS STAGE EXECUTION                    │
└────────────────────────────────────────────────────────────────┘

Stage 1: settings.lua
┌─────────────────────────────────────────────────────────────────┐
│  FOR EACH MOD (in dependency order):                           │
│    • Execute settings.lua                                      │
│    • Settings are defined and added to data.raw                │
│  END                                                            │
│                                                                 │
│  Result: All setting PROTOTYPES exist in data.raw              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                              ↓
Stage 2: settings-updates.lua
┌─────────────────────────────────────────────────────────────────┐
│  FOR EACH MOD (same order as Stage 1):                         │
│    • Execute settings-updates.lua                              │
│    • Can modify data.raw from any mod                          │
│    • Settings-Share: Registration & modification requests      │
│  END                                                            │
│                                                                 │
│  Result: Registry built, modifications queued                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                              ↓
Stage 3: settings-final-fixes.lua
┌─────────────────────────────────────────────────────────────────┐
│  FOR EACH MOD (same order as Stage 1 & 2):                     │
│    • Execute settings-final-fixes.lua                          │
│    • Last chance to modify data.raw                            │
│    • Settings-Share: Apply validated modifications             │
│  END                                                            │
│                                                                 │
│  Result: All settings finalized                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                              ↓
                    Settings prototypes locked
                    Player settings loaded from disk
                    Continue to data stage
```

## Critical Understanding

### Shared Lua State
All three stages share **ONE global Lua state**. This means:
- `data.raw` is accessible and persistent across all three stages
- Custom tables in `data.raw` persist between stages
- All mods can see each other's modifications

### Execution Order
Mods are loaded in **dependency order**, with tiebreaking by alphabetical name:
1. Dependencies are loaded first
2. Mods with shorter dependency chains load before longer chains
3. When dependency depth is equal, alphabetical order is used

Example:
```
base (depth 0)
  ↓
mod-a (depth 1, depends on base)
mod-b (depth 1, depends on base)  ← alphabetically after mod-a
  ↓
mod-c (depth 2, depends on mod-a and mod-b)
```

Load order: `base → mod-a → mod-b → mod-c`

## Settings-Share Data Flow

### Data Structures

```lua
-- Storage in data.raw (persists across all stages)

data.raw["lib-settings-registry"] = {
  ["mod-name-setting-name"] = {
    owner_mod = "mod-name",
    type = "bool-setting",
    read_only = false,
    min_value = nil,
    max_value = nil,
    allowed_values = nil,
    validator = function(value) ... end,
    auto_hide_modified = false,
    original_hidden = false,
    last_modified_by = nil,
    version = 1
  },
  -- ... more settings
}

data.raw["lib-settings-modifications"] = {
  ["mod-name-setting-name"] = {
    {
      requesting_mod = "other-mod",
      property = "default_value",
      value = true,
      priority = 100
    },
    {
      requesting_mod = "another-mod",
      property = "default_value",
      value = false,
      priority = 50
    }
    -- ... more modification requests
  },
  -- ... more settings
}
```

### Detailed Execution Flow

Let's trace a complete example with 3 mods:

**Mods:**
- `power-gen` - Generates power, has settings
- `balance-mod` - Balance pack that modifies other mods
- `compat-fix` - Compatibility fixes

---

#### STAGE 1: settings.lua

```
┌──────────────────────────────────────────────────────┐
│ TIME: Stage 1, Mod 1 (power-gen)                     │
├──────────────────────────────────────────────────────┤
│ File: power-gen/settings.lua                         │
│                                                       │
│ data:extend({                                        │
│   {                                                   │
│     type = "double-setting",                         │
│     name = "power-gen-multiplier",                   │
│     default_value = 1.0,                             │
│     minimum_value = 0.1,                             │
│     maximum_value = 10.0                             │
│   }                                                   │
│ })                                                    │
│                                                       │
│ STATE AFTER:                                         │
│ data.raw["double-setting"]["power-gen-multiplier"] = │
│   { name = ..., default_value = 1.0, ... }          │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│ TIME: Stage 1, Mod 2 (balance-mod)                   │
├──────────────────────────────────────────────────────┤
│ File: balance-mod/settings.lua (if exists)           │
│                                                       │
│ -- balance-mod might define its own settings here   │
│                                                       │
│ STATE: Unchanged for power-gen-multiplier            │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│ TIME: Stage 1, Mod 3 (compat-fix)                    │
├──────────────────────────────────────────────────────┤
│ File: compat-fix/settings.lua (if exists)            │
│                                                       │
│ -- compat-fix might define its own settings here    │
│                                                       │
│ STATE: Unchanged for power-gen-multiplier            │
└──────────────────────────────────────────────────────┘

END OF STAGE 1:
  data.raw["double-setting"]["power-gen-multiplier"] = 
    { name = "power-gen-multiplier", default_value = 1.0, ... }
```

---

#### STAGE 2: settings-updates.lua

```
┌──────────────────────────────────────────────────────┐
│ TIME: Stage 2, Mod 1 (power-gen)                     │
├──────────────────────────────────────────────────────┤
│ File: power-gen/settings-updates.lua                 │
│                                                       │
│ local LIB = require("__lib-settings__/lib")       │
│                                                       │
│ LIB.exposeSetting("multiplier", {                   │
│   min_value = 0.1,                                   │
│   max_value = 10.0                                   │
│ })                                                    │
│                                                       │
│ INTERNAL EXECUTION:                                  │
│ 1. detect_mod_name() → "power-gen"                  │
│ 2. full_name = "power-gen-multiplier"               │
│ 3. Auto-detect type = "double-setting"              │
│ 4. Validate setting exists in data.raw ✓            │
│ 5. Store in registry:                                │
│                                                       │
│ STATE AFTER:                                         │
│ data.raw["lib-settings-registry"] = {             │
│   ["power-gen-multiplier"] = {                      │
│     owner_mod = "power-gen",                         │
│     type = "double-setting",                         │
│     min_value = 0.1,                                 │
│     max_value = 10.0,                                │
│     ...                                              │
│   }                                                   │
│ }                                                     │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│ TIME: Stage 2, Mod 2 (balance-mod)                   │
├──────────────────────────────────────────────────────┤
│ File: balance-mod/settings-updates.lua               │
│                                                       │
│ local LIB = require("__lib-settings__/lib")       │
│                                                       │
│ LIB.set_setting("power-gen", "multiplier", 0.75, {  │
│   priority = 50                                      │
│ })                                                    │
│                                                       │
│ INTERNAL EXECUTION:                                  │
│ 1. detect_mod_name() → "balance-mod"                │
│ 2. full_name = "power-gen-multiplier"               │
│ 3. Check registry - setting is exposed ✓            │
│ 4. Check not read_only ✓                            │
│ 5. Store modification request:                       │
│                                                       │
│ STATE AFTER:                                         │
│ data.raw["lib-settings-modifications"] = {        │
│   ["power-gen-multiplier"] = {                      │
│     {                                                │
│       requesting_mod = "balance-mod",                │
│       property = "default_value",                    │
│       value = 0.75,                                  │
│       priority = 50                                  │
│     }                                                │
│   }                                                   │
│ }                                                     │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│ TIME: Stage 2, Mod 3 (compat-fix)                    │
├──────────────────────────────────────────────────────┤
│ File: compat-fix/settings-updates.lua                │
│                                                       │
│ local LIB = require("__lib-settings__/lib")       │
│                                                       │
│ if mods["power-gen"] and mods["balance-mod"] then   │
│   LIB.set_setting("power-gen", "multiplier", 0.85, {│
│     priority = 10  -- Higher priority!               │
│   })                                                  │
│ end                                                   │
│                                                       │
│ INTERNAL EXECUTION:                                  │
│ 1. detect_mod_name() → "compat-fix"                 │
│ 2. Store another modification request                │
│                                                       │
│ STATE AFTER:                                         │
│ data.raw["lib-settings-modifications"] = {        │
│   ["power-gen-multiplier"] = {                      │
│     {                                                │
│       requesting_mod = "balance-mod",                │
│       value = 0.75,                                  │
│       priority = 50                                  │
│     },                                               │
│     {                                                │
│       requesting_mod = "compat-fix",                 │
│       value = 0.85,                                  │
│       priority = 10  ← Lower number = higher prio   │
│     }                                                │
│   }                                                   │
│ }                                                     │
└──────────────────────────────────────────────────────┘

END OF STAGE 2:
  Registry contains: 1 exposed setting (power-gen-multiplier)
  Modifications contains: 2 requests for power-gen-multiplier
```

---

#### STAGE 3: settings-final-fixes.lua

```
┌──────────────────────────────────────────────────────┐
│ TIME: Stage 3, Mod 1 (power-gen)                     │
├──────────────────────────────────────────────────────┤
│ File: power-gen/settings-final-fixes.lua             │
│                                                       │
│ local LIB = require("__lib-settings__/lib")       │
│ LIB.updateAllMySettings()                           │
│                                                       │
│ INTERNAL EXECUTION:                                  │
│ 1. detect_mod_name() → "power-gen"                  │
│ 2. Find all settings owned by "power-gen"           │
│ 3. For "power-gen-multiplier":                      │
│    a. Get modifications list: [                      │
│         {balance-mod, 0.75, priority 50},           │
│         {compat-fix, 0.85, priority 10}             │
│       ]                                              │
│    b. Sort by priority (lower = higher):            │
│       [                                              │
│         {compat-fix, 0.85, priority 10},  ← First   │
│         {balance-mod, 0.75, priority 50}            │
│       ]                                              │
│    c. Apply each in order:                          │
│       - Validate 0.85: min=0.1 ✓, max=10.0 ✓       │
│       - Apply: default_value = 0.85                  │
│       - Validate 0.75: min=0.1 ✓, max=10.0 ✓       │
│       - Apply: default_value = 0.75                  │
│    d. Last write wins: 0.75                         │
│    e. WAIT! Priority 10 < 50, so iteration order:   │
│       Loop processes in sorted order, so:           │
│       - First applies 0.85 (compat-fix, prio 10)   │
│       - Then applies 0.75 (balance-mod, prio 50)   │
│       - Final value = 0.75? NO!                     │
│                                                       │
│ CORRECTION - Algorithm:                              │
│ Sorted list is processed, but LAST item wins        │
│ After sort: [compat-fix(10), balance-mod(50)]      │
│ Items are applied in order, last one stays:         │
│   - Apply compat-fix: value = 0.85                  │
│   - Apply balance-mod: value = 0.75                 │
│   - Final: 0.75                                     │
│                                                       │
│ WAIT - Let me check the code again...               │
│ The code applies in sorted order, so lower priority │
│ (higher number) comes LAST and overwrites!          │
│                                                       │
│ ACTUAL BEHAVIOR (from code):                        │
│ Sort: priority 10 before priority 50                │
│ Apply: first 10 (0.85), then 50 (0.75)             │
│ Result: 0.75 (balance-mod wins? No!)                │
│                                                       │
│ Let me re-read: "lower number = higher priority"    │
│ So priority 10 SHOULD win over priority 50          │
│ But if we apply in sorted order (10, then 50),      │
│ the last one (50) would overwrite!                  │
│                                                       │
│ FIX: Sort should be REVERSE for last-wins           │
│ OR: Pick the FIRST item after sort (highest prio)   │
│                                                       │
│ CORRECTED BEHAVIOR:                                  │
│ After sort: [{compat-fix, prio 10}, {balance, 50}] │
│ We want priority 10 to WIN (it's higher priority)   │
│ So we apply ALL, and the FIRST one should be final  │
│ OR apply in REVERSE order                           │
│ OR just take the first item                         │
│                                                       │
│ IMPLEMENTATION IN CODE:                             │
│ The code loops through sorted list and applies all  │
│ This means LAST one wins!                           │
│ So with sort [10, 50], item 50 would win           │
│ This is WRONG!                                      │
│                                                       │
│ CORRECT IMPLEMENTATION:                             │
│ Should reverse after sort, OR only apply first      │
│                                                       │
│ For this document, assume CORRECT behavior:         │
│ Priority 10 (compat-fix) WINS                       │
│ Final value: 0.85                                   │
│                                                       │
│ STATE AFTER:                                         │
│ data.raw["double-setting"]["power-gen-multiplier"]  │
│   .default_value = 0.85                             │
│                                                       │
│ Registry updated:                                    │
│   last_modified_by = "compat-fix"                   │
│   version = 2                                        │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│ TIME: Stage 3, Mod 2 (balance-mod)                   │
├──────────────────────────────────────────────────────┤
│ File: balance-mod/settings-final-fixes.lua           │
│       (if exists)                                    │
│                                                       │
│ -- balance-mod doesn't own any exposed settings     │
│ -- Nothing to do here                               │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│ TIME: Stage 3, Mod 3 (compat-fix)                    │
├──────────────────────────────────────────────────────┤
│ File: compat-fix/settings-final-fixes.lua            │
│       (if exists)                                    │
│                                                       │
│ -- compat-fix doesn't own any exposed settings      │
│ -- Nothing to do here                               │
└──────────────────────────────────────────────────────┘

END OF STAGE 3:
  Final value: power-gen-multiplier.default_value = 0.85
  Modified by: compat-fix (priority 10 won over priority 50)
```

## Important Implementation Note

**BUG FOUND IN CURRENT CODE**: The sorting puts lower priority numbers first, but then applies them in order, meaning the LAST one (highest priority number) would win. This is backwards!

**FIX NEEDED**: Either:
1. Reverse the sort (higher priority numbers first)
2. Apply in reverse order after sorting
3. Only apply the first item after sorting

The documentation assumes CORRECT behavior where priority 10 beats priority 50.

## Validation Flow

```
┌─────────────────────────────────────────────────────────┐
│                   VALIDATION PIPELINE                   │
└─────────────────────────────────────────────────────────┘

When applying a modification:

Input: (setting_name, property, value)
   ↓
Check 1: Is property a value property?
   ├─ YES (default_value, forced_value) → Continue
   └─ NO (hidden, order, etc.) → Skip validation ✓
   ↓
Check 2: Type validation
   ├─ bool-setting: Is it a boolean?
   ├─ int-setting: Is it an integer?
   ├─ double-setting: Is it a number?
   └─ string-setting: Is it a string?
   ↓
Check 3: allowed_values constraint
   └─ If defined: Is value in the list?
   ↓
Check 4: min_value constraint
   └─ If defined: Is value >= min_value?
   ↓
Check 5: max_value constraint
   └─ If defined: Is value <= max_value?
   ↓
Check 6: Custom validator function
   └─ If defined: validator(value) → bool, error_msg
   ↓
ALL CHECKS PASSED ✓
   ↓
Apply modification to data.raw
```

## Auto-Hide Feature

When `auto_hide_modified = true`:

```
Setting defined in settings.lua
   ↓
Setting exposed with auto_hide_modified = true
   ↓
Store: original_hidden = current hidden state
   ↓
Another mod modifies the setting
   ↓
In settings-final-fixes, updateAllMySettings() detects:
   • Modification was applied
   • auto_hide_modified = true
   ↓
Automatically set: setting.hidden = true
   ↓
User no longer sees this setting in GUI
```

This is useful for:
- Balance packs that force certain values
- Compatibility fixes that override settings
- Avoiding user confusion when mods manage settings automatically

## Thread Safety & Determinism

### Why This is Safe

1. **Single-threaded**: Lua is single-threaded, no race conditions
2. **Sequential execution**: Mods execute in strict order
3. **Deterministic**: Same mods = same load order = same result
4. **Alphabetical tiebreak**: When priorities are equal, mod names sort alphabetically

### Guarantees

- ✅ Same mods + same priorities = always same result
- ✅ No hidden dependencies - everything explicit
- ✅ Auditable - all modifications logged
- ✅ Safe in multiplayer - runs before game starts

## Performance Characteristics

### Time Complexity
- Registry lookup: O(1) - hash table
- Modification storage: O(1) - append to list
- Modification sorting: O(n log n) where n = number of mods modifying a setting
- Validation: O(1) - constant checks

### Space Complexity
- Registry: O(s) where s = number of exposed settings
- Modifications: O(s × m) where m = average mods per setting
- Typically: s = 10-100, m = 1-5, total = 50-500 entries

### When It Runs
- Only during game startup / mod load
- Zero runtime cost during gameplay
- Settings are already resolved before the game loop starts

## Security Model

### Protection Layers

1. **Explicit Opt-In**: Only registered settings accessible
2. **Read-Only Flag**: Prevents unwanted modifications
3. **Value Validation**: Bounds checking, allowed values
4. **Type Safety**: Enforces correct types
5. **Audit Trail**: All modifications logged

### What's NOT Protected

- Mods can still directly access `data.raw` and bypass the library
- This is intentional - Factorio modding is cooperative, not adversarial
- The library provides safe defaults, not mandatory security

## Future Considerations

### Potential Enhancements

1. **Dependency declarations**: Mods declare which settings they'll modify
2. **Versioning**: Track setting API versions for compatibility
3. **Callbacks**: Notify owning mod when settings are modified
4. **Rollback**: Undo modifications if validation fails later
5. **Runtime settings**: Extend to runtime-global and runtime-per-user

### Limitations

- Cannot modify settings during data stage (settings are locked)
- Cannot modify settings during runtime (would require different approach)
- No built-in UI for managing priorities
- No automatic conflict resolution beyond priority system