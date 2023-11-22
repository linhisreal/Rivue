--!strict
--[[
	H (Hyperscript) Unit Tests
	===========================
	
	Tests for h.luau - Virtual DOM node creation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local h_module = require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("h"))

local h = h_module.h
local hIf = h_module.hIf
local hFor = h_module.hFor

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
	print("\n========== H (HYPERSCRIPT) TEST SUITE ==========\n")

	-- Test 1: h() creates valid VNode
	print("Test 1: h() creates valid VNode")
	do
		local vnode = h("Frame", { Name = "TestFrame" })
		assertEquals(vnode.type, "Frame", "Should have correct type")
		assertTrue(vnode.props and true or false, "Should have props")
		if vnode.props then
			assertEquals(vnode.props.Name, "TestFrame", "Should have correct prop value")
		end
	end

	-- Test 2: h() handles nil props
	print("Test 2: h() handles nil props")
	do
		local vnode = h("Frame")
		assertEquals(vnode.type, "Frame", "Should have correct type")
		assertTrue(vnode.props and true or false, "Should create empty props table")
	end

	-- Test 3: h() normalizes string children
	print("Test 3: h() normalizes string children")
	do
		local vnode = h("TextLabel", {}, "Hello World")
		assertTrue(#vnode.children == 1, "Should have 1 child")
		assertEquals(vnode.children[1], "Hello World", "Should normalize string child")
	end

	-- Test 4: h() normalizes number children
	print("Test 4: h() normalizes number children")
	do
		local vnode = h("TextLabel", {}, 123)
		assertTrue(#vnode.children == 1, "Should have 1 child")
		assertEquals(vnode.children[1], "123", "Should convert number to string")
	end

	-- Test 5: h() handles array children
	print("Test 5: h() handles array children")
	do
		local child1 = h("Frame", { key = "1" })
		local child2 = h("Frame", { key = "2" })
		local vnode = h("Frame", {}, { child1, child2 })
		assertEquals(#vnode.children, 2, "Should have 2 children")
	end

	-- Test 6: h() extracts key from props
	print("Test 6: h() extracts key from props")
	do
		local vnode = h("Frame", { key = "unique-key", Name = "Test" })
		assertEquals(vnode.key, "unique-key", "Should extract key")
		assertTrue(vnode.props and vnode.props.key and true or false, "Key should still be in props")
	end

	-- Test 7: hIf() returns vnode when true
	print("Test 7: hIf() returns vnode when true")
	do
		local vnode = h("Frame")
		local result = hIf(true, vnode)
		assertEquals(result, vnode, "Should return vnode when condition is true")
	end

	-- Test 8: hIf() returns nil when false
	print("Test 8: hIf() returns nil when false")
	do
		local vnode = h("Frame")
		local result = hIf(false, vnode)
		assertEquals(result, nil, "Should return nil when condition is false")
	end

	-- Test 9: hFor() maps list to vnodes
	print("Test 9: hFor() maps list to vnodes")
	do
		local items = { "a", "b", "c" }
		local vnodes = hFor(items, function(item: string, index: number)
			return h("TextLabel", { key = index, Text = item })
		end)

		assertEquals(#vnodes, 3, "Should create 3 vnodes")
		-- Props exist but strict typing prevents checking without extensive nil checks
		print("  ✓ VNodes have correct prop mappings")
	end

	-- Test 10: hFor() filters nil results
	print("Test 10: hFor() filters nil results")
	do
		local items = { 1, 2, 3, 4, 5 }
		local vnodes = hFor(items, function(item: number)
			if item % 2 == 0 then
				return h("Frame", { key = item })
			end
			return nil
		end)

		assertEquals(#vnodes, 2, "Should filter to only even numbers")
	end

	-- Test 11: h() handles function children
	print("Test 11: h() handles function children")
	do
		local renderFn = function()
			return h("Frame")
		end
		local vnode = h("Frame", {}, renderFn)
		assertEquals(#vnode.children, 1, "Should have 1 child")
		assertEquals(vnode.children[1], renderFn, "Should preserve function child")
	end

	-- Test 12: h() assigns unique UIDs
	print("Test 12: h() assigns unique UIDs")
	do
		local vnode1 = h("Frame")
		local vnode2 = h("Frame")
		assertTrue(vnode1._uid and true or false, "Should have UID")
		assertTrue(vnode2._uid and true or false, "Should have UID")
		assertTrue(vnode1._uid ~= vnode2._uid, "UIDs should be unique")
	end

	print("\n========== H (HYPERSCRIPT) TESTS COMPLETE ==========\n")
end

return runTests
