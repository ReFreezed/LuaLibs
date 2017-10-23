--[[============================================================
--=
--=  LuaData encoding/decoding module v1
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See the bottom of this file)
--=
--=  Encode and decode Lua data types, i.e. numbers and tables etc.
--=
--=  TODO:
--=  - Check performace.
--=
--==============================================================



	Basic usage
	----------------------------------------------------------------

	local luaData = require("luaData")

	local data = {

		"Hello, world!",
		3.14,
		math.huge, -- Special numbers works fine.

		myTable = {"Foo"},
		[{}] = "asdf", -- Weird fields with tables (or any other type) as keys works fine too.

	}
	data.self = data.myTable -- Circular references also works as expected.

	print(data.myTable[1]) -- "Foo"

	local encodedDataString = luaData.encode(data)

	local decodedData = luaData.decode(encodedDataString)
	print(decodedData.myTable[1]) -- "Foo"



	Functions
	----------------------------------------------------------------

	encode
	decode



--============================================================]]

local luaData = {}

local byteCodes = {

	['nil']        = 0x0,

	['false']      = 0x1,
	['true']       = 0x2,

	['nan']        = 0x3,

	['+inf']       = 0x4,
	['-inf']       = 0x5,

	['intdec']     = 0x6, -- Null-terminated integer "string".
	['inthex']     = 0x7,

	['float']      = 0x8, -- Null-terminated float "string".

	['string']     = 0xA, -- Null-terminated escaped string.

	['tableempty'] = 0x10,
	['tablekv']    = 0x11, -- Key-value pair.
	['tablevalue'] = 0x12, -- Array item.

	['tableref']   = 0x13, -- Reference to previous table.

	-- Reserved:

	-- N+1-byte signed int.
	['int0']=0x20, ['int1']=0x21, ['int2']=0x22, ['int3']=0x23,
	['int4']=0x24, ['int5']=0x25, ['int6']=0x26, ['int7']=0x27,
	['int8']=0x28, ['int9']=0x29, ['intA']=0x2A, ['intB']=0x2B,
	['intC']=0x2C, ['intD']=0x2D, ['intE']=0x2E, ['intF']=0x2F,

	-- N+1-byte signed float.
	['float0']=0x30, ['float1']=0x31, ['float2']=0x32, ['float3']=0x33,
	['float4']=0x34, ['float5']=0x35, ['float6']=0x36, ['float7']=0x37,
	['float8']=0x38, ['float9']=0x39, ['floatA']=0x3A, ['floatB']=0x3B,
	['floatC']=0x3C, ['floatD']=0x3D, ['floatE']=0x3E, ['floatF']=0x3F,

	-- String with N+1 bytes of length data.
	['string0']=0x40, ['string1']=0x41, ['string2']=0x42, ['string3']=0x43,
	['string4']=0x44, ['string5']=0x45, ['string6']=0x46, ['string7']=0x47,
	['string8']=0x48, ['string9']=0x49, ['stringA']=0x4A, ['stringB']=0x4B,
	['stringC']=0x4C, ['stringD']=0x4D, ['stringE']=0x4E, ['stringF']=0x4F,

}

--==============================================================
--==============================================================
--==============================================================
local F
local insertByteCode
local printAtDepth

F = string.format

function insertByteCode(buffer, name)
	local code = byteCodes[name]
		or error('Bad byte code name "'..name..'".')
	table.insert(buffer, string.char(code))
end

function printAtDepth(depth, s, ...)
	print('[LuaData] '..('    '):rep(depth)..s, ...)
end

--==============================================================
--==============================================================
--==============================================================

