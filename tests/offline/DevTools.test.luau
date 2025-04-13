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

	find(widget, "Filter").Text = "wal"
	Rivue.nextTick()
	assertEquals(#rows(widget), 1, "the filter keeps matching names")
	assertEquals(rows(widget)[1].Text, "  <Wallet>  2", "case-insensitive")

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
