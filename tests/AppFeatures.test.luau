--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local Router = require(ReplicatedStorage:WaitForChild("RivueRouter"))
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
		local router = Router.createRouter({ routes = { home = Home, item = Item }, initial = "home" })
		local Shell = Rivue.defineComponent({
			name = "Shell",
			render = function()
				return h("Frame", { Name = "Shell" }, { h(Router.RouterView) })
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
		assertTrue(Router.isNavigationFailure(router.push("item", { id = 1 })), "a guard returning false cancels")
		Rivue.nextTick()
		assertEquals(screen(), "home", "and nothing changes")
		stopGuard()
		assertTrue(router.push("item", { id = 1 }) == nil, "removing the guard allows it again")

		local ok = pcall(router.push, "missing")
		assertTrue(not ok, "an unknown route errors")

		local injected = nil
		local Probe = Rivue.defineComponent({
			name = "RouterProbe",
			setup = function()
				injected = Router.useRouter()
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

		local keptRouter = Router.createRouter({ routes = { home = Home, item = Item }, initial = "item" })
		local Kept = Rivue.defineComponent({
			name = "KeptShell",
			render = function()
				return h("Frame", nil, { h(Router.RouterView, { keepAlive = true }) })
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

	print("Bindings")
	do
		local seconds = Rivue.ref(10)
		local renders = 0
		local plain = Rivue.ref(false)
		local Timer = Rivue.defineComponent({
			name = "BoundTimer",
			setup = function()
				return { seconds = seconds }
			end,
			render = function(ctx)
				renders += 1
				return h("TextLabel", {
					Name = "Clock",
					Text = if plain.value
						then "paused"
						else Rivue.bind(function()
							return `{ctx.seconds}s`
						end),
					TextTransparency = seconds,
				})
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(Timer)
		app:mount(folder)
		local clock = find(folder, "Clock") :: TextLabel
		assertEquals(clock.Text, "10s", "Rivue.bind sets the first value")
		assertEquals(clock.TextTransparency, 10, "so does a plain ref")
		seconds.value = 9
		Rivue.nextTick()
		assertEquals(clock.Text, "9s", "a bound property follows its state")
		assertEquals(renders, 1, "without re-rendering the component")
		plain.value = true
		Rivue.nextTick()
		assertEquals(clock.Text, "paused", "a plain value replaces the binding")
		seconds.value = 8
		Rivue.nextTick()
		assertEquals(clock.Text, "paused", "and the old binding stops")
		app:unmount()
		seconds.value = 1
		Rivue.nextTick()
		assertEquals(clock.TextTransparency, 8, "unmounting stops bindings")
	end

	print("Testing helpers")
	do
		local Counter = Rivue.defineComponent({
			name = "HelperCounter",
			props = { start = { type = "number", default = 0 } },
			setup = function(props)
				local count = Rivue.ref(props.start)
				local name = Rivue.ref("")
				return {
					count = count,
					name = name,
					add = function()
						count.value += 1
					end,
				}
			end,
			render = function(ctx)
				return h("Frame", nil, {
					h("TextLabel", { Name = "Count", Text = `Count: {ctx.count}` }),
					h("TextButton", { Text = "Add", onActivated = ctx.add }),
					h("TextBox", { Name = "NameBox", model = "name" }),
					h("TextLabel", { Text = `Hi {ctx.name}` }),
				})
			end,
		})
		local screen = Rivue.testing.render(Counter, { start = 5 })
		assertTrue(screen.getByText("Count: 5") ~= nil, "render passes props, getByText finds by text")
		Rivue.testing.click(screen.getByText("Add"))
		assertTrue(screen.queryByText("Count: 6") ~= nil, "click works with onActivated and waits for the render")
		assertEquals(screen.queryByText("Count: 5"), nil, "queryByText returns nil when missing")
		assertTrue(not pcall(screen.getByText, "Nope"), "getByText errors when missing")
		Rivue.testing.typeInto(screen.getByName("NameBox"), "Ana")
		assertTrue(screen.queryByText("Hi Ana") ~= nil, "typeInto types into a TextBox")
		assertEquals(#screen.getAllByText(function(text)
			return string.sub(text, 1, 1) == "C"
		end), 1, "matching with a function")
		screen.unmount()
	end

	print("ErrorBoundary")
	do
		local broken = Rivue.ref(true)
		local reported = nil
		local Widget = Rivue.defineComponent({
			name = "FlakyWidget",
			render = function()
				if broken.value then
					error("widget exploded")
				end
				return h("TextLabel", { Text = "widget ok" })
			end,
		})
		local resetFn = nil
		local reachedApp = 0
		local App = Rivue.defineComponent({
			name = "BoundaryApp",
			render = function()
				return h(Rivue.ErrorBoundary, {
					onError = function(message)
						reported = message
					end,
					fallback = function(message, reset)
						resetFn = reset
						return h("TextLabel", { Text = "Couldn't load this panel" })
					end,
				}, { h(Widget) })
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(App)
		app.config.errorHandler = function()
			reachedApp += 1
		end
		app:mount(folder)
		Rivue.nextTick()
		local function hasText(text)
			for _, d in folder:GetDescendants() do
				if d:IsA("TextLabel") and d.Text == text then
					return true
				end
			end
			return false
		end
		assertTrue(hasText("Couldn't load this panel"), "the fallback replaces children that threw")
		assertTrue(string.find(reported or "", "widget exploded", 1, true) ~= nil, "onError gets the message")
		assertEquals(reachedApp, 0, "the error stops at the boundary")
		broken.value = false
		resetFn()
		Rivue.nextTick()
		assertTrue(hasText("widget ok"), "reset tries the children again")
		app:unmount()
	end

	print("Transition presets")
	do
		local fade = Rivue.transitions.fade({ duration = 0.3, mode = "out-in" })
		assertEquals(fade.tweenInfo.Time, 0.3, "duration sets the tween time")
		assertEquals(fade.mode, "out-in", "other options pass through to the Transition")
		assertEquals(fade.from.TextTransparency, 1, "fade hides text")
		local slide = Rivue.transitions.slide({ direction = "up", distance = 30 })
		assertEquals(
			slide.from.Position(UDim2.fromOffset(10, 10)),
			UDim2.fromOffset(10, 40),
			"slide up starts below where the element sits"
		)
		local pop = Rivue.transitions.pop({ scale = 0.5, fade = false })
		assertEquals(pop.from.Size(UDim2.fromOffset(100, 50)), UDim2.fromOffset(50, 25), "pop starts scaled down")
		assertEquals(pop.from.BackgroundTransparency, nil, "fade = false leaves transparency alone")

		local open = Rivue.ref(true)
		local Panel = Rivue.defineComponent({
			name = "PresetPanel",
			render = function()
				return h("Frame", { Name = "Root" }, {
					h(Rivue.Transition, Rivue.transitions.slide({ duration = 0.1 }), {
						Rivue.hIf(open.value, h("Frame", { Name = "Sheet", Position = UDim2.fromOffset(0, 100) })),
					}),
				})
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(Panel)
		app:mount(folder)
		open.value = false
		Rivue.nextTick()
		task.wait(0.3)
		assertEquals(find(folder, "Sheet"), nil, "a preset with a relative Position plays and removes the element")
		app:unmount()
	end

	print("Suspense waits for useAsync")
	do
		local Shop = Rivue.defineComponent({
			name = "SuspenseShop",
			setup = function()
				local items = Rivue.useAsync(function()
					task.wait(0.15)
					return { "Sword" }
				end, { initial = {} })
				return { items = items.data }
			end,
			render = function(ctx)
				return h("TextLabel", { Name = "Items", Text = table.concat(ctx.items, ",") })
			end,
		})
		local App = Rivue.defineComponent({
			name = "SuspenseApp",
			render = function()
				return h(Rivue.Suspense, nil, { h(Shop) })
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(App)
		app:mount(folder)
		Rivue.nextTick()
		assertTrue(find(folder, "SuspenseFallback") ~= nil, "the fallback shows while useAsync loads")
		task.wait(0.3)
		Rivue.nextTick()
		assertEquals(find(folder, "SuspenseFallback"), nil, "and goes once the data arrives")
		assertEquals((find(folder, "Items") :: TextLabel).Text, "Sword", "with the data rendered")
		app:unmount()
	end

	print("Dialog")
	do
		local open = Rivue.ref(false)
		local closes = 0
		local App = Rivue.defineComponent({
			name = "DialogApp",
			render = function()
				return h(Rivue.Dialog, {
					open = open.value,
					onClose = function()
						closes += 1
						open.value = false
					end,
				}, {
					h("TextButton", { Name = "Confirm", Text = "Confirm", Selectable = true }),
				})
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(App)
		app:mount(folder)
		assertEquals(find(folder, "DialogBackdrop"), nil, "closed, nothing renders")
		open.value = true
		Rivue.nextTick()
		local backdrop = find(folder, "DialogBackdrop")
		assertTrue(backdrop ~= nil, "open, the backdrop renders")
		assertTrue(find(folder, "Confirm") ~= nil, "with the content inside")
		assertTrue((find(folder, "DialogPanel") :: Frame).SelectionGroup, "gamepad navigation is kept inside")
		Rivue.testing.trigger(backdrop :: Instance, "onActivated")
		Rivue.nextTick()
		assertEquals(closes, 1, "a backdrop click asks to close")
		assertEquals(find(folder, "DialogBackdrop"), nil, "and the dialog goes")
		app:unmount()
	end

	print("Row, Column and Spacer")
	do
		local App = Rivue.defineComponent({
			name = "LayoutApp",
			render = function()
				return h(Rivue.Row, { Name = "Toolbar", gap = 8, align = "center" }, {
					h("TextButton", { Name = "Back" }),
					h(Rivue.Spacer),
					h("TextButton", { Name = "Close" }),
				})
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(App)
		app:mount(folder)
		local row = find(folder, "Toolbar") :: Frame
		assertTrue(row ~= nil, "extra props like Name reach the Frame")
		local list = row:FindFirstChildWhichIsA("UIListLayout") :: UIListLayout
		assertTrue(list ~= nil, "a Row gets a UIListLayout")
		assertEquals(list.FillDirection, Enum.FillDirection.Horizontal, "laid out horizontally")
		assertEquals(list.Padding, UDim.new(0, 8), "with the gap")
		local spacer = nil
		for _, child in row:GetChildren() do
			if child:FindFirstChildWhichIsA("UIFlexItem") then
				spacer = child
			end
		end
		assertTrue(spacer ~= nil, "a Spacer flexes to fill")
		app:unmount()
	end

	print("defineAsyncComponent onError")
	do
		local Shop = Rivue.defineComponent({
			name = "LoadedShop",
			render = function()
				return h("TextLabel", { Name = "LoadedShop" })
			end,
		})
		local tries = 0
		local attemptsSeen = {}
		local Lazy = Rivue.defineAsyncComponent(function()
			tries += 1
			task.wait(0.02)
			if tries < 3 then
				error("network")
			end
			return Shop
		end, {
			onError = function(_err, retry, fail, attempts)
				table.insert(attemptsSeen, attempts)
				if attempts < 5 then
					retry()
				else
					fail()
				end
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(Lazy)
		app:mount(folder)
		task.wait(0.3)
		Rivue.nextTick()
		assertEquals(tries, 3, "retry() loads again until it works")
		assertTrue(find(folder, "LoadedShop") ~= nil, "and then shows the component")
		assertEquals(table.concat(attemptsSeen, ","), "1,2", "onError gets the attempt count")
		app:unmount()

		local GaveUp = Rivue.defineAsyncComponent(function()
			error("down")
		end, {
			errorComponent = h("TextLabel", { Name = "LoadFailed" }),
			onError = function(_err, _retry, fail)
				fail()
			end,
		})
		local folder2 = Instance.new("Folder")
		local app2 = Rivue.createApp(GaveUp)
		app2:mount(folder2)
		task.wait(0.1)
		Rivue.nextTick()
		assertTrue(find(folder2, "LoadFailed") ~= nil, "fail() shows the error component")
		app2:unmount()

		local slowTries = 0
		local Slow = Rivue.defineAsyncComponent(function()
			slowTries += 1
			task.wait(if slowTries == 1 then 0.5 else 0.01)
			return Shop
		end, {
			timeout = 100,
			onError = function(err, retry)
				if string.find(err, "timeout", 1, true) then
					retry()
				end
			end,
		})
		local folder3 = Instance.new("Folder")
		local app3 = Rivue.createApp(Slow)
		app3:mount(folder3)
		task.wait(0.3)
		Rivue.nextTick()
		assertEquals(slowTries, 2, "a timeout goes to onError too, and can retry")
		assertTrue(find(folder3, "LoadedShop") ~= nil, "the late first answer is ignored")
		app3:unmount()
	end

	print("models")
	do
		local useColor = Rivue.defineModel({ name = "color" })
		local useAlpha = Rivue.defineModel({ name = "alpha" })
		local picked: any = nil
		local Picker = Rivue.defineComponent({
			name = "ColorPicker",
			props = { color = {}, alpha = {} },
			setup = function(props, ctx)
				picked = { color = useColor(props, ctx), alpha = useAlpha(props, ctx) }
				return picked
			end,
			render = function(ctx)
				return h("TextLabel", { Name = "Swatch", Text = `{ctx.color} {ctx.alpha}` })
			end,
		})
		local color = Rivue.ref("red")
		local App = Rivue.defineComponent({
			name = "PickerApp",
			setup = function()
				return { alpha = Rivue.ref(0.5) }
			end,
			render = function()
				return h(Picker, { models = { color = color, alpha = "alpha" } })
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(App)
		app:mount(folder)
		local swatch = find(folder, "Swatch") :: TextLabel
		assertEquals(swatch.Text, "red 0.5", "each model passes its value, by ref or by setup name")
		picked.color.value = "blue"
		picked.alpha.value = 1
		Rivue.nextTick()
		assertEquals(color.value, "blue", "writing a model updates the parent's ref")
		assertEquals(swatch.Text, "blue 1", "and both values re-render")
		color.value = "green"
		Rivue.nextTick()
		assertEquals(swatch.Text, "green 1", "the parent's changes flow down")
		app:unmount()
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
