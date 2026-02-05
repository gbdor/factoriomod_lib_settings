local lib = {}

-- Internal storage (uses data.raw custom tables since we can't use globals in settings stage)
local function get_registry()
  data.raw["settings-share-registry"] = data.raw["settings-share-registry"] or {}
  return data.raw["settings-share-registry"]
end

local function get_modifications()
  data.raw["settings-share-modifications"] = data.raw["settings-share-modifications"] or {}
  return data.raw["settings-share-modifications"]
end

-- Utility: Detect calling mod name from package.loaded keys
local function detect_mod_name()
  -- Search package.loaded for the calling file
  for key, _ in pairs(package.loaded) do
    -- Keys are in format: __mod-name__/path/to/file.lua
    local mod_name = key:match("^__([^_]+)__/")
    if mod_name and mod_name ~= "settings-share" then
      return mod_name
    end
  end
  error("Could not detect calling mod name. Are you calling this from a required file?")
end
