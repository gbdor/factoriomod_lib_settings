# Exposing your mod's settings

### **Step 1**: Add a dependecy to `lib-settings`:

Add Settings Share as an **optional dependency** in your `info.json`:

```json
{
  "dependencies": [
    "? lib-settings >= 1.0.0"
    ...
  ]
}
```
### **Step 2**: Define your settings normally in `settings.lua`:

```lua
-- your-mod/settings.lua
data:extend({
    {
    type = "bool-setting",
    name = "your-mod-enable-feature",
    setting_type = "startup",
    default_value = true
  },
   {
    type = "double-setting",
    name = "your-mod-power-multiplier",
    setting_type = "startup",
    default_value = 1.0,
    minimum_value = 0.1,
    maximum_value = 10.0
  }
})
```

### **Step 3**: Expose settings in `settings-updates.lua`:

```lua
-- your-mod/settings-updates.lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  LIB.exposeSetting("enable-feature")
  LIB.exposeSetting("power-multiplier", {
    min_value = 0.5,  -- optional, if you want the overhaul to access only part of the allowed range
    max_value = 5.0
  })
end
```

### **Step 4**: Apply modifications in `settings-final-fixes.lua`:

```lua
-- your-mod/settings-final-fixes.lua
if mods["lib-settings"] then
  local LIB = require("__lib-settings__/lib")
  
  -- One line does everything!
  LIB.updateAllMySettings()
end
```

That's it! Your settings are now safely shareable.



## API Reference

### For Owning Mods

#### `LIB.exposeSetting(setting_name, [config])`

Expose a setting for other mods to access and modify.

**Parameters:**
- `setting_name` (string): The name of your setting WITHOUT the mod prefix
  - Example: If your setting is `"your-mod-power-multiplier"`, use `"power-multiplier"`
- `config` (table, optional): Configuration options
  - `type` (string, optional): Setting type, auto-detected if not provided
  - `read_only` (boolean, default: false): Prevent modifications if true
  - `min_value` (number, optional): Minimum allowed value
  - `max_value` (number, optional): Maximum allowed value
  - `allowed_values` (table, optional): List of explicitly allowed values
  - `validator` (function, optional): Custom validation function `(value) -> boolean, error_message`

**Example:**
```lua
-- Simple exposure
LIB.exposeSetting("enable-missiles")

-- With validation constraints
LIB.exposeSetting("difficulty-level", {
  allowed_values = {"easy", "normal", "hard", "extreme"}
})

-- With custom validator
LIB.exposeSetting("grid-size", {
  min_value = 10,
  max_value = 1000,
  validator = function(value)
    if value % 10 ~= 0 then
      return false, "Must be multiple of 10"
    end
    return true
  end
})

-- Read-only (informational only)
LIB.exposeSetting("mod-version", {
  read_only = true
})
```

**When to call:** `settings-updates.lua`

---

#### `LIB.updateAllMySettings()`

Apply all pending modifications to your mod's exposed settings. This is the recommended approach.

**Example:**
```lua
LIB.updateAllMySettings()
```

**When to call:** `settings-final-fixes.lua`

---

#### `LIB.get_my_exposed_settings()`

Returns an iterator over all modifications to your mod's settings. Use this if you need fine-grained control over how modifications are applied.

**Returns:** Iterator of `(setting_name, modification)` pairs where modification contains:
- `property` (string): The property being modified (usually "default_value")
- `value` (any): The new value
- `modified_by` (string): Name of the mod that made the modification

**Example:**
```lua
for setting_name, modification in LIB.get_my_exposed_settings() do
  local setting = data.raw["bool-setting"][setting_name]
  setting[modification.property] = modification.value
  
  log("Setting " .. setting_name .. " was changed by " .. modification.modified_by)
end
```

**When to call:** `settings-final-fixes.lua`

### For Modifying Mods

#### `LIB.set_setting(owner_mod_name, setting_name, value, [options])`

Request to modify another mod's exposed setting.

**Parameters:**
- `owner_mod_name` (string): Name of the mod that owns the setting
- `setting_name` (string): Name of the setting WITHOUT the mod prefix
- `value` (any): New value to set
- `options` (table, optional):
  - `property` (string, default: "default_value"): Which property to modify
    - Common values: `"default_value"`, `"forced_value"`, `"hidden"`, `"order"`
  - `priority` (number, default: 100): Priority for conflict resolution
    - Lower numbers = higher priority (0 = highest)
    - Used when multiple mods try to modify the same setting

**Example:**
```lua
-- Simple modification
LIB.set_setting("awesome-mod", "enable-feature", false)

-- Modify with priority (wins over default priority 100)
LIB.set_setting("awesome-mod", "power-multiplier", 3.0, {
  priority = 50
})

-- Force a value (overrides user choice)
LIB.set_setting("balance-mod", "difficulty", "hard", {
  property = "forced_value"
})

-- Hide a setting from the user
LIB.set_setting("old-mod", "deprecated-option", true, {
  property = "hidden"
})
```

