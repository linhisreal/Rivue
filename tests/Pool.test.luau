--!strict
-- Tests for pool.luau - Object pooling system for Instance recycling

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pool = require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("pool"))

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
	print("\n========== POOL TEST SUITE ==========\n")

	-- Test 1: acquire() creates new instance when pool is empty
	print("Test 1: acquire() creates new instance when pool is empty")
	do
		Pool.clear()
		local frame = Pool.acquire("Frame")
		assertTrue(frame and true or false, "Should return an instance")
		assertTrue(frame:IsA("Frame"), "Should be a Frame instance")
	end

	-- Test 2: release() adds instance to pool
	print("Test 2: release() adds instance to pool")
	do
		Pool.clear()
		local frame = Pool.acquire("Frame")
		Pool.release(frame)
		assertTrue(#Pool.store["Frame"] == 1, "Should have 1 Frame in pool")
	end

	-- Test 3: acquire() reuses pooled instance
	print("Test 3: acquire() reuses pooled instance")
	do
		Pool.clear()
		local frame1 = Pool.acquire("Frame")
		Pool.release(frame1)

		local _frame2 = Pool.acquire("Frame")
		assertTrue(#Pool.store["Frame"] == 0, "Pool should be empty after reuse")
	end

	-- Test 4: release() resets instance properties
	print("Test 4: release() resets instance properties")
	do
		Pool.clear()
		local label = Pool.acquire("TextLabel") :: TextLabel
		label.Text = "Test Text"
		Pool.release(label)

		local reused = Pool.acquire("TextLabel") :: TextLabel
		assertEquals(reused.Text, Instance.new("TextLabel").Text, "Text should be reset to the default")
	end

	-- Test 5: clear() destroys pooled instances
	print("Test 5: clear() destroys pooled instances")
	do
		Pool.clear()
		-- Create 5 DIFFERENT instances at once (don't release until all are created)
		local instances = {}
		for i = 1, 5 do
			instances[i] = Pool.acquire("Frame")
		end

		-- Now release all instances to pool
		for i = 1, 5 do
			Pool.release(instances[i])
		end

		local frameStore = Pool.store["Frame"]
		assertTrue(frameStore ~= nil, "Frame store should exist")
		if frameStore then
			assertEquals(#frameStore, 5, "Should have 5 Frames in pool")
		end

		Pool.clear()
		local clearedStore = Pool.store["Frame"]
		assertTrue(clearedStore ~= nil, "Frame store should still exist after clear")
		if clearedStore then
			assertEquals(#clearedStore, 0, "Pool should be empty after clear")
		end
	end

	-- Test 6: Pool handles multiple types
	print("Test 6: Pool handles multiple types")
	do
		Pool.clear()
		local frame = Pool.acquire("Frame")
		local label = Pool.acquire("TextLabel")
		local button = Pool.acquire("TextButton")

		Pool.release(frame)
		Pool.release(label)
		Pool.release(button)

		assertTrue(Pool.store["Frame"] and true or false, "Should have Frame pool")
		assertTrue(Pool.store["TextLabel"] and true or false, "Should have TextLabel pool")
	end

	--Test 7: release() clears Parent
	print("Test 7: release() clears Parent")
	do
		Pool.clear()
		local container = Instance.new("Folder")
		local frame = Pool.acquire("Frame")
		frame.Parent = container

		Pool.release(frame)
		assertTrue(frame.Parent == nil, "Parent should be cleared")
		container:Destroy()
	end

	-- Test 8: release() restores touched props to class defaults
	print("Test 8: release() restores touched props to class defaults")
	do
		Pool.clear("TextLabel")
		local label = Pool.acquire("TextLabel") :: TextLabel
		local defaultSize = Instance.new("TextLabel").TextSize
		label.TextSize = defaultSize + 10
		Pool.release(label, { TextSize = true })
		local reused = Pool.acquire("TextLabel") :: TextLabel
		assertTrue(reused == label, "Should reuse the pooled instance")
		assertEquals(reused.TextSize, defaultSize, "Touched prop should be restored to its default")
		Pool.release(reused)
	end

	print("\n========== POOL TESTS COMPLETE ==========\n")
end

return runTests
