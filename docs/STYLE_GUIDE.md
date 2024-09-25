# Rivue Style Guide

Conventions for writing Rivue code that stays readable as a game grows. It's modelled on Vue's
style guide: rules are grouped by priority, and each has a bad and a good example.

- **[A. Essential](#a-essential)**: prevent bugs. Follow them.
- **[B. Strongly recommended](#b-strongly-recommended)**: keep code readable and consistent.
  Follow them unless you have a good reason not to.
- **[C. Recommended](#c-recommended)**: pick one way of doing things across the project.

Also: [Project structure](#project-structure) · [Anatomy of a component](#anatomy-of-a-component)

---

## Project structure

Group UI by role. One component per ModuleScript, named after the component.

```
ReplicatedStorage/
  Rivue/                     the library
  UI/
    App.luau                 root component: picks the current view
    styles.luau              app-wide styles, registered with app:styles()
    views/                   screens: Lobby, Shop, Inventory, Settings
      Shop.luau
    components/              reusable pieces: Button, Card, ItemRow, Modal
      ItemRow.luau
    composables/             reusable logic: useInventory, useCountdown
      useCountdown.luau
StarterPlayerScripts/
  UI.client.luau             createApp(App):styles(styles):mountToPlayerGui(player)
```

- **Views** lay out components and own a screen's state. They contain little markup of their own.
- **Components** take props, emit events and own only their own UI state.
- **Composables** (`use*` functions) hold logic shared between components: timers, data
  loading, input handling.
- **Styles** live in style tables, not inline in render functions.

`src/shared/Demo` in this repo follows this layout.

---

## Anatomy of a component

Write the parts of a component in this order, so every file reads the same way:

```lua
local ItemRow = require(script.Parent.ItemRow)

return Rivue.defineComponent({
	name = "Inventory",              -- 1. name
	components = { ItemRow = ItemRow }, -- 2. local components
	props = {                         -- 3. props
		items = { type = "table", required = true },
	},
	emits = { "select" },             -- 4. emits
	styles = {                        -- 5. styles used only here
		list = { Size = UDim2.fromScale(1, 1) },
	},

	setup = function(props, ctx)      -- 6. setup: state, computed, functions, watchers, hooks
		local selectedId = Rivue.ref(nil :: number?)

		local count = Rivue.computed(function()
			return #props.items
		end)

		local function select(id: number)
			selectedId.value = id
			ctx.emit("select", id)
		end

		return { selectedId = selectedId, count = count, select = select }
	end,

	render = function(ctx)            -- 7. render: markup only
		return h("ScrollingFrame", { class = "list", layout = "vertical" }, {
			Rivue.hFor(ctx.items, function(item)
				return h("ItemRow", { key = item.id, item = item, onSelect = ctx.select })
			end),
		})
	end,
})
```

---

## A. Essential

### Give every list item a stable key

Keys identify items between renders. Without them, Rivue patches by position: every item after a
removed one is rewritten, and component state ends up on the wrong row.

```lua
-- Bad
Rivue.hFor(items, function(item)
	return h(ItemRow, { item = item })
end)

-- Bad: the index isn't stable when items move
Rivue.hFor(items, function(item, index)
	return h(ItemRow, { key = index, item = item })
end)

-- Good
Rivue.hFor(items, function(item)
	return h(ItemRow, { key = item.id, item = item })
end)
```

### Read reactive state inside render, not in setup

Only reads made while rendering are tracked. A value copied in `setup` never updates.

```lua
-- Bad
setup = function(props)
	local title = props.title -- copied once
	return function()
		return h("TextLabel", { Text = title })
	end
end

-- Good
render = function(ctx)
	return h("TextLabel", { Text = ctx.title })
end
```

### Edit reactive arrays with Rivue.array

`table.insert`, `table.remove` and `table.sort` work on the raw table, so on a reactive array they
silently do nothing (or worse).

```lua
-- Bad
table.insert(state.todos, todo)

-- Bad: works, but hard to read and easy to get wrong
local list = table.clone(Rivue.toRaw(todos.value))
table.insert(list, todo)
todos.value = list

-- Good
Rivue.array.push(todos.value, todo)
Rivue.array.removeWhere(todos.value, function(t)
	return t.done
end)
```

### Never change props, emit an event

Props belong to the parent. Change state where it lives.

```lua
-- Bad
onClick = function()
	ctx.selected = true
end

-- Good
emits = { "select" },
-- ...
onClick = function()
	ctx.emit("select", ctx.item.id)
end
```

### Keep render functions free of side effects

Render runs whenever its state changes, possibly many times a second. Don't change state, connect
signals or call the server there. Do that in `setup`, watchers or event handlers.

```lua
-- Bad
render = function(ctx)
	ctx.renders += 1
	Rivue.Remote.fire("seen", nil)
	return h("Frame")
end

-- Good
setup = function()
	Rivue.onMounted(function()
		Rivue.Remote.fire("seen", nil)
	end)
	return {}
end,
```

### Clean up what you connect

Watchers, computeds and `Rivue.onHeartbeat` connections made in `setup` stop on their own.
Connections you create yourself don't.

```lua
-- Bad
setup = function()
	workspace.ChildAdded:Connect(onAdded)
	return {}
end

-- Good
setup = function()
	local conn = workspace.ChildAdded:Connect(onAdded)
	Rivue.onUnmounted(function()
		conn:Disconnect()
	end)
	return {}
end
```

### Name components

`name` shows up in errors, warnings, `printTree()` and as the root Instance's name in the Explorer.
Without it, all you see is `<Anonymous>`.

```lua
-- Bad
Rivue.defineComponent({ setup = setup, render = render })

-- Good
Rivue.defineComponent({ name = "ItemRow", setup = setup, render = render })
```

---

## B. Strongly recommended

### One component per ModuleScript

The file name matches `name`. Small private helpers used by one component can stay in its file.

```
-- Bad
components/Shop.luau      -- Shop, ShopItem, PriceTag, BuyButton all inside

-- Good
components/ShopItem.luau
components/PriceTag.luau
views/Shop.luau
```

### Split render functions that grow

A good limit is about 40 lines or 4 levels of nesting per render. Past that, pull a piece out
into a component (or a small render helper function).

```lua
-- Bad: one 150-line render with the header, form, list and footer all inline

-- Good
render = function(ctx)
	return h("Frame", { class = "window", layout = { gap = 12 } }, {
		h("ShopHeader", { coins = ctx.coins }),
		h("ProductList", { products = ctx.products, onBuy = ctx.buy }),
		h("ShopFooter"),
	})
end
```

### Move visual props into styles

Inline visuals (colors, fonts, sizes, corners) bury the structure. Name them once and refer to
them with `class`. Keep props that change with state, and one-off layout tweaks, inline.

```lua
-- Bad
h("TextButton", {
	Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = Color3.fromRGB(70, 110, 220),
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	cornerRadius = 6,
	Text = "Buy",
})

-- Good
h("TextButton", { class = "button", Text = "Buy" })
```

- **App-wide styles** go in `UI/styles.luau` and are registered with `app:styles(styles)`.
- **Styles used by one component only** go in its `styles` option.
- **Variants** combine classes: `class = { "button", danger and "button-danger" }`.

### Lay out with the layout prop, not positions

Absolute offsets break when text, screen size or content changes. Let a layout place children.

```lua
-- Bad
h("Frame", nil, {
	h("TextLabel", { Position = UDim2.fromOffset(10, 10) }),
	h("TextBox", { Position = UDim2.fromOffset(10, 50) }),
	h("TextButton", { Position = UDim2.fromOffset(10, 95) }),
})

-- Good
h("Frame", { layout = { gap = 8 }, padding = 10 }, {
	h("TextLabel"),
	h("TextBox"),
	h("TextButton"),
})
```

`layout = { direction = "horizontal", justify = "space-between" }` and `flex = "fill"` on a child
cover most toolbars and rows.

### Return state from setup, render with render(ctx)

`render(ctx)` sits at the top level, reads state without `.value`, and keeps `setup` about logic.

```lua
-- Bad: harder to scan, .value everywhere
setup = function()
	local count = Rivue.ref(0)
	return function()
		return h("TextButton", {
			Text = tostring(count.value),
			onClick = function()
				count.value += 1
			end,
		})
	end
end

-- Good
setup = function()
	local count = Rivue.ref(0)
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
```

The inline form (setup returning a render function) is fine for very small components.

### Declare props with types, and emits

Declared props are validated in Studio. Declared emits keep listeners out of attrs. Annotate the
setup parameter to get autocomplete and typo checks.

```lua
type Props = { item: Item, selected: boolean }

-- ...
props = {
	item = { type = "table", required = true },
	selected = { type = "boolean", default = false },
},
emits = { "select" },
setup = function(props: Props, ctx)
	-- props.selcted is now a type error
end,
```

### Use v props for directives and model for inputs

```lua
-- Bad
h("TextBox", {
	Text = draft.value,
	onTextChanged = function(text)
		draft.value = text
	end,
	__directives = { { name = "focus", value = true } },
})

-- Good
h("TextBox", { model = "draft", vFocus = true })
```

### Share logic with composables, not copied code

When two components need the same stateful logic, put it in a `use*` function in
`UI/composables`.

```lua
-- composables/useCountdown.luau
local function useCountdown(seconds: number)
	local left = Rivue.ref(seconds)
	Rivue.onHeartbeat(function(dt)
		left.value = math.max(0, left.value - dt)
	end)
	return left
end

-- in any component's setup
local timeLeft = useCountdown(30)
```

---

## C. Recommended

### Naming

| Thing | Style | Example |
|-------|-------|---------|
| Component (name and file) | PascalCase | `ItemRow`, `ItemRow.luau` |
| Composable | camelCase with `use` | `useCountdown` |
| Event | camelCase | `emit("select")`, `onSelect` |
| Style class | camelCase or kebab-case, consistently | `primaryButton` or `"button-primary"` |
| Ref holding an Instance | noun | `input`, `list` |

### Prefer `class` lists for variants, maps for toggles

A list applies in order, so put the base first. A map is shorthand for on/off classes, applied in
alphabetical order. Use a list when two classes set the same property.

```lua
class = { "button", primary and "button-primary" } -- base first, variant last
class = { selected = ctx.selected, disabled = ctx.disabled } -- independent toggles
```

### Keep views thin

A view wires components together and owns the screen's state. If it starts drawing rows and
buttons itself, those are components waiting to be extracted.

### Keep composables UI-free

Composables return state and functions, not vnodes. That keeps them usable from any component.

### Use `--!nonstrict` for UI files on the old type solver

The old Luau type solver can't type mixed children lists (`{ header, Rivue.hFor(...) }`). Use
`--!strict` for composables and logic, and `--!nonstrict` for files with render functions, or
`--!strict` everywhere with the new solver.

---

## Tooling

- **Snippets.** `.vscode/rivue.code-snippets` adds `rcomponent`, `rview`, `rcomposable`,
  `rstyles`, `rwatch` and `rcomputed` to VS Code in this workspace. Copy the file into your own
  project's `.vscode/` folder to use them there.
- **Formatting.** StyLua with the repo's `.stylua.toml`.
- **Type checking.** luau-lsp with the Roblox definitions, as in CI.
- **Linting.** Selene doesn't support Luau's `const` yet (still true in 0.30), so it reports parse
  errors on files that use it.
