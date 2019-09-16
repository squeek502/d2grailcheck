#!/usr/bin/lua

local ui = require "lui"
local utils = require "d2grailcheck.utils"
local lfs = require "lfs"
local d2itemreader = require "d2itemreader"
local Data = require('d2grailcheck.data')
local Checker = require('d2grailcheck.checker')
local simpleFormatter = require('d2grailcheck.formats.simple')
local Settings = require('d2grailcheck.gui.settings')
local steps = false
ui.Init()

local win
local versionLabel
local saveDirEntry
local gameDirEntry
local filterCheckboxes = {}

local SETTINGS_FILE = "d2grailcheck.ini"
local settings = Settings.load(SETTINGS_FILE)
print(require('inspect')(settings))
Settings.save(SETTINGS_FILE, settings)

local function folderEntry(cb)
  local function onOpenFolderClicked(button, entry)
    local filename = ui.OpenFolder(win)
    if filename == nil then
      return
    end
    entry:Text(filename)
    if cb then
      cb(button, entry)
    end
  end

  local entry = ui.NewEntry()
  local button = ui.NewButton("Browse..."):OnClicked(onOpenFolderClicked, entry)

  return ui.NewHorizontalBox():Padded(true):Append(entry, true):Append(button, false), entry, button
end

local onSaveDirChanged
local function setGameVersion(version, saveDir)
  versionLabel:Text("Detected Game Version: " .. (version or "none"))
  if saveDir then
    saveDirEntry:Text(saveDir)
  elseif not utils.pathexists(saveDirEntry:Text()) then
    saveDirEntry:Text("")
  end
  onSaveDirChanged()
end

local function onGameDirChanged(entry)
  local text = entry:Text()
  setGameVersion(utils.getDiabloVersionAndSaveDir(text))
end

local function saveFilePassesFilter(filetype)
  for filter, checkbox in pairs(filterCheckboxes) do
    if filter == filetype then
      return checkbox:Checked()
    end
  end
  return false
end

local selectWindow, selectWindowRoot
local fileChooserButton
local fileChooserTypes = { 'character', 'personal', 'shared', 'atma' }
local fileChooserGroups = {}
local fileChooserGroupCheckboxes = {}
local fileChooserGroupChildCounts = {}
for _, filetype in ipairs(fileChooserTypes) do
  fileChooserGroupCheckboxes[filetype] = {}
  fileChooserGroupChildCounts[filetype] = 0
end

local function appendToFileChooserGroup(name, control)
  local group = fileChooserGroups[name]
  group:Append(control)
  fileChooserGroupChildCounts[name] = (fileChooserGroupChildCounts[name] or 0) + 1
  if control.Checked ~= nil then
    table.insert(fileChooserGroupCheckboxes[name], control)
  end
end
local function refreshFileChooserGroup(name, files)
  local group = fileChooserGroups[name]
  for _=1,(fileChooserGroupChildCounts[name] or 0) do
    -- indexes change as things are deleted, so always delete the head
    group:Delete(0)
  end
  fileChooserGroupChildCounts[name] = 0
  fileChooserGroupCheckboxes[name] = {}
  if #files == 0 then
    appendToFileChooserGroup(name, ui.NewLabel("-"))
    --group:Append(ui.NewLabel("None found"))
    return
  end
  for _, file in ipairs(files) do
    local box = ui.NewCheckbox(file.name)
    box:Checked(true)
    appendToFileChooserGroup(name, box)
  end
end
local function refreshFileChooser(saveDir)
  local filesByType = { character={}, personal={}, shared={}, atma={} }
  for file in lfs.dir(saveDir) do
    if file ~= "." and file ~= ".." then
      local ext = utils.extname(file)
      if ext == '.d2s' or ext == '.d2x' or ext == '.sss' then
        local fullpath = utils.pathjoin(saveDir, file)
        local filetype = d2itemreader.getfiletype(fullpath)
        --if saveFilePassesFilter(filetype) then
          table.insert(filesByType[filetype], {name=file, fullpath=fullpath})
        --end
      end
    end
  end
  for name, files in pairs(filesByType) do
    refreshFileChooserGroup(name, files)
  end
  selectWindow:ContentSize(100, 100)
end
local function fileChooserSetCheckedState(state)
  for _, filetype in ipairs(fileChooserTypes) do
    for _, checkbox in ipairs(fileChooserGroupCheckboxes[filetype]) do
      checkbox:Checked(state)
    end
  end
end

