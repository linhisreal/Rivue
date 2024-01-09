--!strict
--[[
	Utils Unit Tests
	================
	
	Tests for throttle, debounce, nextTick, nextFrame, and iterArray
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))

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
	print("\n========== UTILS TEST SUITE ==========\n")

	-- Test 1: Debounce delays execution
	print("Test 1: debounce delays execution")
	do
		local count = 0
		local debounced = Rivue.utils.debounce(function()
			count = count + 1
		end, 100)
		debounced()
		debounced()
		debounced()
		assertEquals(count, 0, "Should not execute immediately")
		task.wait(0.15)
		assertEquals(count, 1, "Should execute once after delay")
	end

	-- Test 2: Debounce can be cancelled
	print("Test 2: debounce can be cancelled")
	do
		local executed = false
		local debounced = Rivue.utils.debounce(function()
			executed = true
		end, 100)
		local handle = debounced()
		handle.cancel()
		task.wait(0.15)
		assertFalse(executed, "Cancelled debounce should not execute")
	end

	-- Test 3: Debounce auto-converts seconds to milliseconds
	print("Test 3: debounce auto-converts seconds to milliseconds")
	do
		local count = 0
		local debounced = Rivue.utils.debounce(function()
			count = count + 1
		end, 0.1)
		debounced()
		task.wait(0.15)
		assertEquals(count, 1, "Should auto-convert 0.1 seconds to 100ms")
	end

	-- Test 4: Throttle limits execution frequency
	print("Test 4: throttle limits execution frequency")
	do
		local count = 0
		local throttled = Rivue.utils.throttle(function()
			count = count + 1
		end, 100)
		throttled()
		throttled()
		throttled()
		assertEquals(count, 1, "Should execute immediately once")
		task.wait(0.15)
		assertTrue(count <= 2, "Should throttle subsequent calls")
	end

	-- Test 5: Throttle executes immediately on first call
	print("Test 5: throttle executes immediately on first call")
	do
		local count = 0
		local throttled = Rivue.utils.throttle(function()
			count = count + 1
		end, 100)
		throttled()
		assertEquals(count, 1, "Should execute immediately on first call")
	end

	-- Test 6: Throttle auto-converts seconds to milliseconds
	print("Test 6: throttle auto-converts seconds to milliseconds")
	do
		local count = 0
		local throttled = Rivue.utils.throttle(function()
			count = count + 1
		end, 0.1)
		throttled()
		assertEquals(count, 1, "Should auto-convert 0.1 seconds to 100ms")
		task.wait(0.15)
		throttled()
		assertEquals(count, 2, "Should allow second call after interval")
	end

	-- Test 7: nextTick defers execution
	print("Test 7: nextTick defers execution")
	do
		local executed = false
		Rivue.utils.nextTick(function()
			executed = true
		end)
		assertFalse(executed, "nextTick should defer execution")
		task.wait(0.05)
		assertTrue(executed, "nextTick should execute after deferral")
	end

	-- Test 8: nextFrame defers to next Heartbeat
	print("Test 8: nextFrame defers to next Heartbeat")
	do
		local executed = false
		Rivue.utils.nextFrame(function()
			executed = true
		end)
		assertFalse(executed, "nextFrame should defer execution")
		task.wait(0.1)
		assertTrue(executed, "nextFrame should execute after Heartbeat")
	end

	-- Test 9: iterArray iterates reactive arrays
	print("Test 9: iterArray iterates reactive arrays")
	do
		local arr = Rivue.reactive({ 1, 2, 3 })
		local sum = 0
		for _, v in Rivue.iterArray(arr) do
			sum = sum + v
		end
		assertEquals(sum, 6, "Should iterate all elements and sum to 6")
	end

	-- Test 10: iterArray works with non-reactive arrays
	print("Test 10: iterArray works with non-reactive arrays")
	do
		local arr = { 10, 20, 30 }
		local sum = 0
		for _, v in Rivue.iterArray(arr) do
			sum = sum + v
		end
		assertEquals(sum, 60, "Should work with non-reactive arrays")
	end

	-- Test 11: iterArray handles empty arrays
	print("Test 11: iterArray handles empty arrays")
	do
		local arr = Rivue.reactive({})
		local count = 0
		for _, _ in Rivue.iterArray(arr) do
			count = count + 1
		end
		assertEquals(count, 0, "Should handle empty arrays")
	end

	-- Test 12: useRaf runs on every RenderStepped frame
	print("Test 12: useRaf runs on every RenderStepped frame")
	do
		local frameCount = 0
		local handle = Rivue.utils.useRaf(function(dt)
			frameCount = frameCount + 1
			assertTrue(type(dt) == "number", "Should receive delta time")
		end)
		task.wait(0.1)
		assertTrue(frameCount > 0, "Should execute on RenderStepped frames")
		handle.stop()
		local prevCount = frameCount
		task.wait(0.1)
		assertEquals(frameCount, prevCount, "Should stop after handle.stop()")
	end

	-- Test 13: Profiler tracks execution time
	print("Test 13: Profiler tracks execution time")
	do
		Rivue.utils.profiler:start("test-operation")
		task.wait(0.05)
		local elapsed = Rivue.utils.profiler:stop("test-operation")
		assertTrue(elapsed ~= nil and elapsed > 0, "Should track elapsed time")
		assertTrue(elapsed >= 0.05, "Elapsed time should be at least delay duration")
	end

	-- Test 14: Profiler handles multiple operations
	print("Test 14: Profiler handles multiple operations")
	do
		Rivue.utils.profiler:start("op1")
		Rivue.utils.profiler:start("op2")
		task.wait(0.03)
		local elapsed1 = Rivue.utils.profiler:stop("op1")
		local elapsed2 = Rivue.utils.profiler:stop("op2")
		assertTrue(elapsed1 ~= nil and elapsed2 ~= nil, "Should track multiple operations")
	end

	-- Test 15: shallowEqual compares primitives
	print("Test 15: shallowEqual compares primitives")
	do
		assertTrue(Rivue.utils.shallowEqual(1, 1), "Should be equal for same numbers")
		assertFalse(Rivue.utils.shallowEqual(1, 2), "Should not be equal for different numbers")
		assertTrue(Rivue.utils.shallowEqual("test", "test"), "Should be equal for same strings")
		assertFalse(Rivue.utils.shallowEqual("a", "b"), "Should not be equal for different strings")
	end

	-- Test 16: shallowEqual compares tables shallowly
	print("Test 16: shallowEqual compares tables shallowly")
	do
		local a = { x = 1, y = 2 }
		local b = { x = 1, y = 2 }
		local c = { x = 1, y = 3 }
		assertTrue(Rivue.utils.shallowEqual(a, b), "Should be equal for same properties")
		assertFalse(Rivue.utils.shallowEqual(a, c), "Should not be equal for different values")
	end

	-- Test 17: shallowEqual only checks top level
	print("Test 17: shallowEqual only checks top level")
	do
		local a = { nested = { value = 1 } }
		local b = { nested = { value = 1 } }
		assertFalse(Rivue.utils.shallowEqual(a, b), "Should not deep compare nested objects")

		local c = { nested = a.nested }
		assertTrue(Rivue.utils.shallowEqual(a, c), "Should be equal if nested reference is same")
	end

	-- Test 18: filterForClient handles text filtering
	print("Test 18: filterForClient handles text filtering")
	do
		local Players = game:GetService("Players")
		if Players.LocalPlayer then
			local filtered = Rivue.utils.filterForClient(Players.LocalPlayer, "Hello World")
			assertTrue(type(filtered) == "string", "Should return a string")
		else
			print("  ⊘ Skipped (no LocalPlayer available)")
		end
	end

	print("\n========== UTILS TESTS COMPLETE ==========\n")
end

return runTests
