--[[============================================================
--=
--=  Network module
--=
--=  Dependencies:
--=  - LÖVE 0.9.0
--=  - rxi.json
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

	startServer, stopServer, isServer
	getClient, getClientCount
	sendToClient, broadcast
	disconnectClient, kickClient
	getClientPing

	startClient, stopClient, isClient
	connectToServer, disconnectFromServer, hasServer, isConnectedToServer
	sendToServer
	getServerPing

	getMaxPeers, setMaxPeers
	getPort, setPort
	getServerIp, setServerIp
	stop, isActive

--============================================================]]



local enet = require('enet') -- (LÖVE)
local json = require(((('.'..(...)):gsub('%.init$', ''):gsub('%.%w+%.%w+%.%w+$', '')..'.rxi.json'):gsub('^%.+', ''))) -- (grandparent folder)

local network = {

	-- Settings
	_maxPeers = 64,
	_serverIp = 'localhost', _port = 0,

	_connectedClients = {},
	_host = nil,
	_isConnectedToServer = false, _serverPeer = nil,
	_isServer = false, _isClient = false,

	-- Event callbacks
	onClientAdded = nil, -- function( clientId )
	onClientRemoved = nil, -- function( clientId )
	onReceiveClientMessage = nil, -- function( data, clientId )
	onReceiveMessage = nil, -- function( data [, clientId ] )
	onReceiveServerMessage = nil, -- function( data )
	onServerConnect = nil, -- function( )
	onServerDisconnect = nil, -- function( )

}



--==============================================================
--==============================================================
--==============================================================

local coroutineIterator, newIteratorCoroutine
local disconnectClientAtIndex, forgetClientAtIndex
local encode, decode
local getDataStringSummary
local itemWith
local printf
local traversePeers
local trigger



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



-- disconnectClientAtIndex( index [, when, code ] )
-- when: "now"|"later"|nil
function disconnectClientAtIndex(i, when, ...)
	local client = network._connectedClients[i]
		or error('bad client peer index '..tostring(i))
	local peer = client.peer
	local method = peer['disconnect'..(when and '_'..when or '')]
		or error('bad "when" argument '..tostring(when))
	printf('Disconnecting client %s (%d)', client.address, (... or 0))
	method(peer, ...)
	forgetClientAtIndex(i)
end

-- forgetClientAtIndex( index )
function forgetClientAtIndex(i)
	local client = table.remove(network._connectedClients, i)
	if (client) then
		trigger('onClientRemoved', client.id)
	end
end



-- encodedData, errorMessage = encode( data )
function encode(data)
	local ok, encodedDataOrErr = pcall(json.encode, data)
	if (not ok) then
		return nil, encodedDataOrErr
	end
	return encodedDataOrErr
end

-- data, errorMessage = decode( encodedData )
function decode(encodedData)
	local ok, dataOrErr = pcall(json.decode, encodedData)
	if (not ok) then
		return nil, dataOrErr
	end
	return dataOrErr
end



