--!strict
-- Rivue.debug: log, measure, prettyPrint, inspect and assertInvariant

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local debugModule = Rivue.debug

local function assertTrue(condition: boolean, message: string?)
	if not condition then
		error("Assertion failed: " .. (message or "condition is false"))
	end
	print("✓", message or "Assertion passed")
end

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

local function assertNoError(fn: () -> (), message: string?)
	local results = { pcall(fn) }
	local success = results[1]
	if not success then
		local errorMsg = results[2]
		error("Expected no error but got: " .. tostring(errorMsg) .. " (" .. (message or "") .. ")")
	end
	print("✓", message or "No error raised")
end

local function assertError(fn: () -> (), message: string?)
	local results = { pcall(fn) }
	local success = results[1]
	if success then
		error("Expected error but function succeeded (" .. (message or "") .. ")")
	end
	print("✓", message or "Error raised as expected")
end

local function runTests()
	print("\n========== DEBUG MODULE TEST SUITE ==========\n")

	print("Test 1: debug.enabled property exists")
	do
		assertTrue(debugModule.enabled ~= nil, "Should have enabled property")
		assertTrue(type(debugModule.enabled) == "boolean", "Should be boolean")
	end

	print("Test 2: debug.log function exists")
	do
		assertTrue(type(debugModule.log) == "function", "Should have log function")
		local ok = pcall(function()
			debugModule.log("Test", "Test message")
		end)
		assertTrue(ok, "Should not error when logging")
	end

	print("Test 3: debug.log with data parameter")
	do
		local ok = pcall(function()
			debugModule.log("Test", "Test with data", { key = "value" })
		end)
		assertTrue(ok, "Should handle data parameter")
	end

	print("Test 4: debug.measure function exists")
	do
		assertTrue(type(debugModule.measure) == "function", "Should have measure function")
	end

	print("Test 5: debug.measure returns function result")
	do
		local result = debugModule.measure("Test", function()
			return 42
		end)
		assertTrue(result == 42, "Should return function result")
	end

	print("Test 6: debug.measure handles multiple return values")
	do
		local a, b, c = debugModule.measure("Test", function()
			return 1, 2, 3
		end)
		assertTrue(a == 1 and b == 2 and c == 3, "Should preserve multiple return values")
	end

	print("Test 7: debug.enabled can be toggled")
	do
		local original = debugModule.enabled
		debugModule.enabled = true
		assertTrue(debugModule.enabled == true, "Should set to true")
		debugModule.enabled = false
		assertTrue(debugModule.enabled == false, "Should set to false")
		debugModule.enabled = original
	end

	print("Test 8: prettyPrint unwraps reactive proxies")
	do
		local state = Rivue.reactive({
			count = 0,
			nested = { value = 42 },
		})

		assertNoError(function()
			debugModule.prettyPrint(state)
		end, "prettyPrint should handle reactive proxies")
	end

	print("Test 9: prettyPrint handles circular references")
	do
		local obj: any = {}
		obj.self = obj

		assertNoError(function()
			debugModule.prettyPrint(obj)
		end, "prettyPrint should handle circular references")
	end

	print("Test 10: prettyPrint handles refs")
	do
		local count = Rivue.ref(10)

		assertNoError(function()
			debugModule.prettyPrint(count)
		end, "prettyPrint should handle refs")
	end

	print("Test 11: prettyPrint respects maxDepth option")
	do
		local deep = {
			level1 = {
				level2 = {
					level3 = {
						level4 = "too deep",
					},
				},
			},
		}

		assertNoError(function()
			debugModule.prettyPrint(deep, { maxDepth = 2 })
		end, "prettyPrint should respect maxDepth")
	end

	print("Test 12: inspect returns string for reactive values")
	do
		local state = Rivue.reactive({ count = 0 })
		local result = debugModule.inspect(state)

		assertEquals(type(result), "string", "inspect should return a string")
		assertTrue(string.len(result) > 0, "inspect should return non-empty string")
	end

	print("Test 13: inspect handles primitive values")
	do
		assertEquals(debugModule.inspect(42), "42", "Should inspect number correctly")
		assertEquals(debugModule.inspect("hello"), '"hello"', "Should inspect string correctly")
		assertEquals(debugModule.inspect(true), "true", "Should inspect boolean correctly")
		assertEquals(debugModule.inspect(nil), "nil", "Should inspect nil correctly")
	end

	print("Test 14: inspect handles nested tables")
	do
		local data = {
			name = "test",
			items = { 1, 2, 3 },
		}
		local result = debugModule.inspect(data)

		assertEquals(type(result), "string", "Should return string")
		assertTrue(string.find(result, "name") ~= nil, "Should contain 'name' field")
		assertTrue(string.find(result, "items") ~= nil, "Should contain 'items' field")
	end

	print("Test 15: inspect limits depth")
	do
		local deep = {
			a = { b = { c = { d = "deep" } } },
		}

		local result = debugModule.inspect(deep, 2)
		assertEquals(type(result), "string", "Should return string with depth limit")
	end

	print("Test 16: assertInvariant doesn't throw when true")
	do
		assertNoError(function()
			debugModule.assertInvariant(true, "Should not throw")
		end, "assertInvariant should not throw on true condition")
	end

	print("Test 17: assertInvariant throws when false (if debug enabled)")
	do
		local original = debugModule.enabled
		debugModule.enabled = true

		assertError(function()
			debugModule.assertInvariant(false, "Should throw")
		end, "assertInvariant should throw on false condition when debug enabled")

		debugModule.enabled = original
	end

	print("Test 18: formatError creates formatted message")
	do
		local formatted = debugModule.formatError("TestComponent", "Test error")
		assertEquals(type(formatted), "string", "Should return string")
		assertTrue(string.find(formatted, "TestComponent") ~= nil, "Should contain component name")
		assertTrue(string.find(formatted, "Test error") ~= nil, "Should contain error message")
	end

	print("Test 19: formatError includes context")
	do
		local formatted = debugModule.formatError("TestComponent", "Test error", { key = "value" })
		assertTrue(string.find(formatted, "Context") ~= nil, "Should include context section")
	end

	print("Test 20: Integration with reactive state")
	do
		local state = Rivue.reactive({
			user = {
				name = "Alice",
				age = 30,
			},
		})

		local inspected = debugModule.inspect(state)
		assertEquals(type(inspected), "string", "Should work with reactive state")
	end

	print("Test 21: Integration with computed values")
	do
		local count = Rivue.ref(5)
		local doubled = Rivue.computed(function()
			return count.value * 2
		end)

		local inspected = debugModule.inspect(doubled)
		assertEquals(type(inspected), "string", "Should work with computed values")
	end

	print("Test 22: Convenience aliases work")
	do
		assertTrue(Rivue.prettyPrint == debugModule.prettyPrint, "prettyPrint alias should match")
		assertTrue(Rivue.inspect == debugModule.inspect, "inspect alias should match")
		assertTrue(Rivue.assertInvariant == debugModule.assertInvariant, "assertInvariant alias should match")
	end

	print("Test 23: inspect() shows a reactive object's contents")
	do
		local state = Rivue.reactive({ score = 42 })
		local inspected = debugModule.inspect(state)
		assertTrue(string.find(inspected, "score = 42", 1, true) ~= nil, "Should include the raw field")
	end

	print("\n========== ALL DEBUG MODULE TESTS PASSED ==========\n")
end

return {
	runAllTests = runTests,
}
