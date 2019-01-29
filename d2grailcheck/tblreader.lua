local tblreader = {}

local function decode_uint8(str, ofs)
	ofs = ofs or 0
	return string.byte(str, ofs + 1)
end

local function decode_uint16(str, ofs)
	ofs = ofs or 0
	local a, b = string.byte(str, ofs + 1, ofs + 2)
	return a + b * 0x100
end

local function decode_uint32(str, ofs)
	ofs = ofs or 0
	local a, b, c, d = string.byte(str, ofs + 1, ofs + 4)
	return a + b * 0x100 + c * 0x10000 + d * 0x1000000
end

local function decode_string(str, ofs)
	ofs = ofs or 0
	local curOfs = ofs
	while string.byte(str, curOfs+1) ~= 0 do
		curOfs = curOfs+1
	end
	return str:sub(ofs+1, curOfs)
end

function tblreader.read(...)
	local tbl = {}
	for _, data in ipairs({...}) do
		local idCount = decode_uint16(data, 2)
		local entryCount = decode_uint16(data, 4)
		local firstStringOffset = decode_uint32(data, 9)
		local lastStringEnd = decode_uint32(data, 17)
		local firstEntryOffset = 21 + 2*idCount
		for i=1,entryCount do
			local entryOffset = firstEntryOffset + (i-1)*17
			local nameOffset = decode_uint32(data, entryOffset+7)
			local stringOffset = decode_uint32(data, entryOffset+11)
			local stringLength = decode_uint16(data, entryOffset+15)
			if nameOffset > 0 and stringOffset > 0 and stringLength > 0 then
				local name = decode_string(data, nameOffset)
				local str = data:sub(stringOffset+1, stringOffset+stringLength-1)
				assert(#str == stringLength-1, (#str) .. " ~= " .. (stringLength-1))
				tbl[name] = str
			end
		end
	end
	return tbl
end

function tblreader.readfiles(...)
	local datum = {}
	for _, filepath in ipairs({...}) do
		local data = assert(io.open(filepath, "rb")):read("*a")
		table.insert(datum, data)
	end
	return tblreader.read(unpack(datum))
end

return tblreader