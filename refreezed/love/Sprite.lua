--[[============================================================
--=
--=  Sprite class v1.0
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See the bottom of this file)
--=
--=  Dependencies:
--=  - LÖVE 0.10.2 (May work with earlier versions.)
--=  - refreezed.class
--=  - refreezed.love.Animation
--=
--==============================================================

	update
	draw

	clone, copyStateFrom
	getAnchor, setAnchor, centerAnchor, floorAnchor
	getAnimation, getAnimationName, setAnimation
	getAnimationSpeed, setAnimationSpeed, getDynamicAnimationSpeed, setDynamicAnimationSpeed
	getBlendMode, setBlendMode
	getColor, setColor, setRed, setGreen, setBlue, setAlpha, isColorActive, setColorActive
	getCurrentFrame, setCurrentFrame, getCurrentFrameTime, setCurrentFrameTime
	getCurrentImage
	getDimensions, getWidth, getHeight, getScaledDimensions, getScaledWidth, getScaledHeight
	getImageFrameCount, setImageFrame, setRandomImageFrame
	getLeft, getTop
	getName, setName
	getOffset, getOffsetX, getOffsetY, setOffset, setOffsetX, setOffsetY, translateOffset
	getPixelSnapper, setPixelSnapper
	getRotation, setRotation
	getScale, getScaleX, getScaleY, setScale, setScaleX, setScaleY
	getShader, setShader
	getShaderValue, getShaderColorValue, setShaderValue, setShaderColorValue, setDynamicShaderValue, removeShaderValue, removeShaderColorValue, removeDynamicShaderValue
	getSpriteBatch, setSpriteBatch
	getTotalDuration
	gotoMessage
	isActive, isPlaying
	isFlippedX, isFlippedY, getDirectionNumberX, getDirectionNumberY, setFlippedX, setFlippedY
	isSimple, setSimple
	isSkippingFrames, setSkipFramesActive
	play, pause, stop

--============================================================]]



local newClass = require(
	(...) :gsub('%.init$', '') :gsub('%.%w+%.%w+$', '') .. '.class' -- In parent folder.
)

local Sprite = newClass('Sprite', {

	FRAME_MAX_LOOPS = 1000,

	_name = '',

	-- Copyable attributes.
	_anchorX = 0.0, _anchorY = 0.0,
	_animation = nil,
	_animationSpeed = 1.0, _dynamicAnimationSpeed = 1.0,
	_blendMode = 'alpha',
	_color = nil, _colorIsActive = true,
	_flipX = false, _flipY = false,
	_isActive = true, -- Inactive sprites are not drawn.
	_isPlaying = true,
	_isSimple = false,
	_offsetX = 0.0, _offsetY = 0.0,
	_opacity = 1.0,
	_rotation = 0.0,
	_scaleX = 1.0, _scaleY = 1.0,
	_shader = nil, _shaderValues = nil, _shaderColorValues = nil, _dynamicShaderValues = nil,
	_skipFrames = true,
	_snapToPixels = true, _pixelSnapper = nil,

	_spriteBatch = nil, _idInSpriteBatch = nil,

	_currentFrame = 1,
	_currentFrameTime = 0.0,
	_preventFrameChange = false,

	onLoop = nil,
	onMessage = nil,
	onPlay = nil,
	onStop = nil,

})



--==============================================================
--==============================================================
--==============================================================

local copyTableDeep
local printf, printerror, assertarg
local trigger



