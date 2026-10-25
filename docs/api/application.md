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

Creates an app instance.

- **Type**

  ```lua
  function createApp(root: ComponentDef | VNode, options: AppOptions?): App

  type AppOptions = {
  	usePool: boolean?, -- reuse Instances, see "Pooling options"
  	poolConfig: PoolConfig?,
  	poolWarmup: { [string]: number }?,
  }
  ```

- **Details**

  The root can be a component, or a vnode when you want to pass props to it. Nothing renders
  until you mount the app.

- **Example**

  ```lua
  local App = Rivue.defineComponent(function()
  	return function()
  		return h("TextLabel", { Text = "Hello" })
  	end
  end, { name = "App" })

  local app = Rivue.createApp(App)
  -- or with root props:
  local app2 = Rivue.createApp(h(App, { title = "Lobby" }))
  ```

---

## mount()

Shortcut for `createApp(root, options):mount(parent)`.

- **Type**

  ```lua
  function mount(root: ComponentDef | VNode, parent: Instance, options: AppOptions?): App
  ```

- **Example**

  ```lua
  local screen = Instance.new("ScreenGui")
  screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

  local Hud = Rivue.defineComponent({ name = "Hud", render = function() return h("Frame") end })
  local app = Rivue.mount(Hud, screen)
  ```

---

## app:mount()

Renders the app into an Instance.

- **Type**

  ```lua
  function App:mount(container: Instance): MountedState
  ```

- **Details**

  The container can be any Instance: a ScreenGui, a Frame, a SurfaceGui or a BillboardGui.
  Mounting again unmounts the previous tree first.

- **Example**

  ```lua
  local part = Instance.new("Part")
  local surface = Instance.new("SurfaceGui")
  surface.Parent = part

  local Sign = Rivue.defineComponent({ name = "Sign", render = function() return h("TextLabel", { Text = "Shop" }) end })
  Rivue.createApp(Sign):mount(surface)
  ```

---

## app:mountToPlayerGui()

Creates a ScreenGui in the player's PlayerGui and mounts into it.

- **Type**

  ```lua
  function App:mountToPlayerGui(player: Player)
  ```

- **Details**

  The ScreenGui is named `AppRoot` and has `ResetOnSpawn = false`, so the UI survives
  respawning.

- **Example**

  ```lua
  local Hud = Rivue.defineComponent({ name = "Hud", render = function() return h("Frame") end })
  Rivue.createApp(Hud):mountToPlayerGui(Players.LocalPlayer)
  ```

---

## app:unmount()

Unmounts the app: runs unmount hooks, stops watchers and destroys (or pools) its Instances.

- **Type**

  ```lua
  function App:unmount()
  ```

- **Example**

  ```lua
  local Hud = Rivue.defineComponent({ name = "Hud", render = function() return h("Frame") end })
  local app = Rivue.createApp(Hud)
  app:mountToPlayerGui(Players.LocalPlayer)

  -- Later, e.g. when leaving the lobby
  app:unmount()
  ```

---

## app:onUnmount()

Registers a callback that runs when the app unmounts. Useful for plugins that hold resources.

- **Type**

  ```lua
  function App:onUnmount(callback: () -> ()): App
  ```

- **Example**

  ```lua
  local app = Rivue.createApp(h("Frame"))
  local conn = Players.PlayerAdded:Connect(print)

  app:onUnmount(function()
  	conn:Disconnect()
  end)
  ```

---

## app:component()

Registers a component under a name, so `h("Name")` renders it anywhere in the app.

- **Type**

  ```lua
  function App:component(name: string, component: ComponentDef): App
  ```

