--!strict
--[[
	Remote Communication Unit Tests
	================================
	
	Tests for remote.luau - request/response patterns and event handling
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("remote"))

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

local function assertTrue(condition: boolean, message: string?)
	if not condition then
		error("Assertion failed: " .. (message or "condition is false"))
	end
	print("✓", message or "Assertion passed")
end

local function runTests()
	print("\n========== REMOTE COMMUNICATION TEST SUITE ==========\n")

	-- Test 1: Remote events folder is created
	print("Test 1: Remote events folder is created")
	do
		-- Just calling any remote function should create the folder
		Remote.fire("test", {})
		task.wait(0.05)
		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		assertTrue(folder ~= nil, "Should create RemoteEvents folder")
	end

	-- Test 2: fire() creates and uses Request event
	print("Test 2: fire() creates and uses Request event")
	do
		Remote.fire("testAction", { data = "test" })
		task.wait(0.05)
		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local requestEvent = folder and folder:FindFirstChild("Request")
		assertTrue(requestEvent ~= nil, "Should create Request RemoteEvent")
		assertTrue(requestEvent:IsA("RemoteEvent"), "Should be a RemoteEvent")
	end

	-- Test 3: request() creates Response event
	print("Test 3: request() creates Response event")
	do
		-- Start request (will timeout but that's ok)
		task.spawn(function()
			Remote.request("testRequest", { value = 123 }, 0.1)
		end)
		task.wait(0.15)
		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local responseEvent = folder and folder:FindFirstChild("Response")
		assertTrue(responseEvent ~= nil, "Should create Response RemoteEvent")
		assertTrue(responseEvent:IsA("RemoteEvent"), "Should be a RemoteEvent")
	end

	-- Test 4: request() times out properly
	print("Test 4: request() times out properly")
	do
		local data, err = Remote.request("noResponse", { test = true }, 0.1)
		assertTrue(data == nil, "Should return nil data on timeout")
		assertEquals(err, "timeout", "Should return timeout error")
	end

	-- Test 5: on() creates and listens to named event
	print("Test 5: on() creates and listens to named event")
	do
		local conn = Remote.on("CustomEvent", function()
			-- Event handler registered
		end)
		task.wait(0.05)
		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local customEvent = folder and folder:FindFirstChild("CustomEvent")
		assertTrue(customEvent ~= nil, "Should create custom RemoteEvent")
		assertTrue(customEvent and customEvent:IsA("RemoteEvent") or false, "Should be a RemoteEvent")
		-- Note: Cannot test FireClient from client - would need server-side test
		conn:Disconnect()
	end

	-- Test 6: Payload validation rejects non-serializable data
	print("Test 6: Payload validation rejects non-serializable data")
	do
		local badPayload = {
			func = function() end, -- Functions can't be serialized
		}
		local data, err = Remote.request("badPayload", badPayload, 0.1)
		assertTrue(data == nil, "Should reject non-serializable payload")
		assertTrue(err ~= nil, "Should return error for non-serializable payload")
	end

	-- Test 7: Payload validation rejects oversized data
	print("Test 7: Payload validation rejects oversized data")
	do
		-- Create a payload larger than 20KB
		local largeString = string.rep("x", 25000)
		local data, err = Remote.request("largePayload", { data = largeString }, 0.1)
		assertTrue(data == nil, "Should reject oversized payload")
		assertEquals(err, "payload_too_large", "Should return payload_too_large error")
	end

	-- Test 8: Payload validation rejects unsafe types
	print("Test 8: Payload validation rejects unsafe types")
	do
		local unsafePayload = {
			instance = Instance.new("Part"), -- Instances not allowed
		}
		local data, err = Remote.request("unsafePayload", unsafePayload, 0.1)
		assertTrue(data == nil, "Should reject unsafe types")
		assertEquals(err, "payload_unsafe_type", "Should return unsafe type error")
	end

	-- Test 9: Action name validation
	print("Test 9: Action name validation")
	do
		local data, err = Remote.request("", {}, 0.1)
		assertTrue(data == nil, "Should reject empty action name")
		assertEquals(err, "invalid_action_name", "Should return invalid action name error")
	end

	-- Test 10: Multiple listeners can be registered
	print("Test 10: Multiple listeners can be registered")
	do
		local conn1 = Remote.on("MultiEvent", function()
			-- Handler 1
		end)
		local conn2 = Remote.on("MultiEvent", function()
			-- Handler 2
		end)
		task.wait(0.05)

		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local event = folder and folder:FindFirstChild("MultiEvent")

		assertTrue(event ~= nil, "Should create event for multiple listeners")
		-- Note: Cannot test firing from client - would need server-side test
		conn1:Disconnect()
		conn2:Disconnect()
	end

	-- Test 11: fire() accepts valid payloads
	print("Test 11: fire() accepts valid payloads")
	do
		local validPayload = {
			string = "test",
			number = 123,
			boolean = true,
			nested = {
				array = { 1, 2, 3 },
				object = { key = "value" },
			},
		}
		-- Should not error
		local ok = pcall(function()
			Remote.fire("validPayload", validPayload)
		end)
		assertTrue(ok, "Should accept valid payload")
	end

	print("\n========== REMOTE COMMUNICATION TESTS COMPLETE ==========\n")
end

return runTests
