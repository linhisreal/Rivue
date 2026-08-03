--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local renderer = require(ReplicatedStorage:WaitForChild("RivueUI"):WaitForChild("runtime"):WaitForChild("renderer"))

local h = Rivue.h
local array = Rivue.array

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

local function join(list: { any }): string
	local parts = {}
	for i = 1, #list do
		table.insert(parts, tostring(list[i]))
	end
	return table.concat(parts, ",")
end

local function runTests()
	print("\n========== READABILITY TEST SUITE ==========\n")

	print("Test 1: Array helpers change reactive arrays and notify")
	do
		local list = Rivue.reactive({ 1, 2, 3 })
		local seen = ""
		local stop = Rivue.watchEffect(function()
			seen = join(list)
		end, { flush = "sync" })

		assertEquals(array.push(list, 4, 5), 5, "push returns the new length")
		assertEquals(seen, "1,2,3,4,5", "push notifies")
		array.insert(list, 1, 0)
		assertEquals(seen, "0,1,2,3,4,5", "insert")
		assertEquals(array.remove(list), 5, "remove pops the last item")
		assertEquals(array.remove(list, 1), 0, "remove at an index")
		assertEquals(seen, "1,2,3,4", "remove notifies")
		assertTrue(array.removeValue(list, 3), "removeValue finds the value")
		assertEquals(
			array.removeWhere(list, function(n)
				return n % 2 == 0
			end),
			2,
			"removeWhere returns how many it removed"
		)
		assertEquals(seen, "1", "removeWhere notifies once")
		array.push(list, 2, 3, 4)
		local removed = array.splice(list, 2, 2, 9, 9, 9)
		assertEquals(join(removed), "2,3", "splice returns removed items")
		assertEquals(seen, "1,9,9,9,4", "splice inserts")
		array.sort(list, function(a, b)
			return a > b
		end)
		assertEquals(seen, "9,9,9,4,1", "sort")
		array.move(list, 5, 1)
		assertEquals(seen, "1,9,9,9,4", "move")
		assertEquals(array.indexOf(list, 4), 5, "indexOf")
		assertEquals(
			array.count(list, function(n)
				return n == 9
			end),
			3,
			"count"
		)
		assertEquals(
			join(array.filter(list, function(n)
				return n < 5
			end)),
			"1,4",
			"filter"
		)
		assertEquals(
			join(array.map(list, function(n)
				return n * 2
			end)),
			"2,18,18,18,8",
			"map"
		)
		array.clear(list)
		assertEquals(seen, "", "clear")
		stop()

		local items = Rivue.reactive({ { id = 1, done = false }, { id = 2, done = true } })
		local found = array.find(items, function(item)
			return item.id == 2
		end)
		assertTrue(found ~= nil and Rivue.isReactive(found), "find returns the reactive item")
		local nested = { id = 3, done = false }
		array.push(items, Rivue.reactive(nested))
		assertTrue(Rivue.toRaw(items)[3] == nested, "Proxies are stored raw")

		local ok = pcall(function()
			array.push(Rivue.readonly({ 1 }), 2)
		end)
		assertTrue(not ok, "Readonly arrays are refused")
	end

	print("Test 2: proxyRefs")
	do
		local count = Rivue.ref(1)
		local state = Rivue.proxyRefs({ count = count, label = "x" })
		assertEquals(state.count, 1, "Reads unwrap refs")
		state.count = 5
		assertEquals(count.value, 5, "Writes set the ref")
		assertEquals(state.label, "x", "Plain values pass through")
	end

	print("Test 3: render(ctx) reads setup state, props and the setup context")
	do
		local selected: number? = nil
		local Row = Rivue.defineComponent({
			name = "Row",
			props = { label = { type = "string" } },
			emits = { "pick" },
			setup = function()
				local count = Rivue.ref(0)
				return {
					count = count,
					increment = function()
						count.value += 1
					end,
				}
			end,
			render = function(ctx)
				return h("TextButton", {
					Text = `{ctx.label} {ctx.count}`,
					onClick = function()
						ctx.increment()
						ctx.emit("pick", ctx.count)
					end,
				}, ctx.renderSlot("default"))
			end,
		})
		local container = Instance.new("Frame")
		Rivue.createApp(h(Row, {
			label = "Row",
			onPick = function(n: number)
				selected = n
			end,
		}, { h("Frame", { Name = "Inner" }) })):mount(container)
		local button = container:FindFirstChild("Row") :: TextButton
		assertEquals(button.Text, "Row 0", "Refs are unwrapped, props are readable")
		assertTrue(button:FindFirstChild("Inner") ~= nil, "Setup context helpers are available")
		Rivue.testing.trigger(button, "onClick")
		task.wait()
		assertEquals(button.Text, "Row 1", "State updates re-render")
		assertEquals(selected, 1, "ctx.emit works")
	end

	print("Test 4: render(ctx) can assign returned refs")
	do
		local Toggle = Rivue.defineComponent({
			name = "Toggle",
			setup = function()
				return { on = Rivue.ref(false) }
			end,
			render = function(ctx)
				return h("TextButton", {
					Text = if ctx.on then "ON" else "OFF",
					onClick = function()
						ctx.on = not ctx.on
					end,
				})
			end,
		})
		local container = Instance.new("Frame")
		Rivue.createApp(Toggle):mount(container)
		local button = container:FindFirstChild("Toggle") :: TextButton
		Rivue.testing.trigger(button, "onClick")
		task.wait()
		assertEquals(button.Text, "ON", "Assigning ctx.on sets the ref")
	end

	print("Test 5: Local components")
	do
		local Badge = Rivue.defineComponent({
			name = "Badge",
			render = function()
				return h("TextLabel", { Text = "badge" })
			end,
		})
		local Card = Rivue.defineComponent({
			name = "Card",
			components = { Badge = Badge },
			render = function()
				return h("Frame", nil, { h("Badge") })
			end,
		})
		local container = Instance.new("Frame")
		Rivue.createApp(Card):mount(container)
		local card = container:FindFirstChild("Card") :: Frame
		assertTrue(card:FindFirstChild("Badge") ~= nil, "h('Badge') renders the local component")
	end

	print("Test 6: class prop with app and component styles")
	do
		local Panel = Rivue.defineComponent({
			name = "Panel",
			styles = {
				title = { TextSize = 30 },
			},
			setup = function()
				return { active = Rivue.ref(true) }
			end,
			render = function(ctx)
				return h("Frame", { class = "card" }, {
					h("TextLabel", { Name = "Title", class = { "text", "title" } }),
					h("TextLabel", { Name = "Body", class = { text = true, muted = ctx.active }, TextSize = 12 }),
				})
			end,
		})
		local container = Instance.new("Frame")
		Rivue.createApp(h(Panel, { class = "wide" }))
			:styles({
				card = { BackgroundTransparency = 0.5, cornerRadius = 8 },
				wide = { Size = UDim2.fromOffset(500, 100) },
				text = { TextSize = 14 },
				title = { TextSize = 20 },
				muted = { TextTransparency = 0.5 },
			})
			:mount(container)
		local panel = container:FindFirstChild("Panel") :: Frame
		assertEquals(panel.BackgroundTransparency, 0.5, "App style applied")
		assertTrue(panel:FindFirstChildOfClass("UICorner") ~= nil, "Styles can use modifier props")
		assertEquals(panel.Size, UDim2.fromOffset(500, 100), "Parent's class adds to the root's")
		local title = panel:FindFirstChild("Title") :: TextLabel
		assertEquals(title.TextSize, 30, "Component styles win over app styles, later classes win")
		local body = panel:FindFirstChild("Body") :: TextLabel
		assertEquals(body.TextSize, 12, "The element's own props win over classes")
		assertEquals(body.TextTransparency, 0.5, "Map form applies enabled classes")
	end

	print("Test 7: layout and flex props")
	do
		local container = Instance.new("Frame")
		local v1 = h("Frame", {
			Name = "Row",
			layout = { direction = "horizontal", gap = 8, align = "center", justify = "space-between" },
		}, {
			h("Frame", { Name = "A", flex = "grow" }),
			h("Frame", { Name = "B", flex = 2 }),
		})
		renderer.patch(nil, v1, container)
		local row = container:FindFirstChild("Row") :: Frame
		local list = row:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		assertTrue(list ~= nil, "layout creates a UIListLayout")
		assertEquals(list.FillDirection, Enum.FillDirection.Horizontal, "direction")
		assertEquals(list.Padding, UDim.new(0, 8), "gap")
		assertEquals(list.VerticalAlignment, Enum.VerticalAlignment.Center, "align is the cross axis")
		assertEquals(list.HorizontalFlex, Enum.UIFlexAlignment.SpaceBetween, "justify spreads the main axis")
		local a = row:FindFirstChild("A") :: Frame
		local b = row:FindFirstChild("B") :: Frame
		assertTrue(a.LayoutOrder < b.LayoutOrder, "Children get LayoutOrder in render order")
		assertEquals((a:FindFirstChildOfClass("UIFlexItem") :: UIFlexItem).FlexMode, Enum.UIFlexMode.Grow, "flex mode")
		assertEquals((b:FindFirstChildOfClass("UIFlexItem") :: UIFlexItem).GrowRatio, 2, "flex ratio")

		local v2 = h("Frame", { Name = "Row", layout = { grid = UDim2.fromOffset(50, 50), gap = 4 } }, {
			h("Frame", { Name = "A" }),
			h("Frame", { Name = "B" }),
		})
		renderer.patch(v1, v2, container)
		assertTrue(row:FindFirstChildOfClass("UIListLayout") == nil, "Switching to a grid replaces the list")
		local grid = row:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		assertEquals(grid.CellSize, UDim2.fromOffset(50, 50), "grid cell size")
		assertEquals(grid.CellPadding, UDim2.fromOffset(4, 4), "grid gap")
	end

	print('Test 8: model = "name" binds setup state')
	do
		local Form = Rivue.defineComponent({
			name = "Form",
			setup = function()
				return { draft = Rivue.ref("hi") }
			end,
			render = function(ctx)
				return h("TextBox", { model = "draft", PlaceholderText = ctx.draft })
			end,
		})
		local container = Instance.new("Frame")
		Rivue.createApp(Form):mount(container)
		local box = container:FindFirstChild("Form") :: TextBox
		assertEquals(box.Text, "hi", "Reads the ref")
		box.Text = "typed"
		task.wait()
		assertEquals(box.PlaceholderText, "typed", "Typing writes the ref")

		local Broken = Rivue.defineComponent({
			name = "Broken",
			setup = function()
				return {}
			end,
			render = function()
				return h("TextBox", { model = "missing" })
			end,
		})
		-- Through LogService: in Roblox each module has its own globals, so replacing warn here
		-- wouldn't catch Rivue's warn calls
		local warnings: { string } = {}
		local conn = game:GetService("LogService").MessageOut:Connect(function(message, kind)
			if kind == Enum.MessageType.MessageWarning then
				table.insert(warnings, message)
			end
		end)
		Rivue.createApp(Broken):mount(Instance.new("Frame"))
		task.wait()
		conn:Disconnect()
		local mentioned = false
		for _, line in warnings do
			if string.find(line, "didn't return a ref named 'missing'", 1, true) then
				mentioned = true
			end
		end
		assertTrue(mentioned, "A missing ref is reported clearly")
	end

	print("\n========== READABILITY TESTS COMPLETE ==========\n")
end

return runTests
