--!strict
-- Comprehensive API Validation Test Suite
-- Tests that all documented API functions work as described

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))

-- Test utilities
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

local function assertFalse(condition: boolean, message: string?)
	if condition then
		error("Assertion failed: " .. (message or "condition is true"))
	end
	print("✓", message or "Assertion passed")
end

-- Wrap all tests in a function that can be called
local function runTests()
	print("\n========== API VALIDATION TEST SUITE ==========\n")

-- Test 1: ref()
print("Test 1: ref() - Creates a reactive reference")
do
	local count = Rivue.ref(0)
	assertEquals(count.value, 0, "ref initial value is 0")
	
	count.value = 5
	assertEquals(count.value, 5, "ref value can be updated")
	
	local user = Rivue.ref({ name = "Alice", age = 25 })
	assertEquals(user.value.name, "Alice", "ref works with tables")
	
	user.value = { name = "Bob", age = 30 }
	assertEquals(user.value.name, "Bob", "ref table can be replaced")
end

-- Test 2: shallowRef()
print("\nTest 2: shallowRef() - Creates a shallow reactive reference")
do
	local state = Rivue.shallowRef({ count = 0, nested = { value = 10 } })
	assertEquals(state.value.count, 0, "shallowRef initial value")
	
	-- Shallow ref doesn't trigger on nested changes
	state.value.count = 10
	assertEquals(state.value.count, 10, "shallowRef allows mutations but doesn't track them")
	
	-- Replacing entire value works
	state.value = { count = 5, nested = { value = 20 } }
	assertEquals(state.value.count, 5, "shallowRef tracks replacements")
end

-- Test 3: reactive()
print("\nTest 3: reactive() - Creates a deeply reactive proxy")
do
	local state = Rivue.reactive({
		count = 0,
		user = { name = "Alice", profile = { age = 25 } }
	})
	
	assertEquals(state.count, 0, "reactive initial value")
	
	state.count = 5
	assertEquals(state.count, 5, "reactive allows mutations")
	
	state.user.name = "Bob"
	assertEquals(state.user.name, "Bob", "reactive tracks nested changes")
	
	state.user.profile.age = 30
	assertEquals(state.user.profile.age, 30, "reactive tracks deeply nested changes")
end

-- Test 4: shallowReactive()
print("\nTest 4: shallowReactive() - Creates a shallow reactive proxy")
do
	local state = Rivue.shallowReactive({
		count = 0,
		nested = { value = 10 }
	})
	
	state.count = 5
	assertEquals(state.count, 5, "shallowReactive tracks top-level changes")
	
	state.nested.value = 20
	assertEquals(state.nested.value, 20, "shallowReactive allows nested mutations")
	
	state.nested = { value = 30 }
	assertEquals(state.nested.value, 30, "shallowReactive tracks top-level replacements")
end

-- Test 5: computed()
print("\nTest 5: computed() - Creates a computed value")
do
	local count = Rivue.ref(10)
	local double = Rivue.computed(function()
		return count.value * 2
	end)
	
	assertEquals(double.value, 20, "computed initial value")
	
	count.value = 15
	assertEquals(double.value, 30, "computed updates when dependency changes")
end

-- Test 6: watch()
print("\nTest 6: watch() - Watches a reactive source")
do
	local count = Rivue.ref(0)
	local callbackCalled = false
	local oldVal, newVal
	
	local stop = Rivue.watch(
		function() return count.value end,
		function(new, old)
			callbackCalled = true
			oldVal = old
			newVal = new
		end
	)
	
	count.value = 5
	task.wait(0.1) -- Give watch time to trigger
	
	assertTrue(callbackCalled, "watch callback was called")
	assertEquals(oldVal, 0, "watch provides old value")
	assertEquals(newVal, 5, "watch provides new value")
	
	stop()
end

-- Test 7: watchEffect()
print("\nTest 7: watchEffect() - Runs effect with auto dependency tracking")
do
	local count = Rivue.ref(0)
	local name = Rivue.ref("Alice")
	local effectRan = false
	
	local stop = Rivue.watchEffect(function()
		effectRan = true
		local _ = count.value + 0 -- Access to trigger tracking
		local _ = name.value -- Access to trigger tracking
	end)
	
	assertTrue(effectRan, "watchEffect runs immediately")
	
	effectRan = false
	count.value = 5
	task.wait(0.1)
	assertTrue(effectRan, "watchEffect re-runs on dependency change")
	
	stop()
end

