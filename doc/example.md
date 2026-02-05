# Complete Working Example: Three-Mod System

This example demonstrates the complete flow with three mods that interact via lib-settings.

## Directory Structure

```
factorio/mods/
├── lib-settings/
│   ├── info.json
│   └── lib.lua
│
├── power-generator/
│   ├── info.json
│   ├── settings.lua
│   ├── settings-updates.lua
│   └── settings-final-fixes.lua
│
├── balance-overhaul/
│   ├── info.json
│   └── settings-updates.lua
│
└── compatibility-patch/
    ├── info.json
    └── settings-updates.lua
```

---

## Mod 1: power-generator (Exposes Settings)

### power-generator/info.json
```json
{
  "name": "power-generator",
  "version": "1.0.0",
  "title": "Power Generator Mod",
  "author": "ExampleAuthor",
  "factorio_version": "1.1",
  "dependencies": [
    "base >= 1.1",
    "? lib-settings >= 1.0.0"
  ]
}
```

### power-generator/settings.lua
```lua
-- ============================================================================
-- STAGE 1: Define settings normally (just like any Factorio mod)
-- ============================================================================

data:extend({
  -- Power multiplier setting
  {
    type = "double-setting",
    name = "power-generator-multiplier",
    setting_type = "startup",
    default_value = 1.0,
    minimum_value = 0.1,
    maximum_value = 10.0,
    order = "a"
  },
  
  -- Enable/disable solar nerf
  {
    type = "bool-setting",
    name = "power-generator-nerf-solar",
    setting_type = "startup",
    default_value = false,
    order = "b"
  },
  
  -- Difficulty mode
  {
    type = "string-setting",
    name = "power-generator-mode",
    setting_type = "startup",
    default_value = "normal",
    allowed_values = {"easy", "normal", "hard", "extreme"},
    order = "c"
  }
})

-- At this point:
-- - All three settings exist in data.raw
-- - They have their default values
-- - Users can see them in the mod settings GUI
```

### power-generator/settings-updates.lua
```lua
-- ============================================================================
-- STAGE 2: Expose settings to other mods (opt-in)
-- ============================================================================

if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Expose power multiplier with validation
  LIB.exposeSetting("multiplier", {
    type = "double-setting",  -- Optional: will auto-detect
    min_value = 0.1,
    max_value = 10.0
  })
  
  -- Expose solar nerf setting
  LIB.exposeSetting("nerf-solar")
  
  -- Expose mode setting with auto-hide when modified
  LIB.exposeSetting("mode", {
    allowed_values = {"easy", "normal", "hard", "extreme"},
    auto_hide_modified = true  -- Hide from user if another mod changes it
  })
  
  log("[power-generator] Settings exposed via lib-settings")
end

-- At this point:
-- - Registry contains metadata about these three settings
-- - Other mods can now request modifications
-- - Settings are still at their default values
```

### power-generator/settings-final-fixes.lua
```lua
-- ============================================================================
-- STAGE 3: Apply modifications from other mods
-- ============================================================================

if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- This single line does everything:
  -- 1. Fetches all modification requests for our settings
  -- 2. Sorts them by priority
  -- 3. Validates each value
  -- 4. Applies them to data.raw
  -- 5. Auto-hides settings if configured
  LIB.updateAllMySettings()
  
  log("[power-generator] Settings finalized")
end

-- At this point:
-- - All modifications have been applied
-- - Settings have their final values
-- - Game will use these values when creating prototypes
```

---

## Mod 2: balance-overhaul (Modifies Settings)

### balance-overhaul/info.json
```json
{
  "name": "balance-overhaul",
  "version": "1.0.0",
  "title": "Balance Overhaul Pack",
  "author": "BalanceExpert",
  "factorio_version": "1.1",
  "dependencies": [
    "base >= 1.1",
    "? lib-settings >= 1.0.0",
    "? power-generator"
  ]
}
```

### balance-overhaul/settings-updates.lua
```lua
-- ============================================================================
-- STAGE 2: Request modifications to other mods' settings
-- ============================================================================

if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Only modify if power-generator is present
  if mods["power-generator"] then
    log("[balance-overhaul] Adjusting power-generator settings for balance")
    
    -- Reduce power generation by 25%
    LIB.set_setting("power-generator", "multiplier", 0.75, {
      priority = 50  -- Normal priority
    })
    
    -- Enable solar nerf for balance
    LIB.set_setting("power-generator", "nerf-solar", true, {
      priority = 50
    })
    
    -- Set difficulty to hard
    LIB.set_setting("power-generator", "mode", "hard", {
      priority = 50
    })
    
    log("[balance-overhaul] Modifications requested with priority 50")
  end
end

-- At this point:
-- - Modification requests are queued
-- - Nothing has been applied yet
-- - power-generator still has default values
```

