# Lifecycle Hooks

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

Registers a callback to run after the component is mounted.

- **Type**

  ```lua
  function onMounted(callback: () -> ())
  ```

- **Details**

  "Mounted" means the component's Instances and all its descendants are created and parented.
  The callback runs after the whole tree being mounted is attached, so `AbsoluteSize`,
  `AbsolutePosition` and `CaptureFocus()` work here. Children's `onMounted` run before their
  parents'.

- **Example**

  ```lua
  local Measure = Rivue.defineComponent(function()
  	local frame = Rivue.useTemplateRef("frame")
  	Rivue.onMounted(function()
  		print((frame.value :: Frame).AbsoluteSize)
  	end)
  	return function()
  		return h("Frame", { ref = "frame", Size = UDim2.fromScale(0.5, 0.5) })
  	end
  end, { name = "Measure" })
  ```

---

## onUpdated()

Registers a callback to run after the component re-rendered because its state changed.

- **Type**

  ```lua
  function onUpdated(callback: () -> ())
  ```

- **Details**

  Don't change component state here, or it can loop. To react to a specific value, use
  [`watch()`](reactivity-core.md#watch) with `flush = "post"`.

- **Example**

  ```lua
  local Chat = Rivue.defineComponent(function()
  	local messages = Rivue.ref({} :: { string })
  	local list = Rivue.useTemplateRef("list")

  	Rivue.onUpdated(function()
  		local frame = list.value :: ScrollingFrame
  		-- Keep scrolled to the newest message
  		frame.CanvasPosition = Vector2.new(0, frame.AbsoluteCanvasSize.Y)
  	end)

  	return function()
  		return h("ScrollingFrame", { ref = "list", AutomaticCanvasSize = Enum.AutomaticSize.Y }, {
  			h("UIListLayout"),
  			Rivue.hFor(messages.value, function(text, i)
  				return h("TextLabel", { key = i, Text = text })
  			end),
  		})
  	end
  end, { name = "Chat" })
  ```

---

## onUnmounted()

Registers a callback to run after the component is unmounted.

- **Type**

  ```lua
  function onUnmounted(callback: () -> ())
  ```

- **Details**

  Use it to clean up anything you created yourself: connections, threads, tags. Watchers,
  computeds and `Rivue.onHeartbeat` connections from `setup()` are stopped automatically.

- **Example**

  ```lua
  local Ping = Rivue.defineComponent(function()
  	local thread = task.spawn(function()
  		while true do
  			task.wait(1)
  			print("ping")
  		end
  	end)
  	Rivue.onUnmounted(function()
  		task.cancel(thread)
  	end)
  	return function()
  		return h("Frame")
  	end
  end, { name = "Ping" })
  ```

---

## onBeforeMount()

Registers a callback to run right before the component's first render.

- **Type**

  ```lua
  function onBeforeMount(callback: () -> ())
  ```

- **Details**

  The component has its state but no Instances yet.

- **Example**

  ```lua
  local Screen = Rivue.defineComponent(function()
  	Rivue.onBeforeMount(function()
  		print("about to render")
  	end)
  	return function()
  		return h("Frame")
  	end
  end, { name = "Screen" })
  ```

---

## onBeforeUpdate()

Registers a callback to run right before the component re-renders because its state changed.

- **Type**

  ```lua
  function onBeforeUpdate(callback: () -> ())
  ```

- **Example**

  ```lua
  local Score = Rivue.defineComponent(function()
  	local score = Rivue.ref(0)
  	local list = Rivue.useTemplateRef("list")
  	local previousHeight = 0

  	Rivue.onBeforeUpdate(function()
  		-- Read the old layout before it changes
  		local frame = list.value :: Frame?
  		previousHeight = if frame then frame.AbsoluteSize.Y else 0
  	end)

  	return function()
  		return h("Frame", { ref = "list" }, { h("TextLabel", { Text = tostring(score.value) }) })
  	end
  end, { name = "Score" })
  ```

---

## onBeforeUnmount()

Registers a callback to run right before the component is unmounted, while its Instances still
exist.

- **Type**

  ```lua
  function onBeforeUnmount(callback: () -> ())
  ```

- **Example**

  ```lua
  local Draft = Rivue.defineComponent(function()
  	local text = Rivue.ref("")
  	Rivue.onBeforeUnmount(function()
  		print("saving draft", text.value)
  	end)
  	return function()
  		return h("TextBox", { model = text })
  	end
  end, { name = "Draft" })
  ```

---

## onErrorCaptured()

Registers a callback that runs when an error comes from a descendant component.

- **Type**

  ```lua
  function onErrorCaptured(callback: (err: string, instance: ComponentInstance, info: string) -> boolean?)
  ```

- **Details**

  - **What's caught:** errors from descendants' render, patch, lifecycle hooks and emit
    handlers.
  - **`info`** says where the error happened, such as `"render"` or `"mounted hook"`.
  - **Return `true`** to stop the error from going further up.
  - **Uncaught errors** go to [`app.config.errorHandler`](application.md#appconfigerrorhandler),
    or are reported with `warn` along with the component chain.

- **Example**

  An error boundary:

  ```lua
  local ErrorBoundary = Rivue.defineComponent(function(_props, ctx)
  	local failed = Rivue.ref(false)
  	Rivue.onErrorCaptured(function(err, _instance, info)
  		warn("caught", info, err)
  		failed.value = true
  		return true
  	end)
  	return function()
  		if failed.value then
  			return h("TextLabel", { Text = "Something went wrong" })
  		end
  		return h(Rivue.Fragment, nil, ctx.renderSlot("default"))
  	end
  end, { name = "ErrorBoundary" })
  ```

---

## onActivated()

Registers a callback that runs when a component cached by [`KeepAlive`](builtins.md#keepalive)
is shown: on first mount, and every time it comes back.

- **Type**

  ```lua
  function onActivated(callback: () -> ())
  ```

- **Example**

  ```lua
  local InventoryTab = Rivue.defineComponent(function()
  	Rivue.onActivated(function()
  		print("refresh inventory")
  	end)
  	return function()
  		return h("Frame")
  	end
  end, { name = "InventoryTab" })
  ```

---

## onDeactivated()

Registers a callback that runs when a component cached by [`KeepAlive`](builtins.md#keepalive)
is hidden (detached, but kept alive).

- **Type**

  ```lua
  function onDeactivated(callback: () -> ())
  ```

- **Example**

  ```lua
  local Preview = Rivue.defineComponent(function()
  	local spinning = true
  	Rivue.onActivated(function()
  		spinning = true
  	end)
  	Rivue.onDeactivated(function()
  		spinning = false -- stop work while hidden
  	end)
  	Rivue.onHeartbeat(function()
  		if spinning then
  			-- rotate the preview
  		end
  	end)
  	return function()
  		return h("ViewportFrame")
  	end
  end, { name = "Preview" })
  ```

---

## onRenderTracked()

Debug hook: called for each reactive read during the component's render.

- **Type**

  ```lua
  function onRenderTracked(callback: (event: DebuggerEvent) -> ())

  type DebuggerEvent = { target: unknown, key: unknown }
  ```

- **Example**

  ```lua
  local Probe = Rivue.defineComponent(function()
  	local state = Rivue.reactive({ a = 1, b = 2 })
  	Rivue.onRenderTracked(function(event)
  		print("render reads", event.key) -- a, b
  	end)
  	return function()
  		return h("TextLabel", { Text = `{state.a} {state.b}` })
  	end
  end, { name = "Probe" })
  ```

---

## onRenderTriggered()

Debug hook: called with the reactive write that made the component re-render.

- **Type**

  ```lua
  function onRenderTriggered(callback: (event: DebuggerEvent) -> ())
  ```

- **Details**

  This answers "why did this re-render?". Only add it while debugging: when no component registers
  these hooks, tracking costs nothing extra.

- **Example**

  ```lua
  local Slow = Rivue.defineComponent(function()
  	local state = Rivue.reactive({ hp = 100, name = "Player" })
  	Rivue.onRenderTriggered(function(event)
  		print("re-rendered because", event.key, "changed")
  	end)
  	return function()
  		return h("TextLabel", { Text = `{state.name}: {state.hp}` })
  	end
  end, { name = "Slow" })
  ```

---

## onTransition()

Registers a callback for transition events on this component's root element.

- **Type**

  ```lua
  function onTransition(
  	name: "before-enter" | "enter" | "after-enter" | "before-leave" | "leave" | "after-leave",
  	callback: (el: Instance) -> ()
  )
  ```

- **Details**

  These fire when the component's root is animated by a [`Transition`](builtins.md#transition) or
  a `transition` prop.

- **Example**

  ```lua
  local Toast = Rivue.defineComponent(function()
  	Rivue.onTransition("after-enter", function(el)
  		print(el.Name, "finished appearing")
  	end)
  	return function()
  		return h("TextLabel", { Text = "Saved" })
  	end
  end, { name = "Toast" })
  ```
