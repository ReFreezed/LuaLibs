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
	connectToServer, disconnectFromServer, hasServer, isConnectedToServer, isConnectingToServer
	sendToServer
	getServerPing

	getMaxPeers, setMaxPeers
	getPort, setPort, isPortValid
	getServerIp, setServerIp
	stop, isActive

--============================================================]]



local enet = require('enet') -- (LÖVE)
local json = require((('.'..(...)):gsub('%.init$', ''):gsub('%.%w+%.%w+%.%w+$', '')..'.rxi.json'):gsub('^%.+', '')) -- (grandparent folder)

local network = {

	DEFAULT_SERVER_IP = '127.0.0.1',
	MIN_PORT = 1024, MAX_PORT = 65535,

	-- Settings
	_maxPeers = 64,
	_serverIp = '127.0.0.1', _port = 0,

	_connectedClients = {},
	_host = nil,
	_isConnectedToServer = false, _isTryingToConnectToServer = false, _serverPeer = nil,
	_isServer = false, _isClient = false,

	-- Event callbacks
	onClientAdded = nil, -- function( clientId )
	onClientRemoved = nil, -- function( clientId )
	onReceiveMessage = nil, -- function( data [, clientId ] )
	onReceiveMessageFromClient = nil, -- function( data, clientId )
	onReceiveMessageFromServer = nil, -- function( data )
	onServerConnect = nil, -- function( )
	onServerDisconnect = nil, -- function( )
	onAbortServerConnect = nil, -- function( )

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



-- disconnectClientAtIndex( index [, when, code=0 ] )
-- when: "now"|"later"|nil
function disconnectClientAtIndex(i, when, code)
	local client = network._connectedClients[i]
		or error('bad client peer index '..tostring(i))
	local peer = client.peer
	local method = peer['disconnect'..(when and '_'..when or '')]
		or error('bad "when" argument '..tostring(when))
	printf('Disconnecting client %s (%d)', client.address, (code or 0))
	method(peer, (code or 0))
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
	return (#dataStr > 100 and dataStr:sub(1, 70)..'...'..dataStr:sub(#dataStr-30) or dataStr)
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
	local hostType = (network._isServer and 'server') or (network._isClient and 'client') or 'network'
	local timeStr = os.date('%H:%M:%S')
	print(('[%s@%s] %s'):format(hostType, timeStr, s:format(...)))
end
network._printf = printf -- expose to network module extensions



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
network._trigger = trigger -- expose to network module extensions



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
				network._isTryingToConnectToServer = false
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
				if not (network._isConnectedToServer or network._isTryingToConnectToServer) then
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
			if (err) then
				printf('Error: Could not decode message from %s: %s', tostring(peer), err)
			else

				if (network._isServer) then
					local cid = peer:connect_id()
					trigger('onReceiveMessageFromClient', data, cid)
					trigger('onReceiveMessage', data, cid)

				elseif (network._isClient) then
					trigger('onReceiveMessageFromServer', data)
					trigger('onReceiveMessage', data, nil)
				end
			end

		end
		-- void
	end
end



--==============================================================



-- success, errorMessage = startServer( )
function network.startServer()
	if (network._isServer) then
		return false, 'we are already a server'
	elseif (network._host) then
		return false, 'host already created'
	elseif (network._port == 0) then
		return false, 'port has not been set'
	end
	printf('Starting server...')
	-- Note: Trying to start two servers on the same host results in failure here
	local host, err = enet.host_create('*:'..network._port, network._maxPeers)
	if (not host) then
		printf('Could not create host - server start aborted')
		return false, err
	end
	network._host = host
	network._isServer = true
	printf('Server started')
	return true
end

-- success, errorMessage = stopServer( [ code=0 ] )
function network.stopServer(code)
	assert(code == nil or type(code) == 'number')
	if (not network._isServer) then
		return false, 'we are not a server'
	end
	printf('Stopping server...')

	-- Disconnect all clients
	for i = #network._connectedClients, 1, -1 do
		disconnectClientAtIndex(i, nil, (code or 0))
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



-- success, errorMessage = sendToClient( clientId, data [, channel=1, flag="reliable" ] )
function network.sendToClient(cid, data)
	-- assert(type(cid) == 'number')
	if (not network._isServer) then
		return false, 'we are not a server'
	end
	local encodedData, err = encode(data)
	if (not encodedData) then
		return false, err
	end
	local client = itemWith(network._connectedClients, 'id', cid)
	if (not client) then
		return false, 'no client with ID '..tostring(cid)
	end
	printf('Sending message to client %s: %s', client.address, getDataStringSummary(encodedData))
	client.peer:send(encodedData, (channel or 1)-1, flag)
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



-- success, errorMessage = disconnectClient( clientId [, code=0 ] )
function network.disconnectClient(cid, code)
	-- assert(type(cid) == 'number')
	assert(code == nil or type(code) == 'number')
	if (not network._isServer) then
		return false, 'we are not a server'
	end
	local client, i = itemWith(network._connectedClients, 'id', cid)
	if (not client) then
		return false, 'no client with ID '..tostring(cid)
	end
	disconnectClientAtIndex(i, nil, (code or 0))
	return true
end

-- success, errorMessage = kickClient( clientId, data [, code=0 ] )
function network.kickClient(cid, data, code)
	-- assert(type(cid) == 'number')
	assert(code == nil or type(code) == 'number')
	if (not network._isServer) then
		return false, 'we are not a server'
	end
	local encodedData, err = encode(data)
	if (not encodedData) then
		return false, err
	end
	local client, i = itemWith(network._connectedClients, 'id', cid)
	if (not client) then
		return false, 'no client with ID '..tostring(cid)
	end
	printf('Queuing disconnection of client %s (%d) with message: %s',
		client.address, (code or 0), getDataStringSummary(encodedData))
	client.peer:send(encodedData)
	disconnectClientAtIndex(i, 'later', (code or 0)) -- "later" needed for message to arrive
	network._host:flush()
	return true
end



-- ping, errorMessage = getClientPing( clientId )
-- ping: Delay in seconds
function network.getClientPing(cid)
	-- assert(type(cid) == 'number')
	if (not network._isServer) then
		return nil, 'we are not a server'
	end
	local client = itemWith(network._connectedClients, 'id', cid)
	if (not client) then
		return nil, 'no client with ID '..tostring(cid)
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
	local host, err = enet.host_create()
	if (not host) then
		printf('Could not create host - client start aborted')
		return false, err
	end
	network._host = host
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
	elseif (network._isConnectedToServer) then
		return false, 'already connected to server'
	elseif (network._serverPeer) then
		return false, 'already connecting to server'
	elseif (network._port == 0) then
		return false, 'port has not been set'
	end
	printf('Connecting to server...')
	network._serverPeer = assert(network._host:connect(network._serverIp..':'..network._port))
	network._isTryingToConnectToServer = true
	printf('Target server: %s', tostring(network._serverPeer))
	return true
end

-- success, errorMessage = network.disconnectFromServer( [ code=0 ] )
function network.disconnectFromServer(code)
	assert(code == nil or type(code) == 'number')
	if (not network._isClient) then
		return false, 'we are not a client'
	elseif (not network._serverPeer) then
		return false, 'not connected to any server'
	end
	printf('Disconnecting from server...')
	local wasConnectedToServer = network._isConnectedToServer
	network._serverPeer:disconnect_now(code or 0) -- TODO: Figure out how to use disconnect+flush instead of disconnect_now
	-- network._host:flush()
	network._isConnectedToServer = false
	network._isTryingToConnectToServer = false
	network._serverPeer = nil
	trigger(wasConnectedToServer and 'onServerDisconnect' or 'onAbortServerConnect')
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

-- state = isConnectingToServer( )
function network.isConnectingToServer()
	return (network.hasServer() and not network.isConnectedToServer())
end



-- success, errorMessage = sendToServer( data [, channel=1, flag="reliable" ] )
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
	network._serverPeer:send(encodedData, (channel or 1)-1, flag)
	return true
end



-- ping, errorMessage = getServerPing( )
-- ping: Delay in seconds
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
	assert(network.isPortValid(port))
	if (network._isServer) or (network._isClient and network._serverPeer) then
		printf('WARNING: Port changed while being a server or a connected client')
	end
	network._port = port
end

-- result = isPortValid( port )
function network.isPortValid(port)
	return (type(port) == 'number' and port >= network.MIN_PORT and port <= network.MAX_PORT)
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



-- success, errorMessage = stop( )
function network.stop()
	if (network._isServer) then
		return network.stopServer()
	elseif (network._isClient) then
		return network.stopClient()
	end
	return false, 'network is not active'
end

-- state = isActive( )
function network.isActive()
	return (network._host ~= nil)
end



--==============================================================
--==============================================================
--==============================================================

return network
