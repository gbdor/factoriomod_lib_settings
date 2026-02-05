local CONSTANTS = require("cfg/constants")


-- TODO: add manual ignores

data:extend({
  {
    type = "bool-setting",
    name = CONSTANTS.MOD_NAME .. "-verbose-logging",
    setting_type = "startup",
    default_value = true,
    order = "aa",
  }
})
