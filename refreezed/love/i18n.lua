--[[============================================================
--=
--=  Internationalization module
--=
--=  Dependencies:
--=  - LÖVE
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
--=-------------------------------------------------------------
--=
--=  TODO:
--=  - Add proper module description.
--=
--==============================================================

	-- Pre-load settings
	addSpecialLanguage, setSpecialLanguageTextFilter
	ignoreLanguage
	setDefaultLanguage

	-- Loading
	load

	-- Post-load access
	get, has
	getLanguage, setLanguage
	getLanguageCodes
	isSpecial
	getCharacters

--============================================================]]



-- Modules
local utf8 = require('utf8') -- (LÖVE)
local csv = require((...):gsub('%.init$', ''):gsub('%.%w+%.%w+$', '')..'.csv') -- (parent folder)
local LF = love.filesystem

-- Variables
local defaultLanguageCode, currentLanguageCode = 'en-US', 'en-US'
local languageLines = {} -- (sequence and KV table)
local languagesToIgnore = {}
local specialFieldFilter = nil
local specialLanguages = {}

local i18n = {
	debug_preferImportedLanguageFile = false,
	debug_showTextKeys = false,
}



--==============================================================
--==============================================================
--==============================================================

local errorf
local indexWith

local parseLanguageFile
local importTexts



--==============================================================



-- index = indexWith( table, key, value )
function indexWith(t, k, v)
	for i, t in ipairs(t) do
		if (t[k] == v) then
			return i
		end
	end
	return nil
end



-- errorf( [ level=1, ] formatString, ... )
function errorf(levelOrS, s, ...)
	if (type(levelOrS) == 'number') then
		error(('i18n: '..s):format(...), levelOrS+1)
	else
		error(('i18n: '..levelOrS):format(s, ...), 2)
	end
end



--==============================================================



-- lines = parseLanguageFile( path, languageCode )
function parseLanguageFile(path, langCode)

	-- Read file
	local contents, size = LF.read(path)
	if (not contents) then
		errorf('could not read language file %q', path)
	end
	if (size == 0) then
		errorf('language file is empty: %q', path)
	end

	-- Parse contents
	local lines, lastK = {}, nil
	for line in contents:gmatch('%S[^\r\n]*') do
		local k = nil
		if (line:sub(1, 1) ~= ';') then
			local v
			k, v = line:match('^([%w_]+)%s*=%s*(.*)%s*$')
			if (k) then
				if (k == lastK) then
					lines[k] = lines[k]..'\n'..v
				else
					lines[k] = v
				end
			else
				printf('i18n(%s): ignored line with unknown format: %q', langCode, line)
			end
		end
		lastK = k
	end

	return lines
end



