--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

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

Remote.version = "0.8.0-beta.1"
Remote.__index = Remote

local rivue: any = nil
local rivueSearched = false

local function findRivue(): any
	if rivueSearched then
		return rivue
	end
	rivueSearched = true
	local node: Instance? = script.Parent
	while node do
		local candidate = node:FindFirstChild("RivueUI")
		if not candidate then
			local pesdePackages = node:FindFirstChild("roblox_packages")
			candidate = if pesdePackages then pesdePackages:FindFirstChild("RivueUI") else nil
		end
		if candidate then
			local ok, loaded = pcall(require, candidate :: any)
			if ok and type(loaded) == "table" and loaded.createApp then
				rivue = loaded
				return rivue
			end
		end
		node = node.Parent
	end
	return nil
end

local function requireRivue(fnName: string): any
	return findRivue() or error(`[RivueRemote] {fnName}() needs RivueUI: install it next to RivueRemote`, 0)
end

local function stopWithScope(connection: { Disconnect: (any) -> () })
	local found = findRivue()
	if found and found.getCurrentScope() then
		found.onScopeDispose(function()
			connection:Disconnect()
		end)
	end
end

const CLIENT_WAIT_TIMEOUT = 5

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
	maxPayloadSize: number?,
	maxPayloadDepth: number?,
	maxRequestsPerSecond: number?,
	maxBytesPerSecond: number?,
	maxConcurrentRequests: number?,
}

