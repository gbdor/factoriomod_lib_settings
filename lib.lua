-- ==============================================================================
-- settings-share/lib.lua - Cross-mod settings access library
-- ==============================================================================
-- 
-- EXECUTION ORDER UNDERSTANDING:
-- 
-- Stage 1: settings.lua (ALL mods in dependency order)
--   - Mod A defines settings
--   - Mod B defines settings
--   - ...
--   - Mod Z defines settings
-- 
-- Stage 2: settings-updates.lua (ALL mods in same order)
--   - Mod A exposes settings via exposeSetting()
--   - Mod B exposes settings via exposeSetting()
--   - Mod C modifies Mod A's settings via set_setting()
--   - ...
-- 
-- Stage 3: settings-final-fixes.lua (ALL mods in same order)
--   - Mod A applies modifications via updateAllMySettings()
--   - Mod B applies modifications via updateAllMySettings()
--   - ...
-- 
-- This means:
-- 1. At settings.lua: Each mod defines their settings normally
-- 2. At settings-updates.lua: Mods expose settings AND request modifications
-- 3. At settings-final-fixes.lua: Owning mods apply all modifications
-- ==============================================================================

local CONSTANTS = require("cfg/constants")
local settings_verbose = settings.startup[CONSTANTS.MOD_NAME .. "-verbose-logging"].value or false
local L = settings_verbose and log or function() end
local lib = {}

-- ==============================================================================
-- INTERNAL STORAGE
-- ==============================================================================
-- We use data.raw custom tables since we can't use globals in settings stage

local function get_registry()
  data.raw["settings-share-registry"] = data.raw["settings-share-registry"] or {}
  return data.raw["settings-share-registry"]
end

local function get_modifications()
  data.raw["settings-share-modifications"] = data.raw["settings-share-modifications"] or {}
  return data.raw["settings-share-modifications"]
end

-- ==============================================================================
-- MOD NAME DETECTION
-- ==============================================================================
-- Detects calling mod name from package.loaded or debug.getinfo

local function detect_mod_name()
  
  -- Method 1: Search package.loaded for calling file
  -- Keys are in format: __mod-name__/path/to/file.lua
  for key, _ in pairs(package.loaded) do
    local mod_name = key:match("^__([^_]+)__/")
    if mod_name and mod_name ~= CONSTANTS.MOD_NAME then
      return mod_name
    end
  end
  
  -- Method 2: Try debug.getinfo to find calling file
  if debug and debug.getinfo then
    local info = debug.getinfo(3, "S") -- Level 3 = caller of caller of this function
    if info and info.source then
      local mod_name = info.source:match("^@?__([^_/]+)__/")
      if mod_name and mod_name ~= CONSTANTS.MOD_NAME then
        return mod_name
      end
    end
  end
  
  error("[settings-share] Could not detect calling mod name. Ensure you're calling from settings-updates.lua or settings-final-fixes.lua")
end

-- ==============================================================================
-- STAGE 2 API: EXPOSING SETTINGS (called in settings-updates.lua)
-- ==============================================================================

--- Expose a setting for other mods to access and modify
-- @param setting_name string - Setting name WITHOUT mod prefix (e.g., "enable-feature")
-- @param config table - Optional configuration
--   - type: Setting type (auto-detected if not provided)
--   - read_only: Prevent modifications (default: false)
--   - min_value: Minimum allowed value
--   - max_value: Maximum allowed value
--   - allowed_values: List of explicitly allowed values
--   - validator: Custom validation function (value) -> bool, error_msg
--   - auto_hide_modified: Automatically hide setting if modified (default: false)
function lib.exposeSetting(setting_name, config)
  config = config or {}
  
  local mod_name = detect_mod_name()
  local registry = get_registry()
  local full_name = mod_name .. "-" .. setting_name
  
  -- Auto-detect setting type if not provided
  local setting_type = config.type
  if not setting_type then
    for _, stype in ipairs({"bool-setting", "int-setting", "double-setting", "string-setting"}) do
      if data.raw[stype] and data.raw[stype][full_name] then
        setting_type = stype
        break
      end
    end
  end
  
  -- Validate setting exists
  if not setting_type or not data.raw[setting_type] or not data.raw[setting_type][full_name] then
    error("[settings-share] Setting does not exist: " .. full_name .. 
          ". Make sure it's defined in settings.lua before calling exposeSetting() in settings-updates.lua")
  end
  
  -- Store metadata in registry
  registry[full_name] = {
    owner_mod = mod_name,
    type = setting_type,
    read_only = config.read_only or false,
    min_value = config.min_value,
    max_value = config.max_value,
    allowed_values = config.allowed_values,
    validator = config.validator,
    auto_hide_modified = config.auto_hide_modified or false,
    original_hidden = data.raw[setting_type][full_name].hidden or false,
    last_modified_by = nil,
    version = 1
  }
  
  log("[settings-share] Exposed: " .. full_name .. " (type: " .. setting_type .. ")")
