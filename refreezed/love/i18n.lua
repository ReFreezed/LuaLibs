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
	addCsvColumnToIgnore, setCsvColumnsToIgnore
	addSpecialLanguage, setSpecialLanguageTextFilter
	ignoreLanguage
	setCsvColumnWithKey
	setDefaultLanguage
	setLanguageTextFilter

	-- Loading
	load

	-- Post-load access
	get, has, add
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
local columnsToIgnore = {}
local columnWithKey = 1
local defaultLanguageCode, currentLanguageCode = 'en-US', 'en-US'
local fieldFilter, specialFieldFilter = nil, nil
local languageTable = {} -- (sequence and KV table)
local languagesToIgnore = {}
local specialLanguages = {}

local i18n = {
	debug_preferImportedLanguageFile = false,
	debug_showTextKeys = false,
}



--==============================================================
--==============================================================
--==============================================================

local cleanText
local errorf
local indexWith
local printf

local applyFieldFilter
local parseLanguageIniFile
local importTexts



--==============================================================



-- text = cleanText( text )
function cleanText(s)
	return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end



-- errorf( [ level=1, ] formatString, ... )
function errorf(levelOrS, s, ...)
	if (type(levelOrS) == 'number') then
		error(('[i18n] '..s):format(...), levelOrS+1)
	else
		error(('[i18n] '..levelOrS):format(s, ...), 2)
	end
end



-- index = indexWith( table, key, value )
function indexWith(t, k, v)
	for i, t in ipairs(t) do
		if (t[k] == v) then
			return i
		end
	end
	return nil
end



-- printf( formatString, ... )
function printf(s, ...)
	print(('[i18n] '..s):format(...))
end



--==============================================================



-- text = applyFieldFilter( text, languageCode )
function applyFieldFilter(text, langCode)
	if (specialLanguages[langCode]) then
		if (specialFieldFilter) then
			text = specialFieldFilter(text)
		end
	else
		if (fieldFilter) then
			text = fieldFilter(text)
		end
	end
	return text
end



-- texts = parseLanguageIniFile( path, languageCode )
function parseLanguageIniFile(path, langCode)

	-- Read file
	local contents, size = LF.read(path)
	if (not contents) then
		errorf('could not read ini file %q', path)
	elseif (size == 0) then
		errorf('language ini file is empty: %q', path)
	end

	-- Parse contents
	local texts = {}
	for line in contents:gmatch('%S[^\r\n]*') do
		if (line:sub(1, 1) ~= ';') then
			local k, text = line:match('^([-%w_./]+)%s*=(.*)$')
			if (not k) then
				printf('WARNING: %s: bad line format (ignored): %s', langCode, line)
			else
				texts[k] = applyFieldFilter(cleanText(text), langCode)
			end
		end
	end

	return texts
end



-- importTexts( languageTable, path )
function importTexts(languageTable, path)

	-- Read file
	local csvStr, size = LF.read(path)
	if (not csvStr) then
		errorf('could not read csv file %q', path)
	elseif (size == 0) then
		errorf('csv file is empty: %q', path)
	end

	-- Extract texts
	local langCodes = {}
	for lineN, fields in ipairs(csv.parse(csvStr)) do

		-- Table header
		if (lineN == 1) then
			-- void

		-- Language codes
		elseif (lineN == 2) then
			for col, langCode in ipairs(fields) do
				if (not columnsToIgnore[col]) then
					langCode = cleanText(langCode)
					if (not langCode:find('^[-a-zA-Z]+$')) then
						errorf('bad language code format: %s', langCode)
					end
					langCodes[col] = langCode
					if (not languageTable[langCode]) then
						local texts = {_code=langCode}
						languageTable[langCode] = texts
						table.insert(languageTable, texts)
					end
				end
			end

		-- Texts
		else
			local k = nil
			for col, field in ipairs(fields) do
				field = cleanText(field)
				if (col == columnWithKey) then
					k = field
				elseif (not columnsToIgnore[col]) then
					if (not k) then
						errorf('key column must be before text columns')
					end
					local langCode = langCodes[col]
						or errorf('missing language code for column %d on line %d', col, lineN)
					local texts = languageTable[langCode]
						or errorf('missing text table for language code %s', langCode)
					if (texts[k] and not i18n.debug_preferImportedLanguageFile) then
						-- printf('NOTICE: %s: ignored text key %q', langCode, k)
					else
						field = applyFieldFilter(field, langCode)
						if (field ~= '') then
							texts[k] = field
						end
					end
				end
			end

		end
	end

end



--==============================================================
--==============================================================
--==============================================================



-- addCsvColumnToIgnore( column )
function i18n.addCsvColumnToIgnore(col)
	assert(type(col) == 'number')
	columnsToIgnore[col] = true
end

-- setCsvColumnsToIgnore( columns )
function i18n.setCsvColumnsToIgnore(cols)
	assert(type(cols) == 'number')
	columnsToIgnore = {}
	for col = 1, cols do
		columnsToIgnore[col] = true
	end
end



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



