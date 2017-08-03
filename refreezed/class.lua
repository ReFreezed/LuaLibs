--[[============================================================
--=
--=  Class module
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

	myClass = require("class")( className, baseTable ) -- create a new class
	subClass = myClass:extend( className, baseTable ) -- create a sub class

	subClass.super -- access the parent class

	instance = myClass(...) -- create a new instance (calls myClass.init)
	result = instance:is( class ) -- check if the instance inherits a class
	instance = instance:as( class ) -- get the instance if it inherits a class

	instance.class -- access the instance's class

	-- Shorthands
	myClass:define("myValue") -- automatically define simple getter and setter (getMyValue and setMyValue)
	myClass:defineGet("myReadOnly") -- define simple getter (instance:getMyReadOnly returns instance.myReadOnly)
	myClass:defineSet("myValue") -- define simple setter (instance:setMyValue updates instance.myValue)

--============================================================]]

local classes = setmetatable({}, {__mode='k'})
local instances = setmetatable({}, {__mode='k'})

--==============================================================

local extend, define, defineGet, defineSet, is, as, newClass

-- class = newClass( name, class )
local classMt = {
	__call = function(C, ...)
		local instance = {class=C}
		instances[instance] = tostring(instance):match('0x(%w+)')
		setmetatable(instance, C)
		instance:init(...)
		return instance
	end,
	__tostring = function(C)
		return ('class(%s)'):format(C.__name)
	end,
}
function newClass(name, C)
	if (type(name) ~= 'string') then
		error('bad class name type (string expected, got '..type(name)..')', 2)
	end
	if (type(C) ~= 'table') then
		error('bad base table type (table expected, got '..type(C)..')', 2)
	end
	assert(C)
	classes[C] = tostring(C):match('0x(%w+)')
	C.__index = C -- instances uses class as metatable
	C.__name = name
	return setmetatable(C, classMt)
end

-- subClass = class:extend( name, subClass )
function extend(C, name, subC)
	if (type(name) ~= 'string') then
		error('bad class name type (string expected, got '..type(name)..')', 2)
	end
	if (type(subC) ~= 'table') then
		error('bad base table type (table expected, got '..type(subC)..')', 2)
	end
	for k, v in pairs(C) do
		if (subC[k] == nil) then
			subC[k] = v -- subclasses do NOT use superclasses as metatables
		end
	end
	subC.super = C
	return newClass(name, subC)
end

-- class:define( name [, getter=true, setter=true ] )
-- getter/setter: function or boolean
function define(C, k, get, set)
	local suffix = k:gsub('^_', ''):gsub('^.', string.upper)
	if (get ~= false) then
		C['get'..suffix] = (type(get) == 'function' and get or function(self)
			return self[k]
		end)
	end
	if (set ~= false) then
		C['set'..suffix] = (type(set) == 'function' and set or function(self, v)
			self[k] = v
		end)
	end
end
-- class:defineGet( name [, getter ] )
function defineGet(C, k, get)
	C['get'..k:gsub('^_', ''):gsub('^.', string.upper)] = (get or function(self)
		return self[k]
	end)
end
-- class:defineSet( name [, setter ] )
function defineSet(C, k, set)
	C['set'..k:gsub('^_', ''):gsub('^.', string.upper)] = (set or function(self, v)
		self[k] = v
	end)
end

-- result = instance:is( class )
-- result = instance:is( classPath )
-- result = class:is( class )
-- result = class:is( classPath )
function is(obj, C)
	if (type(C) == 'string') then
		C = require(C)
	end
	local currentClass = (classes[obj] and obj or obj.class)
	repeat
		if (currentClass == C) then
			return true
		end
		currentClass = currentClass.super
	until (not currentClass)
	return false
end
-- instance = instance:as( class )
-- instance = instance:as( classPath )
function as(instance, C)
	return (is(instance, C) and instance or nil)
end

--==============================================================

local BaseClass = newClass('Class', {
	__tostring = function(instance)
		return ('%s(%s)'):format(instance.class.__name, instances[instance])
	end,
	extend = extend,
	define = define, defineGet = defineGet, defineSet = defineSet,
	is = is, as = as,
	init = function()end,
})

return function(...)
	return BaseClass:extend(...)
end

--==============================================================