function onSaveDirChanged()
  refreshFileChooser(saveDirEntry:Text())
end

local mainvbox = ui.NewVerticalBox():Padded(true)
win = ui.NewWindow("d2grailcheck", 100, 500, false)
  :Margined(true)
  :SetChild(mainvbox)
  --:Resizeable(false)

local function childWindow(title, w, h, hasMenuBar)
  local vbox = ui.NewVerticalBox():Padded(true)
  local child = ui.NewWindow(title, w, h, hasMenuBar):Margined(true):SetChild(vbox)
  return child, vbox
end

do
  local hbox, entry, button = folderEntry(function(_, e)
    onGameDirChanged(e)
  end)
  entry:OnChanged(onGameDirChanged)
  gameDirEntry = entry
  local labelbox = ui.NewHorizontalBox():Padded(true)
  labelbox:Append(ui.NewLabel("Diablo II Game Directory"), true)
  labelbox:Append(ui.NewLabel(""))
  versionLabel = ui.NewLabel("Detected Game Version: ?")
  labelbox:Append(versionLabel)
  mainvbox:Append(labelbox, hbox)
end
mainvbox:Append(ui.NewHorizontalBox():Padded(true))
do
  local hbox, entry, button = folderEntry(onSaveDirChanged)
  saveDirEntry = entry
  saveDirEntry:OnChanged(onSaveDirChanged)
  mainvbox:Append(ui.NewLabel("Diablo II Save Directory"), hbox)
end
mainvbox:Append(ui.NewHorizontalBox():Padded(true))
do
  local group = ui.NewGroup("Files to include"):Margined(true)
  local vbox = ui.NewVerticalBox():Padded(true)

  local grid = ui.NewGrid():Padded(false)
  local function onFileChooserChange()
  end
  filterCheckboxes.character = ui.NewCheckbox("Characters (.d2s)"):Checked(true):OnToggled(onFileChooserChange)
  filterCheckboxes.personal = ui.NewCheckbox("PlugY Personal Stashes (.d2x)"):Checked(true):OnToggled(onFileChooserChange)
  filterCheckboxes.shared = ui.NewCheckbox("PlugY Shared Stashes (.sss)"):Checked(true):OnToggled(onFileChooserChange)
  filterCheckboxes.atma = ui.NewCheckbox("ATMA/GoMule Stashes (.d2x)"):Checked(true):OnToggled(onFileChooserChange)

  grid:Append(filterCheckboxes.character,
    0, 0, 1, 1,
    false, ui.AlignFill, false, ui.AlignFill)
  grid:Append(filterCheckboxes.personal,
    2, 0, 1, 1,
    false, ui.AlignFill, false, ui.AlignFill)
  grid:Append(filterCheckboxes.shared,
    0, 1, 1, 1,
    false, ui.AlignFill, false, ui.AlignFill)
  grid:Append(filterCheckboxes.atma,
    2, 1, 1, 1,
    false, ui.AlignFill, false, ui.AlignFill)
  grid:Append(ui.NewLabel("  "),
    1, 0, 1, 1,
    true, ui.AlignFill, false, ui.AlignFill)
  vbox:Append(grid)

  vbox:Append(ui.NewHorizontalBox():Padded(true))

  local line2 = ui.NewHorizontalBox():Padded(true)
  local specificFilesCheckbox = ui.NewCheckbox("Only Specific Files"):OnToggled(function(e)
    if e:Checked() then
      grid:Disable()
      fileChooserButton:Enable()
    else
      grid:Enable()
      fileChooserButton:Disable()
    end
  end)
  local chosenFilesLabel = ui.NewLabel("")
  selectWindow, selectWindowRoot = childWindow("Select files", 100, 100, false)
  selectWindow:Resizeable(false)
  local function closeSelectWindow()
    selectWindow:Hide()
  end
  selectWindow:OnClosing(closeSelectWindow)
  do
    local selectWindowGrid = ui.NewGrid():Padded(true)
    fileChooserGroups.character = ui.NewVerticalBox()
    fileChooserGroups.personal = ui.NewVerticalBox()
    fileChooserGroups.shared = ui.NewVerticalBox()
    fileChooserGroups.atma = ui.NewVerticalBox()
    local character = ui.NewGroup("Characters"):Margined(true)
    local personal = ui.NewGroup("PlugY Personal Stashes"):Margined(true)
    local shared = ui.NewGroup("PlugY Shared Stashes"):Margined(true)
    local atma = ui.NewGroup("ATMA/GoMule Stashes"):Margined(true)
    selectWindowGrid:Append(character, 0, 0, 1, 1, false, ui.AlignFill, false, ui.AlignFill)
    selectWindowGrid:Append(personal, 1, 0, 1, 1, false, ui.AlignFill, false, ui.AlignFill)
    selectWindowGrid:Append(shared, 0, 1, 1, 1, false, ui.AlignFill, false, ui.AlignFill)
    selectWindowGrid:Append(atma, 1, 1, 1, 1, false, ui.AlignFill, false, ui.AlignFill)
    character:SetChild(fileChooserGroups.character)
    personal:SetChild(fileChooserGroups.personal)
    shared:SetChild(fileChooserGroups.shared)
    atma:SetChild(fileChooserGroups.atma)
    local buttons = ui.NewHorizontalBox():Padded(true)
    do
      local okButton = ui.NewButton("OK"):OnClicked(function()
        closeSelectWindow()
      end)
      local cancelButton = ui.NewButton("Cancel"):OnClicked(closeSelectWindow)
      buttons:Append(okButton, cancelButton)
    end
    local selectButtons = ui.NewHorizontalBox():Padded(true)
    do
      local allButton = ui.NewButton("Select All"):OnClicked(function() fileChooserSetCheckedState(true) end)
      local noneButton = ui.NewButton("Select None"):OnClicked(function() fileChooserSetCheckedState(false) end)
      selectButtons:Append(allButton, noneButton)
    end
    selectWindowGrid:Append(selectButtons, 0, 2, 1, 1, false, ui.AlignStart, false, ui.AlignFill)
    selectWindowGrid:Append(buttons, 1, 2, 1, 1, false, ui.AlignEnd, false, ui.AlignFill)
    selectWindowRoot:Append(selectWindowGrid)
    refreshFileChooser(saveDirEntry:Text())
  end

  fileChooserButton = ui.NewButton("Choose..."):Disable():OnClicked(function()
    selectWindow:Show()
  end)
  line2:Append(specificFilesCheckbox)
  line2:Append(fileChooserButton)
  line2:Append(chosenFilesLabel, true)
  vbox:Append(line2)
  group:SetChild(vbox)
  mainvbox:Append(group)