local settings = {
	maxPayloadSize = 20000,
	maxPayloadDepth = 10,
	maxRequestsPerSecond = 60,
	maxBytesPerSecond = 50000,
	maxConcurrentRequests = 10,
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

const SAFE_DATATYPES: { [string]: boolean } = table.freeze({
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
}) :: any

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- Datatypes are userdata, so NaN inside a Vector3 or CFrame would skip the number check
local function finiteComponents(value: any, kind: string): boolean
	local parts: { number }
	if kind == "Vector2" then
		parts = { value.X, value.Y }
	elseif kind == "Vector3" then
		parts = { value.X, value.Y, value.Z }
	elseif kind == "CFrame" then
		parts = { value:GetComponents() }
	elseif kind == "Color3" then
		parts = { value.R, value.G, value.B }
	elseif kind == "UDim" then
		parts = { value.Scale, value.Offset }
	elseif kind == "UDim2" then
		parts = { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "NumberRange" then
		parts = { value.Min, value.Max }
	elseif kind == "Rect" then
		parts = { value.Min.X, value.Min.Y, value.Max.X, value.Max.Y }
	else
		return true
	end
	for _, n in parts do
		if not isFinite(n) then
			return false
		end
	end
	return true
end

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
		local t = typeof(val)
		if t == "string" then
			size += #(val :: string) + 2
		elseif t == "number" then
			if not isFinite(val :: number) then
				reason = "payload_bad_number"
				return false
			end
			size += 8
		elseif t == "boolean" or t == "nil" then
			size += 8
		elseif t == "table" then
			size += 2
			for k, v in val :: { [unknown]: unknown } do
				if not visit(k, depth + 1) or not visit(v, depth + 1) then
					return false
				end
			end
		elseif SAFE_DATATYPES[t] then
			if not finiteComponents(val, t) then
				reason = "payload_bad_number"
				return false
			end
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

const STATE_SYNC = "__rivueStateSync"
const STATE_EVENT = "__rivueState"

local function devtools(): any
	local found = findRivue()
	local tools = if found then found._devtools else nil
	if tools and (tools.enabled == nil or tools.enabled()) then
		return tools
	end
	return nil
end

local function sizeOf(payload: unknown): number
	local _, _, size = validatePayload(payload)
	return size
end

local function describe(value: unknown): string
	local t = typeof(value)
	if t == "string" then
		local text = value :: string
		return if #text > 24 then `"{string.sub(text, 1, 21)}..."` else `"{text}"`
	elseif t == "table" then
		local count = 0
		for _ in value :: { [unknown]: unknown } do
			count += 1
		end
		return `table ({count})`
	end
	return tostring(value)
end

local function checkOutgoing(actionName: unknown, payload: unknown): string?
	if type(actionName) ~= "string" or #actionName == 0 or #actionName > 100 then
		return "invalid_action_name"
	end
	local valid, validErr = validatePayload(payload)
	return if valid then nil else validErr
end

local pendingRequests: { [number]: (resp: RemoteResponse) -> () } = {}
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

	local started = os.clock()
	reqEv:FireServer({ action = actionName, payload = payload, id = reqId })

	if not done then
		waiting = true
		coroutine.yield()
	end

	local tools = devtools()
	if tools then
		local outcome = if result == nil then "timeout" elseif result.ok then "ok" else result.error or "error"
		tools.event("request", actionName, `{outcome} · {sizeOf(payload)} B`, (os.clock() - started) * 1000)
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
	local tools = devtools()
	if tools then
		tools.event("send", actionName, `{sizeOf(payload)} B`)
	end
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
	if name ~= STATE_EVENT and type(name) == "string" then
		local tools = devtools()
		if tools then
			tools.event("event", name, `{sizeOf(payload)} B`)
		end
	end
	local list = if type(name) == "string" then listeners[name] else nil
	if list then
		for _, fn in table.clone(list) do
			task.spawn(fn, payload)
		end
	end
end

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
	stopWithScope(connection)
	return connection
end

export type SendOptions = {
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
	maxPerSecond: number?,
	check: ((payload: unknown) -> boolean)?,
	exclusive: boolean?,
	allow: ((player: Player) -> boolean)?,
}

--- Return false to reject the request with "rejected"
export type Middleware = (player: Player, action: string, payload: unknown) -> boolean?

const DEFAULT_MAX_PER_SECOND = 30
const MAX_ACTION_LENGTH = 100
const WARN_INTERVAL = 10

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
local exclusive: { [string]: { [Player]: true } } = {}
local inFlight: { [Player]: number } = {}
local allows: { [string]: ((player: Player) -> boolean)? } = {}
local traps: { [string]: true } = {}
local suspicionListeners: { (player: Player, reason: string, count: number) -> () } = {}
local suspicions: { [Player]: { [string]: { count: number, last: number } } } = {}

-- At most one call per player and reason a second, so a flood can't flood the listeners
local function suspect(player: Player, reason: string)
	if #suspicionListeners == 0 then
		return
	end
	local byReason = suspicions[player]
	if not byReason then
		byReason = {}
		suspicions[player] = byReason
	end
	local record = byReason[reason]
	if not record then
		record = { count = 0, last = -math.huge }
		byReason[reason] = record
	end
	record.count += 1
	local now = os.clock()
	if now - record.last < 1 then
		return
	end
	local count = record.count
	record.count = 0
	record.last = now
	for _, listener in table.clone(suspicionListeners) do
		task.spawn(listener, player, reason, count)
	end
end
local lastWarned: { [string]: number } = {}

local function warnThrottled(key: string, message: string)
	local now = os.clock()
	local last = lastWarned[key]
	if last and now - last < WARN_INTERVAL then
		return
	end
	lastWarned[key] = now
	warn(message)
end
local buckets: { [Player]: { [unknown]: Bucket } } = {}
local stats: { [string]: ActionStats } = {}

local REFUSALS = newproxy(false)
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

local function processRequest(player: Player, req: unknown): RemoteResponse?
	if type(req) ~= "table" then
		suspect(player, "malformed")
		return nil
	end
	local request = req :: { action: unknown, id: unknown, payload: unknown }
	local action = request.action
	if type(action) ~= "string" or #action > MAX_ACTION_LENGTH then
		suspect(player, "malformed")
		return nil
	end
	local id = request.id
	local function reply(ok: boolean, data: unknown?, err: string?): RemoteResponse?
		return if type(id) == "number" then { id = id :: any, ok = ok, data = data, error = err } else nil
	end

	-- Refusals are capped too, or a client could make the server reply as fast as it sends
	local function refuseQuietly(err: string): RemoteResponse?
		return if take(player, REFUSALS, DEFAULT_MAX_PER_SECOND, 1) then reply(false, nil, err) else nil
	end

	local actionHandler = handlers[action]
	if not actionHandler then
		suspect(player, if traps[action] then "trap" else "unknown_action")
		return refuseQuietly("unknown_action")
	end

	local entry = statsFor(action)
	local function refuse(err: string): RemoteResponse?
		entry.rejected += 1
		return refuseQuietly(err)
	end

	-- Totalled across actions, or spam could be spread over all of them
	local total = settings.maxRequestsPerSecond
	if total > 0 and not take(player, ALL_REQUESTS, total, 1) then
		suspect(player, "rate_limited")
		return refuse("rate_limited")
	end
	local rate = limits[action]
	if rate > 0 and not take(player, action, rate, 1) then
		suspect(player, "rate_limited")
		return refuse("rate_limited")
	end

	-- Before the payload is scanned, so refused players cost as little as possible
	local allow = allows[action]
	if allow then
		local ran, allowed = pcall(allow, player)
		if not ran or allowed ~= true then
			suspect(player, "forbidden")
			return refuse("rejected")
		end
	end

	local payload = request.payload
	local valid, validErr, size = validatePayload(payload)
	local bytes = settings.maxBytesPerSecond
	if bytes > 0 and not take(player, ALL_BYTES, bytes, size) then
		suspect(player, "rate_limited")
		return refuse("rate_limited")
	end
	if not valid then
		suspect(player, validErr :: string)
		return refuse(validErr :: string)
	end

	for _, middleware in table.clone(middlewares) do
		local ran, allowed = pcall(middleware, player, action, payload)
		if not ran then
			warnThrottled(`middleware:{action}`, `[RivueRemote] Middleware failed on '{action}': {allowed}`)
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
			suspect(player, "invalid_payload")
			return refuse("invalid_payload")
		end
	end

	local running = exclusive[action]
	if running and running[player] then
		return refuse("busy")
	end
	-- Handlers can yield, so without a cap one player could keep hundreds waiting on DataStores
	local concurrent = inFlight[player] or 0
	local maxConcurrent = settings.maxConcurrentRequests
	if maxConcurrent > 0 and concurrent >= maxConcurrent then
		return refuse("busy")
	end
	inFlight[player] = concurrent + 1
	if running then
		running[player] = true
	end
	local started = os.clock()
	local ok, result = pcall(actionHandler, player, payload)
	local elapsed = os.clock() - started
	if running then
		running[player] = nil
	end
	local left = (inFlight[player] or 1) - 1
	if left > 0 then
		inFlight[player] = left
	else
		inFlight[player] = nil
	end
	entry.calls += 1
	entry.totalTime += elapsed
	if elapsed > entry.maxTime then
		entry.maxTime = elapsed
	end
	if not ok then
		-- The client only learns that it failed, the error stays in the server log
		warnThrottled(`handler:{action}`, `[RivueRemote] Remote handler '{action}' failed: {result}`)
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

Remote._processRequest = processRequest

local function ignore() end
local listening = false

function Remote.setupServer(): ()
	assert(RunService:IsServer(), "Remote.setupServer() must be called on the server")
	getRequestEvent()
	if listening then
		return
	end
	listening = true
	-- Fires to a remote with no server listener are queued, so exploiters could fill the queue
	getResponseEvent().OnServerEvent:Connect(ignore)
	getEventsEvent().OnServerEvent:Connect(ignore)
	getUnreliableEvent().OnServerEvent:Connect(ignore)
end

local function listen()
	if serverConn then
		return
	end
	Remote.setupServer()

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		inFlight[player] = nil
		suspicions[player] = nil
		for _, running in exclusive do
			running[player] = nil
		end
	end)

	local resEv = getResponseEvent()
	serverConn = getRequestEvent().OnServerEvent:Connect(function(player: Player, req: unknown)
		local response = processRequest(player, req)
		if response then
			resEv:FireClient(player, response)
		end
	end)
end

local function register(actionName: string, handler: RequestHandler, opts: HandleOptions?)
	assert(RunService:IsServer(), "Remote.handle() must be called on the server")
	assert(#actionName <= MAX_ACTION_LENGTH, `[RivueRemote] Action names are limited to {MAX_ACTION_LENGTH} characters`)
	handlers[actionName] = handler
	limits[actionName] = if opts and opts.maxPerSecond then opts.maxPerSecond else DEFAULT_MAX_PER_SECOND
	checks[actionName] = if opts then opts.check else nil
	allows[actionName] = if opts then opts.allow else nil
	traps[actionName] = nil
	if opts and opts.exclusive then
		exclusive[actionName] = {}
	else
		exclusive[actionName] = nil
	end
	listen()
end

function Remote.handle(actionName: string, handler: RequestHandler, opts: HandleOptions?): ()
	assert(string.sub(actionName, 1, 7) ~= "__rivue", `[RivueRemote] '{actionName}' is reserved for RivueRemote`)
	register(actionName, handler, opts)
end

type Validator = (value: unknown) -> boolean

local function parseRange(spec: string, range: string): (number, number)
	if range == "" then
		return -math.huge, math.huge
	end
	local low, high = string.match(range, "^(%-?[%d%.]*)%.%.(%-?[%d%.]*)$")
	local min, max = tonumber(low), tonumber(high)
	assert(low ~= nil and (low == "" or min) and (high == "" or max), `[RivueRemote] Bad range in schema '{spec}'`)
	return min or -math.huge, max or math.huge
end

local function compileString(spec: string): Validator
	local name, range = string.match(spec, "^(%S+)%s*(.*)$")
	assert(name, `[RivueRemote] Empty schema type`)
	local optional = string.sub(name, -1) == "?"
	if optional then
		name = string.sub(name, 1, -2)
	end
	local min, max = parseRange(spec, range or "")
	local test: Validator
	if name == "any" then
		test = function(value)
			return value ~= nil
		end
	elseif name == "string" then
		test = function(value)
			return type(value) == "string" and #value >= min and #value <= max
		end
	elseif name == "number" then
		test = function(value)
			return type(value) == "number" and value >= min and value <= max
		end
	elseif name == "integer" then
		test = function(value)
			return type(value) == "number" and value % 1 == 0 and value >= min and value <= max
		end
	elseif name == "boolean" then
		test = function(value)
			return type(value) == "boolean"
		end
	elseif SAFE_DATATYPES[name] then
		test = function(value)
			return typeof(value) == name
		end
	else
		test = function(value)
			return typeof(value) == "Instance" and (value :: Instance):IsA(name)
		end
	end
	if optional then
		return function(value)
			return value == nil or test(value)
		end
	end
	return test
end

local compile: (spec: any) -> Validator

local function compileTable(spec: { [any]: any }): Validator
	if #spec == 1 and next(spec, 1) == nil then
		local item = compile(spec[1])
		return function(value)
			if type(value) ~= "table" then
				return false
			end
			local list = value :: { [unknown]: unknown }
			local length = #list
			local count = 0
			for key, entry in list do
				if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > length or not item(entry) then
					return false
				end
				count += 1
			end
			return count == length
		end
	end
	local fields: { [string]: Validator } = {}
	for key, fieldSpec in spec do
		assert(type(key) == "string", "[RivueRemote] Schema tables are either { spec } or string keys")
		fields[key] = compile(fieldSpec)
	end
	return function(value)
		if type(value) ~= "table" then
			return false
		end
		for key in value :: { [unknown]: unknown } do
			if type(key) ~= "string" or fields[key] == nil then
				return false
			end
		end
		for key, field in fields do
			if not field((value :: any)[key]) then
				return false
			end
		end
		return true
	end
end

compile = function(spec: any): Validator
	local kind = type(spec)
	if kind == "string" then
		return compileString(spec)
	elseif kind == "table" then
		return compileTable(spec)
	elseif kind == "function" then
		return spec
	end
	error(`[RivueRemote] Schemas are made of strings, tables and functions, got {kind}`)
end

--- Builds a `check` function: `Remote.schema({ id = "string 1..32", amount = "integer 1..99" })`
function Remote.schema(spec: any): (payload: unknown) -> boolean
	return compile(spec)
end

--- A fake action the game never calls; anyone who calls it is reported as "trap"
function Remote.trap(actionName: string)
	assert(RunService:IsServer(), "Remote.trap() must be called on the server")
	assert(string.sub(actionName, 1, 7) ~= "__rivue", `[RivueRemote] '{actionName}' is reserved for RivueRemote`)
	assert(handlers[actionName] == nil, `[RivueRemote] '{actionName}' already has a handler`)
	traps[actionName] = true
	listen()
end

--- Called with the player, a reason and how many times it happened since the last call
function Remote.onSuspicious(listener: (player: Player, reason: string, count: number) -> ()): () -> ()
	assert(RunService:IsServer(), "Remote.onSuspicious() must be called on the server")
	table.insert(suspicionListeners, listener)
	return function()
		local at = table.find(suspicionListeners, listener)
		if at then
			table.remove(suspicionListeners, at)
		end
	end
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
	}) :: any