-- shortMessage = getDataStringSummary( dataStr )
function getDataStringSummary(dataStr)
	dataStr = dataStr:gsub('\r?\n', ' ')
	return (#dataStr > 100-3 and dataStr:sub(1, 100-3)..'...' or dataStr)
end



-- item, index = itemWith( table, key, value )
function itemWith(t, k, v)
	for i, item in ipairs(t) do
		if (item[k] == v) then
			return item, i
		end
	end
	return nil
end



-- printf( formatString, ... )
function printf(s, ...)
	local hostType = (network._isServer and '.server') or (network._isClient and '.client') or ''
	print('[network'..hostType..'] '..s:format(...))
end



-- for index, peer in traversePeers( host ) do
do
	local function traverse(host)
		for i = 1, host:peer_count() do
			local peer = host:get_peer(i)
			coroutine.yield(i, peer)
		end
	end
	function traversePeers(host)
		return newIteratorCoroutine(traverse, host)
	end
end



-- ... = trigger( eventPropertyName, ... )
function trigger(k, ...)
	local cb = network[k]
	if (not cb) then
		return nil
	end
	return cb(...)
end



--==============================================================
--==============================================================
--==============================================================



-- update( )
function network.update()
	if (not network.isActive()) then
		return
	end
	while true do
		local e = nil
		if not (network._isClient and not network._serverPeer) then
			-- As a client we must be connected or else host.service will throw an error!
			e = network._host:service()
		end
		if (not e) then
			break
		end
		local eType, peer = e.type, e.peer

		-- Connect
		if (eType == 'connect') then
			local code = e.data

			if (network._isServer) then
				local client = {
					id = peer:connect_id(),
					peer = peer,
					address = tostring(peer),
				}
				printf('Event: Client connected: %s (%d)', client.address, code)
				table.insert(network._connectedClients, client)
				trigger('onClientAdded', client.id)

			elseif (network._isClient) then
				printf('Event: Connected to server: %s (%d)', tostring(network._serverPeer), code)
				network._isConnectedToServer = true
				trigger('onServerConnect')
			end

		-- Disconnect
		elseif (eType == 'disconnect') then
			local code = e.data

			if (network._isServer) then
				printf('Event: Client disconnected: %s (%d)', tostring(peer), code)
				local client, i = itemWith(network._connectedClients, 'peer', peer)
				if (client) then
					forgetClientAtIndex(i)
				end

			elseif (network._isClient) then
				if (not network._isConnectedToServer) then
					printf('WARNING: Non-server peer disconnected: %s (%d)', tostring(peer), code)
				else
					printf('Event: Server disconnected: %s (%d)', tostring(peer), code)
					network.disconnectFromServer()
				end
			end

		-- Receive
		elseif (eType == 'receive') then
			local encodedData = e.data
			printf('Event: Got message from %s: %s', tostring(peer), getDataStringSummary(encodedData))
			local data, err = decode(encodedData)
			if (not data) then
				printf('Error: Could not decode message from %s: %s', tostring(peer), err)
			else

				if (network._isServer) then
					local id = peer:connect_id()
					trigger('onReceiveClientMessage', data, id)
					trigger('onReceiveMessage', data, id)

				elseif (network._isClient) then
					trigger('onReceiveServerMessage', data)
					trigger('onReceiveMessage', data, nil)
				end
			end

		end
	end
end



--==============================================================



-- success, errorMessage = startServer( )
function network.startServer()
	if (network._isServer) then
		return false, 'we are already a server'
	elseif (network._host) then
		return false, 'host already created'
	end
	local port = network._port
	if (port == 0) then
		return false, 'port has not been set'
	end
	printf('Starting server...')
	-- Note: Trying to start two servers on the same host results in failure here
	local host, err = enet.host_create('*:'..port, network._maxPeers)
	if (not host) then
		printf('Could not create host - server start aborted')
		return false, err
	end
	network._host = host
	network._isServer = true
	printf('Server started')
	return true
end

-- success, errorMessage = stopServer( [ code ] )
function network.stopServer(...)
	assert(... == nil or type(...) == 'number')
	if (not network._isServer) then
		return false, 'we are not a server'
	end
	printf('Stopping server...')

	-- Disconnect all clients
	for i = #network._connectedClients, 1, -1 do
		disconnectClientAtIndex(i, nil, ...)
	end
	network._host:flush() -- (probably not needed since all clients are disconnected already)

	network._host:destroy()
	network._host = nil
	network._isServer = false

	printf('Server stopped')
	return true
end

-- state = isServer( )
function network.isServer()
	return network._isServer
end



-- clientId, errorMessage = getClient( index )
function network.getClient(i)
	assert(type(i) == 'number')
	if (not network._isServer) then
		return nil, 'we are not a server'
	end
	local client = network._connectedClients[i]
	if (not client) then
		return nil, 'index out of bounds'
	end
	return client.id
end

-- count, errorMessage = getClientCount( )
function network.getClientCount()
	if (not network._isServer) then
		return nil, 'we are not a server'
	end
	return #network._connectedClients
end



-- success, errorMessage = sendToClient( clientId, data )
function network.sendToClient(id, data)
	-- assert(type(id) == 'number')
	if (not network._isServer) then
		return false, 'we are not a server'
	end
	local encodedData, err = encode(data)
	if (not encodedData) then
		return false, err
	end
	local client = itemWith(network._connectedClients, 'id', id)
	if (not client) then
		return false, 'no client with id '..tostring(id)
	end
	printf('Sending message to client %s: %s', client.address, getDataStringSummary(encodedData))
	client.peer:send(encodedData)
	return true
end

-- success, errorMessage = broadcast( data )
function network.broadcast(data)
	if (not network._isServer) then
		return false, 'we are not a server'
	elseif (not network._connectedClients[1]) then
		return false, 'no clients to broadcast to'
	end
	local encodedData, err = encode(data)
	if (not encodedData) then
		return false, err
	end
	printf('Broadcasting message: %s', getDataStringSummary(encodedData))
	network._host:broadcast(encodedData)
	return true
end



-- success, errorMessage = disconnectClient( clientId [, code ] )
function network.disconnectClient(id, ...)
	-- assert(type(id) == 'number')
	assert(... == nil or type(...) == 'number')
	if (not network._isServer) then
		return false, 'we are not a server'
	end
	local client, i = itemWith(network._connectedClients, 'id', id)
	if (not client) then
		return false, 'no client with id '..tostring(id)
	end
	disconnectClientAtIndex(i, nil, ...)
	return true
end

-- success, errorMessage = kickClient( clientId, data [, code ] )
function network.kickClient(id, data, ...)
	-- assert(type(id) == 'number')
	assert(... == nil or type(...) == 'number')
	if (not network._isServer) then
		return false, 'we are not a server'
	end
	local encodedData, err = encode(data)
	if (not encodedData) then
		return false, err
	end
	local client, i = itemWith(network._connectedClients, 'id', id)
	if (not client) then
		return false, 'no client with id '..tostring(id)
	end
	printf('Queuing disconnection of client %s (%d) with message: %s',
		client.address, (... or 0), getDataStringSummary(encodedData))
	client.peer:send(encodedData)
	disconnectClientAtIndex(i, 'later', ...) -- "later" needed for message to arrive
	network._host:flush()
	return true
end



-- delay, errorMessage = getClientPing( clientId )
function network.getClientPing(id)
	-- assert(type(id) == 'number')
	if (not network._isServer) then
		return nil, 'we are not a server'
	end
	local client = itemWith(network._connectedClients, 'id', id)
	if (not client) then
		return nil, 'no client with id '..tostring(id)
	end
	return client.peer:last_round_trip_time()*0.001
end



--==============================================================



-- success, errorMessage = startClient( )
function network.startClient()
	if (network._isClient) then
		return false, 'we are already a client'
	elseif (network._host) then
		return false, 'host already created'
	end
	printf('Starting client...')
	network._host = enet.host_create()
	network._isClient = true
	printf('Client started')
	return true
end

-- success, errorMessage = stopClient( )
function network.stopClient()
	if (not network._isClient) then
		return false, 'we are not a client'
	end
	printf('Stopping client...')
	network.disconnectFromServer()
	network._host:destroy()
	network._host = nil
	network._isClient = false
	printf('Client stopped')
	return true
end

-- state = isClient( )
function network.isClient()
	return network._isClient
end



-- success, errorMessage = network.connectToServer( )
function network.connectToServer()
	if (not network._isClient) then
		return false, 'we are not a client'
	elseif (network._serverPeer) then
		return false, 'already connected to server'
	end
	local port = network._port
	if (port == 0) then
		return false, 'port has not been set'
	end
	printf('Connecting to server...')
	network._serverPeer = assert(network._host:connect(network._serverIp..':'..port))
	printf('Target server: %s', tostring(network._serverPeer))
	return true
end

-- success, errorMessage = network.disconnectFromServer( [ code ] )
function network.disconnectFromServer(...)
	assert(... == nil or type(...) == 'number')
	if (not network._isClient) then
		return false, 'we are not a client'
	elseif (not network._serverPeer) then
		return false, 'not connected to any server'
	end
	printf('Disconnecting from server...')
	network._serverPeer:disconnect_now(...) -- TODO: Figure out how to use disconnect+flush instead of disconnect_now
	-- network._host:flush()
	if (network._isConnectedToServer) then
		trigger('onServerDisconnect')
	end
	network._isConnectedToServer = false
	network._serverPeer = nil
	printf('Disconnected from server')
	return true
end

-- state = hasServer( )
function network.hasServer()
	return (network._serverPeer ~= nil)
end

-- state = isConnectedToServer( )
function network.isConnectedToServer()
	return network._isConnectedToServer
end



-- success, errorMessage = sendToServer( data )
function network.sendToServer(data)
	if (not network._isClient) then
		return false, 'we are not a client'
	elseif (not network._isConnectedToServer) then
		return false, 'client is not connected to any server'
	end
	local encodedData, err = encode(data)
	if (not encodedData) then
		return nil, err
	end
	printf('Sending message to server: %s', getDataStringSummary(encodedData))
	network._serverPeer:send(encodedData)
	return true
end



-- delay, errorMessage = getServerPing( )
function network.getServerPing()
	if (not network._isClient) then
		return nil, 'we are not a client'
	elseif (not network._isConnectedToServer) then
		return nil, 'client is not connected to any server'
	end
	return network._serverPeer:last_round_trip_time()*0.001
end



--==============================================================



-- count = getMaxPeers( )
function network.getMaxPeers()
	return network._maxPeers
end

-- setMaxPeers( count )
function network.setMaxPeers(count)
	assert(type(count) == 'number' and count >= 0)
	if (network._isServer) then
		printf('WARNING: Max peers changed while being a server')
	end
	network._maxPeers = count
end



-- port = getPort( )
function network.getPort()
	return network._port
end

-- setPort( port )
function network.setPort(port)
	assert(type(port) == 'number' and port >= 1024 and port <= 65535)
	if (network._isServer) or (network._isClient and network._serverPeer) then
		printf('WARNING: Port changed while being a server or a connected client')
	end
	network._port = port
end



-- ip = getServerIp( )
function network.getServerIp()
	return network._serverIp
end

-- setServerIp( ip )
-- ip: Can be e.g. "localhost"
function network.setServerIp(ip)
	assert(type(ip) == 'string' and ip ~= '')
	if (network._isClient and network._serverPeer) then
		printf('WARNING: Server IP changed while being a connected client')
	end
	network._serverIp = ip
end



-- stop( )
function network.stop()
	if (network._isServer) then
		network.stopServer()
	elseif (network._isClient) then
		network.stopClient()
	end
end

-- state = isActive( )
function network.isActive()
	return (network._host ~= nil)
end



--==============================================================
--==============================================================
--==============================================================

return network
