[Docs](../README.md) › [Guide](../GUIDE.md) › **7. Effects and animation**

# 7. Side effects, cleanup and animation

**You'll learn:** where code that isn't "describe the UI" goes, what cleans itself up, when things
run after a change, and how to animate.

## Side effects live in setup

Connecting signals, starting timers, calling the server and reacting to changes all belong in
`setup`, never in `render`:

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

`watch(source, callback)` runs `callback(new, old)` when `source` changes. `watchEffect(fn)` runs
`fn` now and again whenever anything it read changes.

## What runs when, after a change

You can change several values in a row: Rivue batches the updates and renders each component at
most once.

```mermaid
flowchart TD
    W["count.value = 1"] --> S["flush = 'sync' watchers<br/>run immediately"]
    W --> P["default ('pre') watchers<br/>later in the same frame"]
    P --> R["component re-renders<br/>batched, parents before children"]
    R --> M["onUpdated, onMounted of new children,<br/>enter transitions"]
    M --> H["flush = 'post' watchers<br/>next Heartbeat"]
```

Need the updated Instances right after a change? `Rivue.nextTick()` yields until the re-renders
have run.

## Animation

**Appearing and disappearing.** Wrap the element in `Transition` and toggle it inside. `from` is
the hidden state: the element tweens from it when it appears, and back to it before it's
destroyed.

```lua
h(Rivue.Transition, {
	tweenInfo = TweenInfo.new(0.2),
	from = { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.55) },
}, {
	Rivue.hIf(ctx.open, h("Frame", { Position = UDim2.fromScale(0.5, 0.5) })),
})
```

Use `TransitionGroup` for lists: keyed items tween in when added and out when removed.

**Values that move.** `useTween` and `useSpring` turn state into an animated value you bind to a
prop:

```lua
setup = function(props)
	return {
		shown = Rivue.useSpring(function()
			return props.health / 100
		end),
	}
end,

render = function(ctx)
	return h("Frame", { Size = UDim2.fromScale(ctx.shown, 1) })
end,
```

---

**Try it:** [Hud example](../../examples/components/Hud.luau) (springs, attributeRef) ·
[Modal example](../../examples/components/Modal.luau) (Transition)
**Reference:** [watch()](../api/reactivity-core.md#watch) ·
[watchEffect()](../api/reactivity-core.md#watcheffect) · [Lifecycle hooks](../api/lifecycle.md) ·
[Update timing](../api/scheduler.md#update-timing) · [Transition](../api/builtins.md#transition) ·
[useSpring()](../api/roblox.md#usespring)

[← 6. Styling and layout](06-styling-and-layout.md) · [Guide contents](../GUIDE.md) · [8. Sharing state and the server →](08-state-and-server.md)
