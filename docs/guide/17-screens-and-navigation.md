[Docs](../README.md) › [Guide](../GUIDE.md) › **17. Screens and navigation**

# 17. Screens and navigation

A lobby, a shop, an item page, settings: once a game has more than two or three screens, you
want a back button that works, screens that pass each other data, and a way to stop the player
leaving a form half filled in. That's what RivueRouter is for.

[Chapter 13](13-advanced-components.md#switching-screens) switched screens with a lookup table,
which is still the right call for tabs. Reach for the router once screens open other screens.

## Setting it up

RivueRouter is its own package, like Vue Router. Install it next to RivueUI (see the
[README](../../README.md#installation)) and it finds RivueUI by itself.

![how the router, RouterView and the screens fit together](../assets/diagrams/router-setup.webp)

Give each screen a name, pick the first one, and put a `RouterView` where screens should appear:

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
local Router = require(game.ReplicatedStorage.RivueRouter)
local h = Rivue.h

local router = Router.createRouter({
	routes = {
		lobby = Lobby,
		shop = Shop,
		item = Item,
		settings = Settings,
	},
	initial = "lobby",
})

local App = Rivue.defineComponent({
	name = "App",
	render = function()
		return h("ScreenGui", { ResetOnSpawn = false }, {
			h(Router.RouterView),
		})
	end,
})

local app = Rivue.createApp(App)
app:use(router)
app:mountToPlayerGui(game.Players.LocalPlayer)
```

`app:use(router)` has to come before mounting. Any component inside the app can then get the
router with `Router.useRouter()`.

## Moving between screens

Four functions move you around. The history works like a browser's:

![push, back, forward and replace on the history](../assets/diagrams/router-history.webp)

```lua
local router = Router.useRouter()

router.push("shop") -- open a screen, add it to the history
router.back() -- the screen before
router.forward() -- undo a back
router.replace("lobby") -- swap the current screen, without adding to the history
```

Two things to know:

- Pushing after going back drops the screens you could have gone forward to (step 4 in the
  picture).
- `replace` suits screens you never want to come back to, like a loading or login screen. After
  `replace`, `back` skips it.

All four return `false` when they don't move, either because there's nowhere to go or a guard
said no.

## Passing data to a screen

The second argument to `push` becomes the screen's props:

```lua
local Item = Rivue.defineComponent({
	name = "Item",
	props = {
		id = { type = "string", required = true },
	},
	setup = function(props)
		local item = Rivue.computed(function()
			return Catalog[props.id]
		end)
		return { item = item }
	end,
	render = function(ctx)
		return h("TextLabel", { Text = ctx.item.name })
	end,
})

-- In the shop
router.push("item", { id = "sword" })
```

Pass ids, and let the screen look the rest up in a store. If you pass the whole item table
instead, going back to that screen later shows the item as it was when you pushed it, even if
the store has changed since.

## A back button

`canGoBack` is a ref, so a back button can hide itself on the first screen. Bind Escape and the
gamepad's B button to it too, but only while there's somewhere to go back to:

```lua
local BackButton = Rivue.defineComponent({
	name = "BackButton",
	setup = function()
		local router = Router.useRouter()
		Rivue.useKeybind({ Enum.KeyCode.Escape, Enum.KeyCode.ButtonB }, function()
			router.back()
		end, { enabled = router.canGoBack })
		return { canGoBack = router.canGoBack, back = router.back }
	end,
	render = function(ctx)
		return h("TextButton", { Text = "Back", Visible = ctx.canGoBack, onActivated = ctx.back })
	end,
})
```

Put it in `App`, next to the `RouterView`, rather than in each screen. Then there's one binding
for the whole game.

## Stopping the player from leaving

`beforeEach` runs before every move, `back` and `forward` included. Return `false` to cancel:

![a guard deciding whether a move goes ahead](../assets/diagrams/router-guard.webp)

The usual case is a settings screen with changes that aren't saved yet, which the player leaves
with Back. Cancel the move and ask. If the player says leave, mark the changes as dropped and go
back again, which the guard now lets through:

```lua
local Settings = Rivue.defineComponent({
	name = "Settings",
	setup = function()
		local router = Router.useRouter()
		local dirty = Rivue.ref(false)
		local asking = Rivue.ref(false)

		local removeGuard = router.beforeEach(function(_to, from)
			if from.name == "settings" and dirty.value then
				asking.value = true
				return false
			end
			return true
		end)
		Rivue.onUnmounted(removeGuard)

		return {
			asking = asking,
			change = function()
				dirty.value = true
			end,
			stay = function()
				asking.value = false
			end,
			leave = function()
				asking.value = false
				dirty.value = false
				router.back()
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { Size = UDim2.fromScale(1, 1) }, {
			h("TextButton", { Text = "Music: on", onActivated = ctx.change }),
			h(Rivue.Dialog, { open = ctx.asking, onClose = ctx.stay }, {
				h(Rivue.Column, { gap = 12 }, {
					h("TextLabel", { Text = "Leave without saving?", Size = UDim2.fromOffset(240, 30) }),
					h(Rivue.Row, { gap = 8 }, {
						h("TextButton", { Text = "Stay", Size = UDim2.fromOffset(100, 36), onActivated = ctx.stay }),
						h("TextButton", { Text = "Leave", Size = UDim2.fromOffset(100, 36), onActivated = ctx.leave }),
					}),
				}),
			}),
		})
	end,
})
```

A few details from that example:

- `beforeEach` returns a function that removes the guard. Call it in `onUnmounted`, or the guard
  outlives the screen.
- Guards get the route being left as `from`, so one guard can ignore every screen but its own.
- A guard is told where the player is going (`to`), but not whether it was a `push` or a `back`.
  If Settings can also open other screens, have those buttons save changes first.
- A guard that errors cancels the move and logs a warning, so a bug in a guard can't send the
  player somewhere half set up.

## Keeping screens alive

Normally a screen is unmounted when you leave it, and mounted fresh when you come back. For a
shop with a search box and a long scrolling list, that loses the player's place. Turn on
`keepAlive`:

```lua
h(Router.RouterView, { keepAlive = true })
```

Screens you leave now stay in a [KeepAlive](../api/builtins.md#keepalive): the shop is still
scrolled where it was and the search still says "sword". Use `onActivated` and `onDeactivated`
(see [lifecycle hooks](../api/lifecycle.md)) for work that should pause while a screen is hidden.

Each route keeps its own instance, even when two routes use the same component.

## Testing navigation

The router doesn't need a player or a ScreenGui. Mount the app into a Folder, move around, and
check `current`:

```lua
local router = Router.createRouter({ routes = { lobby = Lobby, item = Item }, initial = "lobby" })
local app = Rivue.createApp(App)
app:use(router)
app:mount(Instance.new("Folder"))

router.push("item", { id = "sword" })
assert(router.current.value.name == "item")
assert(router.canGoBack.value)

router.back()
assert(router.current.value.name == "lobby")
app:unmount()
```

---

**Try it:** the router suite in [tests/AppFeatures.test.luau](../../tests/AppFeatures.test.luau)
**Reference:** [RivueRouter](../api/router.md) · [KeepAlive](../api/builtins.md#keepalive) ·
[Dialog](../api/builtins.md#dialog) · [useKeybind()](../api/roblox.md#usekeybind)

[← 16. Testing UI](16-testing-ui.md) · [Guide contents](../GUIDE.md)
