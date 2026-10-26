[Docs](../README.md) › [Guide](../GUIDE.md) › **13. Component patterns**

# 13. Component patterns

**You'll learn:** five ways to structure components that come up in every bigger game UI: tabs,
shared behaviour with different looks, switching screens, modals, and a parent telling a child
what to do.

## Tabs: components that work as a set

A tab bar has buttons and pages. Clicking a button changes which page is shown. You could write
one big `Tabs` component that takes a list of pages. But then every screen with tabs has to fit
that one layout.

It's more flexible to make three small components that work together:

![the parts of a Tabs component](../images/tabs-parts.svg)

The buttons and pages need the same piece of state: which tab is active. Passing it as props to
every button and page would be tedious. Instead, `Tabs` **provides** it once, and every `Tab` and
`TabPanel` inside, however deep, **injects** it (see [chapter 8](08-state-and-server.md) for
provide and inject).

First `Tabs`. It holds the active tab and provides it, together with a function to change it:

```lua
local TABS = "tabs" -- the key all three components use to find the shared state

local Tabs = Rivue.defineComponent({
	name = "Tabs",
	props = { initial = { type = "string", required = true } },
	setup = function(props)
		local active = Rivue.ref(props.initial)
		Rivue.provide(TABS, {
			active = active,
			select = function(name: string)
				active.value = name
			end,
		})
		return {}
	end,
	render = function(ctx)
		return h("Frame", { layout = { gap = 4 } }, ctx.renderSlot("default"))
	end,
})
```

A `Tab` is a button. It injects the shared state to know if it's selected, and calls `select`
when clicked:

```lua
local Tab = Rivue.defineComponent({
	name = "Tab",
	props = { name = { type = "string", required = true } },
	setup = function(props)
		local tabs = Rivue.inject(TABS)
		return {
			tabs = tabs,
			select = function()
				tabs.select(props.name)
			end,
		}
	end,
	render = function(ctx)
		local selected = ctx.tabs.active.value == ctx.name
		return h("TextButton", {
			class = { "tab", selected and "tab-selected" },
			Text = ctx.name,
			onClick = ctx.select,
		})
	end,
})
```

> Why `ctx.tabs.active.value` and not `ctx.tabs.active`? `ctx` only unwraps refs that `setup`
> returns directly. `active` is a ref *inside* a table, so it keeps its `.value`.

A `TabPanel` shows its content only while its tab is active, and renders nothing otherwise:

```lua
local TabPanel = Rivue.defineComponent({
	name = "TabPanel",
	props = { name = { type = "string", required = true } },
	setup = function()
		return { tabs = Rivue.inject(TABS) }
	end,
	render = function(ctx)
		if ctx.tabs.active.value ~= ctx.name then
			return nil
		end
		return h("Frame", { Size = UDim2.fromScale(1, 1) }, ctx.renderSlot("default"))
	end,
})
```

Now a screen can arrange them however it likes. Buttons on top, on the side, or mixed with other
UI:

```lua
h(Tabs, { initial = "Shop" }, {
	h("Frame", { layout = "horizontal" }, {
		h(Tab, { name = "Shop" }),
		h(Tab, { name = "Bag" }),
	}),
	h(TabPanel, { name = "Shop" }, { h(ShopList) }),
	h(TabPanel, { name = "Bag" }, { h(Inventory) }),
})
```

The same idea works for menus and their items, accordions, or a radio group and its options.

## Same behaviour, different looks

Lots of things in a game react to the mouse hovering over them. An item card grows, a button
shows a tooltip. The hover logic is the same every time, but what changes on screen isn't.

`Hoverable` handles the hovering and draws nothing visible itself. It passes `hovered` to its
slot, and whoever uses it decides what to draw:

```lua
local Hoverable = Rivue.defineComponent({
	name = "Hoverable",
	setup = function()
		local hovered = Rivue.ref(false)
		return {
			hovered = hovered,
			enter = function()
				hovered.value = true
			end,
			leave = function()
				hovered.value = false
			end,
		}
	end,
	render = function(ctx)
		-- An invisible frame to catch the mouse, with the slot inside it
		return h("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			onMouseEnter = ctx.enter,
			onMouseLeave = ctx.leave,
		}, ctx.renderSlot("default", { hovered = ctx.hovered }))
	end,
})
```

