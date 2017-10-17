--[[============================================================
--=
--=  GUI class
--=
--=  Dependencies:
--=  - LÖVE 0.10.2
--=  - refreezed.class
--=  - refreezed.love.Animation (unavailable in LuaLibs!)
--=  - refreezed.love.InputField
--=  - refreezed.love.Sprite (unavailable in LuaLibs!)
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
--=  - Percentage sizes for elements.
--=
--==============================================================

	update
	draw

	blur
	defineStyle
	find, findAll, findActive, findToggled
	getDefaultSound, setDefaultSound
	getElementAt
	getFont, setFont, getBoldFont, setBoldFont, getSmallFont, setSmallFont
	getHoveredElement
	getNavigationTarget, navigateTo, navigateToNext, navigateToPrevious, navigateToFirst, navigate, canNavigateTo
	getRoot
	getScissorCoordsConverter, setScissorCoordsConverter
	getSoundPlayer, setSoundPlayer
	getSpriteLoader, setSpriteLoader
	getTarget, getTargetCallback, setTargetCallback
	isBusy, isMouseBusy
	isIgnoringKeyboardInput
	isMouseGrabbed, setMouseIsGrabbed
	keyDown, keyUp, textInput
	load
	mouseDown, mouseMove, mouseUp, mouseWheel
	ok, back
	updateLayout

----------------------------------------------------------------

	(element)
	- close, canClose
	- exists
	- getAnchor, setAnchor, getAnchorX, setAnchorX, getAnchorY, setAnchorY
	- getCallback, setCallback, trigger, triggerBubbling
	- getClosest
	- getData, setData, swapData
	- getDimensions, setDimensions, getWidth, setWidth, getHeight, setHeight
	- getGui
	- getId, hasId
	- getIndex, getDepth
	- getLayout
	- getLayoutDimensions, getLayoutWidth, getLayoutHeight
	- getLayoutPosition, getLayoutX, getLayoutY, getLayoutCenterPosition
	- getOrigin, setOrigin, getOriginX, setOriginX, getOriginY, setOriginY
	- getParent, getParents, hasParent, hasParentWithId, parents, parentsr
	- getPathDescription
	- getPosition, setPosition, getX, setX, getY, setY
	- getRoot
	- getSound, getResultingSound, setSound
	- getTooltip, setTooltip
	- isAt
	- isDisplayed, getClosestHiddenElement, getFarthestHiddenElement
	- isHidden, isVisible, setHidden, setVisible, show, hide, toggleHidden
	- isHovered
	- isMouseFocus, isKeyboardFocus
	- isNavigationTarget
	- isSolid
	- isType
	- refresh
	- remove
	- scrollIntoView
	- showMenu
	- updateLayout
	- Event: beforedraw, afterdraw
	- Event: close
	- Event: keydown
	- Event: mousedown, mousemove, mouseup
	- Event: refresh
	- Event: show, hide
	- Event: update

	container
	- find, findAll, findActive, findToggled
	- get, children
	- getChildWithData
	- getElementAt
	- getMaxWidth, setMaxWidth, getMaxHeight, setMaxHeight
	- getPadding, setPadding
	- getScroll, setScroll, scroll, updateScroll
	- getVisibleChild, getVisibleChildNumber, getVisibleChildCount, setVisibleChild
	- indexOf
	- insert, remove, empty
	- setChildrenActive
	- setChildrenHidden
	- setToggledChild
	- sort
	- traverse, traverseType, traverseVisible

		(bar)

			hbar

			vbar

		root
		- setDimensions

	(leaf)
	- getAlign, setAlign
	- getFont
	- getText, setText
	- getTextColor, setTextColor
	- isBold, setBold
	- isSmall, setSmall

		canvas
		- getCanvasBackgroundColor, setCanvasBackgroundColor
		- Event: draw

		image
		- getImageBackgroundColor, setImageBackgroundColor
		- getSprite, setSprite
		- getSpriteColor, setSpriteColor

		text

		(widget)
		- isActive, setActive

			button
			- getImageBackgroundColor, setImageBackgroundColor
			- getSprite, setSprite
			- getSpriteColor, setSpriteColor
			- getText2, setText2
			- getTheme, setTheme
			- isToggled, setToggled
			- press
			- Event: press

			input
			- focus, blur, isFocused
			- getField
			- getValue, setValue, getVisibleValue
			- isPasswordActive, setPasswordActive
			- Event: change
			- Event: submit

--============================================================]]



-- Modules
local newClass = require((...):gsub('%.init$', ''):gsub('%.%w+%.%w+$', '')..'.class') -- (parent folder)
local InputField = require((...):gsub('%.init$', ''):gsub('%.%w+$', '')..'.InputField') -- (same folder)
local LG = love.graphics

local tau = 2*math.pi
local defaultFont = LG.newFont(12)

local Gui = newClass('Gui', {

	TOOLTIP_DELAY = 0.15,

	_defaultSounds = {},
	_font = defaultFont, _boldFont = defaultFont, _smallFont = defaultFont,
	_hoveredElement = nil,
	_ignoreKeyboardInputThisFrame = false,
	_keyboardFocus = nil,
	_lastAutomaticId = 0,
	_layoutNeedsUpdate = false,
	_lockNavigation = false,
	_mouseFocus = nil, _mouseFocusSet = nil,
	_mouseIsGrabbed = false,
	_mouseOffsetX = 0, _mouseOffsetY = 0, -- (not used at the moment)
	_mouseX = -99999, _mouseY = -99999,
	_navigationTarget = nil, _timeSinceNavigation = 0.0,
	_root = nil,
	_scissorCoordsConverter = nil,
	_soundPlayer = nil,
	_spriteLoader = nil,
	_styles = nil,
	_time = 0.0,
	_tooltipTime = 0.0,

	debug = false,

})

local Cs = {} -- gui element Classes

local validSoundKeys = {

	-- Generic
	['close'] = true, -- usually containers
	['focus'] = true, -- (only used by inputs so far)
	['press'] = true, -- buttons
	['scroll'] = true, -- containers

	-- Element specific
	['inputsubmit'] = true, ['inputrevert'] = true,

}



--==============================================================
--= Local functions ============================================
--==============================================================

local applyStyle
local checkValidSoundKey
local copyTable
local coroutineIterator, newIteratorCoroutine
local drawBackground
local errorf, assertArg
local F
local getTextDimensions, getTextHeight
local lerp
local matchAll
local playSound, prepareSound
local retrieve
local reverseArray
local round
local setMouseFocus, setKeyboardFocus
local updateHoveredElement, validateNavigationTarget
local updateLayout, updateLayoutIfNeeded, scheduleLayoutUpdateIfDisplayed

local updateContainerChildLayoutSizes
local getContainerLayoutSizeValues
local updateContainerLayoutSize
local expandElement
local updateFloatingElementPosition

--==============================================================



-- applyStyle( data, styleData )
function applyStyle(data, styleData)
	for i, childStyleData in ipairs(styleData) do
		if (data[i] == nil) then
			error('cannot apply style (missing children)')
		end
		applyStyle(data[i], childStyleData)
	end
	for k, v in pairs(styleData) do
		if (data[k] == nil) then
			data[k] = v
		end
	end
end



-- checkValidSoundKey( soundKey )
function checkValidSoundKey(soundK)
	if (soundK == nil or validSoundKeys[soundK]) then
		return
	end
	local keys = {}
	for soundK in pairs(validSoundKeys) do
		table.insert(keys, soundK)
	end
	table.sort(keys)
	errorf(2, 'bad sound key %q (must be any of "%s")', tostring(soundK), table.concat(keys, '", "'))
end



