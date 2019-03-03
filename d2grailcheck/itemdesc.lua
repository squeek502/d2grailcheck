local itemdesc = {}

local bit = require('bit')

local ITEM_STATS_STRING_TO = 'ItemStast1k' -- 'to'
local ITEM_STATS_REPAIRSN = 'ModStre9u' -- Repairs %d in %d sec
local ITEM_STATS_LEVEL = 'ModStre10b' -- 'Level'

local VALDISP_NONE = 0
local VALDISP_LEADING = 1
local VALDISP_TRAILING = 2

itemdesc.funcs = {
  [1] = function(disp, val)
    local str = val >= 0 and disp.pos or disp.neg
    if disp.val == VALDISP_NONE then return str end
    if disp.val == VALDISP_LEADING then
      return string.format("%+d %s", val, str)
    else
      return string.format("%s %+d", str, val)
    end
  end,
  [2] = function(disp, val)
    local str = val >= 0 and disp.pos or disp.neg
    if disp.val == VALDISP_NONE then return str end
    if disp.val == VALDISP_LEADING then
      return string.format("%d%% %s", val, str)
    else
      return string.format("%s %d%%", str, val)
    end
  end,
  [3] = function(disp, val)
    local str = val >= 0 and disp.pos or disp.neg
    if disp.val == VALDISP_NONE then return str end
    if disp.val == VALDISP_LEADING then
      return string.format("%d %s", val, str)
    else
      return string.format("%s %d", str, val)
    end
  end,
  [4] = function(disp, val)
    local str = val >= 0 and disp.pos or disp.neg
    if disp.val == VALDISP_NONE then return str end
    if disp.val == VALDISP_LEADING then
      return string.format("%+d%% %s", val, str)
    else
      return string.format("%s %+d%%", str, val)
    end
  end,
  [5] = function(disp, val)
    val = bit.rshift(val*0x64, 7) -- or val/1.28?
    return itemdesc.funcs[2](disp, val)
  end,
  [6] = function(disp, val)
    return itemdesc.funcs[1](disp, val).." "..disp.str2
  end,
  [7] = function(disp, val)
    return itemdesc.funcs[4](disp, val).." "..disp.str2
  end,
  [8] = function(disp, val)
    return itemdesc.funcs[2](disp, val).." "..disp.str2
  end,
  [9] = function(disp, val)
    return itemdesc.funcs[3](disp, val).." "..disp.str2
  end,
  [11] = function(disp, val)
    local quotient = 2500/val
    if quotient <= 30 then
      return string.format(disp.pos, val)
    else
      local duration = math.floor(quotient + 12) / 25
      local fmt = disp.strings.tbl[ITEM_STATS_REPAIRSN]
      return string.format(fmt, 1, duration)
    end
  end,
  [12] = function(disp, val)
    -- TODO: why does this use a separate func?
    return itemdesc.funcs[1](disp, val)
  end,
  [13] = function(disp, classId, val)
    local classAllSkills = disp.strings.classAllSkills[classId]
    classAllSkills = disp.strings.tbl[classAllSkills]
    disp.pos, disp.neg = classAllSkills, classAllSkills
    return itemdesc.funcs[1](disp, val)
  end,
  [14] = function(disp, data, val)
    local classId = bit.rshift(data, 3)
    local skillTabId = bit.band(data, 0x7)
    local skillTabKey = disp.strings.skillTabs[classId][skillTabId]
    local skillTabFormat = disp.strings.tbl[skillTabKey]
    local classOnly = disp.strings.classOnly[classId]
    classOnly = disp.strings.tbl[classOnly]
    return string.format("%s %s", string.format(skillTabFormat, val), classOnly)
  end,
  [15] = function(disp, lvl, skill, chance)
    local str = chance >= 0 and disp.pos or disp.neg
    local skillDesc = disp.strings.skills[skill]
    local skillName = disp.strings.tbl[skillDesc]
    return string.format(str, chance, lvl, skillName)
  end,
  [16] = function(disp, skill, lvl)
    local str = lvl >= 0 and disp.pos or disp.neg
    local skillDesc = disp.strings.skills[skill]
    local skillName = disp.strings.tbl[skillDesc]
    return string.format(str, lvl, skillName)
  end,
  [20] = function(disp, val)
    return itemdesc.funcs[4](disp, -val)
  end,
  [22] = function(disp, mon, val)
    local str = val >= 0 and disp.pos or disp.neg
    local monKey = disp.strings.monsters[mon]
    local monName = disp.strings.tbl[monKey]
    return string.format("%s: %s", itemdesc.funcs[4](disp, val), monName)
  end,
  [23] = function(disp, mon, chance)
    local str = chance >= 0 and disp.pos or disp.neg
    local monKey = disp.strings.monsters[mon]
    local monName = disp.strings.tbl[monKey]
    return string.format("%d%% %s %s", chance, str, monName)
  end,
  [24] = function(disp, lvl, skill, charges, maxcharges)
    -- TODO: check that this is actually what's used
    -- can do that by altering the .TBL to test
    local levelStr = disp.strings.tbl[ITEM_STATS_LEVEL]
    local skillDesc = disp.strings.skills[skill]
    local skillName = disp.strings.tbl[skillDesc]
    return string.format("%s %d %s %s", levelStr, lvl, skillName, string.format(disp.pos, charges, maxcharges))
  end,
  [27] = function(disp, skill, num)
    local skillClass = disp.strings.skillClasses[skill]
    local classOnly = disp.strings.classOnly[skillClass]
    classOnly = disp.strings.tbl[classOnly]
    local skillBonus = itemdesc.funcs[28](disp, skill, num)
    return string.format("%s %s", skillBonus, classOnly)
  end,
  [28] = function(disp, skill, num)
    local str = num >= 0 and disp.pos or disp.neg
    local skillKey = disp.strings.skills[skill]
    local skillName = disp.strings.tbl[skillKey]
    local to = disp.strings.tbl[ITEM_STATS_STRING_TO]
    return string.format("%+d %s %s", num, to, skillName)
  end,
}

function itemdesc.translate(prop, stat, strings)
  local func = stat.descfunc
  if func == nil then return nil end

  local fn = itemdesc.funcs[func]
  if fn == nil then return nil, string.format("func %d not found or not implemented {%s}:\n\t%s: %s\n\t%s: %s\n\t%s: %s", func, table.concat(prop.params,","), tostring(stat.descstrpos), tostring(strings.tbl[stat.descstrpos]), tostring(stat.descstrneg), tostring(strings.tbl[stat.descstrneg]), tostring(stat.descstr2), tostring(strings.tbl[stat.descstr2])) end

  local descpos, descneg, desc2 = stat.descstrpos, stat.descstrneg, stat.descstr2
  descpos, descneg, desc2 = strings.tbl[descpos], strings.tbl[descneg], strings.tbl[desc2]

  local disp = {val=stat.descval, pos=descpos, neg=descneg, str2=desc2, strings=strings}

  return fn(disp, unpack(prop.params))
end

return itemdesc
