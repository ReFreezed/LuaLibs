--[[============================================================
--=
--=  Enum class
--=
--=  Dependencies:
--=  - refreezed.class
--=
--=-------------------------------------------------------------
--=
--=  This file is in the public domain.
--=
--==============================================================

	check, checkNumber
	getNumber, getState
	has, hasNumber
	states, numbers

--==============================================================

	local newEnum = require("refreezed.Enum")

	local elements = newEnum "ElementsEnum" {"fire","water","air","earth"}

	if (elements:has("fire")) then
		print("Fire is an element.")
	end
	if (not elements:has("snake")) then
		print("Snake is not an element.")
	end

--============================================================]]

local Enum = require((...):gsub('%.init$', ''):gsub('%.%w+$', '')..'.class')('Enum', {
	_name = nil,
	_numbers = nil, _numberValues = nil,
	_states = nil, _stateValues = nil,
})

--==============================================================

-- Enum( name )( table )
function Enum:init(name, t)
	if (type(name) ~= 'string') then
		error("bad argument #1 to 'Enum' (string expected, got "..type(name)..")", 3)
	end
	if (type(t) ~= 'table') then
		error("bad argument #2 to 'Enum' (table expected, got "..type(t)..")", 3)
	end
	local numbers, numberValues = {}, {}
	local states,  stateValues  = {}, {}
	local insert = table.insert
	for n, state in pairs(t) do
		if (type(n) ~= 'number') then
			error('enum keys must be numbers', 3)
		end
		if (type(state) == 'number') then
			error('enum states cannot be numbers', 3)
		end
		numbers[state] = n
		states[n] = state
		insert(stateValues, state)
		insert(numberValues, n)
	end
	table.sort(numberValues)
	table.sort(stateValues, function(a, b)
		return (tostring(a) < tostring(b))
	end)
	self._numbers, self._numberValues = numbers, numberValues
	self._states,  self._stateValues  = states,  stateValues
	self._name = name
end

-- Trigger an error if a state doesn't exist in the enum
-- state = check( state )
function Enum:check(state)
	if (not self:has(state)) then
		error('bad enum state '..tostring(self._name)..'.'..tostring(state))
	end
	return state
end
-- Trigger an error if a number doesn't exist in the enum
-- number = checkNumber( number )
function Enum:checkNumber(n)
	if (not self:hasNumber(n)) then
		error('bad enum number '..n..' for '..tostring(self._name))
	end
	return n
end

-- number = getNumber( state )
function Enum:getNumber(state)
	return self._numbers[state]
end
-- state = getState( number )
function Enum:getState(n)
	return self._states[n]
end

-- result = has( state )
function Enum:has(state)
	return (self._numbers[state] ~= nil)
end
-- result = hasNumber( number )
function Enum:hasNumber(n)
	return (self._states[n] ~= nil)
end

-- for index, state in states( ) do
function Enum:states()
	return ipairs(self._stateValues)
end
-- for index, number in numbers( ) do
function Enum:numbers()
	return ipairs(self._numberValues)
end

--==============================================================

do
	local enumName
	local function newEnum(t)
		return Enum(enumName, t)
	end
	return function(name)
		enumName = name
		return newEnum
	end
end
