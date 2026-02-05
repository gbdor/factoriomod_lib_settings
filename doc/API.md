# API Reference

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
