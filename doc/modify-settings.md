# Modifying Other Mods' Settings

In your `settings-updates.lua`

```lua
if mods["settings-share"] and mods["other-mod"] then
  local LIB = require("__settings-share__/lib")
  
  -- Modify another mod's setting
  LIB.set_setting("other-mod", "enable-feature", false)
  LIB.set_setting("other-mod", "power-multiplier", 2.5)
end
```