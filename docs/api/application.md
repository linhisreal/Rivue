[Docs](../README.md) › [API](../API.md) › **Application**

# Application

**Learn it:** [Guide 1: Introduction](../guide/01-introduction.md) · [Guide 6: Styling and layout](../guide/06-styling-and-layout.md)

Creating and configuring an app. All examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h
local Players = game:GetService("Players")
```

- [createApp()](#createapp)
- [mount()](#mount)
- [app:mount()](#appmount)
- [app:mountToPlayerGui()](#appmounttoplayergui)
- [app:unmount()](#appunmount)
- [app:onUnmount()](#apponunmount)
- [app:component()](#appcomponent)
- [app:styles()](#appstyles)
- [app:directive()](#appdirective)
- [app:use()](#appuse)
- [app:provide()](#appprovide)
- [app:runWithContext()](#apprunwithcontext)
- [app:printTree()](#appprinttree)
- [app:rerender() / app:swapRoot()](#apprerender--appswaproot)
- [app.config.errorHandler](#appconfigerrorhandler)
- [app.config.warnHandler](#appconfigwarnhandler)
- [app.config.globalProperties](#appconfigglobalproperties)
- [Pooling options](#pooling-options)

---

## createApp()

The starting point of every Rivue UI. You give it your root component, configure it (styles, global
components, plugins), then mount it somewhere.

- **Example**

  Create the app for your root component, configure it, then mount it:

  ```lua
  local App = Rivue.defineComponent({
  	name = "App",
  	props = { title = { type = "string", default = "Lobby" } },
  	render = function(ctx)
  		return h("TextLabel", { Text = ctx.title })
  	end,
  })

  local app = Rivue.createApp(App)
  -- or pass props to the root by giving it a vnode:
  local lobby = Rivue.createApp(h(App, { title = "Waiting for players" }))
  ```

- **Details**

  The root can be a component, or a vnode when you want to pass props to it. Nothing renders
  until you mount the app.

- **Type**

  ```lua
  function createApp(root: ComponentDef | VNode, options: AppOptions?): App

  type AppOptions = {
  	usePool: boolean?, -- reuse Instances, see "Pooling options"
  	poolConfig: PoolConfig?,
  	poolWarmup: { [string]: number }?,
  }
  ```

---

## mount()

A one-liner for the common case: create an app and mount it straight away. Same as `createApp(root,
options):mount(parent)`.

- **Example**

  ```lua
  local screen = Instance.new("ScreenGui")
  screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

  local Hud = Rivue.defineComponent({ name = "Hud", render = function() return h("Frame") end })
  local app = Rivue.mount(Hud, screen)
  ```

- **Type**

  ```lua
  function mount(root: ComponentDef | VNode, parent: Instance, options: AppOptions?): App
  ```

---

## app:mount()

Puts the app on screen inside any Instance you choose: a ScreenGui, a SurfaceGui on a part, a Frame.
Use [`mountToPlayerGui()`](#appmounttoplayergui) for the usual full-screen case.

- **Example**

  ```lua
  local part = Instance.new("Part")
  local surface = Instance.new("SurfaceGui")
  surface.Parent = part

  local Sign = Rivue.defineComponent({ name = "Sign", render = function() return h("TextLabel", { Text = "Shop" }) end })
  Rivue.createApp(Sign):mount(surface)
  ```

- **Details**

  The container can be any Instance: a ScreenGui, a Frame, a SurfaceGui or a BillboardGui.
  Mounting again unmounts the previous tree first.

- **Type**

  ```lua
  function App:mount(container: Instance): MountedState
  ```

---

## app:mountToPlayerGui()

The usual way to show an app: it creates a ScreenGui in the player's PlayerGui (with `ResetOnSpawn =
false`) and mounts into it.

- **Example**

  ```lua
  local Hud = Rivue.defineComponent({ name = "Hud", render = function() return h("Frame") end })
  Rivue.createApp(Hud):mountToPlayerGui(Players.LocalPlayer)
  ```

- **Details**

  The ScreenGui is named `AppRoot` and has `ResetOnSpawn = false`, so the UI survives
  respawning.

- **Type**

  ```lua
  function App:mountToPlayerGui(player: Player)
  ```

---

## app:unmount()

Takes the whole app off screen and cleans up after it: unmount hooks run, watchers stop, and its
Instances are destroyed (or returned to the pool).

- **Example**

  ```lua
  local Hud = Rivue.defineComponent({ name = "Hud", render = function() return h("Frame") end })
  local app = Rivue.createApp(Hud)
  app:mountToPlayerGui(Players.LocalPlayer)

  -- Later, e.g. when leaving the lobby
  app:unmount()
  ```

- **Type**

  ```lua
  function App:unmount()
  ```

---

## app:onUnmount()

Runs your callback when the app unmounts. Plugins use it to release whatever they set up, like
connections or timers.

- **Example**

  ```lua
  local app = Rivue.createApp(h("Frame"))
  local conn = Players.PlayerAdded:Connect(print)

  app:onUnmount(function()
  	conn:Disconnect()
  end)
  ```

- **Type**

  ```lua
  function App:onUnmount(callback: () -> ()): App
  ```

---

## app:component()

Makes a component available everywhere in the app by name, so any render function can write
`h("Icon")` without requiring it. Good for small, widely used pieces like icons and buttons.

- **Example**

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

- **Details**

  Registered names take priority over ClassNames with the same name.
  [`resolveComponent()`](render-function.md#resolvecomponent) looks them up in code.

- **Type**

  ```lua
  function App:component(name: string, component: ComponentDef): App
  ```

---

## app:styles()

Registers your app-wide style classes, so any element can use them with the
[`class`](render-function.md#element-props) prop. Usually called once with your `styles.luau`
module.

- **Example**

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

- **Details**

  Each class is a table of props: Instance properties and modifier props (`cornerRadius`,
  `padding`, `stroke`, `layout`, ...). Calling it again adds classes and replaces ones with the
  same name. A component's own [`styles`](component.md#styles) option wins over app styles, and an
  element's own props win over both. Unknown class names warn in Studio.

- **Type**

  ```lua
  function App:styles(styles: { [className: string]: { [prop: string]: any } }): App
  ```

---

## app:directive()

Adds your own directive (a reusable behaviour like `vTooltip`) that any element in the app can use
as a `v` prop.

- **Example**

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

  -- Then: h("TextButton", { vHoverScale = true })
  ```

