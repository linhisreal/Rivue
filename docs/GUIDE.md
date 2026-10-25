# Rivue Guide

This guide walks through building Roblox UI with Rivue, from the first component to debugging a
real screen. Each section builds on the last. For exact signatures, see [API.md](API.md). For
working code, see [examples/](../examples).

If you know Vue, skim [VUE.md](VUE.md) first. Most of what you know carries over.

1. [The idea](#1-the-idea)
2. [Your first component](#2-your-first-component)
3. [State](#3-state)
4. [Describing UI with h()](#4-describing-ui-with-h)
5. [Lists and conditions](#5-lists-and-conditions)
6. [Components, props and events](#6-components-props-and-events)
7. [Slots: passing UI into a component](#7-slots-passing-ui-into-a-component)
8. [Forms and input](#8-forms-and-input)
9. [Side effects and cleanup](#9-side-effects-and-cleanup)
10. [Styling and layout](#10-styling-and-layout)
11. [Different devices](#11-different-devices)
12. [Animation](#12-animation)
13. [Sharing state between components](#13-sharing-state-between-components)
14. [Talking to the server](#14-talking-to-the-server)
15. [Performance](#15-performance)
16. [Debugging](#16-debugging)
17. [Common mistakes](#17-common-mistakes)

---

## 1. The idea

Without a framework, UI code creates Instances and then keeps them in sync by hand. Every time
the coins change, someone has to find the label and set its `Text`. That gets harder with every
screen.

With Rivue you write a **render function**: given the current state, it describes what the UI
should look like. When state changes, Rivue calls it again, compares the new description with
the old one, and updates only the Instance properties that changed.

```
state  ──>  render()  ──>  description (vnodes)  ──>  Rivue updates the Instances
  ^                                                              │
  └──────────────── player clicks, server data ──────────────────┘
```

So you never write `label.Text = ...`. You change state, and the UI follows.

## 2. Your first component

```lua
-- StarterPlayerScripts/Hud.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Rivue = require(ReplicatedStorage.Rivue)
local h = Rivue.h

local Counter = Rivue.defineComponent({
	name = "Counter",
	setup = function()
		local count = Rivue.ref(0)

		return function()
			return h("TextButton", {
				Size = UDim2.fromOffset(200, 50),
				Text = `Clicked {count.value} times`,
				onClick = function()
					count.value += 1
				end,
			})
		end
	end,
})

Rivue.createApp(Counter):mountToPlayerGui(Players.LocalPlayer)
```

A component has two parts:

- **`setup()`** runs **once**, when the component appears. Create state here and set up
  anything that should live as long as the component.
- **The function `setup` returns** is the render function. It runs **every time** state it read
  changes. Keep it free of side effects: it should only describe UI.

`createApp(Counter):mountToPlayerGui(player)` creates a ScreenGui in the player's PlayerGui and
renders the component into it. Use `app:mount(instance)` to render into any other Instance.

## 3. State

### ref

`Rivue.ref(value)` holds one value. You read and write it through `.value`, and Rivue notices
both.

```lua
local coins = Rivue.ref(0)
coins.value += 10
```

### reactive

`Rivue.reactive(table)` makes a whole table reactive, including nested tables. There's no
`.value`.

```lua
local player = Rivue.reactive({ coins = 0, inventory = {} })
player.coins += 10
player.inventory[#player.inventory + 1] = "Sword"
```

Use `ref` for single values and for state you replace wholesale. Use `reactive` for objects you
update field by field.

### computed

`Rivue.computed(fn)` derives a value from other state. It's cached and only recomputes when
something it read changes.

```lua
local total = Rivue.computed(function()
	return price.value * quantity.value
end)
print(total.value)
```

### What gets tracked

Rivue tracks **reads that happen while the render function (or a computed or watcher) runs**.
That explains most surprises:

```lua
setup = function()
	local count = Rivue.ref(0)
	local snapshot = count.value  -- read once, in setup: never updates

	return function()
		return h("TextLabel", {
			Text = tostring(count.value), -- read in render: re-renders when count changes
		})
	end
end
```

## 4. Describing UI with h()

`h(className, props, children)` describes one Instance:

```lua
h("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(30, 30, 30),
}, {
	h("TextLabel", { Text = "Title", Size = UDim2.new(1, 0, 0, 40) }),
	h("TextButton", { Text = "Close", onClick = close }),
})
```

**Props**:
- **Properties** are set directly: `Size`, `Text`, `BackgroundColor3`, ...
- **Events** are props starting with `on`: `onClick`, `onMouseEnter`, `onFocusLost`,
  `onInputBegan`. `onClick` works for any button.
- **Property changes**: `onSizeChanged = function(newSize) end`, or `onTextChanged` for text.
- **Modifier shorthands**: `cornerRadius = 8`, `padding = 12`, `stroke = Color3.new(1, 1, 1)`,
  `aspectRatio = 1` create the UICorner/UIPadding/UIStroke/UIAspectRatioConstraint for you.

**Children** can be:
- a list,
- a single vnode,
- or a string (which sets `Text` on a TextLabel or TextButton).

Lists can contain other lists and `nil`, which is what makes the next section work.

## 5. Lists and conditions

Render functions are plain Luau, so conditions are just `if` expressions:

```lua
return h("Frame", nil, {
	h("TextLabel", { Text = "Inventory" }),
	if loading.value then h("TextLabel", { Text = "Loading..." }) else nil,
	Rivue.hIf(isEmpty.value, h("TextLabel", { Text = "Nothing here yet" })),
})
```

`Rivue.hIf(condition, vnode)` is shorthand for that `if`. To only hide an element, keep it and
toggle visibility with `vShow = condition`.

Lists use `Rivue.hFor`, and you can put the result straight into a children list:

```lua
return h("ScrollingFrame", nil, {
	h("UIListLayout"),
	Rivue.hFor(items.value, function(item)
		return h("TextLabel", { key = item.id, Text = item.name })
	end),
})
```

**Always give list items a `key`** that identifies the item, such as an id rather than its
position. Then, when the list is reordered or filtered, Rivue moves the existing Instances instead
of rewriting each row. With a `UIListLayout`, Rivue also keeps each child's `LayoutOrder` in list
order.

## 6. Components, props and events

Split UI into components the way you'd split code into functions. A component receives
**props** from its parent and talks back through **events**.

```lua
local ItemRow = Rivue.defineComponent({
	name = "ItemRow",
	props = {
		item = { type = "table", required = true },
		selected = { type = "boolean", default = false },
	},
	emits = { "select" },
	setup = function(props, ctx)
		return function()
			return h("TextButton", {
				Text = props.item.name,
				BackgroundColor3 = if props.selected then Color3.fromRGB(60, 120, 220) else Color3.fromRGB(40, 40, 40),
				onClick = function()
					ctx.emit("select", props.item.id)
				end,
			})
		end
	end,
})

-- In the parent's render
h(ItemRow, {
	item = item,
	selected = selectedId.value == item.id,
	onSelect = function(id)
		selectedId.value = id
	end,
})
```

- `props` describes what the component accepts. In Studio, Rivue warns when a required prop is
  missing or has the wrong type. Types can be Luau types (`"number"`) or Roblox ones
  (`"UDim2"`, `"Instance"`), or a list of them.
- Read props as `props.x` inside render. They're reactive, so the child re-renders when the
  parent passes a new value.
- **Props flow down, events flow up.** A child never changes its props. It emits an event, and
  the parent changes its own state. `ctx.emit("select", id)` calls the parent's `onSelect(id)`.
- Props you didn't declare (like `Position`) are passed on to the component's root element, so
  `h(ItemRow, { item = item, LayoutOrder = 3 })` just works.

## 7. Slots: passing UI into a component

Wrapper components like panels, modals and cards take UI from their parent. Array children are
the default slot:

```lua
local Panel = Rivue.defineComponent({
	name = "Panel",
	setup = function(props, ctx)
		return function()
			return h("Frame", { cornerRadius = 8, padding = 12 }, {
				h("UIListLayout"),
				ctx.renderSlot("default"),
			})
		end
	end,
})

h(Panel, nil, {
	h("TextLabel", { Text = "Hello" }),
})
```

For several areas, pass named functions. A slot function can also receive data from the child
(a **scoped slot**):

```lua
h(Card, nil, {
	header = function()
		return h("TextLabel", { Text = "Shop" })
	end,
	default = function()
		return h(ShopList)
	end,
})
-- Inside Card: ctx.renderSlot("header"), ctx.renderSlot("default"), ctx.hasSlot("footer")
```

See [examples/components/Modal.luau](../examples/components/Modal.luau).

## 8. Forms and input

`model = someRef` binds a TextBox both ways: typing updates the ref, and setting the ref updates
the box.

```lua
local name = Rivue.ref("")

h("TextBox", {
	PlaceholderText = "Your name",
	model = name,
	onFocusLost = function(enterPressed)
		if enterPressed then
			submit(name.value)
			name.value = "" -- clears the box
		end
	end,
})
```

`model` works on your own components too. The component reads `props.modelValue` and emits
`"update:modelValue"`, or uses `Rivue.defineModel()` for both:

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

h(Toggle, { model = musicEnabled })
```

Directives add behaviour to an element with `v` props: `vFocus = true` focuses a TextBox,
`vClickOutside = close` closes popups, and `vSelect = true` gives gamepad selection.

## 9. Side effects and cleanup

Anything that isn't "describe the UI" belongs outside the render function:
- connecting signals,
- starting timers,
- calling the server,
- reacting to changes.

```lua
setup = function(props)
	-- Run code when something changes
	Rivue.watch(function()
		return props.userId
	end, function(id)
		loadProfile(id)
	end, { immediate = true })

	-- Engine signals: connect on mount, disconnect on unmount
	local conn
	Rivue.onMounted(function()
		conn = workspace.ChildAdded:Connect(onChildAdded)
	end)
	Rivue.onUnmounted(function()
		conn:Disconnect()
	end)

	return render
end
```

- `watch(source, callback)` runs `callback(new, old)` when `source` changes. `watchEffect(fn)`
  runs `fn` now and again whenever anything it reads changes.
- **Watchers created in setup stop automatically** when the component goes away. So do
  `Rivue.onHeartbeat`/`onRenderStepped` connections and `Rivue.queueJob` jobs.
- Connections you make yourself need cleanup in `onUnmounted`, or use the helpers:
  - `Rivue.useTag(tag, fn)` for CollectionService tags,
  - `Rivue.attributeRef(instance, name)` for attributes,
  - `onCleanup` inside `watchEffect`.
- `onMounted` runs once the component's Instances are parented, so `AbsoluteSize` and focus work
  there.

## 10. Styling and layout

Shared looks are plain tables. Pass them with `style`. Later entries win, and the element's own
props win over all of them:

```lua
local Styles = {
	panel = { BackgroundColor3 = Color3.fromRGB(25, 25, 25), cornerRadius = 8, padding = 12 },
	active = { BackgroundColor3 = Color3.fromRGB(60, 120, 220) },
}

h("TextButton", {
	style = { Styles.panel, isActive and Styles.active },
	Text = "Play",
})
```

For layout, use Roblox's own layout objects as children (`UIListLayout`, `UIGridLayout`,
`UIFlexItem`, ...). Rivue keeps `LayoutOrder` in render order for you. Set `LayoutOrder`
yourself when you want a different order.

## 11. Different devices

The same screen has to work on phones, consoles and desktops:

```lua
setup = function()
	local input = Rivue.useInputType()      -- "keyboard" | "gamepad" | "touch"
	local viewport = Rivue.useViewportSize() -- Vector2, follows resizes and rotation
	local safeArea = Rivue.useSafeArea()     -- top bar and notch insets

	return function()
		local compact = input.value == "touch" or viewport.value.X < 700
		return h("Frame", {
			Size = if compact then UDim2.fromScale(1, 0.4) else UDim2.fromOffset(400, 300),
			Position = UDim2.fromOffset(0, safeArea.value.top),
		})
	end
end
```

For controllers, `vSelect = true` selects an element, and `Rivue.useSelection()` reads and sets
the selected object.

## 12. Animation

**Appearing and disappearing.** Wrap the element in `Transition` and toggle it inside:

```lua
h(Rivue.Transition, {
	tweenInfo = TweenInfo.new(0.2),
	from = { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.55) },
}, {
	Rivue.hIf(open.value, h("Frame", { Position = UDim2.fromScale(0.5, 0.5) })),
})
```

`from` is the hidden state. The element tweens from it when it appears and back to it before it's
destroyed. Use `TransitionGroup` for lists.

**Values that move.** `useTween` and `useSpring` turn state into an animated value you bind to
a prop:

```lua
local health = Rivue.ref(100)
local shown = Rivue.useSpring(function()
	return health.value / 100
end)

h("Frame", { Size = UDim2.fromScale(shown.value, 1) })
```

## 13. Sharing state between components

**Parent to descendants.** Use `provide`/`inject` instead of passing a prop through every level:

```lua
-- Root setup
Rivue.provide("theme", Rivue.reactive({ accent = Color3.fromRGB(60, 120, 220) }))
-- Any descendant's setup
local theme = Rivue.inject("theme")
```

**Game-wide state.** Use a module that returns reactive state, which works like a store. Every
component that reads it updates when it changes:

```lua
-- ReplicatedStorage/Stores/PlayerData.luau
local Rivue = require(game.ReplicatedStorage.Rivue)

local state = Rivue.reactive({ coins = 0, level = 1 })

local PlayerData = {}
PlayerData.state = Rivue.readonly(state)  -- components read this

function PlayerData.addCoins(amount: number)
	state.coins += amount
end

return PlayerData
```

Keep the writes in the module's functions, so there's one place to look when a value is wrong.

## 14. Talking to the server

`Rivue.Remote` gives you request/response over RemoteEvents:

```lua
-- Server
Rivue.Remote.setupServer()
Rivue.Remote.handle("shop:buy", function(player, payload)
	return ShopService.buy(player, payload.id) -- validate everything the client sends
end, { maxPerSecond = 5 })

-- Client (yields)
local result, err = Rivue.Remote.request("shop:buy", { id = "sword" })
```

In a component, call it off the render path and keep loading and error state:

```lua
local data = Rivue.shallowRef(nil)
local errorText = Rivue.ref(nil)

Rivue.onMounted(function()
	task.spawn(function()
		local result, err = Rivue.Remote.request("shop:list", nil)
		if result then data.value = result else errorText.value = err end
	end)
end)
```

[examples/components/Shop.luau](../examples/components/Shop.luau) does this with retry and
pending states.

## 15. Performance

Rivue is fast by default. These cover the cases where it isn't:

- **Keys on list items** (section 5) avoid re-patching every row when a list changes.
- **Split big screens into components.** Only the components that read changed state re-render.
- **Long lists:** use `Rivue.VirtualList`, which only creates the rows on screen.
- **Rows that rarely change:** `memo = { item.id, item.version }` skips patching while those
  values are the same.
- **Big data you replace rather than edit:** `Rivue.shallowRef` doesn't make the contents
  reactive.
- **Lots of short-lived Instances:** `createApp(App, { usePool = true })` reuses them.

## 16. Debugging

- **Look in the Explorer.** Each component's root Instance is named after the component, so the
  Explorer reads like your component tree.
- **Print the tree:** `app:printTree()` prints components with their props and the elements
  they rendered:

  ```
  <TodoList>
    Frame "TodoList"
      TextBox "Input"
      <TodoItem todo=table>
        Frame "TodoItem"
  ```

- **"Why did this re-render?"** Add `Rivue.onRenderTriggered(function(e) print(e.key) end)` in
  the component's setup.
- **Errors** name the component chain:
  `[Rivue] Error in render of <ItemRow> in <Inventory> in <App>: ...`. Errors in watchers and
  effects are always reported, never swallowed.
- **Studio warnings** cover:
  - unknown properties,
  - wrong prop types,
  - duplicate keys,
  - list items without keys,
  - undeclared events.
- `Rivue.debug.inspect(value)` prints reactive state readably.

## 17. Common mistakes

| Symptom | Cause | Fix |
|---------|-------|-----|
| UI doesn't update | The value was read in `setup`, not in render | Read `x.value` / `props.x` inside the render function |
| UI doesn't update after `table.insert(list, x)` | `table.*` functions bypass reactive proxies | `list[#list + 1] = x`, or assign a new table to the ref |
| `ipairs`/`pairs` over reactive state finds nothing | Luau has no `__pairs` | `for k, v in state do` or `for i = 1, #list do` |
| Destructured prop never changes | `local name = props.name` copies the value | Read `props.name` in render, or `Rivue.toRef(props, "name")` |
| `onMounted must be called inside a component's setup()` | Hook called in render or later | Call hooks at the top of `setup` |
| Whole list re-renders on every change | Missing `key` | Give every list item a stable key |
| Child state resets when the parent re-renders | The child's type or `key` changes between renders | Keep the same component and key for the same item |
| Type errors on children lists in `--!strict` | The old Luau type solver can't infer mixed lists | Use `--!nonstrict` for UI files, or the new type solver |

---

Next: browse [examples/](../examples), then keep [API.md](API.md) open while you build.
