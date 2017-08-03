--[[============================================================
--=
--=  CSV (Comma Separated Values) module
--=
--=-------------------------------------------------------------
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

	parse
	parseWithHeader
	processColumns
	processFields

--============================================================]]



local insert, remove = table.insert, table.remove
local gsub, match, sub = string.gsub, string.match, string.sub

local csv = {}



--==============================================================
--==============================================================
--==============================================================



--[[
	csvTable = parse( csvString )

	Example:
	-- Parse a CSV string into a Lua table
	local csvString = "1,hello\n2,bye"
	local csvTable = csv.parse(csvString) -- { {"1","hello"}, {"2","bye"} }

]]
function csv.parse(s)
	s = gsub(s, '\r\n?', '\n')
	local pos, fields = 1, {}
	local lines = {fields}
	while true do
		local char = sub(s, pos, pos)

		-- No data
		if (char == '') then
			break

		-- Quoted value
		elseif (char == '"') then
			pos = pos+1
			local startPos = pos
			local endPos
			while true do
				local fieldChar = sub(s, pos, pos)
				if (fieldChar == '"') then
					-- Double quote (single escaped quote)
					if (sub(s, pos+1, pos+1) == '"') then
						pos = pos+2
					-- End of field
					else
						endPos = pos-1
						pos = pos+1
						break
					end
				elseif (fieldChar == '') then
					error('quoted field has no end')
				else
					pos = pos+1
				end
			end
			local endChar = sub(s, pos, pos)
			local field = gsub(sub(s, startPos, endPos), '""', '"')
			insert(fields, field)
			-- More fields after
			if (endChar == ',') then
				pos = pos+1
			-- End of line
			elseif (endChar == '\n') then
				fields = {}
				insert(lines, fields)
				pos = pos+1
			-- End of data
			elseif (endChar == '') then
				break
			else
				error('invalid endChar') -- we should never get here
			end

		-- Unquoted value
		else
			local startPos = pos
			local endPos, endChar = match(s, '()([,\n])', pos)
			endPos, endChar = (endPos or #s+1)-1, (endChar or '')
			local field = sub(s, startPos, endPos)
			insert(fields, field)
			-- More fields after
			if (endChar == ',') then
				pos = endPos+2
			-- End of line
			elseif (endChar == '\n') then
				fields = {}
				insert(lines, fields)
				pos = endPos+2
			-- End of data
			elseif (endChar == '') then
				break
			else
				error('invalid endChar') -- we should never get here
			end

		end
	end
	local len = #lines
	if (len > 0 and not lines[len][1]) then
		remove(lines)
	end
	return lines
end



--[[
	csvTable = parseWithHeader( csvString )

	Example:
	-- Parse a CSV string where the first row contains the names of the columns
	local csvString = "index,word\n1,hello\n2,bye"
	local csvTable = csv.parseWithHeader(csvString) -- { {index="1",word="hello"}, {index="2",word="bye"} }

]]
function csv.parseWithHeader(s)

	-- Parse CSV data string
	local lines = csv.parse(s)

	-- Get header row
	local header = lines[1]
	lines[1] = nil
	if (not header) then
		return lines
	end

	-- Check duplicate field names
	local fieldNameSet = {}
	for _, fieldName in ipairs(header) do
		if (fieldNameSet[fieldName]) then
			error('duplicate field name "'..fieldName..'"')
		end
		fieldNameSet[fieldName] = true
	end

	-- Convert table sequences into key/value pairs
	for row = 2, #lines do
		local fields = lines[row]
		for col, field in ipairs(fields) do
			fields[header[col]] = (field or '')
			fields[col] = nil
		end
		lines[row-1] = fields
		lines[row] = nil
	end

	return lines
end



--[[
	csvTable = processColumns( csvTable, columnProcessors )

	Note: Changes csvTable!

	Example:
	-- Parse a CSV string and convert the second column into numbers
	local csvString = "foo,4\nbar,9"
	local csvTable = csv.parse(csvString) -- { {"foo","4"}, {"bar","9"} }
	csv.processColumns(csvTable, {[2]=tonumber}) -- { {"foo",4}, {"bar",9} }

]]
function csv.processColumns(lines, processors)
	for _, fields in ipairs(lines) do
		for colOrFieldName, field in pairs(fields) do
			local processor = processors[colOrFieldName]
			if (processor) then
				fields[colOrFieldName] = processor(field)
			end
		end
	end
	return lines
end



--[[
	csvTable = processFields( csvTable, processor )

	Note: Changes csvTable!

	Example:
	-- Convert all fields on all rows into numbers
	local csvString = "1,2\n3,4"
	local csvTable = csv.parse(csvString) -- { {"1","2"}, {"3","4"} }
	csv.processFields(csvTable, tonumber) -- { {1,2}, {3,4} }

]]
function csv.processFields(lines, processor)
	for _, fields in ipairs(lines) do
		for colOrFieldName, field in pairs(fields) do
			fields[colOrFieldName] = processor(field)
		end
	end
	return lines
end



--==============================================================
--==============================================================
--==============================================================

return csv