- **Details**

  Registered names take priority over ClassNames with the same name.
  [`resolveComponent()`](render-function.md#resolvecomponent) looks them up in code.

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

---

## app:styles()

Registers style classes for the [`class`](render-function.md#element-props) prop, app-wide.

- **Type**

  ```lua
  function App:styles(styles: { [className: string]: { [prop: string]: any } }): App
  ```

- **Details**

  Each class is a table of props: Instance properties and modifier props (`cornerRadius`,
  `padding`, `stroke`, `layout`, ...). Calling it again adds classes and replaces ones with the
  same name. A component's own [`styles`](component.md#styles) option wins over app styles, and an
  element's own props win over both. Unknown class names warn in Studio.

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

---

## app:directive()

Registers a custom directive.

- **Type**

  ```lua
  function App:directive(name: string, directive: Directive): App
  ```

- **Details**

  Directives are global, so this is the same as
  [`directives.register()`](directives.md#custom-directives). It's here so plugins can register
  through the app.

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

---

## app:use()

Installs a plugin.

- **Type**

  ```lua
  function App:use(plugin: Plugin, ...: any): App

  type Plugin = ((app: App, ...any) -> ()) | { install: (app: App, ...any) -> () }
  ```

- **Details**

  A plugin is a function, or a table with an `install` function. It receives the app and any
  extra arguments.

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

---

## app:provide()

Provides a value to every component in the app.

- **Type**

  ```lua
  function App:provide(key: unknown, value: unknown): App
  ```

- **Example**

  ```lua
  local PlayerData = Rivue.reactive({ coins = 0 })

  local CoinLabel = Rivue.defineComponent(function()
  	local data = Rivue.inject("playerData")
  	return function()
  		return h("TextLabel", { Text = `{data.coins} coins` })
  	end
  end, { name = "CoinLabel" })

  Rivue.createApp(CoinLabel):provide("playerData", PlayerData):mountToPlayerGui(Players.LocalPlayer)
  ```

---

## app:runWithContext()

Runs a function with the app's provides available to [`inject()`](component.md#inject).

- **Type**

  ```lua
  function App:runWithContext<T>(fn: () -> T): T
  ```

- **Details**

  This lets code outside components, such as stores or services, use what the app provides.

- **Example**

  ```lua
  local app = Rivue.createApp(h("Frame")):provide("api", { baseUrl = "shop" })

  local api = app:runWithContext(function()
  	return Rivue.inject("api")
  end)
  print(api.baseUrl) -- shop
  ```

---

## app:printTree()

Prints and returns the mounted tree: components with their props, and the elements they rendered.

- **Type**

  ```lua
  function App:printTree(): string
  ```

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

---

## app:rerender() / app:swapRoot()

Unmounts and mounts again into the same container, optionally with a new root.

- **Type**

  ```lua
  function App:rerender(newRoot: VNode?): MountedState
  function App:swapRoot(newRoot: VNode): MountedState
  ```

- **Details**

  All component state is lost. To update the UI, change reactive state instead; these are for
  swapping whole screens or for hot reloading.

- **Example**

  ```lua
  local Lobby = Rivue.defineComponent({ name = "Lobby", render = function() return h("Frame") end })
  local Match = Rivue.defineComponent({ name = "Match", render = function() return h("Frame") end })

  local app = Rivue.createApp(Lobby)
  app:mountToPlayerGui(Players.LocalPlayer)

  -- When the match starts
  app:swapRoot(h(Match))
  ```

---

## app.config.errorHandler

Handles errors that no [`onErrorCaptured()`](lifecycle.md#onerrorcaptured) stopped.

- **Type**

  ```lua
  app.config.errorHandler: ((err: string, instance: ComponentInstance?, info: string) -> ())?
  ```

- **Details**

  Without a handler, errors are reported with `warn`, along with the component chain.

- **Example**

  ```lua
  local app = Rivue.createApp(h("Frame"))

  app.config.errorHandler = function(err, instance, info)
  	local name = if instance then (instance :: any).type.__name else "?"
  	warn(`[UI] {info} in {name}: {err}`)
  	-- report to your analytics here
  end
  ```

---

## app.config.warnHandler

Receives Rivue's Studio warnings instead of `warn`.

- **Type**

  ```lua
  app.config.warnHandler: ((message: string, instance: ComponentInstance?, trace: string) -> ())?
  ```

- **Details**

  `trace` is the component chain, such as `<Row> in <List> in <App>`. Warnings only happen in
  Studio.

- **Example**

  ```lua
  local app = Rivue.createApp(h("Frame"))

  app.config.warnHandler = function(message, _instance, trace)
  	print(`[Rivue warning] {message}\n  at {trace}`)
  end
  ```

---

## app.config.globalProperties

Values every component can read through `ctx.globals`.

- **Type**

  ```lua
  app.config.globalProperties: { [string]: unknown }
  ```

- **Example**

  ```lua
  local App = Rivue.defineComponent(function(_props, ctx)
  	return function()
  		return h("TextLabel", { Text = `Version {ctx.globals.version}` })
  	end
  end, { name = "App" })

  local app = Rivue.createApp(App)
  app.config.globalProperties.version = "1.4.0"
  app:mountToPlayerGui(Players.LocalPlayer)
  ```

---

## Pooling options

With `usePool = true`, removed Instances are kept and reused instead of destroyed and created
again.

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

- **Details**

  Pooling helps UI that creates and removes many Instances often, like lists that change a lot,
  damage numbers or notifications. Reused Instances have every property Rivue set reset to its
  default. With pooling on, the app also gets `app:getPoolStats()` and
  `app:validatePoolHealth()`. See [Instance pool](pool.md).

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

---

[← Directives](directives.md) · [API reference](../API.md) · [Scheduler →](scheduler.md)
