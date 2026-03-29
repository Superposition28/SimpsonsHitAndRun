-- RemakeEngine Module Init (Simpsons Hit and Run)
-- Keeps setup minimal by managing only placeholders.SourcePath.

local Utils = import("SharedUtils")
local Colours = Utils.Colours

local initutil = import("init/utils")


local function main()
	local ModuleDir = Utils.Dirname(script_dir)
	local ConfigPath = Utils.join(ModuleDir, "config.toml")
	local LocalSourceRoot = Utils.join(ModuleDir, "Source")

	local Placeholders = initutil.EnsureConfig(ConfigPath)

	local SourcePath = nil
	if type(Placeholders.SourcePath) == "string" and Placeholders.SourcePath ~= "" then
		local ConfiguredPath = Utils.Normalize(Placeholders.SourcePath)
		if sdk.is_dir(ConfiguredPath) then
			SourcePath = ConfiguredPath
			Utils.Log(Colours.GREEN, "Using existing SourcePath from config.")
		else
			Utils.Log(Colours.YELLOW, "Configured SourcePath is invalid. Prompting for a new path.")
		end
	end

	if not SourcePath then
		local InputPath = initutil.PromptForSourcePath()
		if not InputPath then
			Utils.Log(Colours.RED, "Initialization canceled: no valid source path provided.")
			return false
		end

		local EffectivePath = initutil.ResolveEffectiveSourcePath(InputPath, LocalSourceRoot)
		if not EffectivePath then
			return false
		end

		SourcePath = EffectivePath
	end

	Placeholders.SourcePath = SourcePath
	initutil.WritePlaceholders(ConfigPath, Placeholders)
	Utils.Log(Colours.GREEN, "Saved placeholders.SourcePath = " .. SourcePath)

	return true
end

do
	local Ok, Result = pcall(main)
	if not Ok then
		Utils.Log(Colours.RED, "Initialization failed: " .. tostring(Result))
		os.exit(1)
	end

	if Result == false then
		os.exit(1)
	end
end
