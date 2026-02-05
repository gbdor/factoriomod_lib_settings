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


## How it works

- At settings stage, each mod defines their own settings as usual; then exposes those they want to
- At settings-update stage, mods are allowed to change exposed settings from others
- At settings-final-fixes stage, each mod exposing their settings call the settings lib 
  - Automatically change the values or their settings
  - (optionally) Hides any settings taht have been modified


### Priority

When multiple mods try to modify the same setting, Settings Share uses a priority system:

1. **Priority-based**: Lower priority numbers win (0 = highest priority)
2. **Alphabetical tiebreak**: If priorities are equal, mods are sorted alphabetically by the engine
3. **Concurrent access is logged**: If more than one mod tries to change a specific setting, the log file tells the whole story

Example:
```lua
-- Mod A (priority 100 (lowest), default)
LIB.set_setting("target-mod", "power-multiplier", 2.0)

-- Mod B (priority 50, higher priority)
LIB.set_setting("target-mod", "power-multiplier", 3.0, {priority=50})

-- Mod C (priority 50, same as B, but comes after alphabetically)
LIB.set_setting("target-mod", "value", 0.5, {priority=50})

-- Result: 
--   * Mod C wins (priority 50, and "mod-c" > "mod-b" alphabetically)
--   * factorio logs tells the whole story
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
- **Allowed values**: Restricts to specific allowed options (those declared in settings.lua)
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
- Ensure you're calling `require("__settings-share__/lib")` from a file in your mod
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

GNU GPL v3 License - See LICENSE file for details

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
