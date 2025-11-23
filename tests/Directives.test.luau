--!strict
--[[
	Directives Unit Tests
	====================
	
	Tests for directives.luau - Custom directive system and vModel helpers
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local directives_module =
	require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("directives"))

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
	local printHeader = "DIRECTIVES TEST SUITE"
	print("\n" .. string.rep("=", 40))
	print(printHeader)
	print(string.rep("=", 40) .. "\n")

	-- Test 1: register() adds directive to registry
	print("Test 1: register() adds directive to registry")
	do
		local testDirective = {
			mounted = function() end,
		}
		directives_module.register("test-directive", testDirective)
		local retrieved = directives_module.get("test-directive")
		assertTrue(retrieved and true or false, "Should register and retrieve directive")
	end

	-- Test 2: Built-in focus directive exists
	print("Test 2: Built-in focus directive exists")
	do
		local focusDirective = directives_module.get("focus")
		assertTrue(focusDirective and true or false, "Should have focus directive")
		assertTrue(focusDirective.mounted and true or false, "Should have mounted hook")
	end

	-- Test 3: Built-in click-outside directive exists
	print("Test 3: Built-in click-outside directive exists")
	do
		local clickOutsideDirective = directives_module.get("click-outside")
		assertTrue(clickOutsideDirective and true or false, "Should have click-outside directive")
		assertTrue(clickOutsideDirective.mounted and true or false, "Should have mounted hook")
	end

	-- Test 4: vModelText creates two-way binding props
	print("Test 4: vModelText creates two-way binding props")
	do
		local textRef = Rivue.ref("initial")
		local props = directives_module.vModelText(textRef)

		assertEquals(props.Text, "initial", "Should have Text property with ref value")
		assertTrue(type(props.onTextChanged) == "function", "Should have onTextChanged handler")

		-- Test binding
		props.onTextChanged("updated")
		task.wait(0.05)
		assertEquals(textRef.value, "updated", "Should update ref when onTextChanged is called")
	end

	-- Test 5: vModelText with debounce option
	print("Test 5: vModelText with debounce option")
	do
		local textRef = Rivue.ref("initial")
		local props = directives_module.vModelText(textRef, { debounce = 100 })

		assertEquals(props.Text, "initial", "Should have Text property")
		assertTrue(type(props.onTextChanged) == "function", "Should have debounced handler")
	end

	-- Test 6: vModelProp creates generic two-way binding
	print("Test 6: vModelProp creates generic two-way binding")
	do
		local valueRef = Rivue.ref(50)
		local props = directives_module.vModelProp(valueRef, "Value")

		assertEquals(props.Value, 50, "Should have Value property with ref value")
		assertTrue(type(props.onValue) == "function", "Should have onValue handler")

		-- Test binding
		props.onValue(75)
		assertEquals(valueRef.value, 75, "Should update ref when handler is called")
	end

	-- Test 7: vModelProp with custom event name
	print("Test 7: vModelProp with custom event name")
	do
		local valueRef = Rivue.ref(100)
		local props = directives_module.vModelProp(valueRef, "Position", "onPositionChanged")

		assertEquals(props.Position, 100, "Should have Position property")
		assertTrue(type(props.onPositionChanged) == "function", "Should have custom event handler")
	end

	-- Test 8: Built-in show directive exists
	print("Test 8: Built-in show directive exists")
	do
		local showDirective = directives_module.get("show")
		assertTrue(showDirective and true or false, "Should have show directive")
		assertTrue(showDirective.mounted and true or false, "Should have mounted hook")
		assertTrue(showDirective.updated and true or false, "Should have updated hook")
	end

	-- Test 9: Built-in drag directive exists
	print("Test 9: Built-in drag directive exists")
	do
		local dragDirective = directives_module.get("drag")
		assertTrue(dragDirective and true or false, "Should have drag directive")
		assertTrue(dragDirective.mounted and true or false, "Should have mounted hook")
	end

	-- Test 10: Built-in fade-in directive exists
	print("Test 10: Built-in fade-in directive exists")
	do
		local fadeInDirective = directives_module.get("fade-in")
		assertTrue(fadeInDirective and true or false, "Should have fade-in directive")
		assertTrue(fadeInDirective.mounted and true or false, "Should have mounted hook")
		assertTrue(fadeInDirective.unmounted and true or false, "Should have unmounted hook")
	end

	-- Test 11: Built-in preload directive exists
	print("Test 11: Built-in preload directive exists")
	do
		local preloadDirective = directives_module.get("preload")
		assertTrue(preloadDirective and true or false, "Should have preload directive")
		assertTrue(preloadDirective.mounted and true or false, "Should have mounted hook")
	end

	-- Test 12: Built-in once directive exists
	print("Test 12: Built-in once directive exists")
	do
		local onceDirective = directives_module.get("once")
		assertTrue(onceDirective and true or false, "Should have once directive")
		assertTrue(onceDirective.mounted and true or false, "Should have mounted hook")
	end

	-- Test 13: Built-in memo directive exists
	print("Test 13: Built-in memo directive exists")
	do
		local memoDirective = directives_module.get("memo")
		assertTrue(memoDirective and true or false, "Should have memo directive")
		assertTrue(memoDirective.mounted and true or false, "Should have mounted hook")
		assertTrue(memoDirective.updated and true or false, "Should have updated hook")
	end

	-- Test 14: v-memo tracks dependencies correctly
	print("Test 14: v-memo tracks dependencies correctly")
	do
		local memoDirective = directives_module.get("memo")
		local mockElement = { Name = "TestElement" }
		local deps1 = { 1, 2, 3 }

		-- Mount with initial deps
		local cleanup = memoDirective.mounted(mockElement, deps1)
		assertTrue(cleanup and cleanup.deps and true or false, "Should return cleanup with deps")
		assertEquals(#cleanup.deps, 3, "Should store dependency snapshot")

		-- Update with same deps (should not trigger update)
		local deps2 = { 1, 2, 3 }
		local updatedCleanup = memoDirective.updated(mockElement, deps2, cleanup)
		assertTrue(updatedCleanup and true or false, "Should handle same dependencies")

		-- Update with different deps (should trigger update)
		local deps3 = { 1, 2, 4 }
		local newCleanup = memoDirective.updated(mockElement, deps3, cleanup)
		assertTrue(newCleanup and newCleanup.deps and true or false, "Should update with new deps")
		assertEquals(newCleanup.deps[3], 4, "Should store new dependency values")
	end

	-- Test 15: vModelText handles debounce correctly
	print("Test 15: vModelText handles debounce correctly")
	do
		local textRef = Rivue.ref("initial")
		local props = directives_module.vModelText(textRef, { debounce = 50 })

		-- Rapid updates
		props.onTextChanged("a")
		props.onTextChanged("ab")
		props.onTextChanged("abc")

		-- Should still be initial (debounced)
		assertEquals(textRef.value, "initial", "Should not update immediately when debounced")

		-- Wait for debounce
		task.wait(0.1)
		assertEquals(textRef.value, "abc", "Should update after debounce delay")
	end

	local printFooter = "DIRECTIVES TESTS COMPLETE"
	print("\n" .. string.rep("=", 40))
	print(printFooter)
	print(string.rep("=", 40) .. "\n")
end

return runTests
