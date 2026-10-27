--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))

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

local function findIn(root: Instance, name: string): any
	for _, child in root:GetDescendants() do
		if child.Name == name then
			return child
		end
	end
	return nil
end

local function runTests()
	print("\n========== VUE FEATURES TEST SUITE ==========\n")

	print("Test 1: Writable computed")
	do
		local first = Rivue.ref("Ada")
		local last = Rivue.ref("Lovelace")
		local full = Rivue.computed({
			get = function()
				return first.value .. " " .. last.value
			end,
			set = function(value: string)
				local a, b = string.match(value, "(%S+) (%S+)")
				first.value, last.value = a :: string, b :: string
			end,
		})
		assertEquals(full.value, "Ada Lovelace", "Getter works")
		full.value = "Grace Hopper"
		assertEquals(first.value, "Grace", "Setter updates sources")
		assertEquals(full.value, "Grace Hopper", "Getter reflects new sources")
		assertTrue(Rivue.isRef(full), "Computed is a ref")
		assertEquals(Rivue.unref(full), "Grace Hopper", "unref unwraps computed")
	end

	print("Test 2: watch() with an array of sources")
	do
		local a = Rivue.ref(1)
		local b = Rivue.ref(2)
		local seen: any = nil
		Rivue.watch(
			{
				a,
				function()
					return b.value * 10
				end,
			} :: any,
			function(values)
				seen = values
			end,
			{ flush = "sync" }
		)
		a.value = 5
		assertTrue(seen ~= nil and seen[1] == 5 and seen[2] == 20, "Callback gets every source value")
		b.value = 3
		assertTrue(seen[1] == 5 and seen[2] == 30, "Any source change fires")
	end

	print("Test 3: watch() with once")
	do
		local count = Rivue.ref(0)
		local calls = 0
		Rivue.watch(count, function()
			calls += 1
		end, { flush = "sync", once = true })
		count.value = 1
		count.value = 2
		assertEquals(calls, 1, "Fires only once")
	end

	print("Test 4: watch() on a reactive object fires on nested changes")
	do
		local state = Rivue.reactive({ nested = { value = 1 } })
		local calls = 0
		Rivue.watch(state, function()
			calls += 1
		end, { flush = "sync" })
		state.nested.value = 2
		assertEquals(calls, 1, "Nested mutation fires the watcher")
	end

	print("Test 5: toValue, isShallow, shallowReadonly")
	do
		local r = Rivue.ref(3)
		assertEquals(Rivue.toValue(r), 3, "toValue unwraps refs")
		assertEquals(
			Rivue.toValue(function()
				return 4
			end),
			4,
			"toValue calls getters"
		)
		assertEquals(Rivue.toValue(5), 5, "toValue passes values through")
		assertTrue(Rivue.isShallow(Rivue.shallowRef(1)), "shallowRef is shallow")
		assertTrue(not Rivue.isShallow(Rivue.ref(1)), "ref is not shallow")
		local ro = Rivue.shallowReadonly({ inner = { x = 1 } })
		assertTrue(Rivue.isReadonly(ro) and Rivue.isShallow(ro), "shallowReadonly is readonly and shallow")
		assertTrue(not Rivue.isReadonly(ro.inner), "Nested table is not wrapped")
	end

	print("Test 6: provide()/inject() and app:provide()")
	do
		local injectedTheme: any, injectedVersion: any = nil, nil
		local Child = Rivue.defineComponent({
			name = "InjectChild",
			setup = function()
				injectedTheme = Rivue.inject("theme")
				injectedVersion = Rivue.inject("version")
				return function()
					return Rivue.h("Frame")
				end
			end,
		})
		local Parent = Rivue.defineComponent({
			name = "ProvideParent",
			setup = function()
				Rivue.provide("theme", "dark")
				return function()
					return Rivue.h(Child)
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Rivue.h(Parent))
		app:provide("version", "1.0")
		app:mount(container)
		assertEquals(injectedTheme, "dark", "inject() sees an ancestor's provide()")
		assertEquals(injectedVersion, "1.0", "inject() falls back to app:provide()")
		app:unmount()
		container:Destroy()
	end

	print("Test 7: app:use() and app.config.errorHandler")
	do
		local installed = false
		local handled: any = nil
		local Broken = Rivue.defineComponent({
			name = "Broken",
			setup = function()
				return function()
					error("render failed")
					return nil
				end
			end,
		})
		local app = Rivue.createApp(Rivue.h(Broken))
		app:use({
			install = function(a: any)
				installed = true
				a.config.errorHandler = function(err: string)
					handled = err
				end
			end,
		})
		local container = Instance.new("Folder")
		app:mount(container)
		assertTrue(installed, "Plugin install() ran")
		assertTrue(
			handled ~= nil and string.find(handled, "render failed", 1, true) ~= nil,
			"errorHandler got the error"
		)
		app:unmount()
		container:Destroy()
	end

	print("Test 8: Fragment and array roots")
	do
		local show = Rivue.ref(true)
		local Multi = Rivue.defineComponent({
			name = "MultiRoot",
			setup = function()
				return function()
					local nodes = { Rivue.h("Frame", { Name = "A" }) }
					if show.value then
						table.insert(nodes, Rivue.h("Frame", { Name = "B" }))
					end
					return nodes :: any
				end
			end,
		})
		local container = Instance.new("Folder")
		local app =
			Rivue.createApp(Rivue.h(Rivue.Fragment, nil, { Rivue.h("Frame", { Name = "Top" }), Rivue.h(Multi) }))
		app:mount(container)
		assertEquals(#container:GetChildren(), 3, "Fragment children mount without a wrapper")
		show.value = false
		task.wait(0.1)
		assertTrue(container:FindFirstChild("B") == nil, "Array root updates in place")
		assertTrue(container:FindFirstChild("A") ~= nil, "Remaining root kept")
		app:unmount()
		assertEquals(#container:GetChildren(), 0, "Unmount removes fragment children")
		container:Destroy()
	end

	print("Test 9: nextTick() runs after the re-render")
	do
		local text = Rivue.ref("before")
		local Label = Rivue.defineComponent({
			name = "TickLabel",
			setup = function()
				return function()
					return Rivue.h("TextLabel", { Name = "Tick", Text = text.value })
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Rivue.h(Label))
		app:mount(container)
		text.value = "after"
		Rivue.nextTick()
		local label = container:FindFirstChild("Tick") :: TextLabel
		assertEquals(label.Text, "after", "DOM is updated after nextTick()")
		app:unmount()
		container:Destroy()
	end

	print("model modifiers: trim, number, lazy")
	do
		local name = Rivue.ref("")
		local amount = Rivue.ref(0)
		local draft = Rivue.ref("")
		local Form = Rivue.defineComponent({
			name = "ModelModifiers",
			setup = function()
				return { name = name, amount = amount, draft = draft }
			end,
			render = function()
				return Rivue.h("Frame", nil, {
					Rivue.h("TextBox", { Name = "Name", model = "name", modelModifiers = { trim = true } }),
					Rivue.h("TextBox", { Name = "Amount", model = "amount", modelModifiers = { number = true } }),
					Rivue.h("TextBox", { Name = "Draft", model = "draft", modelModifiers = { lazy = true } }),
				})
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Form)
		app:mount(container)
		local function find(n: string): TextBox
			return findIn(container, n)
		end
		find("Name").Text = "  Ada  "
		assertEquals(name.value, "Ada", "trim strips whitespace")
		find("Amount").Text = "42"
		assertEquals(amount.value, 42, "number converts to a number")
		find("Amount").Text = "4x"
		assertEquals(amount.value, "4x", "number keeps text that isn't a number")
		Rivue.nextTick()
		assertEquals(find("Amount").Text, "4x", "the box shows the model value")
		find("Draft").Text = "Sword"
		assertEquals(draft.value, "", "lazy doesn't update while typing")
		if __OFFLINE then
			(find("Draft").FocusLost :: any):Fire(false)
			assertEquals(draft.value, "Sword", "lazy updates when focus is lost")
		end
		draft.value = "Shield"
		Rivue.nextTick()
		assertEquals(find("Draft").Text, "Shield", "lazy box follows the model")
		app:unmount()
	end

	print("vOnce renders once")
	do
		local count = Rivue.ref(1)
		local Once = Rivue.defineComponent({
			name = "Once",
			render = function()
				return Rivue.h("Frame", nil, {
					Rivue.h("TextLabel", { Name = "Static", Text = tostring(count.value), vOnce = true }),
					Rivue.h("TextLabel", { Name = "Live", Text = tostring(count.value) }),
				})
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Once)
		app:mount(container)
		count.value = 2
		Rivue.nextTick()
		assertEquals(findIn(container, "Static").Text, "1", "vOnce element keeps its first render")
		assertEquals(findIn(container, "Live").Text, "2", "other elements update")
		app:unmount()
	end

	print("useModel binds a component's model")
	do
		local Toggle = Rivue.defineComponent({
			name = "UseModelToggle",
			props = { modelValue = { type = "boolean", default = false } },
			setup = function(props, ctx)
				local on = Rivue.useModel(props, ctx)
				return {
					on = on,
					flip = function()
						on.value = not on.value
					end,
				}
			end,
			render = function(ctx)
				return Rivue.h(
					"TextButton",
					{ Name = "Toggle", Text = if ctx.on then "on" else "off", onClick = ctx.flip }
				)
			end,
		})
		local music = Rivue.ref(false)
		local Parent = Rivue.defineComponent({
			name = "UseModelParent",
			setup = function()
				return { music = music }
			end,
			render = function()
				return Rivue.h(Toggle, { model = "music" })
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Parent)
		app:mount(container)
		local button = findIn(container, "Toggle") :: TextButton
		Rivue.testing.trigger(button, "onClick")
		assertEquals(music.value, true, "useModel writes back to the parent's ref")
		Rivue.nextTick()
		assertEquals(button.Text, "on", "child re-renders with the new value")
		app:unmount()
	end

	print("computed gets its previous value, like Vue 3.4")
	do
		local list = Rivue.reactive({ 1, 2, 3 })
		local seen: { any } = {}
		local calls = 0
		local evens = Rivue.computed(function(previous: { number }?)
			calls += 1
			seen[calls] = previous
			local out = {}
			for i = 1, #list do
				if list[i] % 2 == 0 then
					table.insert(out, list[i])
				end
			end
			if previous and #previous == #out and previous[1] == out[1] then
				return previous
			end
			return out
		end)
		local first = evens.value
		assertEquals(calls, 1, "runs once on the first read")
		assertEquals(seen[1], nil, "nil on the first run")
		local fired = 0
		local stop = Rivue.watch(evens, function()
			fired += 1
		end, { flush = "sync" })
		Rivue.array.push(list, 5)
		local second = evens.value
		assertEquals(seen[2], first, "then the value it returned last time")
		assertEquals(second, first, "returning it keeps the same table")
		assertEquals(fired, 0, "so a watcher on it doesn't fire")
		stop()
	end

	print("Suspense emits pending, fallback and resolve, like Vue")
	do
		local events: { string } = {}
		local Slow = Rivue.defineComponent({
			name = "SlowShop",
			setup = function()
				local items = Rivue.useAsync(function()
					task.wait(0.1)
					return { "Sword" }
				end, { initial = {} })
				return { items = items.data }
			end,
			render = function()
				return Rivue.h("Frame")
			end,
		})
		local App = Rivue.defineComponent({
			name = "SuspenseEvents",
			render = function()
				return Rivue.h(Rivue.Suspense, {
					onPending = function()
						table.insert(events, "pending")
					end,
					onFallback = function()
						table.insert(events, "fallback")
					end,
					onResolve = function()
						table.insert(events, "resolve")
					end,
				}, { Rivue.h(Slow) })
			end,
		})
		local app = Rivue.createApp(App)
		app:mount(Instance.new("Folder"))
		Rivue.nextTick()
		assertEquals(table.concat(events, ","), "pending,fallback", "pending, then fallback while it loads")
		task.wait(0.2)
		Rivue.nextTick()
		assertEquals(table.concat(events, ","), "pending,fallback,resolve", "resolve once it has loaded")
		app:unmount()
	end

	print("onEffectCleanup runs before the next run and on stop, like Vue 3.5")
	do
		local count = Rivue.ref(0)
		local log: { string } = {}
		local stop = Rivue.watchEffect(function()
			local seen = count.value
			Rivue.onEffectCleanup(function()
				table.insert(log, "clean " .. seen)
			end)
		end, { flush = "sync" })
		count.value = 1
		assertEquals(table.concat(log, ","), "clean 0", "the last run's cleanup runs before the next run")
		stop()
		assertEquals(table.concat(log, ","), "clean 0,clean 1", "and the last one runs on stop")

		local runner = Rivue.effect(function()
			local seen = count.value
			Rivue.onEffectCleanup(function()
				table.insert(log, "effect " .. seen)
			end)
		end)
		Rivue.nextTick()
		count.value = 2
		Rivue.nextTick()
		runner:stop()
		assertEquals(log[#log - 1] .. "|" .. log[#log], "effect 1|effect 2", "plain effects too")
	end

	print("app.config.performance marks setup and render in the MicroProfiler")
	do
		local marks: { string }? = __profileMarks
		local before = if marks then #marks else 0
		local Panel = Rivue.defineComponent({
			name = "PerfPanel",
			setup = function()
				return {}
			end,
			render = function()
				return Rivue.h("Frame")
			end,
		})
		local app = Rivue.createApp(Panel)
		app.config.performance = true
		app:mount(Instance.new("Folder"))
		Rivue.nextTick()
		if marks then
			local joined = table.concat(marks, ",", before + 1)
			assertTrue(string.find(joined, "Rivue PerfPanel setup", 1, true) ~= nil, "setup is marked")
			assertTrue(string.find(joined, "Rivue PerfPanel render", 1, true) ~= nil, "render is marked")
			assertTrue(string.find(joined, "Rivue PerfPanel patch", 1, true) ~= nil, "patch is marked")
			assertEquals((debug :: any).profileDepth(), 0, "every mark is closed")
		end
		app:unmount()
	end

	print("\n========== VUE FEATURES TESTS COMPLETE ==========\n")
end

return runTests
