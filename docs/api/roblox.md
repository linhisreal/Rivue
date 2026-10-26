[Docs](../README.md) › [API](../API.md) › **Roblox Composables**

# Roblox Composables

**Learn it:** [Guide 6: Styling and layout](../guide/06-styling-and-layout.md) · [Guide 7: Effects and animation](../guide/07-effects-and-animation.md)

Composables for engine state: devices, input, attributes, tags, frames and animation. Call them in
`setup()` (or inside an `effectScope`) so they clean up automatically. All examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h
local Players = game:GetService("Players")
```

- [useViewportSize()](#useviewportsize)
- [useDevice()](#usedevice)
- [useKeybind()](#usekeybind)
- [useLocale()](#uselocale)
- [useTranslator()](#usetranslator)
- [useScroll()](#usescroll)
- [useInputType()](#useinputtype)
- [useSafeArea()](#usesafearea)
- [useSelection()](#useselection)
- [useTween()](#usetween)
- [useSpring()](#usespring)
- [attributeRef()](#attributeref)
- [useTag()](#usetag)
- [onRenderStepped() / onHeartbeat() / onStepped()](#onrenderstepped--onheartbeat--onstepped)
- [useTheme()](#usetheme)
- [useStyles()](#usestyles)

---

## useDevice()

The kind of device the game is running on: `"phone"`, `"tablet"`, `"desktop"` or `"console"`.
Style classes use it for their device variants, and you can read it to change layout.

- **Example**

  Show a bottom bar on phones and a side bar everywhere else:

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

- **Details**

  - `"console"` when `GuiService:IsTenFootInterface()` is true.
  - On touch screens without a keyboard: `"phone"` when the screen's short side is under 500
    pixels, otherwise `"tablet"`. Using the short side keeps a phone held sideways a phone.
  - Everything else is `"desktop"`.

  The ref is shared and updates when the screen size changes. It's never stopped, so it's safe to
  read in render.

- **Type**

  ```lua
  function useDevice(): Ref<"phone" | "tablet" | "desktop" | "console">
  ```

---

## useViewportSize()

The screen size in pixels, kept up to date as the window resizes or the phone rotates. Use it to
switch layouts on small screens.

- **Example**

  A sidebar that becomes a bottom sheet on narrow screens:

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

- **Details**

  The value comes from `workspace.CurrentCamera.ViewportSize`, and follows the camera if it's
  replaced. One connection is shared by every caller for the whole session. Treat the ref as
  read only.

- **Type**

  ```lua
  function useViewportSize(): Ref<Vector2>
  ```

---

## useKeybind()

Runs a function when a key or gamepad button is pressed, while the component is mounted. Unbinds
by itself on unmount.

- **Example**

  Close a menu with Escape or the gamepad's B button, but only while it's open:

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

- **Details**

  Uses `ContextActionService`, so a binding takes the key away from the game while active (the
  character doesn't also act on it). Pass `passThrough = true` to let it through. `enabled` can be
  a ref, a getter or a boolean. `priority` defaults to `Enum.ContextActionPriority.High`.

- **Type**

  ```lua
  function useKeybind(
  	keys: Enum.KeyCode | Enum.UserInputType | { Enum.KeyCode | Enum.UserInputType },
  	callback: (input: InputObject) -> (),
  	options: { enabled: MaybeRefOrGetter<boolean>?, priority: number?, passThrough: boolean? }?
  )
  ```

---

## useLocale()

The player's language as a locale id, such as `"en-us"`. Updates when they change it in the
Roblox menu.

- **Example**

  ```lua
  local locale = Rivue.useLocale()
  print(locale.value) -- "en-us"
  ```

- **Type**

  ```lua
  function useLocale(): Ref<string>
  ```

---

## useTranslator()

Translates keys from your game's localization table. Text that uses it updates when the
translations load and when the player switches language.

- **Example**

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

- **Details**

  Calls `LocalizationService:GetTranslatorForPlayerAsync` once, in the background, and again when
  the language changes. Until it's loaded, and for keys the table doesn't have, `t` returns the key
  itself. Arguments fill `{name}` placeholders, like `Translator:FormatByKey`.

- **Type**

  ```lua
  function useTranslator(): (key: string, args: { [string]: any }?) -> string
  ```

---

## useScroll()

Scroll position and controls for a ScrollingFrame, with a callback for loading more when the
player reaches the end.

- **Example**

  A feed that loads the next page near the bottom, with a "Back to top" button:

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

- **Details**

  - `position` is a ref of `CanvasPosition`. `atEnd` is true within `threshold` pixels of the end.
  - `onReachEnd` runs when the player reaches the end, then not again until they scroll away and
    come back. A list shorter than the frame is already at its end, so it also runs once on
    mount, which fills the first screen.
  - `scrollTo` takes a Y position or a Vector2, and an optional TweenInfo to animate.
    `scrollToEnd` goes to the bottom.
  - Works with horizontal frames (`ScrollingDirection = X`) too.

- **Type**

  ```lua
  function useScroll(frame: Ref<ScrollingFrame?>, options: { onReachEnd: (() -> ())?, threshold: number? }?): {
  	position: Ref<Vector2>,
  	atEnd: Ref<boolean>,
  	scrollTo: (position: Vector2 | number, tweenInfo: TweenInfo?) -> (),
  	scrollToEnd: (tweenInfo: TweenInfo?) -> (),
  }
  ```

---

## useInputType()

What the player is using right now: `"keyboard"` (with mouse), `"gamepad"` or `"touch"`. It changes
as soon as they pick up a controller, so you can swap button prompts.

- **Example**

  Show the right button prompt for the player's device:

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

- **Details**

  It's based on the last input, so it switches as soon as the player picks up a controller or
  touches the screen. One connection is shared for the session. Treat the ref as read only.

- **Type**

  ```lua
  function useInputType(): Ref<"keyboard" | "gamepad" | "touch">
  ```

---

## useSafeArea()

How much of the screen edge is covered by the top bar and phone notches, in pixels, so you can keep
buttons out of the way.

- **Example**

  Keep a top bar clear of the Roblox top bar and phone notches:

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

- **Details**

  The values come from `GuiService:GetGuiInset()` and update when the viewport changes, such as
  on rotation. Treat the ref as read only.

- **Type**

  ```lua
  function useSafeArea(): Ref<{ top: number, left: number, bottom: number, right: number }>
  ```

---

## useSelection()

Reads and sets which element is selected for gamepad navigation.

- **Example**

  Start controller players on the Play button, and show what's selected:

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

- **Details**

  The ref follows `GuiService.SelectedObject` and should be treated as read only. The second
  return value selects a GuiObject, or clears the selection when given `nil`. To select an
  element when it appears, the [`vSelect`](directives.md#vselect) directive is simpler.

- **Type**

  ```lua
  function useSelection(): (Ref<GuiObject?>, (target: GuiObject?) -> ())
  ```

---

## useTween()

A value that animates toward its target, with the TweenInfo's time and easing, every time the
target changes. Bind it to a prop for smooth health bars, progress bars and counters.

- **Example**

  A coin counter that counts up instead of jumping:

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

- **Details**

  This works with numbers and anything with `:Lerp()`: UDim2, Color3, Vector2, Vector3, CFrame.
  It uses `tweenInfo.Time`, `EasingStyle` and `EasingDirection`. Bind the returned ref to a prop.
  It steps on RenderStepped only while animating, and stops when the component unmounts.

- **Type**

  ```lua
  function useTween<T>(source: Ref<T> | () -> T, tweenInfo: TweenInfo): Ref<T>
  ```

---

## useSpring()

A value that follows its target like a spring, with a natural ease and optional bounce. It keeps
moving smoothly even if the target changes mid-animation.

- **Example**

  A side drawer that springs open and closed:

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

- **Details**

  Supports numbers, Vector2 and Vector3. Unlike a tween, a spring keeps its velocity when the
  target changes mid-motion, so it never jumps.

- **Type**

  ```lua
  function useSpring<T>(source: Ref<T> | () -> T, options: {
  	speed: number?, -- angular frequency, higher is snappier (default 12)
  	damping: number?, -- 1 = no overshoot, below 1 bounces (default 1)
  }?): Ref<T>
  ```

---

## attributeRef()

A ref linked to an Instance attribute, both ways. Perfect for state the server writes, like
`player:SetAttribute("Health", 80)`, which the UI then shows.

- **Example**

  Show coins the server keeps on the player as an attribute:

  ```lua
  -- Server: player:SetAttribute("Coins", 250)
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