**When to call:** `settings-updates.lua` or `settings-final-fixes.lua`

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

## Understanding the Settings Stage

Factorio processes settings in three sequential stages:

1. **`settings.lua`**: Define your settings here
2. **`settings-updates.lua`**: Expose settings and request modifications here
3. **`settings-final-fixes.lua`**: Apply modifications here

Settings Share uses this staged approach to ensure:
- All settings are defined before exposure
- All exposure happens before modifications are requested
- All modifications are validated and applied in a deterministic order

## Conflict Resolution

When multiple mods try to modify the same setting, Settings Share uses a priority system:

1. **Priority-based**: Lower priority numbers win (0 = highest priority)
2. **Alphabetical tiebreak**: If priorities are equal, mods are sorted alphabetically for deterministic results
3. **Last-write-wins**: The highest priority modification is applied

Example:
```lua
-- Mod A (priority 100, default)
LIB.set_setting("target-mod", "value", 10)

-- Mod B (priority 50, higher priority)
LIB.set_setting("target-mod", "value", 20)

-- Mod C (priority 50, same as B, but comes after alphabetically)
LIB.set_setting("target-mod", "value", 30)

-- Result: Mod C wins (priority 50, and "mod-c" > "mod-b" alphabetically)
```

## Validation and Safety

Settings Share provides multiple layers of safety:

### 1. Explicit Opt-In
Only settings that are explicitly exposed via `exposeSetting()` can be accessed. This prevents:
- Accidental modification of internal settings
- Access to sensitive configuration values
- Unexpected behavior from undocumented settings

### 2. Type Validation
Settings Share validates values against:
- **Minimum values**: Prevents values below `min_value`
- **Maximum values**: Prevents values above `max_value`
- **Allowed values**: Restricts to specific allowed options
- **Custom validators**: Your own validation logic

Invalid modifications are rejected and logged.

### 3. Read-Only Protection
Settings can be marked as `read_only = true` to:
- Share information with other mods
- Prevent any modifications
- Useful for version numbers, capability flags, etc.

### 4. Comprehensive Logging
All modifications are logged with:
- Which mod requested the change
- What value was requested
- Whether it was accepted or rejected
- Why it was rejected (if applicable)

Check your `factorio-current.log` for detailed information.

## Troubleshooting

### "Setting not exposed for sharing"
**Cause**: The target mod hasn't exposed this setting via `exposeSetting()`

**Solutions**:
- Check if the target mod uses Settings Share
- Verify the setting name is correct (without mod prefix)
- Contact the target mod author to request exposure

### "Setting does not exist"
**Cause**: The setting name is incorrect or doesn't exist in `settings.lua`

**Solutions**:
- Check your `settings.lua` for the exact setting name
- Ensure you're using the setting name WITH the mod prefix in `exposeSetting()`
- Ensure you're using the setting name WITHOUT the mod prefix in `set_setting()`

### "Value not in allowed_values"
**Cause**: The value you're trying to set isn't in the allowed list

**Solutions**:
- Check the exposed setting's `allowed_values` constraint
- Use a value from the allowed list
- Contact the owning mod author if you need additional values

### "Setting is read-only"
**Cause**: The setting is marked as read-only and cannot be modified

**Solutions**:
- This is intentional - the owning mod doesn't allow modifications
- Use the setting's value for information only
- Contact the owning mod author if you need write access

### "Could not detect calling mod name"
**Cause**: Settings Share couldn't determine which mod is calling it

**Solutions**:
- Ensure you're calling `require("__lib-settings__/lib")` from a file in your mod
- Don't call the API from inline scripts or data.lua directly
- Call from `settings-updates.lua` or `settings-final-fixes.lua`

### Modifications Not Applied
**Cause**: Multiple possible issues

**Solutions**:
1. Check that you're calling `LIB.updateAllMySettings()` in `settings-final-fixes.lua`
2. Verify your setting is exposed in `settings-updates.lua`
3. Check `factorio-current.log` for rejection messages
4. Ensure Settings Share is installed and enabled
5. Verify the modifying mod has Settings Share as a dependency

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

## FAQ

**Q: Can I modify runtime or per-player settings?**  
A: Currently, Settings Share focuses on startup settings. Runtime setting support may be added in the future.

**Q: What happens if two mods have the same priority?**  
A: Modifications are sorted alphabetically by mod name for deterministic behavior.

**Q: Can I force a value regardless of what the player chooses?**  
A: Yes, use `property = "forced_value"` to override the player's choice.

**Q: Does this work with mod X?**  
A: Settings Share works with any mod that explicitly exposes settings. Check the mod's description or contact the author.

**Q: Can I modify hidden settings?**  
A: Only if the owning mod explicitly exposes them via `exposeSetting()`.

**Q: Is this compatible with mod configuration mods?**  
A: Yes, Settings Share works alongside any mod configuration system.

**Q: Can I see what mods modified what settings?**  
A: Yes, check your `factorio-current.log` file for detailed modification logs.

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request with tests

