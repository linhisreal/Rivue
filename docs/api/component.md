[Docs](../README.md) › [API](../API.md) › **Components**

# Components

**Learn it:** [Guide 1: Introduction](../guide/01-introduction.md) · [Guide 4: Components](../guide/04-components.md)

Defining components, their options, and the functions used in `setup()`. Examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
local h = Rivue.h
```

---

## defineComponent()

Creates a component: a reusable piece of UI with its own state, props and events.

```lua signature
function defineComponent(options: ComponentOptions): ComponentDef
function defineComponent(setup: (props: Props, ctx: SetupContext) -> RenderFunction, options: ComponentOptions?): ComponentDef
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `options.name` | `string?` | | shown in errors, warnings, `printTree()`, DevTools, and as the Explorer name of its root Instance |
| `options.props` | `PropSchema?` | | see [props](#props) |
| `options.emits` | `{ string } \| { [string]: (...any) -> boolean }` | | see [emits](#emits) |
| `options.inheritAttrs` | `boolean` | `true` | put undeclared props on the root element |
| `options.components` | `{ [string]: Component }?` | | see [components](#components) |
| `options.styles` | `{ [string]: table }?` | | see [styles](#styles) |
| `options.setup` | `(props, ctx) -> RenderFunction \| table` | | see [setup()](#setup) |
| `options.render` | `(ctx: RenderContext) -> VNode?` | | see [render()](#render) |

**Returns** a `ComponentDef` to pass to `h()`.

> [!WARNING]
> A component needs `render`, or a `setup` that returns a render function. Otherwise mounting it
> errors.

### Example

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

-- the same, with setup returning the render function
local Counter2 = Rivue.defineComponent(function(props)
	local count = Rivue.ref(props.start or 0)
	return function()
		return h("TextButton", { Text = tostring(count.value) })
	end
end, { name = "Counter2" })
```

### Details

- `setup` plus `render` is the form these docs use: state in `setup`, markup in `render`.
- A render function can return a list of vnodes as well as one.

---

## setup()

Where a component's state and logic live. It runs once, when the component appears, and returns
what render needs.

```lua signature
setup: (props: Props, ctx: SetupContext) -> RenderFunction | { [string]: any }
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `props` | `Props` | | the component's props; annotate it for autocomplete |
| `ctx` | `SetupContext` | | see [Setup context](#setup-context) |

**Returns** the render function, or, with a [`render`](#render) option, a table of state and
functions for it.

> [!NOTE]
> Everything made in `setup()` lives in the component's effect scope and stops on unmount. If
> `setup()` errors, mounting fails and the error names the component.

### Example

```lua
local RoundTimer = Rivue.defineComponent({
	name = "RoundTimer",
	props = { seconds = { type = "number", default = 90 } },
	setup = function(props)
		local left = Rivue.ref(props.seconds)
		Rivue.onHeartbeat(function(dt) -- disconnected on unmount
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

Typed props, for autocomplete and type errors on typos. The schema still checks values in Studio:

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

Describes what the component looks like, from what `setup()` returned and the props. It runs again
whenever state it read changes, so it should only build UI.

```lua signature
render: (ctx: RenderContext) -> VNode?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `ctx` | `RenderContext` | | looks names up in what `setup()` returned (refs unwrapped), then props, then the [setup context](#setup-context) |

> [!WARNING]
> Assigning a name `setup()` returned as a ref sets the ref (`ctx.open = true`). Any other
> assignment warns: props belong to the parent.

### Example

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

-- without state
local Divider = Rivue.defineComponent({
	name = "Divider",
	render = function()
		return h("Frame", { Size = UDim2.new(1, 0, 0, 1) })
	end,
})
```

### Details

- Read `ctx.count`, not `ctx.count.value`. For two-way binding, pass the ref's name:
  `model = "draft"` (see [Element props](render-function.md#element-props)).

---

## Slots

How a parent passes UI into a component, for wrappers like panels, cards and modals. Array children
are the default slot; named functions fill named areas and can get data from the child.

```lua signature
ctx.renderSlot(name: string, scope: any?, fallback: { Child }?): { Child }
ctx.hasSlot(name: string): boolean

-- passing them, in the parent
h(Component, props, { Child })                            -- default slot
h(Component, props, { [string]: (scope: any) -> Children }) -- named slots
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | the slot; `"default"` falls back to the array children |
| `scope` | `any?` | | passed to the slot function |
| `fallback` | `{ Child }?` | | rendered when the parent didn't pass that slot |

**Returns** `renderSlot` returns a new list each time, which can go straight into children.

### Example

```lua
local Card = Rivue.defineComponent({
	name = "Card",
	props = { title = { type = "string" } },
	render = function(ctx)
		return h("Frame", { class = "card", layout = { gap = 6 } }, {
			ctx.renderSlot("header", { title = ctx.title }), -- the slot gets { title }
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

### Details

- Slot functions run during the child's render, so reactive reads inside them re-render the child.

---

## provide()

_setup() only_

Makes a value available to every component below this one, without passing it through each level.
Descendants read it with [`inject()`](#inject).

```lua signature
function provide(key: unknown, value: unknown)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `key` | `unknown` | | what descendants inject by |
| `value` | `unknown` | | provide a ref or reactive table to make it reactive for injectors |

> [!NOTE]
> For app-wide values, use [`app:provide()`](application.md#appprovide).

### Example

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

---

## inject()

Reads a value an ancestor component, or the app, provided.

```lua signature
function inject<T>(key: unknown, default: T?): T?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `key` | `unknown` | | looked up through ancestors first, then the app |
| `default` | `T?` | | returned when nothing was provided |

> [!WARNING]
> Call it in `setup()` or [`app:runWithContext()`](application.md#apprunwithcontext); anywhere
> else it errors.

### Example

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

### Details

- A component's own `provide()` doesn't change what it injects, so it can read a value and provide
  a changed one to its children, such as a nesting depth.

---

## hasInjectionContext()

Whether [`inject()`](#inject) would work right now: inside `setup()` or `app:runWithContext()`. For
composables that can also be called from plain code.

```lua signature
function hasInjectionContext(): boolean
```

### Example

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

_setup() only_

Gives setup a real Instance, or a child component, from render. Mark the element with
`ref = "name"`; the ref holds it while it's mounted. For focus, sizes and tweens.

```lua signature
function useTemplateRef<T>(name: string): Ref<T?>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | the `ref` name used in render |

**Returns** a ref, set before `onMounted` runs and reset to `nil` on unmount. For a component it
holds what the component passed to [`ctx.expose()`](#setup-context), or its instance.

### Example

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

### Details

- The `ref` prop also takes a ref object (`ref = myRef`), or a function called with the Instance
  and later with `nil`.

---

## useAttrs()

_setup() only_

The props passed to this component that it didn't declare; the same as `ctx.attrs`.

```lua signature
function useAttrs(): Props
```

### Example

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

---

## useSlots()

_setup() only_

The children passed to this component; the same as `ctx.slots`.

```lua signature
function useSlots(): { Child }
```

### Example

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

---

## defineModel()

Lets your own component take `model`, as a TextBox does. It gives you a ref: reading it gets the
parent's value, and writing it updates the parent.

```lua signature
function defineModel<T>(options: { name: string?, event: string? }?): (props: Props, ctx: SetupContext) -> Ref<T>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `options.name` | `string` | `"modelValue"` | the prop the model reads |
| `options.event` | `string` | `"update:" .. name` | the event emitted on write |

**Returns** a function to call in `setup()` with `(props, ctx)`. Call `defineModel()` itself once,
at module level.

> [!NOTE]
> If the parent passes no `model`, the ref keeps its own value, as in Vue 3.4, so the component
> also works on its own.

### Example

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

Several models on one component, like Vue's `v-model:title`; the parent binds them with `models`:

```lua
local useColor = Rivue.defineModel({ name = "color" })
local useOpacity = Rivue.defineModel({ name = "opacity" })

local ColorPicker = Rivue.defineComponent({
	name = "ColorPicker",
	props = { color = {}, opacity = {} },
	setup = function(props, ctx)
		return { color = useColor(props, ctx), opacity = useOpacity(props, ctx) }
	end,
	render = function(ctx)
		return h("Frame", { BackgroundColor3 = ctx.color, BackgroundTransparency = 1 - ctx.opacity })
	end,
})

local trailColor = Rivue.ref(Color3.fromRGB(255, 120, 0))
local trailOpacity = Rivue.ref(0.8)
h(ColorPicker, { models = { color = trailColor, opacity = trailOpacity } })
```

### Details

- `model = someRef` passes `modelValue` and the update handler for you. A value in `models` can
  also be the name of a ref `setup()` returned, as with `model`.

---

## useModel()

The same ref as [`defineModel()`](#definemodel), in one call inside `setup()`. Matches Vue's
`useModel`.

```lua signature
function useModel<T>(props: Props, ctx: SetupContext, name: string?): Ref<T>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `props` | `Props` | | the component's props |
| `ctx` | `SetupContext` | | the setup context |
| `name` | `string?` | `"modelValue"` | the model prop; `"count"` reads `count` and emits `"update:count"` |

### Example

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

---

## useId()

A short id that's unique for the session, such as `"r12-1"`. For unique Instance names, or keys for
CollectionService and attributes.

```lua signature
function useId(): string
```

**Returns** an id. In `setup()` it's based on the component's uid, so each instance gets its own.

### Example

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

---

## getCurrentInstance()

The component whose `setup()` is running, or `nil`. For library code; in app code the setup context
and composables cover what it's usually wanted for.

```lua signature
function getCurrentInstance(): ComponentInstance?
```

### Example

```lua
local function useComponentName(): string
	local instance = Rivue.getCurrentInstance()
	return if instance then instance.type.__name or "Anonymous" else "none"
end
```

---

## defineAsyncComponent()

A component whose code loads only when it's first shown, with optional loading and error states.
For big screens most players never open.

```lua signature
function defineAsyncComponent(loader: () -> ComponentDef, options: AsyncComponentOptions?): ComponentDef
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `loader` | `() -> ComponentDef` | | may yield; runs when the component first mounts |
| `options.loadingComponent` | `VNode?` | | shown while loading |
| `options.errorComponent` | `VNode?` | | shown when loading fails |
| `options.delay` | `number?` | | milliseconds before showing `loadingComponent` |
| `options.timeout` | `number?` | | milliseconds before an attempt counts as failed |
| `options.onError` | `(err, retry, fail, attempts) -> ()` | | decide what a failure does: `retry()` runs the loader again, `fail()` shows the error; `attempts` starts at 1 |

### Example

```lua
local ShopPage = Rivue.defineAsyncComponent(function()
	-- yield until the module exists, e.g. streamed in
	local module = game.ReplicatedStorage:WaitForChild("ShopPage")
	return require(module) :: any
end, {
	loadingComponent = h("TextLabel", { Text = "Loading shop..." }),
	errorComponent = h("TextLabel", { Text = "Couldn't load the shop" }),
	delay = 200,
	timeout = 10000,
	-- a dropped connection shouldn't strand the player on an error, so try three times
	onError = function(_err, retry, fail, attempts)
		if attempts < 3 then
			task.wait(1)
			retry()
		else
			fail()
		end
	end,
})

h(ShopPage)
```

### Details

- Copies mounted while it's loading share the load; once loaded, new copies render straight away.
- Without `onError`, a failed load shows `errorComponent` at once. A timeout counts as a failure.
  If the load finishes after the error is showing, the component replaces the error, as in Vue.
- Inside a [`Suspense`](builtins.md#suspense) it counts as pending until it loads or gives up.

---

## useAsync()

Runs something that yields, like a RemoteFunction call, and keeps its result, loading state and
error in refs. For RivueRemote, [`Remote.useRequest()`](remote.md#remoteuserequest) wraps it.

```lua signature
function useAsync<T>(fn: (...any) -> T, options: AsyncOptions<T>?): AsyncState<T>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fn` | `(...any) -> T` | | the work; may yield; what it throws goes into `error` |
| `options.immediate` | `boolean` | `true` | run straight away with `args` |
| `options.args` | `{ any }?` | | arguments for the first run |
| `options.initial` | `T?` | | `data` until the first result |
| `options.suspense` | `boolean` | `true` | hold a surrounding `Suspense` on its fallback until the first result |
| `options.silent` | `boolean` | `false` | don't warn about failures in Studio |

**Returns** `{ data, loading, error, run, refresh }`: three refs, `run(...)` to run again with new
arguments, and `refresh()` to repeat the last ones.

> [!NOTE]
> Only the newest run's result lands, so a slow answer to an old request never overwrites a newer
> one. After a failure, `data` keeps its last good value. Called in `setup()`, results that arrive
> after unmount are dropped.

### Example

```lua
local function fetchItems(category: string): { string }
	task.wait(0.1) -- stands in for a request to the server
	return { `{category} sword`, `{category} shield` }
end

local Shop = Rivue.defineComponent({
	name = "Shop",
	setup = function()
		local items = Rivue.useAsync(fetchItems, { args = { "Iron" }, initial = {} })
		return { items = items.data, loading = items.loading, failed = items.error, retry = items.refresh }
	end,
	render = function(ctx)
		if ctx.loading then
			return h("TextLabel", { Text = "Loading..." })
		elseif ctx.failed then
			return h("TextButton", { Text = "Couldn't load, tap to retry", onClick = ctx.retry })
		end
		return h("TextLabel", { Text = table.concat(ctx.items, ", ") })
	end,
})
```

### Details

- Inside a [Suspense](builtins.md#suspense), one loading screen covers every `useAsync` under it. A
  failed load stays in `error` and doesn't fail the Suspense.

---

## props

The inputs a component takes from its parent. Declaring them lets Rivue check types and required
props in Studio, and fill in defaults.

```lua signature
props: PropSchema

type PropSchema = { [string]: PropSpec }

type PropSpec = {
	type: (string | { string })?,
	required: boolean?,
	default: unknown?,
	validator: ((value: any) -> boolean)?,
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `type` | `string \| { string }` | | `type()` or `typeof()` names: `"number"`, `"table"`, `"UDim2"`, `"Instance"`, ...; a list allows any of them |
| `required` | `boolean` | `false` | warn when it's missing |
| `default` | `unknown` | | the value when it's missing; use a function for a table default |
| `validator` | `(value) -> boolean` | | warn when it returns `false` |

> [!WARNING]
> `props` is shallow reactive. Read `props.x` where it's used, in render, a computed or a watcher.
> Copying it into a local in `setup()` takes a snapshot that never updates; use
> [`toRef()`](reactivity-utilities.md#toref) instead.

### Example

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

-- Position isn't declared, so it goes to the root Frame
h(HealthBar, { current = 40, Position = UDim2.fromOffset(10, 10) })
```

### Details

- Validation runs in Studio only, and warns with the component's name.
- Props that aren't declared are attrs. With one root element they're put on it, unless
  `inheritAttrs = false`. Without a `props` schema, every prop is a prop and there are no attrs.

---

## emits

The events a component sends to its parent, like `"select"` or `"close"`. The parent listens with
`onSelect`, `onClose` and so on.

```lua signature
emits: { string } | { [string]: (...any) -> boolean }
```

| Field | Type | Default | Description |
|---|---|---|---|
| list form | `{ string }` | | the event names |
| map form | `{ [string]: (...any) -> boolean }` | | names to validators; Studio warns when a validator returns `false` |

> [!NOTE]
> In Studio, emitting an undeclared event warns. After the component unmounts, `emit` does
> nothing, as in Vue.

### Example

```lua
local ItemRow = Rivue.defineComponent({
	name = "ItemRow",
	props = { item = { type = "table", required = true } },
	emits = {
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

h(ItemRow, {
	item = { id = 3, name = "Sword" },
	onSelect = function(id)
		print("equip", id)
	end,
})
```

### Details

- `ctx.emit("select", id)` calls the parent's `onSelect(id)`. Kebab-case works as in Vue:
  `ctx.emit("change-value", v)` calls `onChangeValue(v)`.
- Declared listeners aren't attrs, so they don't reach the root element.

---

## components

The components this one uses, so its render can name them: `h("ItemRow", ...)`.

```lua signature
components: { [string]: Component }
```

### Example

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

### Details

- `h("Name")` looks in the rendering component's `components` first, then the app's
  (`app:component()`).

---

## styles

Style classes only this component uses, applied with the [`class`](render-function.md#element-props)
prop. They win over app-wide styles.

```lua signature
styles: { [className: string]: { [prop: string]: any } }
```

### Example

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

### Details

- A class holds Instance properties and Rivue props such as `cornerRadius`, `padding` and
  `layout`, plus the variants described in [app:styles()](application.md#appstyles). The
  element's own props always win.

---

## Setup context

The second argument of `setup()`, also readable from `ctx` in render.

```lua signature
type SetupContext = {
	emit: (event: string, ...any) -> (),
	attrs: Props,
	slots: { Child },
	renderSlot: (name: string, scope: any?, fallback: { Child }?) -> { Child },
	hasSlot: (name: string) -> boolean,
	expose: (exposed: { [string]: unknown }?) -> (),
	provide: (key: string, value: unknown) -> (),
	inject: (key: string, default: unknown?) -> unknown?,
	globals: { [string]: unknown },
	onUnmounted: (fn: () -> ()) -> (),
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `emit` | `(event, ...) -> ()` | | calls the parent's `on<Event>` handler; see [emits](#emits) |
| `attrs` | `Props` | | undeclared props, reactive |
| `slots` | `{ Child }` | | the default slot: array children passed to the component |
| `renderSlot`, `hasSlot` | | | named and scoped slots; see [Slots](#slots) |
| `expose` | `(exposed) -> ()` | | what a [template ref](#usetemplateref) to this component gets |
| `provide`, `inject` | | | the same as [`provide()`](#provide) and [`inject()`](#inject) |
| `globals` | `{ [string]: unknown }` | | `app.config.globalProperties` |
| `onUnmounted` | `(fn) -> ()` | | the same as [`onUnmounted()`](lifecycle.md#onunmounted) |

### Example

```lua
local ConfirmDialog = Rivue.defineComponent({
	name = "ConfirmDialog",
	emits = { "confirm", "cancel" },
	setup = function(_props, ctx)
		local function cancel()
			ctx.emit("cancel")
		end
		-- a parent holding a template ref to this dialog can call dialog.cancel()
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

---

[← Render function](render-function.md) · [API reference](../API.md) · [Lifecycle hooks →](lifecycle.md)
