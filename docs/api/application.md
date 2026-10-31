[Docs](../README.md) › [API](../API.md) › **Application**

# Application

**Learn it:** [Guide 1: Introduction](../guide/01-introduction.md) · [Guide 6: Styling and layout](../guide/06-styling-and-layout.md)

Creating, configuring and mounting an app. Examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
local h = Rivue.h
local Players = game:GetService("Players")
```

---

## createApp()

Creates an app from your root component. Configure it (styles, global components, plugins), then
mount it; nothing renders before that.

```lua signature
function createApp(root: ComponentDef | VNode, options: AppOptions?): App
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `root` | `ComponentDef \| VNode` | | the root component, or a vnode when you want to pass it props |
| `options` | `AppOptions?` | | see [Pooling options](#pooling-options) |

**Returns** an `App`. Its configuration methods return the app, so they chain.

### Example

```lua
local App = Rivue.defineComponent({
	name = "App",
	props = { title = { type = "string", default = "Lobby" } },
	render = function(ctx)
		return h("TextLabel", { Text = ctx.title })
	end,
})

local app = Rivue.createApp(App)
local lobby = Rivue.createApp(h(App, { title = "Waiting for players" })) -- with root props
```

---

## mount()

Creates an app and mounts it in one call: the same as `createApp(root, options):mount(parent)`.

```lua signature
function mount(root: ComponentDef | VNode, parent: Instance, options: AppOptions?): App
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `root` | `ComponentDef \| VNode` | | the root component or vnode |
| `parent` | `Instance` | | where to render |
| `options` | `AppOptions?` | | see [Pooling options](#pooling-options) |

### Example

```lua
local screen = Instance.new("ScreenGui")
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local Hud = Rivue.defineComponent({ name = "Hud", render = function() return h("Frame") end })
local app = Rivue.mount(Hud, screen)
```

---

## app:mount()

Renders the app inside any Instance: a ScreenGui, a Frame, a SurfaceGui or a BillboardGui. For the
usual full-screen case, use [`mountToPlayerGui()`](#appmounttoplayergui).

```lua signature
function App:mount(container: Instance): MountedState
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `container` | `Instance` | | where to render; anything else errors |

### Example

```lua
local part = Instance.new("Part")
local surface = Instance.new("SurfaceGui")
surface.Parent = part

local Sign = Rivue.defineComponent({ name = "Sign", render = function() return h("TextLabel", { Text = "Shop" }) end })
Rivue.createApp(Sign):mount(surface)
```

### Details

- Mounting again unmounts the previous tree first.

---

## app:mountToPlayerGui()

_yields_

The usual way to show an app: creates a ScreenGui named `AppRoot` in the player's PlayerGui and
mounts into it.

```lua signature
function App:mountToPlayerGui(player: Player)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `player` | `Player` | | usually `Players.LocalPlayer`; anything else errors |

> [!NOTE]
> It waits for the player's PlayerGui, so it can yield. The ScreenGui has `ResetOnSpawn = false`,
> so the UI survives respawning, and `app:unmount()` destroys it.

### Example

```lua
local Hud = Rivue.defineComponent({ name = "Hud", render = function() return h("Frame") end })
Rivue.createApp(Hud):mountToPlayerGui(Players.LocalPlayer)
```

---

## app:unmount()

Takes the app off screen and cleans up: unmount hooks run, watchers stop, and its Instances are
destroyed or returned to the pool.

```lua signature
function App:unmount()
```

### Example

```lua
local Hud = Rivue.defineComponent({ name = "Hud", render = function() return h("Frame") end })
local app = Rivue.createApp(Hud)
app:mountToPlayerGui(Players.LocalPlayer)

app:unmount() -- e.g. when leaving the lobby
```

---

## app:onUnmount()

Runs a callback when the app unmounts. Plugins use it to release what they set up.

```lua signature
function App:onUnmount(callback: () -> ()): App
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `() -> ()` | | runs once, on unmount; an error in it is warned |

### Example

```lua
local app = Rivue.createApp(h("Frame"))
local conn = Players.PlayerAdded:Connect(print)

app:onUnmount(function()
	conn:Disconnect()
end)
```

---

## app:component()

Registers a component by name for the whole app, so any render can write `h("Icon")` without
requiring it. For small pieces used everywhere, like icons and buttons.

```lua signature
function App:component(name: string, component: ComponentDef): App
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | the name renders use |
| `component` | `ComponentDef` | | the component; anything else errors |

### Example

```lua
local Icon = Rivue.defineComponent({
	name = "Icon",
	props = { image = { type = "string" } },
	render = function(props)
		return h("ImageLabel", { Image = props.image, Size = UDim2.fromOffset(24, 24) })
	end,
})

local App = Rivue.defineComponent({
	name = "App",
	render = function()
		return h("Icon", { image = "rbxassetid://123" })
	end,
})

Rivue.createApp(App):component("Icon", Icon):mountToPlayerGui(Players.LocalPlayer)
```

### Details

- A registered name wins over a ClassName with the same name.
- [`resolveComponent()`](render-function.md#resolvecomponent) looks names up in code.

---

## app:styles()

Registers app-wide style classes, which any element can use with the
[`class`](render-function.md#element-props) prop. Usually called once with your `styles.luau`
module.

```lua signature
function App:styles(styles: { [className: string]: { [prop: string]: any } }): App
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `styles` | `{ [string]: table }` | | class name to a table of props; calling again adds classes and replaces ones with the same name |

Each class can also hold these variants, each a table of props:

| Field | Type | Default | Description |
|---|---|---|---|
| `hover`, `pressed`, `selected` | `table` | | applied while the player interacts, without re-rendering; pressed wins over hover, hover over selected |
| `disabled` | `table` | | applied with `disabled = true`, which also sets `Interactable = false` and turns hover and pressed off |
| `phone`, `tablet`, `desktop`, `console` | `table` | | applied on that device; see [useDevice()](roblox.md#usedevice) |

> [!NOTE]
> An unknown class name warns in Studio.

### Example

```lua
local styles = {
	card = { BackgroundColor3 = Color3.fromRGB(30, 30, 36), cornerRadius = 8, padding = 12 },
	title = { TextSize = 22, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) },
}

local App = Rivue.defineComponent({
	name = "App",
	render = function()
		return h("Frame", { class = "card", Size = UDim2.fromOffset(300, 200) }, {
			h("TextLabel", { class = "title", Text = "Shop" }),
		})
	end,
})

Rivue.createApp(App):styles(styles):mountToPlayerGui(Players.LocalPlayer)
```

### Details

- A class can hold Instance properties and Rivue's own props (`cornerRadius`, `padding`, `layout`,
  ...).
- A component's own [`styles`](component.md#styles) win over app styles, and an element's own props
  win over both.

---

## app:directive()

Registers a directive that any element can use as a `v` prop.

```lua signature
function App:directive(name: string, directive: Directive): App
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | kebab-case, such as `"hover-scale"` for `vHoverScale` |
| `directive` | `Directive` | | its hooks; see [directives.register()](directives.md#directivesregister) |

> [!NOTE]
> Directives are global: this is the same as `directives.register()`. It's on the app so plugins
> can register through it.

### Example

```lua
local app = Rivue.createApp(h("Frame"))

app:directive("hover-scale", {
	mounted = function(el)
		local scale = Instance.new("UIScale")
		scale.Parent = el
		local enter = (el :: GuiObject).MouseEnter:Connect(function()
			scale.Scale = 1.05
		end)
		local leave = (el :: GuiObject).MouseLeave:Connect(function()
			scale.Scale = 1
		end)
		return { enter, leave }
	end,
	unmounted = function(_el, conns)
		for _, conn in conns do
			conn:Disconnect()
		end
	end,
})

-- then: h("TextButton", { vHoverScale = true })
```

---

## app:use()

Installs a plugin: a bundle of setup, such as registering components, directives and provided
values in one call.

```lua signature
function App:use(plugin: Plugin, ...: any): App

type Plugin = ((app: App, ...any) -> ()) | { install: (app: App, ...any) -> () }
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `plugin` | `Plugin` | | a function, or a table with `install`; anything else errors |
| `...` | `any` | | passed to the plugin after the app |

### Example

```lua
local LocalePlugin = {
	install = function(app, locale: string)
		app:provide("locale", locale)
		app.config.globalProperties.locale = locale
	end,
}

Rivue.createApp(h("Frame")):use(LocalePlugin, "en")
```

---

## app:provide()

Makes a value available to every component in the app through [`inject()`](component.md#inject).
For app-wide services like a theme or a sound player.

```lua signature
function App:provide(key: unknown, value: unknown): App
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `key` | `unknown` | | what components inject by |
| `value` | `unknown` | | the value; pass reactive state if it changes |

### Example

```lua
local PlayerData = Rivue.reactive({ coins = 0 })

local CoinLabel = Rivue.defineComponent({
	name = "CoinLabel",
	setup = function()
		return { data = Rivue.inject("playerData") }
	end,
	render = function(ctx)
		return h("TextLabel", { Text = `{ctx.data.coins} coins` })
	end,
})

Rivue.createApp(CoinLabel):provide("playerData", PlayerData):mountToPlayerGui(Players.LocalPlayer)
```

---

## app:runWithContext()

Runs a function as if it were inside the app, so [`inject()`](component.md#inject) works there.
For plugins, stores and services that run outside components.

```lua signature
function App:runWithContext<T>(fn: () -> T): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fn` | `() -> T` | | the function to run |

**Returns** what `fn` returns.

### Example

```lua
local app = Rivue.createApp(h("Frame")):provide("api", { baseUrl = "shop" })

local api = app:runWithContext(function()
	return Rivue.inject("api")
end)
print(api.baseUrl) -- shop
```

---

## app:printTree()

Prints what's mounted right now as a tree: components with their props, and the elements they
rendered.

```lua signature
function App:printTree(): string
```

**Returns** the same text it printed.

### Example

```lua
local Badge = Rivue.defineComponent({
	name = "Badge",
	props = { text = { type = "string" } },
	render = function(props)
		return h("TextLabel", { Text = props.text })
	end,
})
local app = Rivue.createApp(h("Frame", { Name = "Root" }, { h(Badge, { text = "NEW" }) }))
app:mount(Instance.new("ScreenGui"))
app:printTree()
--[[
Frame "Root"
  <Badge text="NEW">
    TextLabel "Badge"
]]
```

---

## app:rerender() / app:swapRoot()

Throws the current UI away and mounts again into the same container, optionally with a different
root. For swapping whole screens; to update the UI, change state instead.

```lua signature
function App:rerender(newRoot: VNode?): MountedState
function App:swapRoot(newRoot: VNode): MountedState
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `newRoot` | `VNode` | the current root | what to mount instead |

> [!WARNING]
> All component state is lost. Both error when the app isn't mounted.

### Example

```lua
local Lobby = Rivue.defineComponent({ name = "Lobby", render = function() return h("Frame") end })
local Match = Rivue.defineComponent({ name = "Match", render = function() return h("Frame") end })

local app = Rivue.createApp(Lobby)
app:mountToPlayerGui(Players.LocalPlayer)

app:swapRoot(h(Match)) -- when the match starts
```

---

## app.config.errorHandler

Receives every error that no [`onErrorCaptured()`](lifecycle.md#onerrorcaptured) stopped. A good
place to send errors to your analytics.

```lua signature
app.config.errorHandler: ((err: string, instance: ComponentInstance?, info: string) -> ())?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `err` | `string` | | the error |
| `instance` | `ComponentInstance?` | | the component it came from |
| `info` | `string` | | where it happened, such as `"render"` |

### Example

```lua
local app = Rivue.createApp(h("Frame"))

app.config.errorHandler = function(err, instance, info)
	local name = if instance then (instance :: any).type.__name else "?"
	warn(`[UI] {info} in {name}: {err}`)
	-- report to your analytics here
end
```

### Details

- Without a handler, errors are warned along with the component chain.

---

## app.config.warnHandler

Receives Rivue's Studio warnings instead of printing them, so you can collect them or fail a test
run on any warning.

```lua signature
app.config.warnHandler: ((message: string, instance: ComponentInstance?, trace: string) -> ())?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `message` | `string` | | the warning |
| `instance` | `ComponentInstance?` | | the component it came from |
| `trace` | `string` | | the component chain, such as `<Row> in <List> in <App>` |

> [!NOTE]
> These warnings only happen in Studio.

### Example

```lua
local app = Rivue.createApp(h("Frame"))

app.config.warnHandler = function(message, _instance, trace)
	print(`[Rivue warning] {message}\n  at {trace}`)
end
```

---

## app.config.globalProperties

Values every component in the app can read through `ctx.globals`, without injecting them one by
one.

```lua signature
app.config.globalProperties: { [string]: unknown }
```

### Example

```lua
local VersionLabel = Rivue.defineComponent({
	name = "VersionLabel",
	render = function(ctx)
		return h("TextLabel", { Text = `v{ctx.globals.version}` })
	end,
})

local app = Rivue.createApp(VersionLabel)
app.config.globalProperties.version = "1.4.0"
app:mountToPlayerGui(Players.LocalPlayer)
```

---

## app.config.devtools

Lets the [Rivue DevTools plugin](../DEVTOOLS.md) show this app's components while you playtest.

```lua signature
app.config.devtools: boolean?
```

> [!WARNING]
> Set it before `app:mount()`. Every render writes attributes, which costs an engine call each, so
> keep it off in live games: `game:GetService("RunService"):IsStudio()`.

### Example

```lua
local App = Rivue.defineComponent({ name = "App", render = function() return h("Frame") end })

local app = Rivue.createApp(App)
app.config.devtools = game:GetService("RunService"):IsStudio() -- only while testing in Studio
app:mountToPlayerGui(Players.LocalPlayer)
```

### Details

Each component's root Instance gets the `RivueComponent` tag and these attributes, updated on every
render. Writing them adds no dependencies, so it doesn't change what re-renders.

| Field | Type | Default | Description |
|---|---|---|---|
| `RivueComponent` | `string` | | its name |
| `RivueProps` | `string` | | its props, one `key = value` per line |
| `RivueState` | `string` | | the refs `setup` returned, the same way |
| `RivueRenders` | `number` | | how many times it rendered |
| `RivueRenderMs` | `number` | | how long the last render and patch took, in milliseconds |
| `RivueTrigger` | `string` | | what caused the last render: `mount`, `parent`, or the state that changed, like `count` or `props.title` |
| `RivueSource` | `string` | | where `defineComponent` was called, like `ReplicatedStorage.UI.Shop:12` |
| `RivueEmit` | `string` | | the latest `emit`: a counter, the event name and its arguments |
| `RivueProvides` | `string` | | the keys it provides, one per line |
| `RivueInjects` | `string` | | the keys it injected, one per line |

- The app also gets a `Configuration` named `RivueDevTools`, tagged `RivueDevToolsChannel`, in the
  container it was mounted in. Its `RivueTimeline` attribute holds the last 50 renders, emits,
  navigations and remote requests, and `RivueRoute` holds RivueRouter's current route and history.
  It's removed on unmount.
- The plugin edits state by setting `RivueEdit` to `"key=value"`. Rivue sets the ref `setup`
  returned as `key` when the value parses as the ref's current type (number, string or boolean),
  then clears the attribute.

---

## app.config.idPrefix

Replaces the `r` at the start of [`useId()`](component.md#useid) ids for components in this app,
as Vue 3.5's `idPrefix` does. Ids are already unique across apps, so the prefix is for seeing which
app made an id, for example in an Instance name.

```lua signature
app.config.idPrefix: string?
```

> [!WARNING]
> Set it before `app:mount()`. Ids made before the change keep the old prefix.

### Example

```lua
local Slot = Rivue.defineComponent({
	name = "Slot",
	setup = function()
		print(Rivue.useId()) -- for example "inv12-1"
		return {}
	end,
	render = function()
		return h("Frame")
	end,
})

local app = Rivue.createApp(Slot)
app.config.idPrefix = "inv"
app:mount(Instance.new("Folder"))
```

### Details

- Defaults to `"r"`, giving ids like `"r12-1"`.
- `useId()` called outside a component isn't tied to an app, so it always uses `r`.

---

## app.config.experimental

Turns on features that aren't stable yet. The only one today is
[Vapor mode](vapor.md), for components that render once.

```lua signature
app.config.experimental: { vapor: boolean? }?
```

> [!WARNING]
> Experimental features can change between releases. Set it before `app:mount()`.

### Example

```lua
local App = Rivue.defineComponent({ name = "App", render = function() return h("Frame") end })

local app = Rivue.createApp(App)
app.config.experimental = { vapor = true }
app:mount(Instance.new("Folder"))
```

---

## app.config.performance

Marks each component's `setup`, render and patch in Roblox's MicroProfiler, as Vue's
`app.config.performance` does for the browser's tools.

```lua signature
app.config.performance: boolean?
```

> [!NOTE]
> Set it before `app:mount()`. Open the MicroProfiler with Ctrl+F6 and look for
> `Rivue <Name> setup`, `Rivue <Name> render` and `Rivue <Name> patch` in the frame where the UI
> updates.

### Example

```lua
local App = Rivue.defineComponent({ name = "App", render = function() return h("Frame") end })

local app = Rivue.createApp(App)
app.config.performance = game:GetService("RunService"):IsStudio()
app:mountToPlayerGui(Players.LocalPlayer)
```

---

## Pooling options

The `options` of `createApp()` and `mount()`. Turn pooling on for UI that creates and removes many
Instances, like feeds, inventories and damage numbers: removed Instances are reset and reused
instead of destroyed.

```lua signature
type AppOptions = {
	usePool: boolean?,
	poolConfig: PoolConfig?,
	poolWarmup: { [string]: number }?,
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `usePool` | `boolean` | `false` | reuse Instances |
| `poolConfig` | `PoolConfig?` | | the same fields as [Pool.configure()](pool.md#poolconfigure) |
| `poolWarmup` | `{ [string]: number }?` | see below | ClassName to how many to create up front |

> [!NOTE]
> With `usePool` and no `poolWarmup`, it creates 10 Frames, 20 TextLabels and 5 TextButtons up
> front, unless `poolConfig.enableAutoWarmup` is on.

### Example

```lua
local DamageNumbers = Rivue.defineComponent({ name = "DamageNumbers", render = function() return h("Frame") end })

local app = Rivue.createApp(DamageNumbers, {
	usePool = true,
	poolConfig = { maxPoolSize = 100 },
	poolWarmup = { TextLabel = 50 },
})
app:mountToPlayerGui(Players.LocalPlayer)
print((app.getPoolStats :: any)(app))
```

### Details

- Reused Instances have every property Rivue set reset to its default.
- With pooling on, the app also has `app:getPoolStats()` and `app:validatePoolHealth()`. See
  [Instance pool](pool.md).

---

[← Directives](directives.md) · [API reference](../API.md) · [Scheduler →](scheduler.md)
