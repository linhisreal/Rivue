[Docs](../README.md) › [API](../API.md) › **RivueRouter**

# RivueRouter

**Learn it:** [Guide 17: Screens and navigation](../guide/17-screens-and-navigation.md)

Screens with history, modelled on [Vue Router 4](https://router.vuejs.org). It's a separate
package, the way Vue Router is separate from Vue: install `RivueRouter` next to `RivueUI`, in the
same Packages folder or both in ReplicatedStorage. It uses the Rivue your game already requires.
All examples assume `local Router = require(game.ReplicatedStorage.RivueRouter)`.

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

  A menu that opens an item screen and comes back:

  ```lua
  local Home = Rivue.defineComponent({
  	name = "Home",
  	setup = function()
  		local router = Router.useRouter()
  		return {
  			open = function()
  				router.push("item", { id = 7 })
  			end,
  		}
  	end,
  	render = function(ctx)
  		return h("TextButton", { Text = "Open item 7", onActivated = ctx.open })
  	end,
  })

  local Item = Rivue.defineComponent({
  	name = "Item",
  	props = { id = { type = "number", required = true } },
  	setup = function()
  		local router = Router.useRouter()
  		return { back = router.back }
  	end,
  	render = function(ctx)
  		return h("TextButton", { Text = `Item {ctx.id}, tap to go back`, onActivated = ctx.back })
  	end,
  })

  local router = Router.createRouter({
  	routes = { home = Home, item = Item },
  	initial = "home",
  })

  local App = Rivue.defineComponent({
  	name = "App",
  	render = function()
  		return h("ScreenGui", { ResetOnSpawn = false }, { h(Router.RouterView) })
  	end,
  })

  local app = Rivue.createApp(App)
  app:use(router)
  app:mount(Instance.new("Folder"))
  ```

- **Details**

  - `routes` maps names to components or [route records](#route-records). A list of records
    with a `name` each works too, as in Vue Router.
  - `initial` is the first screen, with `initialParams` as its params. `app:use(router)` starts
    navigating to it, through `beforeEach` like any other navigation. Until it arrives,
    `currentRoute` is `Router.START_LOCATION`; [`isReady()`](#routerisready-and-routeronerror)
    waits for it.
  - `currentRoute` is a ref holding the current route: `{ name, params, query, meta, matched,
    redirectedFrom }`. `current` is the same ref under its old name.
  - `canGoBack` and `canGoForward` are refs, for greying out buttons.
  - `backKeys` lists keys that go back, like `{ Enum.KeyCode.ButtonB }` for a gamepad. They call
    `back()` while there's history and are passed on to the game otherwise. They're unbound when
    the app unmounts.

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

A route can be a bare component, or a record with more options.

- **Example**

  A shop with tabs as child routes, an old name kept as an alias, and a screen only staff can open:

  ```lua
  local Screen = function(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local Shop = Rivue.defineComponent({
  	name = "Shop",
  	render = function()
  		return h("Frame", { Size = UDim2.fromScale(1, 1) }, { h(Router.RouterView) })
  	end,
  })

  local isStaff = false

  local router = Router.createRouter({
  	routes = {
  		lobby = Screen("Lobby"),
  		shop = {
  			component = Shop,
  			alias = "store",
  			redirect = "weapons", -- opening the shop opens its first tab
  			meta = { music = "shop" },
  			children = {
  				weapons = Screen("Weapons"),
  				pets = Screen("Pets"),
  			},
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

- **Details**

  | Field | What it does |
  |---|---|
  | `component` | what `RouterView` shows for this route, or a [`Router.lazy()`](#routerlazy) loader |
  | `components` | several components by view name, for [named views](#routerrouterview) |
  | `children` | child routes, shown by a `RouterView` inside this route's component |
  | `meta` | anything you like; `route.meta` merges the meta of the route and its parents |
  | `redirect` | a route name, a location, or `function(to)` returning one; followed before any guard runs |
  | `alias` | another name, or a list of names, that opens this route |
  | `props` | how params become props, see below |
  | `beforeEnter` | a guard, or a list of them, that runs only when entering this route from a different one |

  `props` decides the component's props:

  - `true` (the default) passes the route's params.
  - `false` passes none. Read them with `useRoute()` instead.
  - A table is passed as is.
  - A function gets the route and returns the props.

  With `components`, `props` is per view: `props = { default = true, side = false }`.

  Route names, child names and aliases all share one namespace, so each has to be unique.

- **Type**

  ```lua
  type RouteRecord = {
  	name: string?, -- needed in the list form and for addRoute
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

`push` opens a route and adds it to the history. `replace` swaps the current entry, so `back`
skips it.

- **Example**

  ```lua
  local Screen = function(name: string)
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

  router.replace("lobby") -- back() won't return to the loading screen
  router.push("item", { id = 7 })
  router.push({ name = "item", params = { id = 8 } }) -- the same, as a location table
  router.push({ name = "item", params = { id = 8 }, query = { tab = "stats" } })

  local failure = router.push("item", { id = 8 })
  print(Router.isNavigationFailure(failure, Router.NavigationFailureType.duplicated)) --> true
  ```

- **Details**

  - Both take a route name and params, or a location table `{ name, params, query, replace,
    force }`.
  - `query` is extra data for the screen, like the open tab, as in Vue Router. It doesn't decide
    which route matches, and `RouterLink`'s active classes ignore it. A redirect keeps it unless
    the redirect gives its own.
  - They return `nil` when the route changed, or a [navigation failure](#navigation-failures)
    when it didn't.
  - Pushing the route you're already on, with the same params and query, does nothing and returns
    a `duplicated` failure, as in Vue Router. Pass `force = true` to push it anyway.
  - Pushing after going back drops the entries you could have gone forward to.
  - If a guard [yields](#navigation-guards), `push` and `replace` yield with it.
  - An unknown route name errors and lists the routes there are.

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

Moves through the history. `back()` is `go(-1)` and `forward()` is `go(1)`.

- **Example**

  ```lua
  local Screen = function(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local router = Router.createRouter({
  	routes = { lobby = Screen("Lobby"), shop = Screen("Shop"), item = Screen("Item") },
  	initial = "lobby",
  })
  local app = Rivue.createApp(Router.RouterView)
  app:use(router)
  app:mount(Instance.new("Folder"))

  router.push("shop")
  router.push("item")
  router.go(-2) -- straight back to the lobby
  print(router.currentRoute.value.name) --> lobby
  ```

- **Details**

  Guards run as for `push`. Going past either end of the history does nothing and returns an
  `aborted` failure. If a guard redirects during `back()`, the redirect is pushed.

- **Type**

  ```lua
  go: (delta: number) -> NavigationFailure?
  back: () -> NavigationFailure?
  forward: () -> NavigationFailure?
  ```

---

## Navigation guards

Functions that run before or after every navigation, `back` and `forward` included.

- **Example**

  Keep players out of the shop until their data has loaded, and play each screen's music:

  ```lua
  local Screen = function(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local dataLoaded = false

  local router = Router.createRouter({
  	routes = {
  		lobby = { component = Screen("Lobby"), meta = { music = "calm" } },
  		shop = { component = Screen("Shop"), meta = { music = "shop" } },
  		loading = Screen("Loading"),
  	},
  	initial = "lobby",
  })

  router.beforeEach(function(to)
  	if to.name == "shop" and not dataLoaded then
  		return { name = "loading", replace = true }
  	end
  	return true
  end)

  router.afterEach(function(to, _from, failure)
  	if not failure then
  		print("now playing", to.meta.music)
  	end
  end)
  ```

- **Details**

  A guard gets `(to, from)` and returns:

  | Return | Means |
  |---|---|
  | `nil` or `true` | go ahead |
  | `false` | cancel: the navigation fails with `aborted` |
  | a route name or a location | redirect there instead |

  A guard can yield, for example until the player answers a confirm dialog, and navigation waits
  for it. Vue Router does the same with guards that return a Promise. If another navigation
  starts while one waits, the waiting one fails with `cancelled`.

  A guard that errors cancels the navigation. The error goes to
  [`onError`](#routerisready-and-routeronerror) handlers, or is logged as a warning if there are
  none.

  Guards run in Vue Router's order:

  1. `onBeforeRouteLeave` in the screens being left
  2. `router.beforeEach`
  3. `onBeforeRouteUpdate` in the screens that stay
  4. `beforeEnter` of the routes being entered
  5. `router.beforeResolve`
  6. the route changes
  7. `router.afterEach(to, from, failure)`, which also runs for failed navigations

  Each `router.beforeEach`, `beforeResolve` and `afterEach` call returns a function that removes
  the guard.

- **Type**

  ```lua
  type Guard = (to: Route, from: Route) -> boolean | string | RouteLocation | nil

  beforeEach: (guard: Guard) -> () -> ()
  beforeResolve: (guard: Guard) -> () -> ()
  afterEach: (hook: (to: Route, from: Route, failure: NavigationFailure?) -> ()) -> () -> ()
  ```

---

## onBeforeRouteLeave() and onBeforeRouteUpdate()

Guards that belong to a component. Call them in `setup()` of a screen, or of any component inside
one. They're removed when the component unmounts.

- **Example**

  A screen that asks before the player leaves with unsaved changes. The guard yields until the
  player answers:

  ```lua
  local Settings = Rivue.defineComponent({
  	name = "Settings",
  	setup = function()
  		local dirty = Rivue.ref(false)
  		local asking = Rivue.ref(false)
  		local answer = Instance.new("BindableEvent")
  		Rivue.onUnmounted(function()
  			answer:Destroy()
  		end)

  		Router.onBeforeRouteLeave(function()
  			if not dirty.value then
  				return true
  			end
  			asking.value = true
  			local leave = answer.Event:Wait()
  			asking.value = false
  			return leave
  		end)

  		return {
  			asking = asking,
  			change = function()
  				dirty.value = true
  			end,
  			stay = function()
  				answer:Fire(false)
  			end,
  			leave = function()
  				answer:Fire(true)
  			end,
  		}
  	end,
  	render = function(ctx)
  		return h("Frame", { Size = UDim2.fromScale(1, 1) }, {
  			h("TextButton", { Text = "Music: on", onActivated = ctx.change }),
  			h(Rivue.Dialog, { open = ctx.asking, onClose = ctx.stay }, {
  				h(Rivue.Row, { gap = 8 }, {
  					h("TextButton", { Text = "Stay", onActivated = ctx.stay }),
  					h("TextButton", { Text = "Leave", onActivated = ctx.leave }),
  				}),
  			}),
  		})
  	end,
  })
  ```

- **Details**

  - `onBeforeRouteLeave` runs when the navigation leaves the route this component was shown for.
  - `onBeforeRouteUpdate` runs when the route changes but this screen stays, for example when
    only the params change, or a child route changes under it.
  - Outside a screen shown by a `RouterView`, they warn and do nothing.

- **Type**

  ```lua
  function onBeforeRouteLeave(guard: Guard)
  function onBeforeRouteUpdate(guard: Guard)
  ```

---

## Dynamic routes

Add and remove routes while the game runs, for example an event screen that only exists while the
event is live.

- **Example**

  ```lua
  local EventScreen = Rivue.defineComponent({
  	name = "EventScreen",
  	render = function()
  		return h("TextLabel", { Text = "Winter event" })
  	end,
  })

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

  local removeEvent = router.addRoute({ name = "event", component = EventScreen })
  print(router.hasRoute("event")) --> true
  print(router.resolve("event").name) --> event
  removeEvent()
  print(router.hasRoute("event")) --> false
  ```

- **Details**

  - `addRoute(record)` adds a top-level route. `addRoute(parentName, record)` adds a child. Both
    return a function that removes it. Adding a name that exists replaces that route.
  - `removeRoute(name)` removes a route and its children.
  - `hasRoute(name)` and `getRoutes()` tell you what's there.
  - `resolve(to, params)` returns the route for a location without going there. As in Vue
    Router, it doesn't follow `redirect`.

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

Decides where ScrollingFrames scroll to after a navigation, like Vue Router's `scrollBehavior`.

- **Example**

  Back and forward put each list where the player left it; a new screen starts at the top:

  ```lua
  local router = Router.createRouter({
  	routes = {
  		shop = Rivue.defineComponent({
  			name = "Shop",
  			render = function()
  				return h("ScrollingFrame", { CanvasSize = UDim2.fromOffset(0, 2000) })
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

  - It runs after the new screen has rendered.
  - `savedPosition` is set for `back`, `forward` and `go`: the `CanvasPosition` of every
    ScrollingFrame in the screen, saved when the player left it. Return it to restore them.
    Frames are matched by their names inside the screen.
  - Return `{ top, left }` to scroll every ScrollingFrame in the screen there, or `nil` to leave
    them alone. Add `el = "Name"` to scroll only the frame with that name, or that path inside the
    screen such as `"Panel/List"`.
  - Only the top-level `RouterView` is scrolled. Screens kept alive with `keepAlive` keep their
    scroll position anyway.

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

Renders the current route's component, with props from the route. Put it where screens should
appear. A `RouterView` inside a screen shows that route's child route.

- **Example**

  Fade between screens, the way Vue Router does it with a slot and `Transition`:

  ```lua
  local Layout = Rivue.defineComponent({
  	name = "Layout",
  	render = function()
  		return h("Frame", { Size = UDim2.fromScale(1, 1) }, {
  			h(Router.RouterView, nil, {
  				default = function(view)
  					return h(Rivue.Transition, Rivue.transitions.fade({ mode = "out-in" }), { view.Component })
  				end,
  			}),
  		})
  	end,
  })
  ```

- **Details**

  - With a `default` slot, the view doesn't render the screen itself. The slot gets
    `{ Component, route }`, where `Component` is the screen's vnode (or nil), and returns what to
    render. Wrap it in `Transition`, `KeepAlive` or both.
  - `keepAlive = true` is a shortcut for wrapping the screen in [KeepAlive](builtins.md#keepalive),
    so screens you leave keep their state.
  - `name` picks a named view, for routes with `components = { default = ..., side = ... }`.
    A view the current route has no component for renders nothing.
  - Each route gets its own instance, even when two routes share a component. The same route
    with new params keeps its instance and gets new props.

- **Props**

  ```lua
  type RouterViewProps = {
  	name: string?, -- default "default"
  	keepAlive: boolean?,
  }
  ```

---

## Router.RouterLink

A TextButton that navigates when pressed, and gets style classes while its route is active.

- **Example**

  Tabs that highlight the open one:

  ```lua
  local Tabs = Rivue.defineComponent({
  	name = "Tabs",
  	render = function()
  		return h(Rivue.Row, { gap = 8 }, {
  			h(Router.RouterLink, { to = "weapons", class = "tab", Text = "Weapons" }),
  			h(Router.RouterLink, { to = "pets", class = "tab", Text = "Pets" }),
  		})
  	end,
  })

  local styles = {
  	tab = { TextColor3 = Color3.fromRGB(150, 150, 160) },
  	["router-link-active"] = { TextColor3 = Color3.new(1, 1, 1) },
  }
  ```

- **Details**

  - Any prop that isn't a RouterLink prop goes to the TextButton: `Text`, `Size`, `class` and so
    on. Your own `onActivated` runs before the navigation.
  - `router-link-active` is added while the link's route is open, or one of its child routes.
    `router-link-exact-active` only while that exact route is open with the same params.
    Rename them with `activeClass` and `exactActiveClass`. Define them in
    [app:styles()](application.md#appstyles); they come after the link's own `class`, so they win.
  - With `custom = true` the link renders its default slot instead of a TextButton. The slot gets
    `{ route, navigate, isActive, isExactActive }`.

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

`useRouter()` returns the router installed with `app:use(router)`. `useRoute()` returns the
current route. Call them in `setup()`.

- **Example**

  ```lua
  local ItemTitle = Rivue.defineComponent({
  	name = "ItemTitle",
  	setup = function()
  		local route = Router.useRoute()
  		local title = Rivue.computed(function()
  			return `Item {route.params.id}`
  		end)
  		return { title = title }
  	end,
  	render = function(ctx)
  		return h("TextLabel", { Text = ctx.title })
  	end,
  })
  ```

- **Details**

  - The route from `useRoute()` always shows the current route, and reading a field tracks it,
    so renders and computeds update when the player moves. It's read-only.
  - `useRouter()` errors if no router was installed, so a missing `app:use(router)` shows up
    straight away.

- **Type**

  ```lua
  function useRouter(): Router
  function useRoute(): Route
  ```

---

## Router.useLink()

What `RouterLink` uses inside, for building your own link component.

- **Example**

  ```lua
  local IconLink = Rivue.defineComponent({
  	name = "IconLink",
  	props = { to = { required = true }, icon = { type = "string" } },
  	setup = function(props)
  		local link = Router.useLink(props)
  		return { isActive = link.isActive, navigate = link.navigate }
  	end,
  	render = function(ctx)
  		return h("ImageButton", {
  			Image = ctx.icon,
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

Loads a route's component the first time the route is visited, like Vue Router's lazy routes. Big
menus that most players never open then don't slow down startup.

- **Example**

  ```lua
  local Lobby = Rivue.defineComponent({
  	name = "Lobby",
  	render = function()
  		return h("TextLabel", { Text = "Lobby" })
  	end,
  })

  local router = Router.createRouter({
  	routes = {
  		lobby = Lobby,
  		settings = Router.lazy(function()
  			-- usually: return require(script.Parent.Settings)
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

  - The loader runs during the navigation, after the `beforeEnter` guards and before
    `beforeResolve`, the same place Vue Router loads lazy components. It runs once, and the
    result is kept.
  - If the loader errors, or doesn't return a component, the navigation fails as `aborted` and
    the error goes to [`onError`](#routerisready-and-routeronerror).
  - It works anywhere a component goes: `component`, `components`, or as the whole route.
  - Rivue already treats a plain function as a function component, which is why the loader is
    wrapped in `Router.lazy()`.

- **Type**

  ```lua
  function lazy(loader: () -> ComponentDef): LazyComponent
  ```

---

## router.isReady() and router.onError()

`isReady()` waits until the first screen has arrived. `onError()` is told when a guard or
`scrollBehavior` errors.

- **Example**

  Show the menu once the player's data has loaded, and report guard errors:

  ```lua
  local Screen = function(name: string)
  	return Rivue.defineComponent({
  		name = name,
  		render = function()
  			return h("TextLabel", { Text = name })
  		end,
  	})
  end

  local dataLoaded = Instance.new("BindableEvent")
  local router = Router.createRouter({
  	routes = { lobby = Screen("Lobby") },
  	initial = "lobby",
  })

  router.beforeEach(function(_to, from)
  	if from == Router.START_LOCATION then
  		dataLoaded.Event:Wait()
  	end
  	return true
  end)

  router.onError(function(err, to)
  	warn("navigation to", to.name, "failed:", err)
  end)

  local app = Rivue.createApp(Router.RouterView)
  app:use(router)
  app:mount(Instance.new("Folder"))

  task.spawn(function()
  	router.isReady()
  	print("the lobby is on screen")
  end)
  dataLoaded:Fire()
  ```

- **Details**

  - A guard that waits on the first navigation doesn't hold up `app:mount()`. The app mounts with
    nothing in the `RouterView`, and the first screen appears when the guard lets it through.
  - `isReady()` returns straight away once the first navigation has finished, whether it arrived
    or was cancelled.
  - `onError` returns a function that removes the handler. With no handlers, errors are logged as
    warnings.

- **Type**

  ```lua
  isReady: () -> ()
  onError: (handler: (err: unknown, to: Route, from: Route) -> ()) -> () -> ()
  ```

---

## Navigation failures

When a navigation doesn't happen, `push`, `replace` and `go` return why.

- **Example**

  ```lua
  local function open(router, name: string)
  	local failure = router.push(name)
  	if Router.isNavigationFailure(failure, Router.NavigationFailureType.aborted) then
  		print("a guard said no")
  	end
  end
  ```

- **Details**

  | Type | When |
  |---|---|
  | `aborted` | a guard returned `false` or errored, or `go` had nowhere to go |
  | `cancelled` | another navigation started while a guard was waiting |
  | `duplicated` | the route and params were already open |

  `isNavigationFailure(value)` checks for any failure, `isNavigationFailure(value, type)` for one
  type. Combine types with `bit32.bor`.

- **Type**

  ```lua
  type NavigationFailure = { type: number, to: Route, from: Route }

  NavigationFailureType: { aborted: number, cancelled: number, duplicated: number }
  function isNavigationFailure(value: any, type: number?): boolean
  START_LOCATION: Route
  ```

---

## Differences from Vue Router

- Routes have names but no paths, since Roblox UI has no URLs. There's no hash or history mode,
  and `initial` takes the place of the starting URL. `query` is a table, not a string.
- Lazy routes use [`Router.lazy()`](#routerlazy) around a `require`, where Vue Router takes a
  function returning `import()`.
- `props` defaults to `true`: params become props unless you say otherwise.
- Guards and `push` yield where Vue Router uses Promises. There's no `next()` callback.
- `back`, `forward` and `go` return a failure or `nil`, like `push`.
- `scrollBehavior` scrolls ScrollingFrames, and `savedPosition` holds one position per frame.
- `RouterLink` is a TextButton, and its active state is a style class.

---

[← RivueRemote](remote.md) · [API reference](../API.md) · [Instance pool →](pool.md)
