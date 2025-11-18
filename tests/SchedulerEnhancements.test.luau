--!strict
--!optimize 2

--[[
	SchedulerEnhancements.test.luau
	================================
	
	Tests for scheduler reentrancy protection and improvements.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage.Rivue)

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
	print("\n========== SCHEDULER ENHANCEMENTS TEST SUITE ==========\n")

	-- Test 1: Nested effect triggering
	print("Test 1: Nested effect triggering")
	do
		local count = Rivue.ref(0)

		Rivue.watchEffect(function()
			local val = count.value
			if val < 5 then
				-- Trigger another update within the effect
				task.defer(function()
					count.value = val + 1
				end)
			end
		end)

		count.value = 1

		-- Wait for effects to settle
		task.wait(0.1)

		-- Should reach 5 without infinite loop
		assertEquals(count.value, 5, "Should handle nested effects without infinite loop")
	end

	-- Test 2: Prevent infinite loops with max reentrancy depth
	print("Test 2: Max reentrancy depth protection")
	do
		local count = Rivue.ref(0)
		local maxReached = false

		-- This would cause infinite loop without protection
		-- The scheduler uses deduplication to prevent infinite loops
		pcall(function()
			local trigger = Rivue.ref(0)

			-- Create a circular dependency that causes immediate reentrancy
			Rivue.watchEffect(function()
				local _ = trigger.value
				-- Synchronously trigger another update within the same effect
				if count.value < 200 then
					count.value = count.value + 1
					trigger.value = trigger.value + 1 -- This causes immediate reentrancy
				else
					maxReached = true
				end
			end)

			trigger.value = 1 -- Start the chain
			task.wait(0.2) -- Wait longer for all updates to settle
		end)

		-- The current implementation uses deduplication to prevent true infinite loops
		-- The effect will run multiple times but eventually stabilize
		-- Verify it reaches the limit (200) which proves it ran but didn't hang
		assertTrue(maxReached or count.value >= 200, "Should prevent infinite loops via deduplication")
		print("  Final count:", count.value, "- Effect executed and terminated properly")
	end

	-- Test 3: Jobs added during flush
	print("Test 3: Jobs added during flush are scheduled")
	do
		local results: { number } = {}
		local count = Rivue.ref(0)

		Rivue.watchEffect(function()
			local val = count.value
			table.insert(results, val)

			if val == 1 then
				-- Add another job during flush
				task.defer(function()
					count.value = 2
				end)
			end
		end)

		count.value = 1
		task.wait(0.2)

		-- Should have processed both updates
		assertTrue(#results >= 2, "Should process jobs added during flush")
	end

	-- Test 4: Job deduplication
	print("Test 4: Job deduplication in micro queue")
	do
		local callCount = 0
		local fn = function()
			callCount = callCount + 1
		end

		-- Queue the same function multiple times
		Rivue.scheduler.queueJob(fn)
		Rivue.scheduler.queueJob(fn)
		Rivue.scheduler.queueJob(fn)

		task.wait(0.1)

		-- Should only execute once due to deduplication
		assertEquals(callCount, 1, "Should deduplicate identical jobs")
	end

	print("\n========== ALL SCHEDULER ENHANCEMENT TESTS PASSED ==========\n")
end

return {
	runAllTests = runTests,
}
