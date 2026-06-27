--!strict
--!optimize 2

-- RivueRouter: screen navigation for Rivue, like a small Vue Router. Named routes, params passed
-- as props, and a history you can go back and forward in. No URLs, since Roblox UI has none.
--
-- It uses the Rivue your game already requires, the way Vue Router uses your Vue: two copies would
-- track state separately and the router's components couldn't see the app's

-- Something else in the game may also be called Rivue, so check it really is
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
	-- Wally and pesde put Rivue in the same Packages folder as the router, a few levels up from the
	-- installed copy. A manual install keeps both in ReplicatedStorage
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

export type Route = {
	name: string,
	params: { [string]: any },
}

export type RouterOptions = {
	routes: { [string]: any },
	initial: string,
	initialParams: { [string]: any }?,
}

export type Guard = (to: Route, from: Route) -> boolean?

export type Router = {
	current: { value: Route },
	canGoBack: { value: boolean },
	canGoForward: { value: boolean },
	push: (name: string, params: { [string]: any }?) -> boolean,
	replace: (name: string, params: { [string]: any }?) -> boolean,
	back: () -> boolean,
	forward: () -> boolean,
	beforeEach: (guard: Guard) -> () -> (),
	install: (app: any) -> (),
	routes: { [string]: any },
}

local INJECTION_KEY = "router"

local function createRouter(options: RouterOptions): Router
	assert(type(options) == "table" and type(options.routes) == "table", "createRouter expects { routes, initial }")
	local routes = options.routes
	assert(routes[options.initial], `createRouter: no route named '{options.initial}'`)

	local history: { Route } = { { name = options.initial, params = options.initialParams or {} } }
	local index = 1
	local current = Rivue.shallowRef(history[1])
	local canGoBack = Rivue.ref(false)
	local canGoForward = Rivue.ref(false)
	local guards: { Guard } = {}

	local function sync()
		current.value = history[index]
		canGoBack.value = index > 1
		canGoForward.value = index < #history
	end

	-- Any guard returning false cancels the navigation (an unsaved-changes prompt, say)
	local function allowed(to: Route): boolean
		local from = history[index]
		for _, guard in table.clone(guards) do
			local ok, result = pcall(guard, to, from)
			if not ok then
				warn(`[RivueRouter] A guard failed: {result}`)
				return false
			elseif result == false then
				return false
			end
		end
		return true
	end

	local function resolve(name: string, params: { [string]: any }?): Route
		if not routes[name] then
			local names = {}
			for key in routes do
				table.insert(names, key)
			end
			table.sort(names)
			error(`[RivueRouter] No route named '{name}'. Routes: {table.concat(names, ", ")}`, 3)
		end
		return { name = name, params = params or {} }
	end

	local router: Router
	router = {
		current = current,
		canGoBack = canGoBack,
		canGoForward = canGoForward,
		routes = routes,
		push = function(name: string, params: { [string]: any }?): boolean
			local to = resolve(name, params)
			if not allowed(to) then
				return false
			end
			-- A new page drops anything you could have gone forward to, like a browser
			for i = #history, index + 1, -1 do
				history[i] = nil
			end
			table.insert(history, to)
			index = #history
			sync()
			return true
		end,
		replace = function(name: string, params: { [string]: any }?): boolean
			local to = resolve(name, params)
			if not allowed(to) then
				return false
			end
			history[index] = to
			sync()
			return true
		end,
		back = function(): boolean
			if index <= 1 or not allowed(history[index - 1]) then
				return false
			end
			index -= 1
			sync()
			return true
		end,
		forward = function(): boolean
			if index >= #history or not allowed(history[index + 1]) then
				return false
			end
			index += 1
			sync()
			return true
		end,
		beforeEach = function(guard: Guard): () -> ()
			table.insert(guards, guard)
			return function()
				local at = table.find(guards, guard)
				if at then
					table.remove(guards, at)
				end
			end
		end,
		install = function(app: any)
			app:provide(INJECTION_KEY, router)
		end,
	}
	return router
end

--- The router installed with app:use(router)
local function useRouter(): Router
	local router = Rivue.inject(INJECTION_KEY) :: Router?
	if not router then
		error("[RivueRouter] useRouter() found no router: call app:use(router) before mounting", 2)
	end
	return router
end

--- Renders the current route's component, with the route's params as its props
local RouterView = table.freeze({
	__is_component = true,
	__name = "RouterView",
	props = {
		-- Keep screens you've left alive, so coming back keeps their state (see KeepAlive)
		keepAlive = { type = "boolean" },
	},
	setup = function(props: any)
		local router = useRouter()
		return function(): any
			local route = router.current.value
			local screen = h(router.routes[route.name], table.clone(route.params))
			-- Keyed by route name, so two routes sharing a component still get separate instances
			screen.key = route.name
			if props.keepAlive then
				return h(Rivue.KeepAlive, nil, { screen })
			end
			return screen
		end
	end,
})

return table.freeze({
	-- Set by `lune run version rivue-router <version>`
	version = "0.1.0-beta.1",
	createRouter = createRouter,
	useRouter = useRouter,
	RouterView = RouterView,
})