end

-- ==============================================================================
-- STAGE 2 API: REQUESTING MODIFICATIONS (called in settings-updates.lua)
-- ==============================================================================

--- Request to modify another mod's exposed setting
-- @param owner_mod_name string - Name of mod that owns the setting
-- @param setting_name string - Setting name WITHOUT mod prefix
-- @param value any - New value to set
-- @param options table - Optional configuration
--   - property: Which property to modify (default: "default_value")
--   - priority: Priority for conflict resolution (default: 100, lower = higher priority)
function lib.set_setting(owner_mod_name, setting_name, value, options)
  options = options or {}
  
  local requesting_mod = detect_mod_name()
  local registry = get_registry()
  local modifications = get_modifications()
  
  local full_name = owner_mod_name .. "-" .. setting_name
  local meta = registry[full_name]
  
  -- Validate setting is exposed
  if not meta then
    error("[settings-share] Setting not exposed for sharing: " .. full_name .. 
          ". The owning mod (" .. owner_mod_name .. ") must call exposeSetting() first.")
  end
  
  -- Check read-only protection
  if meta.read_only then
    error("[settings-share] Setting is read-only: " .. full_name)
  end
  
  -- Determine property to modify
  local property = options.property or "default_value"
  
  -- Store modification request
  modifications[full_name] = modifications[full_name] or {}
  table.insert(modifications[full_name], {
    requesting_mod = requesting_mod,
    property = property,
    value = value,
    priority = options.priority or 100
  })
  
  log("[settings-share] Modification requested: " .. full_name .. "." .. property .. 
      " = " .. tostring(value) .. " (by " .. requesting_mod .. ", priority " .. (options.priority or 100) .. ")")
end

-- ==============================================================================
-- STAGE 3 API: APPLYING MODIFICATIONS (called in settings-final-fixes.lua)
-- ==============================================================================

--- Apply all modifications to this mod's exposed settings
-- This is the recommended one-liner to call in settings-final-fixes.lua
function lib.updateAllMySettings()
  local mod_name = detect_mod_name()
  local registry = get_registry()
  local modifications = get_modifications()
  
  local settings_modified = false
  
  -- Find all settings owned by this mod
  for setting_name, meta in pairs(registry) do
    if meta.owner_mod == mod_name then
      local mods_list = modifications[setting_name]
      
      if mods_list and #mods_list > 0 then
        -- Sort modifications by priority, then by mod name for determinism
        table.sort(mods_list, function(a, b)
          if a.priority ~= b.priority then
            return a.priority < b.priority -- Lower number = higher priority
          end
          return a.requesting_mod < b.requesting_mod -- Alphabetical tiebreak
        end)
        
        -- Apply modifications in REVERSE order so highest priority (lowest number) wins last
        local setting = data.raw[meta.type][setting_name]
        local applied_count = 0
        
        for i = #mods_list, 1, -1 do
          local mod_req = mods_list[i]
          -- Validate value
          local valid, err = lib._validate_value(meta, mod_req.property, mod_req.value)
          
          if valid then
            -- Apply the modification
            setting[mod_req.property] = mod_req.value
            meta.last_modified_by = mod_req.requesting_mod
            meta.version = meta.version + 1
            applied_count = applied_count + 1
            
            log("[settings-share] ✓ Applied: " .. setting_name .. "." .. mod_req.property .. 
                " = " .. tostring(mod_req.value) .. " (by " .. mod_req.requesting_mod .. ")")
          else
            log("[settings-share] ✗ REJECTED: " .. setting_name .. " by " .. mod_req.requesting_mod .. 
                " - " .. err)
          end
        end
        
        -- Auto-hide setting if it was modified and auto_hide_modified is enabled
        if applied_count > 0 and meta.auto_hide_modified then
          setting.hidden = true
          log("[settings-share] Auto-hidden: " .. setting_name .. " (was modified)")
          settings_modified = true
        end
        
        if applied_count > 0 then
          settings_modified = true
        end
      end
    end
  end
  
  if settings_modified then
    log("[settings-share] Finished updating settings for mod: " .. mod_name)
  end
end

-- ==============================================================================
-- ALTERNATIVE STAGE 3 API: ITERATOR-BASED (for fine-grained control)
-- ==============================================================================

