# SETTINGS-SHARE: Complete Usage Examples

## Understanding the Three-Stage Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 1: settings.lua (ALL mods, in dependency order)          │
├─────────────────────────────────────────────────────────────────┤
│ • Mod A: defines settings normally                             │
│ • Mod B: defines settings normally                             │
│ • Mod C: defines settings normally                             │
│ • ... all mods define their settings                           │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 2: settings-updates.lua (ALL mods, same order)           │
├─────────────────────────────────────────────────────────────────┤
│ • Mod A: exposes settings via exposeSetting()                  │
│ • Mod B: exposes settings via exposeSetting()                  │
│ • Mod C: modifies Mod A & B via set_setting()                  │
│ • ... mods expose and/or modify settings                       │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 3: settings-final-fixes.lua (ALL mods, same order)       │
├─────────────────────────────────────────────────────────────────┤
│ • Mod A: applies modifications via updateAllMySettings()       │
│ • Mod B: applies modifications via updateAllMySettings()       │
│ • Mod C: nothing (doesn't own settings)                        │
│ • ... owning mods apply all modifications                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Example 1: Basic Mod Exposing Settings

### File Structure
```
awesome-mod/
├── info.json
├── settings.lua
├── settings-updates.lua
└── settings-final-fixes.lua
```

### info.json
```json
{
  "name": "awesome-mod",
  "version": "1.0.0",
  "title": "Awesome Mod",
  "author": "You",
  "dependencies": [
    "base >= 1.1",
    "? lib-settings >= 1.0.0"
  ]
}
```

### settings.lua (STAGE 1: Define settings normally)
```lua
data:extend({
  {
    type = "bool-setting",
    name = "awesome-mod-enable-feature",
    setting_type = "startup",
    default_value = true,
    order = "a"
  },
  {
    type = "double-setting",
    name = "awesome-mod-power-multiplier",
    setting_type = "startup",
    default_value = 1.0,
    minimum_value = 0.1,
    maximum_value = 10.0,
    order = "b"
  },
  {
    type = "string-setting",
    name = "awesome-mod-difficulty",
    setting_type = "startup",
    default_value = "normal",
    allowed_values = {"easy", "normal", "hard"},
    order = "c"
  }
})
```

### settings-updates.lua (STAGE 2: Expose settings)
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Expose the feature toggle
  LIB.exposeSetting("enable-feature")
  
  -- Expose power multiplier with validation
  LIB.exposeSetting("power-multiplier", {
    min_value = 0.1,
    max_value = 10.0
  })
  
  -- Expose difficulty with auto-hide when modified
  LIB.exposeSetting("difficulty", {
    allowed_values = {"easy", "normal", "hard"},
    auto_hide_modified = true  -- Hide from user if another mod changes it
  })
end
```

### settings-final-fixes.lua (STAGE 3: Apply modifications)
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- One line does everything!
  LIB.updateAllMySettings()
end
```

---

## Example 2: Mod That Modifies Other Mods

### File Structure
```
balance-tweaker/
├── info.json
├── settings.lua (optional - if this mod has its own settings)
└── settings-updates.lua (for modifying other mods)
```

### info.json
```json
{
  "name": "balance-tweaker",
  "version": "1.0.0",
  "title": "Balance Tweaker",
  "author": "You",
  "dependencies": [
    "base >= 1.1",
    "? lib-settings >= 1.0.0",
    "? awesome-mod",
    "? another-mod"
  ]
}
```

### settings-updates.lua (STAGE 2: Modify other mods)
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Modify awesome-mod if present
  if mods["awesome-mod"] then
    LIB.set_setting("awesome-mod", "enable-feature", false)
    LIB.set_setting("awesome-mod", "power-multiplier", 2.5)
    LIB.set_setting("awesome-mod", "difficulty", "hard")
  end
  
  -- Modify another-mod if present
  if mods["another-mod"] then
    LIB.set_setting("another-mod", "resource-spawning", 0.5, {
      priority = 50  -- Higher priority (lower number)
    })
  end
end
```

**Note:** This mod doesn't need `settings-final-fixes.lua` because it doesn't own any exposed settings.

---

## Example 3: Complete Workflow with Multiple Mods

Let's trace through what happens with 3 mods:
- **power-mod**: Defines power-related settings
- **balance-pack**: Modifies multiple mods for balance
- **compatibility-fix**: Fixes specific conflicts

### Power Mod

#### power-mod/settings.lua (STAGE 1)
```lua
data:extend({
  {
    type = "double-setting",
    name = "power-mod-generation-multiplier",
    setting_type = "startup",
    default_value = 1.0,
    minimum_value = 0.1,
    maximum_value = 5.0
  },
  {
    type = "bool-setting",
    name = "power-mod-enable-solar-nerf",
    setting_type = "startup",
    default_value = false
  }
})
```

#### power-mod/settings-updates.lua (STAGE 2)
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  LIB.exposeSetting("generation-multiplier", {
    min_value = 0.1,
    max_value = 5.0
  })
  
  LIB.exposeSetting("enable-solar-nerf")
end
```

#### power-mod/settings-final-fixes.lua (STAGE 3)
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  LIB.updateAllMySettings()
end
```

### Balance Pack

#### balance-pack/settings-updates.lua (STAGE 2)
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Apply balance changes to power-mod
  if mods["power-mod"] then
    LIB.set_setting("power-mod", "generation-multiplier", 0.75, {
      priority = 10  -- High priority
    })
    LIB.set_setting("power-mod", "enable-solar-nerf", true)
  end
  
  -- Apply changes to other mods...
end
```

### Compatibility Fix

#### compatibility-fix/settings-updates.lua (STAGE 2)
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Fix: When both power-mod and balance-pack are active,
  -- we need a specific multiplier value
  if mods["power-mod"] and mods["balance-pack"] then
    LIB.set_setting("power-mod", "generation-multiplier", 0.85, {
      priority = 5  -- Even higher priority than balance-pack
    })
    
    log("[compatibility-fix] Adjusted power-mod multiplier for compatibility")
  end
end
```

### Execution Timeline

```
TIME 0: STAGE 1 - settings.lua runs for ALL mods
├─ power-mod/settings.lua executes
│  └─ Creates "power-mod-generation-multiplier" (default: 1.0)
│  └─ Creates "power-mod-enable-solar-nerf" (default: false)
├─ balance-pack/settings.lua executes (if it has one)
└─ compatibility-fix/settings.lua executes (if it has one)

TIME 1: STAGE 2 - settings-updates.lua runs for ALL mods
├─ power-mod/settings-updates.lua executes
│  └─ Exposes "generation-multiplier" and "enable-solar-nerf"
│  └─ Registry now contains these settings
│
├─ balance-pack/settings-updates.lua executes
│  └─ Requests: generation-multiplier = 0.75 (priority 10)
│  └─ Requests: enable-solar-nerf = true (priority 100)
│  └─ Modifications stored in queue
│
└─ compatibility-fix/settings-updates.lua executes
   └─ Requests: generation-multiplier = 0.85 (priority 5)
   └─ Modifications stored in queue

TIME 2: STAGE 3 - settings-final-fixes.lua runs for ALL mods
├─ power-mod/settings-final-fixes.lua executes
│  └─ Calls updateAllMySettings()
│  └─ Processes modifications:
│      • For "generation-multiplier":
│        - balance-pack requested 0.75 (priority 10)
│        - compatibility-fix requested 0.85 (priority 5)
│        - Priority 5 < 10, so compatibility-fix WINS
│        - Final value: 0.85
│      • For "enable-solar-nerf":
│        - balance-pack requested true (priority 100)
│        - No other requests
│        - Final value: true
│
├─ balance-pack/settings-final-fixes.lua (if exists)
│  └─ Does nothing (doesn't own settings)
│
└─ compatibility-fix/settings-final-fixes.lua (if exists)
   └─ Does nothing (doesn't own settings)

RESULT:
• power-mod-generation-multiplier = 0.85 (set by compatibility-fix)
• power-mod-enable-solar-nerf = true (set by balance-pack)
```

---

## Example 4: Advanced - Auto-Hide Modified Settings

Sometimes when a balance pack or compatibility mod changes a setting, you want to hide it from the user to avoid confusion.

### advanced-mod/settings-updates.lua
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- This setting will automatically be hidden if any mod modifies it
  LIB.exposeSetting("balance-value", {
    min_value = 0.1,
    max_value = 10.0,
    auto_hide_modified = true  -- KEY FEATURE
  })
  
  -- This setting will remain visible even if modified
  LIB.exposeSetting("user-preference", {
    auto_hide_modified = false  -- Default behavior
  })
end
```

### What happens:
```
1. User sees both settings in the menu initially
2. balance-pack modifies "balance-value"
3. In settings-final-fixes, updateAllMySettings() detects the modification
4. "balance-value" is automatically hidden from the settings GUI
5. "user-preference" remains visible even if modified
```

---

## Example 5: Fine-Grained Control with Iterator

If you need more control than `updateAllMySettings()` provides:

### custom-mod/settings-final-fixes.lua
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Use the iterator for fine-grained control
  for setting_name, modifications in LIB.get_my_exposed_settings() do
    -- modifications is an array of all valid modification requests
    -- They're already sorted by priority
    
    if setting_name == "custom-mod-special-setting" then
      -- Custom logic for this specific setting
      local best_mod = modifications[#modifications] -- Last one (highest priority)
      
      log("Setting " .. setting_name .. " will be changed by " .. best_mod.modified_by)
      
      -- Apply with custom logic
      local setting = data.raw["bool-setting"][setting_name]
      setting[best_mod.property] = best_mod.value
      
      -- Custom behavior: Add a warning in the description
      setting.localised_description = {"", 
        setting.localised_description or "",
        "\n[color=yellow]Modified by " .. best_mod.modified_by .. "[/color]"
      }
    else
      -- For other settings, just apply normally
      for _, mod in ipairs(modifications) do
        local setting = data.raw["bool-setting"][setting_name]
        setting[mod.property] = mod.value
      end
    end
  end
end
```

---

## Example 6: Read-Only Settings (Information Sharing)

Some settings should be readable by other mods but not modifiable:

### version-mod/settings.lua
```lua
data:extend({
  {
    type = "string-setting",
    name = "version-mod-api-version",
    setting_type = "startup",
    default_value = "2.1.0",
    hidden = true  -- Hide from users
  }
})
```

### version-mod/settings-updates.lua
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Expose as read-only so other mods can check compatibility
  LIB.exposeSetting("api-version", {
    read_only = true  -- Prevents modifications
  })
end
```

### other-mod/settings-updates.lua
```lua
if mods["lib-settings"] and mods["version-mod"] then
  -- Can READ the setting from data.raw
  local api_version = data.raw["string-setting"]["version-mod-api-version"]
  if api_version then
    log("version-mod API version: " .. api_version.default_value)
  end
  
  -- But CANNOT modify it - this would error:
  -- LIB.set_setting("version-mod", "api-version", "3.0.0")
  -- Error: "Setting is read-only: version-mod-api-version"
end
```

---

## Example 7: Priority-Based Conflict Resolution

```lua
-- Mod A wants value = 10 (priority 100, default)
LIB.set_setting("target", "value", 10)

-- Mod B wants value = 20 (priority 50, higher priority)
LIB.set_setting("target", "value", 20, {priority = 50})

-- Mod C wants value = 30 (priority 50, same as B)
LIB.set_setting("target", "value", 30, {priority = 50})

-- Result: Mod C wins (priority 50, and "mod-c" > "mod-b" alphabetically)
-- Final value: 30
```

### Priority Guidelines
- **0-10**: Critical compatibility fixes (use sparingly)
- **10-50**: High-priority balance packs
- **50-100**: Normal balance adjustments
- **100+**: Low-priority tweaks (default is 100)

---

## Example 8: Custom Validation

### physics-mod/settings-updates.lua
```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  LIB.exposeSetting("jump-height", {
    min_value = 0.1,
    max_value = 10.0,
    validator = function(value)
      -- Custom validation: Must be a multiple of 0.5
      if value % 0.5 ~= 0 then
        return false, "Jump height must be a multiple of 0.5"
      end
      
      -- Warn about extreme values
      if value > 5.0 then
        log("[physics-mod] WARNING: Extreme jump height: " .. value)
      end
      
      return true
    end
  })
end
```

---

## Debugging Tips

### Enable Detailed Logging

Add this to your `settings-final-fixes.lua`:

```lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Print statistics before applying
  LIB.print_statistics()
  
  -- Apply modifications
  LIB.updateAllMySettings()
  
  -- Check what was actually applied
  local registry = LIB.get_all_exposed_settings()
  local mods = LIB.get_all_modifications()
  
  for name, meta in pairs(registry) do
    if meta.last_modified_by then
      log("Setting " .. name .. " was modified by " .. meta.last_modified_by)
    end
  end
end
```

### Check factorio-current.log

Look for lines like:
```
[lib-settings] Exposed: awesome-mod-power-multiplier (type: double-setting)
[lib-settings] Modification requested: awesome-mod-power-multiplier.default_value = 2.5 (by balance-tweaker, priority 100)
[lib-settings] ✓ Applied: awesome-mod-power-multiplier.default_value = 2.5 (by balance-tweaker)
```

---

## Common Patterns

### Pattern 1: Compatibility Pack
```lua
-- Detects incompatible mods and adjusts settings
if mods["mod-a"] and mods["mod-b"] then
  -- These mods conflict, disable mod-a feature
  LIB.set_setting("mod-a", "conflicting-feature", false, {
    priority = 1  -- Very high priority
  })
end
```

### Pattern 2: Preset System
```lua
-- User chooses a preset in your mod's settings
local preset = settings.startup["my-mod-preset"].value

if preset == "easy" then
  LIB.set_setting("combat-mod", "enemy-strength", 0.5)
  LIB.set_setting("resource-mod", "abundance", 2.0)
elseif preset == "hard" then
  LIB.set_setting("combat-mod", "enemy-strength", 2.0)
  LIB.set_setting("resource-mod", "abundance", 0.5)
end
```

### Pattern 3: Feature Dependency
```lua
-- Automatically adjust related mods
LIB.set_setting("energy-mod", "consumption-multiplier", 1.5)
LIB.set_setting("production-mod", "speed-multiplier", 0.75)
-- Keep game balanced
```




## Usage Examples

### Example 1: Balance Overhaul Mod

A balance mod that adjusts multiple other mods:

```lua
-- balance-overhaul/info.json
{
  "dependencies": [
    "? lib-settings >= 1.0.0",
    "? bobs-mods",
    "? angels-mods",
    "? space-exploration"
  ]
}

-- balance-overhaul/settings-updates.lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Adjust Bob's Mods if present
  if mods["bobplates"] then
    LIB.set_setting("bobplates", "recipe-difficulty", "hard")
    LIB.set_setting("bobplates", "resource-multiplier", 0.5)
  end
  
  -- Adjust Angel's Mods if present
  if mods["angelssmelting"] then
    LIB.set_setting("angelssmelting", "enable-crushed-stone", true)
  end
  
  -- Adjust Space Exploration if present
  if mods["space-exploration"] then
    LIB.set_setting("space-exploration", "meteor-interval", 1800, {
      priority = 10  -- High priority
    })
  end
end
```

### Example 2: Difficulty Preset Mod

Create preset difficulty configurations:

```lua
-- difficulty-presets/settings.lua
data:extend({
  {
    type = "string-setting",
    name = "difficulty-presets-mode",
    setting_type = "startup",
    default_value = "normal",
    allowed_values = {"easy", "normal", "hard", "deathworld"}
  }
})

-- difficulty-presets/settings-updates.lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  local preset = settings.startup["difficulty-presets-mode"].value
  
  if preset == "easy" then
    -- Make multiple mods easier
    if mods["bobs-mods"] then
      LIB.set_setting("bobplates", "resource-multiplier", 2.0)
    end
    if mods["rampant"] then
      LIB.set_setting("rampant", "enemy-evolution-speed", 0.5)
    end
    
  elseif preset == "deathworld" then
    -- Make everything harder
    if mods["bobs-mods"] then
      LIB.set_setting("bobplates", "resource-multiplier", 0.25)
    end
    if mods["rampant"] then
      LIB.set_setting("rampant", "enemy-evolution-speed", 2.0)
      LIB.set_setting("rampant", "enemy-expansion-enabled", true)
    end
  end
end
```

### Example 3: Compatibility Patch Mod

Fix incompatibilities between mods:

```lua
-- compatibility-fixes/settings-updates.lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Fix: Mod A and Mod B conflict when both enable certain features
  if mods["mod-a"] and mods["mod-b"] then
    -- Disable conflicting feature in Mod A
    LIB.set_setting("mod-a", "conflicting-feature", false, {
      priority = 1  -- Very high priority to ensure this applies
    })
    
    log("[compatibility-fixes] Disabled mod-a-conflicting-feature to prevent conflict with mod-b")
  end
  
  -- Fix: Mod C needs Mod D's settings adjusted for proper balance
  if mods["mod-c"] and mods["mod-d"] then
    LIB.set_setting("mod-d", "production-multiplier", 1.5)
  end
end
```

### Example 4: Comprehensive Mod with Multiple Exposed Settings

```lua
-- super-mod/settings.lua
data:extend({
  {
    type = "bool-setting",
    name = "super-mod-enable-advanced-mode",
    setting_type = "startup",
    default_value = false
  },
  {
    type = "int-setting",
    name = "super-mod-research-speed",
    setting_type = "startup",
    default_value = 100,
    minimum_value = 10,
    maximum_value = 1000
  },
  {
    type = "string-setting",
    name = "super-mod-difficulty",
    setting_type = "startup",
    default_value = "normal",
    allowed_values = {"easy", "normal", "hard"}
  },
  {
    type = "double-setting",
    name = "super-mod-ore-richness",
    setting_type = "startup",
    default_value = 1.0,
    minimum_value = 0.1,
    maximum_value = 10.0
  }
})

-- super-mod/settings-updates.lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Expose all settings with appropriate validation
  LIB.exposeSetting("enable-advanced-mode")
  
  LIB.exposeSetting("research-speed", {
    min_value = 10,
    max_value = 1000
  })
  
  LIB.exposeSetting("difficulty", {
    allowed_values = {"easy", "normal", "hard"}
  })
  
  LIB.exposeSetting("ore-richness", {
    min_value = 0.1,
    max_value = 10.0,
    validator = function(value)
      -- Additional validation: warn if extreme values
      if value < 0.5 or value > 5.0 then
        log("[super-mod] Warning: Extreme ore-richness value: " .. value)
      end
      return true
    end
  })
end

-- super-mod/settings-final-fixes.lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  LIB.updateAllMySettings()
end
```




## Best Practices

### For Mod Authors Exposing Settings

1. **Only expose what's necessary**: Don't expose internal or debug settings
2. **Document exposed settings**: Include in your mod description which settings are shareable
3. **Use validation**: Always specify `min_value`, `max_value`, or `allowed_values`
4. **Consider read-only**: Use `read_only = true` for informational settings
5. **Test thoroughly**: Test with other mods that might modify your settings

### For Mod Authors Modifying Settings

1. **Use optional dependencies**: Always make target mods optional
2. **Check mod presence**: Use `if mods["target-mod"]` before calling `set_setting()`
3. **Use priorities wisely**: Only use high priority (low numbers) when necessary
4. **Document your changes**: Note in your mod description which settings you modify
5. **Respect read-only**: Don't try to force modifications of read-only settings
6. **Provide configuration**: Let users disable your modifications if they want

### For Players

1. **Check mod descriptions**: See which mods use Settings Share
2. **Review logs**: Check `factorio-current.log` for modification details
3. **Report conflicts**: If mods conflict, report to both mod authors
4. **Understand priorities**: Higher-priority mods (balance packs) should load after others

## Compatibility

- **Factorio Version**: 1.1+
- **Save Compatibility**: Settings changes require a new game or restart
- **Multiplayer**: Fully compatible, all players must have the same mods and settings
- **Scenarios**: Compatible with all scenarios

## Performance

Settings Share operates only during the settings stage, which happens:
- When starting a new game
- When loading a save (for startup settings)
- When changing mod settings (for runtime settings)

There is **zero runtime performance impact** during gameplay.
