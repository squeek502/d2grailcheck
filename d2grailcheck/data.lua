local storm = require('storm')
local utils = require('d2grailcheck.utils')
local excelToTable, stringToArray = utils.excelToTable, utils.stringToArray
local pathjoin, pathexists = utils.pathjoin, utils.pathexists
local tblreader = require('d2grailcheck.tblreader')

local Data = {}
Data.__index = Data

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

function Data.new(dataDir)
  local self = setmetatable({}, Data)
  self.dir = dataDir
  self.patchMpq = assert(tryLoadMpq(self.dir, {'Patch_D2.mpq', 'patch_d2.mpq'}))
  self.expMpq = assert(tryLoadMpq(self.dir, 'd2exp.mpq'))
  self.dataMpq = assert(tryLoadMpq(self.dir, 'd2data.mpq'))
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

function Data:isRune(code)
  return self.runeItemCodes[code] ~= nil
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

function Data:_loadStringTable()
  self.stringTable = tblreader.read(
    assert(self.dataMpq:read("data\\local\\lng\\eng\\string.tbl")),
    assert(self.expMpq:read("data\\local\\lng\\eng\\expansionstring.tbl")),
    assert(self.patchMpq:read("data\\local\\lng\\eng\\patchstring.tbl"))
  )
end

function Data:_loadExcelData()
  self.uniqueData = excelToTable(stringToArray(assert(self.patchMpq:read('data\\global\\excel\\UniqueItems.txt'))))
  self.setData = excelToTable(stringToArray(assert(self.patchMpq:read('data\\global\\excel\\SetItems.txt'))))
  self.weaponData = excelToTable(stringToArray(assert(self.patchMpq:read('data\\global\\excel\\Weapons.txt'))))
  self.armorData = excelToTable(stringToArray(assert(self.patchMpq:read('data\\global\\excel\\Armor.txt'))))
  self.miscData = excelToTable(stringToArray(assert(self.patchMpq:read('data\\global\\excel\\Misc.txt'))))
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
  self.totalRunes = 0
  self.totalEthUniques = 0
  self.totalUniques = 0
  self.totalSetItems = #self.setData

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
end

return Data
