--!strict
-- Tests for Transition/TransitionGroup, KeepAlive, Teleport, memo, template refs, emits, app
-- components, watch handles, modifier props, VirtualList and the Roblox composables

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
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

local function runTests()
	print("\n========== UI FEATURES TEST SUITE ==========\n")

	-- Test 1: Leave transitions don't block the patch
	print("Test 1: Leave transition runs in the background")
	do
		local container = Instance.new("Frame")
		local vnode = h("Frame", {
			Name = "Leaving",
			transition = { tweenInfo = TweenInfo.new(0.2), leaveGoals = { BackgroundTransparency = 1 }, leave = true },
		})
		renderer.patch(nil, vnode, container)
		local el = container:FindFirstChild("Leaving") :: Frame
		local started = os.clock()
		renderer.patch(vnode, nil, container)
		assertTrue(os.clock() - started < 0.1, "Unmount returns without waiting for the tween")
		assertTrue(el.Parent == container, "Element stays while it leaves")
		task.wait(0.3)
		assertTrue(el.Parent == nil, "Element is destroyed once the tween completes")
		assertEquals(el.BackgroundTransparency, 1, "Leave goals were tweened to")
	end

	-- Test 2: <Transition> with appear, from and toggling
	print("Test 2: Transition component")
	do
		local show = Rivue.ref(true)
		local events: { string } = {}
		local App = Rivue.defineComponent({
			name = "TransitionApp",
			setup = function()
				return function()
					return h(Rivue.Transition, {
						tweenInfo = TweenInfo.new(0.1),
						from = { BackgroundTransparency = 1 },
						onAfterEnter = function()
							table.insert(events, "after-enter")
						end,
						onAfterLeave = function()
							table.insert(events, "after-leave")
						end,
					}, {
						Rivue.hIf(show.value, h("Frame", { Name = "Panel", BackgroundTransparency = 0.2 })),
					})
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(App))
		app:mount(container)
		local panel = container:FindFirstChild("Panel") :: Frame
		assertTrue(
			math.abs(panel.BackgroundTransparency - 0.2) < 1e-3,
			"No enter animation on first render without appear"
		)

		show.value = false
		task.wait()
		assertTrue(panel.Parent == container, "Panel is still leaving")
		task.wait(0.2)
		assertTrue(panel.Parent == nil, "Panel destroyed after leave")
		assertEquals(events[#events], "after-leave", "onAfterLeave ran")

		show.value = true
		task.wait()
		local again = container:FindFirstChild("Panel") :: Frame
		assertEquals(again.BackgroundTransparency, 1, "Enter starts from the `from` state")
		task.wait(0.2)
		assertTrue(math.abs(again.BackgroundTransparency - 0.2) < 1e-3, "Enter tweens back to the prop value")
		assertEquals(events[#events], "after-enter", "onAfterEnter ran")
		app:unmount()
	end

	-- Test 3: out-in waits for the old child to leave
	print("Test 3: Transition mode out-in")
	do
		local tab = Rivue.ref("A")
		local App = Rivue.defineComponent({
			name = "OutInApp",
			setup = function()
				return function()
					return h(Rivue.Transition, {
						mode = "out-in",
						tweenInfo = TweenInfo.new(0.1),
						from = { BackgroundTransparency = 1 },
					}, {
						h("Frame", { key = tab.value, Name = tab.value }),
					})
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(App))
		app:mount(container)
		tab.value = "B"
		task.wait()
		assertTrue(container:FindFirstChild("A") ~= nil, "Old child is leaving")
		assertTrue(container:FindFirstChild("B") == nil, "New child waits")
		task.wait(0.3)
		assertTrue(container:FindFirstChild("A") == nil, "Old child gone")
		assertTrue(container:FindFirstChild("B") ~= nil, "New child shown after the leave")
		app:unmount()
	end

	-- Test 4: TransitionGroup animates removed list items
	print("Test 4: TransitionGroup")
	do
		local items = Rivue.ref({ "a", "b", "c" })
		local App = Rivue.defineComponent({
			name = "GroupApp",
			setup = function()
				return function()
					return h(
						Rivue.TransitionGroup,
						{ tweenInfo = TweenInfo.new(0.1), from = { BackgroundTransparency = 1 } },
						Rivue.hFor(items.value, function(item)
							return h("Frame", { key = item, Name = item })
						end)
					)
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(App))
		app:mount(container)
		assertEquals(#container:GetChildren(), 3, "Items render without a wrapper")
		items.value = { "a", "c" }
		task.wait()
		assertTrue(container:FindFirstChild("b") ~= nil, "Removed item is leaving")
		task.wait(0.2)
		assertTrue(container:FindFirstChild("b") == nil, "Removed item destroyed after leave")
		assertEquals(#container:GetChildren(), 2, "Remaining items kept")
		app:unmount()
	end

	-- Test 5: KeepAlive keeps state and runs activated/deactivated
	print("Test 5: KeepAlive with onActivated/onDeactivated")
	do
		local activated, deactivated, unmounted = 0, 0, 0
		local counter: any = nil
		local Counter = Rivue.defineComponent({
			name = "Counter",
			setup = function()
				local count = Rivue.ref(0)
				counter = count
				Rivue.onActivated(function()
					activated += 1
				end)
				Rivue.onDeactivated(function()
					deactivated += 1
				end)
				Rivue.onUnmounted(function()
					unmounted += 1
				end)
				return function()
					return h("TextLabel", { Name = "Counter", Text = tostring(count.value) })
				end
			end,
		})
		local Other = Rivue.defineComponent({
			name = "Other",
			render = function()
				return h("Frame", { Name = "Other" })
			end,
		})
		local tab = Rivue.ref("counter")
		local App = Rivue.defineComponent({
			name = "KeepAliveApp",
			setup = function()
				return function()
					return h(Rivue.KeepAlive, nil, { if tab.value == "counter" then h(Counter) else h(Other) })
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(App))
		app:mount(container)
		assertEquals(activated, 1, "onActivated runs on first mount")
		local label = container:FindFirstChild("Counter") :: TextLabel
		counter.value = 5
		task.wait()
		assertEquals(label.Text, "5", "Counter renders")

		tab.value = "other"
		task.wait()
		assertEquals(deactivated, 1, "onDeactivated runs when switched away")
		assertEquals(unmounted, 0, "Cached component isn't unmounted")
		assertTrue(label.Parent == nil, "Cached element is detached")
		assertTrue(container:FindFirstChild("Other") ~= nil, "Other tab mounted")

		counter.value = 7
		task.wait()
		tab.value = "counter"
		task.wait()
		assertEquals(activated, 2, "onActivated runs when it comes back")
		assertTrue(label.Parent == container, "Same element is re-attached")
		assertEquals(label.Text, "7", "Update made while cached is rendered on return")
		assertTrue(container:FindFirstChild("Other") == nil, "Other tab removed")

		app:unmount()
		assertEquals(unmounted, 1, "Unmounting KeepAlive unmounts the cached component")
	end

	-- Test 6: Teleport updates, unmounts and disabled
	print("Test 6: Teleport patch and unmount")
	do
		local target = Instance.new("Frame")
		target.Parent = Instance.new("Folder")
		local label = Rivue.ref("one")
		local disabled = Rivue.ref(false)
		local App = Rivue.defineComponent({
			name = "TeleportApp",
			setup = function()
				return function()
					return h("Frame", { Name = "Root" }, {
						h(Rivue.Teleport, { to = target, disabled = disabled.value }, {
							h("TextLabel", { Name = "Toast", Text = label.value }),
						}),
					})
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(App))
		app:mount(container)
		local toast = target:FindFirstChild("Toast") :: TextLabel
		assertTrue(toast ~= nil, "Teleported into target")
		label.value = "two"
		task.wait()
		assertEquals(toast.Text, "two", "Teleported children update in place")
		disabled.value = true
		task.wait()
		assertTrue(target:FindFirstChild("Toast") == nil, "Disabled moves content out of the target")
		local root = container:FindFirstChild("Root") :: Frame
		assertTrue(root:FindFirstChild("Toast") ~= nil, "Disabled renders in place")
		disabled.value = false
		task.wait()
		app:unmount()
		assertEquals(#target:GetChildren(), 0, "Unmount removes teleported children")
	end

	-- Test 7: memo skips patching while deps match
	print("Test 7: memo prop")
	do
		local container = Instance.new("Frame")
		local v1 = h("TextLabel", { Name = "Memo", Text = "a", memo = { 1 } })
		renderer.patch(nil, v1, container)
		local v2 = h("TextLabel", { Name = "Memo", Text = "b", memo = { 1 } })
		renderer.patch(v1, v2, container)
		local el = container:FindFirstChild("Memo") :: TextLabel
		assertEquals(el.Text, "a", "Same deps skip the patch")
		local v3 = h("TextLabel", { Name = "Memo", Text = "c", memo = { 2 } })
		renderer.patch(v2, v3, container)
		assertEquals(el.Text, "c", "Changed deps patch")
	end

	-- Test 8: String and function template refs
	print("Test 8: useTemplateRef and function refs")
	do
		local mountedEl: Instance? = nil
		local fnEl: unknown = "unset"
		local App = Rivue.defineComponent({
			name = "RefApp",
			setup = function()
				local button = Rivue.useTemplateRef("button")
				Rivue.onMounted(function()
					mountedEl = button.value :: Instance?
				end)
				return function()
					return h("Frame", nil, {
						h("TextButton", { Name = "Btn", ref = "button" }),
						h("Frame", {
							Name = "Fn",
							ref = function(el: unknown)
								fnEl = el
							end,
						}),
					})
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(App))
		app:mount(container)
		assertTrue(mountedEl ~= nil and (mountedEl :: Instance).Name == "Btn", "String ref is set before onMounted")
		assertTrue(typeof(fnEl) == "Instance", "Function ref gets the Instance")
		app:unmount()
		assertTrue(fnEl == nil, "Function ref is called with nil on unmount")
	end

	-- Test 9: Declared emits
	print("Test 9: emits")
	do
		local selected: number? = nil
		local sawAttr = false
		local Picker = Rivue.defineComponent({
			name = "Picker",
			emits = { "select" },
			setup = function(_props, ctx)
				sawAttr = ctx.attrs.onSelect ~= nil
				return function()
					return h("TextButton", {
						Name = "Pick",
						onClick = function()
							ctx.emit("select", 3)
						end,
					})
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(Picker, {
			onSelect = function(id: number)
				selected = id
			end,
		}))
		app:mount(container)
		assertTrue(not sawAttr, "Declared listener isn't an attr")
		local button = container:FindFirstChild("Pick") :: TextButton
		Rivue.testing.trigger(button, "onClick")
		assertEquals(selected, 3, "emit calls the declared listener")
		app:unmount()
	end

	-- Test 10: app:component() and useId()
	print("Test 10: app:component() registration and useId()")
	do
		local ids: { string } = {}
		local Badge = Rivue.defineComponent({
			name = "Badge",
			setup = function()
				table.insert(ids, Rivue.useId())
				table.insert(ids, Rivue.useId())
				return function()
					return h("TextLabel", { Name = "Badge" })
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h("Frame", { Name = "Root" }, { h("Badge") }))
		app:component("Badge", Badge)
		app:mount(container)
		local root = container:FindFirstChild("Root") :: Frame
		assertTrue(root:FindFirstChild("Badge") ~= nil, "Registered component resolves from a string type")
		assertTrue(ids[1] ~= ids[2], "useId() is unique per call")
		app:unmount()
	end

	-- Test 11: watch pause/resume and onWatcherCleanup
	print("Test 11: watch handles")
	do
		local count = Rivue.ref(0)
		local calls = 0
		local cleaned = 0
		local handle = Rivue.watch(count, function()
			calls += 1
			Rivue.onWatcherCleanup(function()
				cleaned += 1
			end)
		end)
		count.value = 1
		task.wait()
		assertEquals(calls, 1, "Watcher runs")
		handle.pause()
		count.value = 2
		count.value = 3
		task.wait()
		assertEquals(calls, 1, "Paused watcher doesn't run")
		handle.resume()
		task.wait()
		assertEquals(calls, 2, "Resume runs once for changes made while paused")
		assertEquals(cleaned, 1, "onWatcherCleanup ran before the next callback")
		handle()
		assertEquals(cleaned, 2, "Calling the handle stops it and runs cleanup")
		count.value = 4
		task.wait()
		assertEquals(calls, 2, "Stopped watcher doesn't run")

		local runs, effectCleanups = 0, 0
		local stop = Rivue.watchEffect(function(onCleanup)
			runs += count.value * 0 + 1
			onCleanup(function()
				effectCleanups += 1
			end)
		end)
		count.value = 5
		task.wait()
		assertEquals(runs, 2, "watchEffect reruns")
		assertEquals(effectCleanups, 1, "watchEffect onCleanup runs before rerun")
		stop()
		assertEquals(effectCleanups, 2, "watchEffect onCleanup runs on stop")
	end

	-- Test 12: Modifier props create UI children
	print("Test 12: cornerRadius / padding / stroke / aspectRatio")
	do
		local container = Instance.new("Frame")
		local v1 =
			h("Frame", { Name = "Card", cornerRadius = 8, padding = { x = 4, y = 2 }, stroke = 2, aspectRatio = 2 })
		renderer.patch(nil, v1, container)
		local card = container:FindFirstChild("Card") :: Frame
		local corner = card:FindFirstChildOfClass("UICorner") :: UICorner
		assertTrue(corner ~= nil, "UICorner created")
		assertEquals(corner.CornerRadius, UDim.new(0, 8), "Number becomes a pixel UDim")
		local padding = card:FindFirstChildOfClass("UIPadding") :: UIPadding
		assertEquals(padding.PaddingLeft, UDim.new(0, 4), "Padding x goes left/right")
		assertEquals(padding.PaddingTop, UDim.new(0, 2), "Padding y goes top/bottom")
		assertEquals((card:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness, 2, "Number stroke sets Thickness")
		assertTrue(card:FindFirstChildOfClass("UIAspectRatioConstraint") ~= nil, "Aspect ratio constraint created")

		local v2 = h("Frame", { Name = "Card", cornerRadius = 12 })
		renderer.patch(v1, v2, container)
		assertTrue(card:FindFirstChildOfClass("UICorner") == corner, "Same UICorner is updated")
		assertEquals(corner.CornerRadius, UDim.new(0, 12), "Corner radius updated")
		assertTrue(card:FindFirstChildOfClass("UIPadding") == nil, "Removed prop destroys its child")
	end

	-- Test 13: onMounted and directives run with the tree parented
	print("Test 13: Mounted hooks see a parented tree")
	do
		local container = Instance.new("Frame")
		local parentedInHook = false
		local directiveParented = false
		Rivue.directives.register("checkParent", {
			mounted = function(el: Instance)
				directiveParented = el:IsDescendantOf(container)
				return nil
			end,
		})
		local Child = Rivue.defineComponent({
			name = "MountChild",
			setup = function()
				local self = Rivue.getCurrentInstance()
				Rivue.onMounted(function()
					local el = if self then self.el else nil
					parentedInHook = el ~= nil and el:IsDescendantOf(container)
				end)
				return function()
					return h("Frame", { Name = "Inner", __directives = { { name = "checkParent", value = true } } })
				end
			end,
		})
		renderer.patch(nil, h("Frame", { Name = "Outer" }, { h(Child) }), container)
		assertTrue(parentedInHook, "Child onMounted runs after the whole tree is parented")
		assertTrue(directiveParented, "Directive mounted runs after the tree is parented")
	end

	-- Test 14: VirtualList renders only the rows in view
	print("Test 14: VirtualList")
	do
		local items = {}
		for i = 1, 1000 do
			items[i] = i
		end
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(Rivue.VirtualList, {
			Name = "List",
			items = items,
			itemSize = 20,
			overscan = 1,
			render = function(item: number)
				return h("TextLabel", { Name = `Row{item}`, Text = tostring(item) })
			end,
		}))
		app:mount(container)
		local list = container:FindFirstChild("List") :: ScrollingFrame
		task.wait()
		local rows = #list:GetChildren()
		assertTrue(rows > 0 and rows <= 8, `Only visible rows render (got {rows})`)
		assertEquals(list.CanvasSize, UDim2.fromOffset(0, 20000), "Canvas covers every row")
		list.CanvasPosition = Vector2.new(0, 10000)
		task.wait()
		assertTrue(list:FindFirstChild("Row501") ~= nil, "Scrolling renders the rows in view")
		assertTrue(list:FindFirstChild("Row1") == nil, "Rows scrolled away are removed")
		local row = list:FindFirstChild("Row501") :: TextLabel
		assertEquals(row.Position, UDim2.fromOffset(0, 10000), "Rows are positioned by index")
		app:unmount()
	end

	print("VirtualList grid with gaps")
	do
		local items = {}
		for i = 1, 100 do
			items[i] = i
		end
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(Rivue.VirtualList, {
			Name = "Grid",
			items = items,
			itemSize = 50,
			columns = 4,
			gap = 10,
			overscan = 0,
			render = function(item: number)
				return h("TextLabel", { Name = `Cell{item}` })
			end,
		}))
		app:mount(container)
		local grid = container:FindFirstChild("Grid") :: ScrollingFrame
		task.wait()
		assertEquals(grid.CanvasSize, UDim2.fromOffset(0, 25 * 60 - 10), "canvas fits 25 rows of 50 with 10 px gaps")
		-- Unrendered GUI has no size in a Roblox server, so nothing is in view
		if grid.AbsoluteSize.Y == 0 then
			print("  skipped: needs a rendered viewport")
		else
			local cell = grid:FindFirstChild("Cell6") :: TextLabel
			assertTrue(cell ~= nil, "second row renders")
			assertEquals(
				cell.Position,
				UDim2.new(UDim.new(0.25, 2.5), UDim.new(0, 60)),
				"cells are placed by column and row"
			)
			assertEquals(
				cell.Size,
				UDim2.new(UDim.new(0.25, -7.5), UDim.new(0, 50)),
				"cells share the width minus the gaps"
			)
			assertTrue(grid:FindFirstChild("Cell41") == nil, "rows below the view aren't rendered")
			grid.CanvasPosition = Vector2.new(0, 600)
			task.wait()
			assertTrue(grid:FindFirstChild("Cell41") ~= nil, "scrolling renders the rows in view")
			assertTrue(grid:FindFirstChild("Cell1") == nil, "rows scrolled away are removed")
		end
		app:unmount()
	end

	print("VirtualList with different row heights")
	do
		local items = {}
		for i = 1, 100 do
			items[i] = i
		end
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(Rivue.VirtualList, {
			Name = "Feed",
			items = items,
			itemSize = function(item: number)
				return if item % 2 == 0 then 100 else 20
			end,
			overscan = 0,
			render = function(item: number)
				return h("TextLabel", { Name = `Post{item}` })
			end,
		}))
		app:mount(container)
		local feed = container:FindFirstChild("Feed") :: ScrollingFrame
		task.wait()
		assertEquals(feed.CanvasSize, UDim2.fromOffset(0, 50 * 100 + 50 * 20), "canvas is the sum of the row heights")
		-- Unrendered GUI has no size in a Roblox server, so nothing is in view
		if feed.AbsoluteSize.Y == 0 then
			print("  skipped: needs a rendered viewport")
		else
			assertEquals(
				(feed:FindFirstChild("Post2") :: TextLabel).Position,
				UDim2.fromOffset(0, 20),
				"rows start after the ones before"
			)
			assertTrue(feed:FindFirstChild("Post3") == nil, "a row starting below the view isn't rendered")
			feed.CanvasPosition = Vector2.new(0, 3000)
			task.wait()
			-- 3000 is 25 pairs of 120, so row 51 starts exactly there
			assertTrue(feed:FindFirstChild("Post51") ~= nil, "scrolling finds the row at that position")
			assertTrue(feed:FindFirstChild("Post1") == nil, "rows scrolled away are removed")
		end
		app:unmount()
	end

	-- Test 15: Roblox composables
	print("Test 15: useViewportSize / useInputType / useSelection / useTween / useSpring")
	do
		-- The camera size and input type are read-only in Studio
		if __OFFLINE then
			local size = Rivue.useViewportSize()
			assertEquals(size.value.X, 1280, "Viewport size read from the camera")
			local camera = workspace.CurrentCamera :: Camera
			camera.ViewportSize = Vector2.new(800, 600)
			assertEquals(size.value.X, 800, "Viewport size follows the camera")

			local inputType = Rivue.useInputType()
			assertEquals(inputType.value, "keyboard", "Mouse counts as keyboard")
			local UserInputService = game:GetService("UserInputService");
			(UserInputService.LastInputTypeChanged :: any):Fire(Enum.UserInputType.Gamepad1)
			assertEquals(inputType.value, "gamepad", "Gamepad input switches the type")
		end

		-- A server has no PlayerGui, and SelectedObject needs one
		if game:GetService("RunService"):IsClient() then
			local selected, select = Rivue.useSelection()
			local button = Instance.new("TextButton")
			select(button)
			assertTrue(GuiService.SelectedObject == button, "select() sets GuiService.SelectedObject")
			assertTrue(selected.value == button, "Selection ref follows")
			select(nil)
		end

		local target = Rivue.ref(0)
		local scope = Rivue.effectScope()
		local tweened: any, sprung: any
		scope:run(function()
			tweened = Rivue.useTween(target, TweenInfo.new(0.1))
			sprung = Rivue.useSpring(target)
			return nil
		end)
		target.value = 10
		task.wait(0.05)
		assertTrue(tweened.value > 0 and tweened.value < 10, "useTween is in between mid-way")
		task.wait(0.1)
		assertEquals(tweened.value, 10, "useTween reaches the target")
		task.wait(1)
		assertTrue(math.abs(sprung.value - 10) < 0.01, "useSpring settles on the target")
		scope:stop()
	end

	-- Test 16: Same type with a different key remounts
	print("Test 16: key change replaces the element")
	do
		local container = Instance.new("Frame")
		local v1 = h("Frame", { key = 1, Name = "Keyed" })
		renderer.patch(nil, v1, container)
		local first = container:FindFirstChild("Keyed")
		local v2 = h("Frame", { key = 2, Name = "Keyed" })
		renderer.patch(v1, v2, container)
		assertTrue(container:FindFirstChild("Keyed") ~= first, "New key gets a new Instance")
		assertEquals(#container:GetChildren(), 1, "Old Instance removed")
	end

	-- Test 17: select directive drives gamepad selection
	print("Test 17: select directive")
	do
		if not game:GetService("RunService"):IsClient() then
			print("  skipped: SelectedObject needs a client")
		else
			local container = Instance.new("Frame")
			local v1 = h("TextButton", { Name = "Sel", __directives = { { name = "select", value = true } } })
			renderer.patch(nil, v1, container)
			local el = container:FindFirstChild("Sel")
			assertTrue(GuiService.SelectedObject == el, "Selected on mount")
			renderer.patch(v1, nil, container)
			assertTrue(GuiService.SelectedObject == nil, "Selection cleared on unmount")
		end
	end

	-- Test 18: Property change handlers get the new value
	print("Test 18: onXChanged handlers")
	do
		local container = Instance.new("Frame")
		local size: UDim2? = nil
		local seen: unknown = nil
		renderer.patch(
			nil,
			h("Frame", {
				Name = "Sized",
				onSizeChanged = function(value: UDim2)
					size = value
				end,
				onVisible = function(value: boolean)
					seen = value
				end,
			}),
			container
		)
		local el = container:FindFirstChild("Sized") :: Frame
		el.Size = UDim2.fromOffset(10, 20)
		assertEquals(size, UDim2.fromOffset(10, 20), "onSizeChanged receives the new Size")
		el.Visible = false
		assertEquals(seen, false, "onVisible receives the new Visible")
	end

	-- Test 19: TextBox keeps typed text, but takes Text from props when it changes
	print("Test 19: TextBox text on re-render")
	do
		local container = Instance.new("Frame")
		local v1 = h("TextBox", { Name = "Input", Text = "", PlaceholderText = "a" })
		renderer.patch(nil, v1, container)
		local box = container:FindFirstChild("Input") :: TextBox
		box.Text = "typed"
		local v2 = h("TextBox", { Name = "Input", Text = "", PlaceholderText = "b" })
		renderer.patch(v1, v2, container)
		assertEquals(box.Text, "typed", "Typed text survives an unrelated re-render")
		local v3 = h("TextBox", { Name = "Input", Text = "cleared", PlaceholderText = "b" })
		renderer.patch(v2, v3, container)
		assertEquals(box.Text, "cleared", "New Text from props is applied")
	end

	print("State styles: hover, pressed, selected, disabled")
	do
		local white = Color3.new(1, 1, 1)
		local grey = Color3.new(0.8, 0.8, 0.8)
		local dark = Color3.new(0.5, 0.5, 0.5)
		local enabled = Rivue.ref(true)
		local Button = Rivue.defineComponent({
			name = "StateStyles",
			styles = {
				button = {
					BackgroundColor3 = white,
					hover = { BackgroundColor3 = grey },
					pressed = { BackgroundColor3 = dark, BackgroundTransparency = 0.2 },
					disabled = { BackgroundTransparency = 0.5 },
				},
			},
			render = function()
				return Rivue.h("TextButton", { Name = "Buy", class = "button", disabled = not enabled.value })
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Button)
		app:mount(container)
		local button = container:FindFirstChild("Buy") :: TextButton
		assertTrue(button.BackgroundColor3 == white, "base style applies")
		Rivue.testing.setInteraction(button, "hover", true)
		assertTrue(button.BackgroundColor3 == grey, "hover style applies")
		Rivue.testing.setInteraction(button, "pressed", true)
		assertTrue(button.BackgroundColor3 == dark, "pressed wins over hover")
		assertTrue(math.abs(button.BackgroundTransparency - 0.2) < 1e-3, "pressed can set extra properties")
		Rivue.testing.setInteraction(button, "pressed", false)
		assertTrue(button.BackgroundColor3 == grey, "back to hover when released")
		assertEquals(button.BackgroundTransparency, 0, "extra properties are restored")
		Rivue.testing.setInteraction(button, "hover", false)
		assertTrue(button.BackgroundColor3 == white, "back to base when the mouse leaves")
		if __OFFLINE then
			(button.MouseEnter :: any):Fire()
			assertTrue(button.BackgroundColor3 == grey, "MouseEnter turns hover on");
			(button.MouseLeave :: any):Fire()
			assertTrue(button.BackgroundColor3 == white, "MouseLeave turns hover off")
		end
		enabled.value = false
		Rivue.nextTick()
		assertEquals(button.BackgroundTransparency, 0.5, "disabled style applies")
		assertEquals(button.Interactable, false, "disabled makes the element not interactable")
		Rivue.testing.setInteraction(button, "hover", true)
		assertTrue(button.BackgroundColor3 == white, "no hover style while disabled")
		enabled.value = true
		Rivue.nextTick()
		assertEquals(button.Interactable, true, "enabled again")
		assertTrue(button.BackgroundColor3 == grey, "hover style comes back once enabled")
		app:unmount()
	end

	print("Responsive styles follow the device")
	do
		local Panel = Rivue.defineComponent({
			name = "Responsive",
			styles = {
				panel = { Size = UDim2.fromOffset(600, 400), phone = { Size = UDim2.fromScale(1, 1) } },
			},
			render = function()
				return Rivue.h("Frame", { Name = "Panel", class = "panel" })
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Panel)
		app:mount(container)
		local panel = container:FindFirstChild("Panel") :: Frame
		assertEquals(Rivue.useDevice().value, "desktop", "Studio and tests run as desktop")
		assertTrue(panel.Size == UDim2.fromOffset(600, 400), "desktop uses the base style")
		if __OFFLINE then
			local UserInputService = game:GetService("UserInputService") :: any
			local camera = workspace.CurrentCamera :: Camera
			UserInputService.TouchEnabled, UserInputService.KeyboardEnabled = true, false
			camera.ViewportSize = Vector2.new(844, 390)
			assertEquals(Rivue.useDevice().value, "phone", "a touch screen with a short side under 500 is a phone")
			Rivue.nextTick()
			assertTrue(panel.Size == UDim2.fromScale(1, 1), "phone variant applies after the device changes")
			UserInputService.TouchEnabled, UserInputService.KeyboardEnabled = false, true
			camera.ViewportSize = Vector2.new(1280, 720)
			Rivue.nextTick()
			assertTrue(panel.Size == UDim2.fromOffset(600, 400), "back to desktop")
		end
		app:unmount()
	end

	print("Sugar props: gradient, scale, sizeLimit, textSizeLimit")
	do
		local top, bottom = Color3.fromRGB(255, 200, 0), Color3.fromRGB(255, 80, 0)
		local big = Rivue.ref(true)
		local Card = Rivue.defineComponent({
			name = "SugarCard",
			render = function()
				return Rivue.h("TextLabel", {
					Name = "Card",
					gradient = if big.value then { top, bottom, rotation = 90 } else { top, bottom },
					scale = if big.value then 1.5 else nil,
					sizeLimit = { max = Vector2.new(300, 200) },
					textSizeLimit = { min = 10, max = 24 },
				})
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Card)
		app:mount(container)
		local card = container:FindFirstChild("Card") :: TextLabel
		local gradient = card:FindFirstChildOfClass("UIGradient") :: UIGradient
		assertTrue(gradient ~= nil, "gradient creates a UIGradient")
		assertEquals(gradient.Rotation, 90, "gradient rotation")
		assertEquals(typeof(gradient.Color), "ColorSequence", "two colours become a ColorSequence")
		assertEquals((card:FindFirstChildOfClass("UIScale") :: UIScale).Scale, 1.5, "scale creates a UIScale")
		local size = card:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint
		assertTrue(size.MaxSize == Vector2.new(300, 200) or size.MaxSize.X == 300, "sizeLimit sets MaxSize")
		local text = card:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
		assertEquals(text.MinTextSize, 10, "textSizeLimit sets MinTextSize")
		assertEquals(text.MaxTextSize, 24, "textSizeLimit sets MaxTextSize")
		big.value = false
		Rivue.nextTick()
		assertEquals(gradient.Rotation, 0, "a removed gradient field goes back to its default")
		assertTrue(card:FindFirstChildOfClass("UIScale") == nil, "removing scale destroys the UIScale")
		app:unmount()
	end

	print("\n========== UI FEATURES TESTS COMPLETE ==========\n")
end

return runTests
