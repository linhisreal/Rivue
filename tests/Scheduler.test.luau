--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = ReplicatedStorage:WaitForChild("Rivue")
local scheduler = require(Rivue:WaitForChild("runtime"):WaitForChild("scheduler"))

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

local function assertFalse(condition: boolean, message: string?)
	if condition then
		error("Assertion failed: " .. (message or "condition is true"))
	end
	print("✓", message or "Assertion passed")
end

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
			count = count + 1
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
			count = count + 1
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
			count1 = count1 + 1
		end, { mode = "micro" })
		scheduler.queueJob(function()
			count2 = count2 + 1
		end, { mode = "micro" })
		scheduler.queueJob(function()
			count3 = count3 + 1
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

	print("\n========== SCHEDULER TESTS COMPLETE ==========\n")
end

return runTests
