
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


