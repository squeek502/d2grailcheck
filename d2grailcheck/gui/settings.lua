local inifile = require('inifile')
local utils = require('d2grailcheck.utils')

local SETTINGS_PATH_ARRAY_MT = {__tostring=function(t) return table.concat(t, ';') end}
local SETTINGS_MAP_ARRAY_MT = {__tostring=function(t) return table.concat(utils.mapToArray(t), ',') end}
local SETTINGS_ARRAY_MT = {__tostring=function(t) return table.concat(t, ',') end}
local SETTINGS_DEFAULTS = {
  files = {
    game_dir = "C:\\Program Files (x86)\\Diablo II\\",
    save_dir = "",
    types = utils.arrayToMap({"chars", "plugy_shared", "plugy_personal", "atma"}),
    only_specific_files = false,
    specific_files = {},
  },
}

local function deepCopyDefaults(dest, defaults)
  for sectionName, sectionTable in pairs(defaults) do
    if not dest[sectionName] then dest[sectionName] = {} end
    for k,v in pairs(sectionTable) do
      dest[sectionName][k] = utils.deepCopy(v)
    end
  end
  return dest
end

local function loadSettings(filepath)
  local settings = {}

  if utils.pathexists(filepath) then
    settings = inifile.parse(filepath)
  end

  -- load defaults for missing keys
  settings = deepCopyDefaults(settings, SETTINGS_DEFAULTS)

  if type(settings.files.specific_files) == "string" then
    settings.files.specific_files = utils.splitString(settings.files.specific_files, ';')
  end
  if type(settings.files.types) == "string" then
    settings.files.types = utils.arrayToMap(utils.splitString(settings.files.types, ','))
  end
  setmetatable(settings.files.types, SETTINGS_MAP_ARRAY_MT)
  setmetatable(settings.files.specific_files, SETTINGS_PATH_ARRAY_MT)

  return settings
end

local function saveSettings(filepath, settings)
  local dirname = utils.dirname(filepath)
  if not utils.pathexists(filepath) and dirname then
    assert(utils.mkdir(dirname))
  end
  inifile.save(filepath, settings)
end

return {
  load = loadSettings,
  save = saveSettings,
}
