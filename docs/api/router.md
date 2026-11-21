[Docs](../README.md) › [API](../API.md) › **RivueRouter**

# RivueRouter

**Learn it:** [Guide 17: Screens and navigation](../guide/17-screens-and-navigation.md)

Named screens with history, after [Vue Router 4](https://router.vuejs.org). Put `RivueRouter` next
to `RivueUI`. Examples assume `local Router = require(game.ReplicatedStorage.RivueRouter)`.

---

## Router.createRouter()

Creates the router. Install it with `app:use(router)` before mounting.

```lua signature
function createRouter(options: RouterOptions): Router
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `options.routes` | `{ [string]: ComponentDef \| RouteRecord } \| { RouteRecord }` | | names to components or [records](#route-records), or a list of named records |
| `options.initial` | `string` | | the first screen; it goes through the guards like any navigation |
| `options.initialParams` | `{ [string]: any }?` | | params for the first screen |
| `options.scrollBehavior` | `ScrollBehavior?` | | see [scrollBehavior](#scrollbehavior) |
| `options.backKeys` | `{ Enum.KeyCode }?` | | keys that call `back()` while there's history, and pass through otherwise |

**Returns** a `Router`. `currentRoute`, `canGoBack` and `canGoForward` are refs; until the first
navigation finishes, `currentRoute` is `Router.START_LOCATION`.

> [!WARNING]
> Two routes with the same name, or an alias that's already a route name, error here.

### Example

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

---

## Route records

A route is a component or a record.

```lua signature
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

| Field | Type | Default | Description |
|---|---|---|---|
| `component` | `ComponentDef` | | the screen, or a [`Router.lazy()`](#routerlazy) loader |
| `components` | `{ [string]: ComponentDef }` | | screens by view name, for [named views](#routerrouterview) |
| `children` | `{ [string]: ... }` | | child routes, shown by a `RouterView` inside the screen |
| `meta` | `{ [string]: any }` | | merged with the parents' meta into `route.meta` |
| `redirect` | `string \| RouteLocation \| (to) -> ...` | | followed before the guards |
| `alias` | `string \| { string }` | | other names for this route |
| `props` | `boolean \| table \| (route) -> table` | `true` | `true` passes params as props, `false` none, a table as is; per view with `components` |
| `beforeEnter` | `Guard \| { Guard }` | | guards run when entering from a different route |

> [!NOTE]
> Names, child names and aliases share one namespace. More than 10 redirects in a row errors.

### Example

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

---

## router.push() and router.replace()

`push` adds a history entry; `replace` swaps the current one.

```lua signature
push: (to: string | RouteLocation, params: { [string]: any }?) -> NavigationFailure?
replace: (to: string | RouteLocation, params: { [string]: any }?) -> NavigationFailure?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `to` | `string \| RouteLocation` | | a route name, or a location |
| `to.params` | `{ [string]: any }?` | | passed to the screen as props |
| `to.query` | `{ [string]: any }?` | | extra data; it doesn't affect matching or `RouterLink` active classes, and redirects keep it |
| `to.replace` | `boolean` | `false` | replace instead of push |
| `to.force` | `boolean` | `false` | navigate even when nothing changed |
| `params` | `{ [string]: any }?` | | with a name as `to`: the params |

**Returns** `nil` when it moved, or a [failure](#navigation-failures). The same route, params and
query again returns `duplicated`.

> [!WARNING]
> It yields while a guard yields. An unknown route name errors.

### Example

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

---

## router.go(), back() and forward()

Moves through history. Guards run as for `push`.

```lua signature
go: (delta: number) -> NavigationFailure?
back: () -> NavigationFailure?
forward: () -> NavigationFailure?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `delta` | `number` | | entries to move; negative goes back |

**Returns** `nil`, or a failure. Going past either end returns `aborted`.

### Example

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

---

## Navigation guards

Run before every navigation, including `back` and `forward`, and can cancel it or send the player
somewhere else.

```lua signature
type Guard = (to: Route, from: Route) -> boolean | string | RouteLocation | nil

beforeEach: (guard: Guard) -> () -> ()
beforeResolve: (guard: Guard) -> () -> ()
afterEach: (hook: (to: Route, from: Route, failure: NavigationFailure?) -> ()) -> () -> ()
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `guard` | `Guard` | | return `nil` or `true` to continue, `false` to abort, or a name or location to redirect |
| `hook` | `(to, from, failure) -> ()` | | `afterEach`: runs once a navigation is done, with its failure if any |

**Returns** a function that removes the guard.

> [!NOTE]
> Guards can yield, and a newer navigation cancels a waiting one with `cancelled`. A guard that
> errors cancels the navigation and goes to [`onError`](#routerisready-and-routeronerror).

### Example

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

### Details

- Order: `onBeforeRouteLeave`, `beforeEach`, `onBeforeRouteUpdate`, `beforeEnter`, lazy
  components load, `beforeResolve`, the route changes, `afterEach`.

---

## onBeforeRouteLeave() and onBeforeRouteUpdate()

_setup() only_

Guards inside a component, called in `setup()` of a screen or anything in it. They're removed on
unmount.

```lua signature
function onBeforeRouteLeave(guard: Guard)
function onBeforeRouteUpdate(guard: Guard)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `guard` | `Guard` | | `onBeforeRouteLeave`: when leaving this screen's route; `onBeforeRouteUpdate`: when the route changes but the screen stays (new params, or a child route) |

> [!WARNING]
> Outside a screen shown by a `RouterView` they warn and do nothing.

### Example

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

---

## Dynamic routes

Add and remove routes while the game runs, such as an event screen.

```lua signature
addRoute: (parentOrRecord: string | RouteRecord, record: RouteRecord?) -> () -> ()
removeRoute: (name: string) -> ()
hasRoute: (name: string) -> boolean
getRoutes: () -> { RouteRecord }
resolve: (to: string | RouteLocation, params: { [string]: any }?) -> Route
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `parentOrRecord` | `string \| RouteRecord` | | a record, or the parent's name to add a child |
| `record` | `RouteRecord?` | | with a parent name: the child record |
| `name` | `string` | | the route to remove; its children go too |

**Returns** `addRoute` returns a remover; an existing name is replaced. `resolve` returns the route
without navigating, and doesn't follow `redirect`.

### Example

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

---

## scrollBehavior

Where ScrollingFrames scroll after a navigation. It runs after the new screen renders.

```lua signature
type ScrollBehavior = (
	to: Route,
	from: Route,
	savedPosition: { [string]: Vector2 }?
) -> { [string]: Vector2 } | { el: string?, top: number?, left: number? } | nil
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `savedPosition` | `{ [string]: Vector2 }?` | | on `back`, `forward` and `go`: each frame's `CanvasPosition` by name |

**Returns** `savedPosition` to restore it, `{ top, left }` for every frame, `el = "Panel/List"` with
those for one frame, or `nil` to leave them.

> [!NOTE]
> Only the top-level `RouterView` is scrolled.

### Example

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

---

## Router.RouterView

Renders the current route's screen. Inside a screen, it renders the child route.

```lua signature
h(Router.RouterView, props: RouterViewProps, slots?)
```

| Prop | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `"default"` | which named view to show |
| `keepAlive` | `boolean` | `false` | wrap the screen in [KeepAlive](builtins.md#keepalive) |

| Slot | Type | Default | Description |
|---|---|---|---|
| `default` | `(view: { Component, route }) -> VNode` | | renders instead of the view, so you can wrap it, for example in a Transition |

### Example

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

### Details

- Each route gets its own component; the same route with new params keeps it.

---

## Router.RouterLink

A TextButton that navigates, with style classes while its route is active.

```lua signature
h(Router.RouterLink, props: RouterLinkProps)
```

| Prop | Type | Default | Description |
|---|---|---|---|
| `to` | `string \| RouteLocation` | | where it goes |
| `replace` | `boolean` | `false` | replace instead of push |
| `custom` | `boolean` | `false` | render the default slot with `{ route, navigate, isActive, isExactActive }` instead of a button |
| `activeClass` | `string` | `"router-link-active"` | applied on the route or its children |
| `exactActiveClass` | `string` | `"router-link-exact-active"` | applied on the exact route and params |
| others | | | go to the TextButton; your `onActivated` runs before navigating |

### Example

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

### Details

- The active classes win over the link's own `class`.

---

## Router.useRouter() and Router.useRoute()

The router, and a reactive view of the current route. Call them in `setup()`.

```lua signature
function useRouter(): Router
function useRoute(): Route

type Route = {
	name: string?,
	params: { [string]: any },
	query: { [string]: any },
	meta: { [string]: any },
	matched: { RouteRecord },
	redirectedFrom: Route?,
}
```

> [!WARNING]
> `useRouter()` errors when no router is installed. The route from `useRoute()` is read-only;
> writing to it errors, so navigate with `push()` or `replace()`.

### Example

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

---

## Router.useLink()

`RouterLink`'s logic, for your own link components.

```lua signature
function useLink(props: { to: string | RouteLocation, replace: boolean? }): {
	route: Ref<Route>,
	isActive: Ref<boolean>,
	isExactActive: Ref<boolean>,
	navigate: () -> NavigationFailure?,
}
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `props.to` | `string \| RouteLocation` | | where it goes |
| `props.replace` | `boolean` | `false` | replace instead of push |

### Example

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

---

## Router.lazy()

Loads a route's component the first time it's visited, usually
`Router.lazy(function() return require(script.Parent.Settings) end)`.

```lua signature
function lazy(loader: () -> ComponentDef): LazyComponent
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `loader` | `() -> ComponentDef` | | runs once, after `beforeEnter` and before `beforeResolve` |

> [!NOTE]
> The wrapper is needed because a plain function is a function component. A loader that errors or
> returns something else aborts the navigation and goes to `onError`.

### Example

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

---

## router.isReady() and router.onError()

`isReady()` yields until the first navigation finishes. `onError()` gets errors from guards, lazy
loaders and `scrollBehavior`.

```lua signature
isReady: () -> ()
onError: (handler: (err: unknown, to: Route, from: Route) -> ()) -> () -> ()
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `handler` | `(err, to, from) -> ()` | | runs for each error |

**Returns** `onError` returns a remover. Without handlers, errors are warned.

> [!NOTE]
> A guard waiting on the first navigation doesn't hold up `app:mount()`. The `RouterView` stays
> empty until it passes.

### Example

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

---

## Navigation failures

What `push`, `replace`, `go`, `back` and `forward` return when they didn't move.

```lua signature
type NavigationFailure = { type: number, to: Route, from: Route }

NavigationFailureType: { aborted: number, cancelled: number, duplicated: number }
function isNavigationFailure(value: any, type: number?): boolean
START_LOCATION: Route
```

| Field | Type | Default | Description |
|---|---|---|---|
| `aborted` | `number` | | a guard returned `false` or errored, or `go` had nowhere to go |
| `cancelled` | `number` | | a newer navigation started while a guard waited |
| `duplicated` | `number` | | already on that route with the same params and query |

Combine types with `bit32.bor`.

### Example

```lua
local function open(router, name: string)
	local failure = router.push(name)
	if Router.isNavigationFailure(failure, Router.NavigationFailureType.aborted) then
		print("a guard said no")
	end
end
```

---

## Differences from Vue Router

- Named routes only, with no paths or history modes. `initial` replaces the start URL, and `query`
  is a table.
- `Router.lazy()` around `require` instead of `import()`.
- `props` defaults to `true`.
- Guards and `push` yield instead of returning Promises. There's no `next()`.
- `back`, `forward` and `go` return a failure like `push`.
- `scrollBehavior` works on ScrollingFrames.
- `RouterLink` is a TextButton, and its active state is a style class.

---

[← RivueRemote](remote.md) · [API reference](../API.md) · [Instance pool →](pool.md)