local function encodeValue(buffer, data, tables, options, depth)
	local dataType = type(data)
	-- printAtDepth(depth, 'dataType', dataType)

	if dataType == 'nil' then
		insertByteCode(buffer, 'nil')
		-- printAtDepth(depth, 'nil:', buffer[#buffer])

	elseif dataType == 'boolean' then
		insertByteCode(buffer, (data and 'true' or 'false'))
		-- printAtDepth(depth, 'bool:', buffer[#buffer])

	elseif dataType == 'number' then

		if data ~= data then
			insertByteCode(buffer, 'nan')
			-- printAtDepth(depth, 'nan:', buffer[#buffer])

		elseif data == math.huge then
			insertByteCode(buffer, '+inf')
			-- printAtDepth(depth, '+inf:', buffer[#buffer])

		elseif data == -math.huge then
			insertByteCode(buffer, '-inf')
			-- printAtDepth(depth, '-inf:', buffer[#buffer])

		elseif data == math.floor(data) then
			-- @Memory: Store ints in N bytes instead of as strings.
			local dec = F('%d', data)
			local hex = F('%x', data)
			if #hex < #dec then
				insertByteCode(buffer, 'inthex')
				table.insert(buffer, hex)
				-- printAtDepth(depth, 'inthex:', buffer[#buffer])
				table.insert(buffer, '\0') -- Null-terminated number.
			else
				insertByteCode(buffer, 'intdec')
				table.insert(buffer, dec)
				-- printAtDepth(depth, 'intdec:', buffer[#buffer])
				table.insert(buffer, '\0') -- Null-terminated number.
			end

		else
			insertByteCode(buffer, 'float')
			table.insert(buffer, F('%.'..(options.floatPrecision or 6)..'g', data))
			-- printAtDepth(depth, 'float:', buffer[#buffer])
			table.insert(buffer, '\0') -- Null-terminated number.

		end

	elseif dataType == 'string' then
		-- @Memory @Speed: Store shorter strings with length of string first and the unescaped string after.
		local escapedStr = data:gsub('[%z\\]', '\\%0') -- Escape nulls and escape characters.
		insertByteCode(buffer, 'string')
		table.insert(buffer, escapedStr)
		-- printAtDepth(depth, 'string:', '"'..buffer[#buffer]..'"')
		table.insert(buffer, '\0') -- Null-terminated string.

	elseif dataType == 'table' then

		-- Detect circular reference.
		local tableId = tables[data]
		if tableId then
			insertByteCode(buffer, 'tableref')
			-- printAtDepth(depth, 'tableref:', tableId)
			local ok, err = encodeValue(buffer, tableId, tables, options, depth+1)
			if not ok then  return false, err  end
			return true
		end

		-- Save table so we can detect circular references later.
		tableId = tables.lastId+1
		tables.lastId = tableId
		tables[data] = tableId
		-- printAtDepth(depth, tableId..': {')

		-- Empty tables gets special treatment.
		if next(data) == nil then
			insertByteCode(buffer, 'tableempty')
			-- printAtDepth(depth, 'tableempty')
			-- Note: No need to terminate empty tables.
			return true
		end

		-- Encode value sequence.
		local i, indices = 0, {}
		while true do

			i = i+1
			if data[i] == nil then
				i = i+1
				if data[i] == nil then
					break
				else
					insertByteCode(buffer, 'tablevalue')
					-- printAtDepth(depth, '  seqvalue:')
					local ok, err = encodeValue(buffer, nil, tables, options, depth+1)
					if not ok then  return false, err  end
				end
			end

			insertByteCode(buffer, 'tablevalue')
			-- printAtDepth(depth, '  value:')
			local ok, err = encodeValue(buffer, data[i], tables, options, depth+1)
			if not ok then  return false, err  end

			indices[i] = true
		end

		-- Encode other attributes.
		for k, v in pairs(data) do
			if not indices[k] then
				insertByteCode(buffer, 'tablekv')
				-- printAtDepth(depth, '  kv_key:')
				local ok, err = encodeValue(buffer, k, tables, options, depth+1)
				-- printAtDepth(depth, '  kv_value:')
				local ok, err = encodeValue(buffer, v, tables, options, depth+1)
			end
		end

		table.insert(buffer, '\0') -- Null-terminated table.
		-- printAtDepth(depth, '}')

	else
		return false, F('Cannot encode value of type %q. (The value is %q.)', dataType, data)

	end
	return true
end

-- dataString, errorMessage = encode( data [, options ] )
-- options = {
--    floatPrecision = 6,
-- }
function luaData.encode(data, options)
	options = (options or {})

	local buffer = {}
	table.insert(buffer, string.char(1)) -- Version number.

	local ok, err = encodeValue(buffer, data, {lastId=0}, options, 0)
	if not ok then
		return nil, err
	end

	return table.concat(buffer)
end

--==============================================================
--==============================================================
--==============================================================

local function decodeValue_v1(dataStr, ptr, tables, depth)

	local code = dataStr:byte(ptr)
	if not code then
		return false, F('Unexpected end of data (at position %d).', ptr)
	end

	if code == byteCodes['nil'] then
		ptr = ptr+1
		-- printAtDepth(depth, 'nil')
		return true, nil, ptr

	elseif code == byteCodes['false'] then
		ptr = ptr+1
		-- printAtDepth(depth, 'bool false')
		return true, false, ptr
	elseif code == byteCodes['true'] then
		ptr = ptr+1
		-- printAtDepth(depth, 'bool true')
		return true, true, ptr

	elseif code == byteCodes['nan'] then
		ptr = ptr+1
		-- printAtDepth(depth, 'number nan')
		return true, 0/0, ptr

	elseif code == byteCodes['+inf'] then
		ptr = ptr+1
		-- printAtDepth(depth, 'number +inf')
		return true, math.huge, ptr
	elseif code == byteCodes['-inf'] then
		-- printAtDepth(depth, 'number -inf')
		return true, -math.huge, ptr

	elseif code == byteCodes['intdec'] then
		ptr = ptr+1

		local nStr = dataStr:match('^(.-)%z', ptr)
		if (not nStr or nStr == '') then
			return false, F('Missing decimal number data at position %d', ptr)
		end

		local n = tonumber(nStr)
		if not n then
			return false, F('Could not parse decimal number at position %d', ptr)
		end

		ptr = ptr+#nStr+1
		-- printAtDepth(depth, 'number intdec', n)
		return true, n, ptr

	elseif code == byteCodes['inthex'] then
		ptr = ptr+1

		local nStr = dataStr:match('^(.-)%z', ptr)
		if (not nStr or nStr == '') then
			return false, F('Missing hexadecimal number data at position %d', ptr)
		end

		local n = tonumber(nStr, 16)
		if not n then
			return false, F('Could not parse hexadecimal number at position %d', ptr)
		end

		ptr = ptr+#nStr+1
		-- printAtDepth(depth, 'number inthex', n)
		return true, n, ptr

	elseif code == byteCodes['float'] then
		ptr = ptr+1

		local nStr = dataStr:match('^(.-)%z', ptr)
		if (not nStr or nStr == '') then
			return false, F('Missing float number data at position %d', ptr)
		end

		local n = tonumber(nStr)
		if not n then
			return false, F('Could not parse float number at position %d', ptr)
		end

		ptr = ptr+#nStr+1
		-- printAtDepth(depth, 'number float', n)
		return true, n, ptr

	elseif code == byteCodes['string'] then
		ptr = ptr+1

		local startPtr = ptr
		while true do
			local c = dataStr:sub(ptr, ptr)
			if c == '' then
				return false, F('Reached end of data without getting a string terminator (at position %d).', ptr)
			elseif c == '\\' then
				ptr = ptr+2
			elseif c == '\0' then
				ptr = ptr+1
				break
			else
				ptr = ptr+1
			end
		end

		local escapedStr = dataStr:sub(startPtr, ptr-2)
		local str = escapedStr:gsub('\\(.)', '%1')

		-- printAtDepth(depth, 'string', '"'..str..'"')
		return true, str, ptr

	elseif (code == byteCodes['tableempty'] or code == byteCodes['tablekv'] or code == byteCodes['tablevalue']) then
		-- printAtDepth(depth, 'table')

		local t = {}

		-- Save table for later circular references.
		local tableId = tables.lastId+1
		tables.lastId = tableId
		tables[tableId] = t

		-- Empty tables gets special treatment.
		if code == byteCodes['tableempty'] then
			ptr = ptr+1
			return true, t, ptr
		end

		local i = 0
		local ok, kOrErr, vOrErr
		while true do

			local code = dataStr:byte(ptr)

			if not code then
				return false, F('Reached end of data without getting a table terminator (at position %d).', ptr)

			elseif code == byteCodes['tablevalue'] then
				ptr = ptr+1

				-- printAtDepth(depth, '  value:')
				ok, vOrErr, ptr = decodeValue_v1(dataStr, ptr, tables, depth+1)
				if not ok then  return false, vOrErr  end

				i = i+1
				t[i] = vOrErr

			elseif code == byteCodes['tablekv'] then
				ptr = ptr+1

				-- printAtDepth(depth, '  kv_key:')
				ok, kOrErr, ptr = decodeValue_v1(dataStr, ptr, tables, depth+1)
				if not ok then  return false, kOrErr  end
				if kOrErr == nil then
					return false, F('Table key is nil at position %d.', ptr)
				end

				-- printAtDepth(depth, '  kv_value:')
				ok, vOrErr, ptr = decodeValue_v1(dataStr, ptr, tables, depth+1)
				if not ok then  return false, vOrErr  end

				t[kOrErr] = vOrErr

			elseif code == 0 then
				ptr = ptr+1
				break

			else
				return false, F('Bad table field byte code %d at position %d.', code, ptr)
			end

		end

		return true, t, ptr

	elseif code == byteCodes['tableref'] then
		ptr = ptr+1

		local ok, tableIdOrErr
		ok, tableIdOrErr, ptr = decodeValue_v1(dataStr, ptr, tables, depth+1)
		if not ok then  return false, tableIdOrErr  end

		local t = tables[tableIdOrErr]
		if not t then
			return false, F('Encountered a table reference to a non-existent table at position %d.', ptr)
		end

		return true, t, ptr

	end
	return false, F('Unknown byte code %d.', code)
end

-- success, data = decode( dataString )
-- success, errorMessage = decode( dataString )
function luaData.decode(dataStr)

	if type(dataStr) ~= 'string' then
		return false, F('Expected a string argument but got %s instead.', type(dataStr))
	end

	if #dataStr == 0 then
		return false, 'No data.'
	end

	local ptr = 1

	local version = dataStr:byte(ptr)
	if version ~= 1 then
		return false, F('Unsupported data version number %d.', version)
	end
	ptr = ptr+1

	local ok, data, ptr = decodeValue_v1(dataStr, ptr, {lastId=0}, 0)
	return ok, data
end

--==============================================================
--==============================================================
--==============================================================

return luaData

--==============================================================
--=
--=  MIT License
--=
--=  Copyright © 2017 Marcus 'ReFreezed' Thunström
--=
--=  Permission is hereby granted, free of charge, to any person obtaining a copy
--=  of this software and associated documentation files (the "Software"), to deal
--=  in the Software without restriction, including without limitation the rights
--=  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--=  copies of the Software, and to permit persons to whom the Software is
--=  furnished to do so, subject to the following conditions:
--=
--=  The above copyright notice and this permission notice shall be included in all
--=  copies or substantial portions of the Software.
--=
--=  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--=  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--=  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--=  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--=  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--=  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--=  SOFTWARE.
--=
--==============================================================
