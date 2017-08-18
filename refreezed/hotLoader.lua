--[[============================================================
--=
--=  Hot file loading module
--=
--=  Dependencies:
--=  - either LuaFileSystem or LÖVE 0.10+
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



	-- Usage outside LÖVE:

	local hotLoader = require("hotLoader")
	local duckImagePath = "duck.jpg"

	-- Initial loading of resources
	hotLoader.load(duckImagePath)

	-- Program loop
	local lastTime = os.clock()
	while true do
		local currentTime = os.clock()

		-- Allow hotLoader to reload module and resource files that have been updated
		hotLoader.update(currentTime-lastTime)

		-- Show if debug mode is enabled
		local settings = hotLoader.require("appSettings")
		if (settings.enableDebug) then
			print("DEBUG")
		end

		-- Show size of duck image
		local duckImageData = hotLoader.load(duckImagePath)
		print("Duck is "..(#duckImageData).." bytes")

		lastTime = currentTime
	end



	-- Usage in LÖVE:

	local hotLoader = require("hotLoader")
	local player = {
		x = 100, y = 50,
		imagePath = "player.png",
	}

	function love.load()

		-- Tell hotLoader to load .png files using love.graphics.newImage
		hotLoader.setLoader("png", love.graphics.newImage)

		-- Do the initial loading of resources
		hotLoader.load(player.imagePath)

	end

	function love.update(dt)

		-- Allow hotLoader to reload module and resource files that have been updated
		hotLoader.update(dt)

	end

	function love.draw()

		-- Show if debug mode is enabled
		local settings = hotLoader.require("gameSettings")
		if (settings.enableDebug) then
			love.graphics.print("DEBUG", 5, 5)
		end

		-- Draw player image
		local playerImage = hotLoader.load(player.imagePath)
		love.graphics.draw(playerImage, player.x, player.y)

	end



--==============================================================

	API:

	update

	getCheckingInterval, setCheckingInterval
	getLoader, setLoader, getCustomLoader, setCustomLoader, getDefaultLoader, setDefaultLoader
	load, unload
	require, unrequire

--============================================================]]



local hotLoader = {}

local checkingInterval = 1.00
local loaders, customLoaders, defaultLoader = {}, {}, nil
local moduleModifiedTimes = {}
local modulePaths = {}
local modules = {}
local resourceModifiedTimes = {}
local resourcePaths = {}
local resources = {}
local time = 0.00



--==============================================================
--==============================================================
--==============================================================

local fileExists
local getLastModifiedTime, getModuleLastModifiedTime
local getModuleFilePath
local getRequirePath
local loadModule
local loadResource
local readFile, loadLuaFile
local removeItem



-- fileExists( filePath )
fileExists = love and love.filesystem.exists or function(filePath)
	local file = io.open(filePath, 'r')
	if (not file) then
		return false
	end
	file:close()
	return true
end



-- time, errorMessage = getLastModifiedTime( filePath )
getLastModifiedTime = love and love.filesystem.getLastModified or require('lfs') and function(filePath)
	return require('lfs').attributes(filePath, 'modification')
end or error('[hotLoader] Requirements are not met')

-- time, errorMessage = getModuleLastModifiedTime( path )
function getModuleLastModifiedTime(path)
	return getLastModifiedTime(getModuleFilePath(path))
end



-- filePath = getModuleFilePath( path )
do
	local filePaths = {}

	function getModuleFilePath(path)
		local filePath = filePaths[path]
		if (not filePath) then
			local filePathsStr = getRequirePath():gsub('?', (path:gsub('%.', '/')))
			for currentFilePath in filePathsStr:gmatch('[^;]+') do
				if (fileExists(currentFilePath)) then
					filePath = currentFilePath
					break
				end
			end
			filePaths[path] = filePath or error('[hotLoader] Cannot find module on path "'..path..'"')
		end
		return filePath
	end

end



-- filePathsString = getRequirePath( )
getRequirePath = love and love.filesystem.getRequirePath or function()
	return package.path
end



-- module = loadModule( path, protected )
function loadModule(path, protected)
	local M
	if (protected) then
		local ok, chunkOrErr = pcall(loadLuaFile, getModuleFilePath(path))
		if (not ok) then
			print('[hotLoader] ERROR: '..chunkOrErr)
			return nil
		end
		M = chunkOrErr()
	else
		M = loadLuaFile(getModuleFilePath(path))()
	end
	if (M == nil) then
		M = true
	end
	return M
end



-- resource = loadResource( filePath, protected )
function loadResource(filePath, protected)
	local loader, res = (customLoaders[filePath] or loaders[filePath:match('%.(%w+)$')] or defaultLoader or readFile)
	if (protected) then
		local ok, resOrErr = pcall(loader, filePath)
		if (not ok) then
			print('[hotLoader] ERROR: '..resOrErr)
			return nil
		elseif (not resOrErr) then
			print('[hotLoader] ERROR: Loader returned nothing for "'..filePath..'"')
			return nil
		end
		res = resOrErr
	else
		res = assert(loader(filePath))
	end
	return res
end



-- contents, errorMessage = readFile( filePath )
readFile = love and love.filesystem.read or function(filePath)
	local file, err = assert(io.open(filename, 'rb'))
	if (not file) then
		return nil, err
	end
	local contents = file:read('*a')
	file:close()
	return contents
end

-- chunk, errorMessage = loadLuaFile( filePath )
loadLuaFile = love and love.filesystem.load or loadfile



-- index = removeItem( table, value )
function removeItem(t, targetV)
	for i, v in ipairs(t) do
		if (v == targetV) then
			t[i] = nil
			return i
		end
	end
	return nil
end



--==============================================================
--==============================================================
--==============================================================



-- update( deltaTime )
function hotLoader.update(dt)
	time = time+dt
	if (time < checkingInterval) then
		return
	end
	time = 0

	-- Check modules
	for _, path in ipairs(modulePaths) do
		local modifiedTime = getModuleLastModifiedTime(path)
		if (modifiedTime ~= moduleModifiedTimes[path]) then
			local M = loadModule(path, true)
			if (M ~= nil) then
				modules[path] = M
			end
			moduleModifiedTimes[path] = modifiedTime
			print('[hotLoader] Reloaded module "'..path..'"')
		end
	end

	-- Check resources
	for _, filePath in ipairs(resourcePaths) do
		local modifiedTime = getLastModifiedTime(filePath)
		if (modifiedTime ~= resourceModifiedTimes[filePath]) then
			local res = loadResource(filePath, true)
			if (res ~= nil) then
				resources[filePath] = res
			end
			resourceModifiedTimes[filePath] = modifiedTime
			print('[hotLoader] Reloaded resource "'..filePath..'"')
		end
	end

end



--==============================================================



-- interval = getCheckingInterval( )
function hotLoader.getCheckingInterval()
	return checkingInterval
end

-- setCheckingInterval( interval )
function hotLoader.setCheckingInterval(interval)
	checkingInterval = interval
end



-- loader = getLoader( fileExtension )
function hotLoader.getLoader(fileExt)
	return loaders[fileExt]
end

-- Sets a loader for a file extension
-- setLoader( fileExtension, [ fileExtension2..., ] loader )
-- loader: function( fileContents, filePath )
function hotLoader.setLoader(...)
	local argCount = select('#', ...)
	local loader = select(argCount, ...)
	for i = 1, argCount-1 do
		loaders[select(i, ...)] = loader
	end
end

-- loader = getCustomLoader( filePath )
function hotLoader.getCustomLoader(filePath)
	return customLoaders[filePath]
end

-- Sets a loader for a specific file path
-- setCustomLoader( filePath, [ filePath2..., ] loader )
-- loader: function( fileContents, filePath )
function hotLoader.setCustomLoader(...)
	local argCount = select('#', ...)
	local loader = select(argCount, ...)
	for i = 1, argCount-1 do
		customLoaders[select(i, ...)] = loader
	end
end

-- loader = getDefaultLoader( )
function hotLoader.getDefaultLoader()
	return defaultLoader
end

-- setDefaultLoader( loader )
-- loader: Specify nil to restore original default loader (which loads the file as a plain string)
function hotLoader.setDefaultLoader(loader)
	defaultLoader = loader
end



-- resource = load( filePath [, customLoader ] )
-- customLoader: If set, replaces the previous custom loader for filePath
function hotLoader.load(filePath, loader)
	if (loader) then
		hotLoader.setCustomLoader(filePath, loader)
	end
	local res = resources[filePath]
	if (res == nil) then
		res = loadResource(filePath, false)
		resources[filePath] = res
		resourceModifiedTimes[filePath] = getLastModifiedTime(filePath)
		table.insert(resourcePaths, filePath)
	end
	return res
end

-- Forces the resource to reload at next load call
-- unload( filePath )
function hotLoader.unload(filePath)
	resources[filePath] = nil
	removeItem(resourcePaths, filePath)
end



-- Requires a module just like the standard Lua require() function
-- module = require( path )
function hotLoader.require(path)
	local M = modules[path]
	if (M == nil) then
		M = loadModule(path, false)
		modules[path] = M
		moduleModifiedTimes[path] = getModuleLastModifiedTime(path)
		table.insert(modulePaths, path)
	end
	return M
end

-- Forces the module to reload at next require call
-- unrequire( path )
function hotLoader.unrequire(path)
	modules[path] = nil
	removeItem(modulePaths, path)
end



--==============================================================
--==============================================================
--==============================================================

-- Set default loaders in LÖVE
if (love) then
	hotLoader.setLoader(
		'jpg','jpeg',
		'png',
		'tga',
		love.graphics.newImage)
	hotLoader.setLoader(
		'wav',
		'ogg','oga','ogv',
		function(filePath)
			return love.audio.newSource(filePath, 'static')
		end)
	hotLoader.setLoader(
		'mp3',
		'699','amf','ams','dbm','dmf','dsm','far','it','j2b','mdl','med',
			'mod','mt2','mtm','okt','psm','s3m','stm','ult','umx','xm',
		'abc','mid','pat',
		function(filePath)
			return love.audio.newSource(filePath, 'stream')
		end)
end

--==============================================================

return hotLoader
