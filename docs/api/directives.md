[Docs](../README.md) › [API](../API.md) › **Directives**

# Directives

**Learn it:** [Guide 5: Forms and input](../guide/05-forms-and-input.md)

Reusable behaviour attached to an element. Turn one on with a `v` prop named after the directive in
camelCase: `vFocus = true` applies the `focus` directive, and `vClickOutside = fn` applies
`click-outside`. Examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
local h = Rivue.h
```

---

## vShow

Shows or hides an element by setting `Visible`, without destroying it. Cheaper than removing and
creating again something you toggle often.

```lua signature
vShow: boolean
```

### Example

```lua
local open = Rivue.ref(false)

h("Frame", { vShow = open.value })
```

### Details

- The element stays mounted and keeps its state. To remove it, use [`hIf()`](render-function.md#hif).

---

## vFocus

Focuses a TextBox when the value turns on, like a search box that's ready to type in when a menu
opens.

```lua signature
vFocus: boolean
```

> [!NOTE]
> It only works on a TextBox. On anything else it does nothing.

### Example

```lua
local searching = Rivue.ref(false)

h("TextBox", { PlaceholderText = "Search", vFocus = searching.value })
```

### Details

- Focuses on mount if the value is on, and again each time it goes from off to on. Re-renders
  don't take focus back.

---

## vSelect

Selects an element for gamepad navigation when the value turns on, so controller players start in
the right place.

```lua signature
vSelect: boolean
```

### Example

```lua
local items = { "Play", "Settings", "Quit" }

h("Frame", nil, {
	h("UIListLayout"),
	Rivue.hFor(items, function(label, index)
		-- the first button is selected when the menu opens on a controller
		return h("TextButton", { key = label, Text = label, vSelect = index == 1 })
	end),
})
```

### Details

- Selects on mount if the value is on, and each time it goes from off to on.
- When the value turns off or the element is removed, the selection is cleared if it's still on
  this element.
- For a whole menu that opens and closes, [`useGamepadFocus()`](roblox.md#usegamepadfocus) also
  gives the selection back.

---

## vClickOutside

Calls a function when the player clicks or taps anywhere outside the element. The usual way to close
dropdowns, popups and context menus.

```lua signature
vClickOutside: () -> ()
```

> [!NOTE]
> An error in the function is caught and warned, so it doesn't break input handling.

### Example

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

### Details

- Mouse clicks and touches are checked against the element's on-screen bounds; clicking another
  button counts as outside.
- The latest function is used, so inline closures work.

---

## vDrag

Lets the player drag an element with the mouse or a finger.

```lua signature
vDrag: boolean
```

### Example

```lua
local locked = Rivue.ref(false)

h("Frame", { Size = UDim2.fromOffset(200, 120), vDrag = not locked.value })
```

### Details

- Dragging writes `Position` directly. Turning the value off stops dragging.
- To keep the position in state, combine it with [`vModelProp()`](#vmodelprop).

---

## vPreload

Starts loading images and sounds as soon as the element appears, so they're ready when shown.

```lua signature
vPreload: number | string | { number | string }
```

The value is one asset id or a list of them, without `rbxassetid://`.

### Example

```lua
h("Frame", { vPreload = { 1234567, 7654321 } }, {
	h("ImageLabel", { Image = "rbxassetid://1234567" }),
})
```

---

## vFadeIn

Fades an element and everything inside it in from fully transparent, once it's on screen.

```lua signature
vFadeIn: { duration: number?, delay: number?, renderWait: number?, waitForLoad: boolean? }
```

| Field | Type | Default | Description |
|---|---|---|---|
| `duration` | `number` | `0.5` | seconds the fade takes |
| `delay` | `number` | `0` | seconds before it starts |
| `renderWait` | `number` | `0.5` | seconds to wait for the UI to render first |
| `waitForLoad` | `boolean` | `false` | wait for `game:IsLoaded()` first |

### Example

```lua
h("Frame", { vFadeIn = { duration = 0.3, renderWait = 0 } }, {
	h("TextLabel", { Text = "Welcome" }),
})
```

### Details

- It runs once, on mount. For enter and leave animations that follow state, use
  [`Transition`](builtins.md#transition).

---

## directives.register()

Registers your own directive, which any element can then turn on with a `v` prop, like
`vTooltip = "Buy"`.

```lua signature
function directives.register(name: string, directive: Directive)

type Directive = {
	mounted: ((el: Instance, value: any) -> any)?,
	updated: ((el: Instance, value: any, state: any) -> any)?,
	unmounted: ((el: Instance, state: any) -> ())?,
}
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | kebab-case: `"hover-scale"` is used as `vHoverScale` |
| `directive.mounted` | `(el, value) -> any` | | runs once the element and the rest of the tree are parented; what it returns is the directive's state |
| `directive.updated` | `(el, value, state) -> any` | | runs when the element re-renders; returning something other than `nil` replaces the state |
| `directive.unmounted` | `(el, state) -> ()` | | runs when the element is removed |

### Example

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

### Details

- [`app:directive()`](application.md#appdirective) registers in the same place.
- The long form `__directives = { { name = "hover-scale", value = true } }` also works.

---

## directives.get()

Looks up a registered directive by name.

```lua signature
function directives.get(name: string): Directive?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | the kebab-case name |

### Example

```lua
if not Rivue.directives.get("tooltip") then
	warn("tooltip directive isn't registered")
end
```

---

## vModelText()

The props that bind a TextBox's `Text` to a ref, with optional debouncing. For a plain binding, the
[`model`](render-function.md#element-props) prop is shorter.

```lua signature
function vModelText(ref: Ref<string>, options: { debounce: number? }?): { Text: string, onTextChanged: (text: string) -> () }
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `ref` | `Ref<string>` | | the ref to bind |
| `options.debounce` | `number?` | none | milliseconds to wait after the last keystroke before writing the ref |

**Returns** props to merge into the TextBox's props.

### Example

```lua
local query = Rivue.ref("")

h("TextBox", Rivue.mergeProps(Rivue.vModelText(query, { debounce = 300 }), {
	PlaceholderText = "Search",
}))
```

---

## vModelProp()

The props that bind any property to a ref: the value, plus a handler that writes the ref when the
property changes.

```lua signature
function vModelProp<T>(ref: Ref<T>, propName: string, eventName: string?): Props
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `ref` | `Ref<T>` | | the ref to bind |
| `propName` | `string` | | the property, such as `"Position"` |
| `eventName` | `string?` | `"on" .. propName` | the event prop to listen on; for a property, that's its changed signal |

**Returns** props to merge into the element's props.

### Example

```lua
local position = Rivue.ref(UDim2.fromScale(0.5, 0.5))

-- position follows the Frame while vDrag moves it
h("Frame", Rivue.mergeProps(Rivue.vModelProp(position, "Position"), {
	Size = UDim2.fromOffset(100, 100),
	vDrag = true,
}))
```

---

[← Built-in components](builtins.md) · [API reference](../API.md) · [Application →](application.md)
