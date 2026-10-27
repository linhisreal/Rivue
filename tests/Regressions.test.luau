--!strict
-- One test per bug that was found and fixed, so they stay fixed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local renderer = require(ReplicatedStorage:WaitForChild("RivueUI"):WaitForChild("runtime"):WaitForChild("renderer"))

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

local function mount(component: any): Instance
	local container = Instance.new("Frame")
	Rivue.createApp(component):mount(container)
	return container
end

local function runTests()
	print("\n========== REGRESSION TEST SUITE ==========\n")

	print("watchEffect writing state it reads doesn't loop")
	do
		local count = Rivue.ref(0)
		local runs = 0
		local stop = Rivue.watchEffect(function()
			runs += 1
			count.value = count.value + 1
		end)
		task.wait(0.1)
		stop()
		assertEquals(runs, 1, "Runs once")
	end

	print("reactive() of a proxy returns the same proxy")
	do
		local state = Rivue.reactive({ a = 1 })
		assertTrue(Rivue.reactive(state) == state, "reactive(proxy) == proxy")
		assertTrue(Rivue.ref(state).value == state, "ref(proxy).value == proxy")
		assertTrue(Rivue.shallowReactive(state) == state, "shallowReactive(proxy) == proxy")
	end

	print("Re-renders swap event handlers instead of reconnecting")
	do
		local container = Instance.new("Frame")
		local hits = 0
		local v1 = h("TextButton", { Name = "B", onClick = function() end })
		renderer.patch(nil, v1, container)
		local conn = (v1._conns :: any).onClick
		local v2 = h("TextButton", {
			Name = "B",
			onClick = function()
				hits += 1
			end,
		})
		renderer.patch(v1, v2, container)
		local button = container:FindFirstChild("B") :: TextButton
		Rivue.testing.trigger(button, "onClick")
		assertEquals(hits, 1, "The new handler runs")
		assertTrue((v2._conns :: any).onClick == conn, "Same connection")
	end

	print("Text children: numbers update, removed text is cleared")
	do
		local container = Instance.new("Frame")
		local v1 = h("TextLabel", { Name = "T" }, { 1 })
		renderer.patch(nil, v1, container)
		local v2 = h("TextLabel", { Name = "T" }, { 2 })
		renderer.patch(v1, v2, container)
		local label = container:FindFirstChild("T") :: TextLabel
		assertEquals(label.Text, "2", "Number child updates Text")
		local v3 = h("TextLabel", { Name = "T" })
		renderer.patch(v2, v3, container)
		assertEquals(label.Text, "", "Removing the text child clears Text")
	end

	print("Pooled Instances get their default Name back")
	do
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h("Frame", { Name = "Custom" }), { usePool = true })
		app:mount(container)
		app:unmount()
		Rivue.createApp(h("Frame", {}), { usePool = true }):mount(container)
		assertEquals((container:FindFirstChildOfClass("Frame") :: Frame).Name, "Frame", "Name reset")
	end

	print("Suspense mounts its children so async components can load")
	do
		local Inner = Rivue.defineComponent({
			name = "Inner",
			render = function()
				return h("TextLabel", { Name = "Loaded" })
			end,
		})
		local Async = Rivue.defineAsyncComponent(function()
			task.wait(0.1)
			return Inner
		end)
		local container = Instance.new("Frame")
		local app =
			Rivue.createApp(h(Rivue.Suspense, { fallback = h("TextLabel", { Name = "Fallback" }) }, { h(Async) }))
		app:mount(container)
		local function has(name: string): boolean
			for _, d in container:GetDescendants() do
				if d.Name == name then
					return true
				end
			end
			return false
		end
		task.wait()
		assertTrue(has("Fallback"), "Fallback while loading")
		task.wait(0.3)
		assertTrue(has("Loaded"), "Content after loading")
		assertTrue(not has("Fallback"), "Fallback removed")
		app:unmount()
	end

	print("Directives: latest click-outside handler, no stolen focus or selection, drag can turn off")
	if not __OFFLINE then
		print("  skipped in Studio: needs fired input signals")
	else
		local n = Rivue.ref(1)
		local got: number? = nil
		mount(Rivue.defineComponent(function()
			return function()
				local current = n.value
				return h("Frame", {
					vClickOutside = function()
						got = current
					end,
				})
			end
		end, { name = "ClickOutside" }))
		n.value = 2
		task.wait();
		(UserInputService.InputBegan :: any):Fire(
			{ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector2.new(500, 500) },
			false
		)
		assertEquals(got, 2, "click-outside calls the latest handler")

		local tick = Rivue.ref(0)
		__focusCalls = 0
		mount(Rivue.defineComponent(function()
			return function()
				return h("TextBox", { Text = tostring(tick.value), vFocus = true })
			end
		end, { name = "Focus" }))
		local other = Instance.new("TextButton")
		mount(Rivue.defineComponent(function()
			return function()
				return h("TextButton", { Text = tostring(tick.value), vSelect = true })
			end
		end, { name = "Select" }))
		GuiService.SelectedObject = other
		tick.value = 1
		task.wait()
		assertEquals(__focusCalls, 1, "vFocus focuses once, not on every re-render")
		assertTrue(GuiService.SelectedObject == other, "vSelect doesn't take selection back on re-render")
		GuiService.SelectedObject = nil

		local dragOn = Rivue.ref(true)
		local container = mount(Rivue.defineComponent(function()
			return function()
				return h("Frame", { Name = "Draggable", vDrag = dragOn.value })
			end
		end, { name = "Drag" }))
		dragOn.value = false
		task.wait()
		local el = container:FindFirstChild("Draggable") :: any
		el.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(0, 0, 0) })
		local move = { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(50, 50, 0) }
		el.InputChanged:Fire(move);
		(UserInputService.InputChanged :: any):Fire(move)
		assertEquals(el.Position, UDim2.new(), "vDrag = false stops dragging")
	end

	print("attributeRef and useTag clean up with their effect scope")
	do
		local inst = Instance.new("Frame")
		local scope = Rivue.effectScope()
		local r: any
		local added = 0
		scope:run(function()
			r = Rivue.attributeRef(inst, "Coins", 0)
			Rivue.useTag("RegressionTag", function()
				added += 1
				return nil
			end)
			return nil
		end)
		scope:stop()
		inst:SetAttribute("Coins", 3)
		game:GetService("CollectionService"):AddTag(Instance.new("Part"), "RegressionTag")
		assertEquals(r.value, 0, "attributeRef stopped syncing")
		assertEquals(added, 0, "useTag stopped listening")
	end

	print("Two keyed lists in one parent don't take each other's rows")
	do
		local a = Rivue.ref({ 1 })
		local b = { 1, 2 }
		local container = mount(Rivue.defineComponent(function()
			return function()
				return h("Frame", { Name = "Root" }, {
					Rivue.hFor(a.value, function(k)
						return h("TextLabel", { key = k, Name = `A{k}` })
					end),
					Rivue.hFor(b, function(k)
						return h("TextLabel", { key = k, Name = `B{k}` })
					end),
				})
			end
		end, { name = "TwoLists" }))
		a.value = { 1, 2 }
		task.wait()
		local names = {}
		for _, child in (container:FindFirstChild("Root") :: Frame):GetChildren() do
			table.insert(names, child.Name)
		end
		table.sort(names)
		assertEquals(table.concat(names, ","), "A1,A2,B1,B2", "Both lists intact")
	end

	print("isReactive() of a readonly plain table is false")
	do
		assertEquals(Rivue.isReactive(Rivue.readonly({})), false, "readonly(plain) isn't reactive")
		assertEquals(Rivue.isReactive(Rivue.readonly(Rivue.reactive({}))), true, "readonly(reactive) is")
	end

	print("Verbose debug logging is off by default")
	do
		assertEquals(Rivue.debug.enabled, false, "debug.enabled defaults to false")
	end

	print("array.indexOf updates when an item is replaced in place")
	do
		local party = Rivue.reactive({ "Ada", "Grace" })
		local index = Rivue.computed(function()
			return Rivue.array.indexOf(party, "Bob")
		end)
		assertEquals(index.value, nil, "not there yet")
		party[2] = "Bob"
		assertEquals(index.value, 2, "found after replacing")
	end

	print("array.removeWhere leaves the list intact when the predicate errors")
	do
		local list = Rivue.reactive({ 1, 2, 3, 4 })
		local ok = pcall(Rivue.array.removeWhere, list, function(n)
			if n == 3 then
				error("boom")
			end
			return n == 1
		end)
		assertTrue(not ok, "the error propagates")
		assertEquals(table.concat(Rivue.toRaw(list), ","), "1,2,3,4", "nothing was removed or overwritten")
	end

	print("array.splice past the end appends instead of dropping values")
	do
		local list = Rivue.reactive({ 1, 2 })
		Rivue.array.splice(list, 5, 0, 9)
		assertEquals(table.concat(Rivue.toRaw(list), ","), "1,2,9", "appended")
	end

	print("render(ctx): a setup ref holding nil isn't shadowed by a prop of the same name")
	do
		local seen: any = "unset"
		local Shadow = Rivue.defineComponent({
			name = "Shadow",
			props = { selected = { type = "string" } },
			setup = function()
				return { selected = Rivue.ref(nil) }
			end,
			render = function(ctx)
				seen = ctx.selected
				return h("Frame")
			end,
		})
		Rivue.createApp(h(Shadow, { selected = "fromProp" })):mount(Instance.new("Frame"))
		assertEquals(seen, nil, "setup state wins even while nil")
	end

	print("Deep watchers fire when items are added to a list")
	do
		local list = Rivue.reactive({ { n = 1 } })
		local fired = 0
		Rivue.watch(list, function()
			fired += 1
		end, { deep = true, flush = "sync" })
		Rivue.array.push(list, { n = 2 })
		assertEquals(fired, 1, "array.push")
		list[#list + 1] = { n = 3 }
		assertEquals(fired, 2, "plain assignment of a new index")
	end

	print("One array operation runs a sync effect once")
	do
		local list = Rivue.reactive({ 3, 1, 2 })
		local runs = 0
		Rivue.watchEffect(function()
			for i = 1, #list do
				local _ = list[i]
			end
			runs += 1
		end, { flush = "sync" })
		runs = 0
		Rivue.array.sort(list)
		assertEquals(runs, 1, "sort")
		Rivue.array.removeWhere(list, function(n)
			return n > 1
		end)
		assertEquals(runs, 2, "removeWhere")
	end

	print("LayoutOrder follows the list through random inserts, removes, moves and sorts")
	do
		local items = Rivue.reactive({})
		local nextId = 0
		local function newItem()
			nextId += 1
			return { id = nextId }
		end
		for _ = 1, 20 do
			Rivue.array.push(items, newItem())
		end
		local List = Rivue.defineComponent({
			name = "OrderList",
			render = function()
				return h("Frame", { layout = "vertical" }, {
					Rivue.hFor(items, function(item)
						return h("Frame", { key = item.id, Name = `i{item.id}` })
					end),
				})
			end,
		})
		local container = Instance.new("Frame")
		Rivue.createApp(List):mount(container)
		local root = container:FindFirstChild("OrderList") :: Frame
		local seed = 7
		local function roll(a: number, b: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return a + seed % (b - a + 1)
		end
		for step = 1, 150 do
			local n = #items
			local op = roll(1, 5)
			if op == 1 or n < 3 then
				Rivue.array.insert(items, roll(1, n + 1), newItem())
			elseif op == 2 then
				Rivue.array.remove(items, roll(1, n))
			elseif op == 3 then
				Rivue.array.move(items, roll(1, n), roll(1, n))
			elseif op == 4 then
				Rivue.array.sort(items, function(a, b)
					return (a.id * 31) % 17 < (b.id * 31) % 17
				end)
			else
				Rivue.array.insert(items, 1, newItem())
			end
			Rivue.nextTick()
			local previous = -math.huge
			for i = 1, #items do
				local el = root:FindFirstChild(`i{items[i].id}`) :: Frame
				assertTrue(el.LayoutOrder > previous, `step {step}: row {i} is in order`)
				previous = el.LayoutOrder
			end
		end
	end

	print("Iterating a reactive table tracks its values")
	do
		local state = Rivue.reactive({ a = 1, b = 2 })
		local shallow = Rivue.shallowReactive({ x = 1 })
		local sum, shallowSum = 0, 0
		Rivue.watchEffect(function()
			local total = 0
			for _, v in state do
				total += v
			end
			sum = total
		end)
		Rivue.watchEffect(function()
			local total = 0
			for _, v in shallow do
				total += v
			end
			shallowSum = total
		end)
		state.b = 5
		shallow.x = 3
		Rivue.nextTick()
		assertEquals(sum, 6, "changing a value re-runs a loop over a reactive table")
		assertEquals(shallowSum, 3, "same for shallowReactive")
		local view = Rivue.readonly(state)
		local viewSum = 0
		Rivue.watchEffect(function()
			local total = 0
			for _, v in view do
				total += v
			end
			viewSum = total
		end)
		state.a = 4
		Rivue.nextTick()
		assertEquals(viewSum, 9, "same through a readonly view")
	end

	print("A component's own model prop isn't treated as v-model")
	do
		local part = Instance.new("Part")
		local node = h(Rivue.ViewportModel, { model = part })
		assertEquals(node.props.model, part, "ViewportModel gets the part")
		assertEquals(node.props.modelValue, nil, "no v-model props are added")
		part:Destroy()
	end

	print("watch() on a list holding a reactive object fires when the object changes")
	do
		local state = Rivue.reactive({ x = 1 })
		local fired = 0
		local stop = Rivue.watch({ state }, function()
			fired += 1
		end)
		state.x = 2
		Rivue.nextTick()
		assertEquals(fired, 1, "the watcher ran")
		stop()
	end

	print("A sync watcher that errors doesn't stop the write or other watchers")
	do
		local value = Rivue.ref(0)
		local seen = 0
		local first = Rivue.watch(value, function()
			error("boom")
		end, { flush = "sync" })
		local second = Rivue.watch(value, function()
			seen += 1
		end, { flush = "sync" })
		local ok = pcall(function()
			value.value = 1
		end)
		assertTrue(ok, "the write doesn't throw")
		assertEquals(seen, 1, "the other watcher still ran")
		first()
		second()
	end

	print("Post watchers run once per frame, not once per change")
	do
		local state = Rivue.reactive({ a = 1, b = 1 })
		local calls, runs = 0, 0
		local watcher = Rivue.watch(state, function()
			calls += 1
		end, { flush = "post" })
		local effect = Rivue.watchEffect(function()
			local _ = state.a + state.b
			runs += 1
		end, { flush = "post" })
		runs = 0
		state.a = 2
		state.b = 2
		task.wait(0.1)
		assertEquals(calls, 1, "deep post watcher ran once")
		assertEquals(runs, 1, "post watchEffect ran once")
		watcher()
		effect()
	end

	print("A render error is reported and doesn't mount the fallback prop")
	do
		local broken = Rivue.ref(false)
		local Widget = Rivue.defineComponent({
			name = "FallbackProp",
			props = { fallback = { type = "table" } },
			setup = function()
				return function()
					if broken.value then
						error("render boom")
					end
					return h("Frame", { Name = "Body" })
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(Widget, { fallback = h("TextLabel", { Name = "Oops" }) }))
		local handled = 0
		app.config.errorHandler = function()
			handled += 1
		end
		app:mount(container)
		broken.value = true
		Rivue.nextTick()
		assertEquals(handled, 1, "the error reached errorHandler")
		assertTrue(container:FindFirstChild("Oops", true) == nil, "the fallback prop isn't mounted")
		assertTrue(container:FindFirstChild("Body", true) ~= nil, "the last good tree stays")
		app:unmount()
	end

	print("Watchers from a setup() that fails are stopped")
	do
		local source = Rivue.ref(0)
		local runs = 0
		local Failing = Rivue.defineComponent({
			name = "FailingSetup",
			setup = function()
				Rivue.watch(source, function()
					runs += 1
				end)
				error("setup boom")
			end,
		})
		pcall(function()
			Rivue.createApp(h(Failing)):mount(Instance.new("Frame"))
		end)
		source.value = 1
		Rivue.nextTick()
		assertEquals(runs, 0, "the watcher doesn't run")
	end

	print("Changing layout resets alignment the new value doesn't set")
	do
		local wide = Rivue.ref(true)
		local Row = Rivue.defineComponent({
			name = "LayoutSwitch",
			setup = function()
				return function()
					return h("Frame", {
						Name = "Row",
						layout = if wide.value
							then { direction = "horizontal", justify = "space-between", align = "center" }
							else "vertical",
					})
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(Row))
		app:mount(container)
		local list = (container:FindFirstChild("Row") :: Frame):FindFirstChildOfClass("UIListLayout") :: UIListLayout
		wide.value = false
		Rivue.nextTick()
		assertEquals(list.HorizontalFlex, Enum.UIFlexAlignment.None, "flex reset")
		assertEquals(list.VerticalAlignment, Enum.VerticalAlignment.Top, "alignment reset")
		app:unmount()
	end

	print("vFadeIn stops when the element unmounts")
	do
		local container = Instance.new("Frame")
		local app = Rivue.createApp(
			h("Frame", { Name = "Fading", BackgroundTransparency = 0.5, vFadeIn = { renderWait = 0.05 } })
		)
		app:mount(container)
		local el = container:FindFirstChild("Fading") :: Frame
		app:unmount()
		el.BackgroundTransparency = 0.5
		task.wait(0.15)
		assertEquals(el.BackgroundTransparency, 0.5, "the element isn't hidden after unmount")
	end

	print("Pool settings and pooled elements")
	do
		local Pool = require(ReplicatedStorage:WaitForChild("RivueUI"):WaitForChild("runtime"):WaitForChild("pool"))
		Pool.configure({ defaultTTL = 30 })
		assertEquals(Pool.config.defaultTTL, 30, "configure sets defaultTTL")
		Pool.configure({ defaultTTL = nil })
		for _, className in { "Frame", "TextLabel" } do
			local fresh = Instance.new(className) :: any
			local pooled = Pool.acquire(className) :: any
			pooled.Size = UDim2.fromOffset(1, 1)
			Pool.release(pooled)
			local reused = Pool.acquire(className) :: any
			assertEquals(reused.Size, fresh.Size, `a pooled {className} gets the default Size`)
			if className == "TextLabel" then
				assertEquals(reused.Text, fresh.Text, "and the default Text")
			end
			Pool.release(reused)
		end
	end

	print("inject() reads from above, not from the component's own provide()")
	do
		local depths: { number } = {}
		local Nested
		Nested = Rivue.defineComponent({
			name = "Nested",
			props = { levels = { type = "number" } },
			setup = function(props)
				-- Provided before injecting, which is the order that used to read its own value
				Rivue.provide("depth", (Rivue.inject("depth", 0) :: number) + 1)
				table.insert(depths, Rivue.inject("depth", 0) :: number)
				return function()
					local levels = props.levels :: number
					return if levels > 1 then h(Nested, { levels = levels - 1 }) else h("Frame")
				end
			end,
		})
		local app = Rivue.createApp(h(Nested, { levels = 3 }))
		app:mount(Instance.new("Frame"))
		assertEquals(table.concat(depths, ","), "0,1,2", "each level sees its parent's depth")
		app:unmount()
	end

	print("KeepAlive drops cached components that no longer match include/exclude")
	do
		local unmounted = 0
		local Kept = Rivue.defineComponent({
			name = "Kept",
			setup = function()
				Rivue.onUnmounted(function()
					unmounted += 1
				end)
				return function()
					return h("Frame", { Name = "Kept" })
				end
			end,
		})
		local Other = Rivue.defineComponent({
			name = "OtherTab",
			render = function()
				return h("Frame", { Name = "OtherTab" })
			end,
		})
		local tab = Rivue.ref("kept")
		local exclude = Rivue.ref({} :: { string })
		local App = Rivue.defineComponent({
			name = "KeepAliveExclude",
			setup = function()
				return function()
					return h(
						Rivue.KeepAlive,
						{ exclude = exclude.value },
						{ if tab.value == "kept" then h(Kept) else h(Other) }
					)
				end
			end,
		})
		local container = Instance.new("Frame")
		local app = Rivue.createApp(h(App))
		app:mount(container)
		tab.value = "other"
		task.wait()
		assertEquals(unmounted, 0, "switched away, still cached")
		exclude.value = { "Kept" }
		task.wait()
		assertEquals(unmounted, 1, "excluding it unmounts the cached copy")

		-- Excluded while on screen: switching away unmounts it instead of caching it
		exclude.value = {}
		tab.value = "kept"
		task.wait()
		exclude.value = { "Kept" }
		task.wait()
		tab.value = "other"
		task.wait()
		assertEquals(unmounted, 2, "the shown one is unmounted when switched away")
		app:unmount()
		assertEquals(unmounted, 2, "nothing left over")
	end

	print("A Row keeps its children when a sibling with prop defaults mounts in an update")
	do
		-- The sibling's defaults made the Column patch the Row's vnode against itself, and slot
		-- replacement cleared the table it was copying from
		local Sibling = Rivue.defineComponent({
			name = "Sibling",
			props = { label = { type = "string", default = "x" } },
			render = function()
				return h("TextLabel", { Name = "Sibling" })
			end,
		})
		local Screen = Rivue.defineComponent({
			name = "Screen",
			render = function()
				return h(Rivue.Column, nil, {
					h(Rivue.Row, nil, { h("TextButton", { Name = "InRow" }) }),
					h(Sibling),
				})
			end,
		})
		local show = Rivue.ref(false)
		local root = Instance.new("Folder")
		local app = Rivue.createApp(Rivue.defineComponent({
			name = "Host",
			render = function()
				return h("Frame", nil, { if show.value then h(Screen) else nil })
			end,
		}))
		app:mount(root)
		show.value = true
		Rivue.nextTick()
		local found = false
		for _, d in root:GetDescendants() do
			if d.Name == "InRow" then
				found = true
			end
		end
		assertTrue(found, "the Row's button is still there")
		app:unmount()
	end

	print("\n========== REGRESSION TESTS COMPLETE ==========\n")
end

return runTests