The second argument to `renderSlot` is passed to the slot function. That's why the slot is a
function here, instead of a list of children:

```lua
h(Hoverable, nil, {
	default = function(slot)
		return h("TextLabel", {
			Text = if slot.hovered then "Sell for 40 coins" else "Iron Sword",
		})
	end,
})
```

If the behaviour doesn't need an Instance of its own, a [composable](12-writing-composables.md)
is simpler. `Hoverable` needs one, because something has to receive the mouse events.

## Switching screens

A game has a lobby, a shop and a settings screen, and shows one at a time. `h()` accepts a
component stored in a variable, so switching screens is just picking which component to pass:

```lua
local screens = { lobby = Lobby, shop = Shop, settings = Settings }

local App = Rivue.defineComponent({
	name = "App",
	setup = function()
		return { screen = Rivue.ref("lobby") }
	end,
	render = function(ctx)
		return h(Rivue.KeepAlive, { include = { "Shop" } }, {
			h(screens[ctx.screen], {
				onNavigate = function(name)
					ctx.screen = name
				end,
			}),
		})
	end,
})
```

Normally a screen is destroyed when you switch away from it. `KeepAlive` keeps the ones listed
in `include` alive instead, so when the player comes back to the shop, it's still scrolled to
where they left it.

## Modals

A "Buy this item?" popup usually opens from deep inside the UI, from an item card in a list in
the shop. It still has to appear above everything, fade in and out, and close when the player
clicks outside it.

Three built-ins handle one job each:

| Piece | What it does |
|---|---|
| `Teleport` | moves the popup's Instances to a top layer, so nothing covers or clips it |
| `Transition` | fades it in when it appears and out when it goes |
| `vClickOutside` | calls a function when the player clicks anywhere outside it |

![Teleport moves a modal to the top layer](../images/teleport-modal.svg)

```lua
local Modal = Rivue.defineComponent({
	name = "Modal",
	props = {
		open = { type = "boolean", required = true },
		layer = { type = "Instance" }, -- a ScreenGui on top of the others
	},
	emits = { "close" },
	render = function(ctx)
		return h(Rivue.Teleport, { to = ctx.layer, disabled = ctx.layer == nil }, {
			h(Rivue.Transition, { tweenInfo = TweenInfo.new(0.15), from = { BackgroundTransparency = 1 } }, {
				Rivue.hIf(
					ctx.open,
					h("Frame", {
						class = "modal",
						vClickOutside = function()
							ctx.emit("close")
						end,
					}, ctx.renderSlot("default"))
				),
			}),
		})
	end,
})
```

There's a full version with a backdrop and buttons in
[examples/components/Modal.luau](../../examples/components/Modal.luau).

## Telling a child what to do

Usually a parent controls a child through props. But some things are actions, not state: "clear
the form", "scroll to the top". There's no prop for "do this once, now".

For these, the child **exposes** functions, and the parent calls them through a template ref:

```lua
local Form = Rivue.defineComponent({
	name = "Form",
	setup = function(_props, ctx)
		local name = Rivue.ref("")
		-- What a parent holding a ref to this Form can call
		ctx.expose({
			reset = function()
				name.value = ""
			end,
		})
		return { name = name }
	end,
	render = function()
		return h("TextBox", { model = "name" })
	end,
})

local Page = Rivue.defineComponent({
	name = "Page",
	setup = function()
		local form = Rivue.useTemplateRef("form") -- filled in once the Form with ref = "form" mounts
		return {
			clear = function()
				(form.value :: any).reset()
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { layout = { gap = 8 } }, {
			h(Form, { ref = "form" }),
			h("TextButton", { Text = "Clear", onClick = ctx.clear }),
		})
	end,
})
```

Keep exposed functions few and small. If the parent needs to read the child's data, that data
should probably live in the parent and be passed down as a prop.

---

**Try it:** [Tabs example](../../examples/components/Tabs.luau) · [Modal example](../../examples/components/Modal.luau)
**Reference:** [provide()](../api/component.md#provide) · [Slots](../api/component.md#slots) ·
[KeepAlive](../api/builtins.md#keepalive) · [Teleport](../api/builtins.md#teleport) ·
[useTemplateRef()](../api/component.md#usetemplateref)

[← 12. Writing composables](12-writing-composables.md) · [Guide contents](../GUIDE.md) · [14. Organising state →](14-state-architecture.md)
