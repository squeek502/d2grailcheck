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

return function(checker)
  local out = getSimpleOutput({
    {name="Uniques", cur=checker.uniques.count, total=checker.uniques.total},
    {name="Set Items", cur=checker.sets.count, total=checker.sets.total},
    {name="Runes", cur=checker.runes.count, total=checker.runes.total},
    {name="Eth Uniques", cur=checker.ethUniques.count, total=checker.ethUniques.total},
  })
  return table.concat(out, "\n")
end
