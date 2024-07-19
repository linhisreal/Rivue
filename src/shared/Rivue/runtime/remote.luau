--!strict
--!optimize 2

--[[
	Remote Communication
    ====================
	
	Client-side wrapper for RemoteEvents with request/response patterns.
	
	@module remote

	@author Rivue

	@version 1.0.0
	
	Type Definitions:
    -----------------

		type RemoteRequest = {
			action: string,
			payload: any,
			id: string?
		}
		
		type RemoteResponse = {
			id: string,
			ok: boolean,
			data: any?,
			error: string?
		}
	
	Public API:
    -----------

		request(actionName: string, payload: any, timeout?: number) -> (data?, error?)
			'Sends a request to server and waits for response'
			
		fire(actionName: string, payload: any)
			'Fires a one-way event to server (no response expected)'
			
		on(eventName: string, callback: (...any) -> ()) -> RBXScriptConnection
			'Listens for server events'

		setupServer()
			'Creates the remotes (server only)'

		handle(actionName: string, handler: (player, payload) -> any, opts?: { maxPerSecond: number? })
			'Registers a server handler for request()/fire(), rate limited per player (server only)'
	
	Server Implementation:
    ----------------------

		Register handlers on the server; the return value is sent back as `data`:

		Remote.setupServer()

		Remote.handle("getData", function(player, payload)
			return { coins = 10 }
		end)

		Handler errors are logged on the server and the client gets "handler_error".
]]

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
local debugModule = require(script.Parent:WaitForChild("debug"))

local Remote = {}
Remote.__index = Remote

const CLIENT_WAIT_TIMEOUT = 5

--- Finds a child, creating it on the server. Clients wait for the server's copy, since
--- instances created on the client never replicate.
--- @param parent Instance -- Parent to search
--- @param className string -- Class to create
--- @param name string -- Child name
--- @return Instance -- The child
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
		warn(`[Rivue] {name} not found in {parent:GetFullName()}, call Remote.setupServer() on the server`)
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

--- Gets the RemoteEvents folder in ReplicatedStorage
--- @return Folder -- RemoteEvents folder
local function getFolder(): Folder
	return findOrCreate(ReplicatedStorage, "Folder", "RemoteEvents") :: Folder
end

--- Gets the Request RemoteEvent
--- @return RemoteEvent -- Request event for client->server communication
local function getRequestEvent(): RemoteEvent
	return findOrCreate(getFolder(), "RemoteEvent", "Request") :: RemoteEvent
end

--- Gets the Response RemoteEvent
--- @return RemoteEvent -- Response event for server->client communication
local function getResponseEvent(): RemoteEvent
	return findOrCreate(getFolder(), "RemoteEvent", "Response") :: RemoteEvent
end

-- Payload validation helpers
const MAX_PAYLOAD_SIZE = 20000 -- 20KB limit
const MAX_PAYLOAD_DEPTH = 10

-- Roblox types RemoteEvents can carry
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

--- Checks types, depth and approximate size in one pass (no JSON encoding)
--- @param payload unknown -- Data to send
--- @return boolean -- True if it can be sent
--- @return string? -- Reason when it can't
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

-- One response listener shared by every pending request: id -> settle
local pendingRequests: { [string]: (resp: RemoteResponse) -> () } = {}
local responseConn: RBXScriptConnection? = nil

--- Connects the shared response listener once
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

--- Sends a request to server and waits for response with timeout
--- @param actionName string -- Action identifier for the request
--- @param payload unknown -- Data to send with the request
--- @param timeout number? -- Optional timeout in seconds (default: 10)
--- @return unknown? -- Response data if successful (refine before use)
--- @return string? -- Error message if failed
function Remote.request(actionName: string, payload: unknown, timeout: number?): (unknown?, string?)
	if debugModule.enabled then
		debugModule.log("Remote", "Sending request to server", {
			action = actionName,
			timeoutSec = timeout or 10,
		})
	end
	-- Validate action name
	if type(actionName) ~= "string" or #actionName == 0 or #actionName > 100 then
		return nil, "invalid_action_name"
	end

	-- Validate payload
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

	-- Resolves once and resumes the waiting thread
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

	-- Response may already be here
	if not done then
		waiting = true
		coroutine.yield()
	end

	if result == nil then
		debugModule.log("Remote", "Request timed out", { action = actionName, timeout = timeoutValue })
		return nil, "timeout"
	end

	if result and result.ok then
		debugModule.log("Remote", "Request successful", { action = actionName })
		return result.data, nil
	else
		debugModule.log(
			"Remote",
			"Request failed",
			{ action = actionName, error = result and result.error or "unknown" }
		)
		return nil, if result then result.error else "unknown error"
	end
end

--- Fires a one-way event to server (no response expected)
--- @param actionName string -- Action identifier
--- @param payload unknown -- Data to send
--- @return
function Remote.fire(actionName: string, payload: unknown): ()
	debugModule.log("Remote", "Firing one-way event to server", { action = actionName })
	local reqEv = getRequestEvent()
	reqEv:FireServer({ action = actionName, payload = payload })
end

--- Listens for server events on a named RemoteEvent
--- @param name string -- Name of the RemoteEvent to listen to
--- @param fn (...any) -> () -- Callback function to execute
--- @return RBXScriptConnection -- Connection that can be disconnected
function Remote.on(name: string, fn: (...any) -> ()): RBXScriptConnection
	debugModule.log("Remote", "Registering server event listener", { eventName = name })
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

--- Token bucket check, refills at `rate` tokens per second up to `rate`
--- @param player Player -- Sender
--- @param action string -- Action name
--- @param rate number -- Requests per second
--- @return boolean -- True if the request is allowed
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

--- Creates the RemoteEvents folder and events. Call once on the server at startup
--- so clients don't wait for them.
function Remote.setupServer(): ()
	assert(RunService:IsServer(), "Remote.setupServer() must be called on the server")
	getRequestEvent()
	getResponseEvent()
end

--- Registers a server handler for an action sent with Remote.request/fire
--- The handler's return value is sent back as the response data.
--- @param actionName string -- Action identifier
--- @param handler RequestHandler -- (player, payload) -> data
--- @param opts HandleOptions? -- Rate limit options
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
		-- Never trust the client: check the shape before using anything
		if type(req) ~= "table" then
			return
		end
		local request = req :: { action: unknown, id: unknown, payload: unknown }
		local action = request.action
		if type(action) ~= "string" then
			return
		end

		-- fire() sends no id and expects no response
		local id = request.id
		local function respond(ok: boolean, data: unknown?, err: string?)
			if type(id) == "string" then
				resEv:FireClient(player, { id = id, ok = ok, data = data, error = err })
			end
		end

		local actionHandler = handlers[action]
		if not actionHandler then
			respond(false, nil, "unknown_action")
			return
		end

		local rate = limits[action]
		if rate > 0 and not takeToken(player, action, rate) then
			respond(false, nil, "rate_limited")
			return
		end

		local valid, validErr = validatePayload(request.payload)
		if not valid then
			respond(false, nil, validErr)
			return
		end

		local ok, result = pcall(actionHandler, player, request.payload)
		if ok then
			respond(true, result)
		else
			-- Don't send server error details to the client
			warn(`[Rivue] Remote handler '{action}' failed: {result}`)
			respond(false, nil, "handler_error")
		end
	end)
end

return Remote
