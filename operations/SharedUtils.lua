-- Shared utilities for Simpsons Hit and Run operation scripts.

local Utils = {}

Utils.PathSeparator = package.config:sub(1, 1) or "/"

Utils.Colours = {
    DEFAULT = "default",
    RED = "red",
    GREEN = "green",
    YELLOW = "yellow",
    BLUE = "blue",
    MAGENTA = "magenta",
    CYAN = "cyan",
    GRAY = "gray",
    GREY = "gray"
}

function Utils.ColourPrint(opts)
    opts = opts or {}
    sdk.colour_print({
        colour = opts.colour or Utils.Colours.DEFAULT,
        message = opts.message or "",
        newline = opts.newline ~= false
    })
end

function Utils.Log(colour, message, prefix)
    local PrefixValue = tostring(prefix or "INIT")
    Utils.ColourPrint({
        colour = colour or Utils.Colours.DEFAULT,
        message = string.format("[%s] %s", PrefixValue, tostring(message or ""))
    })
end

function Utils.Trim(value)
    if type(value) ~= "string" then
        return value
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Utils.Normalize(path)
    if path == nil then
        return nil
    end

    local PathValue = path
    if type(PathValue) ~= "string" then
        PathValue = tostring(PathValue)
    end

    if Utils.PathSeparator == "\\" then
        PathValue = PathValue:gsub("/", "\\")
    else
        PathValue = PathValue:gsub("\\", "/")
    end

    PathValue = PathValue:gsub("[/\\]+", Utils.PathSeparator)
    return PathValue
end

function Utils.Join(...)
    return Utils.Normalize(join(...))
end

function Utils.Basename(path)
    return (path and path:match("([^/\\]+)$")) or path
end

function Utils.Dirname(path)
    if not path or path == "" then
        return "."
    end

    local Directory = path:match("(.+)[/\\][^/\\]+$") or path:match("(.+)[/\\]$") or ""
    if Directory == "" then
        if path:match("^%a:[/\\]?$") then
            return path
        end
        return "."
    end

    return Directory
end

function Utils.IsAbsolute(path)
    return sdk.is_absolute(path)
end

function Utils.ResolveInputPath(path)
    local Value = Utils.Trim(path)
    if not Value or Value == "" then
        return nil
    end

    if not Utils.IsAbsolute(Value) then
        Value = Utils.Join(sdk.currentdir(), Value)
    end

    return Utils.Normalize(Value)
end

function Utils.CountFiles(path)
    if not sdk.is_dir(path) then
        return 0
    end

    local Count = 0
    for _, entry in ipairs(sdk.list_dir(path)) do
        local FullPath = Utils.Join(path, entry)
        if FullPath then
            local Attributes = sdk.attributes(FullPath)
            if Attributes and Attributes.mode == "file" then
                Count = Count + 1
            elseif Attributes and Attributes.mode == "directory" then
                Count = Count + Utils.CountFiles(FullPath)
            end
        end
    end

    return Count
end

function Utils.CopyTree(sourcePath, destinationPath, totalCount, state)
    if not sdk.is_dir(sourcePath) then
        return
    end

    sdk.ensure_dir(destinationPath)

    for _, entry in ipairs(sdk.list_dir(sourcePath)) do
        local SourceEntry = Utils.Join(sourcePath, entry)
        local DestinationEntry = Utils.Join(destinationPath, entry)
        local Attributes = SourceEntry and sdk.attributes(SourceEntry) or nil

        if Attributes and Attributes.mode == "directory" then
            if DestinationEntry then
                Utils.CopyTree(SourceEntry, DestinationEntry, totalCount, state)
            end
        elseif Attributes and Attributes.mode == "file" then
            if SourceEntry and DestinationEntry then
                sdk.ensure_dir(Utils.Dirname(DestinationEntry))
                sdk.copy_file(SourceEntry, DestinationEntry, true)
            end

            if state and totalCount then
                state.count = state.count + 1
                local Progress = (totalCount > 0) and ((state.count / totalCount) * 100) or 100
                Utils.ColourPrint({
                    colour = Utils.Colours.YELLOW,
                    message = string.format("Copying... %d/%d files (%.1f%%)", state.count, totalCount, Progress),
                    newline = false
                })
            end
        end
    end
end

return Utils