-- Converts Radical Engine binary .typ files into readable JSON.
-- Uses the engine Lua API and shared Simpson's Hit & Run operation helpers.

local Utils = import("../SharedUtils")
local Colours = Utils.Colours

---@class BinaryReader
---@field data string
---@field pos integer
---@field length integer
local BinaryReader = {}
BinaryReader.__index = BinaryReader

---@param data string
---@return BinaryReader
function BinaryReader.new(data)
	local self = setmetatable({}, BinaryReader)
	self.data = data or ""
	self.pos = 1
	self.length = #self.data
	return self
end

---@param value string
---@return string
local function CleanBinaryString(value)
	if value == nil or value == "" then
		return ""
	end

	local CleanEnd = #value
	for Index = 1, #value do
		local ByteValue = string.byte(value, Index)
		if ByteValue == 0 or ByteValue == 253 then
			CleanEnd = Index - 1
			break
		end
	end

	if CleanEnd <= 0 then
		return ""
	end

	return string.sub(value, 1, CleanEnd)
end

---@return integer
function BinaryReader:ReadUInt32()
	if self.pos + 3 > self.length then
		self.pos = self.length + 1
		return 0
	end

	local B1, B2, B3, B4 = string.byte(self.data, self.pos, self.pos + 3)
	self.pos = self.pos + 4

	if not B4 then
		return 0
	end

	return B1 + (B2 * 256) + (B3 * 65536) + (B4 * 16777216)
end

---@return string
function BinaryReader:ReadAlignedString()
	local Length = self:ReadUInt32()
	if Length <= 0 or self.pos + Length - 1 > self.length then
		return ""
	end

	local RawValue = string.sub(self.data, self.pos, self.pos + Length - 1)
	self.pos = self.pos + Length

	return CleanBinaryString(RawValue)
end

---@return boolean
function BinaryReader:EOF()
	return self.pos > self.length
end

---@param Reader BinaryReader
---@param MethodCount integer
---@return table<integer, table<string, any>>
local function ReadMethods(Reader, MethodCount)
	local Methods = {}
	local SafeCount = math.max(MethodCount or 0, 0)

	if SafeCount > 1000 then
		SafeCount = 0
	end

	for _ = 1, SafeCount do
		if Reader:EOF() then
			break
		end

		local MethodMarker = Reader:ReadUInt32()
		if MethodMarker ~= 0x41 then
			break
		end

		local MethodName = Reader:ReadAlignedString()
		local ParameterCount = Reader:ReadUInt32()

		-- Skip metadata fields that are not currently surfaced by the demo parser.
		Reader:ReadUInt32()
		Reader:ReadUInt32()

		local ReturnType = Reader:ReadAlignedString()
		local Parameters = {}

		for _ = 1, ParameterCount do
			if Reader:EOF() then
				break
			end

			local ParameterMarker = Reader:ReadUInt32()
			if ParameterMarker == 0x41 or ParameterMarker == 0x0C then
				table.insert(Parameters, Reader:ReadAlignedString())
			end
		end

		table.insert(Methods, {
			Name = MethodName,
			ReturnType = ReturnType,
			Parameters = Parameters
		})
	end

	return Methods
end

local InputArgument = argv[1]
local OutputArgument = argv[2]

if not InputArgument or not OutputArgument then
	error("Missing arguments. Usage: typ2json <input.typ> <output.json>")
	return
end

local InputPath = Utils.ResolveInputPath(InputArgument)
local OutputPath = Utils.ResolveInputPath(OutputArgument)

if not InputPath then
	error("Failed to resolve input path: " .. tostring(InputArgument))
	return
end

if not OutputPath then
	error("Failed to resolve output path: " .. tostring(OutputArgument))
	return
end

if not sdk.is_file(InputPath) then
	error("Input file does not exist: " .. InputPath)
	return
end

Utils.Log(Colours.CYAN, "Reading TYP file: " .. InputPath, "TYP")
local Progress = progress.start(4, "Converting TYP to JSON")

local InputFile, OpenError = io.open(InputPath, "rb")
if not InputFile then
	error("Failed to open input file: " .. InputPath .. (OpenError and (" (" .. tostring(OpenError) .. ")") or ""))
	return
end

local BinaryData = InputFile:read("*all") or ""
InputFile:close()
Progress:Update(1, "Loaded binary data")

local Reader = BinaryReader.new(BinaryData)
local ParsedData = {
	Source = Utils.Basename(InputPath),
	Interfaces = {}
}

while not Reader:EOF() do
	local BlockType = Reader:ReadUInt32()

	if BlockType == 0x43 or BlockType == 0x40 then
		-- Some files begin with an interface block header that must be stepped past first.
		if BlockType == 0x43 then
			Reader:ReadUInt32()
			BlockType = Reader:ReadUInt32()
		end

		local InterfaceName = Reader:ReadAlignedString()
		local DeclaredMethodCount = Reader:ReadUInt32()
		local InheritedMethodCount = Reader:ReadUInt32()
		local MethodCount = math.max(DeclaredMethodCount, InheritedMethodCount)

		local InterfaceEntry = {
			Name = InterfaceName,
			DeclaredMethodCount = DeclaredMethodCount,
			InheritedMethodCount = InheritedMethodCount,
			Methods = ReadMethods(Reader, MethodCount)
		}

		table.insert(ParsedData.Interfaces, InterfaceEntry)
	else
		-- Advance cautiously if the block does not match the expected RTTI layout.
		Reader.pos = math.min(Reader.length + 1, Reader.pos + 4)
	end
end

Progress:Update(1, "Parsed type metadata")

local JsonOutput = sdk.text.json.encode(ParsedData, { indent = true })
Progress:Update(1, "Encoded JSON output")

local OutputDirectory = Utils.Dirname(OutputPath)
if OutputDirectory and OutputDirectory ~= "." then
	sdk.ensure_dir(OutputDirectory)
end

local WriteSuccess = sdk.write_file(OutputPath, JsonOutput)
if not WriteSuccess then
	error("Failed to write output JSON to: " .. OutputPath)
	return
end

Progress:Complete()
Utils.Log(Colours.GREEN, "Successfully exported JSON to: " .. OutputPath, "TYP")
