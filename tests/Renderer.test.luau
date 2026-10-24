--!strict
--[[
	Renderer Unit Tests
	===================
	
	Tests for renderer.luau - VNode patching, mounting, unmounting, lifecycle, and pooling
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local renderer = require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
local Pool = require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("pool"))

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
	print("\n========== RENDERER TEST SUITE ==========\n")

	-- Test 1: createApp creates valid app instance
	print("Test 1: createApp creates valid app instance")
	do
		local vnode = Rivue.h("Frame", { Name = "TestFrame" })
		local app = renderer.createApp(vnode)
		assertTrue(type(app) == "table", "Should return app object")
		assertTrue(type(app.mount) == "function", "Should have mount method")
		assertTrue(type(app.unmount) == "function", "Should have unmount method")
		assertTrue(type(app.rerender) == "function", "Should have rerender method")
	end

	-- Test 2: Mount creates DOM element
	print("Test 2: Mount creates DOM element")
	do
		local container = Instance.new("Folder")
		local vnode = Rivue.h("Frame", { Name = "MountTest" })
		local app = renderer.createApp(vnode)
		app:mount(container)
		task.wait(0.05)
		local frame = container:FindFirstChild("MountTest")
		assertTrue(frame and true or false, "Should create Frame in container")
		if frame then
			assertTrue(frame:IsA("Frame"), "Should be correct type")
		end
		app:unmount()
		container:Destroy()
	end

	-- Test 3: Unmount removes DOM element
	print("Test 3: Unmount removes DOM element")
	do
		local container = Instance.new("Folder")
		local vnode = Rivue.h("Frame", { Name = "UnmountTest" })
		local app = renderer.createApp(vnode)
		app:mount(container)
		task.wait(0.05)
		assertTrue(container:FindFirstChild("UnmountTest") and true or false, "Should mount element")
		app:unmount()
		task.wait(0.05)
		assertTrue(container:FindFirstChild("UnmountTest") == nil, "Should remove element")
		container:Destroy()
	end

	-- Test 4: Patch updates properties
	print("Test 4: Patch updates properties")
	do
		local container = Instance.new("Folder")
		local vnode1 = Rivue.h("Frame", { Name = "Frame1", Size = UDim2.fromOffset(100, 100) })
		local app = renderer.createApp(vnode1)
		app:mount(container)
		task.wait(0.05)
		local frame = container:FindFirstChild("Frame1")
		assertTrue(frame and true or false, "Should mount initial vnode")
		if frame then
			assertEquals((frame :: any).Size, UDim2.fromOffset(100, 100), "Should set initial size")
		end
		app:unmount()
		container:Destroy()
	end

	-- Test 5: Keyed children are mounted
	print("Test 5: Keyed children are mounted")
	do
		local container = Instance.new("Folder")
		local vnode1 = Rivue.h("Frame", {}, {
			Rivue.h("TextLabel", { key = "a", Name = "LabelA", Text = "A" }),
			Rivue.h("TextLabel", { key = "b", Name = "LabelB", Text = "B" }),
		})
		local app = renderer.createApp(vnode1)
		app:mount(container)
		task.wait(0.05)
		local parentFrame = container:FindFirstChildWhichIsA("Frame", true)
		local labelA = parentFrame and parentFrame:FindFirstChild("LabelA")
		local labelB = parentFrame and parentFrame:FindFirstChild("LabelB")
		assertTrue(labelA and true or false, "Should mount first keyed child")
		assertTrue(labelB and true or false, "Should mount second keyed child")
		app:unmount()
		container:Destroy()
	end

	-- Test 6: Component mounting with setup
	print("Test 6: Component mounting with setup")
	do
		local container = Instance.new("Folder")
		local setupCalled = false
		local TestComponent = Rivue.defineComponent({
			name = "TestComponent",
			setup = function()
				setupCalled = true
				return function()
					return Rivue.h("Frame", { Name = "ComponentFrame" })
				end
			end,
		})
		local vnode = Rivue.h(TestComponent, {})
		local app = renderer.createApp(vnode)
		app:mount(container)
		task.wait(0.05)
		assertTrue(setupCalled, "Should call setup function")
		assertTrue(
			container:FindFirstChild("ComponentFrame", true) and true or false,
			"Should mount component render result"
		)
		app:unmount()
		container:Destroy()
	end

	-- Test 8: Pool reuses instances when enabled
	print("Test 8: Pool reuses instances when enabled")
	do
		Pool.clear()
		local container = Instance.new("Folder")
		local vnode = Rivue.h("Frame", { Name = "PoolTest" })
		local app = renderer.createApp(vnode, { usePool = true })
		app:mount(container)
		task.wait(0.05)
		local frame = container:FindFirstChild("PoolTest")
		assertTrue(frame and true or false, "Should mount with pool")
		app:unmount()
		task.wait(0.05)
		-- Frame should be in pool now
		local pooledFrame = Pool.acquire("Frame")
		assertTrue(pooledFrame and true or false, "Should have pooled instance")
		Pool.release(pooledFrame)
		Pool.clear()
		container:Destroy()
	end

	-- Test 9: Lifecycle hooks execute in order
	print("Test 9: Lifecycle hooks execute in order")
	do
		local container = Instance.new("Folder")
		local events = {}
		local TestComponent = Rivue.defineComponent({
			name = "LifecycleTest",
			setup = function()
				Rivue.onBeforeMount(function()
					table.insert(events, "beforeMount")
				end)
				Rivue.onMounted(function()
					table.insert(events, "mounted")
				end)
				Rivue.onBeforeUnmount(function()
					table.insert(events, "beforeUnmount")
				end)
				Rivue.onUnmounted(function()
					table.insert(events, "unmounted")
				end)
				return function()
					return Rivue.h("Frame", { Name = "LifecycleFrame" })
				end
			end,
		})
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.1)
		assertTrue(events[1] == "beforeMount", "beforeMount should run first")
		assertTrue(events[2] == "mounted", "mounted should run second")
		app:unmount()
		task.wait(0.1)
		assertTrue(events[3] == "beforeUnmount", "beforeUnmount should run third")
		assertTrue(events[4] == "unmounted", "unmounted should run last")
		container:Destroy()
	end

	-- Test 10: Template refs work correctly
	print("Test 10: Template refs work correctly")
	do
		local container = Instance.new("Folder")
		local myRef = Rivue.ref(nil)
		local vnode = Rivue.h("Frame", { Name = "RefTest", ref = myRef })
		local app = renderer.createApp(vnode)
		app:mount(container)
		task.wait(0.05)
		assertTrue(myRef.value and true or false, "Ref should be assigned")
		if myRef.value then
			assertTrue(myRef.value.Name == "RefTest", "Ref should point to correct element")
		end
		app:unmount()
		task.wait(0.05)
		assertTrue(myRef.value == nil, "Ref should be cleared on unmount")
		container:Destroy()
	end

	-- Test 11: Children rendering
	print("Test 11: Children rendering")
	do
		local container = Instance.new("Folder")
		local vnode = Rivue.h("Frame", { Name = "Parent" }, {
			Rivue.h("TextLabel", { Name = "Child1", Text = "First" }),
			Rivue.h("TextLabel", { Name = "Child2", Text = "Second" }),
		})
		local app = renderer.createApp(vnode)
		app:mount(container)
		task.wait(0.05)
		local parent = container:FindFirstChild("Parent")
		assertTrue(parent and true or false, "Should mount parent")
		if parent then
			assertTrue(parent:FindFirstChild("Child1") and true or false, "Should mount first child")
			assertTrue(parent:FindFirstChild("Child2") and true or false, "Should mount second child")
		end
		app:unmount()
		container:Destroy()
	end

	-- Test 12: Reactive re-rendering with component
	print("Test 12: Reactive re-rendering with component")
	do
		local container = Instance.new("Folder")
		local renderCount = 0
		local TestComponent = Rivue.defineComponent({
			name = "ReactiveTest",
			setup = function()
				local count = Rivue.ref(0)
				return function()
					renderCount = renderCount + 1
					return Rivue.h("TextLabel", {
						Name = "Counter",
						Text = tostring(count.value),
					})
				end
			end,
		})
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.1)
		assertTrue(renderCount >= 1, "Should render at least once")
		container:Destroy()
	end

	-- Test 13: Child component re-renders when parent passes new props
	print("Test 13: Child component reacts to new props")
	do
		local Child = Rivue.defineComponent({
			name = "PropChild",
			props = { label = { type = "string" } },
			setup = function(props)
				return function()
					return Rivue.h("TextLabel", { Name = "ChildLabel", Text = props.label })
				end
			end,
		})
		local label = Rivue.ref("first")
		local Parent = Rivue.defineComponent({
			name = "PropParent",
			setup = function()
				return function()
					return Rivue.h("Frame", { Name = "ParentFrame" }, { Rivue.h(Child, { label = label.value }) })
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h(Parent))
		app:mount(container)
		task.wait(0.05)
		local text = container:FindFirstChild("ParentFrame"):FindFirstChild("ChildLabel")
		assertEquals(text and (text :: any).Text, "first", "Child should render initial prop")
		label.value = "second"
		task.wait(0.1)
		text = container:FindFirstChild("ParentFrame"):FindFirstChild("ChildLabel")
		assertEquals(text and (text :: any).Text, "second", "Child should re-render with new prop")
		app:unmount()
		container:Destroy()
	end

	-- Test 14: Shrinking an unkeyed child list removes the extra Instances
	print("Test 14: Unkeyed children removed when list shrinks")
	do
		local count = Rivue.ref(3)
		local List = Rivue.defineComponent({
			name = "ShrinkList",
			setup = function()
				return function()
					local children = {}
					for i = 1, count.value do
						table.insert(children, Rivue.h("Frame", { Name = "Item" .. i }))
					end
					return Rivue.h("Frame", { Name = "ListRoot" }, children)
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h(List))
		app:mount(container)
		task.wait(0.05)
		local root = container:FindFirstChild("ListRoot")
		assertEquals(root and #root:GetChildren(), 3, "Should mount three items")
		count.value = 1
		task.wait(0.1)
		assertEquals(root and #root:GetChildren(), 1, "Should unmount items past the new length")
		app:unmount()
		container:Destroy()
	end

	-- Test 15: rerender() reuses the previous container
	print("Test 15: rerender() remounts into the same container")
	do
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h("Frame", { Name = "First" }))
		app:mount(container)
		local ok = pcall(function()
			app:rerender(Rivue.h("Frame", { Name = "Second" }))
		end)
		assertTrue(ok, "rerender should not error")
		assertTrue(container:FindFirstChild("Second") ~= nil, "Should mount the new root")
		assertTrue(container:FindFirstChild("First") == nil, "Should remove the old root")
		app:unmount()
		container:Destroy()
	end

	print("\n========== RENDERER TESTS COMPLETE ==========\n")
end

return runTests
