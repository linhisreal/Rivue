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
		assertTrue(refs1.value.value == 99 and refs2.value.value == 99, "All refs should stay in sync with source")
	end

	-- Test 11: effectScope creates and manages effects
	print("Test 11: effectScope creates and manages effects")
	do
		local scope = Rivue.effectScope()
		local count = 0
		scope:run(function()
			Rivue.effect(function()
				count = count + 1
				return nil
			end)
			return nil
		end)
		task.wait(0.05)
		local initialCount = count
		assertTrue(initialCount > 0, "Effect should have run")
		scope:stop()
		task.wait(0.05)
		assertEquals(count, initialCount, "Effect should not run after scope stopped")
	end

	-- Test 12: getCurrentScope returns active scope
	print("Test 12: getCurrentScope returns active scope")
	do
		local scope = Rivue.effectScope()
		local capturedScope
		scope:run(function()
			capturedScope = Rivue.getCurrentScope()
			return nil
		end)
		assertTrue(capturedScope == scope, "getCurrentScope should return active scope")
	end

	-- Test 13: onScopeDispose runs cleanup on scope stop
	print("Test 13: onScopeDispose runs cleanup on scope stop")
	do
		local scope = Rivue.effectScope()
		local cleanupRan = false
		scope:run(function()
			Rivue.onScopeDispose(function()
				cleanupRan = true
				return nil
			end)
			return nil
		end)
		assertFalse(cleanupRan, "Cleanup should not run before stop")
		scope:stop()
		assertTrue(cleanupRan, "Cleanup should run after stop")
	end

	-- Test 14: readonly prevents mutations
	print("Test 14: readonly prevents mutations")
	do
		local obj = Rivue.reactive({ value = 10 })
		local readonlyObj = Rivue.readonly(obj)
		assertEquals(readonlyObj.value, 10, "Should read values correctly")
		readonlyObj.value = 20 -- This should be prevented
		assertEquals(readonlyObj.value, 10, "Readonly should prevent mutations")
		obj.value = 30
		assertEquals(readonlyObj.value, 30, "Readonly should reflect source changes")
	end

	-- Test 15: isReadonly checks for readonly proxies
	print("Test 15: isReadonly checks for readonly proxies")
	do
		local obj = Rivue.reactive({ value = 1 })
		local readonlyObj = Rivue.readonly(obj)
		assertFalse(Rivue.isReadonly(obj), "Regular reactive should not be readonly")
		assertTrue(Rivue.isReadonly(readonlyObj), "Readonly proxy should be detected")
	end

	-- Test 16: isProxy checks for any proxy type
	print("Test 16: isProxy checks for any proxy type")
	do
		local reactive = Rivue.reactive({ a = 1 })
		local readonly = Rivue.readonly({ b = 2 })
		local plain = { c = 3 }
		assertTrue(Rivue.isProxy(reactive), "Reactive should be a proxy")
		assertTrue(Rivue.isProxy(readonly), "Readonly should be a proxy")
		assertFalse(Rivue.isProxy(plain), "Plain object should not be a proxy")
	end

	-- Test 17: markRaw prevents reactivity
	print("Test 17: markRaw prevents reactivity")
	do
		local rawObj = Rivue.markRaw({ value = 42 })
		local state = Rivue.reactive({ data = rawObj })
		assertTrue(Rivue.toRaw(state.data) == rawObj, "markRaw should prevent reactivity")
	end

	-- Test 18: triggerRef manually triggers updates
	print("Test 18: triggerRef manually triggers updates")
	do
		local shallowRef = Rivue.shallowRef({ count = 0 })
		local triggered = false
		Rivue.effect(function()
			local _ = shallowRef.value.count
			triggered = true
		end)
		task.wait(0.05)
		triggered = false
		shallowRef.value.count = 10 -- Internal mutation, no auto-trigger
		task.wait(0.05)
		assertFalse(triggered, "Shallow ref mutation should not auto-trigger")
		Rivue.triggerRef(shallowRef)
		task.wait(0.05)
		assertTrue(triggered, "triggerRef should manually trigger updates")
	end

	-- Test 19: customRef allows custom tracking logic
	print("Test 19: customRef allows custom tracking logic")
	do
		local value = 0
		local customRef = Rivue.customRef(function(track, trigger)
			return {
				get = function()
					track()
					return value
				end,
				set = function(newValue)
					value = newValue
					trigger()
				end,
			}
		end)
		assertEquals(customRef.value, 0, "Custom ref should read initial value")
		customRef.value = 42
		assertEquals(customRef.value, 42, "Custom ref should update value")
	end

	-- Test 20: shallowRef doesn't auto-wrap objects
	print("Test 20: shallowRef doesn't auto-wrap objects")
	do
		local obj = { nested = { value = 10 } }
		local shallow = Rivue.shallowRef(obj)
		assertTrue(shallow.value == obj, "shallowRef should not wrap objects")
		assertFalse(Rivue.isReactive(shallow.value), "shallowRef value should not be reactive")
	end

	-- Test 21: watchEffect runs immediately and tracks dependencies
	print("Test 21: watchEffect runs immediately and tracks dependencies")
	do
		local count = Rivue.ref(0)
		local watchCount = 0
		local stop = Rivue.watchEffect(function()
			local _ = count.value
			watchCount = watchCount + 1
		end)
		task.wait(0.05)
		assertTrue(watchCount >= 1, "watchEffect should run immediately")
		local initial = watchCount
		count.value = 5
		task.wait(0.05)
		assertTrue(watchCount > initial, "watchEffect should re-run on dependency change")
		stop()
	end

	-- Test 22: Nested effectScopes with parent-child cleanup
	print("Test 22: Nested effectScopes with parent-child cleanup")
	do
		local parentScope = Rivue.effectScope()
		local childCleanupRan = false
		local parentCleanupRan = false

		parentScope:run(function()
			Rivue.onScopeDispose(function()
				parentCleanupRan = true
				return nil
			end)

			local childScope = Rivue.effectScope()
			childScope:run(function()
				Rivue.onScopeDispose(function()
					childCleanupRan = true
					return nil
				end)
				return nil
			end)
			return nil
		end)

		parentScope:stop()
		assertTrue(childCleanupRan and parentCleanupRan, "Both parent and child cleanups should run")
	end

	-- Test 23: computed notifies dependents when its sources change
	print("Test 23: computed chains notify dependent effects")
	do
		local count = Rivue.ref(1)
		local doubled = Rivue.computed(function()
			return count.value * 2
		end)
		local quadrupled = Rivue.computed(function()
			return doubled.value * 2
		end)
		local seen = 0
		Rivue.watchEffect(function()
			seen = quadrupled.value
		end, { flush = "sync" })
		assertEquals(seen, 4, "Effect should see initial computed value")
		count.value = 3
		assertEquals(seen, 12, "Effect should re-run when computed chain changes")
	end

	-- Test 24: appending to a reactive array re-runs length-dependent effects
	print("Test 24: array append triggers length dependents")
	do
		local list = Rivue.reactive({ "a", "b" })
		local length = 0
		Rivue.watchEffect(function()
			length = #list
		end, { flush = "sync" })
		assertEquals(length, 2, "Initial length")
		list[#list + 1] = "c"
		assertEquals(length, 3, "Length effect should re-run after append")
		list[3] = nil
		assertEquals(length, 2, "Length effect should re-run after removal")
	end

	-- Test 25: generalized iteration over a reactive proxy tracks key additions
	print("Test 25: generalized iteration (__iter) tracks new keys")
	do
		local obj = Rivue.reactive({ a = 1 })
		local keyCount = 0
		Rivue.watchEffect(function()
			keyCount = 0
			for _ in obj do
				keyCount += 1
			end
		end, { flush = "sync" })
		assertEquals(keyCount, 1, "Should iterate existing keys")
		obj.b = 2
		assertEquals(keyCount, 2, "Should re-run when a key is added")
	end

	-- Test 26: watch fires when source starts as nil, and not on creation
	print("Test 26: watch handles nil initial values without spurious calls")
	do
		local value = Rivue.ref(nil :: any)
		local calls = 0
		local lastNew, lastOld = nil, nil
		Rivue.watch(value, function(new, old)
			calls += 1
			lastNew, lastOld = new, old
		end, { flush = "sync" })
		assertEquals(calls, 0, "Watch should not fire on creation")
		value.value = "hello"
		assertEquals(calls, 1, "Watch should fire on first change from nil")
		assertEquals(lastNew, "hello", "New value should be passed")
		assertEquals(lastOld, nil, "Old value should be nil")
	end

	-- Test 27: deferred watch does not fire for unchanged source after creation
	print("Test 27: deferred watch is silent until the source changes")
	do
		local value = Rivue.ref(1)
		local calls = 0
		Rivue.watch(value, function()
			calls += 1
		end)
		task.wait(0.05)
		assertEquals(calls, 0, "Watch should not fire without a change")
		value.value = 2
		task.wait(0.05)
		assertEquals(calls, 1, "Watch should fire once after a change")
	end

	print("\n========== REACTIVITY TESTS COMPLETE ==========\n")
end

return runTests
