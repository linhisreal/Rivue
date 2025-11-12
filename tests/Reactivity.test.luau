--!strict
--[[
	Reactivity Unit Tests
	=====================
	
	Tests for toRefs, iterArray integration, and reactive proxy edge cases
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))

local function assertEquals(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(string.format(
			"Assertion failed: %s\nExpected: %s\nActual: %s",
			message or "values not equal",
			tostring(expected),
			tostring(actual)
		))
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
	print("\n========== REACTIVITY TEST SUITE ==========\n")
	
	-- Test 1: toRefs creates refs from reactive object
	print("Test 1: toRefs creates refs from reactive object")
	do
		local obj = Rivue.reactive({ a = 1, b = 2, c = 3 })
		local refs = Rivue.toRefs(obj)
		assertTrue(refs.a ~= nil and refs.b ~= nil and refs.c ~= nil, "Should create refs for all properties")
		assertTrue(refs.a.value == 1 and refs.b.value == 2 and refs.c.value == 3, "Refs should have correct values")
	end
	
	-- Test 2: toRefs refs are reactive
	print("Test 2: toRefs refs are reactive")
	do
		local obj = Rivue.reactive({ count = 0 })
		local refs = Rivue.toRefs(obj)
		local triggered = false
		Rivue.effect(function()
			local _ = refs.count.value
			triggered = true
		end)
		task.wait(0.05)
		triggered = false
		obj.count = 10
		task.wait(0.05)
		assertTrue(triggered, "toRefs should maintain reactivity")
		assertTrue(refs.count.value == 10, "Ref value should update with source")
	end
	
	-- Test 3: toRefs handles empty objects
	print("Test 3: toRefs handles empty objects")
	do
		local obj = Rivue.reactive({})
		local refs = Rivue.toRefs(obj)
		local count = 0
		for _, _ in pairs(refs) do
			count = count + 1
		end
		assertEquals(count, 0, "toRefs should handle empty objects")
	end
	
	-- Test 4: toRefs preserves object structure
	print("Test 4: toRefs preserves object structure")
	do
		local obj = Rivue.reactive({ x = 1, y = 2, z = 3 })
		local refs = Rivue.toRefs(obj)
		local keys = {}
		for k in pairs(refs) do
			table.insert(keys, k)
		end
		table.sort(keys)
		assertEquals(#keys, 3, "Should preserve all keys")
		assertTrue(keys[1] == "x" and keys[2] == "y" and keys[3] == "z", "Should preserve key names")
	end
	
	-- Test 5: Reactive arrays work with iterArray
	print("Test 5: Reactive arrays work with iterArray")
	do
		local arr = Rivue.reactive({ 10, 20, 30 })
		local sum = 0
		for _, v in Rivue.iterArray(arr) do
			sum = sum + v
		end
		assertEquals(sum, 60, "Should iterate reactive array correctly")
	end
	
	-- Test 6: toRaw unwraps reactive proxies
	print("Test 6: toRaw unwraps reactive proxies")
	do
		local obj = Rivue.reactive({ test = 123 })
		local raw = Rivue.toRaw(obj)
		assertEquals(raw.test, 123, "toRaw should unwrap to original object")
	end
	
	-- Test 7: toRaw returns non-reactive objects unchanged
	print("Test 7: toRaw returns non-reactive objects unchanged")
	do
		local obj = { test = 456 }
		local raw = Rivue.toRaw(obj)
		assertTrue(raw == obj, "toRaw should return non-reactive objects unchanged")
		assertEquals(raw.test, 456, "Values should be preserved")
	end
	
	-- Test 8: Reactive handles nested objects
	print("Test 8: Reactive handles nested objects")
	do
		local obj = Rivue.reactive({ nested = { value = 42 } })
		assertEquals(obj.nested.value, 42, "Should handle nested objects")
		obj.nested.value = 100
		assertEquals(obj.nested.value, 100, "Should update nested values")
	end
	
	-- Test 9: iterArray handles empty arrays
	print("Test 9: iterArray handles empty arrays")
	do
		local arr = Rivue.reactive({})
		local count = 0
		for _, _ in Rivue.iterArray(arr) do
			count = count + 1
		end
		assertEquals(count, 0, "Should handle empty arrays")
	end
	
	-- Test 10: Multiple refs from same object stay in sync
	print("Test 10: Multiple refs from same object stay in sync")
	do
		local obj = Rivue.reactive({ value = 1 })
		local refs1 = Rivue.toRefs(obj)
		local refs2 = Rivue.toRefs(obj)
		obj.value = 99
		assertTrue(refs1.value.value == 99 and refs2.value.value == 99, 
			"All refs should stay in sync with source")
	end
	
	print("\n========== REACTIVITY TESTS COMPLETE ==========\n")
end

return runTests
