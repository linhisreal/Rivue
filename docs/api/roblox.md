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

## useViewportSize()

Returns the screen size in pixels, following resizes and rotation.

- **Type**

  ```lua
  function useViewportSize(): Ref<Vector2>
  ```

- **Details**

  The value comes from `workspace.CurrentCamera.ViewportSize`, and follows the camera if it's
  replaced. One connection is shared by every caller for the whole session. Treat the ref as
  read only.

- **Example**

  ```lua
  local Sidebar = Rivue.defineComponent(function()
  	local viewport = Rivue.useViewportSize()
  	return function()
  		local narrow = viewport.value.X < 700
  		return h("Frame", {
  			Size = if narrow then UDim2.fromScale(1, 0.3) else UDim2.new(0, 280, 1, 0),
  		})
  	end
  end, { name = "Sidebar" })
  ```

---

## useInputType()

Returns what the player is using right now: `"keyboard"` (keyboard and mouse), `"gamepad"` or
`"touch"`.

- **Type**

  ```lua
  function useInputType(): Ref<"keyboard" | "gamepad" | "touch">
  ```

- **Details**

  It's based on the last input, so it switches as soon as the player picks up a controller or
  touches the screen. One connection is shared for the session. Treat the ref as read only.

- **Example**

  ```lua
  local Prompt = Rivue.defineComponent(function()
  	local input = Rivue.useInputType()
  	return function()
  		local hint = if input.value == "gamepad" then "Press X" elseif input.value == "touch" then "Tap" else "Press E"
  		return h("TextLabel", { Text = hint })
  	end
  end, { name = "Prompt" })
  ```

---

## useSafeArea()

Returns the insets, in pixels, taken by the top bar and device cutouts.

- **Type**

  ```lua
  function useSafeArea(): Ref<{ top: number, left: number, bottom: number, right: number }>
  ```

- **Details**

  The values come from `GuiService:GetGuiInset()` and update when the viewport changes, such as
  on rotation. Treat the ref as read only.

- **Example**

  ```lua
  local TopBar = Rivue.defineComponent(function()
  	local safeArea = Rivue.useSafeArea()
  	return function()
  		return h("Frame", {
  			Position = UDim2.fromOffset(safeArea.value.left, safeArea.value.top),
  			Size = UDim2.new(1, -safeArea.value.left - safeArea.value.right, 0, 40),
  		})
  	end
  end, { name = "TopBar" })
  ```

---

## useSelection()

Reads and sets gamepad selection.

- **Type**

  ```lua
  function useSelection(): (Ref<GuiObject?>, (target: GuiObject?) -> ())
  ```

