--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

-- Uses the game's own RivueUI, a second copy would track state separately

local function loadRivue(candidate: Instance?): any
	if not candidate then
		return nil
	end
	local ok, loaded = pcall(require, candidate :: any)
	if ok and type(loaded) == "table" and loaded.h and loaded.createApp then
		return loaded
	end
	return nil
end

local function findRivue(): any
	local node: Instance? = script.Parent
	while node do
		local found = loadRivue(node:FindFirstChild("RivueUI"))
		if not found then
			local pesdePackages = node:FindFirstChild("roblox_packages")
			found = loadRivue(if pesdePackages then pesdePackages:FindFirstChild("RivueUI") else nil)
		end
		if found then
			return found
		end
		node = node.Parent
	end
	error("[RivueRouter] Couldn't find Rivue. Install RivueUI next to RivueRouter", 0)
end

local Rivue = findRivue()
local h = Rivue.h
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

export type Params = { [string]: any }

export type RouteRecord = {
	name: string,
	component: any?,
	components: { [string]: any }?,
	children: { RouteRecord }?,
	meta: { [string]: any }?,
	redirect: (string | RouteLocation | (to: Route) -> string | RouteLocation)?,
	alias: (string | { string })?,
	props: any?,
	beforeEnter: (Guard | { Guard })?,
}

export type Query = { [string]: any }

export type RouteLocation = {
	name: string,
	params: Params?,
	query: Query?,
	replace: boolean?,
	force: boolean?,
}

export type Route = {
	name: string?,
	params: Params,
	query: Query,
	meta: { [string]: any },
	matched: { RouteRecord },
	redirectedFrom: Route?,
}

export type NavigationFailure = {
	type: number,
	to: Route,
	from: Route,
}

export type GuardResult = boolean | string | RouteLocation | nil
export type Guard = (to: Route, from: Route) -> GuardResult
export type AfterHook = (to: Route, from: Route, failure: NavigationFailure?) -> ()
export type ScrollPositions = { [string]: Vector2 }
export type ErrorHandler = (err: unknown, to: Route, from: Route) -> ()
export type ScrollBehavior = (to: Route, from: Route, savedPosition: ScrollPositions?) -> any

export type RouterOptions = {
	routes: { [string]: any } | { RouteRecord },
	initial: string,
	initialParams: Params?,
	scrollBehavior: ScrollBehavior?,
	backKeys: { Enum.KeyCode }?,
}

local NavigationFailureType = table.freeze({
	aborted = 4,
	cancelled = 8,
	duplicated = 16,
})

local START_LOCATION: Route = table.freeze({
	name = nil,
	params = table.freeze({}),
	query = table.freeze({}),
	meta = table.freeze({}),
	matched = table.freeze({}),
	redirectedFrom = nil,
}) :: any

local ROUTER_KEY = "router"
local backActions = 0
local VIEW_KEY = "routerView"
local MAX_REDIRECTS = 10

local function isComponent(value: any): boolean
	return type(value) == "table" and value.__is_component == true
end

export type LazyComponent = { __rivueLazy: true, loader: () -> any }

local function lazy(loader: () -> any): LazyComponent
	assert(type(loader) == "function", "[RivueRouter] lazy() expects a function that returns a component")
	return table.freeze({ __rivueLazy = true :: true, loader = loader })
end

local function isLazy(value: any): boolean
	return type(value) == "table" and value.__rivueLazy == true
end

local function describe(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) ~= "table" then
		return tostring(value)
	end
	local parts = {}
	for key, item in value do
		table.insert(parts, `{key} = {describe(item)}`)
	end
	table.sort(parts)
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function failure(kind: number, to: Route, from: Route): NavigationFailure
	return table.freeze({ type = kind, to = to, from = from })
end

local function isNavigationFailure(value: any, kind: number?): boolean
	if type(value) ~= "table" or type(value.type) ~= "number" or value.to == nil then
		return false
	end
	return kind == nil or bit32.band(value.type, kind) ~= 0
end

local function sameParams(a: Params, b: Params): boolean
	for key, value in a do
		if b[key] ~= value then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function includesParams(outer: Params, inner: Params): boolean
	for key, value in inner do
		if outer[key] ~= value then
			return false
		end
	end
	return true
