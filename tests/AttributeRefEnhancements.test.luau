--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage.RivueUI)

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

local function assertError(fn: () -> (), message: string?)
	local success = pcall(fn)
	if success then
		error("Assertion failed: " .. (message or "expected function to throw error"))
	end
	print("✓", message or "Assertion passed")
end

local function runTests()
	print("\n========== ATTRIBUTE REF ENHANCEMENTS TEST SUITE ==========\n")

	print("Test 1: Prevent infinite loops on attribute change")
	do
		local instance = Instance.new("Part")
		instance:SetAttribute("testValue", 10)

		local attrRef = Rivue.attributeRef(instance, "testValue", 0)

		local updateCount = 0
		Rivue.watch(attrRef, function()
			updateCount = updateCount + 1
		end)

		instance:SetAttribute("testValue", 20)
		task.wait(0.05)
		instance:SetAttribute("testValue", 30)
		task.wait(0.05)

		assertTrue(updateCount < 10, "Update count should be reasonable (not infinite)")
		assertEquals(attrRef.value, 30, "Ref should sync with attribute")

		instance:Destroy()
	end

	print("Test 2: Prevent infinite loops on ref change")
	do
		local instance = Instance.new("Part")
		instance:SetAttribute("testValue", 10)

		local attrRef = Rivue.attributeRef(instance, "testValue", 0)

		local attributeChangeCount = 0
		local conn = instance:GetAttributeChangedSignal("testValue"):Connect(function()
			attributeChangeCount = attributeChangeCount + 1
		end)

		attrRef.value = 20
		task.wait(0.05)
		attrRef.value = 30
		task.wait(0.05)

		assertTrue(attributeChangeCount < 10, "Attribute changes should be reasonable (not infinite)")
		assertEquals(instance:GetAttribute("testValue"), 30, "Attribute should sync with ref")

		conn:Disconnect()
		instance:Destroy()
	end

	print("Test 3: Bidirectional sync without loops")
	do
		local instance = Instance.new("Part")
		instance:SetAttribute("counter", 0)

		local attrRef = Rivue.attributeRef(instance, "counter", 0)

		attrRef.value = 5
		task.wait(0.05)
		assertEquals(instance:GetAttribute("counter"), 5, "Attribute should sync from ref")

		instance:SetAttribute("counter", 10)
		task.wait(0.05)
		assertEquals(attrRef.value, 10, "Ref should sync from attribute")

		attrRef.value = 15
		task.wait(0.05)
		assertEquals(instance:GetAttribute("counter"), 15, "Should sync both ways cleanly")

		instance:Destroy()
	end

	print("Test 4: Handle default values correctly")
	do
		local instance = Instance.new("Part")

		local attrRef = Rivue.attributeRef(instance, "newAttr", 42)

		assertEquals(attrRef.value, 42, "Should use default value")

		task.wait(0.05)
		assertEquals(instance:GetAttribute("newAttr"), 42, "Attribute should be set to default")

		instance:Destroy()
	end

	print("Test 5: Validate parameters")
	do
		assertError(function()
			Rivue.attributeRef(nil :: any, "attr", 0)
		end, "Should error on nil instance")

		assertError(function()
			Rivue.attributeRef(Instance.new("Part"), "", 0)
		end, "Should error on empty attribute name")
	end

	print("Test 6: Cleanup connections on component unmount")
	do
		local instance = Instance.new("Part")
		instance:SetAttribute("testValue", 10)

		local cleanedUp = false

		local TestComponent = Rivue.defineComponent({
			setup = function()
				local _attrRef = Rivue.attributeRef(instance, "testValue", 0)

				Rivue.onUnmounted(function()
					cleanedUp = true
				end)

				return function()
					return Rivue.h("Frame")
				end
			end,
		})

		local Players = game:GetService("Players")
		local gui = Instance.new("ScreenGui")
		-- No local player on a server, where the ScreenGui stays unparented
		gui.Parent = if Players.LocalPlayer then Players.LocalPlayer:WaitForChild("PlayerGui") else nil

		local app = Rivue.createApp(Rivue.h(TestComponent))
		app:mount(gui)

		task.wait(0.05)

		app:unmount()
		task.wait(0.05)

		assertEquals(cleanedUp, true, "Should cleanup on unmount")
		instance:Destroy()
		gui:Destroy()
	end

	print("\n========== ALL ATTRIBUTE REF ENHANCEMENT TESTS PASSED ==========\n")
end

return {
	runAllTests = runTests,
}