--- Get an iterator over all modifications to this mod's settings
-- Use this if you need fine-grained control over how modifications are applied
-- @return iterator of (setting_name, modification) pairs
function lib.get_my_exposed_settings()
  local mod_name = detect_mod_name()
  local registry = get_registry()
  local modifications = get_modifications()
  local results = {}
  
  for setting_name, meta in pairs(registry) do
    if meta.owner_mod == mod_name then
      local mods_list = modifications[setting_name]
      
      if mods_list and #mods_list > 0 then
        -- Sort by priority
        table.sort(mods_list, function(a, b)
          if a.priority ~= b.priority then
            return a.priority < b.priority
          end
          return a.requesting_mod < b.requesting_mod
        end)
        
        -- Collect all valid modifications
        local valid_mods = {}
        for _, mod_req in ipairs(mods_list) do
          local valid, err = lib._validate_value(meta, mod_req.property, mod_req.value)
          if valid then
            table.insert(valid_mods, {
              property = mod_req.property,
              value = mod_req.value,
              modified_by = mod_req.requesting_mod,
              priority = mod_req.priority
            })
          end
        end
        
        if #valid_mods > 0 then
          results[setting_name] = valid_mods
        end
      end
    end
  end
  
  return pairs(results)
end

-- ==============================================================================
-- INTERNAL VALIDATION LOGIC
-- ==============================================================================

--- Validate a value against the setting's constraints
-- @param meta table - Setting metadata from registry
-- @param property string - Property being modified
-- @param value any - Value to validate
-- @return boolean, string - (is_valid, error_message)
function lib._validate_value(meta, property, value)
  -- Only validate value properties (default_value, forced_value)
  if property ~= "default_value" and property ~= "forced_value" then
    return true -- Don't validate other properties like "hidden", "order", etc.
  end
  
  -- Type-specific validation
  if meta.type == "bool-setting" then
    if type(value) ~= "boolean" then
      return false, "Expected boolean, got " .. type(value)
    end
  elseif meta.type == "int-setting" then
    if type(value) ~= "number" or math.floor(value) ~= value then
      return false, "Expected integer, got " .. type(value)
    end
  elseif meta.type == "double-setting" then
    if type(value) ~= "number" then
      return false, "Expected number, got " .. type(value)
    end
  elseif meta.type == "string-setting" then
    if type(value) ~= "string" then
      return false, "Expected string, got " .. type(value)
    end
  end
  
  -- Check allowed_values constraint
  if meta.allowed_values then
    local found = false
    for _, allowed in ipairs(meta.allowed_values) do
      if value == allowed then
        found = true
        break
      end
    end
    if not found then
      return false, "Value '" .. tostring(value) .. "' not in allowed_values: " .. 
             table.concat(meta.allowed_values, ", ")
    end
  end
  
  -- Check min_value constraint
  if meta.min_value and type(value) == "number" and value < meta.min_value then
    return false, "Value " .. value .. " below min_value (" .. meta.min_value .. ")"
  end
  
  -- Check max_value constraint
  if meta.max_value and type(value) == "number" and value > meta.max_value then
    return false, "Value " .. value .. " above max_value (" .. meta.max_value .. ")"
  end
  
  -- Custom validator function
  if meta.validator then
    local ok, err = meta.validator(value)
    if not ok then
      return false, "Custom validation failed: " .. (err or "unknown reason")
    end
  end
  
  return true
end

-- ==============================================================================
-- UTILITY FUNCTIONS FOR DEBUGGING
-- ==============================================================================

--- Get all exposed settings (for debugging)
-- @return table - Registry of all exposed settings
function lib.get_all_exposed_settings()
  return get_registry()
end

--- Get all pending modifications (for debugging)
-- @return table - All modification requests
function lib.get_all_modifications()
  return get_modifications()
end

--- Print statistics about settings sharing
function lib.print_statistics()
  local registry = get_registry()
  local modifications = get_modifications()
  
  local total_exposed = 0
  local total_modified = 0
  local by_mod = {}
  
  for setting_name, meta in pairs(registry) do
    total_exposed = total_exposed + 1
    by_mod[meta.owner_mod] = (by_mod[meta.owner_mod] or 0) + 1
    
    if modifications[setting_name] and #modifications[setting_name] > 0 then
      total_modified = total_modified + 1
    end
  end
  
  log("[settings-share] === STATISTICS ===")
  log("[settings-share] Total exposed settings: " .. total_exposed)
  log("[settings-share] Settings with modifications: " .. total_modified)
  log("[settings-share] Settings by mod:")
  for mod, count in pairs(by_mod) do
    log("[settings-share]   " .. mod .. ": " .. count .. " settings")
  end
end

return lib