--[[============================================================
--=
--=  Font utilities for LÖVE
--=
--=  Dependencies:
--=  - LÖVE 0.10.2
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

	createBitmapFont
	newOutlineBitmapFont

	getFallbacks
	setFallbacks
	isFallbackOf

--============================================================]]



local LG = love.graphics

local M = {

	debug_exportBitmapFonts = false,
	debug_exportedBitmapFontFile = 'debug_font%n.png',

	debug_exportMissingChars = false,
	debug_missingCharsFile = 'debug_missingChars.txt',

	debug_limitTextureSize = false,
	debug_maxTextureSize = 1024,

}



--==============================================================
--==============================================================
--==============================================================

local getKeys
local indexOf



-- keys = getKeys( table )
function getKeys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys+1] = k
	end
	return keys
end



-- indexOf( table, value )
function indexOf(t, v)
	for i, item in ipairs(t) do
		if (item == v) then
			return i
		end
	end
	return nil
end



--==============================================================
--==============================================================
--==============================================================



-- font, characters:string = createBitmapFont( sourceFont, charToInclude,
--    charPaddingHorizontal, charPaddingTop, charPaddingBottom [, fontShader ] )
function M.createBitmapFont(sourceFont, charTable, padH, padT, padB, shader)
	assert(sourceFont)
	assert(type(charTable) == 'table')
	assert(type(padH) == 'number')
	assert(type(padT) == 'number')
	assert(type(padB) == 'number')

	-- Get the system's texture size limit
	local maxTextureSize = LG.getSystemLimits().texturesize
	if (M.debug_limitTextureSize) then
		maxTextureSize = math.min(M.debug_maxTextureSize, maxTextureSize)
	end

	local allChars, missingChars = {}, {}

	-- Get individual characters
	for i = #charTable, 1, -1 do
		if (not sourceFont:hasGlyphs(charTable[i])) then
			table.insert(missingChars, table.remove(charTable, i))
		end
	end
	for _, c in ipairs(charTable) do
		allChars[c] = true
	end

	-- Export missing characters
	if (M.debug_exportMissingChars and missingChars[1]) then
		assert(LF.write(M.debug_missingCharsFile, 'MISSING\r\n\r\n'..table.concat(missingChars, '\r\n')))
		error('chars are missing')
	end

	allChars = getKeys(allChars)
	table.sort(allChars) -- (not really needed, but looks nicer...)
	local allCharsStr = table.concat(allChars)

	local charInfos = {}
	for i, char in ipairs(allChars) do
		charInfos[i] = {char=char, width=nil, canvasIndex=nil, isFirst=nil}
	end

	-- Create bitmap font canvases
	local canvasI = 1
	local textW, textH = 1, sourceFont:getHeight()+padT+padB
	local fontCanvases = {}
	local isFirstChar = true
	for _, charInfo in ipairs(charInfos) do
		local charW = (sourceFont:getWidth(charInfo.char)+2*padH)+1
		if (textW+charW > maxTextureSize) then
			fontCanvases[canvasI] = LG.newCanvas(textW, textH)
			canvasI = canvasI+1
			textW = 1
			isFirstChar = true
		end
		charInfo.width = charW
		charInfo.canvasIndex = canvasI
		charInfo.isFirst = isFirstChar
		isFirstChar = false
		textW = textW+charW
	end
	fontCanvases[canvasI] = LG.newCanvas(textW, textH)

	-- Get chars for each canvas
	local fontCanvasesCharsStr = {}
	for _, charInfo in ipairs(charInfos) do
		local canvasI = charInfo.canvasIndex
		local chars = fontCanvasesCharsStr[canvasI]
		if (not chars) then
			chars = {}
			fontCanvasesCharsStr[canvasI] = chars
		end
		table.insert(chars, charInfo.char)
	end
	for canvasI, chars in ipairs(fontCanvasesCharsStr) do
		fontCanvasesCharsStr[canvasI] = table.concat(chars)
	end

	-- Draw characters on bitmaps
	LG.push('all')
	LG.setFont(sourceFont)
	if (shader) then
		LG.setShader(shader)
	end
	-- Characters
	LG.setColor(255, 255, 255)
	local x, y = nil, padT
	for _, charInfo in ipairs(charInfos) do
		if (charInfo.isFirst) then
			x = 1
			LG.setCanvas(fontCanvases[charInfo.canvasIndex])
		end
		assert(x)
		LG.print(charInfo.char, x+padH, y)
		x = x+charInfo.width
	end
	-- Dividers
	LG.setColor(255, 0, 255)
	local x = nil
	for _, charInfo in ipairs(charInfos) do
		if (charInfo.isFirst) then
			x = 0
			LG.setCanvas(fontCanvases[charInfo.canvasIndex])
			LG.rectangle('fill', x, 0, 1, textH)
		end
		assert(x)
		x = x+charInfo.width
		LG.rectangle('fill', x, 0, 1, textH)
	end
	--
	LG.pop()

	-- Create fonts
	local fonts = {}
	for canvasI, fontCanvas in ipairs(fontCanvases) do
		local fontImageData = fontCanvas:newImageData()
		if (M.debug_exportBitmapFonts) then
			fontImageData:encode('png', (M.debug_exportedBitmapFontFile:gsub('%%n', canvasI)))
		end
		local fontImage = LG.newImage(fontImageData)
		fonts[canvasI] = LG.newImageFont(fontImage, fontCanvasesCharsStr[canvasI], 2)
	end
	if (M.debug_exportBitmapFonts) then
		error('[DEBUG] Fonts exported - exiting app')
	end
	M.setFallbacks(unpack(fonts))

	return fonts[1], allCharsStr
