[Docs](../README.md) › [API](../API.md) › **Directives**

# Directives

**Learn it:** [Guide 5: Forms and input](../guide/05-forms-and-input.md)

Reusable behaviour attached to an element. Use a `v` prop with the directive's name in camelCase:
`vFocus = true` applies the `focus` directive, and `vClickOutside = fn` applies `click-outside`.
All examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h
```

- [vShow](#vshow)
- [vFocus](#vfocus)
- [vSelect](#vselect)
- [vClickOutside](#vclickoutside)
- [vDrag](#vdrag)
- [vPreload](#vpreload)
- [vFadeIn](#vfadein)
- [Custom directives](#custom-directives)
- [directives.get()](#directivesget)
- [vModelText()](#vmodeltext)
- [vModelProp()](#vmodelprop)

---

## vShow

Toggles `Visible` based on the value.

- **Expects:** `boolean`

- **Details**

  The element stays mounted and keeps its state. To remove it, use `hIf` instead.

- **Example**

  ```lua
  local open = Rivue.ref(false)

  h("Frame", { vShow = open.value })
  ```

---

## vFocus

Captures focus on a TextBox when the value turns on.

- **Expects:** `boolean`

- **Details**

  It focuses on mount (if truthy), and again whenever the value changes from falsy to truthy.
  Re-renders don't take focus back.

- **Example**

  ```lua
  local searching = Rivue.ref(false)

  h("TextBox", { PlaceholderText = "Search", vFocus = searching.value })
  ```

---

## vSelect

Gives a GuiObject gamepad selection (`GuiService.SelectedObject`) when the value turns on.

- **Expects:** `boolean`

- **Details**

  It selects on mount (if truthy), and whenever the value changes from falsy to truthy. When the
  value turns off or the element is removed, selection is cleared if it's still on this element.
  Re-renders don't take selection back.

- **Example**

  ```lua
  local items = { "Play", "Settings", "Quit" }

  h("Frame", nil, {
  	h("UIListLayout"),
  	Rivue.hFor(items, function(label, index)
  		-- The first button is selected when the menu opens on a controller
  		return h("TextButton", { key = label, Text = label, vSelect = index == 1 })
  	end),
  })
  ```

---

## vClickOutside

Calls a function when the player clicks or taps outside the element.

- **Expects:** `() -> ()`

- **Details**

  Checks mouse clicks and touches against the element's on-screen bounds. Clicking another button
  counts as outside. The latest function is used, so inline closures work.

- **Example**

  ```lua
  local open = Rivue.ref(true)

  h("Frame", {
  	Size = UDim2.fromOffset(200, 150),
  	vShow = open.value,
  	vClickOutside = function()
  		open.value = false
  	end,
  })
  ```

---

## vDrag

Makes a GuiObject draggable with mouse or touch.

- **Expects:** `boolean`

- **Details**

  Dragging updates `Position` directly. Setting the value to `false` stops dragging.

- **Example**

  ```lua
  local locked = Rivue.ref(false)

  h("Frame", { Size = UDim2.fromOffset(200, 120), vDrag = not locked.value })
  ```

---

## vPreload

Preloads assets with `ContentProvider:PreloadAsync()` when the element mounts.

- **Expects:** `number | string | { number | string }`, asset ids without `rbxassetid://`

- **Example**

  ```lua
  h("Frame", { vPreload = { 1234567, 7654321 } }, {
  	h("ImageLabel", { Image = "rbxassetid://1234567" }),
  })
  ```

---

## vFadeIn

Fades an element and all its descendants in from transparent after it mounts.

- **Expects:**

  ```lua
  {
  	duration: number?, -- seconds (default 0.5)
  	delay: number?, -- seconds before starting (default 0)
  	renderWait: number?, -- seconds to wait for the UI to render first (default 0.5)
  	waitForLoad: boolean?, -- wait for game:IsLoaded() first
  }
  ```

- **Details**

  This is a one-time effect on mount. For enter and leave animations that follow state, use
  [`Transition`](builtins.md#transition).

- **Example**

  ```lua
  h("Frame", { vFadeIn = { duration = 0.3, renderWait = 0 } }, {
  	h("TextLabel", { Text = "Welcome" }),
  })
  ```

---

## Custom directives

Register a directive once, then use it as a `v` prop on any element.

- **Type**

  ```lua
  function directives.register(name: string, directive: Directive)

  type Directive = {
  	mounted: ((el: Instance, value: any) -> any)?, -- returns state
  	updated: ((el: Instance, value: any, state: any) -> any)?, -- returning non-nil replaces state
  	unmounted: ((el: Instance, state: any) -> ())?,
  }
  ```

- **Details**

  - **`mounted`** runs once the element and the rest of the tree are parented. Whatever it
    returns is the directive's state, passed to `updated` and `unmounted`.
  - **`updated`** runs when the element re-renders.
  - **`unmounted`** runs when the element is removed.

  The name is kebab-case: `"hover-scale"` is used as `vHoverScale`. The long form
  `__directives = { { name = "hover-scale", value = true } }` also works.
  [`app:directive()`](application.md#appdirective) registers in the same place.

- **Example**

  A tooltip directive:

  ```lua
  Rivue.directives.register("tooltip", {
  	mounted = function(el, text)
  		local state = { text = text }
  		state.conn = (el :: GuiObject).MouseEnter:Connect(function()
  			print("tooltip:", state.text)
  		end)
  		return state
  	end,
  	updated = function(_el, text, state)
  		state.text = text
  		return state
  	end,
  	unmounted = function(_el, state)
  		state.conn:Disconnect()
  	end,
  })

  h("TextButton", { Text = "Buy", vTooltip = "Costs 100 coins" })
  ```

---

## directives.get()

Returns a registered directive by name.

- **Type**

  ```lua
  function directives.get(name: string): Directive?
  ```

- **Example**

  ```lua
  if not Rivue.directives.get("tooltip") then
  	warn("tooltip directive isn't registered")
  end
  ```

---

## vModelText()

Returns props that bind a TextBox's `Text` to a ref, optionally debounced.

- **Type**

  ```lua
  function vModelText(ref: Ref<string>, options: { debounce: number? }?): {
  	Text: string,
  	onTextChanged: (text: string) -> (),
  }
  ```

- **Details**

  For a plain binding, the [`model`](render-function.md#element-props) prop is shorter. Use this
  when you want writes to the ref debounced (milliseconds).

- **Example**

  ```lua
  local query = Rivue.ref("")

  h("TextBox", Rivue.mergeProps(Rivue.vModelText(query, { debounce = 300 }), {
  	PlaceholderText = "Search",
  }))
  ```

---

## vModelProp()

Returns props that bind any property to a ref: the property's value plus a change handler that
writes the ref.

- **Type**

  ```lua
  function vModelProp<T>(ref: Ref<T>, propName: string, eventName: string?): Props
  ```

- **Details**

  `eventName` defaults to `"on" .. propName`. For a property that isn't an event, that connects
  the property's changed signal, which passes the new value.

- **Example**

  ```lua
  local position = Rivue.ref(UDim2.fromScale(0.5, 0.5))

  -- position follows the Frame while vDrag moves it
  h("Frame", Rivue.mergeProps(Rivue.vModelProp(position, "Position"), {
  	Size = UDim2.fromOffset(100, 100),
  	vDrag = true,
  }))
  ```

---

[← Built-in Components](builtins.md) · [API reference](../API.md) · [Application →](application.md)