**Note:** This mod doesn't need `settings-final-fixes.lua` because it doesn't own any exposed settings.

---

## Mod 3: compatibility-patch (Higher Priority Modifications)

### compatibility-patch/info.json
```json
{
  "name": "compatibility-patch",
  "version": "1.0.0",
  "title": "Compatibility Patch",
  "author": "FixItGuy",
  "factorio_version": "1.1",
  "dependencies": [
    "base >= 1.1",
    "? lib-settings >= 1.0.0",
    "? power-generator",
    "? balance-overhaul"
  ]
}
```

### compatibility-patch/settings-updates.lua
```lua
-- ============================================================================
-- STAGE 2: Fix compatibility issues with higher priority
-- ============================================================================

if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Detect if both power-generator and balance-overhaul are present
  if mods["power-generator"] and mods["balance-overhaul"] then
    log("[compatibility-patch] Detected power-generator + balance-overhaul")
    log("[compatibility-patch] Applying compatibility fix")
    
    -- Fix: balance-overhaul is too aggressive, use 0.85 instead of 0.75
    LIB.set_setting("power-generator", "multiplier", 0.85, {
      priority = 10  -- HIGH priority (lower number = higher priority)
    })
    
    -- Keep balance-overhaul's other changes
    -- (we don't override nerf-solar or mode)
    
    log("[compatibility-patch] Multiplier adjusted to 0.85 for compatibility")
  end
end

-- At this point:
-- - Another modification request is queued
-- - This one has priority 10 (higher than balance-overhaul's 50)
-- - Still nothing applied yet
```

---

## Complete Execution Trace

### STAGE 1: settings.lua (All mods execute)

```
[power-generator] settings.lua executes
  → Creates "power-generator-multiplier" (default: 1.0)
  → Creates "power-generator-nerf-solar" (default: false)
  → Creates "power-generator-mode" (default: "normal")

[balance-overhaul] settings.lua (doesn't exist, skipped)

[compatibility-patch] settings.lua (doesn't exist, skipped)
```

**State after Stage 1:**
```lua
data.raw["double-setting"]["power-generator-multiplier"] = {
  name = "power-generator-multiplier",
  default_value = 1.0,
  minimum_value = 0.1,
  maximum_value = 10.0
}
data.raw["bool-setting"]["power-generator-nerf-solar"] = {
  name = "power-generator-nerf-solar",
  default_value = false
}
data.raw["string-setting"]["power-generator-mode"] = {
  name = "power-generator-mode",
  default_value = "normal",
  allowed_values = {"easy", "normal", "hard", "extreme"}
}
```

---

### STAGE 2: settings-updates.lua (All mods execute)

```
[power-generator] settings-updates.lua executes
  → Exposes "multiplier" (min: 0.1, max: 10.0)
  → Exposes "nerf-solar"
  → Exposes "mode" (auto_hide_modified: true)
  → Registry now contains 3 settings

[balance-overhaul] settings-updates.lua executes
  → Requests: multiplier = 0.75 (priority 50)
  → Requests: nerf-solar = true (priority 50)
  → Requests: mode = "hard" (priority 50)
  → 3 modification requests queued

[compatibility-patch] settings-updates.lua executes
  → Requests: multiplier = 0.85 (priority 10)
  → 1 more modification request queued
```

