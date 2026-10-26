--!strict
--[[
	Remote Server Tests (offline only)
	==================================
	
	Swaps RunService.IsServer/IsClient to drive both sides of Remote in one VM,
	which isn't possible in Studio.
]]

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

	print("\n========== REMOTE SERVER TESTS COMPLETE ==========\n")
end

return runTests