end

export type State<T> = {
	set: (value: T) -> string?,
	setFor: (player: Player, value: T?) -> string?,
	get: (player: Player?) -> T,
}

type ServerState = { value: any, perPlayer: { [Player]: any }, version: number }

local serverStates: { [string]: ServerState } = {}

local function effectiveValue(state: ServerState, player: Player): any
	local own = state.perPlayer[player]
	return if own ~= nil then own else state.value
end

function Remote.state<T>(name: string, initial: T): State<T>
	assert(RunService:IsServer(), "[RivueRemote] Remote.state() runs on the server")
	assert(serverStates[name] == nil, `[RivueRemote] There's already a state named '{name}'`)
	local valid, validErr = validatePayload(initial)
	assert(valid, `[RivueRemote] Remote.state('{name}'): {validErr}`)
	local state: ServerState = { value = initial, perPlayer = {}, version = 0 }
	serverStates[name] = state

	if not handlers[STATE_SYNC] then
		register(STATE_SYNC, function(player)
			local snapshot = {}
			for stateName, entry in serverStates do
				snapshot[stateName] = { value = effectiveValue(entry, player), version = entry.version }
			end
			return snapshot
		end, { maxPerSecond = 2 })
		Players.PlayerRemoving:Connect(function(player)
			for _, entry in serverStates do
				entry.perPlayer[player] = nil
			end
		end)
	end

	local function publish(player: Player)
		enqueue(player, STATE_EVENT, { name = name, value = effectiveValue(state, player), version = state.version })
	end

	for _, player in Players:GetPlayers() do
		publish(player)
	end

	return table.freeze({
		set = function(value: T): string?
			local ok, err = validatePayload(value)
			if not ok then
				warn(`[RivueRemote] state '{name}' wasn't set: {err}`)
				return err
			end
			state.value = value
			state.version += 1
			for _, player in Players:GetPlayers() do
				if state.perPlayer[player] == nil then
					publish(player)
				end
			end
			return nil
		end,
		setFor = function(player: Player, value: T?): string?
			local ok, err = validatePayload(value)
			if not ok then
				warn(`[RivueRemote] state '{name}' wasn't set: {err}`)
				return err
			end
			state.perPlayer[player] = value
			state.version += 1
			publish(player)
			return nil
		end,
		get = function(player: Player?): T
			return if player then effectiveValue(state, player) else state.value
		end,
	}) :: any
