--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

-- The DevTools plugin's window, run against live components (offline only: in the dev place the
-- plugin sits in ServerStorage, where client tests can't reach it)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local DevTools = require(ReplicatedStorage:WaitForChild("RivueDevTools"):WaitForChild("App"))
local Highlight = require(ReplicatedStorage:WaitForChild("RivueDevTools"):WaitForChild("Highlight"))
local Theme = require(ReplicatedStorage:WaitForChild("RivueDevTools"):WaitForChild("Theme"))
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

local function rows(root: Instance, listName: string?): { TextButton }
	local list = {}
	for _, child in find(root, listName or "Tree"):GetChildren() do
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

local function indentOf(row: Instance): number
	return (row:FindFirstChildWhichIsA("UIPadding") :: UIPadding).PaddingLeft.Offset
end

local function waitRefresh()
	Rivue.nextTick()
	task.wait(0.3)
	Rivue.nextTick()
end

return function()
	local coins = Rivue.ref(10)
	local Wallet = Rivue.defineComponent({
		name = "Wallet",
		emits = { "spend" },
		setup = function(_, ctx)
			return {
				coins = coins,
				owner = Rivue.ref("Ana"),
				spend = function()
					ctx.emit("spend", 5)
				end,
			}
		end,
		render = function(ctx)
			return h("TextButton", { Text = `{ctx.coins} coins`, onClick = ctx.spend })
		end,
	})
	local Shop = Rivue.defineComponent({
		name = "Shop",
		render = function()
			return h("Frame", nil, { h(Wallet) })
		end,
	})
	local game = Instance.new("ScreenGui")
	local gameApp = Rivue.createApp(Shop)
	gameApp.config.devtools = true
	gameApp:mount(game)

	local overlayParent = Instance.new("Folder")
	Highlight.setParent(overlayParent)
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
	assertEquals(list[2].Text, "<Wallet>  1", "then children")
	assertTrue(indentOf(list[2]) > indentOf(list[1]), "indented under their parent")

	Rivue.testing.trigger(list[2], "onMouseEnter")
	assertTrue(Highlight.current() ~= nil, "hovering a row outlines the component on screen")
	Rivue.testing.trigger(list[2], "onMouseLeave")
	assertEquals(Highlight.current(), nil, "and leaving removes the outline")
	Rivue.testing.trigger(list[1], "onMouseEnter")
	assertEquals(#overlayParent:GetChildren(), 1, "moving to another row moves the one outline")
	Rivue.testing.trigger(list[1], "onMouseLeave")

	Rivue.testing.trigger(find(list[1], "Toggle"), "onClick")
	Rivue.nextTick()
	assertEquals(#rows(widget), 1, "collapsing a row hides its children")
	assertEquals(find(rows(widget)[1], "Toggle").Text, "▸", "and flips its arrow")
	Rivue.testing.trigger(find(rows(widget)[1], "Toggle"), "onClick")
	Rivue.nextTick()
	assertEquals(#rows(widget), 2, "expanding shows them again")
	assertEquals(find(rows(widget)[2], "Toggle"), nil, "rows without children have no arrow")

	Rivue.testing.trigger(rows(widget)[2], "onClick")
	Rivue.nextTick()
	assertEquals(find(widget, "Summary").Text, "<Wallet>  rendered 1×, 0.00 ms", "details name the component")
	assertEquals(find(widget, "Cause").Text, "first render", "and what caused its last render")
	assertEquals(find(find(widget, "coins"), "Value").Text, "10", "state values sit in editable fields")
	assertEquals(Selection:Get()[1], find(game, "Wallet"), "clicking selects its root in the Explorer")

	coins.value = 11
	waitRefresh()
	local wallet = rows(widget)[2]
	assertEquals(wallet.Text, "<Wallet>  2", "render counts update")
	assertTrue(wallet.TextColor3.R == 1 and wallet.TextColor3.G < 0.7, "a component that just re-rendered is orange")
	assertEquals(find(find(widget, "coins"), "Value").Text, "11", "fields follow the state")
	assertEquals(find(widget, "Cause").Text, "coins changed", "the cause follows too")

	local field = find(find(widget, "coins"), "Value")
	field.Text = "50"
	Rivue.testing.trigger(field, "onFocusLost", true)
	waitRefresh()
	assertEquals(coins.value, 50, "editing a field sets the ref in the game")
	assertEquals(rows(widget)[2].Text, "<Wallet>  3", "which re-renders it")
	local owner = find(find(widget, "owner"), "Value")
	assertEquals(owner.Text, '"Ana"', "strings keep their quotes in the field")
	owner.Text = '"Bo"'
	Rivue.testing.trigger(owner, "onFocusLost", true)
	waitRefresh()
	assertEquals(find(find(widget, "owner"), "Value").Text, '"Bo"', "a ref the render doesn't read updates too")

	assertEquals(find(widget, "OpenSource"), nil, "no Open source button when the script can't be found")
	local root = Instance.new("Folder")
	local ui = Instance.new("Folder")
	ui.Name = "UI"
	ui.Parent = root
	local module = Instance.new("ModuleScript")
	module.Name = "Shop"
	module.Parent = ui
	local script, line = DevTools.resolveSource("UI.Shop:12", root)
	assertEquals(script, module, "a source path resolves to its script")
	assertEquals(line, 12, "with its line")
	assertEquals(DevTools.resolveSource("UI.Missing:3", root), nil, "missing scripts resolve to nil")

	Rivue.testing.trigger(find(widget, "Sort"), "onClick")
	Rivue.nextTick()
	assertEquals(find(widget, "Sort").Text, "Sort: most renders", "the sort button cycles")
	assertEquals(rows(widget)[1].Text, "<Wallet>  3", "most renders first")
	assertEquals(find(rows(widget)[2], "Toggle"), nil, "with no tree arrows")
	Rivue.testing.trigger(find(widget, "Sort"), "onClick")
	Rivue.testing.trigger(find(widget, "Sort"), "onClick")
	Rivue.nextTick()
	assertEquals(find(widget, "Sort").Text, "Sort: tree", "and comes back to the tree")

	Rivue.testing.trigger(find(widget, "Pause"), "onClick")
	Rivue.nextTick()
	coins.value = 12
	waitRefresh()
	assertEquals(rows(widget)[2].Text, "<Wallet>  3", "paused, the list holds still")
	assertTrue(string.find(find(widget, "Header").Text, "paused", 1, true) ~= nil, "the header says so")
	Rivue.testing.trigger(find(widget, "Pause"), "onClick")
	Rivue.nextTick()
	assertEquals(rows(widget)[2].Text, "<Wallet>  4", "resuming catches up")

	Rivue.testing.trigger(find(widget, "Reset"), "onClick")
	Rivue.nextTick()
	assertEquals(rows(widget)[2].Text, "<Wallet>  0", "reset counts from zero")
	coins.value = 13
	waitRefresh()
	assertEquals(rows(widget)[2].Text, "<Wallet>  1", "and counts on from there")

	find(widget, "Filter").Text = "wal"
	Rivue.nextTick()
	assertEquals(#rows(widget), 1, "the filter keeps matching names")
	find(widget, "Filter").Text = ""
	Rivue.nextTick()

	Rivue.testing.trigger(find(game, "Wallet"), "onClick")
	Rivue.testing.trigger(find(game, "Wallet"), "onClick")
	Rivue.testing.trigger(find(widget, "EventsTab"), "onClick")
	Rivue.nextTick()
	assertEquals(find(widget, "Tree"), nil, "the Events tab replaces the component list")
	local logged = rows(widget, "Events")
	assertEquals(#logged, 2, "every emit is logged")
	assertEquals(logged[1].Text, "<Wallet>  spend(5)", "with its component and arguments")
	Rivue.testing.trigger(find(widget, "Clear"), "onClick")
	Rivue.nextTick()
	assertEquals(#rows(widget, "Events"), 0, "Clear empties the log")
	Rivue.testing.trigger(find(widget, "ComponentsTab"), "onClick")
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
	waitRefresh()
	local slowRow
	for _, row in rows(widget) do
		if string.find(row.Text, "<Slow>", 1, true) then
			slowRow = row
		end
	end
	assertTrue(slowRow ~= nil and string.find(slowRow.Text, " ms", 1, true) ~= nil, "slow renders show their time")
	assertTrue(slowRow.TextColor3.R == 1 and slowRow.TextColor3.G < 0.5, "in red")
	slowApp:unmount()

	local light = table.clone(DevTools.palette.value)
	light.background = Color3.fromRGB(255, 255, 255)
	DevTools.setPalette(light)
	Rivue.nextTick()
	assertEquals(rows(widget)[1].BackgroundColor3, light.background, "a theme change recolours the window")
	DevTools.setPalette(Theme.DARK)
	Rivue.nextTick()

	gameApp:unmount()
	waitRefresh()
	assertEquals(#rows(widget), 0, "unmounted components disappear")
	assertTrue(
		string.find(find(widget, "Summary").Text, "No components yet", 1, true) ~= nil,
		"and the selection clears"
	)

	devApp:unmount()
	stop()
	Highlight.setParent(nil)
end