- **Details**

  The ref follows `GuiService.SelectedObject` and should be treated as read only. The second
  return value selects a GuiObject, or clears the selection when given `nil`. To select an
  element when it appears, the [`vSelect`](directives.md#vselect) directive is simpler.

- **Example**

  ```lua
  local Menu = Rivue.defineComponent(function()
  	local selected, select = Rivue.useSelection()
  	local play = Rivue.useTemplateRef("play")

  	Rivue.onMounted(function()
  		select(play.value :: GuiObject)
  	end)

  	return function()
  		return h("Frame", nil, {
  			h("UIListLayout"),
  			h("TextButton", { ref = "play", Text = "Play" }),
  			h("TextLabel", { Text = if selected.value then selected.value.Name else "nothing selected" }),
  		})
  	end
  end, { name = "Menu" })
  ```

---

## useTween()

Returns a ref that tweens toward its source every time the source changes.

- **Type**

  ```lua
  function useTween<T>(source: Ref<T> | () -> T, tweenInfo: TweenInfo): Ref<T>
  ```

- **Details**

  This works with numbers and anything with `:Lerp()`: UDim2, Color3, Vector2, Vector3, CFrame.
  It uses `tweenInfo.Time`, `EasingStyle` and `EasingDirection`. Bind the returned ref to a prop.
  It steps on RenderStepped only while animating, and stops when the component unmounts.

- **Example**

  ```lua
  local CoinCounter = Rivue.defineComponent(function()
  	local coins = Rivue.ref(0)
  	local shown = Rivue.useTween(coins, TweenInfo.new(0.5, Enum.EasingStyle.Quad))

  	return function()
  		return h("TextButton", {
  			Text = tostring(math.floor(shown.value)),
  			onClick = function()
  				coins.value += 100 -- the label counts up
  			end,
  		})
  	end
  end, { name = "CoinCounter" })
  ```

---

## useSpring()

Returns a ref that moves toward its source like a spring.

- **Type**

  ```lua
  function useSpring<T>(source: Ref<T> | () -> T, options: {
  	speed: number?, -- angular frequency, higher is snappier (default 12)
  	damping: number?, -- 1 = no overshoot, below 1 bounces (default 1)
  }?): Ref<T>
  ```

- **Details**

  Supports numbers, Vector2 and Vector3. Unlike a tween, a spring keeps its velocity when the
  target changes mid-motion, so it never jumps.

- **Example**

  ```lua
  local Drawer = Rivue.defineComponent(function()
  	local open = Rivue.ref(false)
  	local x = Rivue.useSpring(function()
  		return if open.value then 0 else -300
  	end, { speed = 14, damping = 0.8 })

  	return function()
  		return h("Frame", { Position = UDim2.fromOffset(x.value, 0), Size = UDim2.new(0, 300, 1, 0) }, {
  			h("TextButton", {
  				Text = "Toggle",
  				Position = UDim2.new(1, 0, 0, 0),
  				onClick = function()
  					open.value = not open.value
  				end,
  			}),
  		})
  	end
  end, { name = "Drawer" })
  ```

---

## attributeRef()

Returns a ref synced both ways with an Instance attribute.

- **Type**

  ```lua
  function attributeRef<T>(
  	instance: Instance,
  	name: string,
  	default: T?,
  	options: { throttle: number? }? -- ms, for attributes that change very often
  ): Ref<T?> & { _cleanup: () -> () }
  ```

- **Details**

  Reading the ref gives the attribute's value, and writing it sets the attribute. If the
  attribute doesn't exist, it's created with `default`. The sync stops with the component or
  effect scope, or when you call `ref._cleanup()`.

  This is the simplest way to show state the server writes. Attributes replicate, so the server
  calls `player:SetAttribute("Coins", 10)` and the UI updates.

- **Example**

  ```lua
  local Coins = Rivue.defineComponent(function()
  	local coins = Rivue.attributeRef(Players.LocalPlayer, "Coins", 0)
  	return function()
  		return h("TextLabel", { Text = `{coins.value} coins` })
  	end
  end, { name = "Coins" })
  ```

---

## useTag()

Runs a callback for every Instance with a CollectionService tag, now and as they're added.

- **Type**

  ```lua
  function useTag(tag: string, onAdded: (instance: Instance) -> (() -> ())?)
  ```

- **Details**

  If `onAdded` returns a function, it runs when the tag is removed from that Instance. Everything
  is cleaned up with the component or effect scope.

- **Example**

  ```lua
  local ShopMarkers = Rivue.defineComponent(function()
  	local shops = Rivue.ref({} :: { Instance })

  	Rivue.useTag("Shop", function(shop)
  		local list = table.clone(Rivue.toRaw(shops.value))
  		table.insert(list, shop)
  		shops.value = list
  		return function()
  			local remaining = table.clone(Rivue.toRaw(shops.value))
  			local index = table.find(remaining, shop)
  			if index then
  				table.remove(remaining, index)
  			end
  			shops.value = remaining
  		end
  	end)

  	return function()
  		return h("TextLabel", { Text = `{#shops.value} shops nearby` })
  	end
  end, { name = "ShopMarkers" })
  ```

---

## onRenderStepped() / onHeartbeat() / onStepped()

Connect to a RunService signal for the component's lifetime.

- **Type**

  ```lua
  function onRenderStepped(callback: (deltaTime: number) -> ())
  function onHeartbeat(callback: (deltaTime: number) -> ())
  function onStepped(callback: (time: number, deltaTime: number) -> ())
  ```

- **Details**

  Call them in `setup()`. The connection is closed when the component unmounts.

- **Example**

  ```lua
  local Fps = Rivue.defineComponent(function()
  	local fps = Rivue.ref(60)
  	Rivue.onRenderStepped(function(dt)
  		fps.value = math.floor(1 / dt)
  	end)
  	return function()
  		return h("TextLabel", { Text = `{fps.value} FPS` })
  	end
  end, { name = "Fps" })
  ```

---

## useTheme()

Returns the value provided under the `"theme"` key by the nearest ancestor.

- **Type**

  ```lua
  function useTheme<T>(): T?
  ```

- **Example**

  ```lua
  type Theme = { accent: Color3 }

  local Button = Rivue.defineComponent(function()
  	local theme = Rivue.useTheme() :: Theme?
  	return function()
  		return h("TextButton", { BackgroundColor3 = if theme then theme.accent else Color3.new(1, 1, 1) })
  	end
  end, { name = "Button" })

  local App = Rivue.defineComponent(function()
  	Rivue.provide("theme", Rivue.reactive({ accent = Color3.fromRGB(60, 120, 220) }))
  	return function()
  		return h(Button)
  	end
  end, { name = "App" })
  ```

---

## useStyles()

Builds a table of styles from the theme as a computed ref.

- **Type**

  ```lua
  function useStyles<Theme, Styles>(factory: (theme: Theme) -> Styles): ComputedRef<Styles>
  ```

- **Details**

  The factory gets the provided theme, or an empty table if there's none. If the theme is
  reactive, the styles update when it changes.

- **Example**

  ```lua
  local Card = Rivue.defineComponent(function()
  	local styles = Rivue.useStyles(function(theme: any)
  		return {
  			card = { BackgroundColor3 = theme.surface or Color3.new(0, 0, 0), cornerRadius = 8 },
  		}
  	end)
  	return function()
  		return h("Frame", { style = styles.value.card })
  	end
  end, { name = "Card" })
  ```

---

[← Scheduler](scheduler.md) · [API reference](../API.md) · [Remote →](remote.md)