end

local clientStates: { [string]: { value: any, version: number } } = {}
local stateListeners: { [string]: { (value: any) -> () } } = {}
local stateSynced = false
local stateLoading: { thread }? = nil
local stateListening = false

local function applyState(name: unknown, value: unknown, version: unknown)
	if type(name) ~= "string" or type(version) ~= "number" then
		return
	end
	local current = clientStates[name]
	if current and current.version >= version then
		return
	end
	clientStates[name] = { value = value, version = version }
	local tools = devtools()
	if tools then
		tools.event("state", name, `v{version} = {describe(value)}`)
	end
	local list = stateListeners[name]
	if list then
		for _, fn in table.clone(list) do
			task.spawn(fn, value)
		end
	end
end

local function syncStates()
	if stateSynced then
		return
	end
	if stateLoading then
		table.insert(stateLoading, coroutine.running())
		coroutine.yield()
		return
	end
	local waiting: { thread } = {}
	stateLoading = waiting
	if not stateListening then
		stateListening = true
		Remote.on(STATE_EVENT, function(entry: any)
			if type(entry) == "table" then
				applyState(entry.name, entry.value, entry.version)
			end
		end)
	end
	local snapshot, err = Remote.request(STATE_SYNC, nil)
	if type(snapshot) == "table" then
		stateSynced = true
		for name, entry in snapshot :: { [unknown]: any } do
			if type(entry) == "table" then
				applyState(name, entry.value, entry.version)
			end
		end
	else
		warn(`[RivueRemote] Couldn't load state from the server: {err}`)
	end
	stateLoading = nil
	for _, thread in waiting do
		task.spawn(thread)
	end
