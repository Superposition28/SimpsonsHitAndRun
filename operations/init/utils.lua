
local Utils = import("../SharedUtils")
local Colours = Utils.Colours
local M = {}


function M.ReadPlaceholders(configPath)
	local Document = sdk.toml_read_file(configPath)
	if type(Document) ~= "table" then
		return {}
	end

	local Placeholders = Document["placeholders"]
	if type(Placeholders) ~= "table" then
		return {}
	end

	if Placeholders[1] and type(Placeholders[1]) == "table" then
		return Placeholders[1]
	end

	return Placeholders
end

function M.WritePlaceholders(configPath, placeholders)
	local Document = {
		placeholders = { placeholders }
	}
	sdk.toml_write_file(configPath, Document)
end

function M.EnsureConfig(configPath)
	if not sdk.path_exists(configPath) then
		Utils.Log(Colours.YELLOW, "Config not found. Creating: " .. configPath)
		M.WritePlaceholders(configPath, { SourcePath = "" })
	end

	local Placeholders = M.ReadPlaceholders(configPath)
	if type(Placeholders.SourcePath) ~= "string" then
		Placeholders.SourcePath = ""
		M.WritePlaceholders(configPath, Placeholders)
	end

	return Placeholders
end

function M.StartsWithIgnoreCase(path, prefix)
	if type(path) ~= "string" or type(prefix) ~= "string" then
		return false
	end

	if #prefix > #path then
		return false
	end

	return path:sub(1, #prefix):lower() == prefix:lower()
end

function M.PromptForSourcePath()
	while true do
		local Input = prompt("Enter the path to your game files folder (leave blank to cancel):", "shr_source_path")
		local PathValue = Utils.ResolveInputPath(Input)

		if not PathValue or PathValue == "" then
			return nil
		end

		if sdk.is_dir(PathValue) then
			return PathValue
		end

		Utils.Log(Colours.RED, "Path is not a directory. Please try again.")
	end
end

function M.CopyToLocalSource(sourcePath, localSourceRoot)
	local SourceName = Utils.Basename(sourcePath)
	local DestinationPath = Utils.Join(localSourceRoot, SourceName)

	sdk.ensure_dir(localSourceRoot)

	if sdk.copy_dir then
		local Ok = sdk.copy_dir(sourcePath, DestinationPath, true)
		if Ok then
			return DestinationPath
		end
		Utils.Log(Colours.YELLOW, "sdk.copy_dir failed. Falling back to recursive file copy.")
	end

	local Total = Utils.CountFiles(sourcePath)
	local State = { count = 0 }
	Utils.CopyTree(sourcePath, DestinationPath, Total, State)

	if io and type(io.write) == "function" then
		io.write("\n")
	end

	return DestinationPath
end

function M.MoveToLocalSource(sourcePath, localSourceRoot)
	if not sdk.move_dir then
		Utils.Log(Colours.RED, "Move is not supported in this runtime.")
		return nil
	end

	local SourceName = Utils.Basename(sourcePath)
	local DestinationPath = Utils.Join(localSourceRoot, SourceName)
	sdk.ensure_dir(localSourceRoot)

	local Ok = sdk.move_dir(sourcePath, DestinationPath, true)
	if not Ok then
		Utils.Log(Colours.RED, "Move failed. Please check permissions and try again.")
		return nil
	end

	return DestinationPath
end

function M.PromptForWritableMode()
	local PromptMessage = table.concat({
		"Choose how to use source files:",
		"1) Copy to module Source folder (recommended)",
		"2) Move to module Source folder",
		"3) Use source path as is",
		"",
		"Enter choice (1, 2, or 3):"
	}, "\n")

	while true do
		local Choice = Utils.Trim(prompt(PromptMessage, "shr_source_mode") or "")
		if Choice == "1" or Choice == "2" or Choice == "3" then
			return Choice
		end
		Utils.Log(Colours.YELLOW, "Invalid choice. Please enter 1, 2, or 3.")
	end
end

function M.ResolveEffectiveSourcePath(sourcePath, localSourceRoot)
	local NormalizedSource = Utils.Normalize(sourcePath)
	local NormalizedLocalRoot = Utils.Normalize(localSourceRoot)

	if M.StartsWithIgnoreCase(NormalizedSource, NormalizedLocalRoot) then
		Utils.Log(Colours.GREEN, "Source already inside module Source folder. Using as is.")
		return NormalizedSource
	end

	local IsWritable = true
	if sdk and sdk.is_writable then
		IsWritable = sdk.is_writable(NormalizedSource)
	end

	if not IsWritable then
		Utils.Log(Colours.YELLOW, "Source is read-only. Auto-selecting Copy.")
		return M.CopyToLocalSource(NormalizedSource, NormalizedLocalRoot)
	end

	local Choice = M.PromptForWritableMode()
	if Choice == "1" then
		return M.CopyToLocalSource(NormalizedSource, NormalizedLocalRoot)
	end

	if Choice == "2" then
		return M.MoveToLocalSource(NormalizedSource, NormalizedLocalRoot)
	end

	return NormalizedSource
end

return M
