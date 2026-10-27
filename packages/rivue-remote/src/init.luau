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
Remote.version = "0.5.0-beta.1"
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

const MAX_PAYLOAD_SIZE = 20000
const MAX_PAYLOAD_DEPTH = 10

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

local function validatePayload(payload: unknown): (boolean, string?)
	local size = 0
	local reason: string? = nil

	local function visit(val: unknown, depth: number): boolean
		if depth > MAX_PAYLOAD_DEPTH then
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
		if size > MAX_PAYLOAD_SIZE then
			reason = "payload_too_large"
			return false
		end
		return true
	end

	if not visit(payload, 0) then
		return false, reason
	end
	return true, nil
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

function Remote.on(name: string, fn: (payload: any) -> ()): RBXScriptConnection
	local ev = findOrCreate(getFolder(), "RemoteEvent", name) :: RemoteEvent
	return ev.OnClientEvent:Connect(fn)
end

export type SendOptions = {
	-- UnreliableRemoteEvent: may drop or reorder, but costs less. For values sent many times a second
	unreliable: boolean?,
}

local RESERVED_NAMES = table.freeze({ Request = true, Response = true })

local function serverEvent(name: string, options: SendOptions?): RemoteEvent
	assert(RunService:IsServer(), "[RivueRemote] send() and sendAll() run on the server")
	assert(
		type(name) == "string" and not RESERVED_NAMES[name],
		`[RivueRemote] '{tostring(name)}' can't be used as an event name`
	)
	local className = if options and options.unreliable then "UnreliableRemoteEvent" else "RemoteEvent"
	local existing = getFolder():FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		error(`[RivueRemote] '{name}' is already a {existing.ClassName}, so it can't be sent as a {className}`, 3)
	end
	return findOrCreate(getFolder(), className, name) :: RemoteEvent
end

--- Returns the reason when the payload can't be sent
function Remote.send(player: Player, name: string, payload: unknown, options: SendOptions?): string?
	local event = serverEvent(name, options)
	local valid, validErr = validatePayload(payload)
	if not valid then
		warn(`[RivueRemote] send("{name}") wasn't sent: {validErr}`)
		return validErr
	end
	event:FireClient(player, payload)
	return nil
end

function Remote.sendAll(name: string, payload: unknown, options: SendOptions?): string?
	local event = serverEvent(name, options)
	local valid, validErr = validatePayload(payload)
	if not valid then
		warn(`[RivueRemote] sendAll("{name}") wasn't sent: {validErr}`)
		return validErr
	end
	event:FireAllClients(payload)
	return nil
end

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

local handlers: { [string]: RequestHandler } = {}
local limits: { [string]: number } = {}
local checks: { [string]: ((payload: unknown) -> boolean)? } = {}
local middlewares: { Middleware } = {}
local buckets: { [Player]: { [string]: Bucket } } = {}

local function takeToken(player: Player, action: string, rate: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[action]
	if not bucket then
		bucket = { tokens = rate, last = now }
		playerBuckets[action] = bucket
	end
	bucket.tokens = math.min(rate, bucket.tokens + (now - bucket.last) * rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
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
		-- Limited too, or a client could make the server reply as fast as it sends. Real action
		-- names are never empty, so "" can't clash with one
		if takeToken(player, "", DEFAULT_MAX_PER_SECOND) then
			return reply(false, nil, "unknown_action")
		end
		return nil
	end

	local rate = limits[action]
	if rate > 0 and not takeToken(player, action, rate) then
		return reply(false, nil, "rate_limited")
	end

	local payload = request.payload
	local valid, validErr = validatePayload(payload)
	if not valid then
		return reply(false, nil, validErr)
	end

	for _, middleware in table.clone(middlewares) do
		local ran, allowed = pcall(middleware, player, action, payload)
		if not ran then
			warn(`[RivueRemote] Middleware failed on '{action}': {allowed}`)
			return reply(false, nil, "handler_error")
		elseif allowed == false then
			return reply(false, nil, "rejected")
		end
	end

	local check = checks[action]
	if check then
		local ran, passed = pcall(check, payload)
		if not ran or passed ~= true then
			return reply(false, nil, "invalid_payload")
		end
	end

	local ok, result = pcall(actionHandler, player, payload)
	if not ok then
		-- The error stays in the server log, the client only learns that it failed
		warn(`[RivueRemote] Remote handler '{action}' failed: {result}`)
		return reply(false, nil, "handler_error")
	end
	return reply(true, result)
end

-- A server can't fire its own OnServerEvent, so the tests call this directly
Remote._processRequest = processRequest

-- Call it once at server startup, so clients don't wait for the events
function Remote.setupServer(): ()
	assert(RunService:IsServer(), "Remote.setupServer() must be called on the server")
	getRequestEvent()
	getResponseEvent()
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
