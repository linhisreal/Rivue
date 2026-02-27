--!strict
-- Tests for composables.luau - Composition API utilities

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local composables_module =
	require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("composables"))

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
	local printHeader = "COMPOSABLES TEST SUITE"
	print("\n" .. string.rep("=", 40))
	print(printHeader)
	print(string.rep("=", 40) .. "\n")

	-- Test 1: defineModel creates two-way binding ref
	print("Test 1: defineModel creates two-way binding ref")
	do
		local emitted = false
		local emittedValue = nil

		local mockProps = { modelValue = "initial" }
		local mockContext = {
			emit = function(_eventName: string, value: any)
				emitted = true
				emittedValue = value
			end,
		}

		local modelFactory = composables_module.defineModel()
		local model = modelFactory(mockProps, mockContext)

		assertEquals(model.value, "initial", "Should read initial value from props")

		-- Set value (should emit)
		model.value = "updated"
		assertTrue(emitted, "Should emit update event")
		assertEquals(emittedValue, "updated", "Should emit new value")
	end

	-- Test 2: defineModel with custom name and event
	print("Test 2: defineModel with custom name and event")
	do
		local emittedEvent = ""
		local emittedValue = nil

		local mockProps = { title = "Hello" }
		local mockContext = {
			emit = function(eventName: string, value: any)
				emittedEvent = eventName
				emittedValue = value
			end,
		}

		local modelFactory = composables_module.defineModel({ name = "title", event = "update:title" })
		local model = modelFactory(mockProps, mockContext)

		assertEquals(model.value, "Hello", "Should read custom prop")

		model.value = "World"
		assertEquals(emittedEvent, "update:title", "Should emit custom event name")
		assertEquals(emittedValue, "World", "Should emit new value")
	end

	-- Test 3: useAttrs outside setup throws error
	print("Test 3: useAttrs outside setup throws error")
	do
		local success = pcall(function()
			composables_module.useAttrs()
		end)
		assertFalse(success, "useAttrs should throw error outside setup")
	end

	-- Test 4: useSlots outside setup throws error
	print("Test 4: useSlots outside setup throws error")
	do
		local success = pcall(function()
			composables_module.useSlots()
		end)
		assertFalse(success, "useSlots should throw error outside setup")
	end

	-- Test 5: useTheme returns nil when no theme provided
	print("Test 5: useTheme returns nil when no theme provided")
	do
		local theme = composables_module.useTheme()
		assertTrue(theme == nil, "Should return nil when no theme is provided")
	end

	-- Test 6: useStyles creates computed styles
	print("Test 6: useStyles creates computed styles")
	do
		local styles = composables_module.useStyles(function(theme)
			return {
				backgroundColor = theme.primaryColor or Color3.fromRGB(255, 255, 255),
				textColor = theme.textColor or Color3.fromRGB(0, 0, 0),
			}
		end)

		-- Should return computed ref with default styles
		assertTrue(styles.value ~= nil, "Should create computed styles")
		assertTrue(styles.value.backgroundColor ~= nil, "Should have backgroundColor")
		assertTrue(styles.value.textColor ~= nil, "Should have textColor")
	end

	-- Test 7: defineModel with number types
	print("Test 7: defineModel with number types")
	do
		local emittedValue = nil
		local mockProps = { modelValue = 42 }
		local mockContext = {
			emit = function(_: string, value: any)
				emittedValue = value
			end,
		}

		local modelFactory = composables_module.defineModel()
		local model = modelFactory(mockProps, mockContext)

		assertEquals(model.value, 42, "Should handle number values")

		model.value = 100
		assertEquals(emittedValue, 100, "Should emit updated number value")
	end

	-- Test 8: defineModel tracks reactive changes
	print("Test 8: defineModel tracks reactive changes")
	do
		local props = Rivue.reactive({ modelValue = "test" })
		local mockContext = {
			emit = function(_: string, _: any) end,
		}

		local modelFactory = composables_module.defineModel()
		local model = modelFactory(props, mockContext)

		assertEquals(model.value, "test", "Should read reactive prop")

		-- Change source prop
		props.modelValue = "changed"
		assertEquals(model.value, "changed", "Should reflect prop changes")
	end

	local printFooter = "COMPOSABLES TESTS COMPLETE"
	print("\n" .. string.rep("=", 40))
	print(printFooter)
	print(string.rep("=", 40) .. "\n")
end

return runTests
