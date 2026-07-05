[Docs](../README.md) › [Guide](../GUIDE.md) › **7. Effects and animation**

# 7. Side effects, cleanup and animation

Some UI code doesn't describe UI: it connects signals, polls the server or ticks a timer. This
chapter covers where that code goes, what cleans up after itself, the order things run in after a
change, and animation.

## Side effects live in setup

Put that code in `setup`. `render` can run many times a second, so it's the wrong place for
anything that should happen once:

```lua
setup = function(props)
	local elapsed = Rivue.ref(0)

	-- Run code when something changes
	Rivue.watch(function()
		return props.userId
	end, function(id)
		loadProfile(id)
	end, { immediate = true })

	-- Run code every frame, disconnected on unmount
	Rivue.onHeartbeat(function(dt)
		elapsed.value += dt
	end)

	-- Your own connections need cleanup
	local conn = workspace.ChildAdded:Connect(onChildAdded)
	Rivue.onUnmounted(function()
		conn:Disconnect()
	end)

	return { elapsed = elapsed }
end,
```

| Created in setup | Cleaned up on unmount? |
|---|---|
| `watch`, `watchEffect`, `computed` | yes |
| `onHeartbeat`, `onRenderStepped`, `onStepped` | yes |
| `queueJob`, `useTag`, `attributeRef` | yes |
| `something:Connect(...)` you wrote | **no**, disconnect it in `onUnmounted` |

The two watchers differ in what they track. `watch(source, callback)` only looks at `source`, and
calls `callback(new, old)` when it changes. `watchEffect(fn)` runs `fn` right away, then again
whenever anything it read changes.

When a watcher starts something slow, like a delayed search, the value can change again before it
finishes. `Rivue.onWatcherCleanup` cancels the old run before the next one starts:

```lua
Rivue.watch(query, function(text)
	local pending = task.delay(0.3, function()
		search(text)
	end)
	Rivue.onWatcherCleanup(function()
		task.cancel(pending)
	end)
end)
```

Call it before any yield in the callback, or Rivue can't tell which watcher it belongs to.

## What runs when, after a change

Change five values in a row and each affected component still renders once. Rivue batches the
updates and runs them in this order:

```mermaid
flowchart TD
    W["count.value = 1"] --> S["flush = 'sync' watchers<br/>run immediately"]
    W --> P["default ('pre') watchers<br/>later in the same frame"]
    P --> R["component re-renders<br/>batched, parents before children"]
    R --> M["onUpdated, onMounted of new children,<br/>enter transitions"]
    M --> H["flush = 'post' watchers<br/>next Heartbeat"]
```

If you change state and read an Instance straight away, you see the old value. `Rivue.nextTick()`
yields until the re-renders have run.

## Animation

For things that appear and disappear, wrap the element in `Transition` and toggle it inside.
`from` describes the hidden state. The element tweens out of it when it appears, and back into it
before it's destroyed.

```lua
h(Rivue.Transition, {
	tweenInfo = TweenInfo.new(0.2),
	from = { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.55) },
}, {
	Rivue.hIf(ctx.open, h("Frame", { Position = UDim2.fromScale(0.5, 0.5) })),
})
```

`Rivue.transitions` has the common ones ready: `fade`, `slide` and `pop`. Each returns the props
for a Transition:

![what fade, slide and pop do when an element enters](../assets/diagrams/transition-presets.webp)

```lua
h(Rivue.Transition, Rivue.transitions.slide({ direction = "up" }), {
	Rivue.hIf(ctx.toast ~= nil, h("TextLabel", { Text = ctx.toast })),
})
```

They take a `duration`, and anything else you pass, like `mode = "out-in"`, goes on to the
Transition.

Lists get `TransitionGroup`, where keyed items tween in when they're added and out when they're
removed.

For values that move, like a health bar sliding down, `useTween` and `useSpring` turn state into
an animated value. It changes every frame while it moves, so bind it to the property with
`Rivue.bind`. Each frame then writes only the bar's `Size` and the component doesn't re-render:

```lua
setup = function(props)
	return {
		shown = Rivue.useSpring(function()
			return props.health / 100
		end),
	}
end,

render = function(ctx)
	return h("Frame", {
		Size = Rivue.bind(function()
			return UDim2.fromScale(ctx.shown, 1)
		end),
	})
end,
```

---

**Try it:** [Hud example](../../examples/components/Hud.luau) (a spring on a bound property, attributeRef) ·
[Modal example](../../examples/components/Modal.luau) (Transition)\
**Reference:** [watch()](../api/reactivity-core.md#watch) ·
[watchEffect()](../api/reactivity-core.md#watcheffect) ·
[onWatcherCleanup()](../api/reactivity-core.md#onwatchercleanup) · [Lifecycle hooks](../api/lifecycle.md) ·
[Update timing](../api/scheduler.md#update-timing) · [Transition](../api/builtins.md#transition) ·
[transitions](../api/builtins.md#transitions) · [useSpring()](../api/roblox.md#usespring) ·
[bind()](../api/render-function.md#bind)

[← 6. Styling and layout](06-styling-and-layout.md) · [Guide contents](../GUIDE.md) · [8. Sharing state and the server →](08-state-and-server.md)