end

function Remote.getState(name: string): any
	syncStates()
	local entry = clientStates[name]
	return if entry then entry.value else nil
end

function Remote.onState(name: string, fn: (value: any) -> ()): Connection
	local list = stateListeners[name]
	if not list then
		list = {}
		stateListeners[name] = list
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
			local at = table.find(list :: { (value: any) -> () }, fn)
			if at then
				table.remove(list :: { (value: any) -> () }, at)
			end
		end,
	}
	stopWithScope(connection)
	task.spawn(syncStates)
	return connection
end

function Remote.useState<T>(name: string, default: T?): { value: T }
	local Rivue = requireRivue("useState")
	local entry = clientStates[name]
	local current = if entry then entry.value else nil
	local source = Rivue.shallowRef(if current == nil then default else current)
	Remote.onState(name, function(value)
		source.value = if value == nil then default else value
	end)
	return Rivue.computed(function()
		return source.value
	end)
end

export type RequestOptions = {
	payload: unknown?,
	immediate: boolean?,
	timeout: number?,
	initial: unknown?,
	suspense: boolean?,
}

function Remote.useRequest(name: string, options: RequestOptions?): any
	local Rivue = requireRivue("useRequest")
	local opts: RequestOptions = options or {}
	return Rivue.useAsync(function(payload: unknown)
		local data, err = Remote.request(name, payload, opts.timeout)
		if err then
			error(err, 0)
		end
		return data
	end, {
		immediate = opts.immediate,
		args = if opts.payload ~= nil then { opts.payload } else nil,
		initial = opts.initial,
		suspense = opts.suspense,
	})
end

return Remote
