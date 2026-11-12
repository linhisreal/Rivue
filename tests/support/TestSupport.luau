--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local TestSupport = {}

local function pass(message: string?)
	print("✓", message or "Assertion passed")
end

function TestSupport.assertEquals(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`Assertion failed: {message or "values not equal"}\nExpected: {expected}\nActual: {actual}`, 2)
	end
	pass(message)
end

function TestSupport.assertTrue(condition: any, message: string?)
	if not condition then
		error(`Assertion failed: {message or "condition is false"}`, 2)
	end
	pass(message)
end

function TestSupport.assertFalse(condition: any, message: string?)
	if condition then
		error(`Assertion failed: {message or "condition is true"}`, 2)
	end
	pass(message)
end

function TestSupport.assertNil(value: any, message: string?)
	if value ~= nil then
		error(`Assertion failed: {message or "value should be nil"}\nExpected: nil\nActual: {value}`, 2)
	end
	pass(message)
end

function TestSupport.assertError(fn: () -> (), message: string?)
	if pcall(fn) then
		error(`Assertion failed: {message or "expected an error"}`, 2)
	end
	pass(message)
end

function TestSupport.assertNoError(fn: () -> (), message: string?)
	local ok, err = pcall(fn)
	if not ok then
		error(`Assertion failed: {message or "expected no error"}\nError: {err}`, 2)
	end
	pass(message)
end

--- The first descendant with that name, or nil
function TestSupport.find(root: Instance, name: string): any
	for _, child in root:GetDescendants() do
		if child.Name == name then
			return child
		end
	end
	return nil
end

return TestSupport