end

local function asList<T>(value: T | { T } | nil): { T }
	if value == nil then
		return {}
	elseif type(value) == "table" and (value :: any)[1] ~= nil then
		return value :: any
	end
	return { value :: any }
end

local function scrollKey(frame: Instance, root: Instance): string
	local parts = {}
	local node: Instance? = frame
	while node and node ~= root do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return if #parts == 0 then "." else table.concat(parts, "/")
end

local function scrollingFrames(root: Instance?): { ScrollingFrame }
	local frames = {}
	if not root then
		return frames
	end
	if root:IsA("ScrollingFrame") then
		table.insert(frames, root :: ScrollingFrame)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("ScrollingFrame") then
			table.insert(frames, d :: ScrollingFrame)
		end
	end
	return frames
end

local function rootElement(vnode: any): Instance?
	while vnode do
		if type(vnode.type) == "string" and vnode.el then
			return vnode.el
		elseif vnode._instance then
			vnode = vnode._instance.subTree
		elseif vnode._fnTree then
			vnode = vnode._fnTree
		else
			return nil
		end
	end
	return nil
end

export type Router = {
	currentRoute: { value: Route },
	current: { value: Route },
	canGoBack: { value: boolean },
	canGoForward: { value: boolean },
	push: (to: string | RouteLocation, params: Params?) -> NavigationFailure?,
	replace: (to: string | RouteLocation, params: Params?) -> NavigationFailure?,
	go: (delta: number) -> NavigationFailure?,
	back: () -> NavigationFailure?,
	forward: () -> NavigationFailure?,
	resolve: (to: string | RouteLocation, params: Params?) -> Route,
	beforeEach: (guard: Guard) -> () -> (),
	beforeResolve: (guard: Guard) -> () -> (),
	afterEach: (hook: AfterHook) -> () -> (),
	onError: (handler: ErrorHandler) -> () -> (),
	isReady: () -> (),
	addRoute: (parentOrRecord: string | RouteRecord, record: RouteRecord?) -> () -> (),
	removeRoute: (name: string) -> (),
	hasRoute: (name: string) -> boolean,
	getRoutes: () -> { RouteRecord },
	install: (app: any) -> (),
	_scrollRoot: (() -> Instance?)?,
}

