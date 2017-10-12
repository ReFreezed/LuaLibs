--[[============================================================
--=
--=  Cutscene class
--=
--=  Dependencies:
--=  - refreezed.class
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

	update
	draw

	addFrame, addWaitFrame
	isActive, isPlaying, isPaused, play, pause, stop, abort, restart
	progress

--============================================================]]



local newClass = require((...):gsub('%.init$', ''):gsub('%.%w+$', '')..'.class')

local Cutscene = newClass('Cutscene', {

	_currentFrame = 1, _frameTime = 0.0,
	_isPlaying = true, -- Auto-play cutscene right away when created.
	_sequence = nil,

	onAbort = nil,

})

local emptyTable = {}
local noop = function()end



--==============================================================
--==============================================================
--==============================================================



-- Cutscene( [ sequence ] )
-- sequence: List of...
--    waitTime
--    duration=infinite, updateCallback [, drawName1, drawCallback1, ... ]
--    duration=infinite, drawName1, drawCallback1 [, ... ]
-- sequence can also contain these properties:
--    onAbort = function( )
-- Example: local cutscene = Cutscene{ 1.5,playIntro, 3.0,updateAnimPos,"anim",drawAnim, 0,finalize }
function Cutscene:init(quickSeq)

	self._sequence = {}

	if quickSeq then
		local i = 1
		while (quickSeq[i] or quickSeq[i+1]) do
			local nextType = type(quickSeq[i+1])

			-- duration, updateCallback
			-- duration, updateCallback [, drawName1, drawCallback1, ... ]
			-- nil, updateCallback [, drawName1, drawCallback1, ... ]
			-- nil, drawName1, drawCallback1, ...
			if (nextType == 'function' or nextType == 'string') then

				-- Get frame duration.
				local duration = quickSeq[i]
				if not (type(duration) == 'number' or duration == nil) then
					error('expected a number or nil at index '..i..' but instead got a '..type(duration), 3)
				end
				i = i+1

				-- Get update callback.
				local updateCb = quickSeq[i]
				if type(updateCb) == 'string' then
					updateCb = nil
				else
					if type(updateCb) ~= 'function' then
						error('expected a function at index '..i..' but instead got a '..type(updateCb), 3)
					end
					i = i+1
				end

				-- Collect drawing name and callback pairs.
				local drawCbs = nil
				while type(quickSeq[i]) == 'string' do
					local drawCb = quickSeq[i+1]
					if type(drawCb) ~= 'function' then
						error('draw name "'..quickSeq[i]..'" was not followed by a function', 3)
					end
					drawCbs = (drawCbs or {})
					drawCbs[quickSeq[i]] = drawCb
					i = i+2
				end

				self:addFrame(duration, updateCb, drawCbs)

			-- zeroDurationCallback
			-- waitTime
			else
				local v = quickSeq[i]
				local vType = type(v)
				if not (vType == 'function' or vType == 'number') then
					error('expected a function or number at index '..i..' but instead got a '..vType, 3)
				end
				self:addFrame(v)
				i = i+1
			end
		end
		self.onAbort = quickSeq.onAbort
	end

end



-- success = update( deltaTime )
function Cutscene:update(dt)
	if not dt then
		error('missing deltaTime argument', 2)
	end
	if not self._isPlaying then  return false  end

	local sequence = self._sequence
	local frameData = sequence[self._currentFrame]
	if not frameData then  return false  end

	-- Progress cutscene.
	local time = self._frameTime+dt

	-- End of frame.
	local duration = frameData.duration
	if time >= duration then

		-- Ensure the callback gets progress=100% before we move on.
		frameData.updateCallback(1, duration, duration)

		-- Advance frame.
		self._currentFrame = self._currentFrame+1
		self._frameTime = time-duration

		-- Run through following zero-duration frames.
		while true do
			frameData = sequence[self._currentFrame]
			if (not frameData or frameData.duration > 0) then  break  end
			frameData.updateCallback(1, 0, 0)
			-- If updateCallback() calls progress() then we'll end up skipping frames! Should we detect this?
			-- A similar thing happens if restart() is called.
			self._currentFrame = self._currentFrame+1
		end

	-- Middle of frame.
	else
		self._frameTime = time
		frameData.updateCallback(time/duration, time, duration)

	end

	return true
end



-- success = draw( name )
function Cutscene:draw(name)
	local frameData = self._sequence[self._currentFrame]
	if not frameData then  return false  end
	local cb = frameData.drawCallbacks[name]
	if cb then
		local duration = frameData.duration
		local time = math.min(self._frameTime, duration)
		cb(time/duration, time, duration)
	end
	return true
end



--==============================================================
--==============================================================
--==============================================================



-- addFrame( [ duration=infinite, updateCallback, drawCallbacks ] )
-- addFrame( zeroDurationCallback )
function Cutscene:addFrame(duration, updateCb, drawCbs)
	if type(duration) == 'function' then
		duration, updateCb, drawCbs = 0, duration, nil
	end
	table.insert(self._sequence, {
		duration = (duration or math.huge),
		updateCallback = (updateCb or noop),
		drawCallbacks = (drawCbs or emptyTable),
	})
end

-- Add a frame with infinite duration and optionally have a callback before and/or after.
-- addWaitFrame( [ beforeCallback, afterCallback ] )
function Cutscene:addWaitFrame(beforeCb, afterCb)
	if beforeCb then  self:addFrame(beforeCb)  end
	self:addFrame(math.huge)
	if afterCb then  self:addFrame(afterCb)  end
end



-- Check if the cutscene is playing or has finished.
-- state = isActive( )
function Cutscene:isActive()
	return (self._sequence[self._currentFrame] ~= nil)
end

-- state = isPlaying( )
function Cutscene:isPlaying()
	return (self:isActive() and self._isPlaying)
end

-- state = isPaused( )
function Cutscene:isPaused()
	return (self:isActive() and not self._isPlaying)
end

-- play( )
function Cutscene:play()
	self._isPlaying = true
end

-- pause( )
function Cutscene:pause()
	self._isPlaying = false
end

-- stop( )
function Cutscene:stop()
	self._currentFrame = #self._sequence+1 -- Just fast-forward to the end.
end

-- abort( )
function Cutscene:abort()
	if self:isActive() then
		self:stop()
		local onAbort = self.onAbort
		if onAbort then onAbort() end
	end
end

-- restart( )
function Cutscene:restart()
	self._currentFrame = 1
	self._frameTime = 0
end



-- Force the cutscene to progress to the next frame (useful in frames with infinite duration).
-- success = progress( [ keepTiming=false ] )
--   keepTiming: If true the next frame will appear without changing the timing of the remaining frames.
--   success: Is false if the cutscene has already finished playing.
function Cutscene:progress(keepTiming)
	local frameData = self._sequence[self._currentFrame]
	if not frameData then  return false  end
	self._currentFrame = self._currentFrame+1
	self._frameTime = (keepTiming and frameData.duration ~= math.huge and self._frameTime-frameData.duration or 0)
	return true
end



--==============================================================
--==============================================================
--==============================================================

return Cutscene
