[Docs](../README.md) › [API](../API.md) › **Lifecycle Hooks**

# Lifecycle Hooks

**Learn it:** [Guide 4: Components](../guide/04-components.md) · [Guide 7: Effects and animation](../guide/07-effects-and-animation.md)

Register these in a component's `setup()`. Calling one anywhere else errors. All examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h
```

- [onMounted()](#onmounted)
- [onUpdated()](#onupdated)
- [onUnmounted()](#onunmounted)
- [onBeforeMount()](#onbeforemount)
- [onBeforeUpdate()](#onbeforeupdate)
- [onBeforeUnmount()](#onbeforeunmount)
- [onErrorCaptured()](#onerrorcaptured)
- [onActivated()](#onactivated)
- [onDeactivated()](#ondeactivated)
- [onRenderTracked()](#onrendertracked)
- [onRenderTriggered()](#onrendertriggered)
- [onTransition()](#ontransition)

---

## onMounted()

Runs once the component is on screen and its Instances are parented. The place for anything that
needs real Instances: reading `AbsoluteSize`, focusing, starting a tween.

- **Example**

  Focus a search box as soon as the menu opens:

  ```lua
  local SearchBar = Rivue.defineComponent({
  	name = "SearchBar",
  	setup = function()
  		local box = Rivue.useTemplateRef("box")
  		Rivue.onMounted(function()
  			-- The TextBox exists and is parented now, so focusing works
  			(box.value :: TextBox):CaptureFocus()
  		end)
  		return {}
  	end,
  	render = function()
  		return h("TextBox", { ref = "box", PlaceholderText = "Search items" })
  	end,
  })
  ```

- **Details**

  "Mounted" means the component's Instances and all its descendants are created and parented.
  The callback runs after the whole tree being mounted is attached, so `AbsoluteSize`,
  `AbsolutePosition` and `CaptureFocus()` work here. Children's `onMounted` run before their
  parents'.

- **Type**

  ```lua
  function onMounted(callback: () -> ())
  ```

---

## onUpdated()

Runs after the component re-rendered because its state changed. Use it when you need to react to the
updated Instances.

- **Example**

  Keep a chat scrolled to the newest message:

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

- **Details**

  Don't change component state here, or it can loop. To react to a specific value, use
  [`watch()`](reactivity-core.md#watch) with `flush = "post"`.

- **Type**

  ```lua
  function onUpdated(callback: () -> ())
  ```

---

## onUnmounted()

Runs after the component is removed. The place to disconnect connections and stop anything you
started yourself.

- **Example**

  Disconnect a connection you made yourself:

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

- **Details**

  Use it to clean up anything you created yourself: connections, threads, tags. Watchers,
  computeds and `Rivue.onHeartbeat` connections from `setup()` are stopped automatically.

- **Type**

  ```lua
  function onUnmounted(callback: () -> ())
  ```

---

## onBeforeMount()

Runs right before the component renders for the first time.

- **Example**

  Load a saved setting before the first render, so the UI doesn't render twice:

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

- **Details**

  The component has its state but no Instances yet.

- **Type**

  ```lua
  function onBeforeMount(callback: () -> ())
  ```

---

## onBeforeUpdate()

Runs right before the component re-renders, while the Instances still show the old state.

- **Example**

  Remember whether the player had scrolled up, before new messages arrive:

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
  			if wasAtBottom then -- don't yank the view if they were reading older messages
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

- **Type**

  ```lua
  function onBeforeUpdate(callback: () -> ())
  ```

---

## onBeforeUnmount()

Runs right before the component is removed, while its Instances still exist. Use it to save state or
start an exit animation.

- **Example**

  Save what the player typed when the window closes:

  ```lua
  local NoteEditor = Rivue.defineComponent({
  	name = "NoteEditor",
  	setup = function()
  		local note = Rivue.ref("")
  		Rivue.onBeforeUnmount(function()
  			Rivue.Remote.fire("notes:save", { text = note.value })
  		end)
  		return { note = note }
  	end,
  	render = function()
  		return h("TextBox", { model = "note", MultiLine = true, PlaceholderText = "Notes" })
  	end,
  })
  ```

- **Type**

  ```lua
  function onBeforeUnmount(callback: () -> ())
  ```

---

## onErrorCaptured()

Catches errors from components below this one, so one broken widget can show a fallback instead of
breaking the whole screen.

- **Example**

  An error boundary: if anything inside fails, show a message instead of a broken screen:

  ```lua
  local ErrorBoundary = Rivue.defineComponent({
  	name = "ErrorBoundary",
  	setup = function()
  		local failed = Rivue.ref(false)
  		Rivue.onErrorCaptured(function(err, _instance, info)
  			warn("UI error in", info, err)
  			failed.value = true
  			return true -- handled, don't pass it further up
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

  -- Usage
  h(ErrorBoundary, nil, { h(ShopPanel) })
  ```

- **Details**

  - **What's caught:** errors from descendants' render, patch, lifecycle hooks and emit
    handlers.
  - **`info`** says where the error happened, such as `"render"` or `"mounted hook"`.
  - **Return `true`** to stop the error from going further up.
  - **Uncaught errors** go to [`app.config.errorHandler`](application.md#appconfigerrorhandler),
    or are reported with `warn` along with the component chain.

- **Type**

  ```lua
  function onErrorCaptured(callback: (err: string, instance: ComponentInstance, info: string) -> boolean?)
  ```

---

## onActivated()

For components inside [`KeepAlive`](builtins.md#keepalive): runs when the component is shown, the
first time and every time it comes back. Refresh data here.

- **Example**

  Refresh a tab's data every time the player switches back to it:

  ```lua
  local InventoryTab = Rivue.defineComponent({
  	name = "InventoryTab",
  	setup = function()
  		local items = Rivue.shallowRef({})
  		Rivue.onActivated(function()
  			task.spawn(function()
  				items.value = Rivue.Remote.request("inventory:list", nil) or {}
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

- **Type**

  ```lua
  function onActivated(callback: () -> ())
  ```

---

## onDeactivated()

For components inside [`KeepAlive`](builtins.md#keepalive): runs when the component is hidden but
kept alive. Pause timers and sounds here.

- **Example**

  Stop spinning a 3D preview while its tab is hidden:

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

- **Type**

  ```lua
  function onDeactivated(callback: () -> ())
  ```

---

## onRenderTracked()

A debugging hook that tells you every piece of state the component's render read, so you can see
what it depends on.

- **Example**

  See exactly what a render depends on:

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

- **Type**

  ```lua
  function onRenderTracked(callback: (event: DebuggerEvent) -> ())

  type DebuggerEvent = { target: unknown, key: unknown }
  ```

---

## onRenderTriggered()

A debugging hook that tells you which change made the component re-render. The answer to "why did
this render again?".

- **Example**

  Find out why a component keeps re-rendering:

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

- **Details**

  This answers "why did this re-render?". Only add it while debugging: when no component registers
  these hooks, tracking costs nothing extra.

- **Type**

  ```lua
  function onRenderTriggered(callback: (event: DebuggerEvent) -> ())
  ```

---

## onTransition()

Runs your code at each step of the component's enter and leave animations, for things like playing a
sound when a panel finishes opening.

- **Example**

  Play a sound when a panel has finished sliding in:

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

- **Details**

  These fire when the component's root is animated by a [`Transition`](builtins.md#transition) or
  a `transition` prop.

- **Type**

  ```lua
  function onTransition(
  	name: "before-enter" | "enter" | "after-enter" | "before-leave" | "leave" | "after-leave",
  	callback: (el: Instance) -> ()
  )
  ```

---

[← Components](component.md) · [API reference](../API.md) · [Built-in Components →](builtins.md)
