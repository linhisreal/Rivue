[Docs](../README.md) › [API](../API.md) › **RivueRouter**

# RivueRouter

**Learn it:** [Guide 17: Screens and navigation](../guide/17-screens-and-navigation.md)

Named screens with history, after [Vue Router 4](https://router.vuejs.org). Put `RivueRouter` next
to `RivueUI`. Examples assume `local Router = require(game.ReplicatedStorage.RivueRouter)`.

- [Router.createRouter()](#routercreaterouter)
- [Route records](#route-records)
- [router.push() and router.replace()](#routerpush-and-routerreplace)
- [router.go(), back() and forward()](#routergo-back-and-forward)
- [Navigation guards](#navigation-guards)
- [onBeforeRouteLeave() and onBeforeRouteUpdate()](#onbeforerouteleave-and-onbeforerouteupdate)
- [Dynamic routes](#dynamic-routes)
- [scrollBehavior](#scrollbehavior)
- [Router.RouterView](#routerrouterview)
- [Router.RouterLink](#routerrouterlink)
- [Router.useRouter() and Router.useRoute()](#routeruserouter-and-routeruseroute)
- [Router.useLink()](#routeruselink)
- [Router.lazy()](#routerlazy)
- [router.isReady() and router.onError()](#routerisready-and-routeronerror)
- [Navigation failures](#navigation-failures)
- [Differences from Vue Router](#differences-from-vue-router)

---

## Router.createRouter()

Creates the router. Install it with `app:use(router)` before mounting.

- **Example**

  ```lua
  local function Screen(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local router = Router.createRouter({
  	routes = { home = Screen("Home"), item = Screen("Item") },
  	initial = "home",
  	backKeys = { Enum.KeyCode.ButtonB },
  })

  local app = Rivue.createApp(Router.RouterView)
  app:use(router)
  app:mount(Instance.new("Folder"))
  ```

- **Details**

  - `routes` maps names to components or [records](#route-records), or is a list of named records.
  - `initial` (with `initialParams`) is the first screen. It goes through the guards like any
    navigation; until then `currentRoute` is `Router.START_LOCATION`.
  - `currentRoute`, `canGoBack` and `canGoForward` are refs.
  - `backKeys` call `back()` while there's history and pass through otherwise.

- **Type**

  ```lua
  function createRouter(options: {
  	routes: { [string]: ComponentDef | RouteRecord } | { RouteRecord },
  	initial: string,
  	initialParams: { [string]: any }?,
  	scrollBehavior: ScrollBehavior?,
  	backKeys: { Enum.KeyCode }?,
  }): Router

  type Route = {
  	name: string?,
  	params: { [string]: any },
  	query: { [string]: any },
  	meta: { [string]: any },
  	matched: { RouteRecord },
  	redirectedFrom: Route?,
  }
  ```

---

## Route records

A route is a component or a record.

- **Example**

  ```lua
  local function Screen(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local isStaff = false

  local router = Router.createRouter({
  	routes = {
  		lobby = Screen("Lobby"),
  		shop = {
  			component = Screen("Shop"),
  			alias = "store",
  			redirect = "weapons",
  			meta = { music = "shop" },
  			children = { weapons = Screen("Weapons"), pets = Screen("Pets") },
  		},
  		admin = {
  			component = Screen("Admin"),
  			beforeEnter = function()
  				return isStaff
  			end,
  		},
  	},
  	initial = "lobby",
  })
  ```

- **Fields**

  | Field | |
  |---|---|
  | `component` | the screen, or a [`Router.lazy()`](#routerlazy) loader |
  | `components` | screens by view name, for [named views](#routerrouterview) |
  | `children` | child routes, shown by a `RouterView` inside the screen |
  | `meta` | merged with the parents' meta into `route.meta` |
  | `redirect` | a name, a location or `function(to)`; followed before guards |
  | `alias` | other names for this route |
  | `props` | `true` (default) passes params, `false` passes none, a table as is, or `function(route)` |
  | `beforeEnter` | guards run when entering from a different route |

  Names, child names and aliases share one namespace. With `components`, `props` is per view.

- **Type**

  ```lua
  type RouteRecord = {
  	name: string?,
  	component: ComponentDef?,
  	components: { [string]: ComponentDef }?,
  	children: { [string]: ComponentDef | RouteRecord } | { RouteRecord }?,
  	meta: { [string]: any }?,
  	redirect: string | RouteLocation | ((to: Route) -> string | RouteLocation)?,
  	alias: string | { string }?,
  	props: boolean | { [string]: any } | ((route: Route) -> { [string]: any })?,
  	beforeEnter: Guard | { Guard }?,
  }
  ```

---

## router.push() and router.replace()

`push` adds a history entry; `replace` swaps the current one. Both return `nil` or a
[failure](#navigation-failures), and yield while a guard yields.

- **Example**

  ```lua
  local function Screen(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local router = Router.createRouter({
  	routes = { loading = Screen("Loading"), lobby = Screen("Lobby"), item = Screen("Item") },
  	initial = "loading",
  })
  local app = Rivue.createApp(Router.RouterView)
  app:use(router)
  app:mount(Instance.new("Folder"))

  router.replace("lobby")
  router.push("item", { id = 7 })
  router.push({ name = "item", params = { id = 8 }, query = { tab = "stats" } })
  ```

- **Details**

  - `query` doesn't affect matching or `RouterLink` active classes. Redirects keep it.
  - The same route, params and query again returns `duplicated`; pass `force = true` to push
    anyway.
  - An unknown name errors.

- **Type**

  ```lua
  type RouteLocation = {
  	name: string,
  	params: { [string]: any }?,
  	query: { [string]: any }?,
  	replace: boolean?,
  	force: boolean?,
  }

  push: (to: string | RouteLocation, params: { [string]: any }?) -> NavigationFailure?
  replace: (to: string | RouteLocation, params: { [string]: any }?) -> NavigationFailure?
  ```

---

## router.go(), back() and forward()

Moves through history. Guards run as for `push`. Going past either end returns `aborted`.

- **Example**

  ```lua
  local function Screen(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local router = Router.createRouter({
  	routes = { lobby = Screen("Lobby"), shop = Screen("Shop") },
  	initial = "lobby",
  })
  local app = Rivue.createApp(Router.RouterView)
  app:use(router)
  app:mount(Instance.new("Folder"))

  router.push("shop")
  router.back()
  ```

- **Type**

  ```lua
  go: (delta: number) -> NavigationFailure?
  back: () -> NavigationFailure?
  forward: () -> NavigationFailure?
  ```

---

## Navigation guards

- **Example**

  ```lua
  local function Screen(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local dataLoaded = false
  local router = Router.createRouter({
  	routes = { lobby = Screen("Lobby"), shop = Screen("Shop"), loading = Screen("Loading") },
  	initial = "lobby",
  })

  router.beforeEach(function(to)
  	if to.name == "shop" and not dataLoaded then
  		return { name = "loading", replace = true }
  	end
  	return true
  end)
  ```

- **Details**

  - Return `nil`/`true` to continue, `false` to abort, or a name or location to redirect.
  - Guards can yield. A newer navigation cancels a waiting one with `cancelled`.
  - An error cancels the navigation and goes to [`onError`](#routerisready-and-routeronerror).
  - Order: `onBeforeRouteLeave` → `beforeEach` → `onBeforeRouteUpdate` → `beforeEnter` →
    `beforeResolve` → route changes → `afterEach(to, from, failure)`.
  - Each registration returns a remover.

- **Type**

  ```lua
  type Guard = (to: Route, from: Route) -> boolean | string | RouteLocation | nil

  beforeEach: (guard: Guard) -> () -> ()
  beforeResolve: (guard: Guard) -> () -> ()
  afterEach: (hook: (to: Route, from: Route, failure: NavigationFailure?) -> ()) -> () -> ()
  ```

---

## onBeforeRouteLeave() and onBeforeRouteUpdate()

Component guards, called in `setup()` of a screen or anything inside it. Removed on unmount.

- **Example**

  ```lua
  local Settings = Rivue.defineComponent({
  	name = "Settings",
  	setup = function()
  		local dirty = Rivue.ref(false)
  		Router.onBeforeRouteLeave(function()
  			return not dirty.value
  		end)
  		return { dirty = dirty }
  	end,
  	render = function()
  		return h("Frame")
  	end,
  })
  ```

- **Details**

  - `onBeforeRouteLeave` runs when leaving this screen's route.
  - `onBeforeRouteUpdate` runs when the route changes but the screen stays (new params, or a child
    route).
  - Outside a routed screen they warn and do nothing.

- **Type**

  ```lua
  function onBeforeRouteLeave(guard: Guard)
  function onBeforeRouteUpdate(guard: Guard)
  ```

---

## Dynamic routes

- **Example**

  ```lua
  local function Screen(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local router = Router.createRouter({ routes = { lobby = Screen("Lobby") }, initial = "lobby" })

  local removeEvent = router.addRoute({ name = "event", component = Screen("Event") })
  print(router.hasRoute("event")) --> true
  removeEvent()
  ```

- **Details**

  - `addRoute(record)` or `addRoute(parentName, record)` returns a remover. An existing name is
    replaced.
  - `removeRoute(name)` removes the route and its children.
  - `resolve(to, params)` returns the route without navigating, and doesn't follow `redirect`.

- **Type**

  ```lua
  addRoute: (parentOrRecord: string | RouteRecord, record: RouteRecord?) -> () -> ()
  removeRoute: (name: string) -> ()
  hasRoute: (name: string) -> boolean
  getRoutes: () -> { RouteRecord }
  resolve: (to: string | RouteLocation, params: { [string]: any }?) -> Route
  ```

---

## scrollBehavior

Where ScrollingFrames scroll after a navigation. Runs after the new screen renders.

- **Example**

  ```lua
  local router = Router.createRouter({
  	routes = {
  		shop = Rivue.defineComponent({
  			name = "Shop",
  			render = function()
  				return h("ScrollingFrame")
  			end,
  		}),
  	},
  	initial = "shop",
  	scrollBehavior = function(_to, _from, savedPosition)
  		return savedPosition or { top = 0 }
  	end,
  })
  ```

- **Details**

  - `savedPosition` is set for `back`, `forward` and `go`: each frame's `CanvasPosition` by name.
  - Return `{ top, left }` for every frame, add `el = "Panel/List"` for one, or `nil` to leave them.
  - Only the top-level `RouterView` is scrolled.

- **Type**

  ```lua
  type ScrollBehavior = (
  	to: Route,
  	from: Route,
  	savedPosition: { [string]: Vector2 }?
  ) -> { [string]: Vector2 } | { el: string?, top: number?, left: number? } | nil
  ```

---

## Router.RouterView

Renders the current route's screen. Nested, it renders the child route.

- **Example**

  ```lua
  local Layout = Rivue.defineComponent({
  	name = "Layout",
  	render = function()
  		return h(Router.RouterView, nil, {
  			default = function(view)
  				return h(Rivue.Transition, Rivue.transitions.fade({ mode = "out-in" }), { view.Component })
  			end,
  		})
  	end,
  })
  ```

- **Details**

  - The `default` slot gets `{ Component, route }` and renders instead of the view.
  - `keepAlive = true` wraps the screen in [KeepAlive](builtins.md#keepalive).
  - `name` picks a named view.
  - Each route gets its own instance; the same route with new params keeps it.

- **Props**

  ```lua
  type RouterViewProps = {
  	name: string?, -- default "default"
  	keepAlive: boolean?,
  }
  ```

---

## Router.RouterLink

A TextButton that navigates, with style classes while its route is active.

- **Example**

  ```lua
  local Tabs = Rivue.defineComponent({
  	name = "Tabs",
  	render = function()
  		return h(Rivue.Row, { gap = 8 }, {
  			h(Router.RouterLink, { to = "weapons", Text = "Weapons" }),
  			h(Router.RouterLink, { to = "pets", Text = "Pets" }),
  		})
  	end,
  })
  ```

- **Details**

  - Other props go to the TextButton. Your `onActivated` runs before navigating.
  - `router-link-active` applies on the route or its children, `router-link-exact-active` on the
    exact route and params. They win over the link's own `class`.
  - `custom = true` renders the default slot with `{ route, navigate, isActive, isExactActive }`.

- **Props**

  ```lua
  type RouterLinkProps = {
  	to: string | RouteLocation,
  	replace: boolean?,
  	custom: boolean?,
  	activeClass: string?, -- default "router-link-active"
  	exactActiveClass: string?, -- default "router-link-exact-active"
  }
  ```

---

## Router.useRouter() and Router.useRoute()

Call in `setup()`. `useRoute()` is a read-only, reactive view of the current route.
`useRouter()` errors if no router is installed.

- **Example**

  ```lua
  local ItemTitle = Rivue.defineComponent({
  	name = "ItemTitle",
  	setup = function()
  		local route = Router.useRoute()
  		return {
  			title = Rivue.computed(function()
  				return `Item {route.params.id}`
  			end),
  		}
  	end,
  	render = function(ctx)
  		return h("TextLabel", { Text = ctx.title })
  	end,
  })
  ```

- **Type**

  ```lua
  function useRouter(): Router
  function useRoute(): Route
  ```

---

## Router.useLink()

`RouterLink`'s logic, for your own link components.

- **Example**

  ```lua
  local IconLink = Rivue.defineComponent({
  	name = "IconLink",
  	props = { to = { required = true } },
  	setup = function(props)
  		local link = Router.useLink(props)
  		return { isActive = link.isActive, navigate = link.navigate }
  	end,
  	render = function(ctx)
  		return h("ImageButton", {
  			ImageTransparency = if ctx.isActive then 0 else 0.5,
  			onActivated = function()
  				ctx.navigate()
  			end,
  		})
  	end,
  })
  ```

- **Type**

  ```lua
  function useLink(props: { to: string | RouteLocation, replace: boolean? }): {
  	route: Ref<Route>,
  	isActive: Ref<boolean>,
  	isExactActive: Ref<boolean>,
  	navigate: () -> NavigationFailure?,
  }
  ```

---

## Router.lazy()

Loads a route's component on first visit.

- **Example**

  ```lua
  local router = Router.createRouter({
  	routes = {
  		lobby = Rivue.defineComponent({
  			name = "Lobby",
  			render = function()
  				return h("TextLabel", { Text = "Lobby" })
  			end,
  		}),
  		settings = Router.lazy(function()
  			return Rivue.defineComponent({
  				name = "Settings",
  				render = function()
  					return h("TextLabel", { Text = "Settings" })
  				end,
  			})
  		end),
  	},
  	initial = "lobby",
  })
  ```

- **Details**

  - Usually `Router.lazy(function() return require(script.Parent.Settings) end)`.
  - Runs once, after `beforeEnter` and before `beforeResolve`. An error or non-component aborts
    the navigation and goes to `onError`.
  - The wrapper is needed because plain functions are function components.

- **Type**

  ```lua
  function lazy(loader: () -> ComponentDef): LazyComponent
  ```

---

## router.isReady() and router.onError()

`isReady()` yields until the first navigation finishes. `onError()` gets errors from guards,
loaders and `scrollBehavior`, and returns a remover. Without handlers they're warned.

- **Example**

  ```lua
  local router = Router.createRouter({
  	routes = {
  		lobby = Rivue.defineComponent({
  			name = "Lobby",
  			render = function()
  				return h("TextLabel", { Text = "Lobby" })
  			end,
  		}),
  	},
  	initial = "lobby",
  })

  router.onError(function(err, to)
  	warn("navigation to", to.name, "failed:", err)
  end)

  local app = Rivue.createApp(Router.RouterView)
  app:use(router)
  app:mount(Instance.new("Folder"))
  router.isReady()
  ```

- **Details**

  A guard waiting on the first navigation doesn't hold up `app:mount()`; the `RouterView` stays
  empty until it passes.

- **Type**

  ```lua
  isReady: () -> ()
  onError: (handler: (err: unknown, to: Route, from: Route) -> ()) -> () -> ()
  ```

---

## Navigation failures

- **Example**

  ```lua
  local function open(router, name: string)
  	local failure = router.push(name)
  	if Router.isNavigationFailure(failure, Router.NavigationFailureType.aborted) then
  		print("a guard said no")
  	end
  end
  ```

- **Types**

  | Type | When |
  |---|---|
  | `aborted` | a guard returned `false` or errored, or `go` had nowhere to go |
  | `cancelled` | a newer navigation started while a guard waited |
  | `duplicated` | already on that route with the same params and query |

  Combine types with `bit32.bor`.

- **Type**

  ```lua
  type NavigationFailure = { type: number, to: Route, from: Route }

  NavigationFailureType: { aborted: number, cancelled: number, duplicated: number }
  function isNavigationFailure(value: any, type: number?): boolean
  START_LOCATION: Route
  ```

---

## Differences from Vue Router

- Named routes only, no paths or history modes. `initial` replaces the start URL, and `query` is a
  table.
- `Router.lazy()` around `require` instead of `import()`.
- `props` defaults to `true`.
- Guards and `push` yield instead of returning Promises. No `next()`.
- `back`, `forward` and `go` return a failure like `push`.
- `scrollBehavior` works on ScrollingFrames.
- `RouterLink` is a TextButton, and its active state is a style class.

---

[← RivueRemote](remote.md) · [API reference](../API.md) · [Instance pool →](pool.md)
