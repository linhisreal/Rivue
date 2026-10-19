--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

-- Offline only: swaps RunService.IsServer/IsClient to run both sides of Remote in one VM, which
-- Studio can't do

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService") :: any
local Remote = require(ReplicatedStorage:WaitForChild("RivueRemote"))
local DEFAULT_REPLIES = 30

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

local function assertTrue(condition: boolean, message: string)
	if not condition then
		error("Assertion failed: " .. message)
	end
	print("✓", message)
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

	print("Test 0: requests reach the DevTools timeline")
	do
		local Rivue = require(game:GetService("ReplicatedStorage"):WaitForChild("RivueUI"))
		local App = Rivue.defineComponent({
			name = "TimelineProbe",
			render = function()
				return Rivue.h("Frame")
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(App)
		app.config.devtools = true
		app:mount(folder)
		Remote.request("double", { n = 3 }, 1)
		local channel = folder:FindFirstChild("RivueDevTools")
		local timeline = channel:GetAttribute("RivueTimeline")
		assertEquals(string.find(timeline, "\trequest\t", 1, true) ~= nil, true, "a plain request is on the timeline")
		assertTrue(string.find(timeline, "\tdouble\tok · %d+ B") ~= nil, "with its outcome and payload size")
		Remote.fire("double", { n = 1 })
		assertTrue(
			string.find(channel:GetAttribute("RivueTimeline"), "\tsend\t\tdouble\t", 1, true) ~= nil,
			"fire() shows as a send"
		)
		local pinged = false
		local ping = Remote.on("timelinePing", function()
			pinged = true
		end)
		asServer(function()
			Remote.send(game:GetService("Players").LocalPlayer, "timelinePing", { a = 1 })
		end)
		task.wait()
		task.wait()
		ping:Disconnect()
		assertTrue(pinged, "the event arrives")
		assertTrue(
			string.find(channel:GetAttribute("RivueTimeline"), "\tevent\t\ttimelinePing\t", 1, true) ~= nil,
			"events from the server show as events"
		)
		app:unmount()
	end

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
		local position = Vector3.new(1, 2, 3)
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

	print("Test 8: send() and sendAll() reach Remote.on() on the client, batched per frame")
	do
		local received = {}
		local conn = Remote.on("announce", function(payload)
			table.insert(received, payload)
		end)
		local folder = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
		local events = folder:FindFirstChild("Events")
		local fired = 0
		local count = events.OnClientEvent:Connect(function()
			fired += 1
		end)
		asServer(function()
			Remote.sendAll("announce", "double coins")
			Remote.send(game:GetService("Players").LocalPlayer, "announce", { text = "just you" })
		end)
		assertEquals(#received, 0, "nothing is sent before the end of the frame")
		task.wait()
		assertEquals(received[1], "double coins", "sendAll delivers")
		assertEquals(received[2] and received[2].text, "just you", "send delivers to one player, in order")
		assertEquals(fired, 1, "both travel in one message")
		assertEquals(folder:FindFirstChild("announce"), nil, "no RemoteEvent per event name")
		asServer(function()
			Remote.sendAll("announce", "now")
			Remote.flush()
		end)
		assertEquals(received[3], "now", "flush() sends straight away")
		count:Disconnect()
		conn:Disconnect()
		asServer(function()
			Remote.sendAll("announce", "after")
			Remote.flush()
		end)
		assertEquals(#received, 3, "a disconnected listener hears nothing more")
	end

	print("Test 9: unreliable events")
	do
		local got = nil
		local conn = Remote.on("position", function(payload)
			got = payload
		end)
		asServer(function()
			Remote.sendAll("position", 42, { unreliable = true })
		end)
		assertEquals(got, 42, "an unreliable event arrives straight away, outside the batch")
		asServer(function()
			Remote.send(game:GetService("Players").LocalPlayer, "position", 7, { unreliable = true })
		end)
		assertEquals(got, 7, "send works unreliably too")
		local folder = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
		assertEquals(
			folder:FindFirstChild("UnreliableEvents").ClassName,
			"UnreliableRemoteEvent",
			"through one UnreliableRemoteEvent"
		)
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

	print("Test 13: limits across all actions, and configure()")
	do
		Remote.configure({ maxRequestsPerSecond = 3 })
		local errors = {}
		for i = 1, 4 do
			local action = if i % 2 == 0 then "double" else "fireCheck"
			local _, err = Remote.request(action, { n = 1 }, 1)
			errors[i] = err or "ok"
		end
		assertEquals(
			table.concat(errors, ","),
			"ok,ok,ok,rate_limited",
			"the 4th request in a second is refused, whatever the action"
		)
		Remote.configure({ maxRequestsPerSecond = 60 })
		task.wait(1)

		Remote.configure({ maxBytesPerSecond = 100 })
		local _, small = Remote.request("double", { n = 1 }, 1)
		assertEquals(small, nil, "a small payload fits the byte budget")
		local _, big = Remote.request("echoType", { blob = string.rep("x", 200) }, 1)
		assertEquals(big, "rate_limited", "one over the byte budget is refused")
		Remote.configure({ maxBytesPerSecond = 50000 })

		Remote.configure({ maxPayloadSize = 50 })
		local _, tooBig = Remote.request("double", { n = 1, pad = string.rep("x", 60) }, 1)
		assertEquals(tooBig, "payload_too_large", "maxPayloadSize applies")
		Remote.configure({ maxPayloadSize = 20000 })
		local okUnknown = pcall(Remote.configure, { maxFoo = 1 } :: any)
		assertEquals(okUnknown, false, "an unknown setting errors")
	end

	print("Test 14: stats")
	do
		Remote.resetStats()
		Remote.request("double", { n = 1 }, 1)
		Remote.request("double", { n = 2 }, 1)
		Remote.request("boom", {}, 1)
		Remote.request("checked", { id = 1 }, 1)
		local stats = Remote.stats()
		assertEquals(stats.double.calls, 2, "handler calls are counted")
		assertEquals(stats.boom.failed, 1, "errors are counted")
		assertEquals(stats.checked.rejected, 1, "refused requests are counted")
		assertEquals(type(stats.double.maxTime), "number", "with handler time")
		Remote.resetStats()
		assertEquals(next(Remote.stats()), nil, "resetStats clears them")
	end

	print("Test 15: replicated state")
	do
		local Rivue = require(game:GetService("ReplicatedStorage"):WaitForChild("RivueUI"))
		local me = game:GetService("Players").LocalPlayer
		local round: any, coins: any
		asServer(function()
			round = Remote.state("round", { phase = "lobby" })
			coins = Remote.state("coins", 0)
			coins.setFor(me, 25)
		end)
		assertEquals(Remote.getState("round").phase, "lobby", "a late joiner gets the current value")
		assertEquals(Remote.getState("coins"), 25, "and its own per-player value")
		local heard = {}
		local conn = Remote.onState("round", function(value)
			table.insert(heard, value.phase)
		end)
		asServer(function()
			round.set({ phase = "playing" })
		end)
		task.wait()
		assertEquals(Remote.getState("round").phase, "playing", "changes arrive with the frame's other sends")
		assertEquals(heard[1], "playing", "onState hears them")
		conn:Disconnect()
		asServer(function()
			coins.set(5)
		end)
		task.wait()
		assertEquals(Remote.getState("coins"), 25, "a per-player value wins over the shared one")
		asServer(function()
			coins.setFor(me, nil)
		end)
		task.wait()
		assertEquals(Remote.getState("coins"), 5, "until it's cleared")
		asServer(function()
			assertEquals(coins.get(me), 5, "get() on the server")
			assertEquals(round.set({ bad = print }), "payload_unsafe_type", "values are checked like payloads")
		end)

		local shown = nil
		local Hud = Rivue.defineComponent({
			name = "CoinsHud",
			setup = function()
				local value = Remote.useState("coins", 0)
				return { value = value }
			end,
			render = function(ctx)
				shown = ctx.value
				return Rivue.h("TextLabel")
			end,
		})
		local app = Rivue.createApp(Hud)
		app:mount(Instance.new("Folder"))
		assertEquals(shown, 5, "useState starts from the loaded value")
		asServer(function()
			coins.set(9)
		end)
		task.wait()
		Rivue.nextTick()
		assertEquals(shown, 9, "and re-renders when it changes")
		app:unmount()
	end

	print("Test 15b: a state created after the client loaded the others")
	do
		local late: any
		asServer(function()
			late = Remote.state("late", { open = true })
		end)
		task.wait()
		assertEquals(
			Remote.getState("late") and Remote.getState("late").open,
			true,
			"reaches clients already in the game"
		)
		asServer(function()
			late.set(nil)
		end)
		task.wait()
		task.wait()
		assertEquals(Remote.getState("late"), nil, "and so does setting it to nil")
	end

	print("Test 16: Remote.on inside setup disconnects on unmount")
	do
		local Rivue = require(game:GetService("ReplicatedStorage"):WaitForChild("RivueUI"))
		local heard = 0
		local Toast = Rivue.defineComponent({
			name = "Toast",
			setup = function()
				Remote.on("toast", function()
					heard += 1
				end)
				return {}
			end,
			render = function()
				return Rivue.h("Frame")
			end,
		})
		local app = Rivue.createApp(Toast)
		app:mount(Instance.new("Folder"))
		asServer(function()
			Remote.sendAll("toast", "hi")
			Remote.flush()
		end)
		assertEquals(heard, 1, "it listens while mounted")
		app:unmount()
		asServer(function()
			Remote.sendAll("toast", "hi")
			Remote.flush()
		end)
		assertEquals(heard, 1, "and stops when the component unmounts")
	end

	print("Test 17: useRequest")
	do
		local Rivue = require(game:GetService("ReplicatedStorage"):WaitForChild("RivueUI"))
		local state: any = nil
		local Page = Rivue.defineComponent({
			name = "DoublePage",
			setup = function()
				state = Remote.useRequest("double", { payload = { n = 4 } })
				return {}
			end,
			render = function()
				return Rivue.h("Frame")
			end,
		})
		local app = Rivue.createApp(Page)
		app:mount(Instance.new("Folder"))
		task.wait()
		assertEquals(state.data.value, 8, "it runs straight away and keeps the result")
		assertEquals(state.loading.value, false, "loading is done")
		state.run({ n = 10 })
		task.wait()
		assertEquals(state.data.value, 20, "run() sends a new payload")
		local failing = nil
		Rivue.effectScope():run(function()
			failing = Remote.useRequest("boom")
		end)
		task.wait()
		assertEquals(failing.error.value, "handler_error", "errors land in error")
		app:unmount()
	end

	print("Test 18: exploit-shaped requests are refused cheaply")
	do
		local folder = ReplicatedStorage:WaitForChild("RemoteEvents")
		local requestEvent = folder:WaitForChild("Request") :: RemoteEvent
		local responseEvent = folder:WaitForChild("Response") :: RemoteEvent
		local replies: { any } = {}
		local conn = responseEvent.OnClientEvent:Connect(function(reply)
			table.insert(replies, reply)
		end)
		local function raw(request: any): any?
			table.clear(replies)
			requestEvent:FireServer(request)
			task.wait()
			return replies[1]
		end
		task.wait(1)

		local nan = raw({ action = "double", id = 1, payload = { n = 0 / 0 } })
		assertEquals(nan and nan.error, "payload_bad_number", "NaN is refused")
		local inf = raw({ action = "double", id = 2, payload = { n = math.huge } })
		assertEquals(inf and inf.error, "payload_bad_number", "and so is infinity")
		local fine = raw({ action = "double", id = 3, payload = { n = 4 } })
		assertEquals(fine and fine.data, 8, "ordinary numbers still work")

		assertEquals(
			raw({ action = "double", id = string.rep("x", 5000), payload = { n = 1 } }),
			nil,
			"a string id gets no reply"
		)
		assertEquals(
			raw({ action = string.rep("a", 5000), id = 4, payload = {} }),
			nil,
			"an oversized action name is dropped"
		)

		local overridden = pcall(function()
			asServer(function()
				Remote.handle("__rivueStateSync", function()
					return nil
				end)
			end)
		end)
		assertEquals(overridden, false, "Rivue's internal actions can't be replaced")

		local active, most = 0, 0
		asServer(function()
			Remote.handle("withdraw", function()
				active += 1
				most = math.max(most, active)
				task.wait(0.05)
				active -= 1
				return true
			end, { exclusive = true })
		end)
		table.clear(replies)
		task.spawn(requestEvent.FireServer, requestEvent, { action = "withdraw", id = 10, payload = {} })
		task.spawn(requestEvent.FireServer, requestEvent, { action = "withdraw", id = 11, payload = {} })
		task.wait(0.2)
		assertEquals(most, 1, "an exclusive handler runs one call per player at a time")
		local busy = false
		for _, reply in replies do
			if reply.error == "busy" then
				busy = true
			end
		end
		assertTrue(busy, "and refuses overlapping calls instead of queueing them")

		asServer(function()
			Remote.handle("crash", function()
				error("nope")
			end)
		end)
		local warnings = 0
		local logConn = game:GetService("LogService").MessageOut:Connect(function(message)
			if string.find(message, "Remote handler 'crash' failed", 1, true) then
				warnings += 1
			end
		end)
		for i = 1, 5 do
			raw({ action = "crash", id = 100 + i, payload = {} })
		end
		logConn:Disconnect()
		assertEquals(warnings, 1, "a failing handler can't flood the output")
		conn:Disconnect()
	end

	print("Test 19: a flooding client can't make the server work or reply for free")
	do
		local folder = ReplicatedStorage:WaitForChild("RemoteEvents")
		local requestEvent = folder:WaitForChild("Request") :: RemoteEvent
		local responseEvent = folder:WaitForChild("Response") :: RemoteEvent
		local replies: { any } = {}
		local conn = responseEvent.OnClientEvent:Connect(function(reply)
			table.insert(replies, reply)
		end)

		task.wait(1.1)
		for i = 1, 500 do
			requestEvent:FireServer({ action = "double", id = 1000 + i, payload = { n = 1 } })
		end
		task.wait()
		local refused = 0
		for _, reply in replies do
			if reply.error == "rate_limited" then
				refused += 1
			end
		end
		assertTrue(refused <= DEFAULT_REPLIES, `refusals are answered at a capped rate (got {refused})`)

		task.wait(1.1)
		local junk = { string.rep("x", 19000), 0 / 0 }
		for i = 1, 10 do
			requestEvent:FireServer({ action = "double", id = 2000 + i, payload = junk })
		end
		table.clear(replies)
		requestEvent:FireServer({ action = "double", id = 3000, payload = { n = 1, note = string.rep("x", 15000) } })
		task.wait()
		assertEquals(
			replies[1] and replies[1].error,
			"rate_limited",
			`payloads that fail validation still use up the byte budget`
		)
		conn:Disconnect()

		for _, name in { "Response", "Events", "UnreliableEvents" } do
			local event = folder:FindFirstChild(name) :: any
			assertTrue(
				event ~= nil and #event.OnServerEvent._conns > 0,
				`{name} has a server listener, so client fires are dropped instead of queued`
			)
		end
	end

	print("Test 20: datatypes can't smuggle NaN, and one player can't park endless handlers")
	do
		task.wait(1.1)
		local smuggled = {
			Vector3.new(0 / 0, 0, 0),
			Vector2.new(math.huge, 0),
			UDim2.new(0, -math.huge, 0, 0),
			Color3.new(0 / 0, 0, 0),
		}
		for _, value in smuggled do
			local response = Remote._processRequest(
				game:GetService("Players").LocalPlayer,
				{ action = "double", id = 1, payload = { at = value } }
			)
			assertEquals(
				response and response.error,
				"payload_bad_number",
				`a {typeof(value)} holding NaN or infinity is refused`
			)
		end
		local plain = Remote._processRequest(
			game:GetService("Players").LocalPlayer,
			{ action = "double", id = 2, payload = { n = 2, at = Vector3.new(1, 2, 3) } }
		)
		assertEquals(plain and plain.data, 4, "ordinary datatypes still pass")

		local inFlight, most = 0, 0
		asServer(function()
			Remote.handle("slowSave", function()
				inFlight += 1
				most = math.max(most, inFlight)
				task.wait(0.3)
				inFlight -= 1
				return true
			end, { maxPerSecond = 0 })
		end)
		local folder = ReplicatedStorage:WaitForChild("RemoteEvents")
		local requestEvent = folder:WaitForChild("Request") :: RemoteEvent
		for i = 1, 40 do
			task.spawn(requestEvent.FireServer, requestEvent, { action = "slowSave", id = 4000 + i, payload = {} })
		end
		task.wait(0.5)
		assertTrue(most <= 10, `a player can only have a few handlers running at once (got {most})`)
	end

	print("\n========== REMOTE SERVER TESTS COMPLETE ==========\n")
end

return runTests
