[Docs](../README.md) › [API](../API.md) › **Vapor mode**

# Vapor mode (experimental)

A component in Vapor mode renders once. After that, nothing re-renders: state reaches Instances
through [bindings](render-function.md#bind), and the parts of the tree that come and go use
`createIf` and `createFor`, which update only their own children. It follows Vue 3.6's Vapor mode.
Examples assume `local Rivue = require(game.ReplicatedStorage.RivueUI)` and `local h = Rivue.h`.

> [!WARNING]
> Vapor mode is experimental, as it is in Vue 3.6, where it's still in beta. Names and behaviour
> may change between releases. Keep it off for games you ship until it's stable.

---

## Turning it on

Vapor mode needs two switches: the app has to allow it, and each component opts in.

```lua signature
app.config.experimental: { vapor: boolean? }?
```

| Option | Type | Default | Description |
|---|---|---|---|
| `app.config.experimental.vapor` | `boolean?` | `false` | lets components in this app use Vapor mode |
| `vapor` (component option) | `boolean?` | `false` | renders this component once, in Vapor mode |

### Example

```lua
local coins = Rivue.ref(0)

local Wallet = Rivue.defineComponent({
	name = "Wallet",
	vapor = true,
	setup = function()
		return function()
			return h("TextLabel", {
				Text = Rivue.bind(function()
					return `Coins: {coins.value}`
				end),
			})
		end
	end,
})

local app = Rivue.createApp(Wallet)
app.config.experimental = { vapor = true }
app:mount(Instance.new("Folder"))

coins.value = 10 -- updates the label's Text; the component doesn't render again
```

> [!WARNING]
> A value read directly in a Vapor render is used once and never updates. In the example,
> `Text = tostring(coins.value)` would show `0` forever. Pass a ref or `Rivue.bind(...)` for
> anything that changes.

### Details

- Without the app flag, a component with `vapor = true` renders normally and warns once.
- Set the flag before `app:mount()`.
- Lifecycle hooks, `provide`/`inject` and error handling work as in any component.
- The [DevTools plugin](../DEVTOOLS.md) shows a Vapor component's props and state as they change,
  and what changed them. Its render count stays at 1, because that's the only render.
- Vapor and normal components can be mixed in one tree.
- A Vapor component doesn't render again when its slots change. Pass changing content through
  props instead.

---

## createIf()

Shows one of two branches and swaps them when a condition changes, without re-rendering the
component around it. The Vapor version of [`hIf()`](render-function.md#hif).

```lua signature
function createIf(cond: () -> boolean, yes: () -> VNode?, no: (() -> VNode?)?): VNode
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `cond` | `() -> boolean` | | read again whenever the state it uses changes |
| `yes` | `() -> VNode?` | | builds the branch shown while `cond` is true |
| `no` | `(() -> VNode?)?` | | builds the branch shown while it's false; nothing shows if omitted |

**Returns** a vnode to place among the children.

### Example

```lua
local open = Rivue.ref(false)

local Shop = Rivue.defineComponent({
	name = "Shop",
	vapor = true,
	setup = function()
		return function()
			return h("Frame", nil, {
				Rivue.createIf(function()
					return open.value
				end, function()
					return h("TextLabel", { Text = "Open" })
				end, function()
					return h("TextLabel", { Text = "Closed" })
				end),
			})
		end
	end,
})

local app = Rivue.createApp(Shop)
app.config.experimental = { vapor = true }
app:mount(Instance.new("Folder"))

open.value = true -- swaps the label; the Frame stays as it is
```

### Details

- A branch is built again only when `cond` changes from true to false or back. State read while
  building a branch isn't tracked, so use bindings inside it.
- It also works in normal components; a re-render of the component rebuilds the shown branch.

---

## createFor()

Renders a keyed list and keeps it in step with its source, rebuilding only rows that are new. The
Vapor version of [`hFor()`](render-function.md#hfor).

```lua signature
function createFor<T>(
	source: () -> { T },
	keyOf: (item: T, index: number) -> unknown,
	row: (item: T, index: number) -> VNode?
): VNode
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source` | `() -> { T }` | | returns the list; read again whenever the state it uses changes |
| `keyOf` | `(item: T, index: number) -> unknown` | | a key that stays the same for an item, such as its id |
| `row` | `(item: T, index: number) -> VNode?` | | builds one row |

**Returns** a vnode to place among the children.

### Example

```lua
local players = Rivue.ref({
	{ id = 1, name = "Ada" },
	{ id = 2, name = "Grace" },
})

local Scoreboard = Rivue.defineComponent({
	name = "Scoreboard",
	vapor = true,
	setup = function()
		return function()
			return h("Frame", nil, {
				h("UIListLayout"),
				Rivue.createFor(function()
					return players.value
				end, function(player)
					return player.id
				end, function(player)
					return h("TextLabel", { Text = player.name })
				end),
			})
		end
	end,
})

local app = Rivue.createApp(Scoreboard)
app.config.experimental = { vapor = true }
app:mount(Instance.new("Folder"))

local list = players.value
players.value = { list[2], list[1], { id = 3, name = "Linus" } } -- moves two rows, builds one
```

### Details

- A row is reused while its item is the same table. Replace an item and its row is built again,
  then patched onto the same Instance.
- Rows follow the list's order through `LayoutOrder` when a layout object such as
  `UIListLayout` is among the block's siblings, as in the example. A layout added with the
  `layout` prop doesn't count.
- Duplicate keys warn in Studio, as they do for keyed children.
- `keyOf` and `row` aren't tracked; the list itself is.

---

## Getter props

Since a Vapor component renders once, it can't pass a child a new value by rendering again. It
passes a ref, or a `Rivue.bind(...)` getter, instead, and Rivue keeps the child's prop in step with
it. This is how Vue's Vapor mode passes props too.

### Example

```lua
local score = Rivue.ref(1)

local Badge = Rivue.defineComponent({
	name = "Badge",
	props = { value = { type = "number" } },
	setup = function(props)
		return function()
			return h("TextLabel", { Text = tostring(props.value) })
		end
	end,
})

local Panel = Rivue.defineComponent({
	name = "Panel",
	vapor = true,
	setup = function()
		return function()
			return h(Badge, { value = score })
		end
	end,
})

local app = Rivue.createApp(Panel)
app.config.experimental = { vapor = true }
app:mount(Instance.new("Folder"))

score.value = 7 -- Badge's props.value becomes 7
```

### Details

- It applies when the parent or the child is a Vapor component. Between two normal components a
  ref still arrives as the ref itself.
- The child reads a plain value: `props.value` is `7`, not a ref.
- A normal child re-renders when the value changes; a Vapor child updates through its own bindings.