end
do
  local group = ui.NewGroup("Item types to check"):Margined(true)
  local vbox = ui.NewVerticalBox():Padded(true)

  local line1 = ui.NewHorizontalBox():Padded(true)
  local function onItemFilterChange() end
  local itemFilterCheckboxes = {}
  itemFilterCheckboxes.uniques = ui.NewCheckbox("Uniques"):Checked(true):OnToggled(onItemFilterChange)
  itemFilterCheckboxes.sets = ui.NewCheckbox("Sets"):Checked(true):OnToggled(onItemFilterChange)
  itemFilterCheckboxes.runes = ui.NewCheckbox("Runes"):Checked(true):OnToggled(onItemFilterChange)
  itemFilterCheckboxes.ethuniques = ui.NewCheckbox("Eth Uniques"):Checked(true):OnToggled(onItemFilterChange)
  itemFilterCheckboxes.runewords = ui.NewCheckbox("Runewords"):Checked(true):OnToggled(onItemFilterChange)
  line1:Append(itemFilterCheckboxes.uniques, itemFilterCheckboxes.sets, itemFilterCheckboxes.runes, itemFilterCheckboxes.ethuniques, itemFilterCheckboxes.runewords)
  vbox:Append(line1)

  group:SetChild(vbox)
  mainvbox:Append(group)
end
mainvbox:Append(ui.NewHorizontalBox():Padded(true))
do
  local hbox = ui.NewHorizontalBox():Padded(true)
  local rightCol = ui.NewVerticalBox()
  local mle
  mle = ui.NewMultilineEntry()
  rightCol:Append(ui.NewButton("Save"))
  rightCol:Append(ui.NewButton("Save as..."))
  hbox:Append(mle, true)
  hbox:Append(rightCol)
  mainvbox:Append(hbox, true)
  local checkButton = ui.NewButton("Check"):OnClicked(function()
    local items = assert(utils.getItemsInDirectory(saveDirEntry:Text()))

    local data = Data.new(gameDirEntry:Text())
    local checker = Checker.new(data, items)
    local out = simpleFormatter(checker)
    mle:Text(out)
  end)
  mainvbox:Append(checkButton)
end

win:Show()

if (not steps) then
  ui.Main()
else
  ui.MainSteps()
  while ui.MainStep(true) do
  end
end