-- copy = copyTable( table )
function copyTable(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end



-- ... = coroutineIterator( coroutine )
function coroutineIterator(co)
	return select(2, assert(coroutine.resume(co)))
end

-- iterator, coroutine = newIteratorCoroutine( callback, arguments... )
do
	local function initiator(cb, ...)
		coroutine.yield()
		return cb(...)
	end
	function newIteratorCoroutine(cb, ...)
		local co = coroutine.create(initiator)
		coroutine.resume(co, cb, ...)
		return coroutineIterator, co
	end
end



-- drawBackground( element )
function drawBackground(el)
	local bg = el._background
	if (not bg) then
		return
	end
	local x, y = el._layoutX+el._layoutOffsetX, el._layoutY+el._layoutOffsetY
	local w, h = el._layoutWidth, el._layoutHeight
	if nil then
	elseif (bg == 'shadow') then
		LG.setColor(0, 0, 0, 150)
		LG.rectangle('fill', x, y, w, h)
	elseif (bg == 'header') then
		LG.setColor(255, 255, 255, 50)
		LG.rectangle('fill', x, y, w, h)
	elseif (bg == 'cover') then
		LG.setColor(40, 40, 40, 240)
		LG.rectangle('fill', x, y, w, h)
	elseif (bg == 'warning') then
		LG.setColor(188, 58, 41, 180)
		LG.rectangle('fill', x, y, w, h)
	end
end



-- errorf( [ level=1, ] formatString, ... )
function errorf(i, s, ...)
	if (type(i) == 'number') then
		error(s:format(...), i+1)
	else
		error(i:format(s, ...), 2)
	end
end

-- value = assertArg( [ functionName=auto, ] argumentNumber, value, expectedValueType... [, depth=1 ] )
do
	local function assertArgTypes(fName, n, v, ...)
		local vType = type(v)
		local varargCount = select('#', ...)
		local lastArg = select(varargCount, ...)
		local hasDepthArg = (type(lastArg) == 'number')
		local typeCount = varargCount+(hasDepthArg and -1 or 0)
		for i = 1, typeCount do
			if (vType == select(i, ...)) then
				return v
			end
		end
		local depth = 3+(hasDepthArg and lastArg or 1)
		if (not fName) then
			fName = debug.traceback('', depth-2):match(": in function '(.-)'") or '?'
		end
		local expects = table.concat({...}, ' or ', 1, typeCount)
		errorf(depth, "bad argument #%d to '%s' (%s expected, got %s)", n, fName, expects, vType)
	end

	function assertArg(fNameOrArgNum, ...)
		if (type(fNameOrArgNum) == 'string') then
			return assertArgTypes(fNameOrArgNum, ...)
		else
			return assertArgTypes(nil, fNameOrArgNum, ...)
		end
	end

end



-- string = F"formatString"( ... )
-- ...: Values for string.format
do
	local string_format = string.format
	local formatString
	local function format(...)
		return string_format(formatString, ...)
	end
	function F(s)
		formatString = s
		return format
	end
end



-- width, height = getTextDimensions( font, text [, wrapLimit=none ] )
function getTextDimensions(font, text, wrapLimit)
	local w, lines = font:getWrap(text, (wrapLimit or math.huge))
	local h = font:getHeight()
	return w, h+math.floor(h*font:getLineHeight())*(math.max(#lines, 1)-1)
end

-- height = getTextHeight( font, text [, wrapLimit=none ] )
function getTextHeight(font, text, wrapLimit)
	local lineCount, _
	if (wrapLimit) then
		_, lineCount = font:getWrap(text, wrapLimit)
		lineCount = #lineCount
	else
		_, lineCount = text:gsub('\n', '')
		lineCount = lineCount+1
	end
	local h = font:getHeight()
	return h+math.floor(h*font:getLineHeight())*(lineCount-1)
end



-- value = lerp( v1, v2, t )
function lerp(v1, v2, t)
	return v1+t*(v2-v1)
end



-- matches = matchAll( string, pattern )
function matchAll(s, pat)
	local matches, i = {}, 0
	for match in s:gmatch(pat) do
		i = i+1
		matches[i] = match
	end
	return matches
end



-- playSound( element, soundKey )
function playSound(el, soundK)
	local gui = el._gui
	local soundPlayer = (gui and gui._soundPlayer)
	local sound = (soundPlayer and el:getResultingSound(soundK))
	if (sound ~= nil) then
		soundPlayer(sound)
	end
end

-- Prepare a sound for being played (Useful if it's possible the element will be removed in an event)
-- playSound:function = prepareSound( element, soundKey )
function prepareSound(el, soundK)
	local gui = el._gui
	local soundPlayer = (gui and gui._soundPlayer)
	local sound = (soundPlayer and el:getResultingSound(soundK))
	return function()
		if (sound ~= nil) then
			soundPlayer(sound)
		end
	end
end



-- retrieve( element, data, property1... )
function retrieve(el, data, _k, ...)
	local v = data[_k:sub(2)]
	if (v ~= nil) then
		el[_k] = v
	end
	if (...) then
		return retrieve(el, data, ...)
	end
end



-- array = reverseArray( array )
function reverseArray(arr)
	local lenPlusOne, i2 = #arr+1
	for i = 1, #arr/2 do
		i2 = lenPlusOne-i
		arr[i], arr[i2] = arr[i2], arr[i]
	end
	return arr
end



-- integer = round( number )
function round(n)
	return math.floor(n+0.5)
end



-- setMouseFocus( gui, element, button )
function setMouseFocus(gui, el, buttonN)
	if (el) then
		if (next(gui._mouseFocusSet)) then
			error('mouseFocusSet must be empty for mouse focus to change')
		end
		gui._mouseFocus = el
		gui._mouseFocusSet[buttonN] = true
		love.mouse.setGrabbed(true)
	else
		gui._mouseFocus = nil
		gui._mouseFocusSet = {}
		gui._mouseOffsetX, gui._mouseOffsetY = 0, 0
		love.mouse.setGrabbed(gui._mouseIsGrabbed)
	end
end

-- setKeyboardFocus( gui, element )
function setKeyboardFocus(gui, el)
	gui._keyboardFocus = el
end



-- updateHoveredElement( gui )
function updateHoveredElement(gui)
	local el = gui:getElementAt(gui._mouseX, gui._mouseY)
	if (gui._hoveredElement == el) then
		return
	end
	local oldEl = gui._hoveredElement
	gui._hoveredElement = el
	if not (el and el._tooltip ~= '' and oldEl and oldEl._tooltip ~= '' and gui._tooltipTime >= gui.TOOLTIP_DELAY) then
		gui._tooltipTime = 0
	end
end

-- Removes current navigation target if it isn't a valid target anymore
-- validateNavigationTarget( gui )
function validateNavigationTarget(gui)
	local nav = gui._navigationTarget
	if (nav and not gui:canNavigateTo(nav)) then
		gui:navigateTo(nil)
	end
end



-- didUpdate = updateLayout( element )
function updateLayout(el)
	local gui = el._gui
	if (gui.debug) then
		print('Gui: Updating layout')
	end
	local container = el:getRoot() -- TODO: Make any element able to update it's layout [LOW]
	if (container._hidden) then
		return false
	end
	container:_updateLayoutSize()
	container:_expandLayout(nil, nil) -- (most likely only works correctly if container is root right now)
	container:_updateLayoutPosition()
	gui._layoutNeedsUpdate = false
	for innerEl in container:traverseVisible() do
		innerEl:trigger('layout')
	end
	updateHoveredElement(gui)
	return true
end

-- didUpdate = updateLayoutIfNeeded( gui )
function updateLayoutIfNeeded(gui)
	if (not gui._layoutNeedsUpdate) then
		return false
	end
	gui._layoutNeedsUpdate = false
	local root = gui._root
	if (not root) then
		return false
	end
	return updateLayout(root)
end

-- scheduleLayoutUpdateIfDisplayed( element )
function scheduleLayoutUpdateIfDisplayed(el)
	local gui = el._gui
	if (gui._layoutNeedsUpdate) then
		return
	end
	gui._layoutNeedsUpdate = el:isDisplayed()
	if (gui.debug and gui._layoutNeedsUpdate) then
		print('Gui: Scheduling layout update')
	end
end



--==============================================================



-- updateContainerChildLayoutSizes( container )
function updateContainerChildLayoutSizes(container)
	for _, child in ipairs(container) do
		if (not child._hidden) then
			child:_updateLayoutSize()
		end
	end
end



-- <see_return_statement> = getContainerLayoutSizeValues( bar )
function getContainerLayoutSizeValues(bar)
	local staticW, dynamicW, highestW, highestDynamicW, expandablesX = 0, 0, 0, 0, 0
	local staticH, dynamicH, highestH, highestDynamicH, expandablesY = 0, 0, 0, 0, 0
	local currentMx, currentMy, sumMx, sumMy, first = 0, 0, 0, 0, true
	for _, child in ipairs(bar) do
		if not (child._hidden or child._floating) then

			-- Dimensions
			highestW = math.max(highestW, child._layoutWidth)
			highestH = math.max(highestH, child._layoutHeight)
			if (child._width) then
				staticW = staticW+child._layoutWidth
			else
				dynamicW = dynamicW+child._layoutWidth
				highestDynamicW = math.max(highestDynamicW, child._layoutWidth)
				expandablesX = expandablesX+1
			end
			if (child._height) then
				staticH = staticH+child._layoutHeight
			else
				dynamicH = dynamicH+child._layoutHeight
				highestDynamicH = math.max(highestDynamicH, child._layoutHeight)
				expandablesY = expandablesY+1
			end

			-- Margin
			if (not first) then
				currentMx = math.max(currentMx, (child._marginLeft or child._marginHorizontal or child._margin))
				currentMy = math.max(currentMy, (child._marginTop or child._marginVertical or child._margin))
			end
			sumMx, sumMy = sumMx+currentMx, sumMy+currentMy
			currentMx = (child._marginRight or child._marginHorizontal or child._margin)
			currentMy = (child._marginBottom or child._marginVertical or child._margin)
			first = false

		end
	end
	return staticW, dynamicW, highestW, highestDynamicW, expandablesX, currentMx, sumMx,
	       staticH, dynamicH, highestH, highestDynamicH, expandablesY, currentMy, sumMy
end



-- updateContainerLayoutSize( container )
function updateContainerLayoutSize(container)
	container._layoutWidth = math.min(container._layoutInnerWidth+2*container._padding, (container._maxWidth or math.huge))
	container._layoutHeight = math.min(container._layoutInnerHeight+2*container._padding, (container._maxHeight or math.huge))
end



-- expandElement( element [, expandWidth, expandHeight ] )
function expandElement(el, expandW, expandH)
	if (expandW or el._expandX) then
		el._layoutWidth = math.min((expandW or el._parent._layoutInnerWidth), (el._maxWidth or math.huge))
		el._layoutInnerWidth = el._layoutWidth-2*el._padding
	end
	if (expandH or el._expandY) then
		el._layoutHeight = math.min((expandH or el._parent._layoutInnerHeight), (el._maxHeight or math.huge))
		el._layoutInnerHeight = el._layoutHeight-2*el._padding
	end
end



-- updateFloatingElementPosition( element )
function updateFloatingElementPosition(child)
	local parent = child._parent
	child._layoutX = round(
		parent._layoutX + parent._padding
		+ child._originX*parent._layoutInnerWidth + child._x - child._anchorX*child._layoutWidth
	)
	child._layoutY = round(
		parent._layoutY + parent._padding
		+ child._originY*parent._layoutInnerHeight + child._y - child._anchorY*child._layoutHeight
	)
	child:_updateLayoutPosition()
end



--==============================================================
--= Gui ========================================================
--==============================================================



-- Gui( )
function Gui:init()
	self._defaultSounds = {}
	self._mouseFocusSet = {}
	self._styles = {}
end



-- update( deltaTime )
function Gui:update(dt)

	self._time = self._time+dt
	self._tooltipTime = self._tooltipTime+dt
	self._timeSinceNavigation = self._timeSinceNavigation+dt

	local root = self._root
	if (root) then
		root:_update(dt)
		if (root:isVisible()) then
			root:trigger('update', dt)
			for el in root:traverseVisible() do
				el:trigger('update', dt)
			end
		end
	end

	-- Check if mouse is inside window
	if (not love.window.hasMouseFocus() and not (self._mouseX == -99999 and self._mouseY == -99999)) then
		self:mouseMove(-99999, -99999)
	end

	-- Update mouse cursor
	local el = (self._mouseFocus or self._hoveredElement)
	if (el and el:is(Cs.input) and el._active)
		and (el:isKeyboardFocus() or not el._mouseFocus)
		and (el:isHovered() or self._mouseFocusSet[1])
	then
		love.mouse.setCursor(love.mouse.getSystemCursor('ibeam'))
	else
		love.mouse.setCursor()
	end

	self._ignoreKeyboardInputThisFrame = false

end



-- draw( )
function Gui:draw()
	local root = self._root
	if (root and not root._hidden) then
		updateLayoutIfNeeded(self)

		-- Elements
		root:_draw()

		-- Navigation target
		local nav = self._navigationTarget
		if (nav) then
			local offset = 3*math.max(1-self._timeSinceNavigation/0.1, 0)
			local x, y = nav._layoutX+nav._layoutOffsetX-offset, nav._layoutY+nav._layoutOffsetY-offset
			local w, h = nav._layoutWidth+2*offset, nav._layoutHeight+2*offset
			local v = (math.cos(0.4*self._timeSinceNavigation*tau)+1)/2
			LG.setColor(255, 255, 0, lerp(15, 40, v))
			LG.rectangle('fill', x, y, w, h)
			LG.setColor(255, 255, 0, lerp(140, 255, v))
			LG.rectangle('line', x+0.5, y+0.5, w-1, h-1)
		end

		-- Tooltip
		local el = self._hoveredElement
		if (el and not self._mouseFocus) then
			el:_drawTooltip()
		end

	end
end



--==============================================================



-- blur( )
function Gui:blur()
	if (self._mouseFocus) then
		for buttonN in pairs(self._mouseFocusSet) do
			self:mouseUp(-1, -1, buttonN)
		end
	end
	setMouseFocus(self, nil)
	self._hoveredElement = nil
	self._mouseX, self._mouseY = -99999, -99999
end



-- defineStyle( styleName, styleData )
function Gui:defineStyle(styleName, styleData)
	self._styles[styleName] = styleData
end



-- element = find( id )
function Gui:find(id)
	local root = self._root
	if (root) then
		return (root._id == id and root or root:find(id))
	end
	return nil
end

-- elements = findAll( id )
function Gui:findAll(id)
	local root = self._root
	if (not root) then
		return {}
	end
	local els = root:findAll(id)
	if (root._id == id) then
		table.insert(els, 1, root)
	end
	return els
end

-- element = findActive( )
function Gui:findActive()
	local root = self._root
	return (root and root:findActive())
end

-- element = findToggled( )
function Gui:findToggled()
	local root = self._root
	return (root and root:findToggled())
end



-- sound = getDefaultSound( soundKey )
function Gui:getDefaultSound(soundK)
	assertArg(1, soundK, 'string')
	checkValidSoundKey(soundK)
	return self._defaultSounds[soundK]
end

-- setDefaultSound( soundKey, sound )
-- setDefaultSound( soundKey, nil ) -- remove sound
-- Note: 'sound' is the value sent to the GUI sound player callback
function Gui:setDefaultSound(soundK, sound)
	assertArg(1, soundK, 'string')
	checkValidSoundKey(soundK)
	self._defaultSounds[soundK] = sound
end



-- element = getElementAt( x, y [, includeNonSolid=false ] )
function Gui:getElementAt(x, y, nonSolid)
	local root = self._root
	if (root and not root._hidden) then
		return root:getElementAt(x, y, nonSolid)
	end
	return nil
end



-- getFont
Gui:defineGet('_font')

-- setFont( font )
function Gui:setFont(font)
	font = (font or defaultFont)
	if (self._font == font) then
		return
	end
	self._font = font
	self._layoutNeedsUpdate = true
end

-- getBoldFont
Gui:defineGet('_boldFont')

-- setBoldFont( font )
function Gui:setBoldFont(font)
	font = (font or defaultFont)
	if (self._boldFont == font) then
		return
	end
	self._boldFont = font
	self._layoutNeedsUpdate = true
end

-- getSmallFont
Gui:defineGet('_smallFont')

-- setSmallFont( font )
function Gui:setSmallFont(font)
	font = (font or defaultFont)
	if (self._smallFont == font) then
		return
	end
	self._smallFont = font
	self._layoutNeedsUpdate = true
end



-- element = getHoveredElement( )
Gui:defineGet('_hoveredElement')



do
	local function setNavigationTarget(self, widget)
		if (self._navigationTarget == widget) then
			return false -- no change
		end
		self._navigationTarget = widget
		self._timeSinceNavigation = 0
		if (widget) then
			widget:scrollIntoView()
		end
		;(widget or self._root):triggerBubbling('navigated', widget)
		return true -- change happened!
	end

	-- getNavigationTarget
	Gui:defineGet('_navigationTarget')

	-- success = navigateTo( widget )
	function Gui:navigateTo(widget)
		if (self._navigationTarget == widget) then
			return true
		end
		if (self._lockNavigation or not self:canNavigateTo(widget)) then
			return false
		end
		setNavigationTarget(self, widget)
		return true
	end

	do
		local function navigateToNextOrPrevious(self, id, allowNone, usePrev)
			local root = self._root
			if (not root or root._hidden) then
				return false
			end
			local nav = self._navigationTarget
			if (not nav and not usePrev) then
				return self:navigateToFirst()
			end
			local foundNav, lastWidget = false, nil
			for el in root:traverseVisible() do -- remember that we're traversing backwards
				local elIsValid = (el:is(Cs.widget) and (not id or el._id == id))
				if (elIsValid and usePrev and foundNav) then
					setNavigationTarget(self, el)
					return el
				end
				foundNav = (foundNav or el == nav)
				if (not usePrev and foundNav) then
					if (lastWidget or allowNone) then
						setNavigationTarget(self, lastWidget)
						return lastWidget
					end
					return nav
				end
				if (elIsValid) then
					lastWidget = el
				end
				if (el._captureInput or el._captureGuiInput) then
					break
				end
			end
			if (not allowNone) then
				return nav
			end
			setNavigationTarget(self, nil)
			return nil
		end

		-- element = navigateToNext( [ id=any, allowNone=false ] )
		-- Note: Same at navigateToFirst if there's currently no target
		function Gui:navigateToNext(id, allowNone)
			return navigateToNextOrPrevious(self, id, allowNone, false)
		end

		-- element = navigateToPrevious( [ id=any, allowNone=false ] )
		function Gui:navigateToPrevious(id, allowNone)
			return navigateToNextOrPrevious(self, id, allowNone, true)
		end

	end

	-- element = navigateToFirst( )
	function Gui:navigateToFirst()
		if (self._lockNavigation) then
			return nil
		end
		local root = self._root
		if (not root or root._hidden) then
			return nil
		end
		local first = nil
		for el in root:traverseVisible() do
			if (el:is(Cs.widget) and not (first and first._priority > el._priority)) then
				first = el
			end
			if (el._captureInput or el._captureGuiInput) then
				break
			end
		end
		setNavigationTarget(self, first)
		return first
	end

	-- element = navigate( angle )
	local MAX_ANGLE_DIFF = tau/4
	function Gui:navigate(targetAng)
		if (self._lockNavigation) then
			return nil
		end
		local root = self._root
		if (not root or root._hidden) then
			return nil
		end
		local nav = self._navigationTarget
		if (not nav) then
			return self:navigateToFirst()
		end

		updateLayoutIfNeeded(self)

		if nav:trigger('navigate', targetAng) then
			return self._navigationTarget -- Suppress default behavior.
		end

		updateLayoutIfNeeded(self)

		local navX, navY = nav:getLayoutCenterPosition()
		navX = navX+nav._layoutOffsetX+0.99*nav._layoutWidth/2*math.cos(targetAng)
		navY = navY+nav._layoutOffsetY+0.99*nav._layoutHeight/2*math.sin(targetAng)

		-- Navigate to closest target in targetAng's general direction
		local closestEl, closestDistSquared, closestAngDiff = nav, math.huge, math.huge
		for el in root:traverseVisible() do
			if (el ~= nav and el:is(Cs.widget)) then
				local x, y = el._layoutX+el._layoutOffsetX, el._layoutY+el._layoutOffsetY
				x = math.min(math.max(navX, x+0.01), x+el._layoutWidth-0.01)
				y = math.min(math.max(navY, y+0.01), y+el._layoutHeight-0.01)
				local dx, dy = x-navX, y-navY
				local distSquared = dx*dx+dy*dy
				local angDiff = math.atan2(dy, dx)-targetAng
				angDiff = math.abs(math.atan2(math.sin(angDiff), math.cos(angDiff))) -- (normalize)
				if (angDiff < MAX_ANGLE_DIFF and distSquared <= closestDistSquared) then
					closestEl, closestDistSquared, closestAngDiff = el, distSquared, angDiff
				end
			end
			if (el._captureInput or el._captureGuiInput) then
				break
			end
		end
		setNavigationTarget(self, closestEl)

		return closestEl
	end

	-- state = canNavigateTo( element )
	-- Note: Does not check if navigation is locked
	function Gui:canNavigateTo(widget)
		if (widget == nil) then
			return true -- navigation target can always be nothing
		elseif not (widget:is(Cs.widget) and widget:isDisplayed()) then
			return false
		end
		local root = self._root
		if (not root or root._hidden) then
			return false
		end
		for el in root:traverseVisible() do
			if (el == widget) then
				return true
			elseif (el._captureInput or el._captureGuiInput) then
				return false
			end
		end
		error('somehow the element is a displayed active widget but not among the visible elements under the root')
	end

end



-- element = getRoot( )
Gui:defineGet('_root')



-- getScissorCoordsConverter, setScissorCoordsConverter
Gui:define('_scissorCoordsConverter')



-- getSoundPlayer, setSoundPlayer
-- soundPlayer( sound )
Gui:define('_soundPlayer')



-- getSpriteLoader, setSpriteLoader
-- sprite = spriteLoader( spriteName )
Gui:define('_spriteLoader')



-- callback, errorMessage = getTarget( target )
-- target: "ID.subID.anotherSubID"
function Gui:getTarget(target)
	local el = self._root
	if (not el) then
		return nil, 'there is no root element'
	end
	local ids = matchAll(target, '[^.]+')
	for i = 1, #ids do
		if (not el:is(Cs.container)) then
			return false, F'%q is not a container'(el._id)
		end
		el = el:find(ids[i])
		if (not el) then
			return nil, F'%q does not exist in %q'(ids[i], (ids[i-1] or 'root'))
		end
	end
	return el
end

-- callback, errorMessage = getTargetCallback( targetAndEvent )
-- targetAndEvent: "ID.subID.anotherSubID.event"
function Gui:getTargetCallback(targetAndEvent)
	local target, event = targetAndEvent:match('^(.-)%.?([^.]+)$')
	if (not target) then
		return nil, F'bad targetAndEvent value %q'(targetAndEvent)
	end
	local el, err = self:getTarget(target)
	if (not el) then
		return nil, err
	end
	return el:getCallback(event)
end

-- success, errorMessage = setTargetCallback( targetAndEvent, callback )
-- targetAndEvent: "ID.subID.anotherSubID.event"
function Gui:setTargetCallback(targetAndEvent, cb)
	local target, event = targetAndEvent:match('^(.-)%.?([^.]+)$')
	if (not target) then
		return nil, F'bad targetAndEvent value %q'(targetAndEvent)
	end
	local el, err = self:getTarget(target)
	if (not el) then
		return false, err
	end
	el:setCallback(event, cb)
	return true
end



-- state = isBusy( )
function Gui:isBusy()
	return (self._keyboardFocus ~= nil or self:isMouseBusy())
end

-- state = isMouseBusy( )
function Gui:isMouseBusy()
	return (self._mouseFocus ~= nil)
end



-- state = isIgnoringKeyboardInput( )
function Gui:isIgnoringKeyboardInput()
	return self._ignoreKeyboardInputThisFrame
end



-- state = isMouseGrabbed( )
function Gui:isMouseGrabbed()
	return self._mouseIsGrabbed
end

-- setMouseIsGrabbed( state )
function Gui:setMouseIsGrabbed(state)
	self._mouseIsGrabbed = state
end



-- handled = keyDown( key, scancode, isRepeat )
function Gui:keyDown(key, scancode, isRepeat)
	local focus = (self._keyboardFocus or self._mouseFocus)
	local el = (focus or self._hoveredElement)
	if (self._ignoreKeyboardInputThisFrame) then
		return (el ~= nil)
	end
	if (el) then
		if (not focus and el:trigger('keydown', key, scancode, isRepeat)) then
			return true
		end
		local handled, grabFocus = el:_keyDown(key, scancode, isRepeat)
		if (handled) then
			if (grabFocus) then
				setKeyboardFocus(self, el)
			end
			return true
		end
	end
	if (focus) then
		return true
	end
	local root = self._root
	if (root and not root._hidden) then
		for el in root:traverseVisible() do
			if (key == 'escape' and el:canClose()) then
				el:close()
				return true
			elseif (el._captureInput) then
				return true
			elseif (el._captureGuiInput) then
				break
			end
		end
	end
	return false
end

-- handled = keyUp( key, scancode )
function Gui:keyUp(key, scancode)
	local focus = self._keyboardFocus
	if (focus) then
		focus:_keyUp(key, scancode)
		return true
	end
	return false
end

-- handled = textInput( text )
function Gui:textInput(text)
	local focus = self._keyboardFocus
	if (focus) then
		focus:_textInput(text)
		return true
	end
	return false
end



-- load( data )
function Gui:load(data)
	if (data.type ~= 'root') then
		errorf('gui root element must be of type "root"')
	end
	self._root = Cs.root(self, data, nil)
	self._layoutNeedsUpdate = true
end



-- handled = mouseDown( x, y, button )
function Gui:mouseDown(x, y, buttonN)
	self._mouseX, self._mouseY = x, y

	if self._mouseFocusSet[buttonN] then
		return true -- Should be an error, but it's not really an issue.
	end

	local focus = self._mouseFocus
	if focus then
		self._mouseFocusSet[buttonN] = true
	end

	updateLayoutIfNeeded(self) -- Updates hovered element.

	local el = (focus or self._hoveredElement)
	if el then
		if el:trigger('mousedown',
			x-el._layoutX-el._layoutOffsetX,
			y-el._layoutY-el._layoutOffsetY,
			buttonN)
		then
			return true -- (suppress default behavior)
		end
		local handled, grabFocus = el:_mouseDown(x, y, buttonN)
		handled = (handled or el._captureInput or el._captureGuiInput or el:isSolid())
		if handled then
			if (grabFocus and not next(self._mouseFocusSet)) then
				setMouseFocus(self, el, buttonN)
			end
			return true
		end
	end

	return (focus ~= nil)
end

-- handled = mouseMove( x, y )
function Gui:mouseMove(x, y)
	self._mouseX, self._mouseY = x, y

	if not updateLayoutIfNeeded(self) then
		updateHoveredElement(self) -- Make sure hovered element updates whenever mouse moves.
	end

	local focus = self._mouseFocus
	if (not focus) then
		return false
	end

	local el = (focus or self._hoveredElement)
	if el then
		el:_mouseMove(x, y)
		el:trigger('mousemove',
			x-el._layoutX-el._layoutOffsetX,
			y-el._layoutY-el._layoutOffsetY)
	end

	return true
end

-- handled = mouseUp( x, y, button )
function Gui:mouseUp(x, y, buttonN)
	self._mouseX, self._mouseY = x, y

	local focus = self._mouseFocus
	if not (focus and self._mouseFocusSet[buttonN]) then
		return false
	end

	self._mouseFocusSet[buttonN] = nil

	updateLayoutIfNeeded(self) -- (updates hovered element)

	local el = (focus or self._hoveredElement)
	if el then
		el:_mouseUp(x, y, buttonN)
	end

	if not next(self._mouseFocusSet) then
		setMouseFocus(self, nil)
	end

	if el then
		el:trigger('mouseup',
			x-el._layoutX-el._layoutOffsetX,
			y-el._layoutY-el._layoutOffsetY,
			buttonN)
	end

	return true
end

-- handled = mouseWheel( dx, dy )
function Gui:mouseWheel(dx, dy)

	-- Focus
	local focus = self._mouseFocus
	if (focus) then
		return (focus:_mouseWheel(dx, dy) or focus:isSolid())
	end

	-- Hovered element (bubbling event)
	updateLayoutIfNeeded(self) -- (updates hovered element)
	local el, anyIsSolid = self._hoveredElement, false
	while (el) do
		if (el:_mouseWheel(dx, dy)) then
			return true
		end
		anyIsSolid = (anyIsSolid or el:isSolid())
		el = el._parent
	end
	return anyIsSolid

end



-- _setScissor( x, y, width, height )
-- NOTE: Must be called twice - first with arguments, then without
-- TODO: Make Gui._setScissor local
function Gui:_setScissor(x, y, w, h)
	if (not x) then
		LG.pop()
		return
	end
	local convert = self._scissorCoordsConverter
	if (convert) then
		x, y, w, h = convert(x, y, w, h)
	end
	LG.push('all')
	LG.intersectScissor(x, y, w, h)
end



-- handled = ok( )
function Gui:ok()
	local nav = self._navigationTarget
	if (nav and nav._active) then
		return nav:_ok()
	end
	return false
end

-- handled = back( )
function Gui:back()
	local root = self._root
	if (not root or root._hidden) then
		return false
	end

	-- Close closable (like Escape does)
	for el in root:traverseVisible() do
		if (el:canClose()) then
			el:close()
			return true
		elseif (el._captureInput or el._captureGuiInput) then
			break
		end
	end

	return false
end



-- Force a layout update (should never be needed as it's done automatically)
-- updateLayout( )
function Gui:updateLayout()
	local root = self._root
	if (root and not root._hidden) then
		return updateLayout(root)
	end
end



--==============================================================
--= Element ====================================================
--==============================================================



Cs.element = newClass('GuiElement', {

	MENU_PADDING = 0,

	_callbacks = nil,
	_gui = nil,
	_layoutExpandablesX = 0, _layoutExpandablesY = 0,
	_layoutInnerMarginsX = 0, _layoutInnerMarginsY = 0,
	_layoutInnerStaticWidth = 0, _layoutInnerStaticHeight = 0,
	_layoutInnerWidth = 0, _layoutInnerHeight = 0,
	_layoutOffsetX = 0, _layoutOffsetY = 0, -- sum of parent's scrolling
	_layoutWidth = 0, _layoutHeight = 0,
	_layoutX = 0, _layoutY = 0,
	_parent = nil,

	_anchorX = 0.0, _anchorY = 0.0, -- where in self to base off x and y
	_background = nil,
	_captureInput = false, --[[all input]] _captureGuiInput = false, --[[all input affecting GUI]]
	_closable = false,
	_data = nil,
	_floating = false, -- disables natural positioning in certain parents (e.g. bars)
	_hidden = false,
	_id = '',
	_margin = 0, _marginVertical = nil, _marginHorizontal = nil,
	_marginTop = nil, _marginRight = nil, _marginBottom = nil, _marginLeft = nil,
	_originX = 0.0, _originY = 0.0, -- where in the parent to base x and y off
	_sounds = nil,
	_tooltip = '',
	_width = nil, _height = nil,
	_x = 0, _y = 0, -- offset from origin

	data = nil,

})

function Cs.element:init(gui, data, parent)

	self._gui = assert(gui)
	self._parent = parent
	self._callbacks = {}

	if (data.style) then
		local styleData = gui._styles[data.style]
			or errorf('bad style name %q', data.style)
		applyStyle(data, styleData)
	end

	retrieve(self, data, '_anchorX', '_anchorY')
	retrieve(self, data, '_background')
	retrieve(self, data, '_captureInput', '_captureGuiInput')
	retrieve(self, data, '_closable')
	-- retrieve(self, data, '_data')
	retrieve(self, data, '_floating')
	retrieve(self, data, '_hidden')
	retrieve(self, data, '_id')
	retrieve(self, data, '_margin', '_marginVertical', '_marginHorizontal')
	retrieve(self, data, '_marginTop', '_marginRight', '_marginBottom', '_marginLeft')
	retrieve(self, data, '_originX', '_originY')
	-- retrieve(self, data, '_sounds')
	retrieve(self, data, '_tooltip')
	retrieve(self, data, '_width', '_height')
	retrieve(self, data, '_x', '_y')

	-- Set data table
	assert(data.data == nil or type(data.data) == 'table')
	self._data = (data.data or {})
	self.data = self._data -- element.data is exposed for easy access

	-- Set sounds table
	self._sounds = {}
	if (data.sounds ~= nil) then
		assert(type(data.sounds) == 'table')
		for soundK, sound in pairs(data.sounds) do
			checkValidSoundKey(soundK)
			self._sounds[soundK] = sound
		end
	end

	-- Make sure the element has an ID
	if (self._id == '') then
		local numId = gui._lastAutomaticId+1
		gui._lastAutomaticId = numId
		self._id = '__'..numId
	end

	-- Set initial offset
	if (parent) then
		self._layoutOffsetX = parent._layoutOffsetX+parent._scrollX
		self._layoutOffsetY = parent._layoutOffsetY+parent._scrollY
	end

	if (data.debug) then
		gui.debug = true
	end

end



-- _update( deltaTime )
function Cs.element:_update(dt)
	-- void
end



-- _draw( )
function Cs.element:_draw()
	local x, y = self._layoutX+self._layoutOffsetX, self._layoutY+self._layoutOffsetY
	local w, h = self._layoutWidth, self._layoutHeight
	self:trigger('beforedraw', x, y, w, h)
	drawBackground(self)
	self:trigger('afterdraw', x, y, w, h)
end

-- _drawDebug( red, green, blue [, backgroundOpacity=1 ] )
function Cs.element:_drawDebug(r, g, b, bgOpacity)
	local gui = self._gui
	if (not gui.debug) then
		return
	end
	local w, h = self._layoutWidth, self._layoutHeight
	local x1, y1 = self._layoutX, self._layoutY
	local x2, y2 = x1+w, y1+h
	local p = (self:is(Cs.container) and self._padding or 0)
	local lw = math.max(p, 1)

	-- Background and center line
	LG.setColor(r, g, b, 80*(bgOpacity or 1))
	LG.rectangle('fill', x1, y1, w, h)
	LG.line(x1+p, y1+p, x1+w/2, y1+h/2)

	-- Border
	LG.setLineWidth(lw)
	LG.setColor(r, g, b, 100)
	LG.rectangle('line', x1+lw/2, y1+lw/2, w-lw, h-lw)
	LG.setLineWidth(1)
	LG.setColor(r, g, b, 150)
	LG.rectangle('line', x1+0.5, y1+0.5, w-1, h-1)

	-- Class/ID
	r, g, b = lerp(r, 255, 0.5), lerp(g, 255, 0.5), lerp(b, 255, 0.5)
	LG.setFont(gui._font)
	LG.setColor(r, g, b, 200)
	LG.print(self:getDepth()..':'..self._id, x1, y1)

end

-- _drawTooltip( )
function Cs.element:_drawTooltip()
	local gui = self._gui
	local text = self._tooltip
	if (text == '' or gui._tooltipTime < gui.TOOLTIP_DELAY) then
		return
	end
	local p = 3 -- padding
	local root, font = gui._root, gui._font
	local w, h = getTextDimensions(font, text)
	w, h = w+2*p, h+2*p
	local x = math.max(math.min(self._layoutX, root._width-w), 0)
	local y = self._layoutY+self._layoutHeight
	if (y+h > root._height) then
		y = math.max(y-h-self._layoutHeight, 0)
	end

	-- Background
	LG.setColor(255, 255, 255)
	LG.rectangle('fill', x+1, y+1, w-2, h-2)
	LG.setColor(0, 0, 0)
	LG.rectangle('line', x+0.5, y+0.5, w-1, h-1)

	-- Text
	LG.setFont(font)
	LG.setColor(0, 0, 0)
	LG.print(text, x+p, y+p)

end



-- success = close( )
function Cs.element:close()
	if (not self:canClose()) then
		return false
	end
	local preparedSound = prepareSound(self, 'close')
	if (self:trigger('close')) then
		return false -- (suppress default behavior)
	end
	preparedSound()
	self:hide()
	self:triggerBubbling('closed', self)
	return true
end

-- result = canClose( )
function Cs.element:canClose()
	return (self._closable and not self._gui._lockNavigation and self:isDisplayed())
end



-- state = exists( )
function Cs.element:exists()
	return (self._gui ~= nil)
end



-- anchorX, anchorY = getAnchor( )
function Cs.element:getAnchor()
	return self._anchorX, self._anchorY
end

-- setAnchor( anchorX, anchorY )
function Cs.element:setAnchor(anchorX, anchorY)
	if (self._anchorX == anchorX and self._anchorY == anchorY) then
		return
	end
	self._anchorX, self._anchorY = anchorY
	scheduleLayoutUpdateIfDisplayed(self)
end

-- getAnchorX
Cs.element:defineGet('_anchorX')

-- setAnchorX( anchorX )
function Cs.element:setAnchorX(anchorX)
	if (self._anchorX == anchorX) then
		return
	end
	self._anchorX = anchorX
	scheduleLayoutUpdateIfDisplayed(self)
end

-- getAnchorY
Cs.element:defineGet('_anchorY')

-- setAnchorY( anchorY )
function Cs.element:setAnchorY(anchorY)
	if (self._anchorY == anchorY) then
		return
	end
	self._anchorY = anchorY
	scheduleLayoutUpdateIfDisplayed(self)
end



-- callback = getCallback( event )
function Cs.element:getCallback(event)
	return self._callbacks[event]
end

-- setCallback( event, callback )
function Cs.element:setCallback(event, cb)
	self._callbacks[event] = cb
end

-- value = trigger( event [, extraArguments... ] )
function Cs.element:trigger(event, ...)
	local callbacks = self._callbacks
	local cb = callbacks[event] or callbacks['*']
	if (cb) then
		return cb(self, event, ...)
	end
	return nil
end

-- triggerBubbling( event [, extraArguments... ] )
function Cs.element:triggerBubbling(...)
	local el = self
	repeat
		local returnV = el:trigger(...)
		el = el._parent
	until (returnV or not el)
end



-- Returns closest ancestor matching elementType (including self)
-- element = getClosest( elementType )
function Cs.element.getClosest(el, elType)
	local C = Cs[elType] or errorf('bad gui type %q', elType)
	repeat
		if (el:is(C)) then
			return el
		end
		el = el._parent
	until (not el)
	return nil
end



-- value = getData( key )
-- NOTE: element:getData(k) is the same as element.data[k]
function Cs.element:getData(k)
	return self._data[k]
end

-- setData( key, value )
-- NOTE: element:setData(key, value) is the same as element.data[key]=value
function Cs.element:setData(k, v)
	self._data[k] = v
end

-- oldDataTable = swapData( newDataTable )
function Cs.element:swapData(data)
	assertArg(1, data, 'table')
	local oldData = self._data
	self._data, self.data = data, data
	return oldData
end



-- width, height = getDimensions( )
function Cs.element:getDimensions()
	return self._width, self._height
end

-- setDimensions( width, height )
function Cs.element:setDimensions(w, h)
	if (self._width == w and self._height == h) then
		return
	end
	self._width, self._height = w, h
	scheduleLayoutUpdateIfDisplayed(self)
end

-- getWidth
Cs.element:defineGet('_width')

-- setWidth( width )
function Cs.element:setWidth(w)
	if (self._width == w) then
		return
	end
	self._width = w
	scheduleLayoutUpdateIfDisplayed(self)
end

-- getHeight
Cs.element:defineGet('_height')

-- setHeight( height )
function Cs.element:setHeight(w)
	if (self._height == h) then
		return
	end
	self._height = h
	scheduleLayoutUpdateIfDisplayed(self)
end



-- getGui
Cs.element:defineGet('_gui')



-- getId
Cs.element:defineGet('_id')

-- state = hasId( id [, id2... ] )
function Cs.element:hasId(id, ...)
	if (self._id == id) then
		return true
	elseif (...) then
		return self:hasId(...)
	end
	return false
end



-- index = getIndex( )
function Cs.element:getIndex()
	local parent = self._parent
	return (parent and parent:indexOf(self))
end

-- depth = getDepth( )
function Cs.element:getDepth()
	local depth, current = 0, self
	while true do
		current = current._parent
		if (not current) then
			return depth
		end
		depth = depth+1
	end
end



-- x, y, width, height = getLayout( )
function Cs.element:getLayout()
	updateLayoutIfNeeded(self._gui)
	return self._layoutX, self._layoutY, self._layoutWidth, self._layoutHeight
end



-- width, height = getLayoutDimensions( )
function Cs.element:getLayoutDimensions()
	updateLayoutIfNeeded(self._gui)
	return self._layoutWidth, self._layoutHeight
end

-- width = getLayoutWidth( )
function Cs.element:getLayoutWidth()
	updateLayoutIfNeeded(self._gui)
	return self._layoutWidth
end

-- height = getLayoutHeight( )
function Cs.element:getLayoutHeight()
	updateLayoutIfNeeded(self._gui)
	return self._layoutHeight
end



-- x, y = getLayoutPosition( )
function Cs.element:getLayoutPosition()
	updateLayoutIfNeeded(self._gui)
	return self._layoutX, self._layoutY
end

-- x = getLayoutX( )
function Cs.element:getLayoutX()
	updateLayoutIfNeeded(self._gui)
	return self._layoutX
end

-- y = getLayoutY( )
function Cs.element:getLayoutY()
	updateLayoutIfNeeded(self._gui)
	return self._layoutY
end

-- x, y = getLayoutCenterPosition( )
function Cs.element:getLayoutCenterPosition()
	updateLayoutIfNeeded(self._gui)
	return self._layoutX+self._layoutWidth*0.5,
		self._layoutY+self._layoutHeight*0.5
end



-- originX, originY = getOrigin( )
function Cs.element:getOrigin()
	return self._originX, self._originY
end

-- setOrigin( originX, originY )
function Cs.element:setOrigin(originX, originY)
	if (self._originX == originX and self._originY == originY) then
		return
	end
	self._originX, self._originY = originX, originY
	scheduleLayoutUpdateIfDisplayed(self)
end

-- getOriginX
Cs.element:defineGet('_originX')

-- setOriginX( originX )
function Cs.element:setOriginX(originX)
	if (self._originX == originX) then
		return
	end
	self._originX = originX
	scheduleLayoutUpdateIfDisplayed(self)
end

-- getOriginY
Cs.element:defineGet('_originY')

-- setOriginY( originY )
function Cs.element:setOriginY(originY)
	if (self._originY == originY) then
		return
	end
	self._originY = originY
	scheduleLayoutUpdateIfDisplayed(self)
end



-- getParent
Cs.element:defineGet('_parent')

-- parents = getParents( )
-- Returns parents, with the closest parent first
function Cs.element:getParents()
	local el, parents, i = self, {}, 0
	while true do
		el = el._parent
		if (not el) then
			return parents
		end
		i = i+1
		parents[i] = el
	end
end

-- result = hasParent( parent )
-- Note: Checks all grandparents too
function Cs.element.hasParent(el, parent)
	while true do
		el = el._parent
		if (not el) then
			return false
		elseif (el == parent) then
			return true
		end
	end
	return false
end

-- result = hasParentWithId( id )
function Cs.element.hasParentWithId(el, id)
	while true do
		el = el._parent
		if (not el) then
			return false
		elseif (el._id == id) then
			return true
		end
	end
	return false
end

-- for index, parent in parents( ) do
do
	local function traverseParents(el)
		local i = 0
		while true do
			el = el._parent
			if (not el) then
				return
			end
			i = i+1
			coroutine.yield(i, el)
		end
	end
	function Cs.element:parents()
		return newIteratorCoroutine(traverseParents, self)
	end
end

-- for index, parent in parentsr( ) do
function Cs.element:parentsr()
	return ipairs(reverseArray(self:getParents()))
end



-- description = getPathDescription( )
function Cs.element:getPathDescription()
	local parts, el = {}, self
	while true do
		local id, i = el._id, el:getIndex()
		if (id:find('__', 1, true) ~= 1) then
			table.insert(parts, ')')
			table.insert(parts, el._id)
			table.insert(parts, '(')
		end
		table.insert(parts, (el.class.__name:gsub('^Gui', '')))
		if (i) then
			table.insert(parts, ':')
			table.insert(parts, i)
		end
		el = el._parent
		if (not el) then
			break
		end
		table.insert(parts, '/')
	end
	return table.concat(reverseArray(parts))
end



-- x, y = getPosition( )
function Cs.element:getPosition()
	return self._x, self._y
end

-- setPosition( x, y )
function Cs.element:setPosition(x, y)
	if (self._x == x and self._y == y) then
		return
	end
	self._x, self._y = x, y
	scheduleLayoutUpdateIfDisplayed(self)
end

-- getX
Cs.element:defineGet('_x')

-- setX( x )
function Cs.element:setX(x)
	if (self._x == x) then
		return
	end
	self._x = x
	scheduleLayoutUpdateIfDisplayed(self)
end

-- getY
Cs.element:defineGet('_y')

-- setY( y )
function Cs.element:setY(y)
	if (self._y == y) then
		return
	end
	self._y = y
	scheduleLayoutUpdateIfDisplayed(self)
end



-- root = getRoot( )
function Cs.element:getRoot()
	local el = self
	repeat
		if (el.class == Cs.root) then
			return el
		end
		el = el._parent
	until (not el)
	return nil -- we've probably been removed
end



-- sound = getSound( soundKey )
function Cs.element:getSound(soundK)
	assertArg(1, soundK, 'string')
	checkValidSoundKey(soundK)
	return self._sounds[soundK]
end

-- sound = getResultingSound( soundKey )
function Cs.element:getResultingSound(soundK)
	assertArg(1, soundK, 'string')
	checkValidSoundKey(soundK)
	local sound = self._sounds[soundK]
	if (sound == nil) then
		for _, parent in self:parents() do
			sound = parent._sounds[soundK]
			if (sound ~= nil) then
				break
			end
		end
		if (sound == nil) then
			local gui = self._gui
			if (gui) then
				sound = gui._defaultSounds[soundK]
			end
		end
	end
	if (sound == '') then
		sound = nil -- special case: An empty string intercepts the bubbling and tells that no sound should be played
	end
	return sound
end

-- setSound( soundKey, sound )
-- setSound( soundKey, nil ) -- remove sound
function Cs.element:setSound(soundK, sound)
	assertArg(1, soundK, 'string')
	checkValidSoundKey(soundK)
	self._sounds[soundK] = sound
end



-- getTooltip, setTooltip
Cs.element:define('_tooltip')



-- result = isAt( x, y )
function Cs.element:isAt(x, y)
	updateLayoutIfNeeded(self._gui)
	x, y = x-self._layoutOffsetX, y-self._layoutOffsetY
	return (x >= self._layoutX and y >= self._layoutY
		and x < self._layoutX+self._layoutWidth and y < self._layoutY+self._layoutHeight)
end



-- handled, grabFocus = _keyDown( key, scancode, isRepeat )
function Cs.element:_keyDown(key, scancode, isRepeat)
	return false, false
end

-- _keyUp( key, scancode )
function Cs.element:_keyUp(key, scancode)
	-- void
end

-- _textInput( text )
function Cs.element:_textInput(text)
	-- void
end



-- handled, grabFocus = _mouseDown( x, y, button )
function Cs.element:_mouseDown(x, y, buttonN)
	return false, false
end

-- _mouseMove( x, y )
function Cs.element:_mouseMove(x, y)
	-- void
end

-- _mouseUp( x, y, button )
function Cs.element:_mouseUp(x, y, buttonN)
	-- void
end

-- handled = _mouseWheel( deltaX, deltaY )
function Cs.element:_mouseWheel(dx, dy)
	return false
end



-- state = isDisplayed( )
-- Returns true if the element exists, and it and it's parents are visible
function Cs.element:isDisplayed()
	local el = self
	if (not el:exists()) then
		return false
	end
	repeat
		if (el._hidden) then
			return false
		end
		el = el._parent
	until (not el)
	return true
end

-- element = getClosestHiddenElement( )
function Cs.element:getClosestHiddenElement()
	local el = self
	repeat
		if (el._hidden) then
			return el
		end
		el = el._parent
	until (not el)
	return nil
end

-- element = getFarthestHiddenElement( )
function Cs.element:getFarthestHiddenElement()
	local el, hiddenEl = self, nil
	repeat
		if (el._hidden) then
			hiddenEl = el
		end
		el = el._parent
	until (not el)
	return hiddenEl
end



-- state = isHidden( )
function Cs.element:isHidden()
	return self._hidden
end

-- state = isVisible( )
function Cs.element:isVisible()
	return (not self._hidden)
end

-- stateChanged = setHidden( state )
function Cs.element:setHidden(state)
	if (self._hidden == state) then
		return false
	end
	self._hidden = state

	if (state == true) then
		validateNavigationTarget(self._gui)
	end

	scheduleLayoutUpdateIfDisplayed(self._parent or self)

	self:trigger(state and 'hide' or 'show')
	return true
end

-- stateChanged = setVisible( state )
function Cs.element:setVisible(state)
	return self:setHidden(not state)
end

-- stateChanged = show( )
function Cs.element:show()
	return self:setHidden(false)
end

-- stateChanged = hide( )
function Cs.element:hide()
	return self:setHidden(true)
end

-- toggleHidden( )
function Cs.element:toggleHidden()
	return self:setHidden(not self._hidden)
end



-- state = isHovered( [ checkFocus=false ] )
function Cs.element:isHovered(checkFocus)
	local gui = self._gui
	updateLayoutIfNeeded(gui) -- (updates hovered element)
	return (self == gui._hoveredElement) and not (checkFocus and self ~= (gui._mouseFocus or self))
end



-- state = isMouseFocus( )
function Cs.element:isMouseFocus()
	return (self == self._gui._mouseFocus)
end

-- state = isKeyboardFocus( )
function Cs.element:isKeyboardFocus()
	return (self == self._gui._keyboardFocus)
end



-- state = isNavigationTarget( )
function Cs.element:isNavigationTarget()
	return (self == self._gui._navigationTarget)
end



-- state = isSolid( )
function Cs.element:isSolid()
	return false
end



-- result = isType( elementType )
function Cs.element:isType(elType)
	local C = Cs[elType] or errorf('bad gui type %q', elType)
	return self:is(C)
end



-- Trigger helper event "refresh"
-- refresh( )
function Cs.element:refresh()
	self:trigger('refresh')
end



-- handled = _ok( )
function Cs.element:_ok()
	return false
end



-- remove( )
function Cs.element:remove()
	local parent = self._parent
	if (parent) then
		parent:remove(parent:indexOf(self))
	end
end



-- scrollIntoView( )
function Cs.element.scrollIntoView(el)
	updateLayoutIfNeeded(el._gui)
	local x1, y1 = el._layoutX+el._layoutOffsetX, el._layoutY+el._layoutOffsetY
	local x2, y2 = x1+el._layoutWidth, y1+el._layoutHeight
	repeat
		local parent = el._parent
		local maxW, maxH = parent._maxWidth, parent._maxHeight
		if (maxW or maxH) then
			local scrollX, scrollY = parent._scrollX, parent._scrollY
			if (maxW) then
				local distOutside = x2-(parent._layoutX+parent._layoutOffsetX+maxW)
				if (distOutside > 0) then
					scrollX = scrollX-distOutside
				else
					distOutside = (parent._layoutX+parent._layoutOffsetX)-x1
					if (distOutside > 0) then
						scrollX = scrollX+distOutside
					end
				end
				x1 = el._layoutX+el._layoutOffsetX
				x2 = x1+el._layoutWidth
			end
			if (maxH) then
				local distOutside = y2-(parent._layoutY+parent._layoutOffsetY+maxH)
				if (distOutside > 0) then
					scrollY = scrollY-distOutside
				else
					distOutside = (parent._layoutY+parent._layoutOffsetY)-y1
					if (distOutside > 0) then
						scrollY = scrollY+distOutside
					end
				end
				y1 = el._layoutY+el._layoutOffsetY
				y2 = y1+el._layoutHeight
			end
			parent:setScroll(scrollX, scrollY)
		end
		el, parent = parent, parent._parent
	until (not parent)
end



-- menuElement = showMenu( items, [ highlightedIndex, ] [ offsetX=0, offsetY=0, ] callback )
-- items = { itemText... }
-- items = { { itemText, itemExtraText }... }
-- callback = function( index, itemText )
--    index will be 0 if no item was chosen.
function Cs.element:showMenu(items, highlightI, offsetX, offsetY, cb)
	assertArg(1, items, 'table')

	-- showMenu( items, highlightedIndex, offsetX, offsetY, callback )
	if (type(highlightI) == 'number' and type(offsetX) == 'number' and type(offsetY) == 'number') then
		-- void

	-- showMenu( items, offsetX, offsetY, callback )
	elseif (type(highlightI) == 'number' and type(offsetX) == 'number') then
		highlightI, offsetX, offsetY, cb = nil, highlightI, offsetX, offsetY

	-- showMenu( items, highlightedIndex, callback )
	elseif (type(highlightI) == 'number') then
		offsetX, offsetY, cb = 0, 0, offsetX

	-- showMenu( items, callback )
	else
		highlightI, offsetX, offsetY, cb = nil, 0, 0, highlightI

	end
	if type(cb) ~= 'function' then
		error('Missing callback argument.', 2)
	end

	local gui = self._gui
	local root = self:getRoot()
	local p = self.MENU_PADDING

	updateLayoutIfNeeded(gui) -- So we get the correct self position here below.

	-- Create menu.
	local menu = root:insert{
		type='container', expandX=true, expandY=true, background='cover', closable=true, captureGuiInput=true,
		[1] = {type='vbar', id='_buttons', background='shadow', padding=p, maxHeight=root:getHeight()},
	}
	menu:setCallback('closed', function(button, event)
		if cb then
			cb(0, '')
			cb = nil
		end
	end)
	menu:setCallback('mousedown', function(button, event, x, y, buttonN)
		menu:close()
	end)

	-- Add menu items.
	local buttons = menu:find('_buttons')
	for i, text in ipairs(items) do
		local text2 = nil
		if type(text) == 'table' then
			text, text2 = unpack(text)
		end
		local isToggled = (i == highlightI)
		local button = buttons:insert{ type='button', text=text, text2=text2, align='left', toggled=isToggled }
		button:setCallback('press', function(button, event)
			menu:remove()
			if cb then
				cb(i, text)
				cb = nil
			end
		end)
		if isToggled then
			gui:navigateTo(button)
		end
	end

	-- Set position.
	-- @Incomplete: Make the menu (at least) as wide as self.
	buttons:_updateLayoutSize() -- Expanding and positioning of the whole menu isn't necessary right here.
	buttons:setPosition(
		self._layoutX+self._layoutOffsetX+offsetX-p,
		math.max(math.min(self._layoutY+self._layoutOffsetY+offsetY-p, root._height-buttons._layoutHeight), 0)
	)

	return menu
end



-- Force a layout update (should never be needed as it's done automatically)
-- FINAL
-- updateLayout( )
function Cs.element:updateLayout()
	return updateLayout(self)
end

-- _updateLayoutSize( )
function Cs.element:_updateLayoutSize()
	-- void (subclasses should replace this method)
end

-- _expandLayout( [ expandWidth, expandHeight ] )
function Cs.element:_expandLayout(expandW, expandH)
	if (expandW) then
		self._layoutWidth = expandW
		self._layoutInnerWidth = self._layoutWidth
	end
	if (expandH) then
		self._layoutHeight = expandH
		self._layoutInnerHeight = self._layoutHeight
	end
end

-- _updateLayoutPosition( )
function Cs.element:_updateLayoutPosition()
	-- void (position is always set by the parent container)
end



--==============================================================
--= Container ==================================================
--==============================================================



Cs.container = Cs.element:extend('GuiContainer', {

	SCROLL_SPEED_X = 20, SCROLL_SPEED_Y = 20,
	SCROLLBAR_WIDTH = 4, SCROLLBAR_MIN_LENGTH = 8,

	_scrollX = 0, _scrollY = 0,

	_expandX = false, _expandY = false,
	_maxWidth = nil, _maxHeight = nil,
	_padding = 0,
	_solid = false,

})

function Cs.container:init(gui, data, parent)
	Cs.container.super.init(self, gui, data, parent)

	retrieve(self, data, '_expandX', '_expandY')
	retrieve(self, data, '_maxWidth', '_maxHeight')
	retrieve(self, data, '_padding')
	retrieve(self, data, '_solid')

	for i, childData in ipairs(data) do
		local C = Cs[childData.type] or errorf('bad gui type %q', childData.type)
		self[i] = C(gui, childData, self)
	end

end



-- OVERRIDE _update( deltaTime )
function Cs.container:_update(dt)
	Cs.container.super._update(self, dt)
	for _, child in ipairs(self) do
		child:_update(dt)
	end
end



-- REPLACE _draw( )
function Cs.container:_draw()
	if (self._hidden) then
		return
	end
	local x, y = self._layoutX+self._layoutOffsetX, self._layoutY+self._layoutOffsetY
	local w, h = self._layoutWidth, self._layoutHeight

	-- Scissor
	local scissorX, scissorY, scissorW, scissorH = 0, 0, self._gui:getRoot():getDimensions()
	if (self._maxWidth) then
		scissorX, scissorW = x, w
	end
	if (self._maxHeight) then
		scissorY, scissorH = y, h
	end
	self._gui:_setScissor(scissorX, scissorY, scissorW, scissorH)

	self:trigger('beforedraw', x, y, w, h)

	-- Layout background
	drawBackground(self)

	self:_drawDebug(0, 0, 255)

	for _, child in ipairs(self) do
		child:_draw()
	end

	self:trigger('afterdraw', x, y, w, h)

	-- Scrollbars
	local sbW = self.SCROLLBAR_WIDTH
	local insideW = (w-2*self._padding)
	local insideH = (h-2*self._padding)
	if (self._maxWidth and self._layoutInnerWidth > insideW) then
		local handleLen = math.max(round(w*insideW/self._layoutInnerWidth), self.SCROLLBAR_MIN_LENGTH)
		local x, y = round(x-(w-handleLen)*(self._scrollX/(self._layoutInnerWidth-insideW))), y+h-sbW
		LG.setColor(0, 0, 0, 100)
		LG.rectangle('fill', x, y, handleLen, sbW)
		LG.setColor(255, 255, 255, 200)
		LG.rectangle('fill', x+1, y+1, handleLen-2, sbW-2)
	end
	if (self._maxHeight and self._layoutInnerHeight > insideH) then
		local handleLen = math.max(round(h*insideH/self._layoutInnerHeight), self.SCROLLBAR_MIN_LENGTH)
		local x, y = x+w-sbW, round(y-(h-handleLen)*(self._scrollY/(self._layoutInnerHeight-insideH)))
		LG.setColor(0, 0, 0, 100)
		LG.rectangle('fill', x, y, sbW, handleLen)
		LG.setColor(255, 255, 255, 200)
		LG.rectangle('fill', x+1, y+1, sbW-2, handleLen-2)
	end

	self._gui:_setScissor(nil)
end



-- element = find( id )
function Cs.container:find(id)
	for el in self:traverse() do
		if (el._id == id) then
			return el
		end
	end
	return nil
end

-- elements = findAll( id )
function Cs.container:findAll(id)
	local els = {}
	for el in self:traverse() do
		if (el._id == id) then
			table.insert(els, el)
		end
	end
	return els
end

-- widget = findActive( )
function Cs.container:findActive()
	for el in self:traverse() do
		if (el:is(Cs.widget) and el._active) then
			return el
		end
	end
	return nil
end

-- button = findToggled( )
function Cs.container:findToggled()
	for el in self:traverse() do
		if (el:is(Cs.button) and el._toggled) then
			return el
		end
	end
	return nil
end



-- getMaxWidth
Cs.container:defineGet('_maxWidth')

-- setMaxWidth( width )
-- width: nil removes restriction
function Cs.container:setMaxWidth(w)
	w = (w and math.max(w, 0) or nil)
	if (self._maxWidth == w) then
		return
	end
	self._maxWidth = w
	scheduleLayoutUpdateIfDisplayed(self)
end

-- getMaxHeight
Cs.container:defineGet('_maxHeight')

-- setMaxHeight( height )
-- height: nil removes restriction
function Cs.container:setMaxHeight(h)
	h = (h and math.max(h, 0) or nil)
	if (self._maxHeight == h) then
		return
	end
	self._maxHeight = h
	scheduleLayoutUpdateIfDisplayed(self)
end



-- getPadding
Cs.container:defineGet('_padding')

-- setPadding( padding )
function Cs.container:setPadding(p)
	if (self._padding == p) then
		return
	end
	self._padding = p
	scheduleLayoutUpdateIfDisplayed(self)
end



-- x, y = getScroll( )
function Cs.container:getScroll()
	return self._scrollX, self._scrollY
end

-- setScroll( x, y )
function Cs.container:setScroll(scrollX, scrollY)
	updateLayoutIfNeeded(self._gui)

	-- Limit scrolling
	scrollX = math.min(math.max(scrollX, self._layoutWidth-2*self._padding-self._layoutInnerWidth), 0)
	scrollY = math.min(math.max(scrollY, self._layoutHeight-2*self._padding-self._layoutInnerHeight), 0)
	local dx, dy = scrollX-self._scrollX, scrollY-self._scrollY
	if (dx == 0 and dy == 0) then
		return
	end

	self._scrollX, self._scrollY = scrollX, scrollY

	-- Offset all elements below self
	for el in self:traverse() do
		el._layoutOffsetX = el._layoutOffsetX+dx
		el._layoutOffsetY = el._layoutOffsetY+dy
	end

	if (self:isDisplayed()) then
		playSound(self, 'scroll') -- (may have to add more limitations to whether "scroll" sound plays or not)
		updateHoveredElement(self._gui)
	end
end

-- scroll( deltaX, deltaY )
function Cs.container:scroll(dx, dy)
	self:setScroll(self._scrollX+dx, self._scrollY+dy)
end

-- updateScroll( )
-- TODO: Update scroll automatically when elements change size etc.
function Cs.container:updateScroll()
	self:scroll(0, 0)
end



-- child = getVisibleChild( [ number=1 ] )
function Cs.container:getVisibleChild(n)
	n = (n or 1)
	for _, child in ipairs(self) do
		if (not child._hidden) then
			n = n-1
			if (n == 0) then
				return child
			end
		end
	end
	return nil
end

-- number = getVisibleChildNumber( child )
function Cs.container:getVisibleChildNumber(el)
	local n = 0
	for _, child in ipairs(self) do
		if (not child._hidden) then
			n = n+1
			if (child == el) then
				return n
			end
		end
	end
	return nil
end

-- count = getVisibleChildCount( )
function Cs.container:getVisibleChildCount()
	local count = 0
	for _, child in ipairs(self) do
		if (not child._hidden) then
			count = count+1
		end
	end
	return count
end

-- visibleChild = setVisibleChild( id )
function Cs.container:setVisibleChild(id)
	local visibleChild = nil
	for _, child in ipairs(self) do
		if (child._id == id) then
			child:show()
			visibleChild = child
		else
			child:hide()
		end
	end
	return visibleChild -- if multiple children matched then the last match is returned
end



-- index = indexOf( element )
function Cs.container:indexOf(el)
	for i, child in ipairs(self) do
		if (child == el) then
			return i
		end
	end
	return nil
end



-- REPLACE state = isSolid( )
function Cs.container:isSolid()
	return (self._solid or self._background ~= nil or self._maxWidth ~= nil or self._maxHeight ~= nil)
end



-- child, index = get( index )
-- child, index = get( id )
-- NOTE: parent:get(index) is the same as parent[index]
function Cs.container:get(iOrId)
	if (type(iOrId) == 'string') then
		for i, child in ipairs(self) do
			if (child._id == iOrId) then
				return child, i
			end
		end
		return nil
	else
		local child = self[iOrId]
		return child, (child and iOrId or nil)
	end
end

-- for index, child in children( )
function Cs.container:children()
	return ipairs(self)
end



-- child = getChildWithData( dataKey, dataValue )
function Cs.container:getChildWithData(k, v)
	for _, child in ipairs(self) do
		if (child._data[k] == v) then
			return child
		end
	end
	return nil
end



-- element = getElementAt( x, y [, includeNonSolid=false ] )
function Cs.container:getElementAt(x, y, nonSolid)
	updateLayoutIfNeeded(self._gui)
	if (self._maxWidth) and (x < self._layoutX or x >= self._layoutX+self._layoutWidth) then
		return nil
	end
	if (self._maxHeight) and (y < self._layoutY or y >= self._layoutY+self._layoutHeight) then
		return nil
	end
	for el in self:traverseVisible(x, y) do
		if ((nonSolid or el:isSolid()) and el:isAt(x, y)) or (el._captureInput or el._captureGuiInput) then
			return el
		end
	end
	return nil
end



-- child = insert( data [, index=last ] )
function Cs.container:insert(childData, i)

	local C = Cs[childData.type] or errorf('bad gui type %q', childData.type)
	local child = C(self._gui, childData, self)
	table.insert(self, (i or #self+1), child)

	validateNavigationTarget(self._gui)
	scheduleLayoutUpdateIfDisplayed(self)

	return child
end

-- REPLACE remove( [ index ] )
function Cs.container:remove(i)
	if (not i) then
		return Cs.container.super.remove(self) -- remove self instead of child
	end

	local child = self[i] or errorf('bad child index (out of bounds)')
	if (child:is(Cs.container)) then
		child:empty()
	end
	child._gui, child._parent = nil, nil
	table.remove(self, i)

	validateNavigationTarget(self._gui)
	scheduleLayoutUpdateIfDisplayed(self)
end

-- empty( )
function Cs.container:empty()
	for i = #self, 1, -1 do
		self:remove(i)
	end
end



-- REPLACE handled = _mouseWheel( deltaX, deltaY )
function Cs.container:_mouseWheel(dx, dy)
	if (dx ~= 0 and self._maxWidth) or (dy ~= 0 and self._maxHeight) then
		self:scroll(self.SCROLL_SPEED_X*dx, self.SCROLL_SPEED_Y*dy)
		return true
	end
	return false
end



-- setChildrenActive( state )
function Cs.container:setChildrenActive(state)
	for _, child in ipairs(self) do
		if (child:is(Cs.widget)) then
			child:setActive(state)
		end
	end
end



-- setChildrenHidden( state )
function Cs.container:setChildrenHidden(state)
	for _, child in ipairs(self) do
		child:setHidden(state)
	end
end



-- widget = setToggledChild( id [, includeGrandchildren=false ] )
function Cs.container:setToggledChild(id, deep)
	local toggledChild = nil
	if (deep) then
		for button in self:traverseType('button') do
			if (button._id == id) then
				button:setToggled(true)
				toggledChild = button
			else
				button:setToggled(false)
			end
		end
	else
		for _, child in ipairs(self) do
			if (child:is(Cs.button)) then
				if (child._id == id) then
					child:setToggled(true)
					toggledChild = child
				else
					child:setToggled(false)
				end
			end
		end
	end
	return toggledChild -- if multiple children matched then the last match is returned
end



-- sort( sortFunction )
function Cs.container:sort(f)
	assertArg(1, f, 'function')
	table.sort(self, f)
	scheduleLayoutUpdateIfDisplayed(self)
end



-- for element in traverse( ) do
do
	local function traverseChildren(el)
		for _, child in ipairs(el) do
			coroutine.yield(child)
			if (child:is(Cs.container)) then
				traverseChildren(child)
			end
		end
	end
	function Cs.container:traverse()
		return newIteratorCoroutine(traverseChildren, self)
	end
end

-- for element in traverseType( elementType ) do
do
	local function traverseChildrenOfType(el, C)
		for _, child in ipairs(el) do
			if (child:is(C)) then
				coroutine.yield(child)
			end
			if (child:is(Cs.container)) then
				traverseChildrenOfType(child, C)
			end
		end
	end
	function Cs.container:traverseType(elType)
		local C = Cs[elType] or errorf('bad gui type %q', elType)
		return newIteratorCoroutine(traverseChildrenOfType, self, C)
	end
end

-- for element in traverseVisible( [ x, y ] ) do
do
	local function traverseVisibleChildren(el)
		for i = #el, 1, -1 do
			local child = el[i]
			if (not child._hidden) then
				if (child:is(Cs.container)) then
					traverseVisibleChildren(child)
				end
				coroutine.yield(child)
			end
		end
	end
	local function constrainedTraverseVisibleChildren(el, x, y)
		for i = #el, 1, -1 do
			local child = el[i]
			if (not child._hidden) then
				local isContainer = child:is(Cs.container)
				local skip = false
				if (isContainer) then
					if (child._maxWidth) and (x < child._layoutX or x >= child._layoutX+child._layoutWidth) then
						skip = true
					elseif (child._maxHeight) and (y < child._layoutY or y >= child._layoutY+child._layoutHeight) then
						skip = true
					end
				end
				if (not skip) then
					if (isContainer) then
						constrainedTraverseVisibleChildren(child, x, y)
					end
					coroutine.yield(child)
				end
			end
		end
	end
	function Cs.container:traverseVisible(x, y)
		if (x and y) then
			return newIteratorCoroutine(constrainedTraverseVisibleChildren, self, x, y)
		end
		return newIteratorCoroutine(traverseVisibleChildren, self)
	end
end



-- REPLACE _updateLayoutSize( )
function Cs.container:_updateLayoutSize()
	self._layoutWidth = math.min((self._width or self._expandX and self._parent._layoutInnerWidth or 2*self._padding),
		(self._maxWidth or math.huge))
	self._layoutHeight = math.min((self._height or self._expandY and self._parent._layoutInnerHeight or 2*self._padding),
		(self._maxHeight or math.huge))
	self._layoutInnerWidth = self._layoutWidth-2*self._padding
	self._layoutInnerHeight = self._layoutHeight-2*self._padding
	updateContainerChildLayoutSizes(self)
end

-- REPLACE _expandLayout( [ expandWidth, expandHeight ] )
function Cs.container:_expandLayout(expandW, expandH)
	if (expandW) then
		self._layoutWidth = math.min(expandW, (self._maxWidth or math.huge))
		self._layoutInnerWidth = self._layoutWidth-2*self._padding
	end
	if (expandH) then
		self._layoutHeight = math.min(expandH, (self._maxHeight or math.huge))
		self._layoutInnerHeight = self._layoutHeight-2*self._padding
	end
	for _, child in ipairs(self) do
		child:_expandLayout((expandW and self._layoutInnerWidth or nil),
		                    (expandH and self._layoutInnerHeight or nil))
	end
end

-- REPLACE _updateLayoutPosition( )
function Cs.container:_updateLayoutPosition()
	for _, child in ipairs(self) do
		if (not child._hidden) then
			updateFloatingElementPosition(child) -- (all children counts as floating in plain containers)
		end
	end
end



--==============================================================
--= Bar ========================================================
--==============================================================



Cs.bar = Cs.container:extend('GuiBar', {
	_expandChildren = true,
	_homogeneous = false,
})

function Cs.bar:init(gui, data, parent)
	Cs.bar.super.init(self, gui, data, parent)

	retrieve(self, data, '_expandChildren')
	retrieve(self, data, '_homogeneous')

end



--==============================================================
--= Hbar =======================================================
--==============================================================



Cs.hbar = Cs.bar:extend('GuiHorizontalBar', {
})

-- function Cs.hbar:init(gui, data, parent)
-- 	Cs.hbar.super.init(self, gui, data, parent)
-- end



-- REPLACE _updateLayoutSize( )
function Cs.hbar:_updateLayoutSize()
	updateContainerChildLayoutSizes(self)
	local staticW, dynamicW, highestW, highestDynamicW, expandablesX, currentMx, sumMx,
	      staticH, dynamicH, highestH, highestDynamicH, expandablesY, currentMy, sumMy
	      = getContainerLayoutSizeValues(self)
	local innerW = (self._homogeneous and highestDynamicW*expandablesX or dynamicW)+staticW+sumMx
	self._layoutInnerWidth = (self._width and self._width-2*self._padding or innerW)
	self._layoutInnerHeight = (self._height and self._height-2*self._padding or highestH)
	self._layoutInnerStaticWidth, self._layoutInnerStaticHeight = staticW, 0
	self._layoutInnerMarginsX, self._layoutInnerMarginsY = sumMx, 0
	self._layoutExpandablesX, self._layoutExpandablesY = expandablesX, expandablesY
	updateContainerLayoutSize(self)
end

-- REPLACE _expandLayout( [ expandWidth, expandHeight ] )
function Cs.hbar:_expandLayout(expandW, expandH)

	-- Expand self
	expandElement(self, expandW, expandH)

	-- Calculate amount of space for children to expand into (total or extra, whether homogeneous or not)
	local totalSpaceX = 0
	if (expandW) then
		totalSpaceX = self._layoutInnerWidth-self._layoutInnerMarginsX
		if (self._homogeneous) then
			totalSpaceX = totalSpaceX-self._layoutInnerStaticWidth
		else
			for _, child in ipairs(self) do
				if not (child._hidden or child._floating) then
					totalSpaceX = totalSpaceX-child._layoutWidth
				end
			end
		end
	end

	-- Expand children
	local expandablesX = self._layoutExpandablesX
	for _, child in ipairs(self) do
		if (not child._hidden) then
			if (child._floating) then
				child:_expandLayout(nil, nil)
			else
				if (expandW and not child._width) then
					local spaceX = round(totalSpaceX/expandablesX)
					expandablesX, totalSpaceX = expandablesX-1, totalSpaceX-spaceX
					expandW = (self._homogeneous and 0 or child._layoutWidth)+spaceX
				end
				child:_expandLayout((not child._width and expandW or nil),
					(self._expandChildren and self._layoutInnerHeight or nil))
			end
		end
	end

end

-- REPLACE _updateLayoutPosition( )
function Cs.hbar:_updateLayoutPosition()
	local x, y, m, first = self._layoutX+self._padding, self._layoutY+self._padding, 0, true
	for _, child in ipairs(self) do
		if (not child._hidden) then
			if (child._floating) then
				updateFloatingElementPosition(child)
			else
				if (not first) then
					m = math.max(m, child._marginLeft or child._marginHorizontal or child._margin)
					x = x+m
				end
				child._layoutX, child._layoutY = x, y
				child:_updateLayoutPosition()
				x = x+child._layoutWidth
				m = (child._marginRight or child._marginHorizontal or child._margin)
				first = false
			end
		end
	end
end



--==============================================================
--= Vbar =======================================================
--==============================================================



Cs.vbar = Cs.bar:extend('GuiVerticalBar', {
})

-- function Cs.vbar:init(gui, data, parent)
-- 	Cs.vbar.super.init(self, gui, data, parent)
-- end

-- REPLACE _updateLayoutSize( )
function Cs.vbar:_updateLayoutSize()
	updateContainerChildLayoutSizes(self)
	local staticW, dynamicW, highestW, highestDynamicW, expandablesX, currentMx, sumMx,
	      staticH, dynamicH, highestH, highestDynamicH, expandablesY, currentMy, sumMy
	      = getContainerLayoutSizeValues(self)
	local innerH = (self._homogeneous and highestDynamicH*expandablesY or dynamicH)+staticH+sumMy
	self._layoutInnerWidth = (self._width and self._width-2*self._padding or highestW)
	self._layoutInnerHeight = (self._height and self._height-2*self._padding or innerH)
	self._layoutInnerStaticWidth, self._layoutInnerStaticHeight = 0, staticH
	self._layoutInnerMarginsX, self._layoutInnerMarginsY = 0, sumMy
	self._layoutExpandablesX, self._layoutExpandablesY = expandablesX, expandablesY
	updateContainerLayoutSize(self)
end

-- REPLACE _expandLayout( [ expandWidth, expandHeight ] )
function Cs.vbar:_expandLayout(expandW, expandH)

	-- Expand self
	expandElement(self, expandW, expandH)

	-- Calculate amount of space for children to expand into (total or extra, whether homogeneous or not)
	local totalSpaceY = 0
	if (expandH) then
		totalSpaceY = self._layoutInnerHeight-self._layoutInnerMarginsY
		if (self._homogeneous) then
			totalSpaceY = totalSpaceY-self._layoutInnerStaticHeight
		else
			for _, child in ipairs(self) do
				if not (child._hidden or child._floating) then
					totalSpaceY = totalSpaceY-child._layoutHeight
				end
			end
		end
	end

	-- Expand children
	local expandablesY = self._layoutExpandablesY
	for _, child in ipairs(self) do
		if (not child._hidden) then
			if (child._floating) then
				child:_expandLayout(nil, nil)
			else
				if (expandH and not child._height) then
					local spaceY = round(totalSpaceY/expandablesY)
					expandablesY, totalSpaceY = expandablesY-1, totalSpaceY-spaceY
					expandH = (self._homogeneous and 0 or child._layoutHeight)+spaceY
				end
				child:_expandLayout((self._expandChildren and self._layoutInnerWidth or nil),
					(not child._height and expandH or nil))
			end
		end
	end

end

-- REPLACE _updateLayoutPosition( )
function Cs.vbar:_updateLayoutPosition()
	local x, y, m, first = self._layoutX+self._padding, self._layoutY+self._padding, 0, true
	for _, child in ipairs(self) do
		if (not child._hidden) then
			if (child._floating) then
				updateFloatingElementPosition(child)
			else
				if (not first) then
					m = math.max(m, child._marginTop or child._marginVertical or child._margin)
					y = y+m
				end
				child._layoutX, child._layoutY = x, y
				child:_updateLayoutPosition()
				y = y+child._layoutHeight
				m = (child._marginBottom or child._marginVertical or child._margin)
				first = false
			end
		end
	end
end



--==============================================================
--= Root =======================================================
--==============================================================



Cs.root = Cs.container:extend('GuiRoot', {
	--[[REPLACE]] _width = 0, _height = 0,
})

-- function Cs.root:init(gui, data, parent)
-- 	Cs.root.super.init(self, gui, data, parent)
-- end



-- REPLACE _draw( )
function Cs.root:_draw()
	if (self._hidden) then
		return
	end
	local x, y = self._layoutX+self._layoutOffsetX, self._layoutY+self._layoutOffsetY
	local w, h = self._layoutWidth, self._layoutHeight

	self:trigger('beforedraw', x, y, w, h)

	-- Layout background
	drawBackground(self)

	self:_drawDebug(0, 0, 255, 0)

	-- Children
	for _, child in ipairs(self) do
		child:_draw()
	end

	self:trigger('afterdraw', x, y, w, h)

end



-- REPLACE setDimensions( width, height )
function Cs.root:setDimensions(w, h)
	assert(w)
	assert(h)
	if (self._width == w and self._height == h) then
		return
	end
	self._width, self._height = w, h
	scheduleLayoutUpdateIfDisplayed(self)
end



-- REPLACE _updateLayoutSize( )
function Cs.root:_updateLayoutSize()
	self._layoutWidth = self._width
	self._layoutHeight = self._height
	self._layoutInnerWidth = self._layoutWidth-2*self._padding
	self._layoutInnerHeight = self._layoutHeight-2*self._padding
	updateContainerChildLayoutSizes(self)
end

-- REPLACE _expandLayout( [ expandWidth, expandHeight ] )
-- expandWidth, expandHeight: Ignored
function Cs.root:_expandLayout(expandW, expandH)
	for _, child in ipairs(self) do
		child:_expandLayout(nil, nil)
	end
end



--==============================================================
--= Leaf =======================================================
--==============================================================



Cs.leaf = Cs.element:extend('GuiLeaf', {

	PADDING = 2,

	_mnemonicPosition = nil,
	_textWidth = 0, _textHeight = 0,

	_align = 'center',
	_bold = false, _small = false,
	_mnemonics = false,
	_text = '',
	_textColor = nil,

})

function Cs.leaf:init(gui, data, parent)
	Cs.leaf.super.init(self, gui, data, parent)

	retrieve(self, data, '_align')
	retrieve(self, data, '_bold', '_small')
	retrieve(self, data, '_mnemonics')
	-- retrieve(self, data, '_text')
	retrieve(self, data, '_textColor')

	if (data.text) then
		self:setText(data.text)
	end

end



-- getAlign, setAlign
-- Note: We shouldn't have to update layout after changing text alignment
Cs.leaf:define('_align')



-- font = getFont( )
function Cs.leaf:getFont()
	return self._gui[self._small and '_smallFont' or self._bold and '_boldFont' or '_font']
end



-- getText
Cs.leaf:defineGet('_text')

-- setText( text )
function Cs.leaf:setText(text)
	if (self._text == text) then
		return
	end

	-- Check text for mnemonics (using "&")
	self._mnemonicPosition = nil
	if (self._mnemonics) then
		local matchCount = 0
		text = text:gsub('()&(.)', function(pos, c)
			if (c ~= '&') then
				if (self._mnemonicPosition) then
					errorf('multiple mnemonics in %q', text)
				end
				self._mnemonicPosition = pos-matchCount
			end
			matchCount = matchCount+1
			return c
		end)
	end

	-- Update text
	local font, oldW = self:getFont(), self._textWidth
	self._text = text
	self._textWidth = font:getWidth(text)

	if (self._textWidth ~= oldW) then
		scheduleLayoutUpdateIfDisplayed(self)
	end
end



-- getTextColor, setTextColor
Cs.leaf:define('_textColor')



-- state = isBold( )
function Cs.leaf:isBold(text)
	return self._bold
end

-- setBold( state )
function Cs.leaf:setBold(state)
	if (self._bold == state) then
		return
	end
	self._bold = state
	scheduleLayoutUpdateIfDisplayed(self)
end



-- state = isSmall( )
function Cs.leaf:isSmall(text)
	return self._small
end

-- setSmall( state )
function Cs.leaf:setSmall(state)
	if (self._small == state) then
		return
	end
	self._small = state
	scheduleLayoutUpdateIfDisplayed(self)
end



-- REPLACE state = isSolid( )
function Cs.leaf:isSolid()
	return true
end



--==============================================================
--= Canvas =====================================================
--==============================================================



Cs.canvas = Cs.leaf:extend('GuiCanvas', {

	--[[OVERRIDE]] PADDING = 0,

	_canvasBackgroundColor = nil,

})

function Cs.canvas:init(gui, data, parent)
	Cs.canvas.super.init(self, gui, data, parent)

	retrieve(self, data, '_canvasBackgroundColor')

end



-- REPLACE _draw( )
function Cs.canvas:_draw()
	if (self._hidden) then
		return
	end

	local gui = self._gui
	if (gui.debug) then
		self:_drawDebug(255, 0, 0)
		return
	end

	local x, y = self._layoutX+self._layoutOffsetX, self._layoutY+self._layoutOffsetY
	local w, h = self._layoutWidth, self._layoutHeight

	self:trigger('beforedraw', x, y, w, h)

	-- Layout background
	drawBackground(self)

	-- Canvas
	local cw, ch = (self._width or w), (self._height or h)
	if (cw > 0 and ch > 0) then
		local cx, cy = x+math.floor((w-cw)/2), y+math.floor((h-ch)/2)
		local bgColor = self._canvasBackgroundColor
		if (bgColor) then
			LG.setColor(bgColor)
			LG.rectangle('fill', cx, cy, cw, ch)
		end
		gui:_setScissor(cx, cy, cw, ch)
		LG.translate(cx, cy)
		LG.setColor(255, 255, 255)
		self:trigger('draw', cw, ch)
		gui:_setScissor(nil)
	end

	self:trigger('afterdraw', x, y, w, h)

end



-- getCanvasBackgroundColor, setCanvasBackgroundColor
Cs.canvas:define('_canvasBackgroundColor')



-- REPLACE _updateLayoutSize( )
function Cs.canvas:_updateLayoutSize()
	self._layoutWidth = (self._width or 0)
	self._layoutHeight = (self._height or 0)
	self._layoutInnerWidth = self._layoutWidth
	self._layoutInnerHeight = self._layoutHeight
end



--==============================================================
--= Image ======================================================
--==============================================================



Cs.image = Cs.leaf:extend('GuiImage', {

	--[[OVERRIDE]] PADDING = 0,

	_imageBackgroundColor = nil,
	_imagePadding = 0,
	_sprite = nil,
	_spriteColor = nil,

})

function Cs.image:init(gui, data, parent)
	Cs.image.super.init(self, gui, data, parent)

	retrieve(self, data, '_imageBackgroundColor')
	retrieve(self, data, '_imagePadding')
	-- retrieve(self, data, '_sprite')
	retrieve(self, data, '_spriteColor')

	self:setSprite(data.sprite)

end



-- OVERRIDE _update( deltaTime )
function Cs.image:_update(dt)
	Cs.image.super._update(self, dt)
	local sprite = self._sprite
	if (sprite) then
		sprite:update(dt)
	end
end



-- REPLACE _draw( )
function Cs.image:_draw()
	if (self._hidden) then
		return
	end

	if (self._gui.debug) then
		self:_drawDebug(255, 0, 0)
		return
	end

	local x, y = self._layoutX+self._layoutOffsetX, self._layoutY+self._layoutOffsetY
	local w, h = self._layoutWidth, self._layoutHeight
	local midX, midY = x+math.floor(w/2), y+math.floor(h/2)

	self:trigger('beforedraw', x, y, w, h)

	-- Layout background
	drawBackground(self)

	-- Image
	if (self._sprite) then
		local iw, ih = self._sprite:getScaledDimensions()
		if (self._imageBackgroundColor) then
			local iw, ih = iw+2*self._imagePadding, ih+2*self._imagePadding
			LG.setColor(self._imageBackgroundColor)
			LG.rectangle('fill', midX-iw/2, midY-ih/2, iw, ih)
		end
		self._sprite:draw(midX-iw/2, midY-ih/2)
	end

	self:trigger('afterdraw', x, y, w, h)

end



-- getImageBackgroundColor, setImageBackgroundColor
Cs.image:define('_imageBackgroundColor')



-- getSprite
Cs.image:defineGet('_sprite')

-- sprite = setSprite( sprite )
function Cs.image:setSprite(sprite)
	if (type(sprite) == 'string') then
		local spriteLoader = self._gui._spriteLoader
		sprite = (spriteLoader and spriteLoader(sprite))
	end
	if (sprite) then
		sprite = sprite:clone()
		sprite:setAnchor(0, 0)
		sprite:setOffset(0, 0)
		if (self._spriteColor) then
			sprite:setColor(unpack(self._spriteColor))
		end
		self._sprite = sprite
	else
		self._sprite = nil
	end
	-- TODO: Only update layout if image sprite size is different (Also, restrict access to the sprite)
	scheduleLayoutUpdateIfDisplayed(self)
	return sprite
end



-- getSpriteColor
Cs.image:defineGet('_spriteColor')

-- setSpriteColor( color )
function Cs.image:setSpriteColor(color)
	self._spriteColor = color
	local sprite = self._sprite
	if (sprite) then
		sprite:setColor(unpack(color or {255,255,255}))
	end
end



-- REPLACE _updateLayoutSize( )
function Cs.image:_updateLayoutSize()
	if (self._sprite) then
		local iw, ih = self._sprite:getScaledDimensions()
		self._layoutWidth = iw+2*(self._imagePadding+self.PADDING)
		self._layoutHeight = ih+2*(self._imagePadding+self.PADDING)
	else
		self._layoutWidth = 0
		self._layoutHeight = 0
	end
	self._layoutWidth = (self._width or self._layoutWidth)
	self._layoutHeight = (self._height or self._layoutHeight)
	self._layoutInnerWidth = self._layoutWidth
	self._layoutInnerHeight = self._layoutHeight
end



--==============================================================
--= Text =======================================================
--==============================================================



Cs.text = Cs.leaf:extend('GuiText', {
	_textWrapLimit = nil,
})

function Cs.text:init(gui, data, parent)
	Cs.text.super.init(self, gui, data, parent)

	retrieve(self, data, '_textWrapLimit')

end



-- REPLACE _draw( )
function Cs.text:_draw()
	if self._hidden then
		return
	end

	if self._gui.debug then
		self:_drawDebug(255, 0, 0)
		return
	end

	local x, y = self._layoutX+self._layoutOffsetX, self._layoutY+self._layoutOffsetY
	local w, h = self._layoutWidth, self._layoutHeight
	local midX, midY = x+math.floor(w/2), y+math.floor(h/2)
	local textY = math.floor(midY-self._textHeight/2)

	self:trigger('beforedraw', x, y, w, h)

	-- Layout background
	drawBackground(self)

	self._gui:_setScissor(x+1, y+1, w-2, h-2)

	-- Text
	local textX
	if (self._align == 'left' or self._textWrapLimit) then
		textX = self._layoutX+self.PADDING
	elseif self._align == 'right' then
		textX = self._layoutX+self._layoutWidth-self.PADDING-self._textWidth
	else--if align = center
		textX = midX-math.floor(self._textWidth/2)
	end
	LG.setFont(self:getFont())
	LG.setColor(self._textColor or {255,255,255})
	if self._textWrapLimit then
		LG.printf(self._text, textX, textY, self._textWrapLimit, self._align)
	else
		LG.print(self._text, textX, textY)
	end

	self._gui:_setScissor(nil)

	self:trigger('afterdraw', x, y, w, h)

end



-- REPLACE _updateLayoutSize( )
function Cs.text:_updateLayoutSize()
	local font = self:getFont()
	self._textWidth, self._textHeight = getTextDimensions(font, self._text, self._textWrapLimit)
	self._layoutWidth = (self._width or self._textWidth+2*self.PADDING)
	self._layoutHeight = (self._height or self._textHeight+2*self.PADDING)
	self._layoutInnerWidth = self._layoutWidth
	self._layoutInnerHeight = self._layoutHeight
end



--==============================================================
--= Widget =====================================================
--==============================================================



Cs.widget = Cs.leaf:extend('GuiWidget', {

	_active = true,
	_priority = 0,

})

function Cs.widget:init(gui, data, parent)
	Cs.widget.super.init(self, gui, data, parent)

	retrieve(self, data, '_active')
	retrieve(self, data, '_priority')

end



-- state = isActive( )
function Cs.widget:isActive()
	return self._active
end

-- stateChanged = setActive( state )
function Cs.widget:setActive(state)
	if (self._active == state) then
		return false
	end
	self._active = state
	return true
end



--==============================================================
--= Button =====================================================
--==============================================================



Cs.button = Cs.widget:extend('GuiButton', {

	--[[OVERRIDE]] PADDING = 3,
	ARROW = nil, -- (is set here below)
	ARROW_LENGTH = 2,
	IMAGE_SPACING = 3, TEXT_SPACING = 6,
	THEMES = {['normal']=true, ['highlight']=true, ['negative']=true, ['blend']=true},

	_isPressed = false,
	_textWidth1 = 0, _textWidth2 = 0,

	_arrow = nil,
	_canToggle = false,
	_close = false,
	_imageBackgroundColor = nil,
	_imagePadding = 0,
	_sprite = nil,
	_spriteColor = nil,
	_text2 = '',
	_theme = 'normal',
	_toggled = false,

})

-- Create arrow image
local imageData = love.image.newImageData(Cs.button.ARROW_LENGTH, 4)
imageData:setPixel(0, 0, 255, 255, 255, 255); imageData:setPixel(1, 0, 255, 255, 255, 0);
imageData:setPixel(0, 1, 255, 255, 255, 255); imageData:setPixel(1, 1, 255, 255, 255, 255);
imageData:setPixel(0, 2, 255, 255, 255, 255); imageData:setPixel(1, 2, 255, 255, 255, 255);
imageData:setPixel(0, 3, 255, 255, 255, 255); imageData:setPixel(1, 3, 255, 255, 255, 0);
Cs.button.ARROW = LG.newImage(imageData)
Cs.button.ARROW:setFilter('nearest', 'nearest')

function Cs.button:init(gui, data, parent)
	Cs.button.super.init(self, gui, data, parent)

	retrieve(self, data, '_arrow')
	retrieve(self, data, '_canToggle')
	retrieve(self, data, '_close')
	retrieve(self, data, '_imageBackgroundColor')
	retrieve(self, data, '_imagePadding')
	-- retrieve(self, data, '_sprite')
	retrieve(self, data, '_spriteColor')
	retrieve(self, data, '_text2')
	-- retrieve(self, data, '_theme')
	retrieve(self, data, '_toggled')

	self:setSprite(data.sprite)

	if (data.theme) then
		self:setTheme(data.theme)
	end

end



-- OVERRIDE _update( deltaTime )
function Cs.button:_update(dt)
	Cs.button.super._update(self, dt)
	local sprite = self._sprite
	if (sprite) then
		sprite:update(dt)
	end
end



-- REPLACE _draw( )
function Cs.button:_draw()
	if (self._hidden) then
		return
	end

	if (self._gui.debug) then
		self:_drawDebug(255, 0, 0)
		return
	end

	local x, y = self._layoutX+self._layoutOffsetX, self._layoutY+self._layoutOffsetY
	local w, h = self._layoutWidth, self._layoutHeight

	self:trigger('beforedraw', x, y, w, h)

	local arrow = self._arrow
	if (arrow) then
		if (arrow == 'right') then
			w = w-self.ARROW_LENGTH
		elseif (arrow == 'down') then
			h = h-self.ARROW_LENGTH
		elseif (arrow == 'left') then
			w = w-self.ARROW_LENGTH
			x = x+self.ARROW_LENGTH
		elseif (arrow == 'up') then
			h = h-self.ARROW_LENGTH
			y = y+self.ARROW_LENGTH
		end
	end

	local midX, midY = x+math.floor(w/2), y+math.floor(h/2)
	local textY = midY-math.floor(self._textHeight/2)
	local opacity = (self._active and 1 or 0.3)

	-- Layout background
	drawBackground(self)

	-- Button background
	local isHovered = (self._active and self:isHovered(true))
	local isBlended = not (self:isMouseFocus() or self:isHovered())
	-- Background
	local r, g, b, a = 130, 210, 230, 200 -- (normal theme)
	if (self._toggled) then
		b = b*0.2
	elseif (self._theme == 'normal') then
		-- void
	elseif (self._theme == 'highlight') then
		r, g, b = 230, 245, 255
	elseif (self._theme == 'negative') then
		r, g, b = 235, 83, 67
	elseif (self._theme == 'blend') then
		if (isBlended) then
			a = 50
		end
	end
	if (self._isPressed and isHovered) then
		r, g, b = 0.7*r, 0.7*g, 0.7*b
	end
	LG.setColor(r, g, b, a*opacity)
	LG.rectangle('fill', x+1, y+1, w-2, h-2)
	-- Border
	LG.setColor(255, 255, 255, (isHovered and 255 or 80)*opacity)
	LG.rectangle('line', x+1+0.5, y+1+0.5, w-2-1, h-2-1)

	-- Arrow
	local arrow = self._arrow
	if (arrow and self._toggled) then
		local iw, ih = self.ARROW:getDimensions()
		local function drawArrow(x, y, angQuarter)
			local ang = angQuarter*tau/4
			LG.setColor(r, g, b, a*opacity)
			LG.draw(self.ARROW, x, y, ang)
			LG.setColor(255, 255, 255, (isHovered and 255 or 80)*opacity)
			LG.draw(self.ARROW, x, y, ang)
		end
		if (arrow == 'right') then
			drawArrow(x+w-1, y+(h-ih)/2, 0)
		elseif (arrow == 'down') then
			drawArrow(x+(w+ih)/2, y+h-1, 1)
		elseif (arrow == 'left') then
			drawArrow(x+1, y+(h+ih)/2, 2)
		elseif (arrow == 'up') then
			drawArrow(x+(w-ih)/2, y+1, 3)
		end
	end

	self._gui:_setScissor(x+2, y+2, w-2*2, h-2*2)

	-- Image
	-- TODO: Support 'align' for no-text image buttons
	if (self._sprite and self._text == '' and self._text2 == '') then
		local iw, ih = self._sprite:getScaledDimensions()
		if (self._imageBackgroundColor) then
			local iw, ih = iw+2*self._imagePadding, ih+2*self._imagePadding
			local r, g, b, a = unpack(self._imageBackgroundColor)
			LG.setColor(r, g, b, a*opacity)
			LG.rectangle('fill', midX-iw/2, midY-ih/2, iw, ih)
		end
		self._sprite:draw(midX-iw/2, midY-ih/2)

	-- Text
	elseif (not self._sprite) then
		local text1X, text2X
		if (self._align == 'left') then
			text1X = x+self.PADDING
			text2X = math.max(x+w-self.PADDING-self._textWidth2, text1X+self._textWidth1+self.TEXT_SPACING)
		elseif (self._align == 'right') then
			text1X = math.max(x+w-self.PADDING-self._textWidth1, x+self.PADDING)
			text2X = math.min(x+self.PADDING, text1X-self.TEXT_SPACING-self._textWidth2)
		else--if align = center
			text1X = math.max(midX-math.floor(self._textWidth/2), x+self.PADDING)
			text2X = text1X+self._textWidth1+self.TEXT_SPACING
		end
		local font = self:getFont()
		local r, g, b = 0, 0, 0
		if (self._theme == 'blend' and isBlended) then
			r, g, b = 255, 255, 255
		end
		LG.setFont(font)
		if (self._text2 ~= '') then
			LG.setColor(r, g, b, 100*opacity)
			LG.print(self._text2, text2X, textY)
		end
		LG.setColor(r, g, b, 255*opacity)
		LG.print(self._text, text1X, textY)
		if (self._mnemonicPosition) then
			local mnemonicX1 = text1X+font:getWidth(self._text:sub(1, self._mnemonicPosition-1))-1
			local mnemonicX2 = text1X+font:getWidth(self._text:sub(1, self._mnemonicPosition))
			LG.rectangle('fill', mnemonicX1, textY+font:getHeight(), mnemonicX2-mnemonicX1, 1)
		end

	-- Image and text
	else
		local iw, ih = self._sprite:getScaledDimensions()
		if (self._imageBackgroundColor) then
			local iw, ih = iw+2*self._imagePadding, ih+2*self._imagePadding
			local r, g, b, a = unpack(self._imageBackgroundColor)
			LG.setColor(r, g, b, a*opacity)
			LG.rectangle('fill', x+self.PADDING, midY-ih/2, iw, ih)
		end
		local text1X = x+self.PADDING+(iw+2*self._imagePadding)+self.IMAGE_SPACING
		local text2X = x+w-self.PADDING-self._textWidth2
		local font = self:getFont()
		self._sprite:draw(x+self.PADDING+self._imagePadding, midY-ih/2)
		LG.setFont(font)
		LG.setColor(0, 0, 0, 255*opacity)
		LG.print(self._text, text1X, textY)
		if (self._text2 ~= '') then
			LG.setColor(0, 0, 0, 100*opacity)
			LG.print(self._text2, text2X, textY)
		end
		if (self._mnemonicPosition) then
			local mnemonicX1 = text1X+font:getWidth(self._text:sub(1, self._mnemonicPosition-1))-1
			local mnemonicX2 = text1X+font:getWidth(self._text:sub(1, self._mnemonicPosition))
			LG.rectangle('fill', mnemonicX1, textY+font:getHeight(), mnemonicX2-mnemonicX1, 1)
		end

	end

	self._gui:_setScissor(nil)

	self:trigger('afterdraw', x, y, w, h)

end



-- getImageBackgroundColor, setImageBackgroundColor
Cs.button:define('_imageBackgroundColor')



-- getSprite
Cs.button:defineGet('_sprite')

-- sprite = setSprite( sprite )
function Cs.button:setSprite(sprite)
	if (type(sprite) == 'string') then
		local spriteLoader = self._gui._spriteLoader
		sprite = (spriteLoader and spriteLoader(sprite))
	end
	if (sprite) then
		sprite = sprite:clone()
		sprite:setAnchor(0, 0)
		sprite:setOffset(0, 0)
		if (self._spriteColor) then
			sprite:setColor(unpack(self._spriteColor))
		end
		self._sprite = sprite
	else
		self._sprite = nil
	end
	-- TODO: Only update layout if button sprite size is different (Also, restrict access to the sprite)
	scheduleLayoutUpdateIfDisplayed(self)
	return sprite
end



-- getSpriteColor
Cs.button:defineGet('_spriteColor')

-- setSpriteColor( color )
function Cs.button:setSpriteColor(color)
	self._spriteColor = color
	local sprite = self._sprite
	if (sprite) then
		sprite:setColor(unpack(color or {255,255,255}))
	end
end



-- getText2
Cs.button:defineGet('_text2')

-- OVERRIDE setText( text )
function Cs.button:setText(text)
	if (self._text == text) then
		return
	end
	local oldW = self._textWidth

	Cs.button.super.setText(self, text)

	local font = self:getFont()
	self._textWidth1 = font:getWidth(self._text)
	self._textWidth = self._textWidth1+(self._textWidth2 > 0 and self.TEXT_SPACING+self._textWidth2 or 0)

	if (self._textWidth ~= oldW) then
		scheduleLayoutUpdateIfDisplayed(self)
	end
end

-- setText2( text )
function Cs.button:setText2(text)
	if (self._text2 == text) then
		return
	end

	local font, oldW = self:getFont(), self._textWidth
	self._text2 = text
	self._textWidth2 = font:getWidth(text)
	self._textWidth = self._textWidth1+(self._textWidth2 > 0 and self.TEXT_SPACING+self._textWidth2 or 0)

	if (self._textWidth ~= oldW) then
		scheduleLayoutUpdateIfDisplayed(self)
	end
end



-- theme = getTheme( )
function Cs.button:getTheme()
	return self._theme
end

-- setTheme( theme )
function Cs.button:setTheme(theme)
	if (not self.THEMES[theme]) then
		errorf('bad theme name %q', tostring(theme))
	end
	self._theme = theme
end



-- state = isToggled( )
function Cs.button:isToggled()
	return self._toggled
end

-- setToggled( state )
function Cs.button:setToggled(state)
	if (self._toggled == state) then
		return
	end
	self._toggled = state
	self:trigger('toggle')
end



-- REPLACE handled, grabFocus = _mouseDown( x, y, button )
function Cs.button:_mouseDown(x, y, buttonN)
	if (buttonN == 1) then
		if (not self._active) then
			return true, false
		end
		self._isPressed = true
		return true, true
	end
	return false, false
end

-- -- REPLACE _mouseMove( x, y )
-- function Cs.button:_mouseMove(x, y)
-- end

-- REPLACE _mouseUp( x, y, button )
function Cs.button:_mouseUp(x, y, buttonN)
	if (buttonN == 1) then
		self._isPressed = false
		if (x and self:isHovered()) then
			self:press()
		end
	end
end



-- REPLACE handled = _ok( )
function Cs.button:_ok()
	self:press(true)
	return true
end



-- success = press( [ ignoreActiveState=false ] )
function Cs.button:press(ignoreActiveState)
	if not (ignoreActiveState or self._active) then
		return false
	end

	-- Press/toggle the button
	local preparedSound = prepareSound(self, 'press')
	if (self._canToggle) then
		self._toggled = (not self._toggled)
	end
	self._gui._ignoreKeyboardInputThisFrame = true
	self:trigger('press')
	if (self._canToggle) then
		self:trigger('toggle')
	end
	self:triggerBubbling('pressed', self)

	-- Close closest closable
	local closedAnything = false
	if (self._close) then
		if (self:canClose()) then
			closedAnything = self:close()
		else
			for _, parent in self:parents() do
				if (parent:canClose()) then
					closedAnything = parent:close()
					break
				end
			end
		end
	end
	if (not closedAnything) then
		preparedSound() -- 'close' has it's own sound
	end

	return true
end



-- REPLACE _updateLayoutSize( )
function Cs.button:_updateLayoutSize()

	local font = self:getFont()
	self._textWidth1 = font:getWidth(self._text)
	self._textWidth2 = font:getWidth(self._text2)
	self._textWidth = self._textWidth1+(self._textWidth2 > 0 and self.TEXT_SPACING+self._textWidth2 or 0)
	self._textHeight = font:getHeight()

	local w, h

	-- Image
	if (self._sprite and self._text == '' and self._text2 == '') then
		local iw, ih = self._sprite:getScaledDimensions()
		w = iw+2*(self._imagePadding+self.PADDING)
		h = ih+2*(self._imagePadding+self.PADDING)

	-- Text
	elseif (not self._sprite) then
		w = self._textWidth+2*self.PADDING
		h = self._textHeight+2*self.PADDING

	-- Image and text
	else
		local iw, ih = self._sprite:getScaledDimensions()
		w = iw+self._textWidth+self.IMAGE_SPACING+2*(self._imagePadding+self.PADDING)
		h = math.max(self._textHeight, ih+2*self._imagePadding)+2*self.PADDING

	end
	w = w+((self._arrow == 'left' or self._arrow == 'right') and self.ARROW_LENGTH or 0)
	h = h+((self._arrow == 'up' or self._arrow == 'down') and self.ARROW_LENGTH or 0)
	self._layoutWidth = (self._width or w)
	self._layoutHeight = (self._height or h)
	self._layoutInnerWidth = self._layoutWidth
	self._layoutInnerHeight = self._layoutHeight

end



--==============================================================
--= Input ======================================================
--==============================================================



Cs.input = Cs.widget:extend('GuiInput', {

	--[[OVERRIDE]] PADDING = 4,

	_field = nil,
	_savedKeyRepeat = false,
	_savedValue = '',

	--[[OVERRIDE]] _width = 0,
	_placeholder = '',

})

function Cs.input:init(gui, data, parent)
	Cs.input.super.init(self, gui, data, parent)

	-- retrieve(self, data, '_password')
	retrieve(self, data, '_placeholder')

	self._field = InputField()
	self._field:setFont(self:getFont())
	self._field:setFontFilteringActive(true)
	if data.value then
		self._field:setText(data.value)
	end
	if data.password then
		self._field:setPasswordActive(true)
	end

end



-- OVERRIDE _update( deltaTime )
function Cs.input:_update(dt)
	Cs.input.super._update(self, dt)
	self._field:update(dt)
end



-- REPLACE _draw( )
function Cs.input:_draw()
	if (self._hidden) then
		return
	end

	if (self._gui.debug) then
		self:_drawDebug(255, 0, 0)
		return
	end

	local x, y = self._layoutX+self._layoutOffsetX, self._layoutY+self._layoutOffsetY
	local w, h = self._layoutWidth, self._layoutHeight
	local midX, midY = x+math.floor(w/2), y+math.floor(h/2)
	local textY = midY-math.floor(self._textHeight/2)
	local opacity = (self._active and 1 or 0.3)

	self:trigger('beforedraw', x, y, w, h)

	-- Layout background
	drawBackground(self)

	-- Input background
	local isHovered = (self:isKeyboardFocus() or self._active and self:isHovered(true))
	-- Background
	if (self:isKeyboardFocus()) then
		LG.setColor(100, 255, 100, 40)
		LG.rectangle('fill', x+1, y+1, w-2, h-2)
	end
	-- Border
	LG.setColor(255, 255, 255, (isHovered and 255 or 100)*opacity)
	LG.rectangle('line', x+1+0.5, y+1+0.5, w-2-1, h-2-1)

	self._gui:_setScissor(x+self.PADDING-1, y+self.PADDING-1, self._layoutInnerWidth+2, self._layoutInnerHeight+2)

	-- Selection
	if (self:isKeyboardFocus()) then
		local x1, x2 = self._field:getSelectionOffset()
		if (x2 > x1) then
			LG.setColor(255, 255, 0, 100)
			LG.rectangle('fill', x+self.PADDING+x1, textY, x2-x1, self._textHeight)
		end
	end

	-- Value
	LG.setFont(self:getFont())
	LG.setColor(255, 255, 255, 255*opacity)
	LG.print(self._field:getVisibleText(), x+self.PADDING+self._field:getTextOffset(), textY)

	-- Cursor
	if (self:isKeyboardFocus()) then
		local opacity = ((math.cos(5*self._field:getBlinkPhase())+1)/2)^0.5
		LG.setColor(255, 255, 255, 255*opacity)
		LG.rectangle('fill', x+self.PADDING+self._field:getCursorOffset()-1, textY, 1, self._textHeight)
	end

	self._gui:_setScissor(nil)

	self:trigger('afterdraw', x, y, w, h)

end



-- focus( )
function Cs.input:focus()
	local gui = self._gui
	if (gui._keyboardFocus == self) then
		return
	end

	self._savedValue = self:getValue()
	self._savedKeyRepeat = love.keyboard.hasKeyRepeat()

	gui:navigateTo(gui._navigationTarget and self or nil)
	gui._lockNavigation = true

	setKeyboardFocus(gui, self)
	setMouseFocus(gui, self, 0)

	love.keyboard.setKeyRepeat(true)

	self._field:resetBlinking()

	playSound(self, 'focus')

	self:triggerBubbling('focused', self)
end

-- blur( )
function Cs.input:blur()
	local gui = self._gui
	if (gui._keyboardFocus ~= self) then
		return
	end

	setKeyboardFocus(gui, nil)
	setMouseFocus(gui, nil)

	gui._lockNavigation = false

	love.keyboard.setKeyRepeat(self._savedKeyRepeat)

	self._field:setScroll(0)

	local v = self:getValue()
	if (v ~= self._savedValue) then
		self:trigger('change', v)
	end

	self:triggerBubbling('blurred', self)
end

-- state = isFocused( )
function Cs.input:isFocused()
	return self:isKeyboardFocus()
end



-- getField
Cs.input:defineGet('_field')



-- value = getValue( )
function Cs.input:getValue()
	return self._field:getText()
end

-- setValue( value )
function Cs.input:setValue(value)
	return self._field:setText(value)
end

-- value = getVisibleValue( )
-- Will return "***" for passwords.
function Cs.input:getVisibleValue()
	return self._field:getVisibleText()
end



-- state = isPasswordActive( )
function Cs.input:isPasswordActive()
	return self._field:isPasswordActive()
end

-- setPasswordActive( state )
function Cs.input:setPasswordActive(state)
	self._field:setPasswordActive(state)
end



-- REPLACE handled, grabFocus = _keyDown( key, scancode, isRepeat )
function Cs.input:_keyDown(key, scancode, isRepeat)
	if (key == 'escape') then
		if (not isRepeat) then
			self._field:setText(self._savedValue)
			self:blur()
			playSound(self, 'inputrevert')
		end
	elseif (key == 'return' or key == 'kpenter') then
		if (not isRepeat) then
			self:blur()
			playSound(self, 'inputsubmit')
			self:trigger('submit')
		end
	else
		self._field:keyDown(key, scancode, isRepeat)
	end
	return true, false
end

-- -- REPLACE _keyUp( key, scancode )
-- function Cs.input:_keyUp(key, scancode)
-- end

-- REPLACE _textInput( text )
function Cs.input:_textInput(text)
	self._field:textInput(text)
end



-- REPLACE handled, grabFocus = _mouseDown( x, y, button )
function Cs.input:_mouseDown(x, y, buttonN)
	if (not self._active) then
		return true, false
	end
	if (not self:isHovered()) then
		self:blur()
		return true, false
	end
	self:focus()
	self._gui._mouseFocusSet[buttonN] = true
	self._field:mouseDown(x-self._layoutX-self.PADDING, 0, buttonN)
	return true, false -- NOTE: We've set the focus ourselves
end

-- REPLACE _mouseMove( x, y )
function Cs.input:_mouseMove(x, y)
	self._field:mouseMove(x-self._layoutX-self.PADDING, 0)
end

-- REPLACE _mouseUp( x, y, button )
function Cs.input:_mouseUp(x, y, buttonN)
	self._field:mouseUp(x-self._layoutX-self.PADDING, 0, buttonN)
end



-- REPLACE handled = _ok( )
function Cs.input:_ok()
	self._gui._ignoreKeyboardInputThisFrame = true
	if (not self:isFocused()) then
		self:focus()
	else
		self:blur()
	end
	return true
end



-- OVERRIDE setActive( state )
function Cs.input:setActive(state)
	if (state == false) then
		self:blur()
	end
	Cs.input.super.setActive(self, state)
end



-- REPLACE _updateLayoutSize( )
function Cs.input:_updateLayoutSize()
	local font = self:getFont()
	self._textWidth = font:getWidth(self._text)
	self._textHeight = font:getHeight()
	self._layoutWidth = self._width
	self._layoutHeight = (self._height or self._textHeight+2*self.PADDING)
	self._layoutInnerWidth = self._layoutWidth-2*self.PADDING
	self._layoutInnerHeight = self._layoutHeight-2*self.PADDING
	self._field:setWidth(self._layoutInnerWidth)
end

-- OVERRIDE _expandLayout( [ expandWidth, expandHeight ] )
function Cs.input:_expandLayout(expandW, expandH)
	Cs.input.super._expandLayout(self, expandW, expandH)
	self._layoutInnerWidth = self._layoutWidth-2*self.PADDING
	self._layoutInnerHeight = self._layoutHeight-2*self.PADDING
	self._field:setWidth(self._layoutInnerWidth)
end



--==============================================================
--==============================================================
--==============================================================

return Gui