-- importTexts( languageLines, path )
function importTexts(languageLines, path)

	-- Read file
	local contents, size = LF.read(path)
	if (not contents) then
		errorf('could not read text file %q', path)
	end
	if (size == 0) then
		errorf('text file is empty: %q', path)
	end

	-- Extract texts
	local csvTable = csv.parse(contents)
	local lineNum, langCodes = 0, {}
	local colsToIgnore, colWithKey = 4, 2 -- asdf
	for _, fields in ipairs(csvTable) do
		lineNum = lineNum+1

		-- Table header
		if (lineNum == 1) then
			-- void

		-- Language codes
		elseif (lineNum == 2) then
			for col, field in ipairs(fields) do
				field = field:gsub('^%s+', ''):gsub('%s+$', '') -- cleanup
				-- print('line:'..lineNum, 'col:'..col, '#'..#field, '=', field)
				if (col > colsToIgnore) then
					local langCode = field:match('^%s*([-A-Za-z]+)')
						or errorf('bad language code format: %s', field)
					table.insert(langCodes, langCode)
					if (not languageLines[langCode]) then
						local lines = {_code=langCode}
						languageLines[langCode] = lines
						table.insert(languageLines, lines)
					end
				end
			end

		-- Texts
		else
			local col, k = 0
			for col, field in ipairs(fields) do
				field = field:gsub('^%s+', ''):gsub('%s+$', '') -- cleanup
				-- print('line:'..lineNum, 'col:'..col, '#'..#field, '=', field)
				if (col == colWithKey) then
					k = field
				elseif (col > colsToIgnore) then
					assert(k)
					local langCode = langCodes[col-colsToIgnore]
						or errorf('missing language code for line %d: %s', lineNum, line)
					local lines = languageLines[langCode]
						or errorf('missing language lines for code %s on line %d', langCode, line)
					if (specialFieldFilter and i18n.isSpecial(langCode)) then
						field = specialFieldFilter(field)
					end
					if (lines[k] and not i18n.debug_preferImportedLanguageFile) then
						-- printf('i18n(%s): ignored text key %q', langCode, k)
					elseif (field ~= '') then
						lines[k] = field
					end
				end
			end

		end
	end

end



--==============================================================
--==============================================================
--==============================================================



-- addSpecialLanguage( languageCode )
function i18n.addSpecialLanguage(langCode)
	assert(type(langCode) == 'string')
	specialLanguages[langCode] = true
end

-- setSpecialLanguageTextFilter( filter:function )
function i18n.setSpecialLanguageTextFilter(filter)
	assert(filter == nil or type(filter) == 'function')
	specialFieldFilter = filter
end



-- ignoreLanguage( languageCode )
function i18n.ignoreLanguage(langCode)
	assert(type(langCode) == 'string')
	languagesToIgnore[langCode] = true
end



-- setDefaultLanguage( languageCode )
function i18n.setDefaultLanguage(langCode)
	assert(type(langCode) == 'string')
	defaultLanguageCode = langCode
	currentLanguageCode = defaultLanguageCode
end



--==============================================================



-- load( languageFolder, textsFilePath )
function i18n.load(folder, path)
	languageLines = {}

	-- Load localization files
	for _, name in ipairs((LF.getDirectoryItems or LF.enumerate)(folder)) do
		local langCode = name:match('^(.+)%.ini$')
		if (langCode) then
			local lines = parseLanguageFile(folder..'/'..name, langCode)
			lines._code = langCode
			languageLines[langCode] = lines
			table.insert(languageLines, lines)
		end
	end
	importTexts(languageLines, path)

	-- Remove ignored languages
	for langCode in pairs(languagesToIgnore) do
		if (languageLines[langCode]) then
			languageLines[langCode] = nil
			table.remove(languageLines, indexWith(languageLines, '_code', langCode))
		end
	end

	-- Require the default code to be loaded
	if (not languageLines[defaultLanguageCode]) then
		errorf('missing language file for default language %q', defaultLanguageCode)
	end

	-- Move default language to the beginning
	local i = indexWith(languageLines, '_code', defaultLanguageCode)
	table.insert(languageLines, 1, table.remove(languageLines, i))

end



--==============================================================



do
	local string_find, string_gsub, type = string.find, string.gsub, type

	local function getSpecified(k, langCode, fallback)
		return (languageLines[langCode][k] or fallback)
	end

	local function getCurrent(k, langCode, fallback)
		return (languageLines[currentLanguageCode][k] or languageLines[defaultLanguageCode][k] or fallback)
	end

	-- text = get( textKey [, languageCode=current ] )
	-- Note: If languageCode is omitted, the current code is used AND defaultLanguageCode is used as fallback
	-- Note: If languageCode is set, there's NO fallback
	-- Note: textKey can consist of multiple keys separated by "++" or "+++" (e.g. "ThingTitle+++ThingDescription")
	function i18n.get(k, langCode)
		if (type(k) ~= 'string') then
			errorf(2, 'bad text key %q', tostring(k))
		end
		if (langCode ~= nil and type(langCode) ~= 'string') then
			errorf(2, 'bad language code %q', tostring(langCode))
		end
		if (i18n.debug_showTextKeys) then
			return k
		end
		local get = (langCode and getSpecified or getCurrent)
		if (string_find(k, '++', 1, true)) then
			return (string_gsub(k, '([^+]+)(%+*)', function(k, sep)
				if (sep == '++') then
					return get(k, langCode, k)
				elseif (sep == '+++') then
					return get(k, langCode, k)..'\n'
				else
					return get(k, langCode, k)..sep
				end
			end))
		end
		return get(k, langCode, nil)
	end

	-- state = has( textKey [, languageCode=current ] )
	-- Note: If languageCode is omitted, the current code is used and en-US is used as fallback
	-- Note: If languageCode is set, there's no fallback
	function i18n.has(k, langCode)
		if (type(k) ~= 'string') then
			errorf(2, 'bad text key %q', tostring(k))
		end
		if (langCode ~= nil and type(langCode) ~= 'string') then
			errorf(2, 'bad language code %q', tostring(langCode))
		end
		local get = (langCode and getSpecified or getCurrent)
		return (get(k, langCode, nil) ~= nil)
	end

end



-- currentLanguageCode = getLanguage( )
function i18n.getLanguage()
	return currentLanguageCode
end

-- success, errorMessage = setLanguage( languageCode )
function i18n.setLanguage(langCode)
	if (not languageLines[langCode]) then
		return false, ('no language with code %q'):format(tostring(langCode))
	end
	currentLanguageCode = langCode
	return true
end



-- languageCodes = getLanguageCodes( )
function i18n.getLanguageCodes()
	local langCodes = {}
	for _, lines in ipairs(languageLines) do
		table.insert(langCodes, lines._code)
	end
	return langCodes
end



-- state = isSpecial( [ languageCode=current ] )
function i18n.isSpecial(langCode)
	if (langCode and not languageLines[langCode]) then
		errorf(2, 'no language with code %q', tostring(langCode))
	end
	return (specialLanguages[langCode or currentLanguageCode] or false)
end



-- characters:table = getCharacters( [ ignoreSpecial=false, keyFilter:function ] )
-- characters:table = getCharacters( languageCode [, keyFilter:function ] )
do
	local utf8Codes = utf8.codes

	local function addCodepoints(codepointsSet, s)
		for pos, cp in utf8Codes(s) do
			if (cp >= 32) then -- ignore common control characters
				codepointsSet[cp] = true
			end
		end
	end

	local function getCodepoints(lines, codepointsSet, keyFilter)
		for k, line in pairs(lines) do
			if not (keyFilter and keyFilter(k)) then
				addCodepoints(codepointsSet, line)
			end
		end
	end

	function i18n.getCharacters(ignoreSpecialOrLangCode, keyFilter)
		local codepointsSet = {}

		-- Single language
		if (type(ignoreSpecialOrLangCode) == 'string') then
			local lines = languageLines[ignoreSpecialOrLangCode]
			if (not lines) then
				errorf(2, 'no language with code %q', ignoreSpecialOrLangCode)
			end
			getCodepoints(lines, codepointsSet, keyFilter)

		-- All languages
		else
			for _, lines in ipairs(languageLines) do
				if not (ignoreSpecialOrLangCode and i18n.isSpecial(lines._code)) then
					getCodepoints(lines, codepointsSet, keyFilter)
				end
			end

		end
		local codepoints = {}
		for cp in pairs(codepointsSet) do
			table.insert(codepoints, cp)
		end
		table.sort(codepoints)
		local chars = {}
		for i, cp in ipairs(codepoints) do
			chars[i] = utf8.from32{cp}
		end
		return chars
	end

end



--==============================================================
--==============================================================
--==============================================================

return i18n
