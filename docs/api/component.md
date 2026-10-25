# Components

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
- [useId()](#useid)
- [getCurrentInstance()](#getcurrentinstance)
- [defineAsyncComponent()](#defineasynccomponent)

---

## defineComponent()

Defines a component.

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

- **Details**

  - **`name`** shows up in errors, warnings, `printTree()`, and as the Explorer name of the
    component's root Instance.
  - **`setup`** runs once per instance. It returns either the render function, or a table of
    state for **`render`**.
  - **`render`** builds the component's UI from a [render context](#render). This is the
    recommended form: state lives in `setup`, markup in `render`.

  The other options are covered below.

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

---

## props

Declares the props a component accepts.

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

- **Details**

  - **Reading props.** `props` is shallow reactive: read `props.x` in the render function (or a
    computed or watcher) to track it. Copying a prop into a local in `setup()` loses reactivity;
    use [`toRef()`](reactivity-utilities.md#toref) instead.
  - **Validation** runs in Studio and warns with the component's name: missing required props,
    wrong types, and validators returning `false`.
  - **Attrs.** Props that aren't declared become **attrs**. With a single root element they're
    applied to it, unless `inheritAttrs = false`. Without a `props` schema, every prop is a prop
    and there are no attrs.

- **Example**

  ```lua
  local HealthBar = Rivue.defineComponent({
  	name = "HealthBar",
  	props = {
  		current = { type = "number", required = true },
  		max = { type = "number", default = 100 },
  		color = { type = "Color3", default = Color3.fromRGB(80, 200, 90) },
  		tags = { type = "table", default = function() return {} end },
  		size = { type = { "UDim2", "number" } },
  		mode = {
  			type = "string",
  			validator = function(value)
  				return value == "bar" or value == "text"
  			end,
  		},
  	},
  	setup = function(props)
  		return function()
  			return h("Frame", {
  				Size = UDim2.fromScale(props.current / props.max, 1),
  				BackgroundColor3 = props.color,
  			})
  		end
  	end,
  })

  -- Position isn't declared, so it's an attr and lands on the root Frame
  h(HealthBar, { current = 40, Position = UDim2.fromOffset(10, 10) })
  ```

---

## emits

Declares the events a component emits.

- **Type**

  ```lua
  emits: { string } | { [string]: (...any) -> boolean }
  ```

- **Details**

  The parent listens with an `on<Event>` prop: `ctx.emit("select", id)` calls `onSelect(id)`.
  Declared listeners don't become attrs, so they aren't passed on to the root element. In Studio,
  emitting an undeclared event, or a payload the validator rejects, warns.

- **Example**

  ```lua
  local ItemRow = Rivue.defineComponent({
  	name = "ItemRow",
  	props = { id = { type = "number", required = true } },
  	emits = {
  		select = function(id)
  			return type(id) == "number"
  		end,
  	},
  	setup = function(props, ctx)
  		return function()
  			return h("TextButton", {
  				onClick = function()
  					ctx.emit("select", props.id)
  				end,
  			})
  		end
  	end,
  })

  h(ItemRow, {
  	id = 3,
  	onSelect = function(id)
  		print("selected", id)
  	end,
  })
  ```

---

## setup()

The component's entry point. Runs once per instance, before the first render.

- **Type**

  ```lua
  setup: (props: Props, ctx: SetupContext) -> RenderFunction | { [string]: any }
  ```

- **Details**

  Create state and computeds here, register lifecycle hooks and watchers, then return either the
  render function or, with a [`render`](#render) option, a table of state and functions for it.
  Everything created in `setup()` lives in the component's effect scope and stops when
  it unmounts. If `setup()` errors, mounting fails, and the error names the component.

- **Example**

  ```lua
  local Timer = Rivue.defineComponent({
  	name = "Timer",
  	setup = function()
  		local seconds = Rivue.ref(0)
  		Rivue.onHeartbeat(function(dt)
  			seconds.value += dt
  		end)
  		return function()
  			return h("TextLabel", { Text = string.format("%.1f", seconds.value) })
  		end
  	end,
  })
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

Builds the component's UI. Used with `setup()` returning a table, or alone for components
without state.

- **Type**

  ```lua
  render: (ctx: RenderContext) -> VNode?
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

---

## components

Registers components for use by name inside this component, like Vue's `components` option.

- **Type**

  ```lua
  components: { [string]: Component }
  ```

- **Details**

  `h("Name")` looks the name up in the rendering component's `components` first, then in the
  app's (`app:component()`). Local registration keeps a file's dependencies at the top, next to
  its `require`s.

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

---

## styles

Style classes used only inside this component, applied with the [`class`](render-function.md#element-props) prop.

- **Type**

  ```lua
  styles: { [className: string]: { [prop: string]: any } }
  ```

- **Details**

  A class is a table of props: Instance properties and modifier props such as `cornerRadius`,
  `padding` and `layout`. A class name resolves from the component's `styles` first, then the
  app's ([`app:styles()`](application.md#appstyles)). The element's own props always win.

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

---

## Setup context

The second argument of `setup()`.

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

- **Example**

  ```lua
  local Dialog = Rivue.defineComponent({
  	name = "Dialog",
  	emits = { "close" },
  	setup = function(_props, ctx)
  		local function close()
  			ctx.emit("close")
  		end
  		-- A parent holding a ref to this component can call dialog.close()
  		ctx.expose({ close = close })

  		return function()
  			return h("Frame", { Size = UDim2.fromOffset(300, 200) }, {
  				h("UIListLayout"),
  				ctx.renderSlot("default"),
  				h("TextButton", { Text = `Close ({ctx.globals.locale})`, onClick = close }),
  			})
  		end
  	end,
  })
  ```

---

## Slots

Pass UI into a component. Array children are the default slot. A table of functions passes named
slots, which can also receive data from the child (scoped slots).

- **Type**

  ```lua
  -- Passing (parent)
  h(Component, props, { Child })                            -- default slot
  h(Component, props, { [string]: (scope: any) -> Children }) -- named slots

  -- Rendering (child)
  ctx.renderSlot(name: string, scope: any?, fallback: { Child }?): { Child }
  ctx.hasSlot(name: string): boolean
  ```

- **Details**

  `renderSlot` returns a new list every time:
  - It's the fallback when the parent didn't pass that slot.
  - `"default"` falls back to the array children.
  - Lists can go straight into children.

  Slot functions run during the child's render, so reactive reads inside them re-render the
  child.

- **Example**

  ```lua
  local Card = Rivue.defineComponent({
  	name = "Card",
  	props = { title = { type = "string" } },
  	setup = function(props, ctx)
  		return function()
  			return h("Frame", { Size = UDim2.fromOffset(300, 200) }, {
  				h("UIListLayout"),
  				ctx.renderSlot("header", { title = props.title }),
  				ctx.renderSlot("default"),
  				ctx.renderSlot("footer", nil, { h("TextLabel", { Text = "No footer" }) }),
  			})
  		end
  	end,
  })

  h(Card, { title = "Shop" }, {
  	header = function(scope)
  		return h("TextLabel", { Text = scope.title })
  	end,
  	default = function()
  		return { h("TextLabel", { Text = "Body" }) }
  	end,
  })
  ```

---

## provide()

Provides a value that every descendant can [`inject()`](#inject).

- **Type**

  ```lua
  function provide(key: unknown, value: unknown)
  ```

- **Details**

  Call it in `setup()`. Provide a ref or reactive table to make the value reactive for
  injectors. For app-wide values, use [`app:provide()`](application.md#appprovide).

- **Example**

  ```lua
  local App = Rivue.defineComponent(function()
  	local theme = Rivue.reactive({ accent = Color3.fromRGB(60, 120, 220) })
  	Rivue.provide("theme", theme)
  	return function()
  		return h("Frame")
  	end
  end, { name = "App" })
  ```

---

## inject()

Gets a value provided by an ancestor component or the app.

- **Type**

  ```lua
  function inject<T>(key: unknown, default: T?): T?
  ```

- **Details**

  The key is looked up through ancestors first, then in the app's provides. Returns `default` if
  nothing was provided. Call it in `setup()` or inside
  [`app:runWithContext()`](application.md#apprunwithcontext).

- **Example**

  ```lua
  local Button = Rivue.defineComponent(function()
  	local theme = Rivue.inject("theme", { accent = Color3.new(1, 1, 1) })
  	return function()
  		return h("TextButton", { BackgroundColor3 = theme.accent })
  	end
  end, { name = "Button" })
  ```

---

## hasInjectionContext()

Returns `true` when [`inject()`](#inject) can be called here: inside `setup()` or
`app:runWithContext()`.

- **Type**

  ```lua
  function hasInjectionContext(): boolean
  ```

- **Example**

  ```lua
  local function useLogger()
  	if Rivue.hasInjectionContext() then
  		return Rivue.inject("logger", print)
  	end
  	return print
  end
  ```

---

## useTemplateRef()

Returns a ref that holds the element (or child component) rendered with a matching
`ref = "name"` prop.

- **Type**

  ```lua
  function useTemplateRef<T>(name: string): Ref<T?>
  ```

- **Details**

  - **When it's set.** The ref is set before `onMounted` runs, and reset to `nil` on unmount.
  - **What it holds.** For a component it holds what the component passed to
    [`ctx.expose()`](#setup-context), or its instance.
  - **Other forms of `ref`.** The `ref` prop also accepts a ref object (`ref = myRef`) or a
    function (called with the Instance, then with `nil`).

- **Example**

  ```lua
  local Search = Rivue.defineComponent(function()
  	local input = Rivue.useTemplateRef("input")

  	Rivue.onMounted(function()
  		(input.value :: TextBox):CaptureFocus()
  	end)

  	return function()
  		return h("TextBox", { ref = "input", PlaceholderText = "Search" })
  	end
  end, { name = "Search" })
  ```

---

## useAttrs()

Returns the component's attrs (undeclared props). The same table as `ctx.attrs`.

- **Type**

  ```lua
  function useAttrs(): Props
  ```

- **Example**

  ```lua
  local Wrapper = Rivue.defineComponent({
  	name = "Wrapper",
  	props = {},
  	inheritAttrs = false,
  	setup = function()
  		local attrs = Rivue.useAttrs()
  		return function()
  			-- Put the attrs on the inner element instead of the root
  			return h("Frame", nil, { h("TextButton", Rivue.mergeProps(attrs, { Text = "Inner" })) })
  		end
  	end,
  })
  ```

---

## useSlots()

Returns the default slot children. The same table as `ctx.slots`.

- **Type**

  ```lua
  function useSlots(): { Child }
  ```

- **Example**

  ```lua
  local List = Rivue.defineComponent(function()
  	local slots = Rivue.useSlots()
  	return function()
  		return h("Frame", nil, { h("UIListLayout"), table.clone(slots) })
  	end
  end, { name = "List" })
  ```

---

## defineModel()

Creates the ref behind a component's `model` binding.

- **Type**

  ```lua
  function defineModel<T>(options: { name: string?, event: string? }?): (props: Props, ctx: SetupContext) -> Ref<T>
  ```

- **Details**

  Call `defineModel()` once at module level, then call the result in `setup()`. The ref:
  - reads `props.modelValue`,
  - emits `"update:modelValue"` when written.

  `name` changes the prop and `event` changes the event name.

  The parent binds it with `model = someRef`, which passes `modelValue` and the update handler
  for you.

- **Example**

  ```lua
  local useModel = Rivue.defineModel()

  local Toggle = Rivue.defineComponent(function(props, ctx)
  	local on = useModel(props, ctx)
  	return function()
  		return h("TextButton", {
  			Text = if on.value then "ON" else "OFF",
  			onClick = function()
  				on.value = not on.value
  			end,
  		})
  	end
  end, { name = "Toggle" })

  local music = Rivue.ref(true)
  h(Toggle, { model = music })
  ```

---

## useId()

Returns an id string unique to the session, such as `"r12-1"`.

- **Type**

  ```lua
  function useId(): string
  ```

- **Details**

  In `setup()`, ids are based on the component's uid, so each instance gets its own. It's handy
  for unique Instance names, or keys for `CollectionService` or attributes.

- **Example**

  ```lua
  local Tooltip = Rivue.defineComponent(function()
  	local id = Rivue.useId()
  	return function()
  		return h("TextLabel", { Name = `Tooltip-{id}` })
  	end
  end, { name = "Tooltip" })
  ```

---

## getCurrentInstance()

Returns the component instance whose `setup()` is running, or `nil`.

- **Type**

  ```lua
  function getCurrentInstance(): ComponentInstance?
  ```

- **Details**

  For library code that needs instance internals. App code rarely needs it: prefer the setup
  context and composables.

- **Example**

  ```lua
  local function useComponentName(): string
  	local instance = Rivue.getCurrentInstance()
  	return if instance then instance.type.__name or "Anonymous" else "none"
  end
  ```

---

## defineAsyncComponent()

Defines a component whose definition is loaded on demand.

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

- **Details**

  The loader runs when the component first mounts. Inside a [`Suspense`](builtins.md#suspense)
  it also counts as pending, so Suspense shows its fallback until it loads.

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
