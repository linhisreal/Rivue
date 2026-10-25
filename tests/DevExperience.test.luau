--!strict
--[[
	Developer Experience Unit Tests
	===============================

	Tests for directive props, model, nested children, style, mergeProps/cloneVNode, createApp
	with a component, defineComponent(setup), Explorer names, printTree, render debug hooks,
	error reporting, Teleport defer and the app context helpers
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local renderer = require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))

local h = Rivue.h

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

--- Runs fn and collects what it passed to warn()
local function captureWarnings(fn: () -> ()): { string }
	local warnings: { string } = {}
	local realWarn = warn
	warn = function(...: any)
		local parts = {}
		for i = 1, select("#", ...) do
			table.insert(parts, tostring((select(i, ...))))
		end
		table.insert(warnings, table.concat(parts, " "))
	end :: any
	local ok, err = pcall(fn)
	warn = realWarn
	if not ok then
		error(err, 0)
	end
	return warnings
end

local function anyContains(list: { string }, text: string): boolean
	for _, line in list do
		if string.find(line, text, 1, true) then
			return true
		end
	end
	return false
end

local function runTests()
	print("\n========== DEVELOPER EXPERIENCE TEST SUITE ==========\n")

	-- Test 1: v* props become directives
	print("Test 1: Directive props")
	do
		local container = Instance.new("Frame")
		local v1 = h("Frame", { Name = "Panel", vShow = false })
		assertTrue(v1.props.vShow == nil, "vShow is removed from props")
		assertEquals(v1.props.__directives[1].name, "show", "vShow becomes the show directive")
		renderer.patch(nil, v1, container)
		local panel = container:FindFirstChild("Panel") :: Frame
		assertEquals(panel.Visible, false, "vShow = false hides the element")
		local v2 = h("Frame", { Name = "Panel", vShow = true })
		renderer.patch(v1, v2, container)
		assertEquals(panel.Visible, true, "vShow = true shows it again")

		local multi = h("Frame", { vClickOutside = function() end, vDrag = true })
		assertEquals(#multi.props.__directives, 2, "Multi-word names map to kebab-case directives")
		local plain = h("Frame", { vNotADirective = 1 })
		assertEquals(plain.props.vNotADirective, 1, "Unregistered v* props are left alone")
	end

	-- Test 2: model on a TextBox
	print("Test 2: model prop on TextBox")
	do
		local text = Rivue.ref("hello")
		local Form = Rivue.defineComponent({
			name = "Form",
			setup = function()
				return function()
					return h("TextBox", { Name = "Input", model = text })
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(Form)
		app:mount(container)
		local box = container:FindFirstChild("Input") :: TextBox
		assertEquals(box.Text, "hello", "TextBox starts with the ref value")
		box.Text = "typed"
		assertEquals(text.value, "typed", "Typing writes the ref")
		text.value = ""
		task.wait()
		assertEquals(box.Text, "", "Writing the ref updates the TextBox")
		app:unmount()
	end

	-- Test 3: model on a component with defineModel
	print("Test 3: model prop on a component")
	do
		local volume = Rivue.ref(5)
		local useModel = Rivue.defineModel()
		local Slider = Rivue.defineComponent(function(props, ctx)
			local value = useModel(props, ctx)
			return function()
				return h("TextButton", {
					Name = "Up",
					Text = tostring(value.value),
					onClick = function()
						value.value += 1
					end,
				})
			end
		end, { name = "Slider" })
		local container = Instance.new("Frame")
		local Settings = Rivue.defineComponent(function()
			return function()
				return h("Frame", { Name = "Root" }, { h(Slider, { model = volume }) })
			end
		end)
		local app = Rivue.createApp(Settings)
		app:mount(container)
		local root = container:FindFirstChild("Root") :: Frame
		local button = root:FindFirstChild("Up") :: TextButton
		assertEquals(button.Text, "5", "Component receives modelValue")
		button.Activated:Fire()
		task.wait()
		assertEquals(volume.value, 6, "update:modelValue writes the ref")
		assertEquals(button.Text, "6", "Component re-renders with the new value")
		app:unmount()
	end

	-- Test 4: Nested children lists
	print("Test 4: Nested children")
	do
		local items = { "a", "b" }
		local vnode = h("Frame", nil, {
			h("UIListLayout"),
			Rivue.hFor(items, function(item)
				return h("TextLabel", { key = item, Name = item })
			end),
			Rivue.hIf(false, h("Frame")),
			h("Frame", { Name = "Footer" }),
		})
		assertEquals(#vnode.children, 4, "Nested lists are spliced in, nils dropped")
		assertEquals(vnode.children[2].key, "a", "Order is kept")
		local container = Instance.new("Frame")
		renderer.patch(nil, vnode, container)
		local frame = container:FindFirstChildOfClass("Frame") :: Frame
		assertTrue(frame:FindFirstChild("b") ~= nil and frame:FindFirstChild("Footer") ~= nil, "All children mount")
	end

	-- Test 5: style prop
	print("Test 5: style prop")
	do
		local base = { BackgroundTransparency = 0.5, Size = UDim2.fromOffset(10, 10) }
		local active = { BackgroundTransparency = 0 }
		local vnode = h("Frame", { style = { base, false, active }, Size = UDim2.fromOffset(20, 20) })
		assertEquals(vnode.props.BackgroundTransparency, 0, "Later styles win")
		assertEquals(vnode.props.Size, UDim2.fromOffset(20, 20), "The vnode's own props win over styles")
		assertTrue(vnode.props.style == nil, "style is removed from props")
		assertTrue(base.BackgroundTransparency == 0.5, "Style tables aren't modified")
		local single = h("Frame", { style = base })
		assertEquals(single.props.BackgroundTransparency, 0.5, "A single style table works")
	end

	-- Test 6: mergeProps and cloneVNode
	print("Test 6: mergeProps / cloneVNode / isVNode")
	do
		local calls: { string } = {}
		local merged = Rivue.mergeProps({
			Size = UDim2.fromOffset(1, 1),
			onClick = function()
				table.insert(calls, "a")
			end,
		}, {
			Size = UDim2.fromOffset(2, 2),
			onClick = function()
				table.insert(calls, "b")
			end,
		}, nil)
		merged.onClick()
		assertEquals(table.concat(calls, ","), "a,b", "Handlers are chained in order")
		assertEquals(merged.Size, UDim2.fromOffset(2, 2), "Other props are overwritten")

		local original = h("TextLabel", { Text = "hi", key = 1 }, { "child" })
		local copy = Rivue.cloneVNode(original, { TextSize = 20 })
		assertTrue(copy ~= original and Rivue.isVNode(copy), "cloneVNode returns a new vnode")
		assertEquals(copy.props.Text, "hi", "Clone keeps props")
		assertEquals(copy.props.TextSize, 20, "Clone merges extra props")
		assertEquals(copy.key, 1, "Clone keeps the key")
		assertTrue(not Rivue.isVNode({}), "isVNode rejects plain tables")
	end

	-- Test 7: Explorer names and printTree
	print("Test 7: Component roots are named, printTree")
	do
		local Badge = Rivue.defineComponent({
			name = "Badge",
			props = { text = { type = "string" } },
			render = function(props)
				return h("TextLabel", { Text = props.text })
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h("Frame", { Name = "Root" }, { h(Badge, { text = "NEW" }) }))
		app:mount(container)
		local root = container:FindFirstChild("Root") :: Frame
		assertTrue(root:FindFirstChild("Badge") ~= nil, "Component root is named after the component")
		local tree = app:printTree()
		assertTrue(string.find(tree, '<Badge text="NEW">', 1, true) ~= nil, "printTree shows components with props")
		assertTrue(string.find(tree, 'TextLabel "Badge"', 1, true) ~= nil, "printTree shows elements")
		app:unmount()
	end

	-- Test 8: onRenderTriggered says why a component re-rendered
	print("Test 8: onRenderTracked / onRenderTriggered")
	do
		local state = Rivue.reactive({ count = 0 })
		local tracked: { unknown } = {}
		local triggered: { unknown } = {}
		local Probe = Rivue.defineComponent({
			name = "Probe",
			setup = function()
				Rivue.onRenderTracked(function(event)
					table.insert(tracked, event.key)
				end)
				Rivue.onRenderTriggered(function(event)
					table.insert(triggered, event.key)
				end)
				return function()
					return h("TextLabel", { Text = tostring(state.count) })
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(Probe)
		app:mount(container)
		assertTrue(table.find(tracked, "count") ~= nil, "Tracked reads are reported")
		state.count += 1
		assertTrue(table.find(triggered, "count") ~= nil, "The write that triggered the render is reported")
		app:unmount()
	end

	-- Test 9: Errors are reported with the component trace
	print("Test 9: Error reporting")
	do
		local Broken = Rivue.defineComponent({
			name = "Broken",
			setup = function()
				return function(): any
					error("boom")
				end
			end,
		})
		local Parent = Rivue.defineComponent({
			name = "Parent",
			render = function()
				return h(Broken)
			end,
		})
		local container = Instance.new("Frame")
		local warnings = captureWarnings(function()
			Rivue.createApp(Parent):mount(container)
		end)
		assertTrue(anyContains(warnings, "<Broken> in <Parent>"), "Render errors name the component chain")

		local count = Rivue.ref(0)
		local stop = Rivue.watch(count, function()
			error("watch failed")
		end)
		local watchWarnings = captureWarnings(function()
			count.value = 1
			task.wait()
		end)
		stop()
		assertTrue(anyContains(watchWarnings, "watch failed"), "Watch callback errors are always reported")

		local ok, err = pcall(function()
			renderer.patch(nil, h({ setup = function() end } :: any), Instance.new("Frame"))
		end)
		assertTrue(
			not ok and string.find(tostring(err), "defineComponent", 1, true) ~= nil,
			"Unwrapped component gets a hint"
		)

		local Thrower = Rivue.defineComponent({
			name = "Thrower",
			setup = function(): any
				error("bad setup")
			end,
		})
		local okSetup, setupErr = pcall(function()
			renderer.patch(nil, h(Thrower), Instance.new("Frame"))
		end)
		assertTrue(
			not okSetup and string.find(tostring(setupErr), "setup() of <Thrower>", 1, true) ~= nil,
			"Setup errors name the component"
		)
	end

	-- Test 10: Teleport defer can target something later in the same tree
	print("Test 10: Teleport defer")
	do
		local overlay = Rivue.shallowRef(nil :: Instance?)
		local App = Rivue.defineComponent({
			name = "DeferApp",
			setup = function()
				return function()
					return h("Frame", { Name = "Root" }, {
						h(Rivue.Teleport, {
							defer = true,
							to = function()
								return overlay.value
							end,
						}, {
							h("TextLabel", { Name = "Tip" }),
						}),
						h("Frame", { Name = "Overlay", ref = overlay }),
					})
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(App)
		app:mount(container)
		local overlayEl = (container:FindFirstChild("Root") :: Frame):FindFirstChild("Overlay") :: Frame
		assertTrue(overlayEl:FindFirstChild("Tip") ~= nil, "Deferred Teleport mounts into a later sibling")
		app:unmount()
		assertEquals(#overlayEl:GetChildren(), 0, "Deferred Teleport content is removed on unmount")
	end

	-- Test 11: watch deep levels
	print("Test 11: watch deep = number")
	do
		local state = Rivue.reactive({ a = { b = { c = 1 } } })
		local calls = 0
		local stop = Rivue.watch(function()
			return state.a
		end, function()
			calls += 1
		end, { deep = 1 })
		state.a.b.c = 2
		task.wait()
		assertEquals(calls, 0, "Changes below the depth are ignored")
		state.a.b = { c = 3 }
		task.wait()
		assertEquals(calls, 1, "Changes within the depth fire")
		stop()
	end

	-- Test 12: app helpers
	print("Test 12: app:onUnmount, app:runWithContext, hasInjectionContext")
	do
		local app = Rivue.createApp(h("Frame"))
		local unmounted = false
		app:provide("service", "store"):onUnmount(function()
			unmounted = true
		end)
		assertTrue(not Rivue.hasInjectionContext(), "No injection context outside setup")
		local value = app:runWithContext(function()
			return Rivue.inject("service")
		end)
		assertEquals(value, "store", "inject() works inside runWithContext")
		app:mount(Instance.new("Frame"))
		app:unmount()
		assertTrue(unmounted, "onUnmount callbacks run")
	end

	print("\n========== DEVELOPER EXPERIENCE TESTS COMPLETE ==========\n")
end

return runTests