end



--==============================================================



-- font = newOutlineBitmapFont( sourceFont, characters:string )
function M.newOutlineBitmapFont(sourceFont, allCharsStr)

	-- Get the system's texture size limit
	local maxTextureSize = LG.getSystemLimits().texturesize
	if (M.debug_limitTextureSize) then
		maxTextureSize = math.min(M.debug_maxTextureSize, maxTextureSize)
	end

	-- Get individual characters
	local utf8 = require('utf8')
	local toChar = utf8.char
	local i, charInfos = 0, {}
	for pos, cp in utf8.codes(allCharsStr) do
		i = i+1
		charInfos[i] = {char=toChar(cp), width=nil, canvasIndex=nil, isFirst=nil}
	end

	-- Create bitmap font canvases
	local canvasI = 1
	local textW, textH = 1, sourceFont:getHeight()+2
	local fontCanvases = {}
	local isFirstChar = true
	for _, charInfo in ipairs(charInfos) do
		local charW = sourceFont:getWidth(charInfo.char)+2
		if (textW+charW > maxTextureSize) then
			fontCanvases[canvasI] = LG.newCanvas(textW, textH)
			canvasI = canvasI+1
			textW = 1
			isFirstChar = true
		end
		charInfo.width = charW
		charInfo.canvasIndex = canvasI
		charInfo.isFirst = isFirstChar
		isFirstChar = false
		textW = textW+charW
	end
	fontCanvases[canvasI] = LG.newCanvas(textW, textH)

	-- Get chars for each canvas
	local fontCanvasesCharsStr = {}
	for _, charInfo in ipairs(charInfos) do
		local canvasI = charInfo.canvasIndex
		local chars = fontCanvasesCharsStr[canvasI]
		if (not chars) then
			chars = {}
			fontCanvasesCharsStr[canvasI] = chars
		end
		table.insert(chars, charInfo.char)
	end
	for canvasI, chars in ipairs(fontCanvasesCharsStr) do
		fontCanvasesCharsStr[canvasI] = table.concat(chars)
	end

	-- Draw characters on bitmaps
	LG.push('all')
	LG.setFont(sourceFont)
	-- Characters
	local x, y = nil, 1
	for _, charInfo in ipairs(charInfos) do
		if (charInfo.isFirst) then
			x = 1+1
			LG.setCanvas(fontCanvases[charInfo.canvasIndex])
		end
		assert(x)
		local char = charInfo.char
		LG.setColor(0, 0, 0)
		LG.print(char, x, y-1) -- t
		LG.print(char, x+1, y) -- r
		LG.print(char, x, y+1) -- b
		LG.print(char, x-1, y) -- l
		LG.setColor(0, 0, 0, 150)
		LG.print(char, x-1, y-1) -- tl
		LG.print(char, x+1, y-1) -- tr
		LG.print(char, x-1, y+1) -- bl
		LG.print(char, x+1, y+1) -- br
		LG.setColor(255, 255, 255)
		LG.print(char, x, y) -- c
		x = x+charInfo.width
	end
	-- Dividers
	LG.setColor(255, 0, 255)
	local x = nil
	for _, charInfo in ipairs(charInfos) do
		if (charInfo.isFirst) then
			x = 0
			LG.setCanvas(fontCanvases[charInfo.canvasIndex])
			LG.rectangle('fill', x, 0, 1, textH)
		end
		assert(x)
		x = x+charInfo.width
		LG.rectangle('fill', x, 0, 1, textH)
	end
	--
	LG.pop()

	-- Create fonts
	local fonts = {}
	for canvasI, fontCanvas in ipairs(fontCanvases) do
		local fontImageData = fontCanvas:newImageData()
		if (M.debug_exportBitmapFonts) then
			fontImageData:encode('png', (M.debug_exportedBitmapFontFile:gsub('%%n', canvasI)))
		end
		local fontImage = LG.newImage(fontImageData)
		fonts[canvasI] = LG.newImageFont(fontImage, fontCanvasesCharsStr[canvasI], -1)
	end
	if (M.debug_exportBitmapFonts) then
		error('[DEBUG] Fonts exported - exiting app')
	end
	M.setFallbacks(unpack(fonts))

	return fonts[1]
