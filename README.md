# Factorio settings lib

**A library mod for Factorio that enables safe cross-mod settings access and modification.**

This mod provides a simple, safe API for mod authors to expose their settings to other mods, allowing for 
- purpose mods to expose setting for other mods to modify
- metamods, overhauls or mods with dependencies to tune mods they rely on to their customs
- prevent any conflicts

## Work in progress 

**This mod does nothing on its own**
**this mod is under development, use with caution** 

## Features (planned)

- 🚀 **Minimal Integration**: Easy integration into mods who want to expose their settings
- 🔒 **Safe by Design**: Only explicitly exposed settings can be accessed
- 🔍 **Auto-Hiding**: Settings modified by other mods are hidden from the settings interface

- ✅ **Value Validation**: Automatic validation against min/max values and allowed values
- 🎯 **Priority System**: Deterministic conflict resolution when multiple mods modify the same setting
- 📝 **Comprehensive Logging**: Full audit trail of all modifications
- 🛡️ **Read-Only Protection**: Optional read-only flag prevents unwanted modifications

## Installation & setup

### For Players

- Install your favorite overhaul mod, it takes care of everything
- Open settings: tune whatever settings from the overhaul mods. The settings taht would be overwritten are hidden


### For Mod Authors

- (How to expose your mod's settings)[doc/expose-settings.md]
- (How to modify other mod's settings)[doc/modify-settings.md]
- (API reference)[doc/API.md]
- (Usage examples)[doc/usage.md]
- (Troubleshooting and FAQ)[doc/troubleshooting.md]


## How it works

- At settings stage, each mod defines their own settings as usual; then exposes those they want to
- At settings-update stage, mods are allowed to change exposed settings from others
- At settings-final-fixes stage, each mod exposing their settings call the settings lib 
  - Automatically change the values or their settings
  - (optionally) Hides any settings taht have been modified

### Understanding the Settings Stage

Factorio processes settings in three sequential stages:

1. **`settings.lua`**: Define your settings here
2. **`settings-updates.lua`**: Expose settings and request modifications here
3. **`settings-final-fixes.lua`**: Apply modifications here

Settings Share uses this staged approach to ensure:
- All settings are defined before exposure
- All exposure happens before modifications are requested
- All modifications are validated and applied in a deterministic order

### Conflict Resolution

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

### Validation and Safety

Settings Share provides multiple layers of safety:

#### 1. Explicit Opt-In
Only settings that are explicitly exposed via `exposeSetting()` can be accessed. This prevents:
- Accidental modification of internal settings
- Access to sensitive configuration values
- Unexpected behavior from undocumented settings

#### 2. Type Validation
Settings Share validates values against:
- **Minimum values**: Prevents values below `min_value`
- **Maximum values**: Prevents values above `max_value`
- **Allowed values**: Restricts to specific allowed options
- **Custom validators**: Your own validation logic

Invalid modifications are rejected and logged.

#### 3. Read-Only Protection
Settings can be marked as `read_only = true` to:
- Share information with other mods
- Prevent any modifications
- Useful for version numbers, capability flags, etc.

#### 4. Comprehensive Logging
All modifications are logged with:
- Which mod requested the change
- What value was requested
- Whether it was accepted or rejected
- Why it was rejected (if applicable)

Check your `factorio-current.log` for detailed information.





## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request with tests

## Support

- **Bug Reports**: [GitHub Issues](https://github.com/gbdor/factoriomod_lib_settings/issues)
- **Mod Portal**: [Homepage](https://mods.factorio.com/mod/lib_settings)
- **Forum Thread**: [Mod Portal Discussion](https://mods.factorio.com/mod/lib_settings/discussion)

---
