# Modifying Other Mods' Settings

In your `settings-updates.lua`

```lua
if mods["lib-settings"] and mods["other-mod"] then
  local LIB = require("__lib-settings__/lib")
  
  -- Modify another mod's setting
  LIB.set_setting("other-mod", "enable-feature", false)
  LIB.set_setting("other-mod", "power-multiplier", 2.5)
end
```