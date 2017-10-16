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

	Info

	All peers have a connection ID, and in the case of clients,
	their connection IDs are called client IDs in this module.

--==============================================================

	update

	-- Server
	startServer, stopServer, isServer
	getClient, getClientCount
	sendToClient, broadcast
	disconnectClient, kickClient
	getClientPing

	-- Client
	startClient, stopClient, isClient
	connectToServer, disconnectFromServer, hasServer, isConnectedToServer, isConnectingToServer
	sendToServer
	getServerConnectId
	getServerPing

	-- Both server and client
	collectInfo, getIncomingBandwidth, getOutgoingBandwidth
	getLogLevel, setLogLevel, isLogLevel, isLogging
	getMaxPeers, setMaxPeers
	getPort, setPort, isPortValid
	getServerIp, setServerIp
	stop, isActive

	-- Utils
	formatBytes, formatBits, formatSpeed

--============================================================]]



local enet   = require('enet') -- (LÖVE)
local socket = require('socket') -- (LÖVE)
local json   = require((('.'..(...)):gsub('%.init$', ''):gsub('%.%w+%.%w+%.%w+$', '')..'.rxi.json'):gsub('^%.+', '')) -- (grandparent folder)

local network = {
	_VERSION = 1,

	-- Contstants
	DEFAULT_LOG_LEVEL = 'events',
	DEFAULT_SERVER_IP = '127.0.0.1',
	MIN_PORT = 1024, MAX_PORT = 65535,

	-- Settings
	_isCollectingInfo = false,
	_logLevel = 3,
	_maxPeers = 64,
	_serverIp = '127.0.0.1', _port = 0,

	-- Variables
	_connectedClients = {},
	_host = nil,
	_isConnectedToServer = false, _isTryingToConnectToServer = false, _serverPeer = nil,
	_isServer = false, _isClient = false,
	_peerInfos = {},

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

local logLevelCodes, logLevels = {}, {
	[5] = 'all',
	[4] = 'messages', -- same as all
	[3] = 'events', -- all except messages (default)
	[2] = 'state', -- server/client start/stop
	[1] = 'important', -- errors and warnings
	[0] = 'none',
}
for levelCode, level in pairs(logLevels) do
	logLevelCodes[level] = levelCode
end



--==============================================================
--==============================================================
--==============================================================

local coroutineIterator, newIteratorCoroutine
local disconnectClientAtIndex, forgetClientAtIndex
local encode, decode
local getDataStringSummary
local getPeerInfo
local ipairsr
local itemWith
local printf, log
local sendToPeer
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
	log('events', 'Disconnecting client %s (%d)', client.address, (code or 0))
	method(peer, (code or 0))
	forgetClientAtIndex(i)
end

-- forgetClientAtIndex( index )
function forgetClientAtIndex(i)
	local client = table.remove(network._connectedClients, i)
	if client then
		trigger('onClientRemoved', client.id)
	end
end



-- encodedData, errorMessage = encode( data )
function encode(data)
	local ok, encodedDataOrErr = pcall(json.encode, data)
	if not ok then
		return nil, encodedDataOrErr
	end
	return encodedDataOrErr
end

-- data, errorMessage = decode( encodedData )
function decode(encodedData)
	local ok, dataOrErr = pcall(json.decode, encodedData)
	if not ok then
		return nil, dataOrErr
	end
	return dataOrErr
end



-- shortMessage = getDataStringSummary( dataStr )
function getDataStringSummary(dataStr)
	dataStr = dataStr:gsub('\r?\n', ' ')
	return (#dataStr > 200 and dataStr:sub(1, 150)..' ... '..dataStr:sub(#dataStr-50) or dataStr)
end



-- info = getPeerInfo( clientId [, onlyGetExisting=false ] )
function getPeerInfo(cid, onlyGetExisting)
	local infos = network._peerInfos
	local info = infos[cid]
	if (not info and not onlyGetExisting) then
		info = {
			totalReceiveCount = 0,
			totalSendCount    = 0,
			recentReceived = {--[[ {time=timestamp, amount=dataLength}... ]]},
			recentSent     = {--[[ {time=timestamp, amount=dataLength}... ]]},
		}
		infos[cid] = info
	end
	return info
end



-- for index, item in ipairsr( table ) do
do
	local function iprev(t, i)
		i = i-1
		local v = t[i]
		if v ~= nil then  return i, v  end
	end
	function ipairsr(t)
		return iprev, t, #t+1
	end
end



-- item, index = itemWith( table, key, value )
function itemWith(t, k, v)
	for i, item in ipairs(t) do
		if item[k] == v then
			return item, i
		end
	end
	return nil
end



-- printf( formatString, ... )
function printf(s, ...)
	local hostType = (network._isServer and 'server') or (network._isClient and 'client') or 'network'
	local timeStr = os.date('%H:%M:%S')
	s = s:format(...)
	print(('[%s@%s] %s'):format(hostType, timeStr, s))
end
network._printf = printf -- expose to network module extensions

-- log( level, formatString, ... )
function log(level, ...)
	if network._logLevel >= logLevelCodes[level] then
		printf(...)
	end
end
network._log = log -- expose to network module extensions



-- sendToPeer( peer, dataString [, channel=1, flag="reliable" ] )
function sendToPeer(peer, dataStr, channel, flag)
	channel = (channel or 1)-1
	flag = (flag or 'reliable')
	if network._isCollectingInfo then
		local info = getPeerInfo(peer:connect_id())
		info.totalSendCount = info.totalSendCount+1
		table.insert(info.recentSent, {
			time = socket.gettime(),
			amount = #dataStr,
		})
	end
	return peer:send(dataStr, channel, flag)
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
	if not cb then
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
	if not network.isActive() then
		return
	end

	-- Update info.
	local minTime = socket.gettime()-1
	for cid, info in pairs(network._peerInfos) do

		-- Remove old transfer info from recent.
		for _, transferInfos in ipairs{info.recentReceived, info.recentSent} do
			for i, transferInfo in ipairsr(transferInfos) do
				if transferInfo.time < minTime then
					for count = 1, i do
						table.remove(transferInfos, 1)
					end
					break
				end
			end
		end

	end

	-- Handle events.
	while true do
		local host = network._host
		local ok, e = pcall(host.service, host)
		if not ok then
			if e == 'Error during service' then
				-- We get this error e.g. if the host name is "0.0.0.0" or just "0".
				network.disconnectFromServer()
			else
				log('important', 'ERROR: network: %s', e)
			end
			break
		elseif not e then
			break
		end
		local eType, peer = e.type, e.peer

		-- Connect.
		if eType == 'connect' then
			local code = e.data

			if network._isServer then
				local client = {
					id = peer:connect_id(),
					peer = peer,
					address = tostring(peer),
				}
				log('events', 'Event: Client connected: %s (%d)', client.address, code)
				table.insert(network._connectedClients, client)
				trigger('onClientAdded', client.id)

			elseif network._isClient then
				log('events', 'Event: Connected to server: %s (%d)', network._serverPeer, code)
				network._isConnectedToServer = true
				network._isTryingToConnectToServer = false
				trigger('onServerConnect')
			end

		-- Disconnect.
		elseif eType == 'disconnect' then
			local code = e.data

			if network._isServer then
				log('events', 'Event: Client disconnected: %s (%d)', peer, code)
				local client, i = itemWith(network._connectedClients, 'peer', peer)
				if client then
					forgetClientAtIndex(i)
				end

			elseif network._isClient then
				if not (network._isConnectedToServer or network._isTryingToConnectToServer) then
					log('important', 'WARNING: Non-server peer disconnected: %s (%d)', peer, code)
				else
					log('events', 'Event: Server disconnected: %s (%d)', peer, code)
					network.disconnectFromServer()
				end
			end

		-- Receive.
		elseif eType == 'receive' then
			local encodedData = e.data

			-- Log message.
			if network._logLevel >= 4 then
				if network._isClient then
					log('messages', '<< %s', getDataStringSummary(encodedData))
				else
					log('messages', '<< %s %s', peer, getDataStringSummary(encodedData))
				end
			end

			-- Collect info.
			if network._isCollectingInfo then
				local info = getPeerInfo(peer:connect_id())
				info.totalReceiveCount = info.totalReceiveCount+1
				table.insert(info.recentReceived, {
					time = socket.gettime(),
					amount = #encodedData,
				})
			end

			-- Handle data.
			local data, err = decode(encodedData)
			if err then
				log('important', 'ERROR: Could not decode message from %s: %s', peer, err)
			else
				if network._isServer then
					local cid = peer:connect_id()
					trigger('onReceiveMessageFromClient', data, cid)
					trigger('onReceiveMessage', data, cid)
				elseif network._isClient then
					trigger('onReceiveMessageFromServer', data)
					trigger('onReceiveMessage', data, nil)
				end
			end

		end
	end

end



-- Server
--==============================================================



-- success, errorMessage = startServer( )
function network.startServer()
	if network._isServer then
		return false, 'we are already a server'
	elseif network._host then
		return false, 'host already created'
	elseif network._port == 0 then
		return false, 'port has not been set'
	end
	log('state', 'Starting server...')

	-- Note: Trying to start two servers on the same host results in failure here
	local host, err = enet.host_create('*:'..network._port, network._maxPeers)
	if not host then
		log('important', 'ERROR: Could not create host - server start aborted: %s', err)
		return false, err
	end
	network._host = host
	network._isServer = true

	log('state', 'Server started')
	return true
end

-- success, errorMessage = stopServer( [ code=0 ] )
function network.stopServer(code)
	assert(code == nil or type(code) == 'number')
	if not network._isServer then
		return false, 'we are not a server'
	end
	log('state', 'Stopping server...')

	-- Disconnect all clients
	for i = #network._connectedClients, 1, -1 do
		disconnectClientAtIndex(i, nil, (code or 0))
	end
	network._host:flush() -- (probably not needed since all clients are disconnected already)

	network._host:destroy()
	network._host = nil
	network._isServer = false

	log('state', 'Server stopped')
	return true
end

-- state = isServer( )
function network.isServer()
	return network._isServer
end



-- clientId, errorMessage = getClient( index )
function network.getClient(i)
	assert(type(i) == 'number')
	if not network._isServer then
		return nil, 'we are not a server'
	end
	local client = network._connectedClients[i]
	if not client then
		return nil, 'index out of bounds'
	end
	return client.id
end

-- count, errorMessage = getClientCount( )
function network.getClientCount()
	if not network._isServer then
		return nil, 'we are not a server'
	end
	return #network._connectedClients
end



-- success, errorMessage = sendToClient( clientId, data [, channel=1, flag="reliable" ] )
function network.sendToClient(cid, data, channel, flag)
	-- assert(type(cid) == 'number')
	if not network._isServer then
		return false, 'we are not a server'
	end
	local encodedData, err = encode(data)
	if not encodedData then
		return false, err
	end
	local client = itemWith(network._connectedClients, 'id', cid)
	if not client then
		return false, 'no client with ID '..tostring(cid)
	end
	if network._logLevel >= 4 then
		log('messages', '>> %s %s', client.address, getDataStringSummary(encodedData))
	end
	sendToPeer(client.peer, encodedData, channel, flag)
	return true
end

-- success, errorMessage = broadcast( data )
function network.broadcast(data)
	if not network._isServer then
		return false, 'we are not a server'
	elseif not network._connectedClients[1] then
		return false, 'no clients to broadcast to'
	end
	local encodedData, err = encode(data)
	if not encodedData then
		return false, err
	end
	if network._logLevel >= 4 then
		log('messages', '>> %s', getDataStringSummary(encodedData))
	end
	network._host:broadcast(encodedData)
	return true
end



-- success, errorMessage = disconnectClient( clientId [, code=0 ] )
function network.disconnectClient(cid, code)
	-- assert(type(cid) == 'number')
	assert(code == nil or type(code) == 'number')
	if not network._isServer then
		return false, 'we are not a server'
	end
	local client, i = itemWith(network._connectedClients, 'id', cid)
	if not client then
		return false, 'no client with ID '..tostring(cid)
	end
	disconnectClientAtIndex(i, nil, (code or 0))
	return true
end

-- success, errorMessage = kickClient( clientId, data [, code=0 ] )
function network.kickClient(cid, data, code)
	-- assert(type(cid) == 'number')
	assert(code == nil or type(code) == 'number')
	if not network._isServer then
		return false, 'we are not a server'
	end
	local encodedData, err = encode(data)
	if not encodedData then
		return false, err
	end
	local client, i = itemWith(network._connectedClients, 'id', cid)
	if not client then
		return false, 'no client with ID '..tostring(cid)
	end
	if network._logLevel >= 4 then
		log('messages', 'Queuing disconnection of client %s (%d) with message: %s',
			client.address, (code or 0), getDataStringSummary(encodedData))
	else
		log('events', 'Queuing disconnection of client %s (%d)', client.address, (code or 0))
	end
	sendToPeer(client.peer, encodedData)
	disconnectClientAtIndex(i, 'later', (code or 0)) -- "later" needed for message to arrive
	network._host:flush()
	return true
end



-- ping, errorMessage = getClientPing( clientId )
function network.getClientPing(cid)
	-- assert(type(cid) == 'number')
	if not network._isServer then
		return nil, 'we are not a server'
	end
	local client = itemWith(network._connectedClients, 'id', cid)
	if not client then
		return nil, 'no client with ID '..tostring(cid)
	end
	return client.peer:round_trip_time()*0.001
end



-- Client
--==============================================================



-- success, errorMessage = startClient( )
function network.startClient()
	if network._isClient then
		return false, 'we are already a client'
	elseif network._host then
		return false, 'host already created'
	end
	log('state', 'Starting client...')

	local host, err = enet.host_create()
	if not host then
		log('important', 'ERROR: Could not create host - client start aborted: %s', err)
		return false, err
	end
	network._host = host
	network._isClient = true

	log('state', 'Client started')
	return true
end

-- success, errorMessage = stopClient( )
function network.stopClient()
	if not network._isClient then
		return false, 'we are not a client'
	end
	log('state', 'Stopping client...')

	network.disconnectFromServer()

	network._host:destroy()
	network._host = nil
	network._isClient = false

	log('state', 'Client stopped')
	return true
end

-- state = isClient( )
function network.isClient()
	return network._isClient
end



-- success, errorMessage = network.connectToServer( )
function network.connectToServer()
	if not network._isClient then
		return false, 'we are not a client'
	elseif network._isConnectedToServer then
		return false, 'already connected to server'
	elseif network._serverPeer then
		return false, 'already connecting to server'
	elseif network._port == 0 then
		return false, 'port has not been set'
	end

	local host = network._host
	local ok, peer = pcall(host.connect, host, network._serverIp:gsub(':.*$', '')..':'..network._port)
	if not ok then
		return false, peer -- Server IP is probably malformed.
	end
	network._serverPeer = peer
	network._isTryingToConnectToServer = true

	log('state', 'Connecting to server (%s)...', network._serverPeer)
	return true
end

-- success, errorMessage = network.disconnectFromServer( [ code=0 ] )
function network.disconnectFromServer(code)
	assert(code == nil or type(code) == 'number')
	if not network._isClient then
		return false, 'we are not a client'
	elseif not network._serverPeer then
		return false, 'not connected to any server'
	end
	log('state', 'Disconnecting from server...')

	local wasConnectedToServer = network._isConnectedToServer

	network._serverPeer:disconnect_now(code or 0) -- TODO: Figure out how to use disconnect+flush instead of disconnect_now
	-- network._host:flush()

	network._isConnectedToServer = false
	network._isTryingToConnectToServer = false
	network._serverPeer = nil

	trigger(wasConnectedToServer and 'onServerDisconnect' or 'onAbortServerConnect')

	log('state', 'Disconnected from server')
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
function network.sendToServer(data, channel, flag)
	if not network._isClient then
		return false, 'we are not a client'
	elseif not network._isConnectedToServer then
		return false, 'client is not connected to any server'
	end
	local encodedData, err = encode(data)
	if not encodedData then
		return nil, err
	end
	if network._logLevel >= 4 then
		log('messages', '>> %s', getDataStringSummary(encodedData))
	end
	sendToPeer(network._serverPeer, encodedData, channel, flag)
	return true
end



-- connectId = getServerConnectId( )
-- connectId: Will be nil if we're not connected/connecting.
function network.getServerConnectId()
	local peer = network._serverPeer
	return (peer and peer:connect_id())
end



-- ping, errorMessage = getServerPing( )
function network.getServerPing()
	if not network._isClient then
		return nil, 'we are not a client'
	elseif not network._isConnectedToServer then
		return nil, 'client is not connected to any server'
	end
	return network._serverPeer:round_trip_time()*0.001
end



-- Both server and client
--==============================================================



-- collectInfo( state )
function network.collectInfo(state)
	network._isCollectingInfo = state
	if not state then
		network._peerInfos = {} -- Remove existing info.
	end
end

-- speed = getIncomingBandwidth( [ connectId=all ] )
-- speed: Bits per second.
function network.getIncomingBandwidth(cid)
	local amount = 0
	if cid then
		local info = getPeerInfo(cid, true)
		if not info then
			return 0
		end
		for _, transferInfo in ipairsr(info.recentReceived) do
			amount = amount+transferInfo.amount
		end
	else
		for cid, info in pairs(network._peerInfos) do
			for _, transferInfo in ipairsr(info.recentReceived) do
				amount = amount+transferInfo.amount
			end
		end
	end
	return amount*8 -- Convert bytes to bits.
end

-- speed = getOutgoingBandwidth( [ connectId=all ] )
-- speed: Bits per second.
function network.getOutgoingBandwidth(cid)
	local amount = 0
	if cid then
		local info = getPeerInfo(cid, true)
		if not info then
			return 0
		end
		for _, transferInfo in ipairsr(info.recentSent) do
			amount = amount+transferInfo.amount
		end
	else
		for cid, info in pairs(network._peerInfos) do
			for _, transferInfo in ipairsr(info.recentSent) do
				amount = amount+transferInfo.amount
			end
		end
	end
	return amount*8 -- Convert bytes to bits.
end



-- level = getLogLevel( )
function network.getLogLevel()
	return logLevels[network._logLevel]
end

-- success, errorMessage = setLogLevel( level )
function network.setLogLevel(level)
	local levelCode = logLevelCodes[level]
	if not levelCode then
		return false, 'bad logging level '..tostring(level)
	end
	network._logLevel = levelCode
	return true
end

-- state = isLogLevel( level )
function network.isLogLevel(level)
	return (network._logLevel == logLevelCodes[level])
end

-- state = isLogging( [ level=any ] )
function network.isLogging(level)
	local levelCode = (not level and 1)
		or logLevelCodes[level]
		or error('bad logging level '..tostring(level))
	return (network._logLevel >= levelCode)
end



-- count = getMaxPeers( )
function network.getMaxPeers()
	return network._maxPeers
end

-- setMaxPeers( count )
function network.setMaxPeers(count)
	assert(type(count) == 'number' and count >= 0)
	if network._isServer then
		log('important', 'WARNING: Max peers changed while being a server')
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
		log('important', 'WARNING: Port changed while being a server or a connected client')
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
		log('important', 'WARNING: Server IP changed while being a connected client')
	end
	network._serverIp = ip
end



-- success, errorMessage = stop( )
function network.stop()
	if network._isServer then
		return network.stopServer()
	elseif network._isClient then
		return network.stopClient()
	end
	return false, 'network is not active'
end

-- state = isActive( )
function network.isActive()
	return (network._host ~= nil)
end



-- Utils
--==============================================================



do
	local function formatNumber(n, units)
		if n < 100 then
			return n..' B'
		end
		local power = 0
		repeat
			power = power+1
			n = n/1024
		until (n < 100 or not units[power+1])
		return ('%.2f %s'):format(n, units[power])
	end

	-- formattedBytes = formatBytes( bytesNumber )
	local units = {'kB','MB','GB','TB'}
	function network.formatBytes(n)
		return formatNumber(n, units)
	end

	-- formattedBits = formatBits( bitsNumber )
	local units = {'kbit','Mbit','Gbit','Tbit'}
	function network.formatBits(n)
		return formatNumber(n, units)
	end

	-- formattedBits = formatSpeed( speed )
	local units = {'kb/s','Mb/s','Gb/s','Tb/s'}
	function network.formatSpeed(n)
		return formatNumber(n, units)
	end

end



--==============================================================
--==============================================================
--==============================================================

return network
