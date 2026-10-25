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
	
	Server Implementation:
    ----------------------

		The server must respond using the Response RemoteEvent:
		
		local requestEvent = ReplicatedStorage.RemoteEvents.Request
		local responseEvent = ReplicatedStorage.RemoteEvents.Response
		
		requestEvent.OnServerEvent:Connect(function(player, req)
			if req.action == "getData" then
				local data = { ... }
				responseEvent:FireClient(player, {
					id = req.id,
					ok = true,
					data = data
				})
			end
		end)
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
local debugModule = require(script.Parent:WaitForChild("debug"))

local Remote = {}
Remote.__index = Remote

--- Gets or creates the RemoteEvents folder in ReplicatedStorage
--- @return Folder -- RemoteEvents folder
local function getFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("RemoteEvents") :: Folder?
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "RemoteEvents"
		newFolder.Parent = ReplicatedStorage
		return newFolder
	end
	return folder
end

--- Gets or creates the Request RemoteEvent
--- @return RemoteEvent -- Request event for client->server communication
local function getRequestEvent(): RemoteEvent
	local folder = getFolder()
	local ev = folder:FindFirstChild("Request") :: RemoteEvent?
	if not ev then
		local newEv = Instance.new("RemoteEvent")
		newEv.Name = "Request"
		newEv.Parent = folder
		return newEv
	end
	return ev
end

--- Gets or creates the Response RemoteEvent
--- @return RemoteEvent -- Response event for server->client communication
local function getResponseEvent(): RemoteEvent
	local folder = getFolder()
	local ev = folder:FindFirstChild("Response") :: RemoteEvent?
	if not ev then
		local newEv = Instance.new("RemoteEvent")
		newEv.Name = "Response"
		newEv.Parent = folder
		return newEv
	end
	return ev
end

-- Payload validation helpers
const MAX_PAYLOAD_SIZE = 20000 -- 20KB limit
const MAX_PAYLOAD_DEPTH = 10

local function validatePayload(payload: unknown): (boolean, string?)
	-- Size check via JSON serialization
	local ok, jsonStr = pcall(function()
		return HttpService:JSONEncode(payload)
	end)

	if not ok then
		return false, "payload_not_serializable"
	end

	if #jsonStr > MAX_PAYLOAD_SIZE then
		return false, "payload_too_large"
	end

	-- Type validation - only allow safe types
	local function isSafeType(val: unknown, depth: number): boolean
		if depth > MAX_PAYLOAD_DEPTH then
			return false
		end -- prevent deep nesting
		local t = type(val)
		if t == "string" or t == "number" or t == "boolean" or t == "nil" then
			return true
		elseif t == "table" then
			for k, v in val :: { [unknown]: unknown } do
				if not isSafeType(k, depth + 1) or not isSafeType(v, depth + 1) then
					return false
				end
			end
			return true
		end
		return false
	end

	if not isSafeType(payload, 0) then
		return false, "payload_unsafe_type"
	end

	return true, nil
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
	local resEv = getResponseEvent()
	local thread = coroutine.running()
	local done = false
	local waiting = false
	local result: RemoteResponse? = nil
	local conn: RBXScriptConnection? = nil
	local timeoutThread: thread? = nil

	-- Resolves once and resumes the waiting thread
	local function settle(resp: RemoteResponse?, fromTimeout: boolean)
		if done then
			return
		end
		done = true
		result = resp
		if conn then
			conn:Disconnect()
		end
		if timeoutThread and not fromTimeout then
			task.cancel(timeoutThread)
		end
		if waiting then
			task.spawn(thread)
		end
	end

	conn = resEv.OnClientEvent:Connect(function(resp: RemoteResponse)
		if resp and resp.id == reqId then
			settle(resp, false)
		end
	end)
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
	local folder = getFolder()
	local ev = folder:FindFirstChild(name) :: RemoteEvent?
	if not ev then
		local newEv = Instance.new("RemoteEvent")
		newEv.Name = name
		newEv.Parent = folder
		return newEv.OnClientEvent:Connect(fn)
	end
	return ev.OnClientEvent:Connect(fn)
end

return Remote
