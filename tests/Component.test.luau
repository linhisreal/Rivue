--!strict
--[[
	Component Unit Tests
	====================
	
	Tests for component.luau - Component instance lifecycle and prop validation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
-- local component_module = require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("component"))

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
	local printHeader = "COMPONENT TEST SUITE"
	print("\n" .. string.rep("=", 40))
	print(printHeader)
	print(string.rep("=", 40) .. "\n")
	
	-- Test 1: onMounted hook registration
	print("Test 1: onMounted hook registration")
	do
		local mounted = false
		local TestComponent = Rivue.defineComponent({
			name = "TestMounted",
			setup = function()
				Rivue.onMounted(function()
					mounted = true
				end)
				return function()
					return Rivue.h("Frame")
				end
			end
		})
		
		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.1)
		assertTrue(mounted, "Should call onMounted hook")
		app:unmount()
		container:Destroy()
	end
	
	-- Test 2: onUnmounted hook registration
	print("Test 2: onUnmounted hook registration")
	do
		local unmounted = false
		local TestComponent = Rivue.defineComponent({
			name = "TestUnmounted",
			setup = function()
				Rivue.onUnmounted(function()
					unmounted = true
				end)
				return function()
					return Rivue.h("Frame")
				end
			end
		})
		
		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.05)
		app:unmount()
		task.wait(0.05)
		assertTrue(unmounted, "Should call onUnmounted hook")
		container:Destroy()
	end
	
	-- Test 3: onBeforeMount hook registration
	print("Test 3: onBeforeMount hook registration")
	do
		local beforeMountCalled = false
		local TestComponent = Rivue.defineComponent({
			name = "TestBeforeMount",
			setup = function()
				Rivue.onBeforeMount(function()
					beforeMountCalled = true
				end)
				return function()
					return Rivue.h("Frame")
				end
			end
		})
		
		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.1)
		assertTrue(beforeMountCalled, "Should call onBeforeMount hook")
		app:unmount()
		container:Destroy()
	end
	
	-- Test 4: onBeforeUnmount hook registration
	print("Test 4: onBeforeUnmount hook registration")
	do
		local beforeUnmountCalled = false
		local TestComponent = Rivue.defineComponent({
			name = "TestBeforeUnmount",
			setup = function()
				Rivue.onBeforeUnmount(function()
					beforeUnmountCalled = true
				end)
				return function()
					return Rivue.h("Frame")
				end
			end
		})
		
		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.05)
		app:unmount()
		task.wait(0.05)
		assertTrue(beforeUnmountCalled, "Should call onBeforeUnmount hook")
		container:Destroy()
	end
	
	-- Test 5: Prop defaults are applied
	print("Test 5: Prop defaults are applied")
	do
		local receivedProps: any = nil
		local TestComponent = Rivue.defineComponent({
			name = "TestDefaults",
			props = {
				count = {
					type = "number",
					default = 10
				}
			},
			setup = function(props)
				receivedProps = props
				return function()
					return Rivue.h("Frame")
				end
			end
		})
		
		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.05)
		assertEquals(receivedProps.count, 10, "Should apply default prop value")
		app:unmount()
		container:Destroy()
	end
	
	-- Test 6: Factory function defaults
	print("Test 6: Factory function defaults")
	do
		local receivedProps: any = nil
		local TestComponent = Rivue.defineComponent({
			name = "TestFactoryDefaults",
			props = {
				config = {
					type = "table",
					default = function()
						return { x = 1, y = 2 }
					end
				}
			},
			setup = function(props)
				receivedProps = props
				return function()
					return Rivue.h("Frame")
				end
			end
		})
		
		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.05)
		assertTrue(type(receivedProps.config) == "table", "Should apply factory default")
		assertTrue(receivedProps.config.x == 1, "Should have correct factory values")
		app:unmount()
		container:Destroy()
	end
	
	-- Test 7: ctx.expose() works
	print("Test 7: ctx.expose() works")
	do
		local testRef = Rivue.ref(nil)
		local TestComponent = Rivue.defineComponent({
			name = "TestExpose",
			setup = function(_props, ctx)
				ctx.expose({
					testMethod = function()
						return "exposed"
					end
				})
				return function()
					return Rivue.h("Frame")
				end
			end
		})
		
		local container = Instance.new("Folder")
		local app = Rivue.mount(Rivue.h(TestComponent, { ref = testRef }), container)
		task.wait(0.1)
		assertTrue(testRef.value and true or false, "Ref should be set")
		if testRef.value then
			assertTrue(type(testRef.value.testMethod) == "function", "Should have exposed method")
			assertEquals(testRef.value.testMethod(), "exposed", "Exposed method should work")
		end
		app:unmount()
		container:Destroy()
	end
	
	local printFooter = "COMPONENT TESTS COMPLETE"
	print("\n" .. string.rep("=", 40))
	print(printFooter)
	print(string.rep("=", 40) .. "\n")
end

return runTests