-- table = copyTableDeep( table )
function copyTableDeep(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = (type(v) == 'table' and copyTableDeep(v) or v)
	end
	return copy
end



-- printf( formatString, ... )
function printf(s, ...)
	print(s:format(...))
end

-- printerror( depth, formatString, ... )
function printerror(depth, s, ...)

	local time = require'socket'.gettime()
	local timeStr = os.date('%H:%M:%S', time)
	local msStr = F'%.3f'(time%1):sub(2)
	printf('[%s%s] ERROR: '..s, timeStr, msStr, ...)

	-- Traceback.
	for line in debug.traceback('', 1+depth):gmatch'[^\n]+' do
		local fileAndLine, inside = line:match'\t(%w.-): in (.+)'
		if fileAndLine then
			inside = inside:gsub('^function ', ''):gsub("^['<](.+)['>]$", '%1')
			printf('\t%s  (%s)', fileAndLine, inside)
		end
	end

	print()
end

-- value = assertarg( [ functionName=auto, ] argumentNumber, value, expectedValueType... [, depth=1 ] )
do
	local function assertArgTypes(fName, n, v, ...)
		local vType = type(v)
		local varargCount = select('#', ...)
		local lastArg = select(varargCount, ...)
		local hasDepthArg = (type(lastArg) == 'number')
		local typeCount = varargCount+(hasDepthArg and -1 or 0)
		for i = 1, typeCount do
			if vType == select(i, ...) then
				return v
			end
		end
		local depth = 3+(hasDepthArg and lastArg or 1)
		if not fName then
			fName = debug.traceback('', depth-2):match(": in function '(.-)'") or '?'
		end
		local expects = table.concat({...}, ' or ', 1, typeCount)
		error(("bad argument #%d to '%s' (%s expected, got %s)"):format(n, fName, expects, vType), depth)
	end

	function assertarg(fNameOrArgNum, ...)
		if type(fNameOrArgNum) == 'string' then
			return assertArgTypes(fNameOrArgNum, ...)
		else
			return assertArgTypes(nil, fNameOrArgNum, ...)
		end
	end

end



-- trigger( sprite, eventAttribute, arg... )
function trigger(self, eAttr, ...)
	local f = self[eAttr]
	if f then
		f(self, ...)
	end
end



--==============================================================
--==============================================================
--==============================================================



-- Sprite( spriteName [, animation ] )
function Sprite:init(spriteName, anim)
	assertarg(1, spriteName, 'string')
	assertarg(2, anim,       'table','nil')

	self._color = {255,255,255,255}
	self._name = spriteName

	self:setAnimation(anim)

end



-- frameChanged = update( deltaTime )
do
	local function updateFrame(self, frameI, frameDuration, frameTime)
		if not self._skipFrames then
			frameTime = math.min(frameTime, frameDuration-0.0001)
		end
		if not self._preventFrameChange then
			self._currentFrame = frameI
			self._currentFrameTime = frameTime
		end
		return frameTime
	end

	function Sprite:update(dt)
		assertarg(1, dt, 'number')

		if (not self._animation or not self._isPlaying) then
			return false
		end

		dt = dt*self._animationSpeed*self._dynamicAnimationSpeed
		if dt <= 0 then
			return false
		end

		local anim = self._animation
		local len = #anim
		if len == 1 then
			return false
		end

		local frameI = self._currentFrame
		local frameData = anim[frameI]
		local frameDuration = frameData.duration

		local frameTime = self._currentFrameTime+dt
		if frameTime < frameDuration then
			self._currentFrameTime = frameTime
		else
			frameTime = frameTime-frameDuration
			self._currentFrameTime = frameTime
			self._preventFrameChange = false -- Callbacks here below could switch this.
			for i = 1, self.FRAME_MAX_LOOPS do
				frameI = frameI+1

				-- Loop.
				if frameI > len then
					frameI = 1
					if anim.loop then
						trigger(self, 'onLoop')
					else
						self:stop()
					end
					frameData = anim[frameI]
					frameDuration = frameData.duration
					frameTime = updateFrame(self, frameI, frameDuration, frameTime)
					if (frameTime < frameDuration or not (self._isActive and self._isPlaying)) then
						return true
					end
					frameTime = frameTime-frameDuration

				-- No loop yet.
				else
					frameData = anim[frameI]
					frameDuration = frameData.duration
					if frameData.type == 'message' then
						trigger(self, 'onMessage', frameData.message, frameData)
					else--if frameData.type == 'image' then
						frameTime = updateFrame(self, frameI, frameDuration, frameTime)
						if (frameTime < frameDuration) or not (self._isActive and self._isPlaying) then
							return true
						end
						frameTime = frameTime-frameDuration
					end

				end
				if i == self.FRAME_MAX_LOOPS then
					printf('[Sprite] Possible infinite frame loop in sprite %q. Breaking.', self._name)
				end
			end
		end

		return false
	end

end



-- draw( [ x=0, y=0, pixelSnapper=self:getPixelSnapper() ] )
-- x, y = pixelSnapper( x, y )
function Sprite:draw(x, y, snapper)
	-- assertarg(1, x, 'number','nil')
	-- assertarg(2, y, 'number','nil')

	if not self._isActive then return end

	local anim = self._animation
	if not anim then return end

	local image = anim.image
	local quad = anim[self._currentFrame].quad

	local dirNumX = (self._flipX and -1 or 1)
	local dirNumY = (self._flipY and -1 or 1)

	x = (x or 0)+self._offsetX*dirNumX
	y = (y or 0)+self._offsetY*dirNumY

	if self._snapToPixels or snapper then
		snapper = (snapper or self._pixelSnapper)
		if snapper then
			x, y = snapper(x, y)
		else
			x, y = math.floor(x+0.5), math.floor(y+0.5)
		end
	end

	local rotation = self._rotation*dirNumX*dirNumY
	local sx, sy = self._scaleX*dirNumX, self._scaleY*dirNumY
	local _, _, qw, qh = quad:getViewport()
	local ox, oy = qw*self._anchorX, qh*self._anchorY

	-- Simple sprites don't change the LÖVE state and can thus easily be used in to sprite batches.
	if self._isSimple then
		local batch = self._spriteBatch
		if batch then
			batch:set(self._idInSpriteBatch, quad, x, y, rotation, sx, sy, ox, oy)
		else
			LG.draw(image, quad, x, y, rotation, sx, sy, ox, oy)
		end

	else

		local r, g, b, a
		if self._colorIsActive then
			r, g, b, a = unpack(self._color)
		else
			r, g, b, a = LG.getColor()
		end
		a = a*self._opacity
		if a == 0 then
			return
		end

		LG.push('all')

		LG.setColor(r, g, b, a)
		LG.setBlendMode(self._blendMode)

		local shader = self._shader
		if shader then
			LG.setShader(shader)

			local shaderValues = self._shaderValues
			if shaderValues then
				for k, v in pairs(shaderValues) do
					shader:send(k, v)
				end
			end

			local shaderColorValues = self._shaderColorValues
			if shaderColorValues then
				for k, v in pairs(shaderColorValues) do
					shader:sendColor(k, v)
				end
			end

			local dynamicShaderValues = self._dynamicShaderValues
			if dynamicShaderValues then
				for k, cb in pairs(dynamicShaderValues) do
					shader:send(k, cb(self))
				end
			end

		end

		LG.draw(image, quad, x, y, rotation, sx, sy, ox, oy)

		LG.pop()
	end

end



--==============================================================
--==============================================================
--==============================================================



-- sprite = clone( [ includePosition=false ] )
function Sprite:clone(includePos)
	local clone = Sprite(self._name)
	clone:copyStateFrom(self, includePos)
	return clone
end

-- copyStateFrom( sprite [, includePosition=false ] )
function Sprite:copyStateFrom(other, includePos)
	assertarg(1, other, 'table')
	assertarg(2, includePos, 'boolean','nil')

	self._anchorX, self._anchorY = other._anchorX, other._anchorY
	self._animation = other._animation
	self._animationSpeed, self._dynamicAnimationSpeed = other._animationSpeed, other._dynamicAnimationSpeed
	self._blendMode = other._blendMode
	self._color = {unpack(other._color)}
	self._flipX, self._flipY = other._flipX, other._flipY
	self._isActive = other._isActive
	self._isPlaying = other._isPlaying
	self._isSimple = other._isSimple
	self._offsetX, self._offsetY = other._offsetX, other._offsetY
	self._opacity = other._opacity
	self._rotation = other._rotation
	self._scaleX, self._scaleY = other._scaleX, other._scaleY
	self._shader = other._shader
	self._skipFrames = other._skipFrames
	self._snapToPixels, self._pixelSnapper = other._snapToPixels, other._pixelSnapper
	-- Should we copy sprite batch stuff too? I don't think so...

	self._shaderValues = (other._shaderValues and copyTableDeep(other._shaderValues))
	self._shaderColorValues = (other._shaderColorValues and copyTableDeep(other._shaderColorValues))
	self._dynamicShaderValues = (other._dynamicShaderValues and copyTableDeep(other._dynamicShaderValues))

	self._currentFrame = (includePos and other._currentFrame or 1)
	self._currentFrameTime = (includePos and other._currentFrameTime or 0)
	self._preventFrameChange = true

end



-- anchorX, anchorY = getAnchor( )
function Sprite:getAnchor()
	return self._anchorX, self._anchorY
end

-- setAnchor( anchorX, anchorY )
function Sprite:setAnchor(anchorX, anchorY)
	assertarg(1, anchorX, 'number')
	assertarg(2, anchorY, 'number')
	self._anchorX, self._anchorY = anchorX, anchorY
end

-- centerAnchor( )
function Sprite:centerAnchor()
	self._anchorX, self._anchorY = 0.5, 0.5
end

-- floorAnchor( )
function Sprite:floorAnchor()
	self._anchorX, self._anchorY = 0.5, 1
end



-- getAnimation
Sprite:defget'_animation'

-- animationName = getAnimationName( )
function Sprite:getAnimationName()
	return (self._animation and self._animation.name)
end

-- animationChanged = setAnimation( animation )
-- 'animation' can be nil.
function Sprite:setAnimation(anim)
	assertarg(1, anim, 'table','nil')

	if self._animation == anim then
		return false
	end

	if (anim and not anim[1]) then
		printerror(2, 'Animation has no frames.')
		return false
	end

	self._animation = anim
	self._currentFrame = 1
	self._currentFrameTime = 0

	if (self._isActive and not self._isPlaying) then
		self:play()
	end

	self._preventFrameChange = true
	return true
end



-- getAnimationSpeed, setAnimationSpeed
Sprite:def'_animationSpeed'

-- getDynamicAnimationSpeed, setDynamicAnimationSpeed
-- 'dynamicAnimationSpeed' is really just a second 'animationSpeed'.
Sprite:def'_dynamicAnimationSpeed'



-- getBlendMode
Sprite:defget'_blendMode'

-- setBlendMode( blendMode )
function Sprite:setBlendMode(blendMode)
	assertarg(1, blendMode, 'string')
	self._blendMode = blendMode
end



-- red, green, blue, alpha = getColor( )
function Sprite:getColor()
	return unpack(self._color)
end

-- setColor( red, green, blue [, alpha=255 ] )
-- setColor( grey [, alpha=255 ] )
-- setColor( color )
-- color = { red, green, blue [, alpha=255 ] )
-- color = { grey [, alpha=255 ] )
function Sprite:setColor(_1, _2, _3, _4)
	if type(_1) == 'table' then
		return self:setColor(unpack(_1))
	end
	assertarg(1, _1, 'number')
	local color = self._color
	if _3 then
		assertarg(2, _2, 'number')
		color[1], color[2], color[3], color[4] = _1, _2, _3, (_4 or 255)
	else
		color[1], color[2], color[3], color[4] = _1, _1, _1, (_2 or 255)
	end
end

-- setRed( red )
function Sprite:setRed(r)
	assertarg(1, r, 'number')
	self._color[1] = r
end

-- setGreen( green )
function Sprite:setGreen(g)
	assertarg(1, g, 'number')
	self._color[2] = g
end

-- setBlue( blue )
function Sprite:setBlue(b)
	assertarg(1, b, 'number')
	self._color[3] = b
end

-- setAlpha( alpha )
function Sprite:setAlpha(a)
	assertarg(1, a, 'number')
	self._color[4] = a
end

-- state = isColorActive( )
function Sprite:isColorActive()
	return self._colorIsActive
end

-- setColorActive( state )
function Sprite:setColorActive(state)
	assertarg(1, state, 'boolean')
	self._colorIsActive = state
end



-- getCurrentFrame, setCurrentFrame
Sprite:def'_currentFrame'

-- getCurrentFrameTime, setCurrentFrameTime
Sprite:def'_currentFrameTime'



-- image, quad = getCurrentImage( )
-- Returns nil if the sprite has no animation.
function Sprite:getCurrentImage()
	local anim = self._animation
	if not anim then  return nil  end
	local frameData = anim[self._currentFrame]
	return anim.image, frameData.quad
end



-- width, height = getDimensions( )
function Sprite:getDimensions()
	local anim = self._animation
	if not anim then  return 0, 0  end
	return select(3, anim[self._currentFrame].quad:getViewport())
end

-- width = getWidth( )
function Sprite:getWidth()
	local anim = self._animation
	if not anim then  return 0  end
	return (select(3, anim[self._currentFrame].quad:getViewport()))
end

-- height = getHeight( )
function Sprite:getHeight()
	local anim = self._animation
	if not anim then  return 0  end
	return select(4, anim[self._currentFrame].quad:getViewport())
end

-- width, height = getScaledDimensions( )
function Sprite:getScaledDimensions()
	local w, h = self:getDimensions()
	return w*self._scaleX, h*self._scaleY
end

-- width = getScaledWidth( )
function Sprite:getScaledWidth()
	return self:getWidth()*self._scaleX
end

-- height = getScaledHeight( )
function Sprite:getScaledHeight()
	return self:getHeight()*self._scaleY
end



-- count = getImageFrameCount( )
function Sprite:getImageFrameCount()
	local anim = self._animation
	return (anim and anim:getImageFrameCount() or 0)
end

-- success = setImageFrame( number )
function Sprite:setImageFrame(n)

	local anim = self._animation
	local frameI = (anim and anim:getImageFrame(n))
	if not frameI then  return false  end

	self._currentFrame = frameI
	self._currentFrameTime = 0
	self._preventFrameChange = true

	return true
end

-- setRandomImageFrame( [ randomNumberGenerator ] )
function Sprite:setRandomImageFrame(rng)

	local anim = self._animation
	if not (anim and anim[2]) then
		return
	end

	local time = anim:getTotalDuration()*(rng and rng:random() or math.random())
	self._currentFrame, self._currentFrameTime = anim:getImageFrameAt(time)
	self._preventFrameChange = true

end



-- x = getLeft( )
function Sprite:getLeft()
	local anim = self._animation
	if not anim then  return 0  end
	local _, _, w, h = anim[self._currentFrame].quad:getViewport()
	return self._offsetX-w*self._anchorX
end

-- y = getTop( )
function Sprite:getTop()
	local anim = self._animation
	if not anim then  return 0  end
	local _, _, w, h = anim[self._currentFrame].quad:getViewport()
	return self._offsetY-h*self._anchorY
end



-- getName, setName
Sprite:def'_name'



-- offsetX, offsetX = getOffset( )
function Sprite:getOffset()
	return self._offsetX, self._offsetY
end

-- setOffset( offsetX, offsetY )
function Sprite:setOffset(offsetX, offsetY)
	assertarg(1, offsetX, 'number')
	assertarg(2, offsetY, 'number')
	self._offsetX, self._offsetY = offsetX, offsetY
end

-- getOffsetX, setOffsetX
Sprite:def'_offsetX'

-- getOffsetY, setOffsetY
Sprite:def'_offsetY'

-- translateOffset( offsetX, offsetY )
function Sprite:translateOffset(offsetX, offsetY)
	assertarg(1, offsetX, 'number')
	assertarg(2, offsetX, 'number')
	self._offsetX, self._offsetY = self._offsetX+offsetX, self._offsetY+offsetY
end



-- getOpacity, setOpacity
Sprite:def'_opacity'



-- pixelSnapper = getPixelSnapper( )
-- setPixelSnapper( pixelSnapper )
-- x, y = pixelSnapper( x, y )
Sprite:def'_pixelSnapper'



-- getRotation, setRotation
Sprite:def'_rotation'



-- scaleX, scaleX = getScale( )
function Sprite:getScale()
	return self._scaleX, self._scaleY
end

-- setScale( scaleX [, scaleY=scaleX ] )
function Sprite:setScale(scaleX, scaleY)
	assertarg(1, scaleX, 'number')
	assertarg(2, scaleY, 'number','nil')
	self._scaleX, self._scaleY = scaleX, (scaleY or scaleX)
end

-- getScaleX, setScaleX
Sprite:def'_scaleX'

-- getScaleY, setScaleY
Sprite:def'_scaleY'



-- getShader
Sprite:defget'_shader'

-- shader = setShader( shader )
function Sprite:setShader(shader)
	assertarg(1, shader, 'userdata')
	self._shader = shader
	return shader
end



-- value = getShaderValue( name )
function Sprite:getShaderValue(k)
	assertarg(1, k, 'string')
	local shaderValues = self._shaderValues
	return (shaderValues and shaderValues[k])
end

-- red, green, blua, alpha = getShaderColorValue( name )
function Sprite:getShaderColorValue(k)
	assertarg(1, k, 'string')

	local shaderColorValues = self._shaderColorValues

	local color = (shaderColorValues and shaderColorValues[k])
	if not color then  return nil  end

	return unpack(color)
end

-- setShaderValue( name, value )
function Sprite:setShaderValue(k, v)
	assertarg(1, k, 'string')
	assert(v ~= nil)

	local shaderValues = self._shaderValues
	if not shaderValues then
		shaderValues = {}
		self._shaderValues = shaderValues
	end

	shaderValues[k] = v
end

-- setShaderColorValue( name, red, green, blue [, alpha=255 ] )
function Sprite:setShaderColorValue(k, r, g, b, a)
	assertarg(1, k, 'string')
	assertarg(2, r, 'number')
	assertarg(3, g, 'number')
	assertarg(4, b, 'number')
	assertarg(5, a, 'number','nil')
	a = (a or 255)

	local shaderColorValues = self._shaderColorValues
	if not shaderColorValues then
		shaderColorValues = {}
		self._shaderColorValues = shaderColorValues
	end

	local color = shaderColorValues[k]
	if not color then
		shaderColorValues[k] = {r,g,b,a}
	else
		color[1], color[2], color[3], color[4] = r, g, b, a
	end

end

-- setDynamicShaderValue( name, callback )
function Sprite:setDynamicShaderValue(k, cb)
	assertarg(1, k, 'string')
	assertarg(2, cb, 'function')

	local dynamicShaderValues = self._dynamicShaderValues
	if not dynamicShaderValues then
		dynamicShaderValues = {}
		self._dynamicShaderValues = dynamicShaderValues
	end

	dynamicShaderValues[k] = cb
end

-- removeShaderValue( name )
function Sprite:removeShaderValue(k)
	assertarg(1, k, 'string')

	local shaderValues = self._shaderValues
	if not shaderValues then  return  end

	shaderValues[k] = nil

	if not next(shaderValues) then
		self._shaderValues = nil
	end
end

-- removeShaderColorValue( name )
function Sprite:removeShaderColorValue(k)
	assertarg(1, k, 'string')

	local shaderColorValues = self._shaderColorValues
	if not shaderColorValues then  return  end

	shaderColorValues[k] = nil

	if not next(shaderColorValues) then
		self._shaderColorValues = nil
	end
end

-- removeDynamicShaderValue( name )
function Sprite:removeDynamicShaderValue(k)
	assertarg(1, k, 'string')

	local dynamicShaderValues = self._dynamicShaderValues
	if not dynamicShaderValues then  return  end

	dynamicShaderValues[k] = nil

	if not next(dynamicShaderValues) then
		self._dynamicShaderValues = nil
	end

end



-- spriteBatch, idInSpriteBatch = getSpriteBatch( )
function Sprite:getSpriteBatch()
	return self._spriteBatch, self._idInSpriteBatch
end

-- idInSpriteBatch = setSpriteBatch( spriteBatch )
-- Returns nil if the sprite couldn't add itself to the batch.
-- Note: Sprite batches are ignored for non-simple sprites when drawing.
-- Note: There's no internal check that the same image is used for the sprite as for the batch.
function Sprite:setSpriteBatch(batch)
	assertarg(1, batch, 'userdata','nil')

	if not batch then
		-- Note: It's not possible to actually remove ourselves from the batch's internal sprite list.
		self._spriteBatch, self._idInSpriteBatch = nil, nil
		return nil
	end

	if self._spriteBatch then
		printerror(2, 'Sprite %q is already in a batch (%s).', self._name, self._spriteBatch)
		return nil
	end

	local idInBatch = batch:add(0, 0)
	if idInBatch == 0 then
		printerror(2, 'Sprite batch is too small. (Our sprite is %q, batch is %q.)', self._name, batch)
		return nil
	end

	self._spriteBatch, self._idInSpriteBatch = batch, idInBatch

	return idInBatch
end



-- duration = getTotalDuration( )
function Sprite:getTotalDuration()
	local anim = self._animation
	return (anim and anim:getTotalDuration() or 0)
end



-- success, errorMessage = gotoMessage( message )
function Sprite:gotoMessage(message)
	assertarg(1, message, 'string')

	local anim = self._animation
	if not anim then
		return false, 'Sprite has no animation.'
	end

	local frameI = anim:getImageFrameAfterMessage(message)
	if not frameI then
		return false, 'Message "'..message..'" not found in sprite.'
	end

	self._preventFrameChange = true
	self._currentFrame = frameI
	self._currentFrameTime = 0

	if not self._isActive then
		self:play()
		self:pause()
	end

	return true
end



-- state = isActive( )
function Sprite:isActive()
	return self._isActive
end

-- state = isPlaying( )
function Sprite:isPlaying()
	return self._isPlaying
end



-- state = isFlippedX( )
function Sprite:isFlippedX()
	return self._flipX
end

-- state = isFlippedY( )
function Sprite:isFlippedY()
	return self._flipY
end

-- directionNumber = getDirectionNumberX( )
function Sprite:getDirectionNumberX()
	return (self._flipX and -1 or 1)
end

-- directionNumber = getDirectionNumberY( )
function Sprite:getDirectionNumberY()
	return (self._flipY and -1 or 1)
end

-- setFlippedX( state )
function Sprite:setFlippedX(state)
	assertarg(1, state, 'boolean')
	self._flipX = state
end

-- setFlippedY( state )
function Sprite:setFlippedY(state)
	assertarg(1, state, 'boolean')
	self._flipY = state
end



-- state = isSimple( )
function Sprite:isSimple()
	return self._isSimple
end

-- setSimple( state )
function Sprite:setSimple(state)
	assertarg(1, state, 'boolean')
	self._isSimple = state
end



-- state = isSkippingFrames( )
function Sprite:isSkippingFrames()
	return self._skipFrames
end

-- setSkipFramesActive( state )
function Sprite:setSkipFramesActive(state)
	assertarg(1, state, 'boolean')
	self._skipFrames = state
end



-- play( )
function Sprite:play()
	if self._isPlaying then  return  end

	local wasActive = self._isActive

	self._isActive = true
	self._isPlaying = true

	if not wasActive then
		trigger(self, 'onPlay')
	end

end

-- pause( [ rollbackUpdate=false ] )
function Sprite:pause(rollbackUpdate)
	assertarg(1, rollbackUpdate, 'boolean','nil')

	if not self._isPlaying then return end

	self._isPlaying = false

	if rollbackUpdate then  self._preventFrameChange = true  end

end

-- stop( )
function Sprite:stop()
	if not self._isActive then return end

	self._isPlaying = false
	self._currentFrame = 1
	self._currentFrameTime = 0
	self._isActive = false
	self._preventFrameChange = true

	trigger(self, 'onStop')

end



--==============================================================
--==============================================================
--==============================================================

return Sprite

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