**State after Stage 2:**
```lua
data.raw["lib-settings-registry"] = {
  ["power-generator-multiplier"] = {
    owner_mod = "power-generator",
    type = "double-setting",
    min_value = 0.1,
    max_value = 10.0,
    auto_hide_modified = false
  },
  ["power-generator-nerf-solar"] = {
    owner_mod = "power-generator",
    type = "bool-setting",
    auto_hide_modified = false
  },
  ["power-generator-mode"] = {
    owner_mod = "power-generator",
    type = "string-setting",
    allowed_values = {"easy", "normal", "hard", "extreme"},
    auto_hide_modified = true  -- IMPORTANT: Will auto-hide
  }
}

data.raw["lib-settings-modifications"] = {
  ["power-generator-multiplier"] = {
    {requesting_mod = "balance-overhaul", value = 0.75, priority = 50},
    {requesting_mod = "compatibility-patch", value = 0.85, priority = 10}
  },
  ["power-generator-nerf-solar"] = {
    {requesting_mod = "balance-overhaul", value = true, priority = 50}
  },
  ["power-generator-mode"] = {
    {requesting_mod = "balance-overhaul", value = "hard", priority = 50}
  }
}

-- Settings still have default values!
-- Nothing applied yet!
```

---

### STAGE 3: settings-final-fixes.lua (All mods execute)

```
[power-generator] settings-final-fixes.lua executes
  → Calls updateAllMySettings()
  → Processing "multiplier":
      • Found 2 modifications
      • Sort by priority: [10, 50] → [compat-patch(10), balance(50)]
      • Apply in REVERSE order (highest priority wins):
        - Apply balance(50): 0.75
        - Apply compat-patch(10): 0.85  ← FINAL VALUE
      • Validation: 0.85 within [0.1, 10.0] ✓
      • APPLIED: multiplier = 0.85
  → Processing "nerf-solar":
      • Found 1 modification
      • Apply balance(50): true
      • Validation: boolean ✓
      • APPLIED: nerf-solar = true
  → Processing "mode":
      • Found 1 modification
      • Apply balance(50): "hard"
      • Validation: "hard" in allowed_values ✓
      • APPLIED: mode = "hard"
      • auto_hide_modified = true → SET HIDDEN = TRUE

[balance-overhaul] settings-final-fixes.lua (doesn't exist, skipped)

[compatibility-patch] settings-final-fixes.lua (doesn't exist, skipped)
```

**Final State after Stage 3:**
```lua
data.raw["double-setting"]["power-generator-multiplier"] = {
  name = "power-generator-multiplier",
  default_value = 0.85,  -- Changed by compatibility-patch (priority 10)
  minimum_value = 0.1,
  maximum_value = 10.0
}

data.raw["bool-setting"]["power-generator-nerf-solar"] = {
  name = "power-generator-nerf-solar",
  default_value = true  -- Changed by balance-overhaul
}

data.raw["string-setting"]["power-generator-mode"] = {
  name = "power-generator-mode",
  default_value = "hard",  -- Changed by balance-overhaul
  allowed_values = {"easy", "normal", "hard", "extreme"},
  hidden = true  -- AUTO-HIDDEN because it was modified!
}
```

---

## Log Output

```
[power-generator] Settings exposed via lib-settings
[balance-overhaul] Adjusting power-generator settings for balance
[balance-overhaul] Modifications requested with priority 50
[compatibility-patch] Detected power-generator + balance-overhaul
[compatibility-patch] Applying compatibility fix
[compatibility-patch] Multiplier adjusted to 0.85 for compatibility
[lib-settings] ✓ Applied: power-generator-multiplier.default_value = 0.85 (by compatibility-patch)
[lib-settings] ✓ Applied: power-generator-nerf-solar.default_value = true (by balance-overhaul)
[lib-settings] ✓ Applied: power-generator-mode.default_value = hard (by balance-overhaul)
[lib-settings] Auto-hidden: power-generator-mode (was modified)
[power-generator] Settings finalized
```

---

## What the User Sees

In the Mod Settings GUI, the user will see:

**Power Generator Mod:**
- ✅ Power Multiplier: `0.85` (editable, shows modified value)
- ✅ Nerf Solar: `true` (editable, shows modified value)
- ❌ Mode: **(HIDDEN - not shown to user)**

The "Mode" setting is hidden because:
1. It was modified by balance-overhaul
2. It had `auto_hide_modified = true`
3. Settings-Share automatically hid it to avoid user confusion

---

## Key Takeaways

1. **Stage 1**: Normal setting definitions (no changes to existing workflow)
2. **Stage 2**: Expose and/or request modifications
3. **Stage 3**: Owning mods apply all modifications

4. **Priority System**: Lower number = higher priority (10 beats 50)
5. **Auto-Hide**: Optional feature to hide modified settings
6. **Validation**: Automatic checks prevent invalid values
7. **Logging**: Everything is logged for debugging

This example shows the complete real-world usage of lib-settings!