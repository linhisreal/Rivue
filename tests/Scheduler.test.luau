--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = ReplicatedStorage:WaitForChild("RivueUI")
local scheduler = require(Rivue:WaitForChild("runtime"):WaitForChild("scheduler"))
local RivueUI = require(Rivue)

local TestSupport = require(game:GetService("ReplicatedStorage"):WaitForChild("TestSupport"))
local assertEquals = TestSupport.assertEquals
local assertTrue = TestSupport.assertTrue
local assertFalse = TestSupport.assertFalse

local function runTests()
	print("\n========== SCHEDULER TEST SUITE ==========\n")

	print("Test 1: queueJob micro mode executes function")
	do
		local executed = false
		scheduler.queueJob(function()
			executed = true
		end, { mode = "micro" })
		task.wait(0.1)
		assertTrue(executed, "Micro job should have executed")
	end

	print("Test 2: queueJob micro mode deduplicates same function")
	do
		local count = 0
		local fn = function()
			count += 1
		end
		scheduler.queueJob(fn, { mode = "micro" })
		scheduler.queueJob(fn, { mode = "micro" })
		scheduler.queueJob(fn, { mode = "micro" })
		task.wait(0.1)
		assertTrue(count == 1, "Should execute only once due to deduplication")
	end

	print("Test 3: queueJob micro mode allows re-queue after flush")
	do
		local count = 0
		local fn = function()
			count += 1
		end
		scheduler.queueJob(fn, { mode = "micro" })
		task.wait(0.1)
		assertEquals(count, 1, "First execution should complete")
		scheduler.queueJob(fn, { mode = "micro" })
		task.wait(0.1)
		assertEquals(count, 2, "Should allow re-queue after flush")
	end

	print("Test 4: queueJob micro mode cancels correctly")
	do
		local executed = false
		local handle = scheduler.queueJob(function()
			executed = true
		end, { mode = "micro" })
		handle.cancel()
		task.wait(0.1)
		assertFalse(executed, "Cancelled job should not execute")
	end

	print("Test 5: queueJob micro mode batches multiple different functions")
	do
		local count1, count2, count3 = 0, 0, 0
		scheduler.queueJob(function()
			count1 += 1
		end, { mode = "micro" })
		scheduler.queueJob(function()
			count2 += 1
		end, { mode = "micro" })
		scheduler.queueJob(function()
			count3 += 1
		end, { mode = "micro" })
		task.wait(0.1)
		assertTrue(count1 == 1 and count2 == 1 and count3 == 1, "All different jobs should execute")
	end

	print("Test 6: queueJob render mode executes on next RenderStepped")
	do
		local executed = false
		scheduler.queueJob(function()
			executed = true
		end, { mode = "render" })
		task.wait(0.1)
		assertTrue(executed, "Render job should have executed")
	end

	print("Test 7: queueJob render mode cancels correctly")
	do
		local executed = false
		local handle = scheduler.queueJob(function()
			executed = true
		end, { mode = "render" })
		handle.cancel()
		task.wait(0.1)
		assertFalse(executed, "Cancelled render job should not execute")
	end

	print("Test 8: queueJob heartbeat mode executes on next Heartbeat")
	do
		local executed = false
		scheduler.queueJob(function()
			executed = true
		end, { mode = "heartbeat" })
		task.wait(0.1)
		assertTrue(executed, "Heartbeat job should have executed")
	end

	print("Test 9: queueJob heartbeat mode cancels correctly")
	do
		local executed = false
		local handle = scheduler.queueJob(function()
			executed = true
		end, { mode = "heartbeat" })
		handle.cancel()
		task.wait(0.1)
		assertFalse(executed, "Cancelled heartbeat job should not execute")
	end

	print("Test 10: queueJob micro mode handles errors gracefully")
	do
		local executed = false
		scheduler.queueJob(function()
			error("Test error")
		end, { mode = "micro" })
		scheduler.queueJob(function()
			executed = true
		end, { mode = "micro" })
		task.wait(0.1)
		assertTrue(executed, "Subsequent jobs should execute even after error")
	end

	print("Test 11: queueJob defaults to micro mode")
	do
		local executed = false
		scheduler.queueJob(function()
			executed = true
		end)
		task.wait(0.1)
		assertTrue(executed, "Should default to micro mode")
	end

	print("Test 12: Multiple render jobs execute in order")
	do
		local order = {}
		scheduler.queueJob(function()
			table.insert(order, 1)
		end, { mode = "render" })
		scheduler.queueJob(function()
			table.insert(order, 2)
		end, { mode = "render" })
		scheduler.queueJob(function()
			table.insert(order, 3)
		end, { mode = "render" })
		task.wait(0.1)
		assertEquals(#order, 3, "All render jobs should execute")
	end

	print("Test 13: Multiple heartbeat jobs execute in order")
	do
		local order = {}
		scheduler.queueJob(function()
			table.insert(order, 1)
		end, { mode = "heartbeat" })
		scheduler.queueJob(function()
			table.insert(order, 2)
		end, { mode = "heartbeat" })
		scheduler.queueJob(function()
			table.insert(order, 3)
		end, { mode = "heartbeat" })
		task.wait(0.1)
		assertEquals(#order, 3, "All heartbeat jobs should execute")
	end

	print("Test 14: Scheduler supports different flush modes")
	do
		local microExecuted = false
		local renderExecuted = false
		local heartbeatExecuted = false

		scheduler.queueJob(function()
			microExecuted = true
		end, { mode = "micro" })

		scheduler.queueJob(function()
			renderExecuted = true
		end, { mode = "render" })

		scheduler.queueJob(function()
			heartbeatExecuted = true
		end, { mode = "heartbeat" })

		task.wait(0.15)
		assertTrue(microExecuted and renderExecuted and heartbeatExecuted, "All flush modes should execute")
	end

	print("Test 15: Effects that keep re-triggering each other are stopped")
	do
		local a, b = RivueUI.ref(0), RivueUI.ref(0)
		local runs = 0
		local first = RivueUI.effect(function()
			runs += 1
			b.value = a.value + 1
		end)
		local second = RivueUI.effect(function()
			runs += 1
			a.value = b.value + 1
		end)
		task.wait(0.3)
		local settled = runs
		task.wait(0.3)
		first:stop()
		second:stop()
		assertEquals(runs, settled, "The loop should stop instead of running every frame")
		assertTrue(runs <= 210, `The loop should stop within one flush, ran {runs} times`)
	end

	local function fakeComponent(id: number, source: { value: number }): () -> number?
		local rendered: number?
		local runner: () -> ()
		local job = {
			id = id,
			run = function()
				runner()
			end,
		}
		RivueUI.effect(function()
			rendered = source.value
		end, {
			scheduler = function(run: () -> ())
				runner = run
				scheduler.queueUpdate(job)
			end,
		})
		return function()
			return rendered
		end
	end

	print("Test 16: nextTick waits for updates queued by a watcher")
	do
		local a, b = RivueUI.ref(0), RivueUI.ref(0)
		RivueUI.watch(a, function(value: number)
			b.value = value * 10
		end)
		local view = fakeComponent(1, b)
		task.wait(0.05)
		a.value = 1
		local seen: number?
		scheduler.nextTick(function()
			seen = view()
		end)
		task.wait(0.1)
		assertEquals(seen, 10, "nextTick should see the component updated by the watcher")
	end

	print("Test 17: nextTick waits when a component update was queued before the watcher")
	do
		local a, b = RivueUI.ref(0), RivueUI.ref(0)
		fakeComponent(1, a)
		RivueUI.watch(a, function(value: number)
			b.value = value * 10
		end)
		local view = fakeComponent(2, b)
		task.wait(0.05)
		a.value = 1
		local seen: number?
		task.spawn(function()
			scheduler.nextTick()
			seen = view()
		end)
		task.wait(0.1)
		assertEquals(seen, 10, "A yielding nextTick should resume after the whole cascade")
	end

	print("Test 18: A duplicate micro job returns a handle that cancels the queued job")
	do
		local count = 0
		local fn = function()
			count += 1
		end
		scheduler.queueJob(fn)
		scheduler.queueJob(fn).cancel()
		task.wait(0.05)
		assertEquals(count, 0, "Cancelling the duplicate's handle should cancel the queued job")
	end

	print("Test 19: A stale handle doesn't affect a job queued later")
	do
		local count = 0
		local fn = function()
			count += 1
		end
		local stale = scheduler.queueJob(fn)
		task.wait(0.05)
		scheduler.queueJob(fn)
		stale.cancel()
		scheduler.queueJob(fn)
		task.wait(0.05)
		assertEquals(count, 2, "The later job should still run exactly once")
	end

	print("\n========== SCHEDULER TESTS COMPLETE ==========\n")
end

return runTests
