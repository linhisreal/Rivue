[Docs](../README.md) › [API](../API.md) › **Roblox composables**

# Roblox composables

**Learn it:** [Guide 6: Styling and layout](../guide/06-styling-and-layout.md) · [Guide 7: Effects and animation](../guide/07-effects-and-animation.md)

Composables for engine state: devices, input, language, scrolling, attributes, tags, frames and
animation. Call them in `setup()`, or inside an `effectScope`, so they clean up on their own.
Examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
local h = Rivue.h
local Players = game:GetService("Players")
```

---

## useDevice()

The kind of device the game runs on. Style classes use it for their device variants, and you can
read it to change layout.

```lua signature
function useDevice(): Ref<"phone" | "tablet" | "desktop" | "console">
```

**Returns** a shared ref that updates when the screen size changes. It's never stopped, so it's
safe to read in render.

### Example

```lua
local Navigation = Rivue.defineComponent({
	name = "Navigation",
	setup = function()
		return { device = Rivue.useDevice() }
	end,
	render = function(ctx)
		if ctx.device == "phone" then
			return h("Frame", { Name = "BottomBar", Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1) })
		end
		return h("Frame", { Name = "SideBar", Size = UDim2.new(0, 220, 1, 0) })
	end,
})
```

### Details

- `"console"` when `GuiService:IsTenFootInterface()` is true.
- On a touch screen without a keyboard, `"phone"` when the short side is under 500 pixels and
  `"tablet"` otherwise. Using the short side keeps a phone held sideways a phone.
- Everything else is `"desktop"`.

---

## useViewportSize()

The screen size in pixels, kept up to date as the window resizes or the phone rotates.

```lua signature
function useViewportSize(): Ref<Vector2>
```

**Returns** a shared ref of `workspace.CurrentCamera.ViewportSize`. It follows the camera if it's
replaced. Treat it as read-only.

### Example

```lua
local Sidebar = Rivue.defineComponent({
	name = "Sidebar",
	setup = function()
		return { viewport = Rivue.useViewportSize() }
	end,
	render = function(ctx)
		local narrow = ctx.viewport.X < 700
		return h("Frame", {
			Size = if narrow then UDim2.fromScale(1, 0.3) else UDim2.new(0, 280, 1, 0),
			Position = if narrow then UDim2.fromScale(0, 0.7) else UDim2.new(),
		}, ctx.renderSlot("default"))
	end,
})
```

---

## useKeybind()

Runs a function when a key or gamepad button is pressed, while the component is mounted. It unbinds
itself on unmount.

```lua signature
function useKeybind(
	keys: Enum.KeyCode | Enum.UserInputType | { Enum.KeyCode | Enum.UserInputType },
	callback: (input: InputObject) -> (),
	options: { enabled: MaybeRefOrGetter<boolean>?, priority: number?, passThrough: boolean? }?
)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `keys` | `Enum.KeyCode \| Enum.UserInputType \| { ... }` | | one key or input type, or a list |
| `callback` | `(input: InputObject) -> ()` | | runs on each press |
| `options.enabled` | `MaybeRefOrGetter<boolean>` | `true` | a ref, getter or boolean; the binding only exists while it's true |
| `options.priority` | `number` | `Enum.ContextActionPriority.High` | the ContextActionService priority |
| `options.passThrough` | `boolean` | `false` | let the game act on the key too |

> [!NOTE]
> It uses ContextActionService, so while it's bound the key is taken from the game: the character
> doesn't also act on it, unless `passThrough` is set.

### Example

```lua
local Menu = Rivue.defineComponent({
	name = "Menu",
	setup = function()
		local open = Rivue.ref(true)
		Rivue.useKeybind({ Enum.KeyCode.Escape, Enum.KeyCode.ButtonB }, function()
			open.value = false
		end, { enabled = open })
		return { open = open }
	end,
	render = function(ctx)
		return h("Frame", { Visible = ctx.open, Size = UDim2.fromOffset(300, 200) })
	end,
})
```

---

## useLocale()

The player's language as a locale id, such as `"en-us"`. It updates when they change it in the
Roblox menu.

```lua signature
function useLocale(): Ref<string>
```

### Example

```lua
local locale = Rivue.useLocale()
print(locale.value) -- "en-us"
```

---

## useTranslator()

Translates keys from your game's localization table. Text that uses it updates when the
translations load and when the player switches language.

```lua signature
function useTranslator(): (key: string, args: { [string]: any }?) -> string
```

**Returns** a function `t(key, args)`. `args` fill `{name}` placeholders, like
`Translator:FormatByKey`.

> [!NOTE]
> Until the translator loads, and for keys the table doesn't have, `t` returns the key itself. If
> the translator can't load, it warns and keeps returning keys.

