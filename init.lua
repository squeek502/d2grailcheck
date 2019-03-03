local utils = require('d2grailcheck.utils')
local Data = require('d2grailcheck.data')
local Checker = require('d2grailcheck.checker')
local simpleDecorator = require('d2grailcheck.decorators.simple')

local GAME_DIR = "C:/Program Files (x86)/Diablo II/"
local SAVE_DIR = GAME_DIR .. "Save/"
local items = assert(utils.getItemsInDirectory(SAVE_DIR))

local data = Data.new(GAME_DIR)
local checker = Checker.new(data, items)
local out = simpleDecorator(checker)
print(out)

local function dump(tbl, key)
  for _, v in ipairs(tbl[key]) do
    print(v, tbl:getName(v))
  end
end

dump(checker.runes, 'missing')

--[[
local function getSimpleOutput(groups)
  local maxName, maxCurDigits, maxTotalDigits
  for _, group in ipairs(groups) do
    if not maxName or #group.name > maxName then
      maxName = #group.name
    end
    if not maxCurDigits or #tostring(group.cur) > maxCurDigits then
      maxCurDigits = #tostring(group.cur)
    end
    if not maxTotalDigits or #tostring(group.total) > maxTotalDigits then
      maxTotalDigits = #tostring(group.max)
    end
  end

  local fmt = "%-"..(maxName+2).."s %"..maxCurDigits.."d of %"..maxTotalDigits.."d (missing %d)"

  local out = {}
  for _, group in ipairs(groups) do
    table.insert(out, string.format(fmt, group.name..":", group.cur, group.total, group.total - group.cur))
  end
  return out
end

local out = getSimpleOutput({
  {name="Uniques", cur=checker.uniques.count, total=checker.uniques.total},
  {name="Set Items", cur=checker.sets.count, total=checker.sets.total},
  {name="Runes", cur=checker.runes.count, total=checker.runes.total},
  {name="Eth Uniques", cur=checker.ethUniques.count, total=checker.ethUniques.total},
})
print(table.concat(out, "\n"))
]]

--[[
for _, id in ipairs(checker.uniques.missing) do
  local name, base = checker.uniques:getName(id)
  print(name .. ' (' .. base .. ')')
end
]]--

--[[
print("\nHave:")
print(table.concat(haveEthUniques, "\n"))

print("\nMissing:")
print(table.concat(missingEthUniques, "\n"))
]]
