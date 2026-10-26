--!nonstrict
-- The router, useAsync and gamepad focus

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

local function assertEquals(actual: any, expected: any, message: string)
	if actual ~= expected then
		error(`Assertion failed: {message}\nExpected: {tostring(expected)}\nActual: {tostring(actual)}`)
	end
	print("✓", message)
end

local function assertTrue(condition: boolean, message: string)
	if not condition then
		error("Assertion failed: " .. message)
	end
	print("✓", message)
end

local function find(root: Instance, name: string): Instance?
	for _, child in root:GetDescendants() do
		if child.Name == name then
			return child
		end
	end
	return nil
end

return function()
	print("useAsync")
	do
		local calls = 0
		local result = Rivue.useAsync(function(id: number)
			calls += 1
			task.wait(if id == 1 then 0.2 else 0.05)
			if id == 3 then
				error("not found")
			end
			return `item {id}`
		end, { args = { 1 } })
		assertTrue(result.loading.value, "it starts loading straight away")
		result.run(2)
		task.wait(0.1)
		assertEquals(result.data.value, "item 2", "the newest run lands")
		task.wait(0.2)
		assertEquals(result.data.value, "item 2", "a slower, older run doesn't overwrite it")
		assertTrue(not result.loading.value, "loading is off when done")
		result.run(3)
		task.wait(0.1)
		assertTrue(string.find(result.error.value or "", "not found", 1, true) ~= nil, "errors land in error")
		assertEquals(result.data.value, "item 2", "and data keeps the last good value")
		result.refresh()
		assertEquals(result.error.value, nil, "refresh clears the error")
		task.wait(0.1)
		assertEquals(calls, 4, "refresh reruns with the last arguments")

		local lazy = Rivue.useAsync(function()
			return 1
		end, { immediate = false, initial = 0 })
		assertEquals(lazy.data.value, 0, "immediate = false waits, with the initial value")

		local landed = false
		local Panel = Rivue.defineComponent({
			name = "AsyncPanel",
			setup = function()
				local state = Rivue.useAsync(function()
					task.wait(0.1)
					landed = true
					return 1
				end)
				return { state = state }
			end,
			render = function()
				return h("Frame")
			end,
		})
		local app = Rivue.createApp(Panel)
		app:mount(Instance.new("Folder"))
		app:unmount()
		task.wait(0.2)
		assertTrue(landed, "a result after unmount still runs the function")
	end

	print("Router")
	do
		local Home = Rivue.defineComponent({
			name = "Home",
			render = function()
				return h("TextLabel", { Name = "Screen", Text = "home" })
			end,
		})
		local counterSetups = 0
		local Item = Rivue.defineComponent({
			name = "Item",
			props = { id = { type = "number" } },
			setup = function()
				counterSetups += 1
				return { visits = Rivue.ref(counterSetups) }
			end,
			render = function(ctx)
				return h("TextLabel", { Name = "Screen", Text = `item {ctx.id}` })
			end,
		})
		local router = Rivue.createRouter({ routes = { home = Home, item = Item }, initial = "home" })
		local Shell = Rivue.defineComponent({
			name = "Shell",
			render = function()
				return h("Frame", { Name = "Shell" }, { h(Rivue.RouterView) })
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(Shell)
		app:use(router)
		app:mount(folder)
		local function screen()
			return (find(folder, "Screen") :: TextLabel).Text
		end
		assertEquals(screen(), "home", "the initial route renders")
		assertTrue(not router.canGoBack.value, "nothing to go back to yet")

		router.push("item", { id = 7 })
		Rivue.nextTick()
		assertEquals(screen(), "item 7", "push shows the route, params as props")
		assertTrue(router.canGoBack.value, "now there's history")
		router.push("item", { id = 8 })
		Rivue.nextTick()
		assertEquals(screen(), "item 8", "same route, new params")
		router.back()
		Rivue.nextTick()
		assertEquals(screen(), "item 7", "back")
		assertTrue(router.canGoForward.value, "and forward is possible")
		router.forward()
		Rivue.nextTick()
		assertEquals(screen(), "item 8", "forward")
		router.back()
		router.back()
		router.push("item", { id = 9 })
		Rivue.nextTick()
		assertTrue(not router.canGoForward.value, "a push drops the forward history")
		router.replace("home")
		Rivue.nextTick()
		assertEquals(screen(), "home", "replace swaps the current entry")
		router.back()
		Rivue.nextTick()
		assertEquals(screen(), "home", "so back skips what it replaced")

		local stopGuard = router.beforeEach(function(to)
			return to.name ~= "item"
		end)
		assertTrue(not router.push("item", { id = 1 }), "a guard returning false cancels")
		Rivue.nextTick()
		assertEquals(screen(), "home", "and nothing changes")
		stopGuard()
		assertTrue(router.push("item", { id = 1 }), "removing the guard allows it again")

		local ok = pcall(router.push, "missing")
		assertTrue(not ok, "an unknown route errors")

		local injected = nil
		local Probe = Rivue.defineComponent({
			name = "RouterProbe",
			setup = function()
				injected = Rivue.useRouter()
				return {}
			end,
			render = function()
				return h("Frame")
			end,
		})
		local probeApp = Rivue.createApp(Probe)
		probeApp:use(router)
		probeApp:mount(Instance.new("Folder"))
		assertTrue(injected == router, "useRouter gets the installed router")
		probeApp:unmount()
		app:unmount()

		local keptRouter = Rivue.createRouter({ routes = { home = Home, item = Item }, initial = "item" })
		local Kept = Rivue.defineComponent({
			name = "KeptShell",
			render = function()
				return h("Frame", nil, { h(Rivue.RouterView, { keepAlive = true }) })
			end,
		})
		local keptApp = Rivue.createApp(Kept)
		keptApp:use(keptRouter)
		keptApp:mount(Instance.new("Folder"))
		local before = counterSetups
		keptRouter.push("home")
		Rivue.nextTick()
		keptRouter.back()
		Rivue.nextTick()
		assertEquals(counterSetups, before, "keepAlive brings a screen back without setting it up again")
		keptApp:unmount()
	end

	-- A server has no selection to move
	if game:GetService("RunService"):IsClient() then
		print("useGamepadFocus")
		local GuiService = game:GetService("GuiService")
		-- Offline, services aren't children of game, so this folder stands in for "in the game"
		local inGame = Instance.new("Folder")
		inGame.Parent = game
		local outside = Instance.new("TextButton")
		outside.Parent = inGame
		GuiService.SelectedObject = nil
		local Menu = Rivue.defineComponent({
			name = "Menu",
			setup = function()
				local first = Rivue.useTemplateRef("first")
				Rivue.useGamepadFocus(first, { always = true })
				return {}
			end,
			render = function()
				return h("Frame", nil, {
					h("TextButton", { Name = "Play", ref = "first" }),
					h("TextButton", { Name = "Quit" }),
				})
			end,
		})
		local screen = Instance.new("ScreenGui")
		screen.Parent = workspace
		local app = Rivue.createApp(Menu)
		app:mount(screen)
		-- The focus waits for the post flush, when template refs are set
		task.wait(0.1)
		assertEquals(GuiService.SelectedObject, find(screen, "Play"), "the target is selected on mount")
		app:unmount()
		assertEquals(GuiService.SelectedObject, nil, "unmounting gives the selection back")

		GuiService.SelectedObject = outside
		local app2 = Rivue.createApp(Menu)
		app2:mount(screen)
		task.wait(0.1)
		app2:unmount()
		assertEquals(GuiService.SelectedObject, outside, "to whatever had it before")
		GuiService.SelectedObject = nil
		inGame:Destroy()
		screen:Destroy()
	end
end