### Example

With a `Shop.Buy` entry in the localization table ("Buy for {price}" in English):

```lua
local BuyButton = Rivue.defineComponent({
	name = "BuyButton",
	props = { price = { type = "number", required = true } },
	setup = function()
		return { t = Rivue.useTranslator() }
	end,
	render = function(ctx)
		return h("TextButton", { Text = ctx.t("Shop.Buy", { price = ctx.price }) })
	end,
})
```

### Details

- It calls `LocalizationService:GetTranslatorForPlayerAsync` once, in the background, and again
  when the language changes.

---

## useScroll()

Scroll position and controls for a ScrollingFrame, with a callback for loading more when the player
reaches the end.

```lua signature
function useScroll(frame: Ref<ScrollingFrame?>, options: { onReachEnd: (() -> ())?, threshold: number? }?): {
	position: Ref<Vector2>,
	atEnd: Ref<boolean>,
	scrollTo: (position: Vector2 | number, tweenInfo: TweenInfo?) -> (),
	scrollToEnd: (tweenInfo: TweenInfo?) -> (),
}
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `frame` | `Ref<ScrollingFrame?>` | | usually from [`useTemplateRef()`](component.md#usetemplateref) |
| `options.onReachEnd` | `() -> ()` | | runs when the player reaches the end, then not again until they scroll away and back |
| `options.threshold` | `number` | | how many pixels from the end counts as the end |

**Returns** `position` (the `CanvasPosition`), `atEnd`, `scrollTo(y or Vector2, tweenInfo?)` and
`scrollToEnd(tweenInfo?)`.

> [!NOTE]
> A list shorter than the frame is already at its end, so `onReachEnd` also runs once on mount.
> That fills the first screen.

### Example

```lua
local Feed = Rivue.defineComponent({
	name = "Feed",
	setup = function()
		local posts = Rivue.ref({})
		local frame = Rivue.useTemplateRef("feed")
		local scroll = Rivue.useScroll(frame, {
			threshold = 200,
			onReachEnd = function()
				-- load the next page into posts
			end,
		})
		return {
			posts = posts,
			toTop = function()
				scroll.scrollTo(0, TweenInfo.new(0.3))
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { Size = UDim2.fromOffset(300, 400) }, {
			h("ScrollingFrame", { ref = "feed", Size = UDim2.fromScale(1, 1), AutomaticCanvasSize = Enum.AutomaticSize.Y }),
			h("TextButton", { Text = "Back to top", onClick = ctx.toTop }),
		})
	end,
})
```

### Details

- Horizontal frames (`ScrollingDirection = X`) work too.

---

## useInputType()

What the player is using right now. It changes as soon as they pick up a controller, so you can
swap button prompts.

```lua signature
function useInputType(): Ref<"keyboard" | "gamepad" | "touch">
```

**Returns** a shared ref based on the last input. `"keyboard"` includes the mouse. Treat it as
read-only.

### Example

```lua
local InteractPrompt = Rivue.defineComponent({
	name = "InteractPrompt",
	setup = function()
		return { input = Rivue.useInputType() }
	end,
	render = function(ctx)
		local hint = if ctx.input == "gamepad" then "Press X" elseif ctx.input == "touch" then "Tap" else "Press E"
		return h("TextLabel", { Text = `{hint} to open` })
	end,
})
```

---

## useSafeArea()

How much of each screen edge the Roblox top bar and phone notches cover, in pixels.

```lua signature
function useSafeArea(): Ref<{ top: number, left: number, bottom: number, right: number }>
```

**Returns** a ref from `GuiService:GetGuiInset()`, updated when the viewport changes, such as on
rotation. Treat it as read-only.

### Example

```lua
local TopBar = Rivue.defineComponent({
	name = "TopBar",
	setup = function()
		return { safe = Rivue.useSafeArea() }
	end,
	render = function(ctx)
		return h("Frame", {
			Position = UDim2.fromOffset(ctx.safe.left, ctx.safe.top),
			Size = UDim2.new(1, -ctx.safe.left - ctx.safe.right, 0, 40),
		})
	end,
})
```

---

## useSelection()

Reads and sets which element is selected for gamepad navigation. To select an element when it
appears, the [`vSelect`](directives.md#vselect) directive is shorter.

```lua signature
function useSelection(): (Ref<GuiObject?>, (target: GuiObject?) -> ())
```

**Returns** a ref that follows `GuiService.SelectedObject` (treat it as read-only), and a function
that selects a GuiObject, or clears the selection with `nil`.

### Example

```lua
local MainMenu = Rivue.defineComponent({
	name = "MainMenu",
	setup = function()
		local selected, select = Rivue.useSelection()
		local play = Rivue.useTemplateRef("play")
		Rivue.onMounted(function()
			select(play.value :: GuiObject)
		end)
		return { selected = selected }
	end,
	render = function(ctx)
		return h("Frame", { layout = { gap = 8 } }, {
			h("TextButton", { ref = "play", Name = "Play", Text = "Play" }),
			h("TextButton", { Name = "Settings", Text = "Settings" }),
			h("TextLabel", { Text = if ctx.selected then ctx.selected.Name else "" }),
		})
	end,
})
```

---

## useGamepadFocus()

_client_

Selects a button for gamepad navigation when a menu opens, and gives the selection back when it
closes. Without it, a gamepad player opening a menu has to press the select button before anything
responds.

```lua signature
function useGamepadFocus(target: Ref<GuiObject?>, options: { always: boolean?, restore: boolean? }?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `target` | `Ref<GuiObject?>` | | the button to start on |
| `options.always` | `boolean` | `false` | select it whatever the player is using, not only on a gamepad |
| `options.restore` | `boolean` | `true` | on unmount, give the selection back to what had it before |

### Example

```lua
local PauseMenu = Rivue.defineComponent({
	name = "PauseMenu",
	setup = function()
		local resume = Rivue.useTemplateRef("resume")
		Rivue.useGamepadFocus(resume)
		return {}
	end,
	render = function()
		return h("Frame", { layout = { gap = 8 } }, {
			h("TextButton", { Text = "Resume", ref = "resume" }),
			h("TextButton", { Text = "Settings" }),
		})
	end,
})
```

### Details

- It selects the target once mounted if the player is on a gamepad, and again when they switch to
  one with nothing selected. Something the player already selected stays selected.
- It does nothing on the server.

---

## useTween()

A value that animates toward its target every time the target changes, with the TweenInfo's time
and easing. For smooth health bars, progress bars and counters.

```lua signature
function useTween<T>(source: Ref<T> | () -> T, tweenInfo: TweenInfo): Ref<T>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source` | `Ref<T> \| () -> T` | | the target; a number or anything with `:Lerp()` (UDim2, Color3, Vector2, Vector3, CFrame) |
| `tweenInfo` | `TweenInfo` | | its `Time`, `EasingStyle` and `EasingDirection` are used |

**Returns** a ref with the animated value. It steps each frame only while animating, and stops on
unmount. Bind it with [`bind()`](render-function.md#bind) so only that property updates.

### Example

```lua
local CoinCounter = Rivue.defineComponent({
	name = "CoinCounter",
	props = { coins = { type = "number", required = true } },
	setup = function(props)
		return {
			shown = Rivue.useTween(function()
				return props.coins
			end, TweenInfo.new(0.5, Enum.EasingStyle.Quad)),
		}
	end,
	render = function(ctx)
		return h("TextLabel", { Text = tostring(math.floor(ctx.shown)) })
	end,
})
```

---

## useSpring()

A value that follows its target like a spring, with a natural ease and optional bounce. Unlike a
tween, it keeps its velocity when the target changes mid-motion, so it never jumps.

```lua signature
function useSpring<T>(source: Ref<T> | () -> T, options: { speed: number?, damping: number? }?): Ref<T>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source` | `Ref<T> \| () -> T` | | the target: a number, Vector2, Vector3, UDim, UDim2 or Color3 |
| `options.speed` | `number` | `12` | angular frequency; higher is snappier |
| `options.damping` | `number` | `1` | `1` doesn't overshoot; below 1 bounces |

**Returns** a ref with the animated value.

> [!WARNING]
> Any other type errors. A bouncy Color3 is clamped to 0..1 on the way.

### Example

```lua
local Drawer = Rivue.defineComponent({
	name = "Drawer",
	setup = function()
		local open = Rivue.ref(false)
		return {
			open = open,
			x = Rivue.useSpring(function()
				return if open.value then 0 else -300
			end, { speed = 14, damping = 0.8 }),
			toggle = function()
				open.value = not open.value
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { Position = UDim2.fromOffset(ctx.x, 0), Size = UDim2.new(0, 300, 1, 0) }, {
			h("TextButton", { Text = "≡", Position = UDim2.new(1, 0, 0, 0), onClick = ctx.toggle }),
		})
	end,
})
```

---

## attributeRef()

A ref linked both ways to an Instance attribute. For state the server writes, like
`player:SetAttribute("Coins", 250)`; attributes replicate, so the UI updates.

```lua signature
function attributeRef<T>(instance: Instance, name: string, default: T?, options: { throttle: number? }?): Ref<T?> & { _cleanup: () -> () }
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `instance` | `Instance` | | whose attribute; anything else errors |
| `name` | `string` | | the attribute name; an empty string errors |
| `default` | `T?` | | created with this value if the attribute doesn't exist |
| `options.throttle` | `number?` | | milliseconds between updates, for attributes that change very often |

**Returns** a ref: reading gives the attribute's value, writing sets it. The sync stops with the
component or effect scope, or when you call `ref._cleanup()`.

### Example

```lua
-- server: player:SetAttribute("Coins", 250)
local CoinsLabel = Rivue.defineComponent({
	name = "CoinsLabel",
	setup = function()
		return { coins = Rivue.attributeRef(Players.LocalPlayer, "Coins", 0) }
	end,
	render = function(ctx)
		return h("TextLabel", { Text = `{ctx.coins} coins` })
	end,
})
```

---

## useTag()

Runs code for every Instance with a CollectionService tag, existing and new, and cleans up when the
tag goes. For world UI like nameplates or shop prompts.

```lua signature
function useTag(tag: string, onAdded: (instance: Instance) -> (() -> ())?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `tag` | `string` | | the CollectionService tag |
| `onAdded` | `(instance) -> (() -> ())?` | | runs for each tagged Instance; a function it returns runs when the tag is removed or the Instance streams out |

### Example

```lua
local ShopCounter = Rivue.defineComponent({
	name = "ShopCounter",
	setup = function()
		local shops = Rivue.ref({} :: { Instance })
		Rivue.useTag("Shop", function(shop)
			Rivue.array.push(shops.value, shop)
			return function() -- tag removed, or the shop streamed out
				Rivue.array.removeValue(shops.value, shop)
			end
		end)
		return { shops = shops }
	end,
	render = function(ctx)
		return h("TextLabel", { Text = `{#ctx.shops} shops nearby` })
	end,
})
```

---

## onRenderStepped() / onHeartbeat() / onStepped()

_setup() only_

Runs code every frame while the component is mounted, and disconnects on unmount.

```lua signature
function onRenderStepped(callback: (deltaTime: number) -> ())
function onHeartbeat(callback: (deltaTime: number) -> ())
function onStepped(callback: (time: number, deltaTime: number) -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `(deltaTime) -> ()` | | runs each frame; `onStepped` also gets the time first |

### Example

```lua
local FpsCounter = Rivue.defineComponent({
	name = "FpsCounter",
	setup = function()
		local fps = Rivue.ref(60)
		local frames, elapsed = 0, 0
		Rivue.onRenderStepped(function(dt)
			frames += 1
			elapsed += dt
			if elapsed >= 0.5 then
				fps.value = math.round(frames / elapsed)
				frames, elapsed = 0, 0
			end
		end)
		return { fps = fps }
	end,
	render = function(ctx)
		return h("TextLabel", { Text = `{ctx.fps} FPS` })
	end,
})
```

### Details

- On the client `onRenderStepped` runs before each frame renders; on the server, where that
  doesn't exist, it uses Heartbeat.

---

## useTheme()

Reads the theme an ancestor provided under `"theme"`.

```lua signature
function useTheme<T>(): T?
```

**Returns** the provided theme, or `nil`.

### Example

```lua
type Theme = { accent: Color3 }

local ThemedButton = Rivue.defineComponent({
	name = "ThemedButton",
	setup = function()
		return { theme = Rivue.useTheme() :: Theme? }
	end,
	render = function(ctx)
		return h("TextButton", { BackgroundColor3 = if ctx.theme then ctx.theme.accent else Color3.new(1, 1, 1) })
	end,
})

local App = Rivue.defineComponent({
	name = "App",
	components = { ThemedButton = ThemedButton },
	setup = function()
		Rivue.provide("theme", Rivue.reactive({ accent = Color3.fromRGB(60, 120, 220) }))
		return {}
	end,
	render = function()
		return h("ThemedButton")
	end,
})
```

---

## useStyles()

Builds styles from the current theme, and builds them again when the theme changes. For light and
dark, or team-coloured UI.

```lua signature
function useStyles<Theme, Styles>(factory: (theme: Theme) -> Styles): ComputedRef<Styles>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `factory` | `(theme) -> Styles` | | gets the provided theme, or an empty table when there's none |

**Returns** a computed; with a reactive theme, it updates when the theme changes.

### Example

```lua
local Card = Rivue.defineComponent({
	name = "Card",
	setup = function()
		return {
			styles = Rivue.useStyles(function(theme: any)
				return {
					card = { BackgroundColor3 = theme.surface or Color3.fromRGB(30, 30, 36), cornerRadius = 8 },
				}
			end),
		}
	end,
	render = function(ctx)
		return h("Frame", { style = ctx.styles.card }, ctx.renderSlot("default"))
	end,
})
```

---

[← Scheduler](scheduler.md) · [API reference](../API.md) · [Remote →](remote.md)
