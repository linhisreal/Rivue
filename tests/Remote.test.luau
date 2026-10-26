--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function assertTrue(condition: boolean, message: string?)
	if not condition then
		error("Assertion failed: " .. (message or "condition is false"))
	end
	print("✓", message or "Assertion passed")
end

local RunService = game:GetService("RunService")

-- After the client tests: offline, requests loop back to these handlers
local function runServerTests()
	print("Server: request handling")
	do
		-- Offline the stub RunService says client, so pretend to be a server for this part
		local isServer = RunService.IsServer
		if __OFFLINE then
			(RunService :: any).IsServer = function()
				return true
			end
		end
		if not RunService:IsServer() then
			print("  skipped: needs a server")
		else
			local player = Instance.new("Folder") :: any
			local process = Remote._processRequest
			local seen: unknown = nil
			Remote.handle("test:echo", function(from, payload)
				seen = from
				return payload
			end)
			Remote.handle("test:fail", function()
				error("secret details")
			end)
			Remote.handle("test:limited", function()
				return true
			end, { maxPerSecond = 2 })

			local ok = process(player, { action = "test:echo", id = "1", payload = { value = 5 } })
			assertTrue(ok ~= nil and ok.ok == true and ok.id == "1", "a handled request gets an ok reply")
			assertEquals((ok :: any).data.value, 5, "with the handler's result")
			assertTrue(seen == player, "the handler gets the player")

			local failed = process(player, { action = "test:fail", id = "2" })
			assertEquals((failed :: any).error, "handler_error", "a handler error becomes handler_error")
			assertTrue(
				not string.find(tostring((failed :: any).error), "secret", 1, true),
				"without the server's error text"
			)

			local unsafe = process(player, { action = "test:echo", id = "3", payload = { f = print } })
			assertEquals((unsafe :: any).error, "payload_unsafe_type", "functions in the payload are refused")

			local deep = {}
			local node = deep
			for _ = 1, 20 do
				node.next = {}
				node = node.next
			end
			local tooDeep = process(player, { action = "test:echo", id = "4", payload = deep })
			assertEquals((tooDeep :: any).error, "payload_too_deep", "deeply nested payloads are refused")

			assertEquals(
				process(player, { action = "test:echo", payload = 1 }),
				nil,
				"fire() without an id gets no reply"
			)
			assertEquals(process(player, "junk"), nil, "a request that isn't a table is ignored")
			assertEquals(process(player, { action = 5, id = "5" }), nil, "a non-string action is ignored")

			local results = {}
			for i = 1, 3 do
				local reply = process(player, { action = "test:limited", id = `l{i}` })
				results[i] = if reply and reply.ok then "ok" else (reply :: any).error
			end
			assertEquals(table.concat(results, ","), "ok,ok,rate_limited", "maxPerSecond limits each player")
			local other = process(Instance.new("Folder") :: any, { action = "test:limited", id = "o" })
			assertTrue(other ~= nil and other.ok == true, "other players have their own limit")

			local replies = 0
			for i = 1, 40 do
				local reply = process(player, { action = "test:missing", id = `u{i}` })
				if reply and reply.error == "unknown_action" then
					replies += 1
				end
			end
			assertTrue(replies > 0, "unknown actions say so")
			assertTrue(replies <= 31, `replies to unknown actions are limited (got {replies})`)
		end
		if __OFFLINE then
			(RunService :: any).IsServer = isServer
		end
	end
end

local function runTests()
	print("\n========== REMOTE COMMUNICATION TEST SUITE ==========\n")
	if not RunService:IsClient() then
		print("  skipped: Remote's client API needs a client")
		runServerTests()
		return
	end

	print("Test 1: Remote events folder is created")
	do
		Remote.fire("test", {})
		task.wait(0.05)
		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		assertTrue(folder ~= nil, "Should create RemoteEvents folder")
	end

	print("Test 2: fire() creates and uses Request event")
	do
		Remote.fire("testAction", { data = "test" })
		task.wait(0.05)
		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local requestEvent = folder and folder:FindFirstChild("Request")
		assertTrue(requestEvent ~= nil, "Should create Request RemoteEvent")
		assertTrue(requestEvent:IsA("RemoteEvent"), "Should be a RemoteEvent")
	end

	print("Test 3: request() creates Response event")
	do
		-- Nothing answers, so this times out
		task.spawn(function()
			Remote.request("testRequest", { value = 123 }, 0.1)
		end)
		task.wait(0.15)
		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local responseEvent = folder and folder:FindFirstChild("Response")
		assertTrue(responseEvent ~= nil, "Should create Response RemoteEvent")
		assertTrue(responseEvent:IsA("RemoteEvent"), "Should be a RemoteEvent")
	end

	print("Test 4: request() times out properly")
	do
		local data, err = Remote.request("noResponse", { test = true }, 0.1)
		assertTrue(data == nil, "Should return nil data on timeout")
		assertEquals(err, "timeout", "Should return timeout error")
	end

	print("Test 5: on() creates and listens to named event")
	do
		local conn = Remote.on("CustomEvent", function() end)
		task.wait(0.05)
		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local customEvent = folder and folder:FindFirstChild("CustomEvent")
		assertTrue(customEvent ~= nil, "Should create custom RemoteEvent")
		assertTrue(customEvent and customEvent:IsA("RemoteEvent") or false, "Should be a RemoteEvent")
		-- FireClient needs a server, covered by tests/offline/RemoteServer.test.luau
		conn:Disconnect()
	end

	print("Test 6: Payload validation rejects non-serializable data")
	do
		local badPayload = {
			func = function() end,
		}
		local data, err = Remote.request("badPayload", badPayload, 0.1)
		assertTrue(data == nil, "Should reject non-serializable payload")
		assertTrue(err ~= nil, "Should return error for non-serializable payload")
	end

	print("Test 7: Payload validation rejects oversized data")
	do
		local largeString = string.rep("x", 25000)
		local data, err = Remote.request("largePayload", { data = largeString }, 0.1)
		assertTrue(data == nil, "Should reject oversized payload")
		assertEquals(err, "payload_too_large", "Should return payload_too_large error")
	end

	print("Test 8: Payload validation rejects unsafe types")
	do
		local unsafePayload = {
			thread = coroutine.create(function() end),
		}
		local data, err = Remote.request("unsafePayload", unsafePayload, 0.1)
		assertTrue(data == nil, "Should reject unsafe types")
		assertEquals(err, "payload_unsafe_type", "Should return unsafe type error")
	end

	print("Test 9: Action name validation")
	do
		local data, err = Remote.request("", {}, 0.1)
		assertTrue(data == nil, "Should reject empty action name")
		assertEquals(err, "invalid_action_name", "Should return invalid action name error")
	end

	print("Test 10: Multiple listeners can be registered")
	do
		local conn1 = Remote.on("MultiEvent", function() end)
		local conn2 = Remote.on("MultiEvent", function() end)
		task.wait(0.05)

		local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local event = folder and folder:FindFirstChild("MultiEvent")

		assertTrue(event ~= nil, "Should create event for multiple listeners")
		-- Firing to clients needs a server, covered by tests/offline/RemoteServer.test.luau
		conn1:Disconnect()
		conn2:Disconnect()
	end

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
		local ok = pcall(function()
			Remote.fire("validPayload", validPayload)
		end)
		assertTrue(ok, "Should accept valid payload")
	end

	runServerTests()

	print("\n========== REMOTE COMMUNICATION TESTS COMPLETE ==========\n")
end

return runTests
