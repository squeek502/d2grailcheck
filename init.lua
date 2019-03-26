local utils = require('d2grailcheck.utils')
local Data = require('d2grailcheck.data')
local Checker = require('d2grailcheck.checker')
local argparse = require('d2grailcheck.argparse')

local formats = {
  ["simple"] = require('d2grailcheck.formats.simple'),
  ["d2-holy-grail"] = require('d2grailcheck.formats.d2-holy-grail'),
}
local DEFAULT_GAME_DIR = {
  "C:/Program Files (x86)/Diablo II/",
  "C:/Program Files/Diablo II/"
}

local parser = argparse()
parser:option('-g --game-dir', "Path to Diablo II game directory", DEFAULT_GAME_DIR)
  :argname('<path>')
  :convert(function(path)
    if not utils.pathexists(path) then return nil, "Game directory not found: "..path end
    return path
  end)
parser:option('-s --save-dir', "Path to Diablo II save directory")
  :argname('<path>')
  :convert(function(path)
    if not utils.pathexists(path) then return nil, "Save directory not found: "..path end
    return path
  end)
parser:require_command(false):command_target('format')
local simpleCmd = parser:command('simple')
local dhgCmd = parser:command('d2-holy-grail dhg')
dhgCmd:argument("username")
dhgCmd:argument("password")
local args = parser:parse()

-- Get/validate format
if not args.format then
  args.format = "simple"
end

-- Get/validate game and save directories
if type(args.game_dir) == "table" then
  for _, dir in ipairs(args.game_dir) do
    if utils.pathexists(dir) then
      args.game_dir = dir
      break
    end
  end
end
if type(args.game_dir) ~= "string" then
  parser:error("Game directory not found, tried:\n "..table.concat(args.game_dir, "\n "))
end
print("Game Directory: "..args.game_dir)
if not args.save_dir then
  local dir = utils.guessSaveDir(args.game_dir)
  assert(dir, "Failed to guess save directory from game directory")
  assert(utils.pathexists(dir), "Guessed save directory does not exist: "..dir)
  args.save_dir = dir
end
print("Save Directory: "..args.save_dir)

-- Main logic
print("\nLoading items...")
local items = assert(utils.getItemsInDirectory(args.save_dir))
print("Loading data...")
local data = Data.new(args.game_dir)
print("Checking grail...")
local checker = Checker.new(data, items, args)
print("Formatting...")
local formatter = formats[args.format]
local output = formatter(checker)
print("")
print(output)