local function createRouter(options: RouterOptions): Router
	assert(type(options) == "table" and type(options.routes) == "table", "createRouter expects { routes, initial }")

	local records: { [string]: any } = {}
	local aliases: { [string]: any } = {}
	local roots: { any } = {}

	local removeRecord: (record: any) -> ()

	local function addRecord(raw: any, nameHint: string?, parent: any?): any
		local def: any = if isComponent(raw) or isLazy(raw) then { component = raw } else raw
		assert(type(def) == "table", `[RivueRouter] Route '{nameHint}' must be a component or a route record`)
		local name = def.name or nameHint
		assert(type(name) == "string", "[RivueRouter] Every route needs a name")
		if records[name] or aliases[name] then
			error(`[RivueRouter] Two routes are named '{name}'`, 0)
		end
		local components = def.components or (if def.component then { default = def.component } else nil)
		local record = {
			name = name,
			components = components,
			props = if def.components
				then def.props or {}
				else { default = if def.props == nil then true else def.props },
			meta = def.meta or {},
			redirect = def.redirect,
			beforeEnter = asList(def.beforeEnter),
			parent = parent,
			children = {},
			aliases = asList(def.alias),
			leaveGuards = {},
			updateGuards = {},
		}
		records[name] = record
		for _, alias in record.aliases do
			if records[alias] or aliases[alias] then
				error(`[RivueRouter] Alias '{alias}' is already a route name`, 0)
			end
			aliases[alias] = record
		end
		if parent then
			table.insert(parent.children, record)
		else
			table.insert(roots, record)
		end
		local children = def.children
		if type(children) == "table" then
			if children[1] ~= nil then
				for _, child in children do
					addRecord(child, nil, record)
				end
			else
				local names = {}
				for key in children do
					table.insert(names, key)
				end
				table.sort(names)
				for _, key in names do
					addRecord(children[key], key, record)
				end
			end
		end
		return record
	end

	removeRecord = function(record: any)
		for _, child in table.clone(record.children) do
			removeRecord(child)
		end
		records[record.name] = nil
		for _, alias in record.aliases do
			aliases[alias] = nil
		end
		local siblings = if record.parent then record.parent.children else roots
		local at = table.find(siblings, record)
		if at then
			table.remove(siblings, at)
		end
	end

	local routes = options.routes :: any
	if routes[1] ~= nil then
		for _, raw in routes do
			addRecord(raw, nil, nil)
		end
	else
		local names = {}
		for key in routes do
			table.insert(names, key)
		end
		table.sort(names)
		for _, key in names do
			addRecord(routes[key], key, nil)
		end
	end

	local function findRecord(name: string): any
		local record = records[name] or aliases[name]
		if not record then
			local names = {}
			for key in records do
				table.insert(names, key)
			end
			table.sort(names)
			error(`[RivueRouter] No route named '{name}'. Routes: {table.concat(names, ", ")}`, 0)
		end
		return record
	end

	local function toLocation(to: any, params: Params?): RouteLocation
		if type(to) == "string" then
			return { name = to, params = params }
		end
		assert(
			type(to) == "table" and type(to.name) == "string",
			"[RivueRouter] A location is a route name or { name, params }"
		)
		return to
	end

	local function build(location: RouteLocation, redirectedFrom: Route?): Route
		local record = findRecord(location.name)
		local matched = {}
		local node = record
		while node do
			table.insert(matched, 1, node)
			node = node.parent
		end
		local meta = {}
		for _, r in matched do
			for key, value in r.meta do
				meta[key] = value
			end
		end
		return table.freeze({
			name = record.name,
			params = table.freeze(table.clone(location.params or {})),
			query = table.freeze(table.clone(location.query or {})),
			meta = table.freeze(meta),
			matched = table.freeze(matched),
			redirectedFrom = redirectedFrom,
		}) :: any
	end

	local function resolveRedirects(location: RouteLocation): Route
		local route = build(location, nil)
		local first = route
		for _ = 1, MAX_REDIRECTS do
			local redirect = (route.matched[#route.matched] :: any).redirect
			if redirect == nil then
				return route
			end
			local target = if type(redirect) == "function" then redirect(route) else redirect
			local nextLocation = toLocation(target, nil)
			nextLocation = {
				name = nextLocation.name,
				params = nextLocation.params or route.params,
				query = nextLocation.query or route.query,
			}
			route = build(nextLocation, first)
		end
		error(`[RivueRouter] Too many redirects from '{first.name}'`, 0)
	end

	local history: { { route: Route, scroll: ScrollPositions? } } = {}
	local index = 0
	local currentRoute = Rivue.shallowRef(START_LOCATION)
	local canGoBack = Rivue.ref(false)
	local canGoForward = Rivue.ref(false)
	local beforeGuards: { Guard } = {}
	local resolveGuards: { Guard } = {}
	local afterHooks: { AfterHook } = {}
	local errorHandlers: { ErrorHandler } = {}
	local ready = false
	local readyWaiters: { thread } = {}

	local function reportError(err: unknown, to: Route, from: Route, where: string)
		if #errorHandlers == 0 then
			warn(`[RivueRouter] {where} failed: {err}`)
			return
		end
		for _, handler in table.clone(errorHandlers) do
			local ok, handlerErr = pcall(handler :: (...any) -> ...any, err, to, from)
			if not ok then
				warn(`[RivueRouter] An onError handler failed: {handlerErr}`)
			end
		end
	end
	local pending = 0
	local router: Router

	local function sync()
		currentRoute.value = history[index].route
		canGoBack.value = index > 1
		canGoForward.value = index < #history
		local devtools = Rivue._devtools
		if devtools then
			local route = history[index].route
			local names = {}
			for i, entry in history do
				names[i] = if i == index then `[{entry.route.name}]` else entry.route.name :: string
			end
			devtools.route(table.concat({
				`name = {route.name}`,
				`params = {describe(route.params)}`,
				`query = {describe(route.query)}`,
				`meta = {describe(route.meta)}`,
				`history = {table.concat(names, ", ")}`,
			}, "\n"))
		end
	end

	local function saveScroll()
		local entry = history[index]
		local getRoot = router._scrollRoot
		if not entry or not getRoot then
			return
		end
		local root = getRoot()
		local saved = {}
		for _, frame in scrollingFrames(root) do
			saved[scrollKey(frame, root :: Instance)] = frame.CanvasPosition
		end
		entry.scroll = saved
	end

	local function applyScroll(to: Route, from: Route, saved: ScrollPositions?)
		local behavior = options.scrollBehavior
		if not behavior then
			return
		end
		Rivue.nextTick(function()
			local ok, position = pcall(behavior, to, from, saved)
			if not ok then
				reportError(position, to, from, "scrollBehavior")
				return
			end
			local getRoot = router._scrollRoot
			local root = if getRoot then getRoot() else nil
			if type(position) ~= "table" or not root then
				return
			end
			local only = position.el
			for _, frame in scrollingFrames(root) do
				if type(only) == "string" and frame.Name ~= only and scrollKey(frame, root) ~= only then
					continue
				end
				if position == saved then
					local at = (saved :: ScrollPositions)[scrollKey(frame, root)]
					if at then
						frame.CanvasPosition = at
					end
				else
					frame.CanvasPosition = Vector2.new(position.left or 0, position.top or 0)
				end
			end
		end)
	end

	local function runHooks(to: Route, from: Route, result: NavigationFailure?)
		local devtools = Rivue._devtools
		if devtools then
			local outcome = "ok"
			if result then
				for kind, value in NavigationFailureType do
					if value == result.type then
						outcome = kind :: string
					end
				end
			end
			devtools.event("navigation", `{from.name or "start"} -> {to.name}`, outcome)
		end
		for _, hook in table.clone(afterHooks) do
			local ok, err = pcall(hook :: (...any) -> ...any, to, from, result)
			if not ok then
				warn(`[RivueRouter] An afterEach hook failed: {err}`)
			end
		end
	end

	local navigate: (kind: string, to: Route, target: number?, depth: number) -> NavigationFailure?

	navigate = function(kind: string, to: Route, target: number?, depth: number): NavigationFailure?
		local from = currentRoute.value
		pending += 1
		local id = pending

		local queue: { Guard } = {}
		local fromMatched, toMatched = from.matched :: { any }, to.matched :: { any }
		for i = #fromMatched, 1, -1 do
			if not table.find(toMatched, fromMatched[i]) then
				for _, guard in fromMatched[i].leaveGuards do
					table.insert(queue, guard)
				end
			end
		end
		for _, guard in beforeGuards do
			table.insert(queue, guard)
		end
		for _, record in toMatched do
			if table.find(fromMatched, record) then
				for _, guard in record.updateGuards do
					table.insert(queue, guard)
				end
			end
		end
		for _, record in toMatched do
			if not table.find(fromMatched, record) then
				for _, guard in record.beforeEnter do
					table.insert(queue, guard)
				end
			end
		end
		local function runGuards(list: { Guard }): (boolean, NavigationFailure?)
			for _, guard in list do
				local ok, result = pcall(guard, to, from)
				if pending ~= id then
					local cancelled = failure(NavigationFailureType.cancelled, to, from)
					runHooks(to, from, cancelled)
					return true, cancelled
				end
				if not ok then
					reportError(result, to, from, "A navigation guard")
					local aborted = failure(NavigationFailureType.aborted, to, from)
					runHooks(to, from, aborted)
					return true, aborted
				elseif result == false then
					local aborted = failure(NavigationFailureType.aborted, to, from)
					runHooks(to, from, aborted)
					return true, aborted
				elseif type(result) == "string" or type(result) == "table" then
					if depth >= MAX_REDIRECTS then
						error(`[RivueRouter] Navigation guards redirected more than {MAX_REDIRECTS} times`, 0)
					end
					local location = toLocation(result, nil)
					local redirected = resolveRedirects(location)
					redirected = table.freeze({
						name = redirected.name,
						params = redirected.params,
						query = redirected.query,
						meta = redirected.meta,
						matched = redirected.matched,
						redirectedFrom = to,
					}) :: any
					local nextKind = if location.replace then "replace" elseif kind == "pop" then "push" else kind
					return true, navigate(nextKind, redirected, nil, depth + 1)
				end
			end
			return false, nil
		end

		local stopped, outcome = runGuards(queue)
		if stopped then
			return outcome
		end

		for _, record in toMatched do
			local components = record.components
			if not components then
				continue
			end
			for view, component in components do
				if not isLazy(component) then
					continue
				end
				local ok, loaded = pcall(component.loader)
				if pending ~= id then
					local cancelled = failure(NavigationFailureType.cancelled, to, from)
					runHooks(to, from, cancelled)
					return cancelled
				end
				if not ok or not isComponent(loaded) then
					local err = if ok then `lazy component of '{record.name}' didn't return a component` else loaded
					reportError(err, to, from, "A lazy route component")
					local aborted = failure(NavigationFailureType.aborted, to, from)
					runHooks(to, from, aborted)
					return aborted
				end
				components[view] = loaded
			end
		end

		stopped, outcome = runGuards(resolveGuards)
		if stopped then
			return outcome
		end

		saveScroll()
		local saved: ScrollPositions? = nil
		if kind == "push" then
			for i = #history, index + 1, -1 do
				history[i] = nil
			end
			table.insert(history, { route = to })
			index = #history
		elseif kind == "replace" then
			index = math.max(index, 1)
			history[index] = { route = to }
		else
			index = target :: number
			saved = history[index].scroll
			history[index] = { route = to, scroll = saved }
		end
		sync()
		runHooks(to, from, nil)
		applyScroll(to, from, saved)
		return nil
	end

	local function start(kind: string, to: any, params: Params?): NavigationFailure?
		local location = toLocation(to, params)
		local route = resolveRedirects(location)
		local from = currentRoute.value
		if
			not location.force
			and route.name == from.name
			and sameParams(route.params, from.params)
			and sameParams(route.query, from.query)
		then
			local duplicated = failure(NavigationFailureType.duplicated, route, from)
			runHooks(route, from, duplicated)
			return duplicated
		end
		return navigate(if location.replace then "replace" else kind, route, nil, 0)
	end

	local function guardList(list: { any }, fn: any): () -> ()
		table.insert(list, fn)
		return function()
			local at = table.find(list, fn)
			if at then
				table.remove(list, at)
			end
		end
	end

	router = {
		currentRoute = currentRoute,
		current = currentRoute,
		canGoBack = canGoBack,
		canGoForward = canGoForward,
		push = function(to: string | RouteLocation, params: Params?): NavigationFailure?
			return start("push", to, params)
		end,
		replace = function(to: string | RouteLocation, params: Params?): NavigationFailure?
			return start("replace", to, params)
		end,
		go = function(delta: number): NavigationFailure?
			local target = index + delta
			local from = currentRoute.value
			if delta == 0 or target < 1 or target > #history then
				return failure(NavigationFailureType.aborted, from, from)
			end
			local entry = history[target].route
			local ok, route = pcall(
				build,
				{ name = entry.name :: string, params = entry.params, query = entry.query },
				entry.redirectedFrom
			)
			if not ok then
				warn(`[RivueRouter] {route}`)
				return failure(NavigationFailureType.aborted, from, from)
			end
			return navigate("pop", route, target, 0)
		end,
		back = function(): NavigationFailure?
			return router.go(-1)
		end,
		forward = function(): NavigationFailure?
			return router.go(1)
		end,
		resolve = function(to: string | RouteLocation, params: Params?): Route
			return build(toLocation(to, params), nil)
		end,
		beforeEach = function(guard: Guard): () -> ()
			return guardList(beforeGuards, guard)
		end,
		beforeResolve = function(guard: Guard): () -> ()
			return guardList(resolveGuards, guard)
		end,
		afterEach = function(hook: AfterHook): () -> ()
			return guardList(afterHooks, hook)
		end,
		addRoute = function(parentOrRecord: string | RouteRecord, record: RouteRecord?): () -> ()
			local parent = if type(parentOrRecord) == "string" then findRecord(parentOrRecord) else nil
			local def = if type(parentOrRecord) == "string" then record else parentOrRecord
			assert(
				type(def) == "table" and type(def.name) == "string",
				"[RivueRouter] addRoute needs a record with a name"
			)
			if records[def.name] then
				removeRecord(records[def.name])
			end
			local added = addRecord(def, nil, parent)
			return function()
				if records[added.name] == added then
					removeRecord(added)
				end
			end
		end,
		removeRoute = function(name: string)
			local record = records[name]
			if record then
				removeRecord(record)
			end
		end,
		hasRoute = function(name: string): boolean
			return records[name] ~= nil
		end,
		getRoutes = function(): { RouteRecord }
			local list = {}
			for _, record in records do
				table.insert(list, record)
			end
			table.sort(list, function(a, b)
				return a.name < b.name
			end)
			return list
		end,
		onError = function(handler: ErrorHandler): () -> ()
			return guardList(errorHandlers, handler)
		end,
		isReady = function()
			if not ready then
				table.insert(readyWaiters, coroutine.running())
				coroutine.yield()
			end
		end,
		install = function(app: any)
			app:provide(ROUTER_KEY, router)
			local backKeys = options.backKeys
			if backKeys and #backKeys > 0 and RunService:IsClient() then
				backActions += 1
				local action = `RivueRouterBack{backActions}`
				ContextActionService:BindActionAtPriority(action, function(_, state)
					if state ~= Enum.UserInputState.Begin or not canGoBack.value then
						return Enum.ContextActionResult.Pass
					end
					router.back()
					return Enum.ContextActionResult.Sink
				end, false, Enum.ContextActionPriority.High.Value, table.unpack(backKeys))
				app:onUnmount(function()
					ContextActionService:UnbindAction(action)
				end)
			end
			if index ~= 0 then
				return
			end
			task.spawn(function()
				local route = resolveRedirects({ name = options.initial, params = options.initialParams })
				navigate("replace", route, nil, 0)
				ready = true
				local waiters = readyWaiters
				readyWaiters = {}
				for _, waiter in waiters do
					task.spawn(waiter)
				end
			end)
		end,
	}
	assert(records[options.initial] or aliases[options.initial], `createRouter: no route named '{options.initial}'`)
	return router
end

local function useRouter(): Router
	local router = Rivue.inject(ROUTER_KEY) :: Router?
	if not router then
		error("[RivueRouter] useRouter() found no router: call app:use(router) before mounting", 2)
	end
	return router
end

--- The current route. Reading a field tracks it, so renders and computeds update on navigation
local function useRoute(): Route
	local router = useRouter()
	return setmetatable({}, {
		__index = function(_, key)
			return (router.currentRoute.value :: any)[key]
		end,
		__newindex = function()
			error("[RivueRouter] The route is read-only. Use router.push() or router.replace()", 2)
		end,
	}) :: any
end

local function addComponentGuard(kind: string, guard: Guard)
	local view = Rivue.inject(VIEW_KEY) :: any
	local record = if view then view.record else nil
	if not record then
		warn(`[RivueRouter] {kind}() only works in a screen shown by a RouterView, or inside one`)
		return
	end
	local list = if kind == "onBeforeRouteLeave" then record.leaveGuards else record.updateGuards
	table.insert(list, guard)
	Rivue.onUnmounted(function()
		local at = table.find(list, guard)
		if at then
			table.remove(list, at)
		end
	end)
end

local function onBeforeRouteLeave(guard: Guard)
	addComponentGuard("onBeforeRouteLeave", guard)
end

local function onBeforeRouteUpdate(guard: Guard)
	addComponentGuard("onBeforeRouteUpdate", guard)
end

local function propsFor(record: any, view: string, route: Route): { [string]: any }
	local option = record.props[view]
	if option == true then
		return table.clone(route.params)
	elseif type(option) == "function" then
		return option(route) or {}
	elseif type(option) == "table" then
		return table.clone(option)
	end
	return {}
end

local RouterView = table.freeze({
	__is_component = true,
	__name = "RouterView",
	props = {
		name = { type = "string", default = "default" },
		keepAlive = { type = "boolean" },
	},
	setup = function(props: any, ctx: any)
		local router = useRouter()
		local parent = Rivue.inject(VIEW_KEY) :: any
		local depth = if parent then parent.depth + 1 else 1
		local view = { depth = depth, record = nil :: any }
		Rivue.provide(VIEW_KEY, view)

		if depth == 1 then
			local instance = Rivue.getCurrentInstance() :: any
			router._scrollRoot = function(): Instance?
				return if instance then rootElement(instance.subTree) else nil
			end
		end

		return function(): any
			local route = router.currentRoute.value
			local at = depth
			local skipped = 0
			local record: any = nil
			for i, r in route.matched :: { any } do
				if not r.components then
					skipped += 1
				elseif i - skipped == at then
					record = r
					break
				end
			end
			view.record = record
			local component = if record then record.components[props.name] else nil
			local screen: any = nil
			if component then
				screen = h(component, propsFor(record, props.name, route))
				screen.key = record.name
			end
			if ctx.hasSlot("default") then
				local children = ctx.renderSlot("default", { Component = screen, route = route })
				for _, child in children do
					if type(child) == "table" then
						return child
					end
				end
				return nil
			end
			if screen and props.keepAlive then
				return h(Rivue.KeepAlive, nil, { screen })
			end
			return screen
		end
	end,
})

export type LinkState = {
	route: { value: Route },
	isActive: { value: boolean },
	isExactActive: { value: boolean },
	navigate: () -> NavigationFailure?,
}

local function useLink(props: any): LinkState
	local router = useRouter()
	local route = Rivue.computed(function()
		return router.resolve(props.to)
	end)
	local activeIndex = Rivue.computed(function()
		local target = route.value.matched
		local last = target[#target]
		return table.find(router.currentRoute.value.matched :: { any }, last)
	end)
	local isActive = Rivue.computed(function()
		return activeIndex.value ~= nil and includesParams(router.currentRoute.value.params, route.value.params)
	end)
	local isExactActive = Rivue.computed(function()
		local current = router.currentRoute.value
		return activeIndex.value == #current.matched and sameParams(current.params, route.value.params)
	end)
	return {
		route = route,
		isActive = isActive,
		isExactActive = isExactActive,
		navigate = function(): NavigationFailure?
			if props.replace then
				return router.replace(props.to)
			end
			return router.push(props.to)
		end,
	}
end

local RouterLink = table.freeze({
	__is_component = true,
	__name = "RouterLink",
	inheritAttrs = false,
	props = {
		to = { required = true },
		replace = { type = "boolean" },
		custom = { type = "boolean" },
		activeClass = { type = "string", default = "router-link-active" },
		exactActiveClass = { type = "string", default = "router-link-exact-active" },
	},
	setup = function(props: any, ctx: any)
		local link = useLink(props)
		return function(): any
			if props.custom then
				local children = ctx.renderSlot("default", {
					route = link.route.value,
					navigate = link.navigate,
					isActive = link.isActive.value,
					isExactActive = link.isExactActive.value,
				})
				for _, child in children do
					if type(child) == "table" then
						return child
					end
				end
				return nil
			end
			-- table.clone keeps the proxy, so writes would reach ctx.attrs
			local attrs = {}
			for key, value in ctx.attrs do
				attrs[key] = value
			end
			local classes = {}
			if attrs.class ~= nil then
				table.insert(classes, attrs.class)
			end
			if link.isActive.value then
				table.insert(classes, props.activeClass)
			end
			if link.isExactActive.value then
				table.insert(classes, props.exactActiveClass)
			end
			attrs.class = if #classes > 0 then classes else nil
			local onActivated = attrs.onActivated
			attrs.onActivated = function(...)
				if onActivated then
					onActivated(...)
				end
				link.navigate()
			end
			return h("TextButton", attrs, ctx.renderSlot("default"))
		end
	end,
})

return table.freeze({
	version = "0.3.0-beta.1",
	createRouter = createRouter,
	useRouter = useRouter,
	useRoute = useRoute,
	useLink = useLink,
	onBeforeRouteLeave = onBeforeRouteLeave,
	onBeforeRouteUpdate = onBeforeRouteUpdate,
	isNavigationFailure = isNavigationFailure,
	NavigationFailureType = NavigationFailureType,
	START_LOCATION = START_LOCATION,
	lazy = lazy,
	RouterView = RouterView,
	RouterLink = RouterLink,
})
