[Docs](../README.md) › [API](../API.md) › **Lifecycle hooks**

# Lifecycle hooks

**Learn it:** [Guide 4: Components](../guide/04-components.md) · [Guide 7: Effects and animation](../guide/07-effects-and-animation.md)

Functions that run your code at points in a component's life. Examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
local h = Rivue.h
```

> [!WARNING]
> Register hooks in a component's `setup()`. Calling one anywhere else errors.

---

## onMounted()

_setup() only_

Runs once the component's Instances and all its descendants are created and parented. The place for
anything that needs real Instances: reading `AbsoluteSize`, focusing, starting a tween.

```lua signature
function onMounted(callback: () -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `() -> ()` | | runs once, after the whole tree being mounted is attached |

### Example

```lua
local SearchBar = Rivue.defineComponent({
	name = "SearchBar",
	setup = function()
		local box = Rivue.useTemplateRef("box")
		Rivue.onMounted(function()
			-- the TextBox exists and is parented now, so focusing works
			(box.value :: TextBox):CaptureFocus()
		end)
		return {}
	end,
	render = function()
		return h("TextBox", { ref = "box", PlaceholderText = "Search items" })
	end,
})
```

### Details

- Children's `onMounted` run before their parents'.

---

## onUpdated()

_setup() only_

Runs after the component re-rendered because its state changed. Use it to act on the updated
Instances.

```lua signature
function onUpdated(callback: () -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `() -> ()` | | runs after each re-render |

> [!WARNING]
> Changing the component's state here can loop. To react to one value, use
> [`watch()`](reactivity-core.md#watch) with `flush = "post"`.

### Example

```lua
local Chat = Rivue.defineComponent({
	name = "Chat",
	props = { messages = { type = "table", required = true } },
	setup = function()
		local list = Rivue.useTemplateRef("list")
		Rivue.onUpdated(function()
			local frame = list.value :: ScrollingFrame
			frame.CanvasPosition = Vector2.new(0, frame.AbsoluteCanvasSize.Y)
		end)
		return {}
	end,
	render = function(ctx)
		return h("ScrollingFrame", { ref = "list", layout = "vertical", AutomaticCanvasSize = Enum.AutomaticSize.Y }, {
			Rivue.hFor(ctx.messages, function(message)
				return h("TextLabel", { key = message.id, Text = message.text })
			end),
		})
	end,
})
```

### Details

- Children's `onUpdated` run before their parents', so a parent sees its children's updated
  Instances.

---

## onUnmounted()

_setup() only_

Runs after the component is removed. The place to disconnect connections and stop anything you
started yourself.

```lua signature
function onUnmounted(callback: () -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `() -> ()` | | runs once, after removal |

> [!NOTE]
> Watchers, computeds, `onHeartbeat` connections and jobs from `setup()` stop on their own.
> Connections, threads and tags you made yourself don't.

### Example

```lua
local DamageFlash = Rivue.defineComponent({
	name = "DamageFlash",
	setup = function()
		local flashing = Rivue.ref(false)
		local humanoid = game.Players.LocalPlayer.Character:WaitForChild("Humanoid") :: Humanoid

		local conn = humanoid.HealthChanged:Connect(function()
			flashing.value = true
			task.delay(0.15, function()
				flashing.value = false
			end)
		end)
		Rivue.onUnmounted(function()
			conn:Disconnect() -- Rivue only cleans up what it created
		end)

		return { flashing = flashing }
	end,
	render = function(ctx)
		return h("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(200, 0, 0),
			BackgroundTransparency = if ctx.flashing then 0.6 else 1,
		})
	end,
})
```

### Details

- Children run `onUnmounted` first, then the parent, as in Vue, so a parent can tear down
  something its children still clean up into. `onBeforeUnmount` goes the other way.
- In stores and composables that may run outside a component,
  [`onScopeDispose()`](reactivity-advanced.md#onscopedispose) works in both places.

---

## onBeforeMount()

_setup() only_

Runs right before the first render. The component has its state but no Instances yet.

```lua signature
function onBeforeMount(callback: () -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `() -> ()` | | runs once, before the first render |

### Example

```lua
local VolumeSlider = Rivue.defineComponent({
	name = "VolumeSlider",
	setup = function()
		local volume = Rivue.ref(0.5)
		Rivue.onBeforeMount(function()
			volume.value = game.Players.LocalPlayer:GetAttribute("Volume") or 0.5
		end)
		return { volume = volume }
	end,
	render = function(ctx)
		return h("TextLabel", { Text = `Volume: {math.round(ctx.volume * 100)}%` })
	end,
})
```

---

## onBeforeUpdate()

_setup() only_

Runs right before a re-render, while the Instances still show the old state. State changed here
shows up in that same render, as in Vue.

```lua signature
function onBeforeUpdate(callback: () -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `() -> ()` | | runs before each re-render |

### Example

Remembering whether the player had scrolled up, before new messages arrive:

```lua
local ChatLog = Rivue.defineComponent({
	name = "ChatLog",
	props = { messages = { type = "table", required = true } },
	setup = function()
		local list = Rivue.useTemplateRef("list")
		local wasAtBottom = true

		Rivue.onBeforeUpdate(function()
			local frame = list.value :: ScrollingFrame
			wasAtBottom = frame.CanvasPosition.Y + frame.AbsoluteSize.Y >= frame.AbsoluteCanvasSize.Y - 4
		end)
		Rivue.onUpdated(function()
			if wasAtBottom then -- don't jump if they were reading older messages
				local frame = list.value :: ScrollingFrame
				frame.CanvasPosition = Vector2.new(0, frame.AbsoluteCanvasSize.Y)
			end
		end)
		return {}
	end,
	render = function(ctx)
		return h("ScrollingFrame", { ref = "list", layout = "vertical", AutomaticCanvasSize = Enum.AutomaticSize.Y }, {
			Rivue.hFor(ctx.messages, function(message)
				return h("TextLabel", { key = message.id, Text = message.text })
			end),
		})
	end,
})
```

---

## onBeforeUnmount()

_setup() only_

Runs right before the component is removed, while its Instances still exist and parents before
children. Use it to save state or start an exit animation.

```lua signature
function onBeforeUnmount(callback: () -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `() -> ()` | | runs once, before removal |

### Example

```lua
local NoteEditor = Rivue.defineComponent({
	name = "NoteEditor",
	setup = function()
		local note = Rivue.ref("")
		Rivue.onBeforeUnmount(function()
			Remote.fire("notes:save", { text = note.value })
		end)
		return { note = note }
	end,
	render = function()
		return h("TextBox", { model = "note", MultiLine = true, PlaceholderText = "Notes" })
	end,
})
```

---

## onErrorCaptured()

_setup() only_

Catches errors from components below this one, so one broken widget can show a fallback instead of
breaking the whole screen. [`ErrorBoundary`](builtins.md#errorboundary) is built on it.

```lua signature
function onErrorCaptured(callback: (err: string, instance: ComponentInstance, info: string) -> boolean?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `(err, instance, info) -> boolean?` | | gets the error, the component it came from, and where it happened |

**Returns** nothing. In the callback, return `false` to stop the error going further up, as in
Vue; return nothing to pass it on to ancestors and then
[`app.config.errorHandler`](application.md#appconfigerrorhandler).

### Example

```lua
local Boundary = Rivue.defineComponent({
	name = "Boundary",
	setup = function()
		local failed = Rivue.ref(false)
		Rivue.onErrorCaptured(function(err, _instance, info)
			warn("UI error in", info, err)
			failed.value = true
			return false -- handled
		end)
		return { failed = failed }
	end,
	render = function(ctx)
		if ctx.failed then
			return h("TextLabel", { Text = "This panel couldn't load." })
		end
		return h(Rivue.Fragment, nil, ctx.renderSlot("default"))
	end,
})

h(Boundary, nil, { h(ShopPanel) })
```

### Details

- It catches errors from descendants' render, patch, lifecycle hooks, emit handlers, event
  handlers and watchers made in their `setup()`.
- `info` is a short label such as `"render"`, `"mounted hook"`, `"component event handler"`,
  `"watcher callback"` or `"watcher getter"`.
- Errors nobody stops go to `app.config.errorHandler`, or are warned with the component chain.

---

## onActivated()

_setup() only_

For components inside [`KeepAlive`](builtins.md#keepalive): runs when the component is shown, the
first time and every time it comes back. Refresh data here.

```lua signature
function onActivated(callback: () -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `() -> ()` | | runs each time it's shown |

### Example

```lua
local InventoryTab = Rivue.defineComponent({
	name = "InventoryTab",
	setup = function()
		local items = Rivue.shallowRef({})
		Rivue.onActivated(function()
			task.spawn(function()
				items.value = Remote.request("inventory:list", nil) or {}
			end)
		end)
		return { items = items }
	end,
	render = function(ctx)
		return h("Frame", { layout = "vertical" }, {
			Rivue.hFor(ctx.items, function(item)
				return h("TextLabel", { key = item.id, Text = item.name })
			end),
		})
	end,
})
```

---

## onDeactivated()

_setup() only_

For components inside [`KeepAlive`](builtins.md#keepalive): runs when the component is hidden but
kept alive. Pause timers and sounds here.

```lua signature
function onDeactivated(callback: () -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `() -> ()` | | runs each time it's hidden |

> [!NOTE]
> A kept-alive component's watchers and `onHeartbeat` connections keep running while it's hidden.
> Pause expensive work here yourself.

### Example

```lua
local ItemPreview = Rivue.defineComponent({
	name = "ItemPreview",
	setup = function()
		local visible = true
		local angle = Rivue.ref(0)
		Rivue.onActivated(function()
			visible = true
		end)
		Rivue.onDeactivated(function()
			visible = false -- no work while hidden
		end)
		Rivue.onHeartbeat(function(dt)
			if visible then
				angle.value += dt * 45
			end
		end)
		return { angle = angle }
	end,
	render = function(ctx)
		return h("ImageLabel", { Rotation = ctx.angle, Image = "rbxassetid://0" })
	end,
})
```

---

## onRenderTracked()

_setup() only_

A debugging hook that reports every piece of state the component's render read, which is
everything that can make it re-render.

```lua signature
function onRenderTracked(callback: (event: DebuggerEvent) -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `(event: { target, key }) -> ()` | | runs once per value read |

### Example

```lua
local HealthBar = Rivue.defineComponent({
	name = "HealthBar",
	props = { player = { type = "table", required = true } },
	setup = function()
		Rivue.onRenderTracked(function(event)
			print("render reads", event.key) -- health, maxHealth
		end)
		return {}
	end,
	render = function(ctx)
		return h("Frame", { Size = UDim2.fromScale(ctx.player.health / ctx.player.maxHealth, 1) })
	end,
})
```

### Details

- Add it while debugging only. When no component uses these two hooks, tracking costs nothing
  extra.

---

## onRenderTriggered()

_setup() only_

A debugging hook that reports which change made the component re-render.

```lua signature
function onRenderTriggered(callback: (event: DebuggerEvent) -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `(event: { target, key }) -> ()` | | runs before each re-render, with the change that caused it |

### Example

```lua
local Scoreboard = Rivue.defineComponent({
	name = "Scoreboard",
	props = { stats = { type = "table", required = true } },
	setup = function()
		Rivue.onRenderTriggered(function(event)
			print("re-rendered because", event.key, "changed") -- e.g. "ping", 10 times a second
		end)
		return {}
	end,
	render = function(ctx)
		return h("TextLabel", { Text = `Kills {ctx.stats.kills}  Ping {ctx.stats.ping}` })
	end,
})
```

---

## onTransition()

_setup() only_

Runs code at a step of the component's enter or leave animation, like playing a sound once a panel
has opened.

```lua signature
function onTransition(
	name: "before-enter" | "enter" | "after-enter" | "before-leave" | "leave" | "after-leave",
	callback: (el: Instance) -> ()
)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `"before-enter" \| "enter" \| "after-enter" \| "before-leave" \| "leave" \| "after-leave"` | | the step |
| `callback` | `(el: Instance) -> ()` | | gets the component's root Instance |

> [!NOTE]
> It only fires when the component's root is animated by a [`Transition`](builtins.md#transition)
> or a `transition` prop.

### Example

```lua
local Panel = Rivue.defineComponent({
	name = "Panel",
	setup = function()
		Rivue.onTransition("after-enter", function()
			game:GetService("SoundService").PanelOpen:Play()
		end)
		return {}
	end,
	render = function(ctx)
		return h("Frame", { class = "panel" }, ctx.renderSlot("default"))
	end,
})
```

---

[← Components](component.md) · [API reference](../API.md) · [Built-in components →](builtins.md)
