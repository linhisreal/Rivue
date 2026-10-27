--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

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

local function assertTrue(condition: any, message: string)
	if not condition then
		error("Assertion failed: " .. message)
	end
	print("✓", message)
end

local function find(root: Instance, name: string): any
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function texts(root: Instance): string
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			table.insert(list, d.Text)
		end
	end
	table.sort(list)
	return table.concat(list, ",")
end

local function label(name: string, text: string?)
	return Rivue.defineComponent({
		name = name,
		render = function()
			return h("TextLabel", { Name = name, Text = text or name })
		end,
	})
end

local Shell = Rivue.defineComponent({
	name = "Shell",
	render = function()
		return h("Frame", { Name = "Shell" }, { h(Router.RouterView) })
	end,
})

local function mount(router, root)
	local folder = Instance.new("Folder")
	local app = Rivue.createApp(root or Shell)
	app:use(router)
	app:mount(folder)
	return folder, app
end

return function()
	local Failure = Router.NavigationFailureType

	print("Duplicated navigation")
	do
		local router =
			Router.createRouter({ routes = { home = label("Home"), item = label("Item") }, initial = "home" })
		local _, app = mount(router)
		assertEquals(router.push("item", { id = 1 }), nil, "push returns nil when it moves")
		local again = router.push("item", { id = 1 })
		assertTrue(
			Router.isNavigationFailure(again, Failure.duplicated),
			"the same route and params is a duplicated failure"
		)
		router.back()
		assertEquals(router.currentRoute.value.name, "home", "so one back is enough")
		assertEquals(router.push({ name = "home", force = true }), nil, "force pushes it anyway")
		assertTrue(router.push("item", { id = 2 }) == nil, "different params are a new entry")
		app:unmount()
	end

	print("Guards: order, redirect, afterEach")
	do
		local order = {}
		local Edit = Rivue.defineComponent({
			name = "Edit",
			setup = function()
				Router.onBeforeRouteLeave(function()
					table.insert(order, "leave")
				end)
				Router.onBeforeRouteUpdate(function()
					table.insert(order, "update")
				end)
				return {}
			end,
			render = function()
				return h("TextLabel", { Name = "Edit" })
			end,
		})
		local router = Router.createRouter({
			routes = {
				home = label("Home"),
				edit = Edit,
				admin = {
					component = label("Admin"),
					meta = { staff = true },
					beforeEnter = function()
						table.insert(order, "enter")
						return "home"
					end,
				},
			},
			initial = "home",
		})
		local initialSeen = nil
		router.beforeEach(function(to, from)
			table.insert(order, "each")
			if from == Router.START_LOCATION then
				initialSeen = to.name
			end
			return true
		end)
		router.beforeResolve(function()
			table.insert(order, "resolve")
		end)
		local after = {}
		router.afterEach(function(to, _from, result)
			table.insert(after, `{to.name}:{if result then result.type else "ok"}`)
		end)
		local folder, app = mount(router)
		assertEquals(initialSeen, "home", "the first screen goes through beforeEach on app:use")

		table.clear(order)
		router.push("edit", { id = 1 })
		Rivue.nextTick()
		assertTrue(find(folder, "Edit"), "edit shows")
		table.clear(order)
		router.push("edit", { id = 2 })
		assertEquals(table.concat(order, ","), "each,update,resolve", "a params change runs onBeforeRouteUpdate")
		table.clear(order)
		local result = router.push("admin")
		assertEquals(
			table.concat(order, ","),
			"leave,each,enter,leave,each,resolve",
			"leave, beforeEach, beforeEnter, then the redirect runs the guards again"
		)
		assertEquals(result, nil, "a guard redirect is a successful navigation")
		assertEquals(router.currentRoute.value.name, "home", "and lands on the redirect")
		assertEquals(router.currentRoute.value.redirectedFrom.name, "admin", "redirectedFrom says where it came from")
		assertEquals(after[#after], "home:ok", "afterEach runs for the final route")
		assertEquals(router.resolve("admin").meta.staff, true, "meta is on the resolved route")
		app:unmount()
	end

	print("Async guards and cancelled navigation")
	do
		local router =
			Router.createRouter({ routes = { a = label("A"), b = label("B"), c = label("C") }, initial = "a" })
		local _, app = mount(router)
		-- Stands in for a guard waiting on a confirm dialog
		local waiting: thread? = nil
		local function answer(value: boolean)
			local thread = waiting :: thread
			waiting = nil
			task.spawn(thread, value)
		end
		local stop = router.beforeEach(function(to)
			if to.name == "b" then
				waiting = coroutine.running()
				return coroutine.yield()
			end
			return true
		end)
		local first
		task.spawn(function()
			first = router.push("b")
		end)
		assertEquals(router.currentRoute.value.name, "a", "a yielding guard holds the navigation")
		assertEquals(router.push("c"), nil, "another navigation meanwhile goes ahead")
		answer(true)
		task.wait()
		assertTrue(Router.isNavigationFailure(first, Failure.cancelled), "and the waiting one is cancelled")
		assertEquals(router.currentRoute.value.name, "c", "c stays")

		local second
		task.spawn(function()
			second = router.push("b")
		end)
		answer(false)
		task.wait()
		assertTrue(Router.isNavigationFailure(second, Failure.aborted), "a guard that yields false aborts")
		task.spawn(function()
			second = router.push("b")
		end)
		answer(true)
		task.wait()
		assertEquals(second, nil, "and one that yields true lets it through")
		assertEquals(router.currentRoute.value.name, "b", "b shows")
		stop()
		app:unmount()
	end

	print("Nested routes, redirect, alias, props option")
	do
		local Shop = Rivue.defineComponent({
			name = "Shop",
			render = function()
				return h("Frame", { Name = "Shop" }, { h(Router.RouterView) })
			end,
		})
		local Pet = Rivue.defineComponent({
			name = "Pet",
			props = { kind = { type = "string" }, rare = { type = "boolean" } },
			render = function(ctx)
				return h("TextLabel", { Name = "Pet", Text = `{ctx.kind} {ctx.rare}` })
			end,
		})
		local router = Router.createRouter({
			routes = {
				{ name = "home", component = label("Home") },
				{
					name = "shop",
					component = Shop,
					alias = "store",
					redirect = "weapons",
					meta = { music = "shop" },
					children = {
						{ name = "weapons", component = label("Weapons"), meta = { tab = 1 } },
						{
							name = "pet",
							component = Pet,
							props = function(route)
								return { kind = route.params.kind, rare = true }
							end,
						},
					},
				},
			},
			initial = "home",
		})
		local folder, app = mount(router)
		router.push("store")
		Rivue.nextTick()
		local route = router.currentRoute.value
		assertEquals(route.name, "weapons", "an alias resolves, and the record's redirect goes to the child")
		assertEquals(#route.matched, 2, "matched holds the parent and the child")
		assertEquals(route.meta.music, "shop", "meta merges from the parent")
		assertEquals(route.meta.tab, 1, "and the child")
		assertTrue(find(find(folder, "Shop"), "Weapons"), "the child renders in the nested RouterView")
		assertEquals(router.resolve("shop").name, "shop", "resolve doesn't follow redirects, like Vue Router's")
		router.push("pet", { kind = "cat" })
		Rivue.nextTick()
		assertEquals(find(folder, "Pet").Text, "cat true", "a props function decides the props")
		assertTrue(find(folder, "Shop"), "the parent screen stays")
		app:unmount()
	end

	print("Named views")
	do
		local Layout = Rivue.defineComponent({
			name = "Layout",
			render = function()
				return h("Frame", nil, {
					h(Router.RouterView),
					h(Router.RouterView, { name = "side" }),
				})
			end,
		})
		local router = Router.createRouter({
			routes = {
				home = { components = { default = label("Main"), side = label("Chat") } },
				solo = label("Solo"),
			},
			initial = "home",
		})
		local folder, app = mount(router, Layout)
		assertEquals(texts(folder), "Chat,Main", "each RouterView shows its own component")
		router.push("solo")
		Rivue.nextTick()
		assertEquals(texts(folder), "Solo", "a view the route doesn't fill is empty")
		app:unmount()
	end

	print("RouterView slot with Transition, and lazy routes")
	do
		local loads = 0
		local Lazy = Rivue.defineAsyncComponent(function()
			loads += 1
			return label("Lazy")
		end)
		local router = Router.createRouter({ routes = { home = label("Home"), lazy = Lazy }, initial = "home" })
		local Root = Rivue.defineComponent({
			name = "Root",
			render = function()
				return h(Router.RouterView, nil, {
					default = function(view)
						return h(
							Rivue.Transition,
							{ mode = "out-in", tweenInfo = TweenInfo.new(0) },
							{ view.Component }
						)
					end,
				})
			end,
		})
		local folder, app = mount(router, Root)
		assertTrue(find(folder, "Home"), "the slot gets the screen as Component")
		router.push("lazy")
		task.wait(0.2)
		assertEquals(loads, 1, "a defineAsyncComponent route loads when first visited")
		assertTrue(find(folder, "Lazy") and not find(folder, "Home"), "and replaces the old screen")
		app:unmount()
	end

	print("RouterLink, useLink, useRoute")
	do
		local seenId = nil
		local Item = Rivue.defineComponent({
			name = "Item",
			setup = function()
				local route = Router.useRoute()
				local id = Rivue.computed(function()
					return route.params.id
				end)
				return { id = id }
			end,
			render = function(ctx)
				seenId = ctx.id
				return h("TextLabel", { Name = "Item", Text = tostring(ctx.id) })
			end,
		})
		local Nav = Rivue.defineComponent({
			name = "Nav",
			render = function()
				return h("Frame", nil, {
					h(Router.RouterLink, { Name = "ToShop", to = "shop", Text = "Shop" }),
					h(Router.RouterLink, { Name = "ToSword", to = { name = "item", params = { id = "sword" } } }),
					h(Router.RouterLink, { to = "home", custom = true }, {
						default = function(link)
							return h("TextButton", {
								Name = "Custom",
								Text = if link.isExactActive then "here" else "away",
								onActivated = link.navigate,
							})
						end,
					}),
					h(Router.RouterView),
				})
			end,
		})
		local router = Router.createRouter({
			routes = {
				home = label("Home"),
				shop = {
					component = Rivue.defineComponent({
						name = "ShopScreen",
						render = function()
							return h("Frame", nil, { h(Router.RouterView) })
						end,
					}),
					children = { item = Item },
				},
			},
			initial = "home",
		})
		local folder, app = mount(router, Nav)
		local toShop, toSword, custom = find(folder, "ToShop"), find(folder, "ToSword"), find(folder, "Custom")
		assertEquals(toShop.Text, "Shop", "extra props reach the TextButton")
		assertEquals(custom.Text, "here", "a custom link renders its slot with the link's state")
		Rivue.testing.click(toSword)
		Rivue.nextTick()
		assertEquals(router.currentRoute.value.name, "item", "pressing a link navigates")
		assertEquals(seenId, "sword", "useRoute reads the params")
		local ShopLink = Rivue.defineComponent({
			name = "ShopLink",
			setup = function()
				return Router.useLink({ to = "shop" })
			end,
			render = function()
				return h("Frame")
			end,
		})
		local link
		local probe = Rivue.createApp(Rivue.defineComponent({
			name = "LinkProbe",
			setup = function()
				link = Router.useLink({ to = "shop" })
				return {}
			end,
			render = function()
				return h(ShopLink)
			end,
		}))
		probe:use(router)
		probe:mount(Instance.new("Folder"))
		assertTrue(link.isActive.value, "a parent's link is active while a child route shows")
		assertTrue(not link.isExactActive.value, "but not exactly active")
		assertEquals(custom.Text, "away", "the custom link updates")
		router.push("shop")
		assertTrue(link.isExactActive.value, "exactly active on the route itself")
		probe:unmount()
		app:unmount()
	end

	print("RouterLink classes")
	do
		local router = Router.createRouter({ routes = { a = label("A"), b = label("B") }, initial = "a" })
		local Tabs = Rivue.defineComponent({
			name = "Tabs",
			render = function()
				return h("Frame", nil, {
					h(Router.RouterLink, { Name = "TabA", to = "a", class = "tab" }),
					h(Router.RouterLink, { Name = "TabB", to = "b", class = "tab" }),
				})
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(Tabs)
		app:styles({
			tab = { TextSize = 14, TextColor3 = Color3.new(0.5, 0.5, 0.5) },
			["router-link-active"] = { TextColor3 = Color3.new(1, 1, 1) },
		})
		app:use(router)
		app:mount(folder)
		local tabA, tabB = find(folder, "TabA"), find(folder, "TabB")
		assertEquals(tabA.TextSize, 14, "the link keeps its own class")
		assertEquals(tabA.TextColor3.R, 1, "and gets router-link-active while its route shows")
		assertEquals(tabB.TextColor3.R, 0.5, "the other tab doesn't")
		router.push("b")
		Rivue.nextTick()
		assertEquals(tabA.TextColor3.R, 0.5, "the class moves when the route changes")
		assertEquals(tabB.TextColor3.R, 1, "to the new tab")
		app:unmount()
	end

	print("go(), dynamic routes")
	do
		local router =
			Router.createRouter({ routes = { a = label("A"), b = label("B"), c = label("C") }, initial = "a" })
		local _, app = mount(router)
		router.push("b")
		router.push("c")
		assertEquals(router.go(-2), nil, "go(-2) moves two steps")
		assertEquals(router.currentRoute.value.name, "a", "back to a")
		assertTrue(Router.isNavigationFailure(router.go(-1), Failure.aborted), "going past the start fails")
		router.go(2)
		assertEquals(router.currentRoute.value.name, "c", "go(2) forward")

		assertTrue(not router.hasRoute("event"), "no event route yet")
		local remove = router.addRoute({ name = "event", component = label("Event") })
		assertTrue(router.hasRoute("event"), "addRoute adds it")
		assertEquals(router.push("event"), nil, "and it can be visited")
		router.addRoute("event", { name = "prizes", component = label("Prizes") })
		assertEquals(router.resolve("prizes").matched[1].name, "event", "addRoute(parent, record) nests it")
		remove()
		assertTrue(
			not router.hasRoute("event") and not router.hasRoute("prizes"),
			"the remover takes it and its children away"
		)
		router.removeRoute("c")
		assertTrue(not router.hasRoute("c"), "removeRoute")
		assertEquals(#router.getRoutes(), 2, "getRoutes lists what's left")
		app:unmount()
	end

	print("scrollBehavior")
	do
		local List = Rivue.defineComponent({
			name = "List",
			render = function()
				return h("ScrollingFrame", { Name = "List", CanvasSize = UDim2.fromOffset(0, 2000) })
			end,
		})
		local router = Router.createRouter({
			routes = { list = List, other = label("Other") },
			initial = "list",
			scrollBehavior = function(_to, _from, savedPosition)
				return savedPosition or { top = 0 }
			end,
		})
		local folder, app = mount(router)
		find(folder, "List").CanvasPosition = Vector2.new(0, 500)
		router.push("other")
		Rivue.nextTick()
		router.back()
		task.wait()
		assertEquals(find(folder, "List").CanvasPosition.Y, 500, "back restores the saved position")
		router.push("other")
		router.push("list")
		task.wait()
		assertEquals(find(folder, "List").CanvasPosition.Y, 0, "a push scrolls to the top")
		app:unmount()
	end

	print("scrollBehavior with el")
	do
		local Screen = Rivue.defineComponent({
			name = "TwoLists",
			render = function()
				return h("Frame", nil, {
					h("ScrollingFrame", { Name = "Main" }),
					h("ScrollingFrame", { Name = "Side" }),
				})
			end,
		})
		local router = Router.createRouter({
			routes = { a = Screen, b = label("B") },
			initial = "b",
			scrollBehavior = function()
				return { el = "Main", top = 40 }
			end,
		})
		local folder, app = mount(router)
		router.push("a")
		task.wait()
		assertEquals(find(folder, "Main").CanvasPosition.Y, 40, "the frame named by el scrolls")
		assertEquals(find(folder, "Side").CanvasPosition.Y, 0, "the others stay put")
		app:unmount()
	end

	print("isReady and onError")
	do
		local release: thread? = nil
		local router = Router.createRouter({ routes = { a = label("A"), b = label("B") }, initial = "a" })
		router.beforeEach(function(to, from)
			if from == Router.START_LOCATION then
				release = coroutine.running()
				coroutine.yield()
			end
			return to.name ~= "b"
		end)
		local folder, app = mount(router)
		assertEquals(router.currentRoute.value, Router.START_LOCATION, "a waiting guard doesn't block mounting")
		local readyAt = nil
		task.spawn(function()
			router.isReady()
			readyAt = router.currentRoute.value.name
		end)
		assertEquals(readyAt, nil, "isReady waits for the first navigation")
		task.spawn(release :: thread)
		task.wait()
		assertEquals(readyAt, "a", "and returns once it's done")
		Rivue.nextTick()
		assertTrue(find(folder, "A") ~= nil, "the first screen shows")
		router.isReady()

		local errors = {}
		local removeHandler = router.onError(function(err, to)
			table.insert(errors, `{to.name}:{tostring(err):match("broken") ~= nil}`)
		end)
		local removeGuard = router.beforeEach(function(to)
			if to.name == "a" then
				error("broken guard")
			end
			return true
		end)
		router.replace("b")
		local result = router.push("a", { again = true })
		assertTrue(
			Router.isNavigationFailure(result, Router.NavigationFailureType.aborted),
			"an erroring guard still aborts"
		)
		assertEquals(errors[1], "a:true", "onError gets the error and the target route")
		removeHandler()
		removeGuard()
		app:unmount()
	end

	print("Route query")
	do
		local router = Router.createRouter({
			routes = { lobby = label("Lobby"), shop = label("Shop"), store = { redirect = "shop" } },
			initial = "lobby",
		})
		local _, app = mount(router)
		router.isReady()
		assertEquals(next(router.currentRoute.value.query), nil, "query starts empty")
		router.push({ name = "shop", query = { tab = "weapons" } })
		assertEquals(router.currentRoute.value.query.tab, "weapons", "push takes a query")
		assertTrue(table.isfrozen(router.currentRoute.value.query), "and it's read-only")
		local again = router.push({ name = "shop", query = { tab = "armor" } })
		assertEquals(again, nil, "a different query is a new navigation, like Vue Router")
		local same = router.push({ name = "shop", query = { tab = "armor" } })
		assertTrue(Router.isNavigationFailure(same, Failure.duplicated), "the same query is duplicated")
		router.push({ name = "store", query = { tab = "pets" } })
		assertEquals(router.currentRoute.value.name, "shop", "redirects still apply")
		assertEquals(router.currentRoute.value.query.tab, "pets", "and keep the query")
		router.back()
		assertEquals(router.currentRoute.value.query.tab, "armor", "history keeps each entry's query")
		assertEquals(router.resolve({ name = "shop", query = { tab = "x" } }).query.tab, "x", "resolve too")
		app:unmount()
	end

	print("Back keys")
	do
		local router = Router.createRouter({
			routes = { lobby = label("Lobby"), shop = label("Shop") },
			initial = "lobby",
			backKeys = { Enum.KeyCode.ButtonB },
		})
		local _, app = mount(router)
		router.isReady()
		__pressKey(Enum.KeyCode.ButtonB)
		assertEquals(router.currentRoute.value.name, "lobby", "nothing to go back to")
		router.push("shop")
		__pressKey(Enum.KeyCode.ButtonB)
		assertEquals(router.currentRoute.value.name, "lobby", "the key goes back")
		app:unmount()
		router.push("shop")
		__pressKey(Enum.KeyCode.ButtonB)
		assertEquals(router.currentRoute.value.name, "shop", "unbound when the app unmounts")
	end

	print("Lazy route components")
	do
		local loads = 0
		local router = Router.createRouter({
			routes = {
				lobby = label("Lobby"),
				shop = Router.lazy(function()
					loads += 1
					return label("Shop")
				end),
				broken = Router.lazy(function()
					error("missing module")
				end),
			},
			initial = "lobby",
		})
		local errors = {}
		router.onError(function(err)
			table.insert(errors, tostring(err))
		end)
		local folder, app = mount(router)
		router.isReady()
		assertEquals(loads, 0, "not loaded until it's visited")
		local order = {}
		router.beforeResolve(function(to)
			if to.name == "shop" then
				table.insert(order, `beforeResolve after {loads} load`)
			end
			return true
		end)
		router.push("shop")
		Rivue.nextTick()
		assertTrue(find(folder, "Shop") ~= nil, "then it shows")
		assertEquals(order[1], "beforeResolve after 1 load", "loaded before beforeResolve, like Vue Router")
		router.push("lobby")
		router.push("shop")
		assertEquals(loads, 1, "and only loaded once")
		local result = router.push("broken")
		assertTrue(Router.isNavigationFailure(result, Failure.aborted), "a loader error aborts")
		assertTrue(errors[1] and errors[1]:find("missing module") ~= nil, "and goes to onError")
		app:unmount()
	end

	print("Navigations reach the DevTools")
	do
		local router =
			Router.createRouter({ routes = { lobby = label("Lobby"), shop = label("Shop") }, initial = "lobby" })
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(Shell)
		app.config.devtools = true
		app:use(router)
		app:mount(folder)
		router.isReady()
		router.push({ name = "shop", params = { id = 2 }, query = { tab = "x" } })
		local channel = folder:FindFirstChild("RivueDevTools")
		local route = channel:GetAttribute("RivueRoute")
		assertTrue(route:find("name = shop", 1, true) ~= nil, `the current route: {route}`)
		assertTrue(
			route:find("id = 2", 1, true) ~= nil and route:find('tab = "x"', 1, true) ~= nil,
			"with params and query"
		)
		assertTrue(route:find("history = lobby, [shop]", 1, true) ~= nil, "and the history")
		local timeline = channel:GetAttribute("RivueTimeline")
		assertTrue(timeline:find("\tnavigation\t\tlobby -> shop", 1, true) ~= nil, "navigations are on the timeline")
		app:unmount()
	end
end
