--[[============================================================
--=
--=  Animation data class (for the Sprite class)
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See the bottom of this file)
--=
--=  Changelog:
--=    1.1.0 2017-11-01: Added get*Time().
--=    1.0.1 2017-??-??: Quad cache can now be garbage collected.
--=    1.0.0 2017-??-??: First release.
--=
--==============================================================

	getFrameStartingTime, getMessageTime
	getImageFrame, getImageFrameAt, getImageFrameAfterMessage, getImageFrameCount
	getTotalDuration

--============================================================]]



local moduleFolder = ('.'..(...)) :gsub('%.%w+$', '')
local parentFolder = moduleFolder :gsub('%.%w+$', '')
local class = require((parentFolder..'.class'):sub(2))

local Animation = class('Animation', {

	DEFAULT_FRAME_DURATION = 1/60,

	--[[STATIC]] _quadCache = setmetatable({}, {__mode='v'}),

	_imageFrameCount = 0,
	_totalDuration = 0.0,

	image = nil,
	loop = false,
	name = '',

	-- Frame data objects are stored in numerical indices.
	[1] = nil,

})



--==============================================================
--==============================================================
--==============================================================



-- Animation( name, image [, loop=true ] [, frames=oneFrameShowingWholeImage ] )
-- frames = { frame... }
-- frame = { y(0), x(0), width(image.width), height(image.height), duration(DEFAULT_FRAME_DURATION) }
-- frame = { type="image", quad=quad, duration=duration }
-- frame = { type="message", message=message }
function Animation:init(name, image, loop, frames)
	if type(loop) ~= 'boolean' then
		loop, frames = nil, loop
	end
	frames = (frames or {{}})

	self.name = name
	self.image = image
	self.loop = (loop ~= false)

	-- Add/build frame data objects.
	local newQuad = love.graphics.newQuad
	local quads = Animation._quadCache
	local iw, ih = image:getDimensions()
	for i, frameData in ipairs(frames) do
		if not frameData.type then
			local qx, qy = (frameData[2] or 0), (frameData[1] or 0)
			local qw, qh = (frameData[3] or iw), (frameData[4] or ih)
			local quadId = F'%d/%d/%d/%d/%d/%d'(qx, qy, qw, qh, iw, ih)
			local quad = quads[quadId]
			if not quad then
				quad = love.graphics.newQuad(qx, qy, qw, qh, iw, ih)
				quads[quadId] = quad
			end
			frameData = {
				type = 'image',
				quad = quad,
				duration = (frameData[5] or self.DEFAULT_FRAME_DURATION),
			}
		end
		self[i] = frameData
	end

	-- Precalculate useful info.
	local count, duration = 0, 0
	for _, frameData in ipairs(self) do
		if frameData.type == 'image' then
			count = count+1
			duration = duration+frameData.duration
		end
	end
	self._imageFrameCount = count
	self._totalDuration = duration

end



--==============================================================
--==============================================================
--==============================================================



-- time = getFrameStartingTime( frameIndex )
function Animation:getFrameStartingTime(targetFrameI)
	local time = 0
	for frameI, frameData in ipairs(self) do

		if frameI == targetFrameI then return time end

		if frameData.type == 'image' then
			time = time+frameData.duration
		end

	end
	return nil -- The target frame index is out of bounds.
end

-- time = getMessageTime( message )
function Animation:getMessageTime(message)
	local time = 0
	for frameI, frameData in ipairs(self) do

		if frameData.message == message then return time end

		if frameData.type == 'image' then
			time = time+frameData.duration
		end

	end
	return nil -- The message doesn't exist.
end



-- frameIndex, frameData = getImageFrame( number )
function Animation:getImageFrame(n)
	for frameI, frameData in ipairs(self) do
		if frameData.type == 'image' then
			n = n-1
			if n == 0 then
				return frameI, frameData
			end
		end
	end
	return nil -- 'n' is out of bounds.
end

-- frameIndex, frameTime, frameData = getImageFrameAt( time )
function Animation:getImageFrameAt(time)
	time = math.max(time, 0)

	-- Figure out during what frame the time is.
	for frameI, frameData in ipairs(self) do
		if frameData.type == 'image' then
			local nextTime = time-frameData.duration
			if nextTime < 0 then
				return frameI, time, frameData
			end
			time = nextTime
		end
	end

	-- If time is outside total duration, return end of last frame.
	local frameI = #self
	local frameData = self[frameI]
	return frameI, frameData.duration, frameData
end

-- frameIndex, frameData = getImageFrameAfterMessage( message )
function Animation:getImageFrameAfterMessage(message)
	local messageFound = false
	for frameI, frameData in ipairs(self) do
		if not messageFound then
			if frameData.message == message then
				messageFound = true
			end
		elseif frameData.type == 'image' then
			return frameI, frameData
		end
	end
	return nil -- No frame with the specified message exists, or there was no image after the found frame.
end

-- getImageFrameCount
Animation:defget'_imageFrameCount'



-- getTotalDuration
Animation:defget'_totalDuration'



--==============================================================
--==============================================================
--==============================================================

return Animation

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
