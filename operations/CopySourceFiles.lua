--- CopySourceFiles.lua
--- Moves or copies the 'simpsons.ini' file and 'scripts' folder from the source 
--- into the processed assets target directory.
---
--- Arguments:
---   --source: The source path containing the files.
---   --target: The target directory where the files should be copied.
---   --move:   Optional flag to move the files instead of copying them.
---   --copy:   Optional flag to explicitly copy the files (default behavior).

---@type SharedUtils
local Utils = import("SharedUtils")

---@class CopySourceFilesOptions
---@field SourcePath string|nil
---@field TargetPath string|nil
---@field Action string

---@param List string[]
---@return CopySourceFilesOptions
local function ParseArgs(List)
    ---@type CopySourceFilesOptions
    local Opts = {
        Action = "copy"
    }
    local I = 1
    while I <= #List do
        local Key = List[I]
        if Key == "--source" and List[I + 1] then
            Opts.SourcePath = List[I + 1]
            I = I + 2
        elseif Key == "--target" and List[I + 1] then
            Opts.TargetPath = List[I + 1]
            I = I + 2
        elseif Key == "--move" then
            Opts.Action = "move"
            I = I + 1
        elseif Key == "--copy" then
            Opts.Action = "copy"
            I = I + 1
        else
            I = I + 1
        end
    end
    return Opts
end

-- Parse command line arguments
---@type CopySourceFilesOptions
local Opts = ParseArgs(argv or {...})
---@type string|nil
local SourcePath = Opts.SourcePath
---@type string|nil
local TargetPath = Opts.TargetPath
local Action = Opts.Action

if not SourcePath or not TargetPath then
    sdk.colour_print({ colour = "red", message = "Error: Missing required arguments --source and --target" })
    error("Missing required arguments")
end

local actionCapitalized = Action == "move" and "Moving" or "Copying"
local actionGerund = Action == "move" and "moving" or "copying"

sdk.colour_print({ colour = "cyan", message = "=== " .. actionCapitalized .. " Source Files ===" })
sdk.colour_print({ colour = "white", message = "  Action: " .. Action })
sdk.colour_print({ colour = "white", message = "  Source: " .. SourcePath })
sdk.colour_print({ colour = "white", message = "  Target: " .. TargetPath })

-- Initialize progress tracking
progress.start(3, actionCapitalized .. " Files")

-- Ensure the target base directory exists
sdk.ensure_dir(TargetPath)

-- Process simpsons.ini File
progress.step(actionCapitalized .. " 'simpsons.ini' file...")
local IniSource = Utils.join(SourcePath, "simpsons.ini")
local IniTarget = Utils.join(TargetPath, "simpsons.ini")

if sdk.path_exists(IniSource) then
    sdk.colour_print({ colour = "white", message = "  Found 'simpsons.ini', " .. actionGerund .. "..." })
    if Action == "move" then
        sdk.rename_file(IniSource, IniTarget, true)
    else
        sdk.copy_file(IniSource, IniTarget, true)
    end
else
    sdk.colour_print({ colour = "yellow", message = "  Warning: 'simpsons.ini' file not found at " .. IniSource })
end

-- Process scripts Folder
progress.step(actionCapitalized .. " 'scripts' folder...")
local ScriptsSource = Utils.join(SourcePath, "scripts")
local ScriptsTarget = Utils.join(TargetPath, "scripts")

if sdk.path_exists(ScriptsSource) then
    sdk.colour_print({ colour = "white", message = "  Found 'scripts', " .. actionGerund .. "..." })
    if Action == "move" then
        sdk.move_dir(ScriptsSource, ScriptsTarget, true)
    else
        sdk.copy_dir(ScriptsSource, ScriptsTarget, true)
    end
else
    sdk.colour_print({ colour = "yellow", message = "  Warning: 'scripts' folder not found at " .. ScriptsSource })
end

-- Finish
progress.step("Finalizing")
sdk.colour_print({ colour = "green", message = "Successfully finished " .. actionGerund .. " source files." })