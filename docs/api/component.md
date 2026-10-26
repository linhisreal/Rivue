[Docs](../README.md) › [API](../API.md) › **Components**

# Components

**Learn it:** [Guide 1: Introduction](../guide/01-introduction.md) · [Guide 4: Components](../guide/04-components.md)

APIs for defining components and using them in `setup()`. All examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h
```

- [defineComponent()](#definecomponent)
- [props](#props)
- [emits](#emits)
- [setup()](#setup)
- [render()](#render)
- [components](#components)
- [styles](#styles)
- [Setup context](#setup-context)
- [Slots](#slots)
- [provide()](#provide)
- [inject()](#inject)
- [hasInjectionContext()](#hasinjectioncontext)
- [useTemplateRef()](#usetemplateref)
- [useAttrs()](#useattrs)
- [useSlots()](#useslots)
- [defineModel()](#definemodel)
- [useModel()](#usemodel)
- [useId()](#useid)
- [getCurrentInstance()](#getcurrentinstance)
- [defineAsyncComponent()](#defineasynccomponent)

---

## defineComponent()

Creates a component: a reusable piece of UI with its own state, props and events. Every component in
your game starts here.

- **Example**

  ```lua
  local Counter = Rivue.defineComponent({
  	name = "Counter",
  	props = {
  		start = { type = "number", default = 0 },
  	},
  	setup = function(props)
  		local count = Rivue.ref(props.start)
  		return {
  			count = count,
  			increment = function()
  				count.value += 1
  			end,
  		}
  	end,
  	render = function(ctx)
  		return h("TextButton", { Text = tostring(ctx.count), onClick = ctx.increment })
  	end,
  })

  -- The same, with setup returning the render function
  local Counter2 = Rivue.defineComponent(function(props)
  	local count = Rivue.ref(props.start or 0)
  	return function()
  		return h("TextButton", { Text = tostring(count.value) })
  	end
  end, { name = "Counter2" })
  ```

- **Details**

  - **`name`** shows up in errors, warnings, `printTree()`, and as the Explorer name of the
    component's root Instance.
  - **`setup`** runs once per instance. It returns either the render function, or a table of
    state for **`render`**.
  - **`render`** builds the component's UI from a [render context](#render). This is the
    recommended form: state lives in `setup`, markup in `render`.

  The other options are covered below.

- **Type**

  ```lua
  -- Options form
  function defineComponent(options: ComponentOptions): ComponentDef

  -- Setup function form
  function defineComponent(
  	setup: (props: Props, ctx: SetupContext) -> RenderFunction,
  	options: ComponentOptions?
  ): ComponentDef

  type ComponentOptions = {
  	name: string?,
  	props: PropSchema?,
  	emits: ({ string } | { [string]: (...any) -> boolean })?,
  	inheritAttrs: boolean?, -- default true
  	components: { [string]: Component }?,
  	styles: { [string]: { [string]: any } }?,
  	setup: ((props: Props, ctx: SetupContext) -> RenderFunction | { [string]: any })?,
  	render: ((ctx: RenderContext) -> VNode?)?,
  }

  type RenderFunction = () -> VNode? -- may also return a list of vnodes
  ```

---

## props

The inputs a component accepts from its parent, like function parameters. Declaring them lets Rivue
check types and required props in Studio, and fill in defaults.

- **Example**

  A health bar that validates what it's given:

  ```lua
  local HealthBar = Rivue.defineComponent({
  	name = "HealthBar",
  	props = {
  		current = { type = "number", required = true },
  		max = { type = "number", default = 100 },
  		color = { type = "Color3", default = Color3.fromRGB(80, 200, 90) },
  		size = { type = { "UDim2", "number" } }, -- either type is fine
  		mode = {
  			type = "string",
  			default = "bar",
  			validator = function(value)
  				return value == "bar" or value == "text"
  			end,
  		},
  	},
  	render = function(ctx)
  		if ctx.mode == "text" then
  			return h("TextLabel", { Text = `{ctx.current} / {ctx.max}` })
  		end
  		return h("Frame", {
  			Size = UDim2.fromScale(ctx.current / ctx.max, 1),
  			BackgroundColor3 = ctx.color,
  		})
  	end,
  })

  -- Position isn't declared, so it's passed through to the root Frame
  h(HealthBar, { current = 40, Position = UDim2.fromOffset(10, 10) })
  ```

- **Details**

  - **Reading props.** `props` is shallow reactive: read `props.x` in the render function (or a
    computed or watcher) to track it. Copying a prop into a local in `setup()` loses reactivity;
    use [`toRef()`](reactivity-utilities.md#toref) instead.
  - **Validation** runs in Studio and warns with the component's name: missing required props,
    wrong types, and validators returning `false`.
  - **Attrs.** Props that aren't declared become **attrs**. With a single root element they're
    applied to it, unless `inheritAttrs = false`. Without a `props` schema, every prop is a prop
    and there are no attrs.

- **Type**

  ```lua
  type PropSchema = { [string]: PropSpec }

  type PropSpec = {
  	type: (string | { string })?, -- type() or typeof() names: "number", "table", "UDim2", "Instance", ...
  	required: boolean?,
  	default: unknown?, -- use a function for table defaults
  	validator: ((value: any) -> boolean)?,
  }
  ```

---

## emits

The events a component can send to its parent, like `"select"` or `"close"`. The parent listens with
`onSelect`, `onClose` and so on.

- **Example**

  An inventory row that tells its parent when it's picked:

  ```lua
  local ItemRow = Rivue.defineComponent({
  	name = "ItemRow",
  	props = { item = { type = "table", required = true } },
  	emits = {
  		-- A validator: Studio warns if the payload is wrong
  		select = function(id)
  			return type(id) == "number"
  		end,
  	},
  	render = function(ctx)
  		return h("TextButton", {
  			Text = ctx.item.name,
  			onClick = function()
  				ctx.emit("select", ctx.item.id)
  			end,
  		})
  	end,
  })

  -- The parent listens with on + the event name
  h(ItemRow, {
  	item = { id = 3, name = "Sword" },
  	onSelect = function(id)
  		print("equip", id)
  	end,
  })
  ```

- **Details**

  The parent listens with an `on<Event>` prop: `ctx.emit("select", id)` calls `onSelect(id)`.
  Declared listeners don't become attrs, so they aren't passed on to the root element. In Studio,
  emitting an undeclared event, or a payload the validator rejects, warns.

- **Type**

  ```lua
  emits: { string } | { [string]: (...any) -> boolean }
  ```

---

## setup()

Where a component's state and logic live. It runs once, when the component appears, and returns what
the render function needs.

- **Example**

  A round timer: state, a frame callback and a function, handed to render:

  ```lua
  local RoundTimer = Rivue.defineComponent({
  	name = "RoundTimer",
  	props = { seconds = { type = "number", default = 90 } },
  	setup = function(props)
  		local left = Rivue.ref(props.seconds)
  		Rivue.onHeartbeat(function(dt) -- disconnected automatically on unmount
  			left.value = math.max(0, left.value - dt)
  		end)
  		return {
  			left = left,
  			restart = function()
  				left.value = props.seconds
  			end,
  		}
  	end,
  	render = function(ctx)
  		return h("TextButton", {
  			Text = string.format("%d:%02d", ctx.left // 60, ctx.left % 60),
  			onClick = ctx.restart,
  		})
  	end,
  })
  ```

- **Details**

  Create state and computeds here, register lifecycle hooks and watchers, then return either the
  render function or, with a [`render`](#render) option, a table of state and functions for it.
  Everything created in `setup()` lives in the component's effect scope and stops when
  it unmounts. If `setup()` errors, mounting fails, and the error names the component.

- **Type**

  ```lua
  setup: (props: Props, ctx: SetupContext) -> RenderFunction | { [string]: any }
  ```

- **Typed props**

  Annotate the `props` parameter to get autocomplete and type errors on typos. The runtime
  schema still validates values in Studio.

  ```lua
  type Props = { title: string, count: number }

  local Header = Rivue.defineComponent({
  	name = "Header",
  	props = {
  		title = { type = "string", required = true },
  		count = { type = "number", default = 0 },
  	},
  	setup = function(props: Props)
  		return function()
  			return h("TextLabel", { Text = `{props.title} ({props.count})` })
  		end
  	end,
  })
  ```

---

## render()

Describes what the component looks like, using what `setup()` returned and the props. It runs again
whenever the state it read changes, so keep it to building UI.

- **Example**

  ```lua
  local Toggle = Rivue.defineComponent({
  	name = "Toggle",
  	props = { label = { type = "string", default = "Sound" } },
  	emits = { "change" },
  	setup = function()
  		return { on = Rivue.ref(false) }
  	end,
  	render = function(ctx)
  		return h("TextButton", {
  			Text = `{ctx.label}: {if ctx.on then "ON" else "OFF"}`,
  			onClick = function()
  				ctx.on = not ctx.on
  				ctx.emit("change", ctx.on)
  			end,
  		})
  	end,
  })

  -- Without state
  local Divider = Rivue.defineComponent({
  	name = "Divider",
  	render = function()
  		return h("Frame", { Size = UDim2.new(1, 0, 0, 1) })
  	end,
  })
  ```

- **Details**

  `ctx` looks names up in this order:

  1. What `setup()` returned. Refs are unwrapped, so read `ctx.count`, not `ctx.count.value`.
  2. Props.
  3. The [setup context](#setup-context): `ctx.emit`, `ctx.slots`, `ctx.attrs`, `ctx.renderSlot`,
     `ctx.expose`.

  Assigning a name `setup()` returned as a ref sets the ref (`ctx.open = true`). Other
  assignments warn: props belong to the parent.

  Reads are tracked like any render, so the component re-renders when they change. For two-way
  binding, pass the ref's name: `model = "draft"` (see [Element props](render-function.md#element-props)).

- **Type**

  ```lua
  render: (ctx: RenderContext) -> VNode?
  ```

---

## components

Lists the components this one uses, so its render function can refer to them by name: `h("ItemRow",
...)`.

- **Example**

  ```lua
  local Badge = Rivue.defineComponent({
  	name = "Badge",
  	render = function(ctx)
  		return h("TextLabel", { Text = ctx.text })
  	end,
  })

  local Card = Rivue.defineComponent({
  	name = "Card",
  	components = { Badge = Badge },
  	render = function()
  		return h("Frame", { layout = "vertical" }, {
  			h("Badge", { text = "NEW" }),
  		})
  	end,
  })
  ```

- **Details**

  `h("Name")` looks the name up in the rendering component's `components` first, then in the
  app's (`app:component()`). Local registration keeps a file's dependencies at the top, next to
  its `require`s.

- **Type**

  ```lua
  components: { [string]: Component }
  ```

---

## styles

Style classes that only this component uses, applied with the
[`class`](render-function.md#element-props) prop. They take priority over app-wide styles.

- **Example**

  ```lua
  local Alert = Rivue.defineComponent({
  	name = "Alert",
  	styles = {
  		box = { BackgroundColor3 = Color3.fromRGB(120, 30, 30), cornerRadius = 6, padding = 8 },
  		message = { TextColor3 = Color3.new(1, 1, 1), TextSize = 16 },
  	},
  	render = function(ctx)
  		return h("Frame", { class = "box", Size = UDim2.fromOffset(300, 40) }, {
  			h("TextLabel", { class = "message", Text = ctx.text }),
  		})
  	end,
  })
  ```

- **Details**

  A class is a table of props: Instance properties and modifier props such as `cornerRadius`,
  `padding` and `layout`. A class name resolves from the component's `styles` first, then the
  app's ([`app:styles()`](application.md#appstyles)). The element's own props always win.

- **Type**

  ```lua
  styles: { [className: string]: { [prop: string]: any } }
  ```

---

## Setup context

The second argument of `setup()`: your component's toolbox for emitting events, rendering slots and
reading attrs.

- **Example**

  A confirm dialog that emits, exposes a method, renders its slot and reads a global:

  ```lua
  local ConfirmDialog = Rivue.defineComponent({
  	name = "ConfirmDialog",
  	emits = { "confirm", "cancel" },
  	setup = function(_props, ctx)
  		local function cancel()
  			ctx.emit("cancel")
  		end
  		-- A parent holding a template ref to this dialog can call dialog.cancel()
  		ctx.expose({ cancel = cancel })
  		return { cancel = cancel }
  	end,
  	render = function(ctx)
  		return h("Frame", { class = "dialog", layout = { gap = 8 } }, {
  			ctx.renderSlot("default"),
  			h("TextButton", {
  				Text = if ctx.globals.locale == "fr" then "Confirmer" else "Confirm",
  				onClick = function()
  					ctx.emit("confirm")
  				end,
  			}),
  			h("TextButton", { Text = "Cancel", onClick = ctx.cancel }),
  		})
  	end,
  })
  ```

- **Details**

  | Field | Description |
  |-------|-------------|
  | `emit` | Calls the parent's `on<Event>` handler, see [emits](#emits) |
  | `attrs` | Undeclared props (reactive) |
  | `slots` | The default slot: array children passed to the component |
  | `renderSlot` / `hasSlot` | Named and scoped slots, see [Slots](#slots) |
  | `expose` | What a [template ref](#usetemplateref) to this component receives |
  | `provide` / `inject` | Same as the standalone [`provide()`](#provide) and [`inject()`](#inject) |
  | `globals` | `app.config.globalProperties` |
  | `onUnmounted` | Same as [`onUnmounted()`](lifecycle.md#onunmounted) |

- **Type**

  ```lua
  type SetupContext = {
  	emit: (event: string, ...any) -> (),
  	attrs: Props,
  	slots: { Child },
  	renderSlot: (name: string, scope: any?, fallback: { Child }?) -> { Child },
  	hasSlot: (name: string) -> boolean,
  	expose: (exposed: { [string]: unknown }?) -> (),
  	provide: (key: string, value: unknown) -> (),
  	inject: (key: string, default: unknown?) -> unknown?,
  	globals: { [string]: unknown }, -- app.config.globalProperties
  	onUnmounted: (fn: () -> ()) -> (),
  }
  ```

---

## Slots

How a parent passes UI into a component, for wrappers like panels, cards and modals. Children in a
list are the default slot; named functions fill named areas, and can receive data from the child.

- **Example**

  A card with a scoped header slot, a default slot and a footer with a fallback:

  ```lua
  local Card = Rivue.defineComponent({
  	name = "Card",
  	props = { title = { type = "string" } },
  	render = function(ctx)
  		return h("Frame", { class = "card", layout = { gap = 6 } }, {
  			ctx.renderSlot("header", { title = ctx.title }), -- the slot receives { title }
  			ctx.renderSlot("default"),
  			ctx.renderSlot("footer", nil, { h("TextLabel", { Text = "No footer" }) }),
  		})
  	end,
  })

  h(Card, { title = "Shop" }, {
  	header = function(scope)
  		return h("TextLabel", { Text = scope.title, TextSize = 20 })
  	end,
  	default = function()
  		return { h("TextLabel", { Text = "Daily deals refresh in 3h" }) }
  	end,
  })
  ```

- **Details**

  `renderSlot` returns a new list every time:
  - It's the fallback when the parent didn't pass that slot.
  - `"default"` falls back to the array children.
  - Lists can go straight into children.

  Slot functions run during the child's render, so reactive reads inside them re-render the
  child.

- **Type**

  ```lua
  -- Passing (parent)
  h(Component, props, { Child })                            -- default slot
  h(Component, props, { [string]: (scope: any) -> Children }) -- named slots

  -- Rendering (child)
  ctx.renderSlot(name: string, scope: any?, fallback: { Child }?): { Child }
  ctx.hasSlot(name: string): boolean
  ```

---

## provide()

Makes a value available to every component below this one, without passing it as a prop through each
level. Descendants read it with [`inject()`](#inject).

- **Example**

  Share one sound player with the whole screen, without passing it down as a prop:

  ```lua
  local GameScreen = Rivue.defineComponent({
  	name = "GameScreen",
  	setup = function()
  		Rivue.provide("sounds", {
  			play = function(name: string)
  				local sound = game:GetService("SoundService"):FindFirstChild(name) :: Sound?
  				if sound then
  					sound:Play()
  				end
  			end,
  		})
  		return {}
  	end,
  	render = function()
  		return h("Frame", nil, { h(ShopPanel), h(InventoryPanel) })
  	end,
  })
  ```

- **Details**

  Call it in `setup()`. Provide a ref or reactive table to make the value reactive for
  injectors. For app-wide values, use [`app:provide()`](application.md#appprovide).

- **Type**

  ```lua
  function provide(key: unknown, value: unknown)
  ```

---

## inject()

Reads a value that an ancestor component (or the app) provided.

- **Example**

  Any component under GameScreen can use it. The second argument is the fallback:

  ```lua
  local BuyButton = Rivue.defineComponent({
  	name = "BuyButton",
  	setup = function()
  		local sounds = Rivue.inject("sounds", { play = function() end })
  		return {
  			buy = function()
  				sounds.play("Purchase")
  			end,
  		}
  	end,
  	render = function(ctx)
  		return h("TextButton", { Text = "Buy", onClick = ctx.buy })
  	end,
  })
  ```

- **Details**

  The key is looked up through ancestors first, then in the app's provides. Returns `default` if
  nothing was provided. A component's own `provide()` doesn't change what it injects, so it can
  read a value and provide a changed one to its children (a nesting depth, for example). Call it in `setup()` or inside
  [`app:runWithContext()`](application.md#apprunwithcontext).

- **Type**

  ```lua
  function inject<T>(key: unknown, default: T?): T?
  ```

---

## hasInjectionContext()

Tells you whether [`inject()`](#inject) would work right now, which is inside `setup()` or
`app:runWithContext()`. Useful in composables that can also be called from plain code.

- **Example**

  ```lua
  local function useLogger()
  	if Rivue.hasInjectionContext() then
  		return Rivue.inject("logger", print)
  	end
  	return print
  end
  ```

- **Type**

  ```lua
  function hasInjectionContext(): boolean
  ```

---

## useTemplateRef()

Gives setup access to a real Instance (or child component) from render. Mark the element with `ref =
"name"`, and the ref holds it while it's mounted. Use it for focus, sizes and tweens.

- **Example**

  Focus a TextBox when the search panel opens:

  ```lua
  local SearchPanel = Rivue.defineComponent({
  	name = "SearchPanel",
  	setup = function()
  		local input = Rivue.useTemplateRef("input")
  		Rivue.onMounted(function()
  			(input.value :: TextBox):CaptureFocus()
  		end)
  		return {}
  	end,
  	render = function()
  		return h("Frame", { layout = "vertical" }, {
  			h("TextBox", { ref = "input", PlaceholderText = "Search" }),
  		})
  	end,
  })
  ```

- **Details**

  - **When it's set.** The ref is set before `onMounted` runs, and reset to `nil` on unmount.
  - **What it holds.** For a component it holds what the component passed to
    [`ctx.expose()`](#setup-context), or its instance.
  - **Other forms of `ref`.** The `ref` prop also accepts a ref object (`ref = myRef`) or a
    function (called with the Instance, then with `nil`).

- **Type**

  ```lua
  function useTemplateRef<T>(name: string): Ref<T?>
  ```

---

## useAttrs()

The props passed to this component that it didn't declare, same as `ctx.attrs`.

- **Example**

  A labelled button whose extra props go to the button, not the outer frame:

  ```lua
  local LabeledButton = Rivue.defineComponent({
  	name = "LabeledButton",
  	props = { label = { type = "string", required = true } },
  	inheritAttrs = false, -- don't put attrs on the root
  	setup = function()
  		return { attrs = Rivue.useAttrs() }
  	end,
  	render = function(ctx)
  		return h("Frame", { layout = { direction = "horizontal", gap = 6 } }, {
  			h("TextLabel", { Text = ctx.label }),
  			h("TextButton", Rivue.mergeProps(ctx.attrs, { Text = "Go" })),
  		})
  	end,
  })

  -- onClick and BackgroundColor3 land on the inner TextButton
  h(LabeledButton, { label = "Teleport", onClick = function() end, BackgroundColor3 = Color3.new(0, 1, 0) })
  ```

- **Type**

  ```lua
  function useAttrs(): Props
  ```

---

## useSlots()

The children passed to this component, same as `ctx.slots`.

- **Example**

  A list wrapper that lays out whatever children it's given:

  ```lua
  local Stack = Rivue.defineComponent({
  	name = "Stack",
  	setup = function()
  		return { children = Rivue.useSlots() }
  	end,
  	render = function(ctx)
  		return h("Frame", { layout = { gap = 8 } }, table.clone(ctx.children))
  	end,
  })

  h(Stack, nil, { h("TextLabel", { Text = "One" }), h("TextLabel", { Text = "Two" }) })
  ```

- **Type**

  ```lua
  function useSlots(): { Child }
  ```

---

## defineModel()

Lets your own component support `model`, like a TextBox does. It gives you a ref: reading it gets
the parent's value, writing it updates the parent.

- **Example**

  A settings toggle that works with `model`, like a TextBox does:

  ```lua
  local useModel = Rivue.defineModel()

  local SettingToggle = Rivue.defineComponent({
  	name = "SettingToggle",
  	props = { label = { type = "string", required = true } },
  	setup = function(props, ctx)
  		return { on = useModel(props, ctx) }
  	end,
  	render = function(ctx)
  		return h("TextButton", {
  			Text = `{ctx.label}: {if ctx.on then "ON" else "OFF"}`,
  			onClick = function()
  				ctx.on = not ctx.on -- updates the parent's ref
  			end,
  		})
  	end,
  })

  local musicEnabled = Rivue.ref(true)
  h(SettingToggle, { label = "Music", model = musicEnabled })
  ```

- **Details**

  Call `defineModel()` once at module level, then call the result in `setup()`. The ref:
  - reads `props.modelValue`,
  - emits `"update:modelValue"` when written.

  `name` changes the prop and `event` changes the event name.

  The parent binds it with `model = someRef`, which passes `modelValue` and the update handler
  for you.

- **Type**

  ```lua
  function defineModel<T>(options: { name: string?, event: string? }?): (props: Props, ctx: SetupContext) -> Ref<T>
  ```

---

## useModel()

The same ref as [`defineModel()`](#definemodel), in one call inside `setup()`. Matches Vue's
`useModel`.

- **Example**

  A volume slider the parent binds with `model`:

  ```lua
  local VolumeSlider = Rivue.defineComponent({
  	name = "VolumeSlider",
  	props = { modelValue = { type = "number", default = 50 } },
  	setup = function(props, ctx)
  		local volume = Rivue.useModel(props, ctx)
  		return {
  			volume = volume,
  			louder = function()
  				volume.value = math.min(100, volume.value + 10)
  			end,
  		}
  	end,
  	render = function(ctx)
  		return h("TextButton", { Text = `Volume {ctx.volume}`, onClick = ctx.louder })
  	end,
  })

  local volume = Rivue.ref(50)
  h(VolumeSlider, { model = volume })
  ```

- **Details**

  `name` picks another model prop, for example `useModel(props, ctx, "count")` reads `count` and
  emits `"update:count"`.

- **Type**

  ```lua
  function useModel<T>(props: Props, ctx: SetupContext, name: string?): Ref<T>
  ```

---

## useId()

A short id that's unique for this session, such as `"r12-1"`. Handy for naming Instances or linking
a label to its input.

- **Example**

  Give each tooltip Instance a unique name:

  ```lua
  local Tooltip = Rivue.defineComponent({
  	name = "Tooltip",
  	props = { text = { type = "string", required = true } },
  	setup = function()
  		return { id = Rivue.useId() }
  	end,
  	render = function(ctx)
  		return h("TextLabel", { Name = `Tooltip-{ctx.id}`, Text = ctx.text })
  	end,
  })
  ```

- **Details**

  In `setup()`, ids are based on the component's uid, so each instance gets its own. It's handy
  for unique Instance names, or keys for `CollectionService` or attributes.

- **Type**

  ```lua
  function useId(): string
  ```

---

## getCurrentInstance()

The component whose `setup()` is running right now, or `nil`. Mostly for library code; your own
components rarely need it.

- **Example**

  ```lua
  local function useComponentName(): string
  	local instance = Rivue.getCurrentInstance()
  	return if instance then instance.type.__name or "Anonymous" else "none"
  end
  ```

- **Details**

  For library code that needs instance internals. App code rarely needs it: prefer the setup
  context and composables.

- **Type**

  ```lua
  function getCurrentInstance(): ComponentInstance?
  ```

---

## defineAsyncComponent()

A component whose code is loaded only when it's first shown, with optional loading and error states.
Use it for big screens most players never open.

- **Example**

  ```lua
  local ShopPage = Rivue.defineAsyncComponent(function()
  	-- Yield until the module exists, e.g. streamed in
  	local module = game.ReplicatedStorage:WaitForChild("ShopPage")
  	return require(module) :: any
  end, {
  	loadingComponent = h("TextLabel", { Text = "Loading shop..." }),
  	errorComponent = h("TextLabel", { Text = "Couldn't load the shop" }),
  	delay = 200,
  	timeout = 10000,
  })

  h(ShopPage)
  ```

- **Details**

  The loader runs when the component first mounts. Inside a [`Suspense`](builtins.md#suspense)
  it also counts as pending, so Suspense shows its fallback until it loads.

- **Type**

  ```lua
  function defineAsyncComponent(
  	loader: () -> ComponentDef, -- may yield
  	options: {
  		loadingComponent: VNode?,
  		errorComponent: VNode?,
  		delay: number?, -- ms before showing loadingComponent
  		timeout: number?, -- ms before giving up
  	}?
  ): ComponentDef
  ```

---

[← Render Function](render-function.md) · [API reference](../API.md) · [Lifecycle Hooks →](lifecycle.md)
