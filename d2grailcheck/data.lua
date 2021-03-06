local storm = require('storm')
local utils = require('d2grailcheck.utils')
local excelToTable, stringToArray = utils.excelToTable, utils.stringToArray
local pathjoin, pathexists = utils.pathjoin, utils.pathexists
local tblreader = require('d2grailcheck.tblreader')

local Data = {}
Data.__index = Data

-- this ID is not in UniqueItems.txt
Data.STANDARD_OF_HEROES_ID = 4095

local function tryLoadMpq(dir, names)
  if type(names) == 'string' then names = {names} end
  for _, name in ipairs(names) do
    local path = pathjoin(dir, name)
    if pathexists(path) then
      local mpq, err = storm.open(path)
      if err then
        return nil, err
      end
      return mpq
    end
  end
  return nil, 'MPQ file not found with name(s) ' .. table.concat(names, ', ') .. ' in \'' .. dir ..'\''
end

function Data.new(gameDir)
  local self = setmetatable({}, Data)
  self.dir = gameDir
  self.patchMpq = tryLoadMpq(self.dir, {'Patch_D2.mpq', 'patch_d2.mpq'})
  self.expMpq = tryLoadMpq(self.dir, 'd2exp.mpq')
  self.dataMpq = tryLoadMpq(self.dir, 'd2data.mpq')
  self:_loadStringTable()
  self:_loadExcelData()
  self:_setup()
  return self
end

function Data:isWeapon(code)
  return self.weaponDict[code] ~= nil
end

function Data:isArmor(code)
  return self.armorDict[code] ~= nil
end

function Data:hasDurability(code)
  if self.noDurabilityDict[code] then
    return false
  end
  return self:isWeapon(code) or self:isArmor(code)
end

function Data:isStandardOfHeroes(uniqueID)
  return uniqueID == self.STANDARD_OF_HEROES_ID
end

function Data:isRune(code)
  return self.runeItemCodes[code] ~= nil
end

function Data:isRuneword(codestring)
  return self.runeWords[codestring] ~= nil
end

function Data:getItemCodeName(code)
  return self.itemCodeNames[code]
end

function Data:isQuestItem(code)
  return self.questItemCodes[code] ~= nil
end

function Data:getString(key)
  return self.stringTable[key]
end

function Data:_getDataFromDiskOrMPQ(mpq, path)
  local filepath = path:gsub("\\", "/")
  filepath = pathjoin(self.dir, filepath)
  if pathexists(filepath) then
    local file = assert(io.open(filepath, "rb"))
    local contents = file:read("*a")
    file:close()
    return contents
  elseif mpq then
    return assert(mpq:read(path))
  else
    return nil, "filepath '"..filepath.."' doesn't exist and mpq is nil"
  end
end

function Data:_loadStringTable()
  self.stringTable = tblreader.read(
    assert(self:_getDataFromDiskOrMPQ(self.dataMpq, "data\\local\\lng\\eng\\string.tbl")),
    assert(self:_getDataFromDiskOrMPQ(self.expMpq, "data\\local\\lng\\eng\\expansionstring.tbl")),
    assert(self:_getDataFromDiskOrMPQ(self.patchMpq, "data\\local\\lng\\eng\\patchstring.tbl"))
  )
end

function Data:_loadExcelData()
  self.uniqueData = excelToTable(stringToArray(assert(self:_getDataFromDiskOrMPQ(self.patchMpq, 'data\\global\\excel\\UniqueItems.txt'))))
  self.setData = excelToTable(stringToArray(assert(self:_getDataFromDiskOrMPQ(self.patchMpq, 'data\\global\\excel\\SetItems.txt'))))
  self.weaponData = excelToTable(stringToArray(assert(self:_getDataFromDiskOrMPQ(self.patchMpq, 'data\\global\\excel\\Weapons.txt'))))
  self.armorData = excelToTable(stringToArray(assert(self:_getDataFromDiskOrMPQ(self.patchMpq, 'data\\global\\excel\\Armor.txt'))))
  self.miscData = excelToTable(stringToArray(assert(self:_getDataFromDiskOrMPQ(self.patchMpq, 'data\\global\\excel\\Misc.txt'))))
  self.runewordData = excelToTable(stringToArray(assert(self:_getDataFromDiskOrMPQ(self.patchMpq, 'data\\global\\excel\\Runes.txt'))))
end

function Data:canRowBeEth(row)
  local code = row.code
  local canBe = true
  for i=1,12 do
    local prop = row["prop"..i]
    if prop then
      -- indestructable uniques can't be eth
      if prop == "indestruct" then
        canBe = false
      end
      -- but always eth uniques are always eth
      if prop == "ethereal" then
        return true
      end
    end
  end
  return canBe and self:hasDurability(code)
end

function Data:_setup()
  self.questItemCodes = {}
  self.itemCodeNames = {}
  self.runeItemCodes = {}
  self.runeArray = {}
  self.weaponDict = {}
  self.armorDict = {}
  self.noDurabilityDict = {}
  self.runeWords = {}
  self.totalRunes = 0
  self.totalEthUniques = 0
  self.totalUniques = 0
  self.totalSetItems = #self.setData
  self.totalRunewords = 0

  for _, row in ipairs(self.weaponData) do
    if row.quest and row.quest ~= 0 then
      self.questItemCodes[row.code] = true
    end
    self.itemCodeNames[row.code] = self.stringTable[row.namestr]
    self.weaponDict[row.code] = true
    if row.nodurability == 1 then
      self.noDurabilityDict[row.code] = true
    end
  end

  for _, row in ipairs(self.armorData) do
    if row.quest and row.quest ~= 0 then
      self.questItemCodes[row.code] = true
    end
    self.itemCodeNames[row.code] = self.stringTable[row.namestr]
    self.armorDict[row.code] = true
  end

  for _, row in ipairs(self.miscData) do
    if row.quest and row.quest ~= 0 then
      self.questItemCodes[row.code] = true
    end
    self.itemCodeNames[row.code] = self.stringTable[row.namestr]
    if row.type == "rune" then
      self.runeItemCodes[row.code] = true
      self.totalRunes = self.totalRunes + 1
      table.insert(self.runeArray, row.code)
    end
  end

  for _, row in ipairs(self.uniqueData) do
    if row.enabled == 1 and not self.questItemCodes[row.code] then
      self.totalUniques = self.totalUniques + 1
      if self:canRowBeEth(row) then
        self.totalEthUniques = self.totalEthUniques + 1
      end
    end
  end

  for _, row in ipairs(self.runewordData) do
    if row.complete == 1 then
      local runeCodes = (row.Rune1 or "") .. (row.Rune2 or "") .. (row.Rune3 or "") .. (row.Rune4 or "") .. (row.Rune5 or "") .. (row.Rune6 or "")
      self.runeWords[runeCodes] = self.stringTable[row.Name]
      self.totalRunewords = self.totalRunewords + 1
    end
  end
end

return Data
