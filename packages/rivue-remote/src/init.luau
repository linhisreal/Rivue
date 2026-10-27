--!strict
--!optimize 2

export type RemoteRequest = {
	action: string,
	payload: unknown,
	id: number?,
}

--- `data` comes from the network, check its type before use
export type RemoteResponse = {
	id: number,
	ok: boolean,
	data: unknown?,
	error: string?,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Remote = {}

-- Set by `lune run version rivue-remote <version>`
Remote.version = "0.7.0-beta.1"
Remote.__index = Remote

const CLIENT_WAIT_TIMEOUT = 5

-- Clients wait for the server's copy: instances created on the client never replicate
local function findOrCreate(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end

	if RunService:IsClient() then
		local replicated = parent:WaitForChild(name, CLIENT_WAIT_TIMEOUT)
		if replicated then
			return replicated
		end
		-- Server never set up remotes (e.g. no Remote.handle/setupServer call); create locally so
		-- the client doesn't error, but nothing will reach the server
		warn(`[RivueRemote] {name} not found in {parent:GetFullName()}, call Remote.setupServer() on the server`)
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

local function getFolder(): Folder
	return findOrCreate(ReplicatedStorage, "Folder", "RemoteEvents") :: Folder
end

local function getRequestEvent(): RemoteEvent
	return findOrCreate(getFolder(), "RemoteEvent", "Request") :: RemoteEvent
end

local function getResponseEvent(): RemoteEvent
	return findOrCreate(getFolder(), "RemoteEvent", "Response") :: RemoteEvent
end

export type Config = {
	-- Largest payload, in bytes, roughly as the network sends it (default 20000)
	maxPayloadSize: number?,
	maxPayloadDepth: number?,
	-- Requests one player may send per second across all actions (default 60, 0 disables)
	maxRequestsPerSecond: number?,
	-- Payload bytes one player may send per second across all actions (default 50000, 0 disables)
	maxBytesPerSecond: number?,
}

local settings = {
	maxPayloadSize = 20000,
	maxPayloadDepth = 10,
	maxRequestsPerSecond = 60,
	maxBytesPerSecond = 50000,
}

--- Call it with the same values on the server and the client, from a shared module
function Remote.configure(config: Config)
	local known = settings :: { [string]: number }
	for key, value in config :: any do
		assert(known[key] ~= nil, `[RivueRemote] Unknown setting '{key}'`)
		assert(type(value) == "number" and value >= 0, `[RivueRemote] {key} must be a number of 0 or more`)
		known[key] = value
	end
end

const SAFE_DATATYPES = table.freeze({
	Vector2 = true,
	Vector3 = true,
	CFrame = true,
	Color3 = true,
	UDim = true,
	UDim2 = true,
	EnumItem = true,
	Instance = true,
	BrickColor = true,
	NumberRange = true,
	Rect = true,
	DateTime = true,
})

local function validatePayload(payload: unknown): (boolean, string?, number)
	local size = 0
	local reason: string? = nil
	local maxSize = settings.maxPayloadSize
	local maxDepth = settings.maxPayloadDepth

	local function visit(val: unknown, depth: number): boolean
		if depth > maxDepth then
			reason = "payload_too_deep"
			return false
		end
		local t = type(val)
		if t == "string" then
			size += #(val :: string) + 2
		elseif t == "number" or t == "boolean" or t == "nil" then
			size += 8
		elseif t == "table" then
			size += 2
			for k, v in val :: { [unknown]: unknown } do
				if not visit(k, depth + 1) or not visit(v, depth + 1) then
					return false
				end
			end
		elseif SAFE_DATATYPES[typeof(val)] then
			size += 16
		else
			reason = "payload_unsafe_type"
			return false
		end
		if size > maxSize then
			reason = "payload_too_large"
			return false
		end
		return true
	end

	if not visit(payload, 0) then
		return false, reason, size
	end
	return true, nil, size
end

local function checkOutgoing(actionName: unknown, payload: unknown): string?
	if type(actionName) ~= "string" or #actionName == 0 or #actionName > 100 then
		return "invalid_action_name"
	end
	local valid, validErr = validatePayload(payload)
	return if valid then nil else validErr
end

local pendingRequests: { [number]: (resp: RemoteResponse) -> () } = {}
-- The server answers only the player who asked, so ids need to be unique per client, not globally
local nextRequestId = 0
local responseConn: RBXScriptConnection? = nil

local function listenForResponses()
	if responseConn then
		return
	end
	responseConn = getResponseEvent().OnClientEvent:Connect(function(resp: unknown)
		if type(resp) ~= "table" then
			return
		end
		local id = (resp :: RemoteResponse).id
		local settle = if type(id) == "number" then pendingRequests[id] else nil
		if settle then
			settle(resp :: RemoteResponse)
		end
	end)
end

--- Returns the response data, unchecked: refine it before use
function Remote.request(actionName: string, payload: unknown, timeout: number?): (unknown?, string?)
	local outgoingErr = checkOutgoing(actionName, payload)
	if outgoingErr then
		return nil, outgoingErr
	end

	local timeoutValue = timeout or 10
	nextRequestId += 1
	local reqId = nextRequestId
	local reqEv = getRequestEvent()
	listenForResponses()
	local thread = coroutine.running()
	local done = false
	local waiting = false
	local result: RemoteResponse? = nil
	local timeoutThread: thread? = nil

	local function settle(resp: RemoteResponse?, fromTimeout: boolean)
		if done then
			return
		end
		done = true
		result = resp
		pendingRequests[reqId] = nil
		if timeoutThread and not fromTimeout then
			task.cancel(timeoutThread)
		end
		if waiting then
			task.spawn(thread)
		end
	end

	pendingRequests[reqId] = function(resp: RemoteResponse)
		settle(resp, false)
	end
	timeoutThread = task.delay(timeoutValue, settle, nil, true)

	reqEv:FireServer({ action = actionName, payload = payload, id = reqId })

	if not done then
		waiting = true
		coroutine.yield()
	end

	if result == nil then
		return nil, "timeout"
	end

	if result and result.ok then
		return result.data, nil
	else
		return nil, if result then result.error else "unknown error"
	end
end

--- Returns the reason when the payload can't be sent
function Remote.fire(actionName: string, payload: unknown): string?
	local outgoingErr = checkOutgoing(actionName, payload)
	if outgoingErr then
		warn(`[RivueRemote] fire("{tostring(actionName)}") wasn't sent: {outgoingErr}`)
		return outgoingErr
	end
	getRequestEvent():FireServer({ action = actionName, payload = payload })
	return nil
end

local function getEventsEvent(): RemoteEvent
	return findOrCreate(getFolder(), "RemoteEvent", "Events") :: RemoteEvent
end

local function getUnreliableEvent(): UnreliableRemoteEvent
	return findOrCreate(getFolder(), "UnreliableRemoteEvent", "UnreliableEvents") :: UnreliableRemoteEvent
end

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

local listeners: { [string]: { (payload: any) -> () } } = {}
local eventsConnected = false

local function dispatch(name: unknown, payload: unknown)
	local list = if type(name) == "string" then listeners[name] else nil
	if list then
		for _, fn in table.clone(list) do
			task.spawn(fn, payload)
		end
	end
end

-- Every event the server sends arrives on two shared events, so a game with many event names
-- still holds two RemoteEvents, and a frame's sends to a player travel as one message
local function connectEvents()
	if eventsConnected then
		return
	end
	eventsConnected = true
	getEventsEvent().OnClientEvent:Connect(function(batch: unknown)
		if type(batch) ~= "table" then
			return
		end
		for _, entry in batch :: { { unknown } } do
			if type(entry) == "table" then
				dispatch(entry[1], entry[2])
			end
		end
	end)
	getUnreliableEvent().OnClientEvent:Connect(dispatch)
end

function Remote.on(name: string, fn: (payload: any) -> ()): Connection
	connectEvents()
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	table.insert(list, fn)
	local connection: Connection
	connection = {
		Connected = true,
		Disconnect = function(self: Connection)
			if not connection.Connected then
				return
			end
			connection.Connected = false
			local current = listeners[name]
			local at = if current then table.find(current, fn) else nil
			if current and at then
				table.remove(current, at)
			end
		end,
	}
	return connection
end

export type SendOptions = {
	-- UnreliableRemoteEvent: may drop or reorder, but costs less. For values sent many times a second
	unreliable: boolean?,
}

local outbox: { [Player]: { { unknown } } } = {}
local flushConn: RBXScriptConnection? = nil

local function flush()
	if next(outbox) == nil then
		return
	end
	local pending = outbox
	outbox = {}
	local event = getEventsEvent()
	for player, batch in pending do
		-- A player can leave between the send and the end of the frame
		pcall(event.FireClient, event, player, batch)
	end
end

local function enqueue(player: Player, name: string, payload: unknown)
	local batch = outbox[player]
	if not batch then
		batch = {}
		outbox[player] = batch
	end
	table.insert(batch, { name :: unknown, payload })
	if not flushConn then
		flushConn = RunService.Heartbeat:Connect(flush)
		Players.PlayerRemoving:Connect(function(leaving)
			outbox[leaving] = nil
		end)
	end
end

local function checkSend(fnName: string, name: unknown, payload: unknown): string?
	assert(RunService:IsServer(), `[RivueRemote] {fnName}() runs on the server`)
	assert(type(name) == "string" and #name > 0, `[RivueRemote] {fnName}() needs an event name`)
	local valid, validErr = validatePayload(payload)
	if not valid then
		warn(`[RivueRemote] {fnName}("{name}") wasn't sent: {validErr}`)
		return validErr
	end
	return nil
end

--- Sent at the end of the frame, with the frame's other sends. Returns the reason when the payload
--- can't be sent
function Remote.send(player: Player, name: string, payload: unknown, options: SendOptions?): string?
	local err = checkSend("send", name, payload)
	if err then
		return err
	end
	if options and options.unreliable then
		getUnreliableEvent():FireClient(player, name, payload)
	else
		enqueue(player, name, payload)
	end
	return nil
end

function Remote.sendAll(name: string, payload: unknown, options: SendOptions?): string?
	local err = checkSend("sendAll", name, payload)
	if err then
		return err
	end
	if options and options.unreliable then
		getUnreliableEvent():FireAllClients(name, payload)
	else
		for _, player in Players:GetPlayers() do
			enqueue(player, name, payload)
		end
	end
	return nil
end

Remote.flush = flush

export type RequestHandler = (player: Player, payload: unknown) -> unknown

export type HandleOptions = {
	-- Requests per second per player (default 30, 0 disables)
	maxPerSecond: number?,
	-- Return false to reject the payload with "invalid_payload" before the handler runs
	check: ((payload: unknown) -> boolean)?,
}

--- Return false to reject the request with "rejected"
export type Middleware = (player: Player, action: string, payload: unknown) -> boolean?

const DEFAULT_MAX_PER_SECOND = 30

type Bucket = { tokens: number, last: number }

export type ActionStats = {
	calls: number,
	failed: number,
	rejected: number,
	totalTime: number,
	maxTime: number,
}

local handlers: { [string]: RequestHandler } = {}
local limits: { [string]: number } = {}
local checks: { [string]: ((payload: unknown) -> boolean)? } = {}
local middlewares: { Middleware } = {}
local buckets: { [Player]: { [unknown]: Bucket } } = {}
local stats: { [string]: ActionStats } = {}

-- Keys no action name can collide with
local UNKNOWN_ACTIONS = newproxy(false)
local ALL_REQUESTS = newproxy(false)
local ALL_BYTES = newproxy(false)

local function take(player: Player, key: unknown, rate: number, amount: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { tokens = rate, last = now }
		playerBuckets[key] = bucket
	end
	bucket.tokens = math.min(rate, bucket.tokens + (now - bucket.last) * rate)
	bucket.last = now
	if bucket.tokens < amount then
		return false
	end
	bucket.tokens -= amount
	return true
end

local function statsFor(action: string): ActionStats
	local entry = stats[action]
	if not entry then
		entry = { calls = 0, failed = 0, rejected = 0, totalTime = 0, maxTime = 0 }
		stats[action] = entry
	end
	return entry
end
local serverConn: RBXScriptConnection? = nil

--- The reply to one request, or nil when none is sent. fire() sends no id and gets no reply
local function processRequest(player: Player, req: unknown): RemoteResponse?
	if type(req) ~= "table" then
		return nil
	end
	local request = req :: { action: unknown, id: unknown, payload: unknown }
	local action = request.action
	if type(action) ~= "string" then
		return nil
	end
	local id = request.id
	local function reply(ok: boolean, data: unknown?, err: string?): RemoteResponse?
		local idType = type(id)
		return if idType == "number" or idType == "string"
			then { id = id :: any, ok = ok, data = data, error = err }
			else nil
	end

	local actionHandler = handlers[action]
	if not actionHandler then
		-- Limited too, or a client could make the server reply as fast as it sends
		if take(player, UNKNOWN_ACTIONS, DEFAULT_MAX_PER_SECOND, 1) then
			return reply(false, nil, "unknown_action")
		end
		return nil
	end

	local entry = statsFor(action)
	local function refuse(err: string): RemoteResponse?
		entry.rejected += 1
		return reply(false, nil, err)
	end

	-- Per action limits alone would let a client spread its spam over every action
	local total = settings.maxRequestsPerSecond
	if total > 0 and not take(player, ALL_REQUESTS, total, 1) then
		return refuse("rate_limited")
	end
	local rate = limits[action]
	if rate > 0 and not take(player, action, rate, 1) then
		return refuse("rate_limited")
	end

	local payload = request.payload
	local valid, validErr, size = validatePayload(payload)
	if not valid then
		return refuse(validErr :: string)
	end
	local bytes = settings.maxBytesPerSecond
	if bytes > 0 and not take(player, ALL_BYTES, bytes, size) then
		return refuse("rate_limited")
	end

	for _, middleware in table.clone(middlewares) do
		local ran, allowed = pcall(middleware, player, action, payload)
		if not ran then
			warn(`[RivueRemote] Middleware failed on '{action}': {allowed}`)
			entry.failed += 1
			return reply(false, nil, "handler_error")
		elseif allowed == false then
			return refuse("rejected")
		end
	end

	local check = checks[action]
	if check then
		local ran, passed = pcall(check, payload)
		if not ran or passed ~= true then
			return refuse("invalid_payload")
		end
	end

	local started = os.clock()
	local ok, result = pcall(actionHandler, player, payload)
	local elapsed = os.clock() - started
	entry.calls += 1
	entry.totalTime += elapsed
	if elapsed > entry.maxTime then
		entry.maxTime = elapsed
	end
	if not ok then
		-- The error stays in the server log, the client only learns that it failed
		warn(`[RivueRemote] Remote handler '{action}' failed: {result}`)
		entry.failed += 1
		return reply(false, nil, "handler_error")
	end
	return reply(true, result)
end

--- Handler time includes any yields, such as DataStore calls
function Remote.stats(): { [string]: ActionStats }
	local copy = {}
	for action, entry in stats do
		copy[action] = table.clone(entry)
	end
	return copy
end

function Remote.resetStats()
	table.clear(stats)
end

-- A server can't fire its own OnServerEvent, so the tests call this directly
Remote._processRequest = processRequest

-- Call it once at server startup, so clients don't wait for the events
function Remote.setupServer(): ()
	assert(RunService:IsServer(), "Remote.setupServer() must be called on the server")
	getRequestEvent()
	getResponseEvent()
	getEventsEvent()
	getUnreliableEvent()
end

function Remote.handle(actionName: string, handler: RequestHandler, opts: HandleOptions?): ()
	assert(RunService:IsServer(), "Remote.handle() must be called on the server")
	handlers[actionName] = handler
	limits[actionName] = if opts and opts.maxPerSecond then opts.maxPerSecond else DEFAULT_MAX_PER_SECOND
	checks[actionName] = if opts then opts.check else nil
	if serverConn then
		return
	end

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	local resEv = getResponseEvent()
	serverConn = getRequestEvent().OnServerEvent:Connect(function(player: Player, req: unknown)
		local response = processRequest(player, req)
		if response then
			resEv:FireClient(player, response)
		end
	end)
end

--- Runs before every handler, after the rate limit and payload checks. Returns a remover
function Remote.use(middleware: Middleware): () -> ()
	assert(RunService:IsServer(), "Remote.use() must be called on the server")
	table.insert(middlewares, middleware)
	return function()
		local at = table.find(middlewares, middleware)
		if at then
			table.remove(middlewares, at)
		end
	end
end

export type Action<Req, Res> = {
	name: string,
	request: (payload: Req, timeout: number?) -> (Res?, string?),
	fire: (payload: Req) -> string?,
	handle: (handler: (player: Player, payload: Req) -> Res, opts: HandleOptions?) -> (),
}

--- One action shared by client and server, so both sides agree on its types:
--- `local Buy: Remote.Action<{ id: string }, boolean> = Remote.action("shop:buy")`
function Remote.action<Req, Res>(name: string): Action<Req, Res>
	return table.freeze({
		name = name,
		request = function(payload: Req, timeout: number?): (Res?, string?)
			local data, err = Remote.request(name, payload, timeout)
			return data :: Res?, err
		end,
		fire = function(payload: Req): string?
			return Remote.fire(name, payload)
		end,
		handle = function(handler: (player: Player, payload: Req) -> Res, opts: HandleOptions?)
			Remote.handle(name, handler :: any, opts)
		end,
	})
end

return Remote
