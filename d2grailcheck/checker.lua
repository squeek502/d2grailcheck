local ItemGroup = {}
ItemGroup.__index = ItemGroup

function ItemGroup.new()
  local self = setmetatable({}, ItemGroup)
  self.count = 0
  self.counts = {}
  self.missing = {}
  self.have = {}
  self.names = {}
  self.baseNames = {}
  return self
end

function ItemGroup:add(id)
  if self.counts[id] == nil then
    self.counts[id] = 0
    self.count = self.count + 1
  end
  self.counts[id] = self.counts[id] + 1
end

function ItemGroup:addMissing(id)
  table.insert(self.missing, id)
end

function ItemGroup:setNames(id, name, baseName)
  self.names[id] = name
  self.baseNames[id] = baseName
end

function ItemGroup:getName(id)
  return self.names[id], self.baseNames[id]
end

function ItemGroup:has(id)
  return self.counts[id] ~= nil
end

function ItemGroup:clear()
  self.count = 0
  self.counts = {}
  self.missing = {}
  self.have = {}
end

function ItemGroup:finalize()
  -- sanity check
  for _, id in ipairs(self.missing) do
    assert(not self:has(id))
  end
  for id in self:iterator() do
    table.insert(self.have, id)
  end
  self.total = #self.have + #self.missing
end

function ItemGroup:iterator()
  return pairs(self.counts)
end

local Uniques = setmetatable({}, {__index = ItemGroup})
Uniques.__index = Uniques

function Uniques.new()
  local self = setmetatable(ItemGroup.new(), Uniques)
  return self
end

local Checker = {}
Checker.__index = Checker

function Checker.new(data, items)
  local self = setmetatable({}, Checker)
  self.data = data
  self.sets = ItemGroup.new()
  self.uniques = Uniques.new()
  self.ethUniques = Uniques.new()
  self.runes = ItemGroup.new()
  self.runewords = ItemGroup.new()
  if type(items) == 'table' then
    self:check(items)
  end
  return self
end

function Checker:isUniqueApplicable(id, code)
  return not self.data:isQuestItem(code) and not self.data:isStandardOfHeroes(id)
end

function Checker:check(items)
  for _, item in ipairs(items) do
    if item.rarity == "unique" and self:isUniqueApplicable(item.rarityData.id, item.code) then
      local id = item.rarityData.id
      self.uniques:add(id)
      if item.ethereal then
        self.ethUniques:add(id)
      end
    elseif item.rarity == "set" then
      local id = item.rarityData.id
      self.sets:add(id)
    elseif self.data:isRune(item.code) then
      local id = item.code
      self.runes:add(id)
    elseif item.isRuneword then
      local runes = item.socketedItems
      if #runes == item.numSockets then
        local runeCodes = ""
        for _, rune in ipairs(runes) do
          runeCodes = runeCodes .. rune.code
        end
        if self.data:isRuneword(runeCodes) then
          self.runewords:add(runeCodes)
        end
      end
    end
  end

  for _, row in ipairs(self.data.uniqueData) do
    local id = row._ID
    if row.enabled == 1 and self:isUniqueApplicable(id, row.code) then
      self.uniques:setNames(id, self.data:getString(row.index), self.data:getItemCodeName(row.code))
      if not self.uniques:has(id) then
        self.uniques:addMissing(id)
      end
      if self.data:canRowBeEth(row) then
        self.ethUniques:setNames(id, self.data:getString(row.index), self.data:getItemCodeName(row.code))
        if not self.ethUniques:has(id) then
          self.ethUniques:addMissing(id)
        end
      end
    end
  end

  for _, row in ipairs(self.data.setData) do
    local id = row._ID
    self.sets:setNames(id, self.data:getString(row.index), self.data:getItemCodeName(row.code))
    if not self.sets:has(id) then
      self.sets:addMissing(id)
    end
  end

  for _, code in pairs(self.data.runeArray) do
    self.runes:setNames(code, self.data:getItemCodeName(code), code)
    if not self.runes:has(code) then
      self.runes:addMissing(code)
    end
  end

  for codes, name in pairs(self.data.runeWords) do
    self.runewords:setNames(codes, name)
    if not self.runewords:has(codes) then
      self.runewords:addMissing(codes)
    end
  end

  self.uniques:finalize()
  self.ethUniques:finalize()
  self.sets:finalize()
  self.runes:finalize()
  self.runewords:finalize()
end

--[[
local function getRowById(tbl, id)
  for _, row in ipairs(tbl) do
    if row._ID == id then
      return row
    end
  end
end

local haveEthUniques = {}
for id in pairs(ethUniqueCounts) do
  local row = getRowById(uniqueData, id)
  table.insert(haveEthUniques, stringTable[row.index] .. " (" .. itemCodeNames[row.code] .. ")")
end
local missingUniques = {}
local missingEthUniques = {}
for _, data in ipairs(uniqueData) do
  local id = data._ID
  if data.enabled == 1 and not questItemCodes[data.code] then
    if uniqueCounts[id] == nil then
      table.insert(missingUniques, stringTable[data.index] .. " (" .. itemCodeNames[data.code] .. ")")
    end
    if ethUniqueCounts[id] == nil and canBeEth(data) then
      table.insert(missingEthUniques, stringTable[data.index] .. " (" .. itemCodeNames[data.code] .. ")")
    end
  end
end
local missingSets = {}
for _, data in ipairs(setData) do
  local id = data._ID
  if setCounts[id] == nil then
    table.insert(missingSets, stringTable[data.index] .. " (" .. itemCodeNames[data.item] .. ")")
  end
end
local missingRunes = {}
for _, code in pairs(runeArray) do
  if runeCounts[code] == nil then
    table.insert(missingRunes, itemCodeNames[code] .. " (" .. code .. ")")
  end
end
]]--

return Checker
