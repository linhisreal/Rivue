[Docs](../README.md) › [API](../API.md) › **Render Function**

# Render Function

**Learn it:** [Guide 3: Describing UI](../guide/03-describing-ui.md) · [Guide 6: Styling and layout](../guide/06-styling-and-layout.md)

Rivue has no templates: components return a tree of vnodes built with `h()`. All examples
assume:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h
```

- [h()](#h)
- [Element props](#element-props)
- [Fragment](#fragment)
- [hIf()](#hif)
- [hFor()](#hfor)
- [mergeProps()](#mergeprops)
- [cloneVNode()](#clonevnode)
- [isVNode()](#isvnode)
- [resolveComponent()](#resolvecomponent)
- [Function components](#function-components)

---

## h()

Creates a vnode: a description of an Instance, a component, or a fragment.

- **Type**

  ```lua
  function h(type: VNodeType, props: Props?, children: Children?): VNode

  type VNodeType =
  	string -- a ClassName ("Frame"), or a name registered with app:component()
  	| ComponentDef
  	| (props: Props) -> VNode? -- function component
  	| typeof(Rivue.Fragment)

  type Children =
  	{ ChildInput } -- a list (nested lists and nil/false entries are allowed)
  	| VNode | string | number -- a single child
  	| { [string]: (scope: any) -> Children } -- named slots, components only
  ```

- **Details**

  - **`type`** decides what's rendered: an Instance class, a component, a function component or
    a Fragment.
  - **`props`** set Instance properties and connect events. Rivue also handles a few prop names
    itself; see [Element props](#element-props).
  - **`children`**:
    - A string or number child sets `Text` on TextLabels, TextButtons and TextBoxes.
    - A nested list (like the result of `hFor`) becomes a [Fragment](#fragment), so its keyed
      diff stays separate from its siblings.
    - `nil` and `false` entries are skipped.
    - For components, a table with string keys passes
      [named slots](component.md#slots).

- **Example**

  ```lua
  -- An element with props and children
  h("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
  	h("UIListLayout", { Padding = UDim.new(0, 8) }),
  	h("TextLabel", { Text = "Title" }),
  	h("TextButton", {
  		Text = "Close",
  		onClick = function()
  			print("closed")
  		end,
  	}),
  })

  -- Text as the child
  h("TextLabel", nil, "Hello")

  -- A component with props
  local Badge = Rivue.defineComponent({
  	name = "Badge",
  	props = { text = { type = "string" } },
  	render = function(props)
  		return h("TextLabel", { Text = props.text })
  	end,
  })
  h(Badge, { text = "NEW" })
  ```

---

## Element props

What each kind of prop on an element does.

| Prop | Meaning |
|------|---------|
| `Size`, `Text`, ... | Instance properties. camelCase (`size`) also works |
| `onX = fn` | Connects event `X`: `onMouseEnter`, `onFocusLost`, `onInputBegan`, ... |
| `onClick = fn` | `Activated` on buttons (falls back to `MouseButton1Click`) |
| `onTextChanged = fn` | Called with the new `Text` |
| `onXChanged = fn` / `onX = fn` | For a property `X` that isn't an event, called with the new value (`onSizeChanged`, `onVisible`) |
| `key` | Identity among siblings. A new key replaces the element |
| `ref` | A `Ref`, a function, or a string name. See [Template refs](component.md#usetemplateref) |
| `vName = value` | A [directive](directives.md): `vShow`, `vFocus`, `vClickOutside`, `vSelect`, `vDrag`, ... |
| `model = ref \| "name"` | Two-way `Text` binding on a TextBox. A string names a ref returned by `setup()` (for [`render(ctx)`](component.md#render)) |
| `class = "a" \| { "a", "b" } \| { a = bool }` | Applies named styles from the component's [`styles`](component.md#styles) and [`app:styles()`](application.md#appstyles). See below |
| `style = table \| { tables }` | Prop tables merged under the element's own props. `false`/`nil` entries are skipped |
| `memo = { deps }` | Skips patching this element and its children while every dep is `==` |
| `transition` | Enter/leave tween config, see [Transition](builtins.md#transition) |
| `cornerRadius` | Creates a `UICorner` (number of pixels, or a UDim) |
| `padding` | Creates a `UIPadding`: a number/UDim for all sides, `{ top, right, bottom, left }`, or `{ x, y }` |
| `stroke` | Creates a `UIStroke`: a Color3, a number (Thickness), or a table of UIStroke properties |
| `aspectRatio` | Creates a `UIAspectRatioConstraint` |
| `layout` | Creates a `UIListLayout` or `UIGridLayout`. See below |
| `flex` | Creates a `UIFlexItem`: `"fill"`, `"grow"`, `"shrink"`, `"none"`, a grow ratio, or a table of UIFlexItem properties |

- **Details**

  - **Diffing.** Props are diffed shallowly and only changed ones are written. Removing a prop
    restores the property default, or destroys the generated modifier child.
  - **Events.** Each event is connected once. A re-render with a new handler function swaps it
    in place instead of reconnecting.
  - **TextBoxes.**
    - Re-renders keep what the player typed, the cursor and focus, unless the render passes a
      different `Text`.
    - With `onTextChanged` or `model`, the state always owns `Text`.
  - **Layouts.** With a `layout` prop, or a `UIListLayout` (or another UI*Layout) among the
    children, Rivue keeps each child's `LayoutOrder` in render order. A child that sets
    `LayoutOrder` itself keeps it.
  - **`class`.** A string, a list (applied in order, later wins, `false`/`nil` skipped), or a map
    of name to boolean (enabled names, applied alphabetically: use a list when order matters).
    Precedence, lowest first: app styles, component styles, `style`, the element's own props. A
    component's root also receives the `class` its parent passed.
  - **`layout`.**

    | Value | Result |
    |-------|--------|
    | `"vertical"` / `"horizontal"` | `UIListLayout` in that direction |
    | `"grid"` | `UIGridLayout` |
    | `{ direction, gap, align, justify, wrap }` | `UIListLayout`. `gap` is pixels or a UDim. `align` is the cross axis (`"start"`, `"center"`, `"end"`), `justify` the main axis (also `"space-between"`, `"space-around"`, `"space-evenly"`, `"fill"`). `wrap = true` wraps |
    | `{ grid = UDim2, gap }` | `UIGridLayout` with that cell size |

- **Example**

  ```lua
  local name = Rivue.ref("")
  local Styles = {
  	card = { BackgroundColor3 = Color3.fromRGB(30, 30, 30), cornerRadius = 8, padding = 12 },
  }

  h("Frame", { style = Styles.card, Size = UDim2.fromOffset(300, 120), layout = { gap = 6 } }, {
  	h("TextBox", { model = name, vFocus = true, PlaceholderText = "Name" }),
  	h("TextLabel", {
  		Text = `Hello {name.value}`,
  		onSizeChanged = function(size: UDim2)
  			print("resized", size)
  		end,
  	}),
  })

  -- A toolbar: title on the left, buttons on the right
  local isFull = false
  h("Frame", { Size = UDim2.new(1, 0, 0, 40), layout = { direction = "horizontal", justify = "space-between", align = "center" } }, {
  	h("TextLabel", { Text = "Inventory", flex = "fill" }),
  	h("TextButton", { class = { "button", isFull and "button-disabled" }, Text = "Sort" }),
  })
  ```

---

## Fragment

Renders its children with no wrapper Instance.

- **Type**

  ```lua
  Rivue.Fragment: FragmentType
  ```

- **Details**

  Nested lists in children become Fragments automatically. A component's render function can
  also return a list instead of a single vnode.

- **Example**

  ```lua
  -- Both labels are parented directly to whatever this renders into
  h(Rivue.Fragment, nil, {
  	h("TextLabel", { Text = "One" }),
  	h("TextLabel", { Text = "Two" }),
  })
  ```

---

## hIf()

Returns the vnode when the condition is truthy, otherwise `nil`.

- **Type**

  ```lua
  function hIf(condition: boolean, vnode: VNode?): VNode?
  ```

- **Details**

  Shorthand for `if condition then vnode else nil`. The vnode is created either way, so prefer
  an `if` expression when building it is expensive.

- **Example**

  ```lua
  local loading = Rivue.ref(true)

  h("Frame", nil, {
  	h("TextLabel", { Text = "Inventory" }),
  	Rivue.hIf(loading.value, h("TextLabel", { Text = "Loading..." })),
  })
  ```

---

## hFor()

Maps a list (plain or reactive) to vnodes.

- **Type**

  ```lua
  function hFor<T>(list: { T }, mapper: (item: T, index: number) -> VNode?): { VNode }
  ```

- **Details**

  Returning `nil` from the mapper skips that item. Give each vnode a stable `key` (an id, not
  the index), so reordering moves Instances instead of re-patching them. In Studio, Rivue warns
  when list items have no key. The result can go straight into a children list.

- **Example**

  ```lua
  local items = Rivue.ref({
  	{ id = 1, name = "Sword" },
  	{ id = 2, name = "Shield" },
  })

  h("ScrollingFrame", nil, {
  	h("UIListLayout"),
  	Rivue.hFor(items.value, function(item)
  		return h("TextLabel", { key = item.id, Text = item.name })
  	end),
  })
  ```

---

## mergeProps()

Merges props tables, combining event handlers instead of overwriting them.

- **Type**

  ```lua
  function mergeProps(...: Props?): Props
  ```

- **Details**

  Tables are merged left to right:
  - `on*` handlers are chained, so both run,
  - `__directives` lists and `style` entries are combined,
  - everything else is overwritten by the later table.

  `nil` arguments are skipped.

- **Example**

  ```lua
  local base = {
  	Size = UDim2.fromOffset(100, 40),
  	onClick = function()
  		print("base")
  	end,
  }
  local extra = {
  	Size = UDim2.fromOffset(200, 40),
  	onClick = function()
  		print("extra")
  	end,
  }

  local merged = Rivue.mergeProps(base, extra)
  -- merged.Size is 200x40, and clicking prints "base" then "extra"
  h("TextButton", merged)
  ```

---

## cloneVNode()

Copies a vnode, optionally merging extra props in with [`mergeProps()`](#mergeprops).

- **Type**

  ```lua
  function cloneVNode(vnode: VNode, extraProps: Props?): VNode
  ```

- **Details**

  The copy keeps the original's children, slots and key. This is useful in wrapper components
  that adjust what they were given.

- **Example**

  ```lua
  local Highlight = Rivue.defineComponent(function(_props, ctx)
  	return function()
  		local child = ctx.slots[1]
  		if not Rivue.isVNode(child) then
  			return nil
  		end
  		return Rivue.cloneVNode(child :: Rivue.VNode, { stroke = Color3.new(1, 1, 0) })
  	end
  end, { name = "Highlight" })

  h(Highlight, nil, { h("Frame", { Size = UDim2.fromOffset(50, 50) }) })
  ```

---

## isVNode()

Checks if a value is a vnode created by `h()`.

- **Type**

  ```lua
  function isVNode(value: unknown): boolean
  ```

- **Example**

  ```lua
  print(Rivue.isVNode(h("Frame"))) -- true
  print(Rivue.isVNode({ type = "Frame" })) -- false
  ```

---

## resolveComponent()

Looks up a component registered with [`app:component()`](application.md#appcomponent).

- **Type**

  ```lua
  function resolveComponent(name: string): ComponentDef?
  ```

- **Details**

  Call it in `setup()` or a render function. In Studio it warns when the name isn't
  registered. You rarely need it, because `h("Name")` resolves registered names on its own.

- **Example**

  ```lua
  local Toolbar = Rivue.defineComponent(function()
  	local Icon = Rivue.resolveComponent("Icon")
  	return function()
  		return if Icon then h(Icon, { name = "settings" }) else nil
  	end
  end, { name = "Toolbar" })
  ```

---

## Function components

A function from props to a vnode: no state, no hooks, no instance.

- **Type**

  ```lua
  type FunctionalComponent = (props: Props) -> VNode?
  ```

- **Details**

  A function component runs again every time its parent re-renders. Use one for small
  presentational pieces, and `defineComponent` when you need state or lifecycle.

- **Example**

  ```lua
  local function Pill(props)
  	return h("TextLabel", {
  		Text = props.text,
  		Size = UDim2.fromOffset(80, 24),
  		cornerRadius = 12,
  	})
  end

  h(Pill, { text = "Online" })
  ```

---

[← Reactivity: Advanced](reactivity-advanced.md) · [API reference](../API.md) · [Components →](component.md)
