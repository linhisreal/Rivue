--!strict
--!optimize 2
-- RivueRemote: request/response and events between client and server over RemoteEvents, with
-- payload checks and per-player rate limits. Separate from Rivue, which only does UI.

export type RemoteRequest = {
	action: string,
	payload: unknown,
	id: string?,
}

--- `data` comes from the network, check its type before use
export type RemoteResponse = {
	id: string,
	ok: boolean,
	data: unknown?,
	error: string?,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Remote = {}
Remote.__index = Remote

const CLIENT_WAIT_TIMEOUT = 5

--- Finds a child, creating it on the server. Clients wait for the server's copy, since
--- instances created on the client never replicate.
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

local pendingRequests: { [string]: (resp: RemoteResponse) -> () } = {}
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
		local settle = if type(id) == "string" then pendingRequests[id] else nil
		if settle then
			settle(resp :: RemoteResponse)
		end
	end)
end

--- Returns the response data, unchecked: refine it before use
function Remote.request(actionName: string, payload: unknown, timeout: number?): (unknown?, string?)
	if type(actionName) ~= "string" or #actionName == 0 or #actionName > 100 then
		return nil, "invalid_action_name"
	end

	local valid, validErr = validatePayload(payload)
	if not valid then
		return nil, validErr
	end

	local timeoutValue = timeout or 10
	local reqId = HttpService:GenerateGUID(false)
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

function Remote.fire(actionName: string, payload: unknown): ()
	local reqEv = getRequestEvent()
	reqEv:FireServer({ action = actionName, payload = payload })
end

function Remote.on(name: string, fn: (...any) -> ()): RBXScriptConnection
	local ev = findOrCreate(getFolder(), "RemoteEvent", name) :: RemoteEvent
	return ev.OnClientEvent:Connect(fn)
end

export type RequestHandler = (player: Player, payload: unknown) -> unknown

export type HandleOptions = {
	-- Requests per second per player (default 30, 0 disables)
	maxPerSecond: number?,
}

const DEFAULT_MAX_PER_SECOND = 30

type Bucket = { tokens: number, last: number }

local handlers: { [string]: RequestHandler } = {}
local limits: { [string]: number } = {}
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
		return if type(id) == "string" then { id = id, ok = ok, data = data, error = err } else nil
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

	local valid, validErr = validatePayload(request.payload)
	if not valid then
		return reply(false, nil, validErr)
	end

	local ok, result = pcall(actionHandler, player, request.payload)
	if not ok then
		-- The error stays in the server log, the client only learns that it failed
		warn(`[RivueRemote] Remote handler '{action}' failed: {result}`)
		return reply(false, nil, "handler_error")
	end
	return reply(true, result)
end

-- A server can't fire its own OnServerEvent, so the tests call this directly
Remote._processRequest = processRequest

--- Creates the RemoteEvents folder and events. Call once on the server at startup
--- so clients don't wait for them.
function Remote.setupServer(): ()
	assert(RunService:IsServer(), "Remote.setupServer() must be called on the server")
	getRequestEvent()
	getResponseEvent()
end

function Remote.handle(actionName: string, handler: RequestHandler, opts: HandleOptions?): ()
	assert(RunService:IsServer(), "Remote.handle() must be called on the server")
	handlers[actionName] = handler
	limits[actionName] = if opts and opts.maxPerSecond then opts.maxPerSecond else DEFAULT_MAX_PER_SECOND
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

return Remote