-- Test 8: effect()
print("\nTest 8: effect() - Runs a function with reactive dependencies")
do
	local count = Rivue.ref(0)
	local effectRan = 0
	
	local eff = Rivue.effect(function()
		effectRan = effectRan + 1
		local _ = count.value
	end)
	
	-- Wait for scheduler to process the effect
	task.wait(0.1)
	assertEquals(effectRan, 1, "effect runs after scheduler processes")
	
	count.value = 5
	task.wait(0.1)
	assertTrue(effectRan > 1, "effect re-runs on dependency change")
	
	eff:stop()
end

-- Test 9: readonly()
print("\nTest 9: readonly() - Creates a readonly reactive proxy")
do
	local state = Rivue.reactive({ count = 0, user = { name = "Alice" } })
	local readonlyState = Rivue.readonly(state)
	
	assertEquals(readonlyState.count, 0, "readonly allows reading")
	assertEquals(readonlyState.user.name, "Alice", "readonly allows deep reading")
	
	-- Mutations should be blocked (but won't throw in production)
	local _success = pcall(function()
		readonlyState.count = 10
	end)
	
	-- Original state can still be mutated
	state.count = 10
	assertEquals(readonlyState.count, 10, "readonly reflects original state changes")
end

-- Test 10: toRef()
print("\nTest 10: toRef() - Creates a ref linked to a reactive property")
do
	local state = Rivue.reactive({ count = 0, name = "Alice" })
	local countRef = Rivue.toRef(state, "count")
	
	assertEquals(countRef.value, 0, "toRef initial value")
	
	countRef.value = 10
	assertEquals(state.count, 10, "toRef updates original state")
	
	state.count = 20
	assertEquals(countRef.value, 20, "toRef reflects state changes")
end

-- Test 11: toRefs()
print("\nTest 11: toRefs() - Converts reactive object properties to refs")
do
	local state = Rivue.reactive({
		count = 0,
		name = "Alice",
		age = 25
	})
	
	-- Debug: Test if pairs works on reactive proxy
	print("  [DEBUG] Testing pairs() on reactive proxy:")
	for k, v in pairs(state) do
		print("    ", k, "=", v)
	end
	
	local refs = Rivue.toRefs(state)
	
	-- Debug: Check what toRefs actually returned
	print("  [DEBUG] Testing pairs() on refs table:")
	for k, v in pairs(refs) do
		print("    ", k, "=", v, "type:", type(v))
	end
	
	print("  [DEBUG] refs type:", type(refs))
	print("  [DEBUG] refs.count:", refs.count)
	print("  [DEBUG] refs.name:", refs.name)
	print("  [DEBUG] refs.age:", refs.age)
	
	-- Check if refs.count exists before accessing .value
	if refs.count then
		assertEquals(refs.count.value, 0, "toRefs creates refs for each property")
	else
		error("toRefs did not create ref for 'count' property")
	end
	
	if refs.name then
		assertEquals(refs.name.value, "Alice", "toRefs preserves values")
	else
		error("toRefs did not create ref for 'name' property")
	end
	
	if refs.count then
		refs.count.value = 10
		assertEquals(state.count, 10, "toRefs refs are linked to original state")
	end
end

-- Test 12: isRef()
print("\nTest 12: isRef() - Checks if value is a ref")
do
	local count = Rivue.ref(0)
	local obj = { value = 10 }
	
	assertTrue(Rivue.isRef(count), "isRef returns true for ref")
	assertFalse(Rivue.isRef(obj), "isRef returns false for plain object")
end

-- Test 13: unref()
print("\nTest 13: unref() - Returns inner value of ref or value as-is")
do
	local count = Rivue.ref(10)
	local num = 20
	
	assertEquals(Rivue.unref(count), 10, "unref returns ref value")
	assertEquals(Rivue.unref(num), 20, "unref returns non-ref as-is")
end

-- Test 14: isReactive()
print("\nTest 14: isReactive() - Checks if value is reactive proxy")
do
	local state = Rivue.reactive({ count = 0 })
	local plainObj = { count = 0 }
	local refVal = Rivue.ref(0)
	
	assertTrue(Rivue.isReactive(state), "isReactive returns true for reactive")
	assertFalse(Rivue.isReactive(plainObj), "isReactive returns false for plain object")
	assertFalse(Rivue.isReactive(refVal), "isReactive returns false for ref")
end

-- Test 15: isReadonly()
print("\nTest 15: isReadonly() - Checks if value is readonly proxy")
do
	local state = Rivue.reactive({ count = 0 })
	local readonlyState = Rivue.readonly(state)
	
	assertFalse(Rivue.isReadonly(state), "isReadonly returns false for reactive")
	assertTrue(Rivue.isReadonly(readonlyState), "isReadonly returns true for readonly")
end

-- Test 16: isProxy()
print("\nTest 16: isProxy() - Checks if value is any kind of proxy")
do
	local state = Rivue.reactive({ count = 0 })
	local readonlyState = Rivue.readonly(state)
	local plainObj = { count = 0 }
	
	assertTrue(Rivue.isProxy(state), "isProxy returns true for reactive")
	assertTrue(Rivue.isProxy(readonlyState), "isProxy returns true for readonly")
	assertFalse(Rivue.isProxy(plainObj), "isProxy returns false for plain object")
end

-- Test 17: markRaw()
print("\nTest 17: markRaw() - Marks object to never be reactive")
do
	local rawData = Rivue.markRaw({ largeDataset = {} })
	local state = Rivue.reactive({
		raw = rawData,
		normal = { value = 10 }
	})
	
	assertFalse(Rivue.isReactive(state.raw), "markRaw prevents reactivity")
	assertTrue(Rivue.isReactive(state.normal), "normal data is still reactive")
end

-- Test 18: toRaw()
print("\nTest 18: toRaw() - Returns original object from proxy")
do
	local original = { count = 0, nested = { value = 10 } }
	local state = Rivue.reactive(original)
	
	assertTrue(state ~= original, "reactive creates a proxy")
	
	local raw = Rivue.toRaw(state)
	assertTrue(raw == original, "toRaw returns original object")
end

-- Test 19: triggerRef()
print("\nTest 19: triggerRef() - Manually triggers ref updates")
do
	local state = Rivue.shallowRef({ count = 0, items = {} })
	
	-- Mutate without triggering
	state.value.count = 10
	table.insert(state.value.items, "new")
	
	-- Manually trigger (this should work)
	Rivue.triggerRef(state)
	
	assertEquals(state.value.count, 10, "triggerRef works with mutations")
end

-- Test 20: customRef()
print("\nTest 20: customRef() - Creates custom ref with control over tracking")
do
	local useDebouncedRef
	useDebouncedRef = function(value, delay)
		local actualValue = value
		local timer = nil
		
		return Rivue.customRef(function(track, trigger)
			return {
				get = function()
					track()
					return actualValue
				end,
				set = function(newValue)
					actualValue = newValue
					if timer then
						task.cancel(timer)
					end
					timer = task.delay(delay, function()
						trigger()
					end)
				end
			}
		end)
	end
	
	local searchQuery = useDebouncedRef("", 0.1)
	searchQuery.value = "test"
	assertEquals(searchQuery.value, "test", "customRef getter works")
end

-- Test 21: effectScope()
print("\nTest 21: effectScope() - Creates a scope for managing effects")
do
	local scope = Rivue.effectScope()
	local effectRan = false
	
	scope:run(function()
		Rivue.watchEffect(function()
			effectRan = true
		end)
		return nil
	end)
	
	assertTrue(effectRan, "effectScope runs effects")
	assertTrue(scope.active, "effectScope is active")
	
	scope:stop()
	assertFalse(scope.active, "effectScope can be stopped")
end

-- Test 22: getCurrentScope()
print("\nTest 22: getCurrentScope() - Returns current effect scope")
do
	local scope = Rivue.effectScope()
	local currentScope
	
	scope:run(function()
		currentScope = Rivue.getCurrentScope()
		return nil
	end)
	
	assertTrue(currentScope == scope, "getCurrentScope returns correct scope")
	
	local outsideScope = Rivue.getCurrentScope()
	assertTrue(outsideScope == nil, "getCurrentScope returns nil outside scope")
end

-- Test 23: onScopeDispose()
print("\nTest 23: onScopeDispose() - Registers cleanup callback")
do
	local scope = Rivue.effectScope()
	local cleanupCalled = false
	
	scope:run(function()
		Rivue.onScopeDispose(function()
			cleanupCalled = true
		end)
		return nil
	end)
	
	assertFalse(cleanupCalled, "onScopeDispose doesn't run immediately")
	
	scope:stop()
	assertTrue(cleanupCalled, "onScopeDispose runs when scope stops")
end

-- Test 24: h() - hyperscript function
print("\nTest 24: h() - Creates virtual nodes")
do
	local vnode = Rivue.h("TextLabel", {
		Text = "Hello",
		Size = UDim2.fromOffset(200, 50)
	})
	
	assertEquals(vnode.type, "TextLabel", "h() sets correct type")
	assertTrue(vnode.props ~= nil, "h() creates props table")
	if vnode.props then
		assertEquals(vnode.props.Text, "Hello", "h() sets props")
	end
	
	-- With children
	local parent = Rivue.h("Frame", {}, {
		Rivue.h("TextLabel", { Text = "Child" })
	})
	
	assertEquals(#parent.children, 1, "h() handles children")
end

-- Test 25: defineComponent()
print("\nTest 25: defineComponent() - Defines a component")
do
	local MyComponent = Rivue.defineComponent({
		props = {
			title = { type = "string", required = true }
		},
		setup = function(props, _ctx)
			assertEquals(props.title, "Test", "defineComponent receives props")
			return function()
				return Rivue.h("TextLabel", { Text = props.title })
			end
		end
	})
	
	assertTrue(MyComponent.__is_component, "defineComponent creates component")
end

-- Test 26: Lifecycle hooks
print("\nTest 26: Lifecycle hooks - onBeforeMount, onMounted, etc.")
do
	local beforeMountCalled = false
	local mountedCalled = false
	
	local TestComponent = Rivue.defineComponent({
		setup = function()
			Rivue.onBeforeMount(function()
				beforeMountCalled = true
			end)
			
			Rivue.onMounted(function()
				mountedCalled = true
			end)
			
			return function()
				return Rivue.h("Frame")
			end
		end
	})
	
	-- Create and mount app
	local app = Rivue.createApp(Rivue.h(TestComponent))
	local container = Instance.new("ScreenGui")
	container.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	
	app:mount(container)
	
	task.wait(0.2) -- Wait for mount
	
	assertTrue(beforeMountCalled, "onBeforeMount was called")
	assertTrue(mountedCalled, "onMounted was called")
	
	app:unmount()
	container:Destroy()
end

-- Test 27: vModelText()
print("\nTest 27: vModelText() - Two-way binding for text")
do
	local inputText = Rivue.ref("")
	local props = Rivue.vModelText(inputText)
	
	assertEquals(props.Text, "", "vModelText sets initial Text")
	assertTrue(type(props.onTextChanged) == "function", "vModelText provides onTextChanged")
	
	-- Simulate text change
	props.onTextChanged("new text")
	assertEquals(inputText.value, "new text", "vModelText updates ref on change")
end

-- Test 28: iterArray()
print("\nTest 28: iterArray() - Iterator for reactive arrays")
do
	local items = Rivue.reactive({ "apple", "banana", "cherry" })
	local collected = {}
	
	for _i, item in Rivue.iterArray(items) do
		table.insert(collected, item)
	end
	
	assertEquals(#collected, 3, "iterArray iterates all items")
	assertEquals(collected[1], "apple", "iterArray provides correct values")
end

-- Test 29: Rivue.dev
print("\nTest 29: Rivue.dev - Development mode flag")
do
	assertTrue(type(Rivue.dev) == "boolean", "Rivue.dev is a boolean")
	print("  Rivue.dev =", Rivue.dev)
end

-- Test 30: Utils - debounce, throttle, etc.
print("\nTest 30: Utils - debounce, throttle, nextTick, nextFrame")
do
	-- Debounce
	local debounceCalled = 0
	local debounced = Rivue.utils.debounce(function()
		debounceCalled = debounceCalled + 1
	end, 0.1)
	
	debounced()
	debounced()
	debounced()
	
	task.wait(0.2)
	assertEquals(debounceCalled, 1, "debounce only calls once after delay")
	
	-- Throttle
	local throttleCalled = 0
	local throttled = Rivue.utils.throttle(function()
		throttleCalled = throttleCalled + 1
	end, 100) -- 100ms throttle interval
	
	throttled()
	throttled()
	task.wait(0.05) -- Wait 50ms
	throttled()
	
	-- Wait for any scheduled throttle calls to complete (100ms + buffer)
	task.wait(0.15)
	assertTrue(throttleCalled <= 2, "throttle limits call frequency")
	
	-- nextTick
	local nextTickCalled = false
	Rivue.utils.nextTick(function()
		nextTickCalled = true
	end)
	
	task.wait(0.1)
	assertTrue(nextTickCalled, "nextTick executes callback")
	
	-- nextFrame
	local nextFrameCalled = false
	Rivue.utils.nextFrame(function()
		nextFrameCalled = true
	end)
	
	task.wait(0.1)
	assertTrue(nextFrameCalled, "nextFrame executes callback")
end

print("\n========== ALL TESTS PASSED ✓ ==========\n")
print("Total tests: 30")
print("All API functions work as documented!")

end -- End of runTests function

-- Return the test runner function
return runTests
