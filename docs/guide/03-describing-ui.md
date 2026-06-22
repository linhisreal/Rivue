[Docs](../README.md) › [Guide](../GUIDE.md) › **3. Describing UI**

# 3. Describing UI with h()

Everything on screen in a Rivue UI comes from calls to `h()`. This chapter goes through what you
can pass it, and how to show things only sometimes, or once per item in a list.

## One call per Instance

```lua
h("Frame", { Size = UDim2.fromScale(1, 1), cornerRadius = 8 }, {
	h("TextLabel", { Text = "Inventory" }),
	h("TextButton", { Text = "Close", onClick = close }),
})
```

One `h(type, props, children)` call describes one Instance. The type is a ClassName like
`"Frame"`, a component, or a name you registered (`"ItemRow"`). Props are everything in the table
below, and children come last.

## What a prop can be

| You write | Rivue does |
|---|---|
| `Size = ...`, `Text = ...` | sets the Instance property (camelCase `size` works too) |
| `onClick = fn`, `onMouseEnter = fn` | connects the event (`onClick` works on any button) |
| `onSizeChanged = fn`, `onTextChanged = fn` | calls `fn(newValue)` when that property changes |
| `cornerRadius = 8`, `padding = 12`, `stroke = color`, `aspectRatio = 1` | creates the UICorner / UIPadding / UIStroke / UIAspectRatioConstraint |
| `gradient = { top, bottom, rotation = 90 }`, `scale = 1.2`, `sizeLimit = { max = size }`, `textSizeLimit = { min = 12, max = 32 }` | creates the UIGradient / UIScale / UISizeConstraint / UITextSizeConstraint |
| `layout = "vertical"`, `flex = "fill"` | creates the list/grid layout and flex items, see [chapter 6](06-styling-and-layout.md) |
| `class = "card"` | applies named styles, see [chapter 6](06-styling-and-layout.md) |
| `vFocus = true`, `vShow = open` | applies a directive, see [chapter 5](05-forms-and-input.md) |
| `key = item.id` | identifies a list item (below) |
| `ref = "input"` | gives setup access to the Instance, see [useTemplateRef()](../api/component.md#usetemplateref) |

Children can be a list, a single vnode, or a string (which sets `Text` on a label or button).
Lists can hold other lists and `nil`, which is what makes conditions and loops work.

## Conditions

There's no special syntax for conditions. A render function is plain Luau, so you write an `if`
expression, or `Rivue.hIf` if you like it shorter:

```lua
render = function(ctx)
	return h("Frame", { layout = "vertical" }, {
		h("TextLabel", { Text = "Inventory" }),
		if ctx.loading then h("TextLabel", { Text = "Loading..." }) else nil,
		Rivue.hIf(ctx.isEmpty, h("TextLabel", { Text = "Nothing here yet" })),
	})
end,
```

For something that toggles a lot, you can keep it mounted and set `vShow = condition` instead. That
hides it without destroying it.

## Lists and keys

For lists, `Rivue.hFor(list, fn)` turns each item into a vnode. The result goes straight into a
children list:

```lua
h("ScrollingFrame", { layout = "vertical" }, {
	Rivue.hFor(ctx.items, function(item)
		return h("TextLabel", { key = item.id, Text = item.name })
	end),
})
```

Give every list item a `key`, and make it something that belongs to the item, like an id. Its
position in the list won't do. Keys are how Rivue tells which Instance is which when the list
changes:

![keys let Rivue keep the right Instances](../assets/diagrams/keyed-list.webp)

Leave them out and removing one row re-patches every row after it. Worse, state inside a row
component, like a hover or a half-typed value, ends up on the wrong item.

---

**Try it:** [Inventory example](../../examples/components/Inventory.luau) (a long keyed list)
**Reference:** [h()](../api/render-function.md#h) · [Element props](../api/render-function.md#element-props) ·
[hIf()](../api/render-function.md#hif) · [hFor()](../api/render-function.md#hfor)

[← 2. State](02-state.md) · [Guide contents](../GUIDE.md) · [4. Components →](04-components.md)
