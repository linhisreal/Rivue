[Docs](../README.md) › [Guide](../GUIDE.md) › **11. Style rules**

# 11. Style rules

**You'll learn:** the habits that keep Rivue code bug-free and easy to read, each with the reason
behind it. The first group prevents real bugs; the second keeps a growing project readable.

## At a glance

| | Rule | Because |
|---|---|---|
| **Must** | [Key every list item](#key-every-list-item) | otherwise rows get rewritten and state lands on the wrong item |
| **Must** | [Read state in render, not setup](#read-state-in-render-not-setup) | only reads during render are tracked |
| **Must** | [Edit lists with Rivue.array](#edit-lists-with-rivuearray) | `table.*` skips the proxy, so nothing updates |
| **Must** | [Emit, don't change props](#emit-dont-change-props) | props belong to the parent |
| **Must** | [Keep render free of side effects](#keep-render-free-of-side-effects) | render can run many times a second |
| **Must** | [Clean up your own connections](#clean-up-your-own-connections) | Rivue only cleans up what it created |
| **Must** | [Name every component](#name-every-component) | errors and the Explorer show `<Anonymous>` otherwise |
| Should | [Put visuals in style classes](#put-visuals-in-style-classes) | the structure stays visible |
| Should | [Lay out with layout, not positions](#lay-out-with-layout-not-positions) | positions break when content changes |
| Should | [Use setup + render](#use-setup--render) | logic and markup stay apart, no `.value` |
| Should | [Declare props and emits](#declare-props-and-emits) | Studio checks them for you |
| Should | [Use model and v props](#use-model-and-v-props) | less wiring, fewer mistakes |

## Must

### Key every list item

Keys tell Rivue which Instance belongs to which item ([chapter 3](03-describing-ui.md#lists-and-keys)).
Use something that belongs to the item: its position changes when the list does.

```lua
-- ✗ No key, or the index as key
Rivue.hFor(items, function(item, index)
	return h("ItemRow", { key = index, item = item })
end)

-- ✓ The item's own id
Rivue.hFor(items, function(item)
	return h("ItemRow", { key = item.id, item = item })
end)
```

### Read state in render, not setup

A value copied in `setup` is a snapshot. It never updates.

```lua
-- ✗ Copied once
setup = function(props)
	local title = props.title
	return { title = title }
end,

-- ✓ Read where it's used
render = function(ctx)
	return h("TextLabel", { Text = ctx.title })
end,
```

### Edit lists with Rivue.array

```lua
-- ✗ Silently does nothing on a reactive list
table.insert(state.todos, todo)

-- ✓
Rivue.array.push(state.todos, todo)
Rivue.array.removeWhere(state.todos, function(t)
	return t.done
end)
```

### Emit, don't change props

Change state where it lives. A child that wants something changed asks its parent with an event.

```lua
-- ✗ The parent's next render overwrites this anyway
onClick = function()
	ctx.selected = true
end

-- ✓
emits = { "select" },
-- ...
onClick = function()
	ctx.emit("select", ctx.item.id)
end
```

### Keep render free of side effects

Render runs whenever its state changes, possibly every frame during an animation. Changing state,
connecting signals or calling the server there causes loops and duplicate requests.

```lua
-- ✗
render = function(ctx)
	Rivue.Remote.fire("seen", nil)
	return h("Frame")
end,

-- ✓
setup = function()
	Rivue.onMounted(function()
		Rivue.Remote.fire("seen", nil)
	end)
	return {}
end,
```

### Clean up your own connections

Watchers, computeds, `onHeartbeat` and `useTag` stop with the component. A `:Connect()` you wrote
doesn't.

```lua
-- ✗ Keeps firing after the component is gone
workspace.ChildAdded:Connect(onAdded)

-- ✓
local conn = workspace.ChildAdded:Connect(onAdded)
Rivue.onUnmounted(function()
	conn:Disconnect()
end)
```

### Name every component

`name` is what you see in errors (`Error in render of <ItemRow> in <Inventory>`), warnings,
`printTree()` and the Explorer.

```lua
Rivue.defineComponent({ name = "ItemRow", setup = setup, render = render })
```

## Should

### Put visuals in style classes

Colours, fonts and sizes written inline bury what the render function is actually building.

```lua
-- ✗
h("TextButton", {
	Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = Color3.fromRGB(70, 110, 220),
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	cornerRadius = 6,
	Text = "Buy",
})

-- ✓
h("TextButton", { class = "button", Text = "Buy" })
```

Keep values that change with state inline (`Visible = ctx.open`). For variants, combine classes:
`class = { "button", danger and "button-danger" }`.

### Lay out with layout, not positions

![layout = "vertical", "horizontal" and grid](../images/layout-direction.svg)

```lua
-- ✗ Breaks as soon as a label wraps
h("TextLabel", { Position = UDim2.fromOffset(10, 10) }),
h("TextBox", { Position = UDim2.fromOffset(10, 50) }),

-- ✓
h("Frame", { layout = { gap = 8 }, padding = 10 }, {
	h("TextLabel"),
	h("TextBox"),
})
```

### Use setup + render

Return state from `setup` and write markup in `render(ctx)`: no `.value`, and each half reads on
its own. Returning a render function from `setup` is fine for components of a few lines.

### Declare props and emits

Declared props are validated in Studio. Declared emits keep `on*` listeners out of the attributes
passed to the root. Annotate setup's parameter for autocomplete:

```lua
type Props = { item: Item, selected: boolean }

setup = function(props: Props, ctx)
	-- props.selcted is now a type error
end,
```

### Use model and v props

```lua
-- ✗
h("TextBox", {
	Text = draft.value,
	onTextChanged = function(text)
		draft.value = text
	end,
})

-- ✓
h("TextBox", { model = "draft", vFocus = true })
```

## Naming

| Thing | Style | Example |
|---|---|---|
| Component, and its file | PascalCase | `ItemRow`, `ItemRow.luau` |
| Composable | camelCase starting with `use` | `useCountdown` |
| Event | camelCase | `emit("select")` → `onSelect` |
| Style class | pick camelCase or kebab-case and stick to it | `primaryButton` or `"button-primary"` |

## Tooling

- **Snippets.** `.vscode/rivue.code-snippets` adds `rcomponent`, `rview`, `rcomposable`,
  `rstyles`, `rwatch` and `rcomputed`. Copy it into your own project's `.vscode/` to use them.
- **Formatting and types.** StyLua with the repo's `.stylua.toml`, and luau-lsp with the Roblox
  definitions.
- **Strict mode.** The old Luau type solver can't type mixed children lists
  (`{ header, Rivue.hFor(...) }`). Use `--!strict` for logic and composables and `--!nonstrict` for
  files with render functions, or `--!strict` everywhere with the new solver.

---

**You've finished the Guide.** Keep the [API reference](../API.md) open while you build, and
browse the [examples](../../examples) when you want to see a feature in a real component.

[← 10. Organising a project](10-organising-a-project.md) · [Guide contents](../GUIDE.md)
