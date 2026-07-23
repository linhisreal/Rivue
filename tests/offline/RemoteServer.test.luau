--!strict
-- Offline only: swaps RunService.IsServer/IsClient to run both sides of Remote in one VM, which
-- Studio can't do

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService") :: any
local Remote = require(ReplicatedStorage:WaitForChild("RivueRemote"))

local function assertEquals(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(
			string.format(
				"Assertion failed: %s\nExpected: %s\nActual: %s",
				message or "values not equal",
				tostring(expected),
				tostring(actual)
			)
		)
	end
	print("✓", message or "Assertion passed")
end

local function asServer(fn: () -> ())
	RunService.IsServer = function()
		return true
	end
	RunService.IsClient = function()
		return false
	end
	fn()
	RunService.IsServer = function()
		return false
	end
	RunService.IsClient = function()
		return true
	end
end

local function runTests()
	print("\n========== REMOTE SERVER TEST SUITE ==========\n")

	asServer(function()
		Remote.setupServer()
		Remote.handle("double", function(_player, payload: any)
			return payload.n * 2
		end)
		Remote.handle("boom", function()
			error("secret detail")
		end)
		Remote.handle("limited", function()
			return true
		end, { maxPerSecond = 2 })
		Remote.handle("slow", function(_player, payload: any)
			task.wait(payload.delay)
			return payload.n
		end)
		Remote.handle("echoType", function(_player, payload: any)
			return typeof(payload.position)
		end)
	end)

	print("Test 1: Handler result is returned to the client")
	do
		local data, err = Remote.request("double", { n = 21 }, 2)
		assertEquals(data, 42, "Should return handler result")
		assertEquals(err, nil, "Should not return an error")
	end

	print("Test 2: Handler errors are hidden from the client")
	do
		local data, err = Remote.request("boom", {}, 2)
		assertEquals(data, nil, "Should not return data")
		assertEquals(err, "handler_error", "Should return a generic error")
	end

	print("Test 3: Unknown actions are rejected")
	do
		local _, err = Remote.request("missing", {}, 2)
		assertEquals(err, "unknown_action", "Should return unknown_action")
	end

	print("Test 4: Requests are rate limited per player")
	do
		local errors = {}
		for i = 1, 3 do
			local _, err = Remote.request("limited", {}, 1)
			errors[i] = err or "ok"
		end
		assertEquals(errors[1], "ok", "First request allowed")
		assertEquals(errors[2], "ok", "Second request allowed")
		assertEquals(errors[3], "rate_limited", "Third request rate limited")
	end

	print("Test 5: Concurrent requests each get their own response")
	do
		local results = {}
		task.spawn(function()
			results.a = Remote.request("slow", { delay = 0.2, n = 1 }, 2)
		end)
		task.spawn(function()
			results.b = Remote.request("slow", { delay = 0.05, n = 2 }, 2)
		end)
		task.wait(0.4)
		assertEquals(results.a, 1, "Slow request gets its own answer")
		assertEquals(results.b, 2, "Fast request gets its own answer")
	end

	print("Test 6: Roblox datatypes are allowed in payloads")
	do
		local position = newproxy(true)
		getmetatable(position).__rbxtype = "Vector3"
		local result, err = Remote.request("echoType", { position = position }, 1)
		assertEquals(err, nil, "Vector3 payload isn't rejected")
		assertEquals(result, "Vector3", "Server receives it")
		local _, badErr = Remote.request("echoType", { fn = function() end }, 1)
		assertEquals(badErr, "payload_unsafe_type", "Functions are still rejected")
	end

	print("Test 7: fire() checks its payload like request() does")
	do
		local reached = false
		asServer(function()
			Remote.handle("fireCheck", function()
				reached = true
				return nil
			end)
		end)
		assertEquals(
			Remote.fire("fireCheck", { fn = function() end }),
			"payload_unsafe_type",
			"an unsafe payload is refused"
		)
		assertEquals(reached, false, "and never reaches the server")
		assertEquals(Remote.fire("", {}), "invalid_action_name", "so is an empty action name")
		assertEquals(Remote.fire("fireCheck", { ok = true }), nil, "a good payload is sent")
		assertEquals(reached, true, "and handled")
	end

	print("Test 8: send() and sendAll() reach Remote.on() on the client")
	do
		asServer(function()
			Remote.sendAll("announce", "warm-up")
		end)
		local received = {}
		local conn = Remote.on("announce", function(payload)
			table.insert(received, payload)
		end)
		asServer(function()
			Remote.sendAll("announce", "double coins")
			Remote.send(game:GetService("Players").LocalPlayer, "announce", { text = "just you" })
		end)
		assertEquals(received[1], "double coins", "sendAll delivers")
		assertEquals(received[2] and received[2].text, "just you", "send delivers to one player")
		conn:Disconnect()
		local folder = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
		assertEquals(folder:FindFirstChild("announce").ClassName, "RemoteEvent", "the server made the event")
		local okReserved = pcall(function()
			asServer(function()
				Remote.sendAll("Response", 1)
			end)
		end)
		assertEquals(okReserved, false, "Request and Response can't be used as event names")
	end

	print("Test 9: unreliable events")
	do
		local got = nil
		asServer(function()
			Remote.sendAll("position", 0, { unreliable = true })
		end)
		local conn = Remote.on("position", function(payload)
			got = payload
		end)
		asServer(function()
			Remote.sendAll("position", 42, { unreliable = true })
		end)
		assertEquals(got, 42, "an unreliable event is received the same way")
		local folder = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
		assertEquals(
			folder:FindFirstChild("position").ClassName,
			"UnreliableRemoteEvent",
			"as an UnreliableRemoteEvent"
		)
		local okMixed = pcall(function()
			asServer(function()
				Remote.sendAll("position", 1)
			end)
		end)
		assertEquals(okMixed, false, "one name can't be sent both ways")
		conn:Disconnect()
	end

	print("Test 10: check rejects a payload before the handler runs")
	do
		local ran = false
		asServer(function()
			Remote.handle("checked", function(_player, payload: any)
				ran = true
				return payload.id
			end, {
				check = function(payload: any)
					return type(payload) == "table" and type(payload.id) == "string"
				end,
			})
		end)
		local _, err = Remote.request("checked", { id = 5 }, 1)
		assertEquals(err, "invalid_payload", "a payload that fails the check is rejected")
		assertEquals(ran, false, "and the handler doesn't run")
		local data = Remote.request("checked", { id = "sword" }, 1)
		assertEquals(data, "sword", "a good payload goes through")
	end

	print("Test 11: middleware runs before every handler")
	do
		local seen = {}
		local remove
		asServer(function()
			remove = Remote.use(function(_player, action, payload: any)
				table.insert(seen, action)
				return not (type(payload) == "table" and payload.banned)
			end)
		end)
		local data = Remote.request("double", { n = 2 }, 1)
		assertEquals(data, 4, "an allowed request goes through")
		local _, err = Remote.request("double", { n = 2, banned = true }, 1)
		assertEquals(err, "rejected", "returning false rejects it")
		assertEquals(seen[1], "double", "the middleware sees the action name")
		remove()
		local _, after = Remote.request("double", { n = 2, banned = true }, 1)
		assertEquals(after, nil, "the remover takes it away")
	end

	print("Test 12: Remote.action ties both sides to one name")
	do
		local Double = Remote.action("doubleAction")
		asServer(function()
			Double.handle(function(_player, payload: any)
				return payload * 2
			end)
		end)
		assertEquals(Double.request(21, 1), 42, "request goes through the action")
		assertEquals(Double.name, "doubleAction", "and it knows its name")
	end

	print("\n========== REMOTE SERVER TESTS COMPLETE ==========\n")
end

return runTests
