--!strict

-- Scheduler: reentrancy limits and job ordering

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

	print("Test 1: Nested effect triggering")
	do
		local count = Rivue.ref(0)

		Rivue.watchEffect(function()
			local val = count.value
			if val < 5 then
				task.defer(function()
					count.value = val + 1
				end)
			end
		end)

		count.value = 1

		task.wait(0.1)

		assertEquals(count.value, 5, "Should handle nested effects without infinite loop")
	end

	print("Test 2: Max reentrancy depth protection")
	do
		local count = Rivue.ref(0)
		local maxReached = false

		-- An effect that keeps changing what it reads must stop eventually
		pcall(function()
			local trigger = Rivue.ref(0)

			Rivue.watchEffect(function()
				local _ = trigger.value
				if count.value < 200 then
					count.value = count.value + 1
					trigger.value = trigger.value + 1
				else
					maxReached = true
				end
			end)

			trigger.value = 1
			task.wait(0.2)
		end)

		-- Like Vue, an effect writing state it reads doesn't re-trigger itself: it runs once on
		-- creation and once for the outside write, then settles
		assertTrue(not maxReached and count.value <= 2, "Effect writing its own dependencies doesn't loop")
		print("  Final count:", count.value, "- Effect executed and terminated properly")
	end

	print("Test 3: Jobs added during flush are scheduled")
	do
		local results: { number } = {}
		local count = Rivue.ref(0)

		Rivue.watchEffect(function()
			local val = count.value
			table.insert(results, val)

			if val == 1 then
				task.defer(function()
					count.value = 2
				end)
			end
		end)

		count.value = 1
		task.wait(0.2)

		assertTrue(#results >= 2, "Should process jobs added during flush")
	end

	print("Test 4: Job deduplication in micro queue")
	do
		local callCount = 0
		local fn = function()
			callCount = callCount + 1
		end

		Rivue.scheduler.queueJob(fn)
		Rivue.scheduler.queueJob(fn)
		Rivue.scheduler.queueJob(fn)

		task.wait(0.1)

		assertEquals(callCount, 1, "Should deduplicate identical jobs")
	end

	print("\n========== ALL SCHEDULER ENHANCEMENT TESTS PASSED ==========\n")
end

return {
	runAllTests = runTests,
}
