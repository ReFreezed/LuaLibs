--[[============================================================
--=
--=  reLua - ReFreezed Lua utility functions v1.1.1
--=  Beware of old code!
--=
--=-------------------------------------------------------------
--=
--=  MIT License
--=
--=  Copyright © 2014-2015 Marcus 'ReFreezed' Thunström
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
--============================================================]]



-- Check Lua version
if (not _VERSION or _VERSION:match('[%d.]+') ~= '5.1') then
	print('[reLua] WARNING: reLua is only tested with Lua 5.1')
end



-- Load modules
local json
do
	local loaded, failed = {}, {}

	local function include(name)
		local success, m = pcall(require, name)
		local messageArr = (success and loaded or failed)
		messageArr[#messageArr+1] = name
		return (success and m or nil)
	end

	json = include('json')

	-- if (loaded[1]) then print('[reLua] Modules loaded: '..table.concat(loaded, ', ')) end
	-- if (failed[1]) then print('[reLua] Modules missing/ignored: '..table.concat(failed, ', ')) end
end















--==============================================================
--=        =====================================================
--=  Base  =====================================================
--=        =====================================================
--==============================================================







local M = {version='1.0'}

local nullMessage = 'reLua.null represents nil and is not a normal table'
M.null = setmetatable({}, {
	__index=function() error(nullMessage, 2); end,
	__metatable=nullMessage,
	__newindex=function() error(nullMessage, 2); end,
	__tostring=function() return 'nil'; end,
})







--[[
	getFunctionSpeed()
		Times the speed of a function call.

	Description:
		speed = getFunctionSpeed( function [, iterations [, ... ] ] )
			- function: The function to call.
			- iterations: How many times the function should be called.
			- ...: Arguments for the function.
			> Returns: The speed in seconds.

	Example:
		reLua.getFunctionSpeed(math.pow, 1000000, 2, 1000) -- e.g. 0.076

]]
function M.getFunctionSpeed(f, iterations, ...)
	iterations = (iterations or 1)
	collectgarbage()
	local startTime = os.clock()
	for i = 1, iterations do
		f(...)
	end
	return os.clock()-startTime
end



-- Function speed test helper
local function test(description, ...)
	if type(description) == 'function' then
		print(M.getFunctionSpeed(description, ...))
	else
		print(description, M.getFunctionSpeed(...))
	end
end















--==============================================================
--=               ==============================================
--=  File system  ==============================================
--=               ==============================================
--==============================================================







--[[
	copyFile()
		Copies a file to another file.

	Description:
		success = copyFile( sourcePath, targetPath )
			- sourcePath: File to copy.
			- targetPath: Target file.
			> Returns: True on success, false otherwise.

	Example:
		reLua.copyFile("C:\\Foo.txt", "C:\\Text files\\Bar.txt")

]]
function M.copyFile(sourcePath, targetPath)
	if (sourcePath == targetPath) then return false, 'Source path and target path is the same' end

	local contents, fail = M.getFileContents(sourcePath)
	if (fail) then return false, 'Could not open the source file' end

	local file = io.open(targetPath, 'wb')
	if (not file) then return false, 'Could not open the target file' end
	file:write(contents)
	file:close()

	return true
end



-- Writes/overwrites a file with the given data string
-- success, failMessage = writeFile( path, dataString )
function M.writeFile(path, dataString)
	local file = io.open(path, 'wb')
	if (not file) then return false, 'Could not open the file' end
	file:write(dataString)
	file:close()
	return true
end



-- Appends a string to the end of a file
-- success, failMessage = appendToFile( path, dataString )
function M.appendToFile(path, dataString)
	local file = io.open(path, 'ab')
	if (not file) then return false, 'Could not open the file' end
	file:write(dataString)
	file:close()
	return true
end







-- Checks if a file exists by trying to read from it
-- result = fileExists( path )
function M.fileExists(path)
	local file = io.open(path, 'r')
	if (file) then
		file:close()
		return true
	else
		return false
	end
end







-- Returns the contents of a file in a string
-- fileContents, failMessage = getFileContents( path )
function M.getFileContents(path)
	local file = io.open(path, 'rb')
	if (not file) then return nil, 'Cannot open the file' end
	local dataString = file:read('*a')
	file:close()
	return dataString
end







-- Loads and parses a JSON file and returns the result
-- loadJsonFile( path )
if json then function M.loadJsonFile(path)
	return (not fail and json.decode(M.getFileContents(path) or ''))
end end

-- Parses and saves an object to a JSON file
-- saveJsonFile( path, dataString )
if json then function M.saveJsonFile(path, data)
	return M.writeFile(path, json.encode(data))
end end















--==============================================================
--=                     ========================================
--=  Garbage collector  ========================================
--=                     ========================================
--==============================================================







do local objects, callbacks, amount = setmetatable({},{__mode='v'}), {}, 0



	--[[
		gcCheck()
			Checks the monitored objects added by gcMonitor and calls the callbacks for collected objects.
			Calls collectgarbage() internally.

		Description:
			monitoredObjectsLeft = gcCheck( )
				> Returns: The amount of monitored objects left.

		Example:
			See reLua.gcMonitor().

	]]
	function M.gcCheck()
		collectgarbage()
		local callbacksToCall
		for i = amount, 1, -1 do
			if (not objects[i]) then
				if (callbacksToCall) then callbacksToCall[#callbacksToCall+1] = callbacks[i] else callbacksToCall = {callbacks[i]} end
				for i = i, amount-1 do objects[i], callbacks[i] = objects[i+1], callbacks[i+1] end
				objects[amount], callbacks[amount], amount = nil, nil, amount-1
			end
		end
		if (callbacksToCall) then
			for i = #callbacksToCall, 1, -1 do callbacksToCall[i]() end
		end
		return amount
	end



	--[[
		gcMonitor()
			Calls a function when an object has been collected by the Garbage Collector (GC) and reLua.gcCheck() has been called.

		Description:
			object = gcMonitor( object, callback )
				- object: The object to monitor.
				- callback: Function to call when 'object' is collected. Note: an object cannot be collected by the GC until absolutely all references to the object is removed. This means that the callback itself cannot know what object was collected.
				> Returns: The object argument.

		Example:
			local gcMonitor = reLua.gcMonitor

			-- Create four objects
			local obj1, obj2, obj3, obj4 = {}, {}, {}, {}

			-- Monitor when each object is collected by GC
			-- (Wneh obj2 is collected we also make obj3 subject for collection)
			gcMonitor(obj1, function()
				print("obj1 has been removed")
			end)
			gcMonitor(obj2, function()
				print("obj2 has been removed")
				print("Removes reference to obj3")
				obj3 = nil
			end)
			gcMonitor(obj3, function()
				print("obj3 has been removed")
			end)
			gcMonitor(obj4, function()
				print("obj4 has been removed")
			end)

			-- Function which keep a reference to each object
			local function referenceAllObjects()
				obj1, obj2, obj3, obj4 = obj1, obj2, obj3, obj4
			end

			-- Call gcCheck() every once in a while
			local frequencyInMs = 200
			runAtIntervals(reLua.gcCheck, frequencyInMs)

			-- After 3 seconds, remove obj2
			local delayInMs = 3000
			runAfterDelay(function()
				print("Removes reference to obj2")
				obj2 = nil
			end, delayInMs)

			-- After 6 seconds, remove the referenceAllObjects function
			local delayInMs = 6000
			runAfterDelay(function()
				print("Removes reference to referenceAllObjects function")
				referenceAllObjects = nil
			end, delayInMs)

	]]
	function M.gcMonitor(obj, callback)
		amount = amount+1
		objects[amount] = obj
		callbacks[amount] = callback
		return obj
	end



end















--==============================================================
--=        =====================================================
--=  Math  =====================================================
--=        =====================================================
--==============================================================







--[[
	closest()
		Returns the value which is closest to a specific value.

	Description:
		closestValue = closest( v, v1 [, ... vN ] )
			- v: The target value.
			- vN: Value selection.
			> Returns: The value in the selection closest to the target value.

	Example:
		reLua.closest(5, 1,7) -- 7
		reLua.closest(5, 1,7,4) -- 4

]]
function M.closest(v, v1, ...)
	local closestDist, closestValue = math.abs(v-v1), v1
	for i = 1, select('#', ...) do
		local compareValue = select(i, ...)
		local compareDist = math.abs(v-compareValue)
		if (compareDist < closestDist) then
			closestValue, closestDist = compareValue, compareDist
		end
	end
	return closestValue
end



--[[
	farthest()
		Returns the value which is farthest from a specific value.

	Description:
		farthestValue = farthest( v, v1 [, ... vN ] )
			- v: The target value.
			- vN: Value selection.
			> Returns: The value in the selection farthest from the target value.

	Example:
		reLua.farthest(5, 1,7) -- 1
		reLua.farthest(5, 1,7,20) -- 20

]]
function M.farthest(v, v1, ...)
	local farthestDist, farthestValue = math.abs(v-v1), v1
	for i = 1, select('#', ...) do
		local compareValue = select(i, ...)
		local compareDist = math.abs(v-compareValue)
		if (compareDist > farthestDist) then
			farthestValue, farthestDist = compareValue, compareDist
		end
	end
	return farthestValue
end







--[[
	distance()
		Returns the distance between two points in an any-dimensional system.

	Description:
		distance = distance( x1 [, y1, ... coord1 ], x2 [, y2, ... coord2 ] )
			- xN, yN, ... coordN: The coordinates of the two points.
			> Returns: The distance between two specified points.

	Example:
		reLua.distance(10, 30) -- 20
		reLua.distance(5,5, 15,15) -- ~14.1
		reLua.distance(25,32,78, -15,258,7) -- ~240.2

]]
function M.distance(...)
	local distSum, dimensions = 0, select('#', ...)*0.5
	for i = 1, dimensions do
		local dist = select(dimensions+i, ...)-select(i, ...)
		distSum = distSum+dist*dist
	end
	return math.sqrt(distSum)
end



--[[
	latLonDist()
		Calculates the distance between two latitude/longitude coordinates.
		Source: http://www.movable-type.co.uk/scripts/latlong.html

	Description:
		distance = latLonDist( lat1, lon1, lat2, lon2 )
			- latN, lonN: The coordinates of the two points.
			> Returns: The distance between two points.

]]
function M.latLonDist(lat1, lon1, lat2, lon2)
	local dLat = math.rad(lat2-lat1)
	local dLon = math.rad(lon2-lon1)
	lat1, lat2 = math.rad(lat1), math.rad(lat2)
	local a = math.sin(dLat/2)*math.sin(dLat/2) + math.sin(dLon/2)*math.sin(dLon/2)*math.cos(lat1)*math.cos(lat2)
	return 2*math.atan2(math.sqrt(a), math.sqrt(1-a)) * 6371 -- km
end







--[[
	lerp()
		Performs (precise) linear interpolation between two values.
		https://en.wikipedia.org/wiki/Linear_interpolation

	Description:
		v = lerp( v1, v2, t )
			- v1, v2: The values to interpolate between.
			- t: The position between v1 and v2 where 0=v1 and 1=v2.
			> Returns: A value between v1 and v2.

	Example:
		reLua.lerp(10, 20, 0.5) -- 15
		reLua.lerp(1000, 2000, 0.2) -- 1200

]]
function M.lerp(v1, v2, t)
	return (1-t)*v1+t*v2
end



--[[
	tween()
		Returns the coordinates of a point between two other points in
			an any-dimensional system using linear interpolation.

	Description:
		x [, y, ... coord ] = tween( percent, x1 [, y1, ... coord1 ], x2 [, y2, ... coord2 ] )
			- percent: How far from the first point towards the second
				point. (0: at first point, 1: at second point point)
			- xN, yN, ... coordN: The coordinates of the two points.
			> Returns: The coordinates of the point between the specified points.

	Example:
		reLua.tween(0.5, 10, 20) -- 15
		reLua.tween(0.2, 1000, 2000) -- 1200
		reLua.tween(0.5, 62,100, 86,204) -- 74,152

]]
function M.tween(percent, ...)
	local values, dimensions = {}, select('#', ...)/2
	for i = 1, dimensions do
		local v1, v2 = select(i, ...), select(dimensions+i, ...)
		values[i] = (1-percent)*v1+percent*v2
	end
	return unpack(values)
end







-- The same as math.max but also works on tables with a __gt metametod
function M.max(v, ...)
	for i = 1, select('#', ...) do
		local v2 = select(i, ...)
		if (v2 > v) then v = v2; end
	end
	return v
end

-- The same as math.min but also works on tables with a __lt metametod
function M.min(v, ...)
	for i = 1, select('#', ...) do
		local v2 = select(i, ...)
		if (v2 < v) then v = v2; end
	end
	return v
end



--[[
	clamp()
		Clamps a number inside an interval.

	Description:
		clampedValue = clamp( value, minValue, maxValue )
			- value: The value to clamp.
			- minValue, maxValue: The min and max boundaries. If min is higher than max then the outcome is undefined.
			> Returns: The clamped value.

	Example:
		reLua.clamp(4, 3, 7) -- 4
		reLua.clamp(1, 3, 7) -- 3
		reLua.clamp(9, 3, 7) -- 7

]]
function M.clamp(n, min, max)
	return math.min(math.max(n, min), max)
end



--[[
	clampWithChecks()
		Clamps a number inside an interval.

	Description:
		clampedValue = clampWithChecks( value, minValue, maxValue )
			- value: The value to clamp. If tonumber(value) isn't a number then nil is returned.
			- minValue, maxValue: The min and max boundaries. If min is higher than max then nil is returned.
			> Returns: The clamped value, or nil if a check didn't pass.

	Example:
		reLua.clampWithChecks(4, 3, 7) -- 4
		reLua.clampWithChecks(1, 3, 7) -- 3
		reLua.clampWithChecks(9, 3, 7) -- 7
		reLua.clampWithChecks("foo", 3, 7) -- nil
		reLua.clampWithChecks(4, 7, 3) -- nil

]]
function M.clampWithChecks(v, min, max)
	if (tonumber(v) == nil or min > max) then return nil end
	return math.min(math.max(v, min), max)
end







--[[
	pointInArea()
		Checks if a point is inside an area in an any-dimensional system.

	Description:
		result = pointInArea( pointX [, pointY, ... pointCoord ], areaX1 [, areaY1, ... areaCoord1 ], areaX2 [, areaY2, ... areaCoord2 ] )
			- pointX, pointY, coordN: The coordinates of the point.
			> Returns: True if the point is inside the area, false otherwise.

	Example:
		local pointInArea = reLua.pointInArea

		-- 2D
		pointInArea(0, 10, 20) -- 0>10 and 0<20 = false
		pointInArea(15, 10, 20) -- 15>10 and 15<20 = true

		-- 3D
		local point = {x=25, y=80}
		local rect = {left=50, top=0, right=100, bottom=100}
		pointInArea(point.x, point.y, rect.left, rect.top, rect.right, rect.bottom) -- (25>50 and 25<100) and (80>0 and 80<100) = false
		point.x = 75
		pointInArea(point.x, point.y, rect.left, rect.top, rect.right, rect.bottom) -- (75>50 and 75<100) and (80>0 and 80<100) = true

]]
function M.pointInArea(...)
	local dims = select('#', ...)/3
	for i = 1, dims do
		local pv = select(i, ...) -- point value
		if (pv <= select(dims+i, ...) or pv >= select(dims+dims+i, ...)) then
			return false
		end
	end
	return true
end



--[[
	pointTouchingArea()
		Checks if a point is touching an area in an any-dimensional system.
		Same as reLua.pointInArea() except also return true if the point only touches the edge of the area.

	Description:
		result = pointTouchingArea( pointX [, pointY, ... pointCoord ], areaX1 [, areaY1, ... areaCoord1 ], areaX2 [, areaY2, ... areaCoord2 ] )
			- pointX, pointY, coordN: The coordinates of the point.
			> Returns: True if the point is inside or touching the edge of the area, false otherwise.

	Example:
		reLua.pointTouchingArea(10, 10, 20) -- 10>=10 and 10<=20 = true
		reLua.pointInArea(10, 10, 20) -- 10>10 and 10<20 = false

]]
function M.pointTouchingArea(...)
	local dims = select('#', ...)/3
	for i = 1, dims do
		local pv = select(i, ...) -- point value
		if (pv < select(dims+i, ...) or pv > select(dims+dims+i, ...)) then
			return false
		end
	end
	return true
end







-- Same as math.floor(v+0.5), with the addition of rounding the number to a given number of decimal places
-- round( value [, decimals=0 ] )
function M.round(v, decimals)
	local exp = 10^(decimals or 0)
	return math.floor(v*exp+0.5)/exp
end

-- Same as math.floor, with the addition of rounding the number to a given number of decimal places
-- floor( value [, decimals=0 ] )
function M.floor(v, decimals)
	local exp = 10^(decimals or 0)
	return math.floor(v*exp)/exp
end

-- Same as math.ceil, with the addition of rounding the number to a given number of decimal places
-- ceil( value [, decimals=0 ] )
function M.ceil(v, decimals)
	local exp = 10^(decimals or 0)
	return math.ceil(v*exp)/exp
end

-- Rounds a number towards zero
-- truncate( value [, decimals=0 ] )
function M.truncate(v, decimals)
	local exp = 10^(decimals or 0)
	return (v >= 0 and math.floor(v*exp) or math.ceil(v*exp))/exp
end

-- Rounds a number away from zero
-- antiTruncate( value [, decimals=0 ] )
function M.antiTruncate(v, decimals)
	local exp = 10^(decimals or 0)
	return (v >= 0 and math.ceil(v*exp) or math.floor(v*exp))/exp
end

-- Rounding info: http://mathforum.org/library/drmath/view/71202.html















--==============================================================
--=           ==================================================
--=  Strings  ==================================================
--=           ==================================================
--==============================================================







--[[
	capitalize()
		Capitalizes the words in a string.

	Description:
		capitalizedString = capitalize( string )
			- string: The string to capitalize.
			> Returns: The capitalized string.

	Example:
		reLua.capitalize("thE WInd BLOwS.") -- The Wind Blows.

]]
function M.capitalize(s)
	return (s:lower():gsub('%f[%a]%a', string.upper))
end







--[[
	chunkString()
		Splits an string into chunks.

	Description:
		chunkString( string, size )
			- string: The string to split.
			- size: The size of each chunk.
			> Returns: An array with chunks of the string.

	Example:
		reLua.chunkString("Hello", 2) -- {"He","ll","o"}

]]
function M.chunkString(s, size)
	size = (size or 1)
	if (size < 1) then error('Invalid size', 2); end
	local chunks = {}
	for i = 1, #s, size do chunks[#chunks+1] = s:sub(i, i+size-1); end
	return chunks
end







--[[
	escapePattern()
		Escapes special characters used in patterns in a string.

	Description:
		escapedString = escapePattern( string )
			- string: The string to escape.
			> Returns: The escaped string.

	Example:
		local searchString = "Contants: 15%dollars, 30%euros, 45%pounds"
		local stringToFind = "(%d+)"..reLua.escapePattern("%dollars") -- %%dollars
		searchString:match(stringToFind) -- 15

]]
function M.escapePattern(s)
	return (s:gsub('([%(%)%.%%%+%-%*%?%[%^%$])', '%%%1'))
end







-- Returns all characters in a string in an array
-- characters = getCharacters( string )
function M.getCharacters(s)
	local chars = {}
	for i = 1, #s do
		chars[i] = s:sub(i, i)
	end
	return chars
end







do
	local intervals = {
		{from=('a'):byte(), to=('z'):byte()},
		{from=('A'):byte(), to=('Z'):byte()},
	}

	-- result = reLua.isLetter( string [, position=1 ] )
	function M.isLetter(str, i)
		local byte = str:byte(i or 1)
		for _, interval in ipairs(intervals) do
			if (byte >= interval.from and byte <= interval.to) then return true; end
		end
		return false
	end

end







--[[
	newStringStack()
		Creates an object that joins many strings together.
		(See: http://www.lua.org/pil/11.6.html)

	Description:
		stack = newStringStack( [ string ] )
			- string: The initial string. (Default: "")
			> Returns: A new string stack object (table with metatable).

	Example:
		local stack = reLua.newStringStack()
		local testStrings = {"a.","foo.","qwerty.","1234.","bar."}

		for i, v in ipairs(testStrings) do
			stack:append(v)
			print(#stack, v)
		end

		print(stack)
		print(#stack)

		-- Output:
		--  1  a.
		--  1  foo.
		--  1  qwerty.
		--  2  1234.
		--  3  bar.
		--  a.foo.qwerty.1234.bar.
		--  1

]]
do

	local function __tostring(stack)
		if (stack[2]) then
			stack[1] = table.concat(stack)
			for i = 2, #stack do stack[i] = nil end
		end
		return stack[1]
	end

	local mt = {
		__index = {append=function(stack, s)
			stack[#stack+1] = s
			for i = #stack-1, 1, -1 do
				if #stack[i] > #stack[i+1] then break end
				stack[i] = stack[i]..table.remove(stack)
			end
		end},
		__tostring = function(stack)
			if (stack[2]) then
				stack[1] = table.concat(stack)
				for i = 2, #stack do stack[i] = nil end
			end
			return stack[1]
		end,
	}

	function M.newStringStack(s)
		return (setmetatable({s or ''}, mt))
	end

end







--[[
	padString()
		Fills the space around a string until it reaches a specific lenth.

	Description:
		paddedString = padString( string, padding, length [, side ] )
			- string: The string to pad.
			- padding: String to pad with.
			- length: The target length. If the string is already equal or longer than 'length' the string is returned untouched.
			- side: Which side to pad. Can be "right" or "left". (Default: "right")
			> Returns: The padded string.

	Example:
		reLua.padString("Hello", "!", 8) -- Hello!!!

]]
function M.padString(s, padding, len, side)
	s, padding, side = tostring(s), tostring(padding), (side or 'right')
	if #s < len then
		if (side == 'right') then
			return s..padding:rep(math.floor((len-#s)/#padding))
		elseif (side == 'left') then
			return padding:rep(math.floor((len-#s)/#padding))..s
		else
			error('Invalid side value', 2)
		end
	else
		return s
	end
end



-- Shorthand for padding numbers with zeroes
-- paddedString = padNumber( number, length )
function M.padNumber(num, len)
	return M.padString(num, 0, len, 'left')
end







-- Shuffles the letters in a string
-- shuffledString = shuffleString( string )
function M.shuffleString(s)
	return string.char(unpack(M.shuffleArray{s:byte(1, #s)}))
end







--[[
	snext()
		Same as the iteration function for the primitive ipairs(), but iterates over string charaters instead of array items.

	Description:
		index, byte = snext( string [, prevIndex ] )
			- string: The string being traversed.
			- prevIndex: The previous index. (Default: 0)
			> Returns: The current index and character byte code, or nil if no more characters exist.

	Example:
		local str = "Abc"
		for i, byte in reLua.snext, str do
			print(string.char(byte))
		end
		-- Prints: A, b, c

		-- Iterate through letters without using reLua.snext():
		for char in str:gmatch(".") do
			print(char)
		end
		-- Prints: A, b, c

]]
function M.snext(s, i)
	i = (i or 0)+1
	local byte = s:byte(i)
	if (byte ~= nil) then return i, byte end
end



-- Same as reLua.snext() but returns the previous character instead of the next
function M.sprev(s, i)
	i = (i and i-1 or #s)
	local byte = s:byte(i)
	if (byte) then return i, byte; end
end







--[[
	spliceString()
		Inserts/removes part of a string.

	Description:
		newString = spliceString( string, from [, amount [, insertion ] ] )
			- string: The string to modify.
			- from: At what index the removal/insertion will occur. If negative, it is taken as the offset from the end of the array.
			- amount: How many charaters should be removed. (Default: all remaining charaters)
			- insertion: String to insert. (Default: "")
			> Returns: The modified string.

	Example:
		reLua.spliceString("Hello", 2, 3, "al") -- Halo
		reLua.spliceString("Hello", 2, nil, "yrule") -- Hyrule
		reLua.spliceString("Hello", -1) -- Hell (the inverse of string.sub("Hello", -1) in this case)

]]
function M.spliceString(s, from, amount, insertion)
	if (from < 0) then from = #s+from+1; end
	return s:sub(1, from-1)..(insertion or '')..(amount and s:sub(from+amount) or '')
end







--[[
	splitString()
		Splits a string.

	Description:
		splittedString, delimiters = splitString( string, delimiter [, plain ] )
			- string: The string to split.
			- delimiter: The delimiter string/pattern.
			- plain: If 'delimiter' is plain text instead of a pattern. (Default: false)
			> Returns: An array containing the splitted string and an array of the delimiters.

	Example:
		reLua.splitString("Hello to you!", " ") -- {"Hello","to","you"}, {" "," "}
		reLua.splitString("Hello big\nworld", "[ \n]") -- {"Hello","big","world"}, {" ","\n"}

]]
function M.splitString(s, delimiter, plain)
	local results, delimiters, startIndex = {}, {}, 1
	for i = 1, math.huge do
		local delimStart, delimEnd = s:find(delimiter, startIndex, plain)
		if (not delimStart) then break; end
		results[i], delimiters[i] = s:sub(startIndex, delimStart-1), s:sub(delimStart, delimEnd)
		startIndex = delimEnd+1
	end
	results[#results+1] = s:sub(startIndex)
	return results, delimiters
end







--[[
	stringMatchAll()
		Returns all matches from a string using string.gmatch().

	Description:
		matches = stringMatchAll( string, pattern [, plain ] )
			- string, pattern: These arguments are the same as string.gmatch().
			- plain: If 'pattern' is plain text instead of a pattern. (Default: false)
			> Returns: An array with all matches.

	Example:
		reLua.stringMatchAll("Good news everyone!", "%w+") -- {"Good", "news", "everyone"}

]]
function M.stringMatchAll(s, pattern, plain)
	local matches = {}
	for match in s:gmatch(plain and M.escapePattern(pattern) or pattern) do matches[#matches+1] = match; end
	return matches
end



--[[ TODO asdf > _, nvow = string.gsub(text, "[AEIOUaeiou]", "")
	stringMatchCount()
		Calculates the amount of matches in a string.
		Note: count=stringMatchCount(s, pat) is faster than count=#stringMatchAll(s, pat) .

	Description:
		amount = stringMatchCount( string, pattern [, plain ] )
			- the arguments are the same as string.find().
			> Returns: The amount of matches.

	Example:
		reLua.stringMatchCount("Hi hi hi!", "hi") -- 2

]]
function M.stringMatchCount(s, pattern, plain)
	local count, len, startIndex = 0, #s, 1
	while (startIndex <= len) do
		local _, i = s:find(pattern, startIndex, plain)
		if (not i) then return count; end
		count = count+1
		startIndex = (i < startIndex and startIndex+1 or i+1)
	end
	return count+((''):find(pattern, 1, plain) and 1 or 0)
end







-- result = stringStartsWith( string, startString )
function M.stringStartsWith(s, startStr)
	return (s:sub(1, #startStr) == startStr)
end



-- result = stringEndsWith( string, endString )
function M.stringEndsWith(s, endStr)
	return (endStr == '' or s:sub(-#endStr) == endStr)
end







--[[
	trim()
		Removes all leading and trailing white-space characters from a string.

	Description:
		trimmedString = trim( string [, side [, chars ] ] )
			- string: The string to trim.
			- side: What side to trim. (Default: "both")
			- chars: A custom list of characters to trim away. (Default: " \t\n\r\011" (ordinary space, tab, new line (line feed), carriage return and vertical tab))
			> Returns: The trimmed string.

	Example:
		reLua.trim("  Hello\n") -- "Hello"
		reLua.trim("  Hello\n", nil, "left") -- "Hello\n"

]]
function M.trim(s, side, chars)
	chars = (chars and M.escapePattern(chars) or ' \t\n\r\011')
	if (side ~= 'right') then s = s:match('^['..chars..']*(.*)$') end
	if (side ~= 'left') then s = s:match('^(.-)['..chars..']*$') end
	return s
end



--[[
	truncateString()
		Truncates a string so it fits within a specified length.
		Only the right side of the string is affected.

	Description:
		truncatedString = truncateString( string, maxLength [, overflowIndicator [, truncateIndicator ] ] )
			- string: The string subject to truncation.
			- maxLength: Max length of the output string.
			- overflowIndicator: String used as an overflow indicator at the end of the string. (Default: "...")
			- truncateIndicator: If the overflow indicator should be truncated as well if #overflowIndicator < maxLength. (Default: false)
			> Returns: The truncated string if it was too long, otherwise the string is returned unmodified.

	Example:
		local s = "Hello world!"
		reLua.truncateString(s, 50) -- "Hello world!"
		reLua.truncateString(s, 10) -- "Hello w..."
		reLua.truncateString(s, 10, "~") -- "Hello wor~"
		reLua.truncateString(s, 1, nil, false) -- "..."
		reLua.truncateString(s, 1, nil, true) -- "."

]]
function M.truncateString(s, maxLength, overflowIndicator, truncateIndicator)
	local overflowIndicator = (overflowIndicator or '...')
	if (#s <= maxLength) then return s; end
	if (truncateIndicator and #overflowIndicator >= maxLength) then
		return overflowIndicator:sub(1, math.max(maxLength, 0))
	else
		return s:sub(1, math.max(maxLength-#overflowIndicator, 0))..overflowIndicator
	end
end







--[[
	wrapText()
		Wraps a string at a given margin.
		This is intended for strings without newlines in them.
		Source: http://lua-users.org/wiki/StringRecipes

	Description:
		wrappedString = wrapText( string, margin [, indent [, firstIndent ] ] )
			- string: The string subject to wrap.
			- margin: Max number of characters on a line.
			- indent: Indentation string prepended to each line. (Default: "")
			- firstIndent: Indentation string to prepend to the first line. (Default: indent)
			> Returns: The wrapped string.

	Example:
		reLua.wrapText("Lorem ipsum dolor sit amet.", 15) -- "Lorem ipsum\ndolor sit amet."
		reLua.wrapText("abcdefghijklmnopqrstuvwzyx foobar?", 15) -- "abcdefghijklmnopqrstuvwzyx\nfoobar?" (does not split too long words)

		-- Handle too long words
		local str = "abcdefghijklmnopqrstuvwzyx foobar?"
		local margin = 15
		print(reLua.wrapText(reLua.splitWords(str, margin, "-"), margin))
		-- Prints:
		-- abcdefghijklmn-
		-- opqrstuvwzyx
		-- foobar?

]]
function M.wrapText(s, margin, indent, firstIndent)
	indent = (indent or '')
	firstIndent = (firstIndent or indent)
	local here = 1-#firstIndent
	return firstIndent..s:gsub('%s+()(%S+)()', function(start, word, finish)
		if (finish-here > margin) then
			here = start-#indent
			return '\n'..indent..word
		end
	end)
end



--[[
	splitWords()
		Splits long words in a string.
		Can be used on a string before using reLua.wrapText().

	Description:
		newString = splitWords( string, maxLength [, tail ] )
			- string: The string subject.
			- maxLength: Maximum length of each word.
			- tail: A string to insert at each cut in words, e.g. a hyphen. (Default: "")
			> Returns: The altered string.

	Example:
		local str = "It is incomprehensible!"
		reLua.splitWords(str, 7) -- "It is incompr ehensib le!"
		reLua.splitWords(str, 7, "-") -- "It is incomp- rehens- ible!"

	TODO:
		Check if tails longer than one character works as expected.
		Optimization: Reuse the results table?

]]
function M.splitWords(s, maxLength, tail)
	if (maxLength < 1) then error('Invalid max word length', 2); end
	tail = (tail or '')

	-- Split actual words
	-- print('__1__', s)
	local maxWordLength = maxLength-#tail
	if (maxWordLength < 1) then error('Max word length must be longer than the tail length', 2); end
	s = s:gsub(('%a'):rep(maxLength+1)..'+', function(word)
		return table.concat(M.chunkString(word, maxWordLength), '\0 ')
	end)

	-- Split non-space "words"
	-- print('__2__', (s:gsub('%z', tail)))
	local i, len, removeSpace, result, start, section, endsWithLetter, nextStartsWithLetter, lastWordEnd
	s = s:gsub(('%S'):rep(maxLength+1)..'+', function(nonSpaceWord)
		i, len, removeSpace, result, start = 0, #nonSpaceWord, false, {}, 1
		-- Make the splits at smart positions
		while (start <= len-maxLength) do
			i = i+1
			section = nonSpaceWord:sub(start, start+maxLength-1)
			endsWithLetter, nextStartsWithLetter = M.isLetter(section, #section), M.isLetter(nonSpaceWord, start+#section)
			lastWordEnd = select(2, section:reverse():find('%a%A')) -- index from end of section
			if (not endsWithLetter and nextStartsWithLetter) then
				-- This section ends with a non-word and the next begins with a word
				lastWordEnd = #section
				result[i] = section:sub(1, lastWordEnd)..' '
			elseif (lastWordEnd) then
				-- This section contains mixed characters
				lastWordEnd = #section-lastWordEnd+1 -- convert to index from start of section
				result[i] = section:sub(1, lastWordEnd)..' '
			elseif (endsWithLetter and nextStartsWithLetter) then
				-- This section ends and the next begins with a word
				lastWordEnd = #section-#tail
				result[i] = section:sub(1, lastWordEnd)..'\0 '
			else
				-- This whole section is a solid word or sequence of non-letters
				lastWordEnd = #section
				result[i] = section..' '
			end
			start, removeSpace = start+lastWordEnd, true
		end
		if (start <= len) then
			-- Add the remainder of the section
			i = i+1
			result[i], removeSpace = nonSpaceWord:sub(start), false
		end
		if (removeSpace) then result[i] = result[i]:gsub(' $', ''); end
		return table.concat(result)
	end)

	-- print('__3__', (s:gsub('%z', tail)))
	return (s:gsub('%z', tail))
end

--[[ Just some tests...
local margin, tail = 15, '-'
print()
print('"'..M.wrapText(M.splitWords('abcdefghijklmnopqrstuvwzyx foobar?', margin, tail), margin)..'"')
print()
print('maxLen', 'pass', 'result')
for _, s in ipairs{
	'abcde', -- 4="abcd e"
	'abcd?', -- 4="abcd ?"
	'?abcd', -- 4="? abcd"
	'abcd?efghi??', -- 4="abcd ? efgh i??"  5="abcd? efghi ??"
	'????a?????bc', -- 4="???? a??? ??bc"  5="???? a???? ?bc"
	'?a?b?c?d?e?f?', -- 4="?a? b?c? d?e? f?"  5="?a?b? c?d? e?f?"
} do
	print('----------------'); print('str', '"'..s..'"');
	for i = 3, 5 do
		print(i, (not M.splitWords(s, i, tail):find(('%S'):rep(i+1))), '"'..M.splitWords(s, i, tail)..'"')
	end
end
for _, s in ipairs{
	'asdfgh asdfgh', -- 4="asdf gh asdf gh"
	'asdfgh? asdfgh?', -- 4="asdf gh? asdf gh?"
	'asd???fgh', -- 4="asd? ?? fgh"
	'asdfgh???asdfgh', -- 4="asdf gh?? ? asdf gh"
	'asdfgh???asdfghijklmn', -- 4="asdf gh?? ? asdf ghij klmn"
} do
	print('----------------'); print('str', '"'..s..'"');
	for i = 4, 8 do
		print(i, (not M.splitWords(s, i, tail):find(('%S'):rep(i+1))), '"'..M.splitWords(s, i, tail)..'"')
	end
end
--]]



--[[
	splitWordsSimple()
		Splits long words in a string.
		All non-space characters are considered letters by this function, unlike reLua.splitWords().

	Description:
		newString = splitWordsSimple( string, maxLength )
			- string: The string subject.
			- maxLength: Maximum length of each word.
			> Returns: The altered string.

	Example:
		local str = "Hi!Hello!"
		reLua.splitWordsSimple(str, 6) -- "Hi!Hel lo!" (fast "dumb" splits)
		reLua.splitWords(str, 6)       -- "Hi! Hello!" (slow "smart" splits)

		local str = "http://www.example.com"
		reLua.splitWordsSimple(str, 8) -- "http://w ww.examp le.com"
		reLua.splitWords(str, 8)       -- "http:// www. example. com"

]]
function M.splitWordsSimple(s, maxLength)
	if (maxLength < 1) then error('Invalid max word length', 2); end
	return (s:gsub(('%S'):rep(maxLength+1)..'+', function(word)
		return table.concat(M.chunkString(word, maxLength), ' ')
	end))
end















--==============================================================
--=          ===================================================
--=  Tables  ===================================================
--=          ===================================================
--==============================================================







--[[
	appendToArray()
		Inserts one or more elements at the end of an array.

	Description:
		array = appendToArray( array, value1 [, ... ] )
			- array: The table to insert the values into.
			> value1, ...: The values to insert.
			> Returns: The array argument.

	Example:
		local arr = {1,4,8}
		reLua.appendToArray(arr, 12, 15) -- {1,4,8,12,15}

]]
function M.appendToArray(arr, ...)
	local len = #arr
	for i = 1, select('#', ...) do
		arr[len+i] = select(i, ...)
	end
	return arr
end



--[[
	appendUnique()
		Inserts a value into an array only if it doesn't already exists.

	Description:
		array = appendUnique( array, value )
			- array: The table to insert the value into.
			> value: The value to insert.
			> Returns: The array argument.

	Example:
		local arr = {}
		reLua.appendUnique(arr, "A")  -- {"A"}
		reLua.appendUnique(arr, "B")  -- {"A", "B"}
		reLua.appendUnique(arr, "A")  -- {"A", "B"} (no change)

]]
function M.appendUnique(arr, v)
	if (not M.indexOf(arr, v)) then arr[#arr+1] = v; end
	return arr
end







--[[
	arrayDiff()
		Computes the difference of arrays.

	Description:
		arrayDiff( array1, array2 [, ... ] )
			- array1: The array to compare from.
			- array2: An array to compare against.
			- ...: More arrays to compare against.
			> Returns: An array with the values in array1 that are not present in any of the other arrays.

	Example:
		local arr1 = {"green", "red", "blue"}
		local arr2 = {"green", "yellow", "red"}
		reLua.arrayDiff(arr1, arr2) -- {"blue"}

]]
function M.arrayDiff(arr, ...)
	local diff, len = {}, select('#', ...)
	for _, v in ipairs(arr) do
		local exists = false
		for i = 1, len do
			if (M.indexOf(select(i, ...), v)) then
				exists = true
				break
			end
		end
		if (not exists) then
			diff[#diff+1] = v
		end
	end
	return diff
end



--[[
	arrayIntersect()
		Computes the intersection of arrays.

	Description:
		arrayIntersect( array1, array2 [, ... ] )
			- array1: The array to compare from.
			- array2: An array to compare against.
			- ...: More arrays to compare against.
			> Returns: An array with all the values of array1 that are present in all the other arrays.

	Example:
		local arr1 = {"green", "red", "blue"}
		local arr2 = {"green", "yellow", "red"}
		reLua.arrayIntersect(arr1, arr2) -- {"green","red"}

]]
function M.arrayIntersect(arr, ...)
	local intersect, len = {}, select('#', ...)
	for _, v in ipairs(arr) do
		local exists = true
		for i = 1, len do
			if (not M.indexOf(select(i, ...), v)) then
				exists = false
				break
			end
		end
		if (exists) then
			intersect[#intersect+1] = v
		end
	end
	return intersect
end







--[[
	chunkArray()
		Splits an array into chunks.
		Does not alter the original array.

	Description:
		chunkArray( array, size [, preserveKeys ] )
			- array: The array to split.
			- size: The size of each chunk.
			- preserveKeys: If the original index should be kept for each array item in the chunks. (Default: false)
			> Returns: asdf.

	Example:
		local chunks = reLua.chunkArray({"A","B","C","D","E"}, 2)
		-- chunks is: {
		--   {"A","B"},
		--   {"C","D"},
		--   {"E"},
		-- }

		-- Preserve keys
		local chunks = reLua.chunkArray({"A","B","C","D","E"}, 2, true)
		-- chunks is: {
		--   {[1]="A", [2]="B"},
		--   {[3]="C", [4]="D"},
		--   {[5]="E"},
		-- }

]]
function M.chunkArray(arr, size, preserveKeys)
	local chunks, chunkIndex, key = {}, 0, 0
	local chunk
	for i = 1, #arr do
		if ((i-1)%size == 0) then
			chunkIndex, chunk = chunkIndex+1, {}
			chunks[chunkIndex] = chunk
			if (not preserveKeys) then key = 0; end
		end
		key = key+1
		chunk[key] = arr[i]
	end
	return chunks
end







--[[
	compareTables()
		Compares the values of two or more arrays against each other.

	Description:
		compareTables( array1, array2 [, ... ] )
			- array1: The array to compare from.
			- array2: An array to compare against.
			- ...: More arrays to compare against.
			> Returns: True if all arrays are equal, false otherwise.

	Example:
		local arr1 = {"green", "red"}
		local arr2 = {"green", "red"}
		local arr3 = {"green", "red", "yellow"}
		reLua.compareTables(arr1, arr2) -- true
		reLua.compareTables(arr1, arr3) -- false

]]
function M.compareTables(t1, ...)
	local t1Keys = M.setKeysIdentical({}, M.getKeys(t1), true)
	for _, t2 in ipairs{...} do
		local keys = M.setKeysIdentical(M.copyTable(t1Keys), M.getKeys(t2), true)
		for k, _ in pairs(keys) do
			if (t1[k] ~= t2[k]) then
				return false
			end
		end
	end
	return true
end







--[[
	concatRecursive()
		Concatenates an array recursively.
		Unlike table.concat() this function does not throw errors for "invalid" values.

	Description:
		result = concatRecursive( array [, separator ] )
			- array: The array to concatenate.
			- separator: The separator to use. (Default: "")
			> Returns: The concatenated array (string).

	Example:
		reLua.concatRecursive{"A", {"B",7}, "C"} -- "AB7C"

]]
do

	local function addValues(arr, values)
		for _, v in ipairs(arr) do
			if (type(v) == 'table') then
				addValues(v, values)
			else
				values.n = values.n+1
				values[values.n] = tostring(v)
			end
		end
		return values
	end

	function M.concatRecursive(arr, separator)
		return table.concat(addValues(arr, {n=0}), separator)
	end

end







-- Copies an array
-- arrayCopy = copyArray( array [, deepCopy [, emptyIsArray ] ] )
function M.copyArray(arr, deepCopy, emptyIsArray)
	local copy = {}
	if deepCopy then
		for i, v in ipairs(arr) do
			copy[i] = (M.isArray(v, emptyIsArray) and M.copyArray(v, true) or v)
		end
	else
		for i, v in ipairs(arr) do copy[i] = v end
	end
	return copy
end



-- Copies a table
-- tableCopy = copyTable( table [, deepCopy ] )
function M.copyTable(t, deepCopy)
	local copy = {}
	if deepCopy then
		for k, v in pairs(t) do
			copy[k] = ((type(v) == 'table') and M.copyTable(v, true) or v)
		end
	else
		for k, v in pairs(t) do copy[k] = v; end
	end
	return copy
end







-- Empties a table
-- table = emptyTable( table )
function M.emptyTable(t)
	for k, _ in pairs(t) do t[k] = nil; end
	return t
end







--[[
	fillEmptyArraySlots()
		Fixes a broken array by filling in the empty slots between the values.

	Description:
		array = fillEmptyArraySlots( array [, fillValue ] )
			- array: The table to fix.
			- fillValue: Value to fill the empty spots with. (Default: reLua.null)
			> Returns: The array argument.

	Example:
		local arr = {1,2}
		arr[5] = 5
		print(unpack(arr)) -- 1, 2
		reLua.fillEmptyArraySlots(arr, 0)
		print(unpack(arr)) -- 1, 2, 0, 0, 5

]]
function M.fillEmptyArraySlots(arr, v)
	if (v == nil) then v = M.null; end
	for i = 1, table.maxn(arr)-1 do
		if (arr[i] == nil) then arr[i] = v; end
	end
	return arr
end







--[[
	filterArray()
		Filter items from an array with a callback function.
		Does not alter the original array.

	Description:
		filterArray( array, filter [, returnFiltered ] )
			- array: The table to filter.
			- filter: Testing function.
			- returnFiltered: If the filtered away values should be returned instead. (Default: false)
			> Returns: A filtered array.

	Example:
		local function lessThanThree(num)
			return (num < 3)
		end
		local array = {1,2,3,4,5}
		reLua.filterArray(array, lessThanThree) -- {3,4,5}
		reLua.filterArray(array, lessThanThree, true) -- {1,2}

]]
function M.filterArray(arr, filter, returnFiltered)
	returnFiltered = (not returnFiltered)
	local filteredArray = {}
	for i, v in ipairs(arr) do
		if (not filter(v, i) == returnFiltered) then filteredArray[#filteredArray+1] = v; end
	end
	return filteredArray
end



--[[
	filterTable()
		Filters the attributes of a table.

	Description:
		filterTable( table, filter [, returnFiltered ] )
			- table: The table to filter.
			- filter: Testing function or an array of attribute names.
			- returnFiltered: If the filtered away values should be returned instead. (Default: false)
			> Returns: A filtered table.

	Example: Filter away unimportant attributes from an object.
		local person = {name="John", age=34, hasPets=false}
		local importantAttributes = {"name", "age"}
		reLua.filterTable(person, importantAttributes, true) -- {name=John, age=34}

	Example: Remove boolean attributes.
		local function isBoolean(value)
			return (type(value) == "boolean")
		end
		local house = {basement=true, width=80, depth=60, flatRoof=false}
		reLua.filterTable(house, isBoolean) -- {width=80, depth=60}

]]
function M.filterTable(t, filter, returnFiltered)
	local filteredTable = {}
	if (type(filter) == 'function') then
		returnFiltered = (not returnFiltered)
		for k, v in pairs(t) do
			if (not filter(v, k) == returnFiltered) then filteredTable[k] = v end
		end
	elseif returnFiltered then
		for _, k in ipairs(filter) do filteredTable[k] = t[k]; end
	else
		filter = M.setKeysIdentical({}, filter, true)
		for k, v in pairs(t) do
			if (not filter[k]) then filteredTable[k] = v; end
		end
	end
	return filteredTable
end







--[[
	flatten()
		Flattens a multi-dimensional array.

	Description:
		flatten( array [, separator ] )
			- array: The array to concatenate.
			- separator: The separator to use. (Default: "")
			> Returns: The concatenated array (string).

	Example:
		reLua.flatten{1, {2,3}, 4} -- {1,2,3,4}

]]
do

	local function addValues(arr, values)
		for _, v in ipairs(arr) do
			if (type(v) == 'table') then
				addValues(v, values)
			else
				values.n = values.n+1
				values[values.n] = v
			end
		end
		return values
	end

	function M.flatten(arr, separator)
		local flatArr = addValues(arr, {n=0})
		flatArr.n = nil
		return flatArr
	end

end







--[[
	flip()
		Flips the key/value pairs in a table so keys become the values and vice versa.
		Does not alter the original table.

	Description:
		flip( table )
			- table: The table to flip.
			> Returns: The resulting value that callback has produced.

	Example:
		local tbl = {a="x", b="y", c="z"}
		reLua.flip(tbl) -- {x="a", y="b", z="c"}

]]
function M.flip(t)
	local flipped = {}
	for k, v in pairs(t) do flipped[v] = k; end
	return flipped
end



--[[
	nameIndices()
		Converts an indexed array to a table with named keys.
		Does not alter the original table.

	Description:
		table = nameIndices( array, keys )
			- array: The table to reduce.
			> Returns: A new table with swapped keys.
			! Same as:
				table = reLua.setKeys({}, keys, array)

	Example:
		local person = {"Charles",62,false}
		local keys = {"name","age","hasPets"}
		reLua.nameIndices(person, keys) -- {name="Charles", age=62, hasPets=false}

]]
function M.nameIndices(arr, keys)
	return M.setKeys({}, keys, arr)
end



--[[
	swapKeys()
		Swaps existing keys in a table for new ones.
		Does not alter the original table.

	Description:
		newTable = swapKeys( table, keyPairs )
			- array: The table to reduce.
			> Returns: A new table with swapped keys.

	Example:
		local bandInfo = {name="A-ha", year=1982}
		local keys = {name="band", year="formed"}
		reLua.swapKeys(bandInfo, keys) -- {band="A-ha", formed=1982}

]]
function M.swapKeys(t, keys)
	local swapped = {}
	for old, new in pairs(keys) do swapped[new] = t[old]; end
	return swapped
end







--[[
	fold()
		Reduces the values in an array to a single value.

	Description:
		fold( array, callback [, init ] )
			- array: The table to reduce.
			- callback: The function to call for each value in the array. It will recieve a base value and the current array item as arguments. The returned value will be the base value for the next call.
			- init: The initial base value used for the first callback call. (Default: nil)
			> Returns: The resulting value that callback has produced.

	Example:
		local function add(v1, v2)
			return v1+v2
		end
		local arr = {1,2,3}
		local sum = reLua.fold(arr, add, 0) -- 6

]]
function M.fold(arr, callback, v)
	for i = 1, #arr do v = callback(v, arr[i]); end
	return v
end



--[[
	foldReverse()
		Reduces the values in an array to a single value going from last array item to first.

	Description:
		foldReverse( array, callback [, init ] )
			- the arguments and return value are the same as reLua.fold().

	Example:
		local function glue(str1, str2)
			return str1..str2
		end
		local arr = {"Alpha","Beta","Gamma"}
		reLua.foldReverse(arr, glue, "") -- "GammaBetaAlpha"

]]
function M.foldReverse(arr, callback, v)
	for i = #arr, 1, -1 do v = callback(v, arr[i]); end
	return v
end







--[[
	foreach()
		Calls a function on all items in an array, similarly to the deprecated table.foreachi() function.

	Description:
		breakValue = foreach( array, callback [, reverse ] )
			- array: The table to traverse.
			- callback: The function to call on each item. Returning a true value from this function stops the traversion of the array.
			- reverse: If the array should be traversed from last to first. (Default: false)
			> Returns: The true value that broke the loop, if any, otherwise nil.

	Example:
		local function printPow(value)
			print(2^value)
		end

		reLua.foreach({1,2,3,4}, printPow) -- 2, 4, 8, 16
		reLua.foreach({1,2,3,4}, printPow, true) -- 16, 8, 4, 2

		local function isNumber(value)
			print(value)
			return (type(value) == "number")
		end

		local values = {"foo","bar",5,"baz"}
		local containsNumber = reLua.foreach(values, isNumber) -- prints: "foo", "bar", 5
		print(containsNumber) -- true

]]
function M.foreach(arr, callback, reverse)
	if (reverse) then
		for i = #arr, 1, -1 do
			local v = callback(arr[i], i)
			if (v) then return v; end
		end
	else
		for i = 1, #arr do
			local v = callback(arr[i], i)
			if (v) then return v; end
		end
	end
	return nil
end



--[[
	mapArray()
		Calls a function on all items in an array, similarly to reLua.foreach().
		Note: unlike reLua.foreach(), the traversion of the array cannot be stopped by returning a true value from the callback.

	Description:
		values = mapArray( array, callback [, ... ] )
			- array: The table to traverse.
			- callback: The function to call on each item. The arguments are the current array item and the extra arguments (...).
			- ...: Extra arguments for the callback. (Default: none)
			> Returns: An array of values returned from each callback call.
				Note that the array might become broken if the callback returns nil at any point.
				reLua.fillEmptyArraySlots() or reLua.getValues() can be used to fix the array.

	Example:
		local results = reLua.mapArray({1,2,3,4}, math.pow, 2) -- {1,4,9,16}

]]
function M.mapArray(arr, callback, ...)
	local values = {}
	for i, v in ipairs(arr) do
		values[i] = callback(v, ...)
	end
	return values
end



--[[
	mapArrayRecursive()
		Calls a function on all items in an array, just like reLua.mapArray(), but also traverses all underlying arrays.

	Description:
		values = mapArrayRecursive( array, callback [, ... ] )
			- the arguments are the same as for reLua.mapArray(). Note that the function is called on the underlying arrays themselves as well.
			> Returns: A (non-broken) array of values returned from the function calls.

	Example:
		local values = {
			1,
			2,
			{10, {56,57}, 11},
			"foo",
			3,
		}
		local numbers = reLua.mapArrayRecursive(values, tonumber) -- {1,2,10,56,57,11,3}

]]
function M.mapArrayRecursive(arr, callback, ...)
	local values = {}
	for i = 1, #arr do
		local v = arr[i]
		values[#values+1] = callback(v, ...)
		if (type(v) == 'table') then
			M.appendToArray(values, unpack(M.mapArrayRecursive(v, callback, ...)))
		end
	end
	return values
end







--[[
	getColumn()
		Retrieves a specific attribute from each item in an array.

	Description:
		values = getColumn( array, attrName )
			- array: The table to traverse.
			- attrName: The name of the attribute.
			> Returns: An array containing the values of each array item's 'attrName' attribute.

	Example:
		local coords = {
			{x=1, y=10},
			{x=2, y=15},
			{x=3, y=20},
		}
		local yValues = reLua.getColumn(coords, "y") -- {10,15,20}

		-- Use another column as keys
		people = {
			{id=1793, name="John"},
			{id=2178, name="Sally"},
			{id=2630, name="Greg"},
		}
		local column = reLua.getColumn(coords, "name", "id")
		-- column is: {
		--   [1793] = "John",
		--   [2178] = "Sally",
		--   [2630] = "Greg",
		-- }

]]
function M.getColumn(arr, attr, key)
	local values = {}
	if (key == nil) then
		for i, t in ipairs(arr) do values[i] = t[attr]; end
	else
		for _, t in ipairs(arr) do values[t[key]] = t[attr]; end
	end
	return values
end



--[[
	setColumn()
		Sets a specific attribute on each item in an array.

	Description:
		setColumn( array, attrName, value )
		setColumn( array, attrName, callback )
			- array: The table to traverse.
			- attrName: The name of the attribute.
			- value: The new value.
			- callback: Function to call for each value to change. It recieves the old attribute value and the current array item as arguments.

	Example:
		local coords = {
			{x=1, y=10},
			{x=2, y=15},
			{x=3, y=20},
		}

		-- Set all y values to 0
		reLua.setColumn(coords, "y", 0)
		-- coords is: {
		--   {x=1, y=0},
		--   {x=2, y=0},
		--   {x=3, y=0},
		-- }

		-- Double the x values
		local function double(num)
			return num*2
		end
		reLua.setColumn(coords, "x", double)
		-- coords is: {
		--   {x=2, y=0},
		--   {x=4, y=0},
		--   {x=6, y=0},
		-- }

		-- Set each item's y to x*10
		reLua.setColumn(coords, "y", function(oldY, point)
			return point.x*10
		end)
		-- coords is: {
		--   {x=2, y=20},
		--   {x=4, y=40},
		--   {x=6, y=60},
		-- }

]]
function M.setColumn(arr, attr, v)
	if (type(v) == 'function') then
		for _, t in ipairs(arr) do t[attr] = v(t[attr], t); end
	else
		for _, t in ipairs(arr) do t[attr] = v; end
	end
end







--[[
	getKeys()
		Returns a list of all keys a table has.

	Description:
		keyArray = getKeys( table )
			- table: The table to traverse.
			> Returns: An array containing all keys the table has.

	Example:
		local tbl = {foo=10, bar=20, baz=30}
		reLua.getKeys(tbl) -- {"foo","bar","baz"}

]]
function M.getKeys(t)
	local keys = {}
	for k, _ in pairs(t) do keys[#keys+1] = k end
	return keys
end



--[[
	getValues()
		Returns a list of all values a table contains.

	Description:
		values = getValues( table [, keys [, preserveKeys ] ] )
			- table: The table to traverse.
			- keys: An array of key names to return from 'table'. (Default: all keys)
			- preserveKeys: If the returned table should keep the original key names. Otherwise an array is returned. (Default: false)
			> Returns: A new table containing the values from 'table'.

	Example:
		local tbl = {foo=10, bar=20, baz=30}
		reLua.getValues(tbl) -- {10, 20, 30} (the order of the items can vary)
		reLua.getValues(tbl, {"foo","baz"}) -- {10, 30}
		reLua.getValues(tbl, {"foo","baz"}, true) -- {foo=10, baz=30}

]]
function M.getValues(t, keys, preserveKeys)
	local values = {}
	if (keys) then
		if (preserveKeys) then
			for _, k in ipairs(keys) do values[k] = t[k]; end
		else
			for i, k in ipairs(keys) do values[i] = t[k]; end
		end
	else
		for _, v in pairs(t) do values[#values+1] = v; end
	end
	return values
end



--[[
	getUniqueValues()
		Returns a list of all unique values a table contains.

	Description:
		valueArray = getUniqueValues( table )
			- table: The table to traverse.
			> Returns: An array containing all unique values from 'table'.

	Example:
		local tbl = {foo=10, bar=20, baz=30}
		reLua.getUniqueValues(tbl) -- {10,20,30} (the order of the items can vary)

]]
function M.getUniqueValues(t)
	local values, usedValues = {}, {}
	for _, v in pairs(t) do
		if (not usedValues[v]) then
			values[#values+1] = v
			usedValues[v] = true
		end
	end
	return values
end



--[[
	getUniqueItems()
		Returns a list of all unique items an array contains.
		Unlike reLua.getUniqueValues(), the order of the returned items is always preserved.

	Description:
		valueArray = getUniqueItems( array )
			- array: The table to traverse.
			> Returns: An array containing all unique values from 'array'.

	Example:
		local array = {"A","B","C","B"}
		reLua.getUniqueItems(array) -- {"A","B","C"}

]]
function M.getUniqueItems(arr)
	local values, usedValues = {}, {}
	for _, v in ipairs(arr) do
		if (not usedValues[v]) then
			values[#values+1] = v
			usedValues[v] = true
		end
	end
	return values
end







-- Returns a random item from an array
-- value = getRandomItem( array [, from [, to ] ] )
function M.getRandomItem(arr, from, to)
	return arr[math.random((from or 1), (to or #arr))]
end



--[[
	extractRandomItem()
		Extracts one or several values from an array.
		Note: this changes the original table.

	Description:
		extracts = extractRandomItem( array [, amount ] )
			- array: The table to extract values from.
			- amount: How many values to extract. (Default: 1)
			> Returns: An array of randomly chosen values if amount is set, or one value if amount is not set.

	Example:
		local numbers = {12,18,23,29,41}
		local randomNumber = reLua.extractRandomItem(numbers) -- e.g. 18

		local names = {"Anne","John","Simon"}
		local randomNames = reLua.extractRandomItem(names, 2) -- e.g. {"Simon","Anne"}

]]
function M.extractRandomItem(t, amount)
	if (amount) then
		local extracted = {}
		for i = 1, amount do extracted[i] = table.remove(t, math.random(#t)); end
		return extracted
	else
		return table.remove(t, math.random(#t))
	end
end







--[[
	getTablePathToValue()
		Returns the path to a value in a table.
		Can e.g. be used with reLua.setTablePathValue() to update that specific value.

	Description:
		path = getTablePathToValue( table, value )
			- table: The table to search through.
			- value: The value to search for.
			> Returns: An array with attribute names forming the path to the value in the table, of nil if the value wasn't found.

	Example:
		local tbl = {
			foo = "a",
			bar = "b",
			animal = {fish="c", bird="d"},
			[4] = "e",
		}
		reLua.getTablePathToValue(tbl, "c") -- {"animal","fish"}

]]
do local insert = table.insert

	local function explore(t, vToFind, path)
		for k, v in pairs(t) do
			if (v == vToFind) then
				path[1] = k
				return true
			elseif (type(v) == 'table' and explore(v, vToFind, path)) then
				insert(path, 1, k)
				return true
			end
		end
		return false
	end

	function M.getTablePathToValue(t, v)
		local path = {}
		return (explore(t, v, path) and path or nil)
	end

end



--[[
	setTablePathValue()
		Updates an attribute somewhere within a multi-dimensional array or other kind of table containing sub-tables.

	Description:
		setTablePathValue( table, path, value )
			- table: The table to alter.
			- path: An array of attribute names forming a path. If a step in the path doesn't exist a new table is created. An error is thrown if this array is empty.
			- value: The new value for the attribute.

	Example:
		local tbl = {}
		reLua.setTablePathValue(tbl, {1,7,"foo"}, "bar")
		print(tbl[1][7].foo) -- bar

]]
function M.setTablePathValue(t, path, v)
	if (path[2]) then
		path = M.copyArray(path)
		local k = table.remove(path, 1)
		if (t[k] == nil) then t[k] = {}; end
		M.setTablePathValue(t[k], path, v)
	elseif (path[1]) then
		t[path[1]] = v
	else
		error('Invalid path (empty)', 2)
	end
end



--[[
	getTablePathValue()
		Returns the value of an attribute somewhere within a multi-dimensional array or other kind of table containing sub-tables.
		Unlike typing the path directly (table.attr1.attr2), if an attribute doesn't exist no error is thrown.

	Description:
		value = getTablePathValue( table, path )
			- table: The table to use.
			- path: An array of attribute names forming a path.
			> Returns: The value if it exists and a boolean indicating if the path existed.

	Example:
		local function printTablePathValue(...)
			print(reLua.getTablePathValue(...))
		end

		local tbl = {a="foo"}

		print(tbl.a) -- foo
		printTablePathValue(tbl, {"a"}) -- foo, true

		print(tbl.a.b) -- nil
		printTablePathValue(tbl, {"a","b"}) -- nil, true

		print(tbl.a.b.c) -- Runtime error: attempt to index field 'b' (a nil value)
		printTablePathValue(tbl, {"a","b","c"}) -- nil, false (No error)

]]
function M.getTablePathValue(t, path)
	if (path[2]) then
		path = M.copyArray(path)
		local k = table.remove(path, 1)
		if (t[k] == nil) then return nil, false; end
		return M.getTablePathValue(t[k], path)
	elseif (path[1]) then
		return t[path[1]], true
	else
		return t, true
	end
end







--[[
	indexOf()
		Returns the index of a value in an array.

	Description:
		index = indexOf( array, value [, startIndex ] [, returnLast ] )
			- array: The table to search through.
			- value: The value to search for.
			- startIndex: The index to start the search at. If negative, it is taken as the offset from the end of the array. (Default: 1)
			- returnLast: If the array should be searched backwards. (Default: false)
			> Returns: The index of the value, or nil if it wasn't found.

	Example:
		local array = {"A", "B", "C", "B"}
		reLua.indexOf(array, "B")  -- 2
		reLua.indexOf(array, "B", 3)  -- 4
		reLua.indexOf(array, "foo")  -- nil
		reLua.indexOf(array, "B", true)  -- 4

]]
function M.indexOf(arr, v, startIndex, returnLast)
	if (type(startIndex) == 'boolean') then startIndex, returnLast = nil, startIndex end
	local len = #arr
	local from = (startIndex and startIndex < 0 and len+startIndex+1)
		or (startIndex) or (returnLast and len or 1)
	from = (returnLast and math.min(from, len) or math.max(from, 1))
	for i = from, (returnLast and 1 or len), (returnLast and -1 or 1) do
		if (arr[i] == v) then return i; end
	end
	return nil
end



--[[
	indexOfAll()
		Returns all indices containing a specific value in an array.

	Description:
		indices = indexOfAll( array, value [, invert ] )
			- array: The table to search through.
			- value: The value to search for.
			- invert: If all indices NOT containing the value should be returned instead. (Default: false)
			> Returns: All indices containing the value, or if 'invert' is set, all other indices.

	Example:
		local array = {"A", "B", "A"}
		reLua.indexOfAll(array, "A") -- {1,3}
		reLua.indexOfAll(array, "A", true) -- {2}

]]
function M.indexOfAll(arr, v, invert)
	invert = (not invert)
	local indices = {}
	for i = 1, #arr do
		if ((arr[i] == v) == invert) then indices[#indices+1] = i; end
	end
	return indices
end



--[[
	indexWith()
		Returns the array index containing an item matching a comparison table.

	Description:
		index, object = indexWith( array, comparison [, startIndex ] [, returnLast [, invert ] ] )
			- array: The table to search through.
			- comparison: A table to compare each array item against.
			- startIndex: The index to start the search at. If negative, it is taken as the offset from the end of the array. (Default: 1)
			- returnLast: If the array should be searched backwards. (Default: false)
			- invert: If the first index NOT matching 'comparison' should be returned instead. (Default: false)
			> Returns: The index of the item matching 'comparison' and the item itself if found, nil otherwise.

	Example:
		local array = {
			{name="foo"},
			{name="bar"},
			{name="baz"},
			{name="foo"},
		}
		reLua.indexWith(array, {name="bar"}) -- 2
		reLua.indexWith(array, {name="foobar"}) -- nil
		reLua.indexWith(array, {name="foo"}, true) -- 4 (last index with name=="foo")
		reLua.indexWith(array, {name="foo"}, false, true) -- 2 (first index with name~="foo")

]]
function M.indexWith(arr, comparison, startIndex, returnLast, invert)
	if (type(startIndex) == 'boolean') then startIndex, returnLast, invert = nil, startIndex, returnLast end
	invert = (not invert)
	local len = #arr
	local from = (startIndex and startIndex < 0 and len+startIndex+1)
		or (startIndex) or (returnLast and len or 1)
	from = (returnLast and math.min(from, len) or math.max(from, 1))
	for i = from, (returnLast and 1 or len), (returnLast and -1 or 1) do
		local match = true
		for k, v in pairs(comparison) do
			if (v == M.null) then v = nil; end
			if (arr[i][k] ~= v) then match = false; break; end
		end
		if (match == invert) then return i, arr[i] end
	end
	return nil, nil
end



--[[
	indexWithAll()
		Returns all array indices containing an item matching a comparison table.

	Description:
		indices, objects = indexWithAll( array, comparison [, invert ] )
			- array: The table to search through.
			- comparison: A table to compare each array item against.
			- invert: If the indices of items NOT matching the comparison table should be returned instead. (Default: false)
			> Returns: An array of indices and an array with the indices' respective object.

	Example:
		local poeple = {
			{name="Steve"},
			{name="John"},
			{name="Janet"},
			{name="Steve"},
		}
		reLua.indexWithAll(poeple, {name="Steve"}) -- {1,4}
		reLua.indexWithAll(poeple, {name="Sam"}) -- {}
		reLua.indexWithAll(poeple, {name="Steve"}, true) -- {2,3}

]]
function M.indexWithAll(arr, comparison, invert)
	invert = (not invert)
	local indices, objects, len = {}, {}, 0
	for i = 1, #arr do
		local match = true
		for k, v in pairs(comparison) do
			if (v == M.null) then v = nil; end
			if (arr[i][k] ~= v) then match = false; break; end
		end
		if (match == invert) then
			len = len+1
			indices[len], objects[len] = i, arr[i]
		end
	end
	return indices, objects
end



--[[
	indexMatching()
		Returns the index of a string matching a pattern in an array.

	Description:
		index = indexMatching( array, pattern [, plain [, startIndex ] [, returnLast ] ] )
			- array: The table to search through.
			- startIndex: The index to start the search at. If negative, it is taken as the offset from the end of the array. (Default: 1)
			- returnLast: If the array should be searched backwards. (Default: false)
			- the rest of the arguments are the same as string.find().
			> Returns: The index of the string matching the pattern, or nil if none matched.

	Example:
		local array = {"foo","bar","foobar","baz"}
		reLua.indexMatching(array, "ba[zr]") -- 2 (first string matching the pattern)
		reLua.indexMatching(array, "foo", 2) -- 3 (first string containing "foo" starting from index 2)
		reLua.indexMatching(array, "ba.", false, true) -- 4 (return last)
		reLua.indexMatching(array, "ba.", true) -- nil (plain text search)

]]
function M.indexMatching(arr, pattern, plain, startIndex, returnLast)
	if (type(startIndex) == 'boolean') then startIndex, returnLast = nil, startIndex end
	local len = #arr
	local from = (startIndex and startIndex < 0 and len+startIndex+1)
		or (startIndex) or (returnLast and len or 1)
	from = (returnLast and math.min(from, len) or math.max(from, 1))

	for i = from, (returnLast and 1 or len), (returnLast and -1 or 1) do
		if (arr[i]:find(pattern, 1, plain)) then
			return i
		end
	end

	return nil
end



--[[
	indexMatchingAll()
		Returns the index of all strings matching a pattern in an array.

	Description:
		indices = indexOfAll( array, pattern [, plain [, invert ] ] )
			- array: The table to search through.
			- invert: If all indices NOT matching the pattern should be returned instead. (Default: false)
			- the rest of the arguments are the same as string.find().
			> Returns: An array with indices of the strings matching the pattern, and an array with the matching strings themselves.

	Example:
		local array = {"foo","bar","foobar","baz"}
		reLua.indexMatchingAll(array, "ba[rz]") -- {2,3,4}
		reLua.indexMatchingAll(array, "ba[rz]", true) -- {} (plain text search)
		reLua.indexMatchingAll(array, "^ba", false, true) -- {1,3} (inverted search)

]]
function M.indexMatchingAll(arr, pattern, plain, invert)
	invert = (not invert)
	local indices, strings, len = {}, {}, 0
	if (plain) then
		for i = 1, #arr do
			if ((not arr[i]:find(pattern, 1, true)) ~= invert) then
				len = len+1
				indices[len], strings[len] = i, arr[i]
			end
		end
	else
		for i = 1, #arr do
			if ((not arr[i]:match(pattern)) ~= invert) then
				len = len+1
				indices[len], strings[len] = i, arr[i]
			end
		end
	end
	return indices, strings
end



-- Same as reLua.indexWith(), but with the returned object and index switched around
function M.itemWith(...)
	local i, obj = M.indexWith(...)
	return obj, i
end



-- Same as reLua.indexWithAll(), but with the returned object array and index array switched around
function M.itemWithAll(...)
	local indices, objects = M.indexWithAll(...)
	return objects, indices
end







-- Reference to the primitive array iteration function
-- Note that this function needs an initial value, otherwise an error is thrown (0 will start from the beginning)
M.inext = ipairs({}, 0)



-- Same as reLua.inext() but returns the previous array item instead of the next
-- The initial value can be emitted, unlike with reLua.inext().
function M.iprev(arr, i)
	i = (i and i-1 or #arr)
	local v = arr[i]
	if (v ~= nil) then return i, v; end
end



--[[
	prev()
		Same as the primitive next() but returns the previous key instead of the next.

	Description:
		prevKey, value = prev( table [, key ] )
			- key: The key to start at. If nil then the last key is returned. (Default: nil)
			> Returns: The previous key and it's associated value, or nil if no more keys exist.

	Example:
		local tbl = {a="X", b="Y", c="Z"}
		local key

		repeat
			key = next(tbl, key)
			print(key)
		until (key == nil)
		-- prints a, b, c, nil (the order of the keys can vary)

		repeat
			key = reLua.prev(tbl, key)
			print(key)
		until (key == nil)
		-- prints c, b, a, nil

]]
function M.prev(t, key)
	local success, failMessage = pcall(next, t, key)
	if (not success) then -- throws an error if the key is invalid
		error(failMessage:gsub('%f[%a]next%f[%A]', 'prev'), 2)
	end
	local currentKey, currentValue
	while (true) do
		if (next(t, currentKey) == key) then
			if (currentKey == nil) then
				return nil
			else
				return currentKey, currentValue
			end
		end
		currentKey, currentValue = next(t, currentKey)
	end
end







--[[
	ipairs()
		Same as the primitive ipairs(), but additionally with the ability to traverse arrays backwards.

	Description:
		iterator, array, init = ipairs( array [, reverse ] )
			- array: The table to traverse.
			- reverse: If the array should be traversed backwards. (Default: false)
			> Returns: An iterator function, the array argument and the initial value for the control variable, used for for loops.

	Example:
		local array = {"A","B","C"}

		for i, value in reLua.ipairs(array) do
			print(value)
		end
		-- Prints: A, B, C

		for i, value in reLua.ipairs(array, true) do
			print(value)
		end
		-- Prints: C, B, A

]]
function M.ipairs(arr, reverse)
	if reverse then
		return M.iprev, arr, #arr+1
	else
		return ipairs(arr)
	end
end



--[[
	sortedPairs()
		Same as the primitive pairs() except with sorted keys.

	Description:
		iterator, table, init = sortedPairs( table [, orderFunction ] )
			- table: The table to traverse.
			- orderFunction: Order function to use. (Default: alphabetical order)
			> Returns: An iterator function, the table argument and the initial value for the control variable, used for for loops.

	Example:
		local tbl = {foo=1, bar=5, foobar=8}
		for key, value in reLua.sortedPairs(tbl, true) do
			print(key)
		end
		-- Prints: bar, foo, foobar

]]
function M.sortedPairs(t, orderFunction)
	local i, keys = 0, M.sort(M.getKeys(t), orderFunction)
	return function()
		i = i+1
		local k = keys[i]
		if (k ~= nil) then return k, t[k] end
	end
end







--[[
	isArray()
		Checks if a value is an array-like table.

	Description:
		result = isArray( value [, emptyIsArray ] )
			- value: The value to check.
			- emptyIsArray: If an empty table would count as an array. (Default: true)
			> Returns: True if the value seems to be an array.

	Example:
		reLua.isArray({5,"foo",true}) -- true
		reLua.isArray({key="value"}) -- false
		reLua.isArray({}) -- true
		reLua.isArray({}, false) -- false
		reLua.isArray("Not a table") -- false

]]
function M.isArray(v, emptyIsArray)
	if (type(v) ~= 'table') then return false end
	for k, _ in pairs(v) do
		if (type(k) ~= 'number') then return false end
	end
	return (emptyIsArray ~= false)
end







-- Returns the amount of keys a table has
-- amount = keyAmount( table )
function M.keyAmount(t)
	local count = 0
	for k, v in pairs(t) do count = count+1; end
	return count
end







-- Removes excessive array items
-- array = limitArrayLength( array, maxLength )
function M.limitArrayLength(arr, len)
	for i = len+1, #arr do arr[i] = nil; end
	return arr
end



--[[
	padArray()
		Makes sure an array have a minimum length by filling in the remaining slots with a value.

	Description:
		array = padArray( array, minLength [, padding ] )
			- array: The array to pad.
			- minLength: The target length. If positive then the array is padded on the right side, otherwise the left side is padded.
			- padding: The value to pad with. (Default: reLua.null)
			> Returns: The array argument.

	Example:
		reLua.padArray({1,2,3}, 5, 0) -- {1,2,3,0,0}
		reLua.padArray({1,2,3}, -5, 0) -- {0,0,1,2,3}
		reLua.padArray({1,2,3}, 2, 0) -- no change

]]
function M.padArray(arr, len, v)
	if (v == nil) then v = M.null; end
	if (len < 0) then
		local offset = -len-#arr
		if (offset > 0) then
			for i = #arr, 1, -1 do arr[i+offset] = arr[i]; end
			for i = 1, offset do arr[i] = v; end
		end
	else
		for i = #arr+1, len do arr[i] = v; end
	end
	return arr
end



--[[
	fillArray()
		Replaces all values in an array with a specified value.

	Description:
		array = fillArray( array [, from, to ], value )
			- array: The array to fill.
			- from: From what index to begin filling. If negative, it is taken as the offset from the end of the array. (Default: 1)
			- to: At what index to stop filling. If negative, it is taken as the offset from the end of the array. (Default: #array)
			- value: Value to use as filling.
			> Returns: The array argument.
			! Alternative to:
				reLua.setKeysIdentical(array, reLua.range(from, to), value)

	Example:
		reLua.fillArray({1,2,3,4}, 0) -- {0,0,0,0}
		reLua.fillArray({1,2,3,4}, 2,3, 0) -- {1,0,0,4}
		reLua.fillArray({1,2}, 2,3, 0) -- {1,0,0}

]]
function M.fillArray(arr, from, to, v)
	if (to) then
		if (from < 0) then from = #arr-from; end
		if (to < 0) then to = #arr-to; end
	else
		from, to, v = 1, #arr, from
	end
	for i = from, to do arr[i] = v; end
	return arr
end







--[[
	mergeArrays()
		Merges several arrays into a single one.
		Unlike reLua.appendToArray() this function creates a new array instead of modifying an existing one.

	Description:
		mergedArray = mergeArrays( ... )
			- ...: Arrays to merge.
			> Returns: A new array containing everything from the argument arrays.

	Example:
		local arr1 = {"A", "B"}
		local arr2 = {"i", "j"}
		local arr3 = {true}
		reLua.mergeArrays(arr1, arr2, arr3) -- {"A","B","i","j",true}

]]
function M.mergeArrays(...)
	local merge, i = {}, 0
	for _, arr in ipairs{...} do
		for _, v in ipairs(arr) do
			i = i+1
			merge[i] = v
		end
	end
	return merge
end



--[[
	mergeUniqueArrays()
		Merges several arrays into a single one without containing dublettes.

	Description:
		mergedArray = mergeUniqueArrays( ... )
			- ...: Arrays to merge.
			> Returns: A new array containing all unique items from the argument arrays.

	Example:
		local arr1 = {"A", "i", "B", true}
		local arr2 = {"i", "j"}
		local arr3 = {true}
		reLua.mergeArrays(arr1, arr2, arr3) -- {"A","i","B",true,"i","j",true}
		reLua.mergeUniqueArrays(arr1, arr2, arr3) -- {"A","i","B",true,"j"}

]]
function M.mergeUniqueArrays(...)
	local merge, i, existing = {}, 0, {}
	for _, arr in ipairs{...} do
		for _, v in ipairs(arr) do
			if (not existing[v]) then
				i = i+1
				merge[i] = v
				existing[v] = true
			end
		end
	end
	return merge
end







--[[
	migrateArray()
		Moves all items from one array to another.

	Description:
		from, to = migrateArray( from, to )
			- from: The source array. This array will end up empty.
			- to: The target array. New items are inserted at the end.
			> Returns: All arguments.

	Example:
		local arr1, arr2 = {1,2}, {8,9}
		migrateArray(arr1, arr2)
		-- arr1 is: {}
		-- arr2 is: {8,9,1,2}

]]
function M.migrateArray(from, to)
	local len = #to
	for i, v in ipairs(from) do
		to[len+i], from[i] = v, nil
	end
	return from, to
end



--[[
	migrateTable()
		Moves all attributes from one table to another.

	Description:
		from, to = migrateTable( from, to )
			- from: The source table. This table will end up empty.
			- to: The target table. Existing attributes will get overwritten if they appear in 'from'.
			> Returns: All arguments.

	Example:
		local tbl1 = {a=1, b=2}
		local tbl2 = {b=8, c=9}
		migrateTable(tbl1, tbl2)
		-- tbl1 is: {}
		-- tbl2 is: {a=1, b=8, c=9}

]]
function M.migrateTable(from, to)
	for k, v in pairs(from) do
		to[k], from[k] = v, nil
	end
	return from, to
end







--[[
	newSet()
		Returns a simple object used for checking if a value is part of a set.

	Description:
		set = newSet( list )
			- list: An array with items for the set.

	Example: Checking if words are reserved.
		local reserved = reLua.newSet{"while", "end", "function", "local"}

		local function checkWord(word)
			if reserved[word] then
				print(("'%s' is reserved"):format(word))
			else
				print(("'%s' is not reserved"):format(word))
			end
		end

		checkWord("hello") -- prints: 'hello' is not reserved
		checkWord("function") -- prints: 'function' is reserved

		-- Print out the reserved words
		for word in pairs(reserved) do
			print(word)
		end

]]
function M.newSet(values)
	return M.setKeysIdentical({}, values, true)
end







--[[
	range()
		Returns an array filled with numbers in a given range.

	Description:
		numbers = range( [ from, ] to [, step ] )
			- from: The starting number. (Default: 1)
			- to: The ending number.
			- step: The step size between all numbers. (Default: 1)
			> Returns: An array with numbers in the given range.

	Example:
		reLua.range(3) -- {1,2,3}
		reLua.range(2, 5) -- {2,3,4,5}
		reLua.range(0, 30, 10) -- {0,10,20,30}

]]
function M.range(from, to, step)
	if (not to) then from, to = 1, from end
	local arr = {}
	for nr = from, to, (step or 1) do
		arr[#arr+1] = nr
	end
	return arr
end







--[[
	removeItem()
		Removes an object from an array.

	Description:
		removedIndex = removeItem( array, obj )
			- array: The table to alter.
			- obj: What object to remove.
			> Returns: The index that was removed, if any, nil otherwise.

	Example:
		local arr = {"A","B","C"}
		reLua.removeItem(arr, "B") -- 2
		print(unpack(arr)) -- A, C
		reLua.removeItem(arr, "B") -- nil

]]
function M.removeItem(arr, obj)
	local i = M.indexOf(arr, obj)
	return (i and table.remove(arr, i) and i or nil)
end



--[[
	removeItemAll()
		Removes an object from an array.

	Description:
		removedIndex = removeItemAll( array, obj )
			- array: The table to alter.
			- obj: What object to remove.
			> Returns: The index that was removed, if any, nil otherwise.

	Example:
		local arr = {"A","B","A"}
		reLua.removeItemAll(arr, "A") -- {1,3}
		-- arr is: {"B"}

]]
function M.removeItemAll(arr, obj)
	local indices, len, shift = {}, #arr, 0
	for i = 1, len do
		arr[i-shift] = arr[i]
		if (arr[i] == obj) then
			shift = shift+1
			indices[shift] = i
		end
	end
	for i = len-shift+1, len do arr[i] = nil end
	return indices
end



--[[
	replaceItem()
		Replaces a value in an array.
		Use replaceTableValueAll to replace all instances of the value.

	Description:
		replacedIndex = replaceItem( array, search, replace )
			- array: The table to alter.
			- search: The value to search for and replace.
			- replace: The replacement.
			> Returns: The index of the replaced item, or nil if the item wasn't found.

	Example:
		local arr = {"A","B","C"}
		reLua.replaceItem(arr, "B", "X") -- 2
		print(unpack(arr)) -- A, X, C
		reLua.replaceItem(arr, "B") -- nil

]]
function M.replaceItem(arr, search, replace)
	local i = M.indexOf(arr, search)
	if (i) then arr[i] = replace; end
	return i
end



--[[
	replaceTableValue()
		Replaces a value in a table.

	Description:
		replacedKey = replaceTableValue( table, search, replace )
			- table: The table to alter.
			- search: The value to search for and replace.
			- replace: The replacement.
			> Returns: The key whose value was replaced, or nil if the value wasn't found.

	Example:
		local person = {name="Theodor", nick="Theo", age=32}
		reLua.replaceTableValue(person, "Theo", "Mr. T") -- "nick"
		print(person.nick) -- Mr. T

]]
function M.replaceTableValue(t, search, replace)
	for k, v in pairs(t) do
		if (v == search) then
			t[k] = replace
			return k
		end
	end
	return nil
end



--[[
	replaceTableValueAll()
		Replaces all instances of a value in a table.

	Description:
		replacedKeys = replaceTableValueAll( table, search, replace )
			- table: The table to alter.
			- search: The value to search for and replace.
			- replace: The replacement.
			> Returns: The keys whose values was replaced.

	Example:
		local tbl = {a="foo", b="bar", c="foo"}
		reLua.replaceTableValueAll(tbl, "foo", "X") -- {"a","c"}
		-- tbl is: {a="X", b="bar", c="X"}

]]
function M.replaceTableValueAll(t, search, replace)
	local keys = {}
	for k, v in pairs(t) do
		if (v == search) then
			keys[#keys+1], t[k] = k, replace
		end
	end
	return keys
end



--[[
	replaceTableValueRecursive()
		Replaces all instances of a value in a table recursively.

	Description:
		table = replaceTableValueRecursive( table, search, replace )
			- table: The table to alter.
			- search: The value to search for and replace.
			- replace: The replacement.
			> Returns: The key whose value was replaced, or nil if the value wasn't found.

	Example:
		local databaseEntry = {
			id = 21,
			name = "?",
			children = {
				{id=43, name="Foo"},
				{id=44, name="?"},
				{id=45, name="Bar"},
			},
		}
		reLua.replaceTableValueRecursive(databaseEntry, "?", nil)

]]
function M.replaceTableValueRecursive(t, search, replace)
	for k, v in pairs(t) do
		if (v == search) then
			t[k] = replace
		elseif (type(v) == 'table') then
			M.replaceTableValueRecursive(v, search, replace)
		end
	end
	return t
end







-- Reverses the order of an array's items
-- array = reverseArray( array )
function M.reverseArray(arr)
	local lenPlusOne, i2 = #arr+1
	for i = 1, #arr/2 do
		i2 = lenPlusOne-i
		arr[i], arr[i2] = arr[i2], arr[i]
	end
	return arr
end







--[[
	setAttr()
		Sets one or multiple attributes on a table.

	Description:
		target = setAttr( target, attrTable )
		target = setAttr( target, attrName1, value1 [, ... attrNameN, valueN ] )
			- target: The table to update.
			- attrTable: A table with values to copy over to the target.
			- attrName, value: Key/value pairs to update target with.
			> Returns: The target argument.

	Example:
		local tbl = {
			name = "Lee",
			city = "Tokyo",
			year = 1957,
		}
		reLua.setAttr(tbl, {year=1934, color="Blue"}) -- {name="Lee", city="Tokyo", year=1934, color="Blue"}
		reLua.setAttr(tbl, "color",nil, "year",1929) -- {name="Lee", city="Tokyo", year=1929}

]]
function M.setAttr(t, ...)
	local argLen = select('#', ...)
	if (argLen > 1) then
		for i = 1, argLen-1, 2 do
			t[select(i, ...)] = select(i+1, ...)
		end
	else
		for k, v in pairs(select(1, ...)) do
			t[k] = v
		end
	end
	return t
end



--[[
	setKeys()
		Sets one or multiple attributes on a table using separate arguments for keys and values.

	Description:
		target = setKeys( target, keys, values )
			- target: The table to update.
			- keys: An array with key names.
			- values: An array with values for each respective key.
			> Returns: The target argument.

	Example:
		local tbl = {}
		reLua.setKeys(tbl, {"a","b"}, {"Foo","Bar"})
		print(tbl.a..tbl.b)  -- FooBar

]]
function M.setKeys(t, keys, values)
	for i, k in ipairs(keys) do t[k] = values[i]; end
	return t
end



--[[
	setKeysIdentical()
		Same as reLua.setKeys() but reuses the same value for all keys.

	Description:
		target = setKeysIdentical( target, keys, value )
			- target: The table to update.
			- keys: An array with key names.
			- value: The value for the keys.
			> Returns: The target argument.

	Example:
		local tbl = {a="Foo", b="Bar", c="Baz"}
		reLua.setKeysIdentical(tbl, {"a","c"}, "Hello")
		print(tbl.a..tbl.b..tbl.c)  -- HelloBarHello

]]
function M.setKeysIdentical(t, keys, value)
	for _, k in ipairs(keys) do t[k] = value; end
	return t
end



--[[
	setMissing()
		Sets missing (nil) attributes on a table.

	Description:
		target = setMissing( target, complement )
			- target: The table to complete.
			- complement: A table with standard values.
			> Returns: The target argument.

	Example:
		local defaultPerson = {name="John Doe", age=30, height=175}
		local person = {name="Sam Fisher", height=189}
		reLua.setMissing(person, defaultPerson)
		print(person.name, person.age)  -- Sam Fisher  30

]]
function M.setMissing(t, values)
	for k, v in pairs(values) do
		if t[k] == nil then t[k] = v; end
	end
	return t
end







-- Shuffles the items in an array
-- array = shuffleArray( array [, fromIndex [, toIndex ] ] )
function M.shuffleArray(arr, from, to)
	local tmp, len, tmpLen = {}, #arr, 0
	from, to = (from or 1), (to or len)
	if (from < 1) then from = len+from+1; end
	if (to < 1) then to = len+to; end
	for i = from, to do
		tmpLen = tmpLen+1
		tmp[tmpLen] = arr[i]
	end
	for i = from, to do
		arr[i] = table.remove(tmp, math.random(tmpLen))
		tmpLen = tmpLen-1
	end
	return arr
end







-- Returns part of an array
-- slice = sliceArray( array, from [, length ] )
function M.sliceArray(arr, from, length)
	local slice = {}
	for i = from, math.min(from+(length or math.huge)-1, #arr) do slice[i-from+1] = arr[i]; end
	return slice
end



--[[
	spliceArray()
		Adds/removes part of an array.

	Description:
		removedItems = spliceArray( array, from [, amount [, ... ] ] )
			- array: The table to alter.
			- from: At what index the removal/insertion will occur. If negative, it is taken as the offset from the end of the array.
			- amount: How many items should be removed. (Default: all remaining items)
			- ...: Objects to insert. (Default: none)
			> Returns: A list containing the removed items.

	Example:
		local array = {1,2,3,4,5,6}
		local removedItems = reLua.spliceArray(array, 3, 2, "A","B","C")
		-- removedItems is {3,4}
		-- array is {1,2,"A","B","C",5,6}

]]
function M.spliceArray(arr, from, amount, ...)
	local removed, len, argLen = {}, #arr, select('#', ...)
	from = (from < 0 and math.max(len+from+1, 1) or M.clamp(from, 1, len+1))
	amount = M.clamp(amount or math.huge, 0, len-from+1)

	-- Retrieve the values that will be removed
	for i = from, from+amount-1 do removed[#removed+1] = arr[i]; end
	if (argLen < amount) then

		-- New length will be shorter - move items back and pad with nil at the end
		for i = from+argLen, len do
			arr[i] = arr[i-argLen+amount]
		end

	else

		-- New length will be longer - move items forward
		for i = len, from+amount, -1 do
			arr[i-amount+argLen] = arr[i]
		end

	end

	-- Add the new items
	for i = from, from+argLen-1 do
		arr[i] = select(i-from+1, ...)
	end

	return removed
end

-- -- A lot slower...
-- function M.spliceArray2(arr, from, amount, ...)
-- 	local len, removed = #arr, {}
-- 	from = (from < 0 and math.max(len+from+1, 1) or M.clamp(from, 1, len+1))
-- 	amount = M.clamp(amount or math.huge, 0, len-from+1)
-- 	for i = 1, amount do removed[i] = table.remove(arr, from); end
-- 	for i, v in ipairs{...} do table.insert(arr, from+i-1, v); end
-- 	return removed
-- end

-- -- Tests...
-- for _, spliceArray in ipairs{M.spliceArray, M.spliceArray2} do
-- 	print('========')
-- 	local array = M.range(6)
-- 	table.foreachi(array, print) -- {1,2,3,4,5,6}
-- 	print('--')
-- 	local removedItems = spliceArray(array, -1, -1, "A","B","C")
-- 	-- local removedItems = spliceArray(array, -1, nil, "A","B","C")
-- 	-- local removedItems = spliceArray(array, -1, 0, "A","B","C")
-- 	-- local removedItems = spliceArray(array, 100, nil, "A","B","C")
-- 	-- local removedItems = spliceArray(array, 100, 0, "A","B","C")
-- 	-- local removedItems = spliceArray(array, 3, nil, "A","B","C")
-- 	-- local removedItems = spliceArray(array, 3, 100, "A","B","C")
-- 	-- local removedItems = spliceArray(array, 3, 0, "A","B","C")
-- 	-- local removedItems = spliceArray(array, 3, 2, "A","B","C")
-- 	-- local removedItems = spliceArray(array, 3, 2, "A")
-- 	-- local removedItems = spliceArray(array, 3, 2)
-- 	table.foreachi(removedItems, print) -- {3,4}
-- 	print('--')
-- 	table.foreachi(array, print) -- {1,2,"A","B","C",5,6}
-- end
-- print('========')
-- test(function()
-- 	M.spliceArray(M.range(50), 10, 30, unpack(M.range(30)))
-- end, 10000)
-- test(function()
-- 	M.spliceArray2(M.range(50), 10, 30, unpack(M.range(30)))
-- end, 10000)







-- Same as table.sort() but also returns the array argument
-- array = sort( array [, orderFunction ] )
function M.sort(...)
	table.sort(...)
	return (...)
end



--[[
	sortByColumn()
		Sorts an array of tables by one of their attributes.

	Description:
		array = sortByColumn( array, attrName [, orderFunction ] )
			- array: The array of tables to sort.
			- attrName: What attribute to compare.
			- orderFunction: A comparison function. It receives two attribute values to compare. (Default: the < operator is used)
			> Returns: The array argument.

	Example:
		function orderReverse(a, b)
			return (b < a)
		end
		local poeple = {
			{name="Harry", age=31},
			{name="Sarah", age=49},
			{name="Jones", age=25},
		}

		reLua.sortByColumn(poeple, "name", orderReverse)
		-- poeple is: {
		--   {name="Sarah", age=49},
		--   {name="Jones", age=25},
		--   {name="Harry", age=31},
		-- }

		reLua.sortByColumn(poeple, "age", orderReverse)
		-- poeple is: {
		--   {name="Sarah", age=49},
		--   {name="Harry", age=31},
		--   {name="Jones", age=25},
		-- }

]]
function M.sortByColumn(arr, attr, comp)
	if (comp) then
		table.sort(arr, function(a, b)
			return comp(a[attr], b[attr])
		end)
	else
		table.sort(arr, function(a, b)
			return a[attr] < b[attr]
		end)
	end
	return arr
end







-- Converts a value to an array
-- Tables with non-numeric keys are not considered arrays
-- array = toArray( value )
function M.toArray(v)
	return (M.isArray(v) and v or {v})
end



-- Converts a value to a table
-- Non-tables are inserted into a new array-like table
-- table = toTable( value )
function M.toTable(v)
	return (type(v) == 'table' and v or {v})
end















--==============================================================
--=         ====================================================
--=  Other  ====================================================
--=         ====================================================
--==============================================================







-- Bulletproof alternative to 'a and b or c'  ('a ? b : c' in other languages)
function M.choose(cond, a, b)
	if (cond) then return a; else return b; end
end







-- Creates the specified module (if it doesn't already exist)
-- Set overwrite to true to replace existing module if needed
-- module = createModule( name, content [, overwrite=false ] )
function M.createModule(name, content, overwrite)
	if (content == nil) then error('Content cannot be nil', 2); end
	if (overwrite or package.loaded[name] == nil) then package.loaded[name] = content; end
	return require(name)
end

-- Checks if a module has been loaded
-- result = moduleLoaded( name )
function M.moduleLoaded(name)
	return (not not package.loaded[name])
end

-- Removes a module
-- unloadModule( name )
function M.unloadModule(name)
	package.loaded[name] = nil
end

-- Removes the specified module if it exists and requires it again
-- module = requireNew( moduleName )
function M.requireNew(name)
	M.unloadModule(name)
	return require(name)
end

-- Same as the primitive require(), but doesn't throw an error for missing modules
-- Returns nil for missing modules
-- module = include( moduleName )
function M.include(name)
	local success, m = pcall(require, name)
	return (success and m or nil)
end

-- Same as reLua.requireNew(), but calls reLua.include() instead of the primitive require()
-- module = includeNew( moduleName )
function M.includeNew(name)
	M.unloadModule(name)
	return M.include(name)
end







--[[
	firstValue()
		Returns the first non-nil argument.

	Description:
		value, position = firstValue( value1 [, ... valueN ] )
			- value: Values.
			> Returns: The first non-nil value and it's argument number, or nil if none exists.

	Example:
		reLua.firstValue(5, "A") -- 5, 1
		reLua.firstValue(nil, "A") -- "A", 2
		reLua.firstValue(nil, false) -- false, 2
		reLua.firstValue(nil, nil) -- nil, nil

]]
function M.firstValue(...)
	for i = 1, select('#', ...) do
		local v = select(i, ...)
		if (v ~= nil) then return v, i end
	end
	return nil
end







--[[
	isEmpty()
		Checks if a variable is empty or not (like the empty() funtion in PHP).

	Description:
		result = isEmpty( value [, zeroStringIsEmpty ] )
			- value: The value to check.
			- zeroStringIsEmpty: If a string casted as a number equals zero should count as empty (e.g. "0.0"). (Default: false)
			> Returns: True if the variable is empty, false otherwise.

	Example:
		local isEmpty = reLua.isEmpty

		-- Empty values
		isEmpty( nil ) -- true
		isEmpty( false ) -- true
		isEmpty( 0 ) -- true
		isEmpty( "" ) -- true
		isEmpty( {} ) -- true
		isEmpty( "0.0", true ) -- true

		-- Icke-tomma värden
		isEmpty( true ) -- false
		isEmpty( 1 ) -- false
		isEmpty( "a" ) -- false
		isEmpty( {0} ) -- false (the table contains a value)
		isEmpty( "0.0", false ) -- false

]]
function M.isEmpty(v, zeroStringIsEmpty)
	if (type(v) == 'table') then
		return (not next(v))
	else
		return (not v or v == '' or v == 0 or (zeroStringIsEmpty and tonumber(v) == 0) or false)
	end
end







--[[
	weakReference()
		Create an object which holds a weak reference to another object.

	Description:
		weakReference = newWeakReference( object )
			- object: A reference to any object.
			> Returns: A new weakReference object (table).

	Example:
		local tbl = {}
		local tblRef = reLua.newWeakReference(tbl)
		print(tblRef:get()) -- table: ########
		tbl = nil
		collectgarbage()
		print(tblRef:get()) -- nil

]]
do local function get(ref) return ref[1]; end

	function M.newWeakReference(object)
		local ref = setmetatable({object}, {__mode='v'})
		ref.get = get
		return ref
	end

end







--[[
	print()
		Prints variables a bit more nicely than the primitive print().
		Recursion can occur safely.

	Description:
		print( ... )
			- ...: Things to print. Literally anything! :D

	Example:
		local tbl = {
			array = {"a","b","c"},
			num = 12.3,
			[{}] = "Table index",
		}
		tbl.myself = tbl
		tbl.recursive1 = {tbl}
		tbl.recursive2 = {{tbl}}
		reLua.print("Hello, world!", nil, tbl)

]]
do local indentStr, ipairs, print, tostring, type = '   ', _G.ipairs, _G.print, _G.tostring, _G.type



	local function compareKeys(a, b)
		return tostring(a) < tostring(b)
	end



	local function printObj(o, parents, indent, name)
		local fullIndentStr, depth = indentStr:rep(indent), M.indexOf(parents, o)

		-- Avoid infinite table recursion
		if (depth) then
			if (depth == indent) then
				print(fullIndentStr..name..'SELF')
			else
				print(fullIndentStr..name..'PARENT('..(indent-depth)..')')
			end
			return
		end
		local oType = type(o)

		-- Tables
		if oType == 'table' then
			if (next(o) == nil) then
				print(fullIndentStr..name..'{}')

			-- :: array-like tables
			elseif (M.isArray(o)) then
				parents[indent+1] = o
				print(fullIndentStr..name..'{')
				for i = 1, table.maxn(o) do
					if (o[i] ~= nil) then
						printObj(o[i], parents, indent+1, i..' = ')
					end
				end
				print(fullIndentStr..'}')
				parents[indent+1] = nil

			-- :: other tables
			else
				parents[indent+1] = o
				print(fullIndentStr..name..'{')
				for _, k in ipairs(M.sort(M.getKeys(o), compareKeys)) do
					printObj(o[k], parents, indent+1, '['..tostring(k)..'] = ')
				end
				print(fullIndentStr..'}')
				parents[indent+1] = nil
			end

		-- Strings
		elseif oType == 'string' then
			print(fullIndentStr..name..'"'..o:gsub('%z+', '')..'"')

		-- Other types
		else
			print(fullIndentStr..name..tostring(o))

		end
	end



	function M.print(...)
		for i = 1, select('#', ...) do
			printObj(select(i, ...), {}, 0, '')
		end
	end



end







-- Converts a value to a boolean
-- bool = toBoolean( value )
function M.toBoolean(v)
	return (not not v)
end







--[[
	xor()
		Returns the one true argument if exactly one exists.

	Description:
		result = xor( ... )
			- ...: Any values.
			> Returns: the true argument if exactly one exists, false otherwise.

	Example:
		local xor = reLua.xor

		xor(false, false) -- false
		xor(true, false) -- true
		xor(false, true) -- true
		xor(true, true) -- false
		xor(nil, true) -- true
		xor(8, false) -- 8
		xor(8, false, 5) -- false
		xor(false, nil) -- false

		-- Comparison to 'or'
		(false or false) -- false
		(true or false) -- true
		(false or true) -- true
		(true or true) -- true
		(nil or true) -- true
		(8 or false) -- 8
		(8 or false or 5) -- 8
		(false or nil) -- nil

]]
function M.xor(...)
	local v, v2 = false
	for i = 1, select('#', ...) do
		v2 = select(i, ...)
		if (v2) then
			if (v) then return false; end
			v = v2
		end
	end
	return v
end















--==============================================================
--==============================================================
--==============================================================
--==============================================================
--==============================================================

return M
