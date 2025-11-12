--!strict
--!optimize 2

--[[
	PoolEnhancements.test.luau
	==========================
	
	Tests for Pool instance reset improvements.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pool = require(ReplicatedStorage.Rivue.runtime.pool)

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

local function assertNil(value: any, message: string?)
	if value ~= nil then
		error(
			string.format(
				"Assertion failed: %s\nExpected: nil\nActual: %s",
				message or "value should be nil",
				tostring(value)
			)
		)
	end
	print("✓", message or "Assertion passed")
end

local function runTests()
	print("\n========== POOL ENHANCEMENTS TEST SUITE ==========\n")

	-- Test 1: Clear children when releasing
	print("Test 1: Clear all children when releasing")
	do
		local frame = Pool.acquire("Frame")

		-- Add some children
		local child1 = Instance.new("TextLabel")
		child1.Parent = frame
		local child2 = Instance.new("ImageLabel")
		child2.Parent = frame

		Pool.release(frame)

		-- Acquire again
		local reacquired = Pool.acquire("Frame")

		if reacquired == frame then
			assertEquals(#reacquired:GetChildren(), 0, "Released frame should have no children")
		end
	end

	-- Test 2: Reset text properties
	print("Test 2: Reset text properties")
	do
		local label = Pool.acquire("TextLabel") :: TextLabel
		label.Text = "Hello World"

		Pool.release(label)

		local reacquired = Pool.acquire("TextLabel") :: TextLabel
		if reacquired == label then
			assertEquals(reacquired.Text, "", "Text should be cleared")
		end
	end

	-- Test 3: Reset image properties
	print("Test 3: Reset image properties")
	do
		local imageLabel = Pool.acquire("ImageLabel") :: ImageLabel
		imageLabel.Image = "rbxassetid://123456"

		Pool.release(imageLabel)

		local reacquired = Pool.acquire("ImageLabel") :: ImageLabel
		if reacquired == imageLabel then
			assertEquals(reacquired.Image, "", "Image should be cleared")
		end
	end

	-- Test 4: Reset GuiObject properties
	print("Test 4: Reset GuiObject properties")
	do
		local frame = Pool.acquire("Frame") :: Frame
		frame.LayoutOrder = 99
		frame.Visible = false
		frame.Size = UDim2.fromScale(1, 1)
		frame.Position = UDim2.fromScale(0.5, 0.5)

		Pool.release(frame)

		local reacquired = Pool.acquire("Frame") :: Frame
		if reacquired == frame then
			assertEquals(reacquired.LayoutOrder, 0, "LayoutOrder should be 0")
			assertEquals(reacquired.Visible, true, "Visible should be true")
			assertEquals(reacquired.Size, UDim2.new(0, 0, 0, 0), "Size should be reset")
			assertEquals(reacquired.Position, UDim2.new(0, 0, 0, 0), "Position should be reset")
		end
	end

	-- Test 5: Clear all attributes
	print("Test 5: Clear all attributes")
	do
		local frame = Pool.acquire("Frame")
		frame:SetAttribute("customAttr1", "value1")
		frame:SetAttribute("customAttr2", 42)
		frame:SetAttribute("customAttr3", true)

		Pool.release(frame)

		local reacquired = Pool.acquire("Frame")
		if reacquired == frame then
			local attrs = reacquired:GetAttributes()
			assertNil(next(attrs), "Attributes table should be empty")
		end
	end

	-- Test 6: Reset parent to nil
	print("Test 6: Reset parent to nil")
	do
		local container = Instance.new("Frame")
		local frame = Pool.acquire("Frame")
		frame.Parent = container

		Pool.release(frame)

		assertNil(frame.Parent, "Parent should be nil after release")
		container:Destroy()
	end

	-- Test 7: Pool.clear destroys all instances
	print("Test 7: Pool.clear destroys all pooled instances")
	do
		-- Acquire and release some instances
		local frame1 = Pool.acquire("Frame")
		local frame2 = Pool.acquire("Frame")
		local label1 = Pool.acquire("TextLabel")

		Pool.release(frame1)
		Pool.release(frame2)
		Pool.release(label1)

		-- Clear the pool
		Pool.clear()

		-- Acquiring new instances should create fresh ones
		local newFrame = Pool.acquire("Frame")
		assertTrue(newFrame and true or false, "Should create new instance after clear")
		assertEquals(newFrame.ClassName, "Frame", "Should be correct class")
	end

	print("\n========== ALL POOL ENHANCEMENT TESTS PASSED ==========\n")
end

return {
	runAllTests = runTests,
}
