--[[============================================================
--=
--=  INI file module
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

	Example:

	local iniString = "Object=Car\n[Dimensions]\nWidth=2.4\nLength=4.9\n[Interior]\nLength=3.6"
	local iniTable, iniSections = ini.parse(iniString)
	-- iniTable is {Object="Car", Width="2.4", Length="3.6"}
	-- iniSections is {[""]={Object="Car"}, Dimensions={Width="2.4", Length="4.9"}, Interior={Length="3.6"}}

--============================================================]]

local error
    = error
local string, table
    = string, table
local string_find, string_format, string_gmatch, string_gsub, string_match, string_sub
    = string.find, string.format, string.gmatch, string.gsub, string.match, string.sub
local table_insert
    = table.insert

local ini = {}

--==============================================================

local function insert(t, v)
	t = (t or {})
	table_insert(t, v)
	return t
end

--==============================================================

-- table, sections = parse( csvString [, enableArrays=false ] )
function ini.parse(s, enableArrays)
	local t, sections, currentSectionK = {}, {['']={}}, ''
	for i, line in string_gmatch(s, '()(%S[^\r\n]*) *') do

		-- Key/value
		local k, v = string_match(line, '^(%w.-) *= *(.*)$')
		if (k) then
			if (enableArrays and string_find(k, '%[%]$')) then
				local section = sections[currentSectionK]
				t[k] = insert(t[k], v)
				section[k] = insert(section[k], v)
			else
				t[k] = v
				sections[currentSectionK][k] = v
			end
		else

			-- Section
			local sectionK = string_match(line, '^%[ *(..-) *%]$')
			if (sectionK) then
				currentSectionK = sectionK
				sections[currentSectionK] = {}

			-- Comment
			elseif (string_sub(line, 1, 1) == ';') then
				-- void

			else
				error(string_format('bad ini line (on line %d): %q',
					#string_gsub(string_sub(s, 1, i), '[^\n]+', '')+1, line))
			end
		end
	end
	return t, sections
end

--==============================================================

return ini
