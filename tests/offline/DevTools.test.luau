--!nonstrict
-- The DevTools plugin's window, run against live components (offline only: in the dev place the
-- plugin sits in ServerStorage, where client tests can't reach it)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local DevTools = require(ReplicatedStorage:WaitForChild("RivueDevTools"):WaitForChild("App"))
local h = Rivue.h

local function assertEquals(actual: any, expected: any, message: string)
	if actual ~= expected then
		error(`Assertion failed: {message}\nExpected: {tostring(expected)}\nActual: {tostring(actual)}`)
	end
end

local function assertTrue(condition: boolean, message: string)
	if not condition then
		error("Assertion failed: " .. message)
	end
end

local function find(root: Instance, name: string): any
	for _, child in root:GetDescendants() do
		if child.Name == name then
			return child
		end
	end
	return nil
end

local function rows(root: Instance): { TextButton }
	local list = {}
	for _, child in find(root, "Tree"):GetChildren() do
		if child.ClassName == "TextButton" then
			table.insert(list, child)
		end
	end
	-- Keyed rows move by LayoutOrder, not by child order
	table.sort(list, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return list
end

return function()
	local coins = Rivue.ref(10)
	local Wallet = Rivue.defineComponent({
		name = "Wallet",
		setup = function()
			return { coins = coins }
		end,
		render = function(ctx)
			return h("TextLabel", { Text = `{ctx.coins} coins` })
		end,
	})
	local Shop = Rivue.defineComponent({
		name = "Shop",
		render = function()
			return h("Frame", nil, { h(Wallet) })
		end,
	})
	local game = Instance.new("Folder")
	local gameApp = Rivue.createApp(Shop)
	gameApp.config.devtools = true
	gameApp:mount(game)

	local stop = DevTools.start()
	local widget = Instance.new("Frame")
	local devApp = Rivue.createApp(DevTools.App)
	devApp:mount(widget)

	assertEquals(
		find(widget, "Header").Text,
		`Rivue {Rivue.version} · 2 components`,
		"header shows the version and count"
	)
	local list = rows(widget)
	assertEquals(#list, 2, "one row per component")
	assertEquals(list[1].Text, "<Shop>  1", "parents first")
	assertEquals(list[2].Text, "  <Wallet>  1", "children indented under them")

	Rivue.testing.trigger(list[2], "onClick")
	Rivue.nextTick()
	local details = find(widget, "Details").Text
	assertTrue(string.find(details, "<Wallet>  rendered 1×", 1, true) ~= nil, "details name the component")
	assertTrue(string.find(details, "coins = 10", 1, true) ~= nil, "details show its state")
	assertEquals(Selection:Get()[1], find(game, "Wallet"), "clicking selects its root in the Explorer")

	coins.value = 11
	Rivue.nextTick()
	task.wait(0.3)
	Rivue.nextTick()
	local wallet = rows(widget)[2]
	assertEquals(wallet.Text, "  <Wallet>  2", "render counts update")
	assertTrue(wallet.TextColor3.R == 1 and wallet.TextColor3.G < 0.7, "a component that just re-rendered is orange")
	assertTrue(string.find(find(widget, "Details").Text, "coins = 11", 1, true) ~= nil, "details follow the state")
	assertTrue(
		string.find(find(widget, "Details").Text, "Last render: coins changed", 1, true) ~= nil,
		"details say what caused the render"
	)

	Rivue.testing.trigger(find(widget, "Sort"), "onClick")
	Rivue.nextTick()
	assertEquals(find(widget, "Sort").Text, "Sort: most renders", "the sort button cycles")
	assertEquals(rows(widget)[1].Text, "<Wallet>  2", "most renders first, without indents")
	Rivue.testing.trigger(find(widget, "Sort"), "onClick")
	Rivue.testing.trigger(find(widget, "Sort"), "onClick")
	Rivue.nextTick()
	assertEquals(find(widget, "Sort").Text, "Sort: tree", "and comes back to the tree")

	Rivue.testing.trigger(find(widget, "Pause"), "onClick")
	Rivue.nextTick()
	coins.value = 12
	Rivue.nextTick()
	task.wait(0.3)
	Rivue.nextTick()
	assertEquals(rows(widget)[2].Text, "  <Wallet>  2", "paused, the list holds still")
	assertTrue(string.find(find(widget, "Header").Text, "paused", 1, true) ~= nil, "the header says so")
	Rivue.testing.trigger(find(widget, "Pause"), "onClick")
	Rivue.nextTick()
	assertEquals(rows(widget)[2].Text, "  <Wallet>  3", "resuming catches up")

	Rivue.testing.trigger(find(widget, "Reset"), "onClick")
	Rivue.nextTick()
	assertEquals(rows(widget)[2].Text, "  <Wallet>  0", "reset counts from zero")
	coins.value = 13
	Rivue.nextTick()
	task.wait(0.3)
	Rivue.nextTick()
	assertEquals(rows(widget)[2].Text, "  <Wallet>  1", "and counts on from there")

	find(widget, "Filter").Text = "wal"
	Rivue.nextTick()
	assertEquals(#rows(widget), 1, "the filter keeps matching names")
	assertEquals(rows(widget)[1].Text, "  <Wallet>  1", "case-insensitive")
	find(widget, "Filter").Text = ""
	Rivue.nextTick()

	local Slow = Rivue.defineComponent({
		name = "Slow",
		render = function()
			return h("Frame")
		end,
	})
	local slowApp = Rivue.createApp(Slow)
	slowApp.config.devtools = true
	slowApp:mount(game)
	-- os.clock is virtual offline, so every render takes 0 ms; the plugin only reads the attribute
	find(game, "Slow"):SetAttribute("RivueRenderMs", DevTools.SLOW_MS + 1)
	task.wait(0.3)
	Rivue.nextTick()
	local slowRow
	for _, row in rows(widget) do
		if string.find(row.Text, "<Slow>", 1, true) then
			slowRow = row
		end
	end
	assertTrue(slowRow ~= nil and string.find(slowRow.Text, " ms", 1, true) ~= nil, "slow renders show their time")
	assertTrue(slowRow.TextColor3.R == 1 and slowRow.TextColor3.G < 0.5, "in red")
	slowApp:unmount()

	gameApp:unmount()
	task.wait(0.3)
	Rivue.nextTick()
	assertEquals(#rows(widget), 0, "unmounted components disappear")
	assertTrue(
		string.find(find(widget, "Details").Text, "No components yet", 1, true) ~= nil,
		"and the selection clears"
	)

	devApp:unmount()
	stop()
end