- **Details**

  Reading the ref gives the attribute's value, and writing it sets the attribute. If the
  attribute doesn't exist, it's created with `default`. The sync stops with the component or
  effect scope, or when you call `ref._cleanup()`.

  This is the simplest way to show state the server writes. Attributes replicate, so the server
  calls `player:SetAttribute("Coins", 10)` and the UI updates.

- **Type**

  ```lua
  function attributeRef<T>(
  	instance: Instance,
  	name: string,
  	default: T?,
  	options: { throttle: number? }? -- ms, for attributes that change very often
  ): Ref<T?> & { _cleanup: () -> () }
  ```

---

## useTag()

Runs your code for every Instance with a CollectionService tag, existing ones and new ones, and
cleans up when the tag goes away. Great for world UI like nameplates or shop prompts.

- **Example**

  Count the shops tagged "Shop" in the world, as they stream in and out:

  ```lua
  local ShopCounter = Rivue.defineComponent({
  	name = "ShopCounter",
  	setup = function()
  		local shops = Rivue.ref({} :: { Instance })
  		Rivue.useTag("Shop", function(shop)
  			Rivue.array.push(shops.value, shop)
  			return function() -- runs when the tag is removed, or the shop streams out
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

- **Details**

  If `onAdded` returns a function, it runs when the tag is removed from that Instance. Everything
  is cleaned up with the component or effect scope.

- **Type**

  ```lua
  function useTag(tag: string, onAdded: (instance: Instance) -> (() -> ())?)
  ```

---

## onRenderStepped() / onHeartbeat() / onStepped()

Runs your code every frame for as long as the component is mounted, and disconnects by itself.
On the server, where RenderStepped doesn't exist, `onRenderStepped` uses Heartbeat.

- **Example**

  An FPS counter, updated twice a second:

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

- **Details**

  Call them in `setup()`. The connection is closed when the component unmounts.

- **Type**

  ```lua
  function onRenderStepped(callback: (deltaTime: number) -> ())
  function onHeartbeat(callback: (deltaTime: number) -> ())
  function onStepped(callback: (time: number, deltaTime: number) -> ())
  ```

---

## useTheme()

Reads the theme an ancestor provided under `"theme"`.

- **Example**

  A button that takes its colour from the app's theme:

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

- **Type**

  ```lua
  function useTheme<T>(): T?
  ```

---

## useStyles()

Builds styles from the current theme, and rebuilds them when the theme changes. Use it for
light/dark or team-coloured UI.

- **Example**

  A card whose colours follow a light/dark theme:

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

- **Details**

  The factory gets the provided theme, or an empty table if there's none. If the theme is
  reactive, the styles update when it changes.

- **Type**

  ```lua
  function useStyles<Theme, Styles>(factory: (theme: Theme) -> Styles): ComputedRef<Styles>
  ```

---

[← Scheduler](scheduler.md) · [API reference](../API.md) · [Remote →](remote.md)
