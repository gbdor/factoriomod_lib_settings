# Usage Examples

### Example 1: Balance Overhaul Mod

A balance mod that adjusts multiple other mods:

```lua
-- balance-overhaul/info.json
{
  "dependencies": [
    "? settings-share >= 1.0.0",
    "? bobs-mods",
    "? angels-mods",
    "? space-exploration"
  ]
}

-- balance-overhaul/settings-updates.lua
if mods["settings-share"] then
  local LIB = require("__settings-share__/lib")
  
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
if mods["settings-share"] then
  local LIB = require("__settings-share__/lib")
  
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
if mods["settings-share"] then
  local LIB = require("__settings-share__/lib")
  
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
if mods["settings-share"] then
  local LIB = require("__settings-share__/lib")
  
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
if mods["settings-share"] then
  local LIB = require("__settings-share__/lib")
  LIB.updateAllMySettings()
end
```

## Understanding the Settings Stage

Factorio processes settings in three sequential stages:

1. **`settings.lua`**: Define your settings here
2. **`settings-updates.lua`**: Expose settings and request modifications here
3. **`settings-final-fixes.lua`**: Apply modifications here

Settings Share uses this staged approach to ensure:
- All settings are defined before exposure
- All exposure happens before modifications are requested
- All modifications are validated and applied in a deterministic order