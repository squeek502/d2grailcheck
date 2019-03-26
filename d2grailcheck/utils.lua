local lfs = require('lfs')
local d2itemreader = require('d2itemreader')

local utils = {}

function utils.extname(path)
  return path:match(".(%.[^.]*)$")
end

-- strip any trailing slashes
function utils.pathnorm(path)
  local norm = path:gsub("([^\\/])[\\/]+$", "%1")
  return norm
end

function utils.pathjoin(...)
  local paths = {}
  for _, path in pairs({...}) do
    table.insert(paths, utils.pathnorm(path))
  end
  local usedPathSep = paths[1]:match("[/\\]")
  return table.concat(paths, usedPathSep or "/")
end

function utils.pathexists(path)
  return lfs.attributes(path, "mode") ~= nil
end

function utils.getItemsInDirectory(saveDir)
  local allItems = {}
  for file in lfs.dir(saveDir) do
    if file ~= "." and file ~= ".." then
      local ext = utils.extname(file)
      if ext == '.d2s' or ext == '.d2x' or ext == '.sss' then
        local fullpath = utils.pathjoin(saveDir, file)
        local items, err = d2itemreader.getitems(fullpath)
        if not items then
          return nil, err
        end
        for _,v in ipairs(items) do
          table.insert(allItems, v)
        end
      end
    end
  end
  return allItems
end

function utils.fileToArray(filepath)
  local t={}
  for l in assert(io.lines(filepath)) do t[#t+1] = l:gsub("\r$", "") end
  return t
end

function utils.stringToArray(str)
  local t={}
  for s in str:gmatch("[^\r\n]+") do table.insert(t, s) end
  return t
end

function utils.splitString(str, sep)
  local parts = {}
  local pos = 0
  local splitIterator = function() return str:find(sep, pos, true) end
  for sepStart, sepEnd in splitIterator do
    table.insert(parts, str:sub(pos, sepStart - 1))
    pos = sepEnd + 1
  end
  table.insert(parts, str:sub(pos))
  return parts
end

function utils.excelToTable(lines)
  local headerLine = table.remove(lines, 1)
  local headers = utils.splitString(headerLine, "\t")
  local rows = {}
  local id, rowNum = 0, 2
  for _, line in ipairs(lines) do
    local row = {_ROWNUM=rowNum, _ID=id}
    local fields = utils.splitString(line, "\t")
    if fields[1] ~= "Expansion" then
      for i, field in ipairs(fields) do
        if field == "" then field = nil end
        if tonumber(field) then field = tonumber(field) end
        row[headers[i]] = field
      end
      table.insert(rows, row)
      id = id+1
    end
    rowNum = rowNum+1
  end
  return rows
end

function utils.arrayContains(arr, needle)
  for _, v in ipairs(arr) do
    if v == needle then
      return true
    end
  end
  return false
end

local function dirHas113Dlls(dir)
  return utils.pathexists(utils.pathjoin(dir, "D2Client.dll")) or utils.pathexists(utils.pathjoin(dir, "d2client.dll"))
end

local function dirIsD2(dir)
  return utils.pathexists(utils.pathjoin(dir, "Game.exe")) and utils.pathexists(utils.pathjoin(dir, "Diablo II.exe"))
end

function utils.guessSaveDir(gameDir)
  local _, saveDir = utils.getDiabloVersionAndSaveDir(gameDir)
  if not saveDir then
    saveDir = utils.pathjoin(gameDir, "Save")
  end
  return saveDir
end

function utils.getDiabloVersionAndSaveDir(gameDir)
  if not dirIsD2(gameDir) then
    return nil
  end
  if dirHas113Dlls(gameDir) then
    return "<= 1.13", utils.pathjoin(gameDir, "Save")
  else
    return ">= 1.14", utils.pathjoin(os.getenv("USERPROFILE"), "Saved Games", "Diablo II")
  end
end

return utils
