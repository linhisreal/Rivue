# Rivue API Reference

Everything below is on the module returned by `require(game.ReplicatedStorage.Rivue)`.
Examples assume `local h = Rivue.h`. New to Rivue? Start with the [guide](GUIDE.md).

- [Reactivity](#reactivity)
- [Watchers and effects](#watchers-and-effects)
- [Virtual nodes](#virtual-nodes)
- [Element props](#element-props)
- [Components](#components)
- [Lifecycle hooks](#lifecycle-hooks)
- [Slots](#slots)
- [Provide / inject](#provide--inject)
- [Built-in components](#built-in-components)
- [Apps and mounting](#apps-and-mounting)
- [Directives](#directives)
- [Composables](#composables)
- [Roblox composables](#roblox-composables)
- [Scheduler](#scheduler)
- [Remote](#remote)
- [Instance pool](#instance-pool)
- [Utilities and debugging](#utilities-and-debugging)
- [Types](#types)

---

## Reactivity

### `ref(value)`

```lua
ref<T>(value: T): Ref<T>
```

A reactive box. Read and write through `.value`. Tables are made deeply reactive.

```lua
local count = Rivue.ref(0)
count.value += 1
```

### `shallowRef(value)`

Like `ref`, but only replacing `.value` is tracked. Mutating the table inside doesn't trigger
anything (call `triggerRef(r)` if you need to). Use it for large data and for values that
shouldn't be proxied, like Instances or component definitions.

### `reactive(table)` / `shallowReactive(table)`

```lua
reactive<T>(target: T): T
```

Returns a proxy that tracks reads and triggers on writes, including added and removed keys.
`reactive` wraps nested tables when you read them. `shallowReactive` only tracks the top level.

```lua
local state = Rivue.reactive({ coins = 0, items = {} })
state.coins += 10
state.items[#state.items + 1] = "Sword"
```

**Iterating proxies.** Luau has no `__pairs`/`__ipairs`, so `pairs()`, `ipairs()` and the
`table.*` functions see an empty table. Use generalized iteration or a numeric loop:

```lua
for key, value in state do end            -- __iter, tracks added/removed keys
for i = 1, #list do local v = list[i] end -- __len + index reads
list[#list + 1] = value                   -- instead of table.insert
```

### `readonly(table)` / `shallowReadonly(table)`

A read-only view of a table or reactive object. Writes are ignored (and logged in Studio).
Reads are still tracked when the source is reactive.

### `computed(getter)` / `computed({ get, set })`

```lua
computed<T>(getter: () -> T): ComputedRef<T>
computed<T>(options: { get: () -> T, set: (T) -> () }): ComputedRef<T>
```

A cached derived value. It recomputes lazily when something it read changes.

```lua
local total = Rivue.computed(function()
	return price.value * quantity.value
end)

local fullName = Rivue.computed({
	get = function() return first.value .. " " .. last.value end,
	set = function(v) first.value, last.value = string.match(v, "(%S+) (%S+)") end,
})
```

### `customRef(factory)`

```lua
customRef<T>(factory: (track: () -> (), trigger: () -> ()) -> { get: () -> T, set: (T) -> () }): Ref<T>
```

A ref where you control when it's tracked and triggered. This is useful for debounced values.

### Ref and proxy helpers

| Function | Description |
|----------|-------------|
| `isRef(v)` | `true` for refs and computeds |
| `unref(v)` | `v.value` if `v` is a ref, otherwise `v` |
| `toValue(v)` | Like `unref`, and also calls getter functions |
| `toRef(obj, key)` | A ref bound to `obj[key]` |
| `toRefs(obj)` | A table of refs, one per key. Use it to destructure reactive objects |
| `triggerRef(r)` | Forces effects that read a `shallowRef` to run |
| `isReactive(v)` / `isReadonly(v)` / `isProxy(v)` / `isShallow(v)` | Type checks |
| `toRaw(proxy)` | The underlying table |
| `markRaw(table)` | Never wrap this table in a proxy |

---

## Watchers and effects

### `watch(source, callback, options?)`

```lua
watch<T>(source: WatchSource<T>, cb: (new: T, old: T?, onCleanup: OnCleanup) -> (), options: WatchOptions?): WatchHandle
```

`source` can be:
- a getter function,
- a ref,
- a reactive object (watched deeply),
- or an array of these (the callback gets arrays of new and old values).

| Option | Default | Description |
|--------|---------|-------------|
| `immediate` | `false` | Run the callback right away |
| `deep` | `false` | Traverse nested tables (on by default for reactive objects). A number limits the depth |
| `flush` | `"pre"` | `"pre"`: deferred, before component updates. `"post"`: next Heartbeat. `"sync"`: immediately |
| `once` | `false` | Stop after the first callback |

The handle stops the watcher when you call it (or `handle.stop()`). `handle.pause()` /
`handle.resume()` suspend it. Changes made while paused run once on resume. Watchers created in
`setup()` stop when the component unmounts.

```lua
local stop = Rivue.watch({ hp, maxHp }, function(values)
	print(values[1], "/", values[2])
end, { immediate = true })
```

### `watchEffect(fn, options?)`

Runs `fn` now and again whenever anything it read changes. `fn` receives `onCleanup`.
`watchPostEffect` and `watchSyncEffect` are shortcuts for `flush = "post"` and `flush = "sync"`.

```lua
Rivue.watchEffect(function(onCleanup)
	local conn = target.value.Touched:Connect(onTouched)
	onCleanup(function() conn:Disconnect() end)
end)
```

### `onWatcherCleanup(fn)`

Registers a cleanup for the watch callback or `watchEffect` that's running. The cleanup runs
before the next run and when the watcher stops.

### `effect(fn, options?)`

The low-level reactive effect. Returns an `Effect` with `run()` and `stop()`. Options:
- `scheduler: (run) -> ()`,
- `lazy: boolean`,
- debug hooks `onTrack(event)` and `onTrigger(event)`, where `event` is `{ target, key }`.

Errors thrown inside effects, watch callbacks and queued jobs are always reported with `warn`.

### `effectScope(detached?)`

Groups effects so you can stop them together.

```lua
local scope = Rivue.effectScope()
scope:run(function()
	Rivue.watch(a, print)
	Rivue.watchEffect(function() print(b.value) end)
end)
scope:stop()
```

`getCurrentScope()` returns the active scope. `onScopeDispose(fn)` runs `fn` when it stops.
Each component's setup runs inside its own scope.

---

## Virtual nodes

### `h(type, props?, children?)`

```lua
h(type: string | ComponentDef | (props) -> VNode? | Fragment, props: Props?, children: Children?): VNode
```

- **`type`**: a ClassName (`"Frame"`), a component, a function component, or `Rivue.Fragment`.
  A string registered with `app:component()` renders that component.
- **`children`**: one of
  - an array of vnodes, strings or functions,
  - a single vnode or string,
  - for components, a table of [named slots](#slots).

  Arrays may contain `nil`/`false` (from `hIf` or `cond and h(...)`) and other arrays. A nested
  array becomes a Fragment, so `{ header, Rivue.hFor(items, row), footer }` works and diffs
  correctly.

A string child sets `Text` on text elements (otherwise a TextLabel is created). A function child
is called once and its result rendered.

### `Fragment`

Renders its children with no wrapper Instance: `h(Rivue.Fragment, nil, { a, b })`. A component
render function can also return an array.

### `hIf(condition, vnode)`

Returns `vnode` when `condition` is truthy, otherwise `nil`.

### `hFor(list, mapper)`

```lua
hFor<T>(list: { T }, mapper: (item: T, index: number) -> VNode?): { VNode }
```

Maps an array (plain or reactive) to vnodes. Returning `nil` skips the item. Give each item a
`key` so reordering moves Instances instead of re-patching them (Studio warns if you don't).

### Function components

A function from props to a vnode. It has no state or hooks, and runs again whenever its parent
re-renders.

```lua
local function Badge(props)
	return h("TextLabel", { Text = props.text, cornerRadius = 4 })
end

h(Badge, { text = "NEW" })
```

---

## Element props

| Prop | Meaning |
|------|---------|
| `Size`, `Text`, ... | Instance properties. camelCase (`size`) also works |
| `onX = fn` | Connects event `X` (`onMouseEnter`, `onFocusLost`, `onInputBegan`, ...) |
| `onClick` | `Activated` on buttons (falls back to `MouseButton1Click`) |
| `onTextChanged` | Called with the new `Text` |
| `onPropChanged` / `onProp` | For a property that isn't an event, connects its changed signal and passes the new value (`onSizeChanged`, `onVisible`) |
| `key` | Identity among siblings. A new key replaces the element |
| `ref` | A `Ref` (set to the Instance), a function (called with the Instance, then `nil` on unmount), or a string name for [`useTemplateRef`](#usetemplaterefname) |
| `memo = { deps }` | Skips patching this element and its children while every dep is unchanged (`==`) |
| `transition` | Enter/leave tween config, see [Transition](#transition) |
| `cornerRadius` | Creates a `UICorner` (number of pixels, or a UDim) |
| `padding` | Creates a `UIPadding`: a number/UDim for every side, `{ top, right, bottom, left }`, or `{ x, y }` |
| `stroke` | Creates a `UIStroke`: a Color3, a number (Thickness), or a table of UIStroke properties |
| `aspectRatio` | Creates a `UIAspectRatioConstraint` |
| `vName = value` | A [directive](#directives): `vShow`, `vFocus`, `vClickOutside`, `vSelect`, `vDrag`, or any registered one (`vMyThing` -> `"my-thing"`) |
| `model = ref` | On a TextBox, binds `Text` both ways (keeps your own `onTextChanged`) |
| `style = table \| { tables }` | Props merged under the element's own props, in order. `false`/`nil` entries are skipped |
| `__directives` | The long form of `v` props: `{ { name = "focus", value = true }, ... }` |

Props are diffed shallowly, so only changed props are written. Removing a prop restores the
property default (or destroys the generated child). On a TextBox, what the player typed, the
cursor and focus survive re-renders, unless the render passes a different `Text`. A TextBox with
`onTextChanged` (or `model`) always shows its state's `Text`.

### `mergeProps(...)` / `cloneVNode(vnode, extraProps?)` / `isVNode(value)`

`mergeProps` merges props tables left to right:
- event handlers are chained, so both run,
- `__directives` and `style` are combined,
- everything else is overwritten.

`cloneVNode` copies a vnode with extra props merged in (useful for wrapper components).
`isVNode` tells vnodes from plain tables.

---

## Components

### `defineComponent(options)`

```lua
defineComponent(setup: (props, ctx) -> RenderFunction, options: ComponentOptions?): ComponentDef
defineComponent({
	name: string?,
	props: PropSchema?,
	emits: { string } | { [string]: (...any) -> boolean }?,
	inheritAttrs: boolean?,           -- default true
	setup: ((props, ctx) -> RenderFunction | { render: RenderFunction, ... })?,
	render: ((props) -> VNode?)?,     -- for components without setup
}): ComponentDef
```

`setup` runs once per instance and returns the render function. Inside render, read reactive
state and return the tree (a vnode, an array, or `nil`).

```lua
local Health = Rivue.defineComponent({
	name = "Health",
	props = {
		current = { type = "number", required = true },
		max = { type = "number", default = 100 },
	},
	setup = function(props)
		local ratio = Rivue.computed(function()
			return props.current / props.max
		end)
		return function()
			return h("Frame", { Size = UDim2.new(ratio.value, 0, 0, 8), BackgroundColor3 = Color3.new(0.2, 0.8, 0.3) })
		end
	end,
})
```

### Props

Each schema entry can have:
- `type`: a `type()` or `typeof()` name (`"number"`, `"table"`, `"UDim2"`, `"Color3"`,
  `"Instance"`, ...), or a list of them,
- `required`,
- `default` (use a function for table defaults),
- `validator: (value) -> boolean`.

Validation runs in Studio only, and warns with the component's name.

`props` is a shallow reactive table. Read `props.x` inside render or `computed` to track it.
Copying `local x = props.x` in setup loses reactivity (use `Rivue.toRef(props, "x")`).

Props not in the schema become **attrs** (`ctx.attrs`). If the component renders a single
element, attrs are applied to it unless `inheritAttrs = false`. Without a `props` schema, every
prop is a prop.

### Setup context (`ctx`)

| Field | Description |
|-------|-------------|
| `ctx.emit(event, ...)` | Calls the parent's `on<Event>` handler: `emit("select", id)` calls `onSelect(id)` |
| `ctx.attrs` | Undeclared props (reactive) |
| `ctx.slots` | Default slot: the array children passed to the component |
| `ctx.renderSlot(name, scope?, fallback?)` | Renders a named or scoped slot, see [Slots](#slots) |
| `ctx.hasSlot(name)` | Whether the parent passed that slot |
| `ctx.expose(table)` | What a template ref to this component receives |
| `ctx.provide(key, value)` / `ctx.inject(key, default?)` | Same as the standalone functions |
| `ctx.globals` | `app.config.globalProperties` |
| `ctx.emit("update:modelValue", v)` | What the `model` prop listens to (`modelValue` is the prop) |
| `ctx.onUnmounted(fn)` | Same as `onUnmounted` |

### Emits

Declaring `emits` keeps the listeners out of `attrs`, so they don't fall through to the root
element. In Studio, emitting an undeclared event, or failing a validator, warns.

```lua
emits = { "select" }
emits = { select = function(id) return type(id) == "number" end }
```

### `useTemplateRef(name)`

```lua
useTemplateRef<T>(name: string): Ref<T?>
```

Holds the element rendered with `ref = name` (or a child component's exposed table) while it's
mounted. It's set before `onMounted` runs.

```lua
setup = function()
	local input = Rivue.useTemplateRef("input")
	Rivue.onMounted(function()
		(input.value :: TextBox):CaptureFocus()
	end)
	return function()
		return h("TextBox", { ref = "input" })
	end
end
```

### `getCurrentInstance()` / `useId()` / `resolveComponent(name)`

`getCurrentInstance()` returns the component instance during setup (or `nil`). `useId()` returns
a string unique to the session, such as `"r12-1"`, handy for Instance names.
`resolveComponent(name)` looks up a component registered with `app:component()`.

### `model` on components

`h(Comp, { model = someRef })` passes `modelValue = someRef.value` and an
`["onUpdate:modelValue"]` handler that writes the ref. `defineModel()` gives the component a ref
wired to both:

```lua
local useModel = Rivue.defineModel()
local Toggle = Rivue.defineComponent(function(props, ctx)
	local on = useModel(props, ctx)
	return function()
		return h("TextButton", { Text = tostring(on.value), onClick = function() on.value = not on.value end })
	end
end, { name = "Toggle" })

h(Toggle, { model = enabled })
```

### Error handling

`onErrorCaptured(fn)` catches errors from descendants' render, patch, lifecycle hooks and emit
handlers. `fn(err, instance, info)` returns `true` to stop the error there. Errors nothing
handled go to `app.config.errorHandler(err, instance, info)`. If there's no error handler, they
are reported with `warn`, along with the component chain:

```
[Rivue] Error in render of <ItemRow> in <Inventory> in <App>: attempt to index nil with 'name'
```

Errors thrown by `setup()` itself propagate to whoever is mounting, and the message names the
component.

---

## Lifecycle hooks

Call these in `setup()`.

| Hook | Runs |
|------|------|
| `onBeforeMount(fn)` | Before the first render is patched |
| `onMounted(fn)` | After the component and every descendant are parented. Children run before parents |
| `onBeforeUpdate(fn)` / `onUpdated(fn)` | Around each re-render |
| `onBeforeUnmount(fn)` / `onUnmounted(fn)` | Before and after teardown. Watchers, effects and `Rivue.queueJob` jobs from setup are stopped automatically |
| `onActivated(fn)` / `onDeactivated(fn)` | Inside `KeepAlive`, on mount and on every return, and when cached |
| `onErrorCaptured(fn)` | See [Error handling](#error-handling) |
| `onRenderTracked(fn)` / `onRenderTriggered(fn)` | Debugging: `fn({ target, key })` for each reactive read in render, and for the write that caused a re-render |
| `onTransition(name, fn)` | Transition events on this component's root: `"before-enter"`, `"enter"`, `"after-enter"`, `"before-leave"`, `"leave"`, `"after-leave"` |

Component re-renders are batched and deferred. Parents update before children, and each
component renders once per batch.

---

## Slots

Array children are the default slot (`ctx.slots`). For named or scoped slots, pass a table of
functions:

```lua
h(Card, { title = "Shop" }, {
	header = function(scope)
		return h("TextLabel", { Text = scope.title })
	end,
	default = function()
		return { h("TextLabel", { Text = "Body" }) }
	end,
})
```

Inside `Card`:

```lua
return function()
	local children = ctx.renderSlot("header", { title = props.title })
	for _, child in ctx.renderSlot("default") do
		table.insert(children, child)
	end
	if not ctx.hasSlot("footer") then
		table.insert(children, h("TextLabel", { Text = "No footer" }))
	end
	return h("Frame", nil, children)
end
```

`renderSlot(name, scope?, fallback?)` always returns a new list. `"default"` falls back to the
array children. Slot functions run during the child's render, so reactive reads inside them
re-render the child.

---

## Provide / inject

```lua
provide(key: unknown, value: unknown)
inject<T>(key: unknown, default: T?): T?
```

Pass values down the tree without props. Call both in setup (or inject inside
`app:runWithContext()`). Keys are looked up through ancestors, then in `app:provide()`. Provide a
ref or reactive table to make the value reactive. `hasInjectionContext()` tells you whether
`inject()` can be called where you are.

```lua
-- Root
Rivue.provide("theme", Rivue.reactive({ accent = Color3.new(0, 0.6, 1) }))
-- Any descendant
local theme = Rivue.inject("theme")
```

---

## Built-in components

### Transition

Animates one child in and out with TweenService. Toggle the child, not the Transition:

```lua
h(Rivue.Transition, {
	tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad),
	from = { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.05) },
}, {
	Rivue.hIf(open.value, h(Panel)),
})
```

| Prop | Description |
|------|-------------|
| `tweenInfo` | Used for both phases (`enterInfo` / `leaveInfo` override it) |
| `from` | The hidden state. It's applied before enter, and tweened to on leave. Enter tweens back to the element's own prop values |
| `enterFrom`, `enterGoals`, `leaveGoals` | Set each phase explicitly |
| `appear` | Also animate the first render (default `false`) |
| `mode = "out-in"` | When the child changes (type or key), wait for the old one to leave before showing the new one |
| `onBeforeEnter`, `onAfterEnter`, `onBeforeLeave`, `onAfterLeave` | `(el) -> ()` |

Leaving elements stay on screen until their tween finishes, then they're destroyed. Leaving never
blocks rendering. A component child animates its root element.

The same config can be set per element with the `transition` prop. Add `enter = true` /
`leave = true` to enable each phase.

### TransitionGroup

`Transition` for keyed lists: added items enter, removed items leave. Takes the same props
without `mode`, plus `tag` / `tagProps` to wrap the items in an element.

```lua
h(Rivue.TransitionGroup, { tweenInfo = TweenInfo.new(0.15), from = { BackgroundTransparency = 1 } },
	Rivue.hFor(notifications.value, function(n)
		return h(Toast, { key = n.id, text = n.text })
	end))
```

### KeepAlive

Caches the component it wraps instead of destroying it. Switching back reuses the same Instances
and state. While cached, its Instances are detached and its re-renders wait until it's shown
again.

```lua
h(Rivue.KeepAlive, { max = 5, exclude = { "Settings" } }, {
	if tab.value == "inventory" then h(Inventory) else h(Shop),
})
```

The props are `include` / `exclude` (lists of component names) and `max`, which defaults to 10.
Least recently used entries are dropped first. Entries are cached by `key`, or by component when
there's no key.

### Teleport

Renders children into another Instance, which is useful for modals and tooltips that must escape
a `ClipsDescendants` parent.

```lua
h(Rivue.Teleport, { to = overlayGui }, { h(Tooltip, { text = "Hi" }) })
```

`to` is an Instance or a function returning one. `disabled = true` renders the children in place
instead. `defer = true` waits until the rest of the tree is mounted, so `to` can point at
something rendered later in the same tree. Children are removed when the Teleport unmounts.

### VirtualList

A ScrollingFrame that only renders the rows in view. Every row is the same size.

```lua
h(Rivue.VirtualList, {
	Size = UDim2.fromScale(1, 1),     -- undeclared props go to the ScrollingFrame
	items = inventory,                -- plain or reactive array
	itemSize = 48,                    -- row height (width when horizontal)
	key = function(item) return item.id end,
	render = function(item, index)
		return h(ItemRow, { item = item })
	end,
	overscan = 2,
	horizontal = false,
})
```

Rows get `Position` and `key` set for you. Make them fill the width (`Size = UDim2.new(1, 0, 0, 48)`).

### Suspense and async components

```lua
local Profile = Rivue.defineAsyncComponent(function()
	local data = fetchProfile() -- may yield
	return makeProfileComponent(data)
end, {
	loadingComponent = h("TextLabel", { Text = "Loading..." }),
	errorComponent = h("TextLabel", { Text = "Failed" }),
	delay = 200,   -- ms before showing loadingComponent
	timeout = 5000, -- ms
})

h(Rivue.Suspense, { fallback = h(Spinner), timeout = 5000 }, { h(Profile) })
```

`Suspense` shows `fallback` until every async component inside it has loaded. If one fails, it
shows an error message instead.

---

## Apps and mounting

### `createApp(root, options?)`

```lua
createApp(root: VNode | ComponentDef, options: { usePool: boolean?, poolConfig: PoolConfig?, poolWarmup: { [string]: number }? }?): App
```

| Method | Description |
|--------|-------------|
| `app:mount(container)` | Renders into an Instance |
| `app:mountToPlayerGui(player)` | Creates a `ScreenGui` (`ResetOnSpawn = false`) in the player's PlayerGui and mounts into it |
| `app:unmount()` | Tears everything down |
| `app:provide(key, value)` | App-wide provide |
| `app:component(name, def)` | Lets `h("Name")` render `def` anywhere in the app |
| `app:directive(name, hooks)` | Registers a directive |
| `app:use(plugin, ...)` | Calls `plugin(app, ...)` or `plugin.install(app, ...)` |
| `app.config.errorHandler` | `(err, instance, info) -> ()` for errors nothing else handled |
| `app.config.globalProperties` | Shared values, read through `ctx.globals` |
| `app.config.warnHandler` | `(message, instance, trace) -> ()` receives Studio warnings instead of `warn` |
| `app:onUnmount(fn)` | Runs `fn` when the app unmounts |
| `app:runWithContext(fn)` | Runs `fn` with the app's provides available to `inject()` |
| `app:printTree()` | Prints and returns the mounted tree, components with their props |
| `app:rerender(newRoot?)` / `app:swapRoot(newRoot)` | Remounts with a new root |
| `app:getPoolStats()` / `app:validatePoolHealth()` | Only with `usePool = true` |

Methods that configure the app return it, so they chain:

```lua
Rivue.createApp(h(Hud))
	:provide("player", game.Players.LocalPlayer)
	:component("Icon", Icon)
	:mountToPlayerGui(game.Players.LocalPlayer)
```

### `mount(componentOrVNode, parent, options?)`

A shortcut for `createApp(...):mount(parent)`. It returns the app.

---

## Directives

Directives attach reusable behaviour to an element. Use a `v` prop with the directive's name in
camelCase:

```lua
h("TextBox", { vFocus = true, vClickOutside = close })
```

The long form `__directives = { { name = "focus", value = true } }` also works.

Directive `mounted` hooks run after the tree is parented. `updated` runs when the element
patches, and `unmounted` runs on removal.

| Name | Value | Effect |
|------|-------|--------|
| `focus` | boolean | Captures focus on a TextBox |
| `select` | boolean | Gives a GuiObject gamepad selection while truthy, and clears it on removal |
| `show` | boolean | Sets `Visible` |
| `drag` | boolean | Drag a GuiObject with mouse or touch |
| `click-outside` | function | Called when the player clicks or taps outside the element |
| `preload` | asset id or list | Preloads with ContentProvider |
| `fade-in` | `{ duration?, delay? }` | Fades the element and its descendants in |

Custom directives use `Rivue.directives.register(name, hooks)` or `app:directive(name, hooks)`:

```lua
Rivue.directives.register("tooltip", {
	mounted = function(el, text)
		return { conn = el.MouseEnter:Connect(function() showTooltip(text) end) } -- state
	end,
	updated = function(el, text, state) return state end,
	unmounted = function(el, state) state.conn:Disconnect() end,
})
```

Whatever `mounted` returns is passed to `updated` and `unmounted`. If `updated` returns a value,
it replaces that state.

### Two-way binding helpers

```lua
h("TextBox", Rivue.vModelText(name))                         -- Text + onTextChanged
h("TextBox", Rivue.vModelText(query, { debounce = 300 }))    -- debounced writes
Rivue.vModelProp(ref, "Position", "onPositionChanged")         -- any property
```

They return a props table. Merge it with your own props if you need more.

---

## Composables

| Function | Description |
|----------|-------------|
| `useAttrs()` | `ctx.attrs` |
| `useSlots()` | `ctx.slots` |
| `defineModel(options?)` | Returns `(props, ctx) -> Ref`. The ref reads `props.modelValue` and emits `update:modelValue` on write (`name` / `event` options change both) |
| `useTheme()` | The nearest provided `"theme"` |
| `useStyles(factory)` | `computed(factory(theme))` |

---

## Roblox composables

| Function | Returns |
|----------|---------|
| `useViewportSize()` | `Ref<Vector2>`. Follows the camera's `ViewportSize` |
| `useInputType()` | `Ref<"keyboard" \| "gamepad" \| "touch">`, from the last input (mouse counts as keyboard) |
| `useSafeArea()` | `Ref<{ top, left, bottom, right }>` from `GuiService:GetGuiInset()` |
| `useSelection()` | `selected: Ref<GuiObject?>` and `select: (GuiObject?) -> ()` for gamepad selection |
| `useTween(source, tweenInfo)` | `Ref<T>` that tweens to `source` whenever it changes. Works with numbers and types that have `:Lerp` (UDim2, Color3, Vector2, CFrame, ...) |
| `useSpring(source, { speed?, damping? })` | `Ref<T>` that springs to `source` (number, Vector2, Vector3). `speed` defaults to 12, `damping` to 1 (no overshoot) |
| `attributeRef(instance, name, default?, { throttle? }?)` | A ref synced both ways with an attribute |
| `useTag(tag, onAdded)` | Calls `onAdded(instance)` for every tagged Instance. Its returned cleanup runs when the tag is removed |
| `onRenderStepped(fn)` / `onHeartbeat(fn)` / `onStepped(fn)` | RunService connections that disconnect on unmount |

`source` is a ref or a getter. The first four share one connection for the whole session. Treat
their refs as read only.

```lua
setup = function()
	local open = Rivue.ref(false)
	local x = Rivue.useSpring(function() return if open.value then 0 else -320 end)
	local input = Rivue.useInputType()
	return function()
		return h("Frame", {
			Position = UDim2.fromOffset(x.value, 0),
			Size = if input.value == "touch" then UDim2.fromOffset(320, 480) else UDim2.fromOffset(280, 400),
		})
	end
end
```

---

## Scheduler

| Function | Description |
|----------|-------------|
| `nextTick(fn?)` | Runs `fn` after pending re-renders and `"pre"` watchers. With no argument, yields until then |
| `queueJob(fn, { mode? })` | Queues `fn` once. Modes: `"micro"` (default, deferred), `"render"` (RenderStepped), `"heartbeat"`. Returns `{ cancel }`. Cancelled automatically on unmount when called in setup |

```lua
count.value += 1
Rivue.nextTick()
print(label.Text) -- updated
```

---

## Remote

A request/response layer over RemoteEvents, with payload validation and per-player rate limits.

```lua
-- Server
Rivue.Remote.setupServer()
Rivue.Remote.handle("buy", function(player, payload)
	return { ok = Shop.buy(player, payload.itemId) }
end, { maxPerSecond = 5 })

-- Client
local data, err = Rivue.Remote.request("buy", { itemId = "sword" }, 10)
```

| Function | Description |
|----------|-------------|
| `Remote.setupServer()` | Creates the remotes. Call once on the server at startup |
| `Remote.handle(action, handler, { maxPerSecond? })` | Server handler, `(player, payload) -> data`. The default limit is 30 requests per second per player, and `0` disables it |
| `Remote.request(action, payload, timeout?)` | Client. Yields and returns `(data, nil)` or `(nil, err)` |
| `Remote.fire(action, payload)` | Client, one way |
| `Remote.on(name, fn)` | Client, listens to a named RemoteEvent |

Possible `err` values:
- `"timeout"`,
- `"unknown_action"`,
- `"rate_limited"`,
- `"handler_error"`,
- `"invalid_action_name"`,
- a payload validation message (payloads are limited to 20 KB and 10 levels of nesting).

---

## Instance pool

`createApp(root, { usePool = true })` reuses released Instances instead of creating new ones.
Released Instances have the properties Rivue set reset to their defaults.

| Function | Description |
|----------|-------------|
| `pool.configure({ maxPoolSize?, maxTotalSize?, defaultTTL?, enableMetrics?, enableDebug?, enableAutoWarmup? })` | Limits and options |
| `pool.warmup(className, count)` | Pre-creates Instances |
| `pool.acquire(className)` / `pool.release(inst)` | Manual use |
| `pool.clear(className?)` | Destroys pooled Instances |
| `pool.getStatistics()` | `{ totalInstances, poolsByClass, metrics, hitRate }` |
| `pool.setResetHandler(className, fn)` | Custom reset for a class |

---

## Utilities and debugging

| Function | Description |
|----------|-------------|
| `utils.debounce(fn, ms)` | Calls `fn` once calls stop for `ms`. The returned handle has `cancel()` |
| `utils.throttle(fn, ms)` | At most once per `ms`, with a trailing call |
| `utils.nextFrame(fn)` | Next Heartbeat |
| `utils.useRaf(fn)` | Calls `fn(dt)` every RenderStepped. Returns `{ stop }` |
| `utils.filterForClient(player, text)` | TextService filtering |
| `utils.shallowEqual(a, b)` | Shallow table comparison |
| `iterArray(array)` | Index iterator for reactive arrays |
| `Rivue.dev` | `true` in Studio |
| `debug.enabled` | Verbose runtime logging (on in Studio) |
| `debug.inspect(value, depth?)` / `prettyPrint(value)` | Readable dump, unwraps proxies |
| `debug.measure(name, fn)` | Times `fn` and logs it |
| `debug.assertInvariant(cond, msg)` | Errors in Studio when `cond` is false |

`Rivue.printTree(vnode)` prints the tree under a mounted vnode, like `app:printTree()`.
Component root Instances are named after their component (unless you set `Name`), so the
Explorer shows the component structure.

In Studio, Rivue warns once per case about:
- unknown Instance properties,
- duplicate keys among siblings,
- a missing Teleport target,
- `hFor()` items without a key,
- undeclared emits.

---

## Types

Exported from the main module: `Rivue.Ref<T>`, `ComputedRef<T>`, `MaybeRef<T>`, `WatchOptions`,
`WatchHandle`, `WatchSource<T>`, `OnCleanup`, `MaybeRefOrGetter<T>`, `DebuggerEvent`, `ChildInput`, `Effect`, `EffectScope`, `VNode`, `Props`, `Child`,
`Children`, `ComponentDef`, `ComponentOptions`, `PropSchema`, `EmitsOptions`, `SetupContext`,
`TransitionConfig`, `Directive`, `App`, `AppOptions`, `Plugin`, `ComponentInstance`.

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
type Ref<T> = Rivue.Ref<T>

local selected: Ref<string?> = Rivue.ref(nil :: string?)
```