- **Details**

  Directives are global, so this is the same as
  [`directives.register()`](directives.md#custom-directives). It's here so plugins can register
  through the app.

- **Type**

  ```lua
  function App:directive(name: string, directive: Directive): App
  ```

---

## app:use()

Installs a plugin: a reusable bundle of setup for an app, such as registering components, directives
and provided values in one call.

- **Example**

  ```lua
  local LocalePlugin = {
  	install = function(app, locale: string)
  		app:provide("locale", locale)
  		app.config.globalProperties.locale = locale
  	end,
  }

  Rivue.createApp(h("Frame")):use(LocalePlugin, "en")
  ```

- **Details**

  A plugin is a function, or a table with an `install` function. It receives the app and any
  extra arguments.

- **Type**

  ```lua
  function App:use(plugin: Plugin, ...: any): App

  type Plugin = ((app: App, ...any) -> ()) | { install: (app: App, ...any) -> () }
  ```

---

## app:provide()

Makes a value available to every component in the app through [`inject()`](component.md#inject).
Handy for app-wide services like a theme or a sound player.

- **Example**

  Give every component access to the player's data:

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

- **Type**

  ```lua
  function App:provide(key: unknown, value: unknown): App
  ```

---

## app:runWithContext()

Runs a function as if it were inside the app, so [`inject()`](component.md#inject) works there.
Useful in plugins and helper modules that run outside any component.

- **Example**

  ```lua
  local app = Rivue.createApp(h("Frame")):provide("api", { baseUrl = "shop" })

  local api = app:runWithContext(function()
  	return Rivue.inject("api")
  end)
  print(api.baseUrl) -- shop
  ```

- **Details**

  This lets code outside components, such as stores or services, use what the app provides.

- **Type**

  ```lua
  function App:runWithContext<T>(fn: () -> T): T
  ```

---

## app:printTree()

Prints what's on screen right now, as a tree: components with their props, and the elements they
rendered. The quickest way to answer "what is actually mounted?".

- **Example**

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

- **Type**

  ```lua
  function App:printTree(): string
  ```

---

## app:rerender() / app:swapRoot()

Throws the current UI away and mounts again into the same container, optionally with a different
root. Handy for hot-reloading while you work in Studio.

- **Example**

  ```lua
  local Lobby = Rivue.defineComponent({ name = "Lobby", render = function() return h("Frame") end })
  local Match = Rivue.defineComponent({ name = "Match", render = function() return h("Frame") end })

  local app = Rivue.createApp(Lobby)
  app:mountToPlayerGui(Players.LocalPlayer)

  -- When the match starts
  app:swapRoot(h(Match))
  ```

- **Details**

  All component state is lost. To update the UI, change reactive state instead; these are for
  swapping whole screens or for hot reloading.

- **Type**

  ```lua
  function App:rerender(newRoot: VNode?): MountedState
  function App:swapRoot(newRoot: VNode): MountedState
  ```

---

## app.config.errorHandler

Your last chance to deal with an error: it receives anything that no
[`onErrorCaptured()`](lifecycle.md#onerrorcaptured) handler stopped. Use it to report errors to your
analytics.

- **Example**

  ```lua
  local app = Rivue.createApp(h("Frame"))

  app.config.errorHandler = function(err, instance, info)
  	local name = if instance then (instance :: any).type.__name else "?"
  	warn(`[UI] {info} in {name}: {err}`)
  	-- report to your analytics here
  end
  ```

- **Details**

  Without a handler, errors are reported with `warn`, along with the component chain.

- **Type**

  ```lua
  app.config.errorHandler: ((err: string, instance: ComponentInstance?, info: string) -> ())?
  ```

---

## app.config.warnHandler

Receives Rivue's Studio warnings instead of printing them with `warn`. Useful for collecting them,
or failing a test run on any warning.

- **Example**

  ```lua
  local app = Rivue.createApp(h("Frame"))

  app.config.warnHandler = function(message, _instance, trace)
  	print(`[Rivue warning] {message}\n  at {trace}`)
  end
  ```

- **Details**

  `trace` is the component chain, such as `<Row> in <List> in <App>`. Warnings only happen in
  Studio.

- **Type**

  ```lua
  app.config.warnHandler: ((message: string, instance: ComponentInstance?, trace: string) -> ())?
  ```

---

## app.config.globalProperties

Values every component in the app can read through `ctx.globals`, without injecting them one by one.

- **Example**

  Show the game version in any component, without injecting it:

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

- **Type**

  ```lua
  app.config.globalProperties: { [string]: unknown }
  ```

---

## Pooling options

Turn this on for UI that creates and removes many Instances (feeds, inventories, damage numbers):
removed Instances are reset and reused instead of destroyed and created again.

- **Example**

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

- **Details**

  Pooling helps UI that creates and removes many Instances often, like lists that change a lot,
  damage numbers or notifications. Reused Instances have every property Rivue set reset to its
  default. With pooling on, the app also gets `app:getPoolStats()` and
  `app:validatePoolHealth()`. See [Instance pool](pool.md).

- **Type**

  ```lua
  type AppOptions = {
  	usePool: boolean?,
  	poolConfig: {
  		maxPoolSize: number?, -- per class (default 50)
  		maxTotalSize: number?, -- across classes (default 500)
  		defaultTTL: number?, -- seconds an unused Instance is kept
  		enableMetrics: boolean?, -- default true
  		enableDebug: boolean?,
  		enableAutoWarmup: boolean?,
  	}?,
  	poolWarmup: { [string]: number }?, -- ClassName -> how many to create up front
  }
  ```

---

[← Directives](directives.md) · [API reference](../API.md) · [Scheduler →](scheduler.md)
