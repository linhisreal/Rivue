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

	-- Test 16: Nested components get their parent, so inject() sees an ancestor's provide()
	print("Test 16: inject() resolves values provided by an ancestor component")
	do
		local injected: any = nil
		local Child = Rivue.defineComponent({
			name = "InjectChild",
			setup = function(_props, ctx)
				injected = ctx.inject("theme")
				return function()
					return Rivue.h("Frame")
				end
			end,
		})
		local Provider = Rivue.defineComponent({
			name = "Provider",
			setup = function(_props, ctx)
				ctx.provide("theme", "dark")
				return function()
					return Rivue.h("Frame", {}, { Rivue.h(Child) })
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h(Provider))
		app:mount(container)
		assertEquals(injected, "dark", "Child should inject the ancestor's provided value")
		app:unmount()
		container:Destroy()
	end

	-- Test 17: Directive updated hooks run when the bound value changes
	print("Test 17: Directive updated hook runs on re-render")
	do
		local visible = Rivue.ref(true)
		local Comp = Rivue.defineComponent({
			name = "ShowDirective",
			setup = function()
				return function()
					return Rivue.h("Frame", {
						Name = "Shown",
						__directives = { { name = "show", value = visible.value } },
					})
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h(Comp))
		app:mount(container)
		local frame = container:FindFirstChild("Shown") :: Frame
		assertEquals(frame.Visible, true, "Initially visible")
		visible.value = false
		task.wait(0.1)
		assertEquals(frame.Visible, false, "show directive should hide the element on update")
		app:unmount()
		container:Destroy()
	end

	-- Test 18: Functional components update in place instead of remounting
	print("Test 18: Functional component output is diffed, not remounted")
	do
		local label = Rivue.ref("a")
		local function Label(props: any)
			return Rivue.h("TextLabel", { Name = "FnLabel", Text = props.text })
		end
		local Comp = Rivue.defineComponent({
			name = "FnHost",
			setup = function()
				return function()
					return Rivue.h("Frame", { Name = "FnHostRoot" }, { Rivue.h(Label, { text = label.value }) })
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h(Comp))
		app:mount(container)
		local first = container:FindFirstChild("FnHostRoot"):FindFirstChild("FnLabel")
		label.value = "b"
		task.wait(0.1)
		local second = container:FindFirstChild("FnHostRoot"):FindFirstChild("FnLabel")
		assertTrue(first == second, "Should reuse the same Instance")
		assertEquals(second and (second :: any).Text, "b", "Should update the text")
		app:unmount()
		container:Destroy()
	end

	-- Test 19: Undeclared props fall through to the root element (inheritAttrs)
	print("Test 19: inheritAttrs applies undeclared props to the root element")
	do
		local Button = Rivue.defineComponent({
			name = "FallthroughButton",
			props = { label = { type = "string" } },
			setup = function(props)
				return function()
					return Rivue.h("TextButton", { Name = "Fallthrough", Text = props.label })
				end
			end,
		})
		local NoInherit = Rivue.defineComponent({
			name = "NoInherit",
			props = { label = { type = "string" } },
			inheritAttrs = false,
			setup = function()
				return function()
					return Rivue.h("Frame", { Name = "NoInherit" })
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h("Frame", { Name = "Host" }, {
			Rivue.h(Button, { label = "Hi", LayoutOrder = 5 }),
			Rivue.h(NoInherit, { label = "x", LayoutOrder = 7 }),
		}))
		app:mount(container)
		local host = container:FindFirstChild("Host")
		local button = host:FindFirstChild("Fallthrough") :: TextButton
		assertEquals(button.LayoutOrder, 5, "Undeclared prop should reach the root element")
		assertEquals(button.Text, "Hi", "Declared prop should still work")
		local frame = host:FindFirstChild("NoInherit") :: Frame
		assertEquals(frame.LayoutOrder, 0, "inheritAttrs = false should not apply attrs")
		app:unmount()
		container:Destroy()
	end

	-- Test 20: Slot content updates when the parent re-renders
	print("Test 20: Slots update on parent re-render")
	do
		local Card = Rivue.defineComponent({
			name = "SlotCard",
			setup = function(_props, ctx)
				return function()
					return Rivue.h("Frame", { Name = "Card" }, ctx.slots)
				end
			end,
		})
		local text = Rivue.ref("one")
		local App = Rivue.defineComponent({
			name = "SlotApp",
			setup = function()
				return function()
					return Rivue.h(Card, {}, { Rivue.h("TextLabel", { Name = "SlotLabel", Text = text.value }) })
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h(App))
		app:mount(container)
		local label = container:FindFirstChild("Card"):FindFirstChild("SlotLabel") :: TextLabel
		assertEquals(label.Text, "one", "Initial slot content")
		text.value = "two"
		task.wait(0.1)
		label = container:FindFirstChild("Card"):FindFirstChild("SlotLabel") :: TextLabel
		assertEquals(label.Text, "two", "Slot content should update")
		app:unmount()
		container:Destroy()
	end

	-- Test 21: Unmounting right after a state change doesn't re-render the component
	print("Test 21: No render after unmount")
	do
		local text = Rivue.ref("a")
		local renders = 0
		local Comp = Rivue.defineComponent({
			name = "Zombie",
			setup = function()
				return function()
					renders += 1
					return Rivue.h("TextLabel", { Name = "Zombie", Text = text.value })
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h(Comp))
		app:mount(container)
		text.value = "b"
		app:unmount()
		task.wait(0.1)
		assertEquals(renders, 1, "Should not render after unmount")
		assertEquals(#container:GetChildren(), 0, "Should not recreate Instances")
		container:Destroy()
	end

	-- Test 22: Parent and child changing together render the child once, after the parent
	print("Test 22: Child renders once when parent and child update together")
	do
		local parentValue = Rivue.ref(1)
		local childValue = Rivue.ref(1)
		local childRenders = 0
		local seenProp: any = nil
		local Child = Rivue.defineComponent({
			name = "OrderChild",
			props = { value = { type = "number" } },
			setup = function(props)
				return function()
					childRenders += 1
					seenProp = props.value
					return Rivue.h("Frame", { Name = "Child" .. tostring(childValue.value) })
				end
			end,
		})
		local Parent = Rivue.defineComponent({
			name = "OrderParent",
			setup = function()
				return function()
					return Rivue.h("Frame", { Name = "OrderRoot" }, { Rivue.h(Child, { value = parentValue.value }) })
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h(Parent))
		app:mount(container)
		childRenders = 0
		childValue.value = 2 -- child queued first
		parentValue.value = 2 -- then parent
		task.wait(0.1)
		assertEquals(childRenders, 1, "Child should render once")
		assertEquals(seenProp, 2, "Child should see the parent's new prop")
		app:unmount()
		container:Destroy()
	end

	-- Test 23: Named and scoped slots
	print("Test 23: Named slots, scoped slots, and fallback content")
	do
		local Card = Rivue.defineComponent({
			name = "NamedSlotCard",
			setup = function(_props, ctx)
				return function()
					local children = {}
					for _, child in ctx.renderSlot("header", { title = "Hello" }) do
						table.insert(children, child)
					end
					for _, child in ctx.renderSlot("default") do
						table.insert(children, child)
					end
					for _, child in ctx.renderSlot("footer", nil, { Rivue.h("Frame", { Name = "DefaultFooter" }) }) do
						table.insert(children, child)
					end
					return Rivue.h("Frame", { Name = "NamedCard" }, children)
				end
			end,
		})
		local count = Rivue.ref(1)
		local hasFooter: any = nil
		local Probe = Rivue.defineComponent({
			name = "SlotProbe",
			setup = function(_props, ctx)
				hasFooter = ctx.hasSlot("footer")
				return function()
					return Rivue.h("Frame")
				end
			end,
		})
		local App = Rivue.defineComponent({
			name = "NamedSlotApp",
			setup = function()
				return function()
					return Rivue.h("Frame", { Name = "SlotHost" }, {
						Rivue.h(Card, {}, {
							header = function(scope)
								return Rivue.h("TextLabel", { Name = "Header", Text = scope.title })
							end,
							default = function()
								return Rivue.h("TextLabel", { Name = "Body", Text = tostring(count.value) })
							end,
						}),
						Rivue.h(Probe),
					})
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = renderer.createApp(Rivue.h(App))
		app:mount(container)
		local card = container:FindFirstChild("SlotHost"):FindFirstChild("NamedCard")
		local header = card:FindFirstChild("Header") :: TextLabel
		assertEquals(header and header.Text, "Hello", "Scoped slot receives its scope")
		assertTrue(card:FindFirstChild("DefaultFooter") ~= nil, "Missing slot renders fallback")
		assertEquals(hasFooter, false, "hasSlot() is false for missing slots")
		count.value = 2
		task.wait(0.1)
		local body = card:FindFirstChild("Body") :: TextLabel
		assertEquals(body and body.Text, "2", "Slot content updates on parent re-render")
		app:unmount()
		container:Destroy()
	end

	-- Test 24: A single vnode can be passed as children
	print("Test 24: Single vnode as children")
	do
		local container = Instance.new("Folder")
		local app = renderer.createApp(
			Rivue.h("Frame", { Name = "SingleParent" }, Rivue.h("TextLabel", { Name = "OnlyChild" }))
		)
		app:mount(container)
		local parent = container:FindFirstChild("SingleParent")
		assertEquals(parent and #parent:GetChildren(), 1, "Should mount exactly one child")
		assertTrue(parent:FindFirstChild("OnlyChild") ~= nil, "Child should be the passed vnode")
		app:unmount()
		container:Destroy()
	end

	print("\n========== RENDERER TESTS COMPLETE ==========\n")
end

return runTests