-- setCsvColumnWithKey( column )
function i18n.setCsvColumnWithKey(col)
	assert(type(col) == 'number')
	columnWithKey = col
end



-- setDefaultLanguage( languageCode )
function i18n.setDefaultLanguage(langCode)
	assert(type(langCode) == 'string')
	defaultLanguageCode = langCode
	currentLanguageCode = defaultLanguageCode
end



-- setLanguageTextFilter( filter:function )
function i18n.setLanguageTextFilter(filter)
	assert(filter == nil or type(filter) == 'function')
	fieldFilter = filter
end



--==============================================================



-- load( languageFolder, textsFilePath )
function i18n.load(folder, path)
	languageTable = {}

	-- Load localization files
	for _, name in ipairs((LF.getDirectoryItems or LF.enumerate)(folder)) do
		local langCode = name:match('^(.+)%.ini$')
		if (langCode) then
			local texts = parseLanguageIniFile(folder..'/'..name, langCode)
			texts._code = langCode
			languageTable[langCode] = texts
			table.insert(languageTable, texts)
		end
	end
	importTexts(languageTable, path)

	-- Remove ignored languages
	for langCode in pairs(languagesToIgnore) do
		if (languageTable[langCode]) then
			languageTable[langCode] = nil
			table.remove(languageTable, indexWith(languageTable, '_code', langCode))
		end
	end

	-- Require the default code to be loaded
	if (not languageTable[defaultLanguageCode]) then
		errorf('missing language file for default language %q', defaultLanguageCode)
	end

	-- Move default language to the beginning
	local i = indexWith(languageTable, '_code', defaultLanguageCode)
	table.insert(languageTable, 1, table.remove(languageTable, i))

end



--==============================================================



do
	local string_find, string_gsub, type = string.find, string.gsub, type

	local function getSpecified(k, langCode, fallback)
		return (languageTable[langCode][k] or fallback)
	end

	local function getCurrent(k, langCode, fallback)
		return (languageTable[currentLanguageCode][k] or languageTable[defaultLanguageCode][k] or fallback)
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

	-- add( textKey, [ languageCode=defaultLanguageCode, ] text )
	function i18n.add(k, langCode, text)
		if (text == nil) then
			k, langCode, text = k, defaultLanguageCode, langCode
		end
		if (type(k) ~= 'string') then
			errorf(2, 'bad text key %q', tostring(k))
		end
		if (type(text) ~= 'string') then
			errorf(2, 'bad text argument type %q', type(text))
		end
		local texts = languageTable[langCode]
		if (not texts) then
			errorf(2, 'bad language code %q', tostring(langCode))
		end
		if (texts[k]) then
			errorf(2, 'text key %q is already occupied in language %q', k, langCode)
		end
		texts[k] = applyFieldFilter(text, langCode)
	end

end



-- currentLanguageCode = getLanguage( )
function i18n.getLanguage()
	return currentLanguageCode
end

-- success, errorMessage = setLanguage( languageCode )
function i18n.setLanguage(langCode)
	if (not languageTable[langCode]) then
		return false, ('no language with code %q'):format(tostring(langCode))
	end
	currentLanguageCode = langCode
	return true
end



-- languageCodes = getLanguageCodes( )
function i18n.getLanguageCodes()
	local langCodes = {}
	for _, texts in ipairs(languageTable) do
		table.insert(langCodes, texts._code)
	end
	return langCodes
end



-- state = isSpecial( [ languageCode=current ] )
function i18n.isSpecial(langCode)
	if (langCode and not languageTable[langCode]) then
		errorf(2, 'no language with code %q', tostring(langCode))
	end
	return (specialLanguages[langCode or currentLanguageCode] or false)
end



-- characters:table = getCharacters( [ ignoreSpecial=false, keyFilter:function ] )
-- characters:table = getCharacters( languageCode [, keyFilter:function ] )
do
	local function addCodepoints(codepointsSet, s)
		for pos, cp in utf8.codes(s) do
			if (cp >= 32) then -- ignore common control characters
				codepointsSet[cp] = true
			end
		end
	end

	local function getCodepoints(texts, codepointsSet, keyFilter)
		for k, text in pairs(texts) do
			if not (keyFilter and keyFilter(k)) then
				addCodepoints(codepointsSet, text)
			end
		end
	end

	function i18n.getCharacters(ignoreSpecialOrLangCode, keyFilter)
		local codepointsSet = {}

		-- Single language
		if (type(ignoreSpecialOrLangCode) == 'string') then
			local texts = languageTable[ignoreSpecialOrLangCode]
			if (not texts) then
				errorf(2, 'no language with code %q', ignoreSpecialOrLangCode)
			end
			getCodepoints(texts, codepointsSet, keyFilter)

		-- All languages
		else
			for _, texts in ipairs(languageTable) do
				if not (ignoreSpecialOrLangCode and i18n.isSpecial(texts._code)) then
					getCodepoints(texts, codepointsSet, keyFilter)
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
			chars[i] = utf8.char(cp)
		end
		return chars
	end

end



--==============================================================
--==============================================================
--==============================================================

return i18n