end



--==============================================================
--==============================================================
--==============================================================

local fontFallbacks = setmetatable({}, {__mode='k'}) -- only top-level fallbacks



local function collectFallbacks(font, collection)
	assert(font)
	assert(collection)
	local fallbacks = fontFallbacks[font]
	if (fallbacks) then
		for _, fallback in ipairs(fallbacks) do
			if (not indexOf(collection, fallback)) then
				table.insert(collection, fallback)
				collectFallbacks(fallback, collection)
			end
		end
	end
	return collection
end



local function updateFonts()
	for font in pairs(fontFallbacks) do
		font:setFallbacks(unpack(collectFallbacks(font, {})))
	end
end



-- ... = getFallbacks( font [, includeWholeStack=false ] )
-- ...: Fallback fonts
function M.getFallbacks(font, wholeStack)
	local fallbacks = fontFallbacks[font]
	if (fallbacks) then
		return unpack(wholeStack and collectFallbacks(font, {}) or fallbacks)
	end
	return nil
end



-- success, failMessage = setFallbacks( font, ... )
-- success, failMessage = setFallbacks( font, nil ) -- removes fallbacks
-- ...: Fallback fonts
function M.setFallbacks(font, ...)

	-- Removing fallbacks
	if (not ...) then
		font:setFallbacks()
		fontFallbacks[font] = nil
		updateFonts()
		return true
	end

	-- Check cross fallbacks
	for i = 1, select('#', ...) do
		local fallback = select(i, ...)
		if (indexOf(collectFallbacks(fallback, {}), font)) then
			return nil, 'font cross fallback detected' -- (keep this limitation?)
		end
	end

	-- Save fallback data for font
	fontFallbacks[font] = {...}

	updateFonts() -- TODO: Optimization: Only update affected fonts (This font + parents) [LOW]
	return true
end



-- result = isFallbackOf( fallback, font )
function M.isFallbackOf(fallback, font)
	return (indexOf(collectFallbacks(font, {}), fallback) ~= nil)
end



--==============================================================
--==============================================================
--==============================================================

return M
