--!strict
--!optimize 2

-- Screen navigation, like a small Vue Router: named routes, params passed as props, and a history
-- you can go back and forward in. No URLs, since Roblox UI has none

local Types = require("./types")
local reactivity = require("./reactivity")
local componentAPI = require("./component")
local builtins = require("./builtins")
local hModule = require("./h")

type ComponentDef = Types.ComponentDef
type Ref<T> = Types.Ref<T>

export type Route = {
	name: string,
	params: { [string]: any },
}

export type RouterOptions = {
	routes: { [string]: ComponentDef },
	initial: string,
	initialParams: { [string]: any }?,
}

export type Guard = (to: Route, from: Route) -> boolean?

export type Router = {
	current: Ref<Route>,
	canGoBack: Ref<boolean>,
	canGoForward: Ref<boolean>,
	push: (name: string, params: { [string]: any }?) -> boolean,
	replace: (name: string, params: { [string]: any }?) -> boolean,
	back: () -> boolean,
	forward: () -> boolean,
	beforeEach: (guard: Guard) -> () -> (),
	install: (app: any) -> (),
	routes: { [string]: ComponentDef },
}

local INJECTION_KEY = "router"

local function createRouter(options: RouterOptions): Router
	assert(type(options) == "table" and type(options.routes) == "table", "createRouter expects { routes, initial }")
	local routes = options.routes
	assert(routes[options.initial], `createRouter: no route named '{options.initial}'`)

	local history: { Route } = { { name = options.initial, params = options.initialParams or {} } }
	local index = 1
	local current = reactivity.shallowRef(history[1])
	local canGoBack = reactivity.ref(false)
	local canGoForward = reactivity.ref(false)
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
				warn(`[Rivue] A router guard failed: {result}`)
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
			error(`[Rivue] No route named '{name}'. Routes: {table.concat(names, ", ")}`, 3)
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
	local router = componentAPI.inject(INJECTION_KEY) :: Router?
	if not router then
		error("[Rivue] useRouter() found no router: call app:use(router) before mounting", 2)
	end
	return router
end

--- Renders the current route's component, with the route's params as its props
local RouterView: ComponentDef = {
	__is_component = true :: true,
	__name = "RouterView",
	props = {
		-- Keep screens you've left alive, so coming back keeps their state (see KeepAlive)
		keepAlive = { type = "boolean" :: "boolean" },
	},
	setup = function(props: Types.Props)
		local router = useRouter()
		return function(): Types.VNode?
			local route = router.current.value
			local screen = hModule.h(router.routes[route.name] :: ComponentDef, table.clone(route.params))
			-- Keyed by route name, so two routes sharing a component still get separate instances
			screen.key = route.name
			if props.keepAlive then
				return hModule.h(builtins.KeepAlive :: ComponentDef, nil, { screen })
			end
			return screen
		end
	end,
} :: any

return {
	createRouter = createRouter,
	useRouter = useRouter,
	RouterView = RouterView,
}
