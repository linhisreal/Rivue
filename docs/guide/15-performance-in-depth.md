[Docs](../README.md) › [Guide](../GUIDE.md) › **15. Performance in depth**

# 15. Performance in depth

**You'll learn:** what makes Rivue UI slow, how to find the component causing it, and which fix
to try first.

Most UI never needs any of this. Read it when something actually feels slow, or when you build a
screen that updates many times a second.

## What takes time

When state changes, Rivue does two kinds of work:

1. **It runs render functions** of the components that used that state. This is plain Luau, and
   a single render is cheap. It adds up when a big render runs many times a second.
2. **It changes Instances** to match. Every property it sets on an Instance is a call into the
   Roblox engine, and these calls are what usually cost the most.

Rivue already keeps the second part small: it only sets properties whose values changed. So the
main thing you control is the first part: **how often renders run, and how big they are.**

## Which components re-render

When a value changes, Rivue re-renders only the components whose render read that value. A child
component isn't re-rendered just because its parent was, as long as the props it gets are the
same.

So it matters *where* a fast-changing value is read. Here a HUD shows the player's ping, which
updates ten times a second:

![moving a fast-changing read into a small component](../images/rerender-split.svg)

On the left, `Hud`'s render reads `ping`, so its whole render runs ten times a second, even
though only one label changes. On the right, the ping label is its own small component. Now
only that tiny render runs ten times a second:

```lua
-- Network is a store module (chapter 14) whose state.ping the client updates
local PingLabel = Rivue.defineComponent({
	name = "PingLabel",
	render = function()
		return h("TextLabel", { Text = `{Network.state.ping} ms` })
	end,
})

-- In Hud's render, instead of reading ping itself:
h(PingLabel)
```

This is the most useful fix in this chapter: **move a value that changes often into the smallest
component that shows it.**

## Finding the slow part

Before changing code, find out what is re-rendering and why.

Which value made this component re-render? Add this to its `setup`:

```lua
Rivue.onRenderTriggered(function(event)
	print("re-rendered because", event.key, "changed")
end)
```

Some other tools:

- `Rivue.onRenderTracked(fn)` prints every value the render read, to see what it depends on.
- `app:printTree()` prints all mounted components, to see what's on screen.
- `Rivue.debug.measure("label", fn)` prints how long `fn` takes, when `Rivue.debug.enabled` is
  `true`.

## Fixes, from most to least common

| What you see | What to do |
|---|---|
| A big component re-renders many times a second | Move the fast-changing value into a small child component (above) |
| Every row of a list updates when one item changes | Give each row a stable `key`, and make the row its own component |
| A list has hundreds or thousands of rows | Use `Rivue.VirtualList`: only the rows on screen exist |
| A part of a render rarely changes but is expensive | Add `memo = { ... }` to skip it while those values stay the same |
| A value is updated every frame (mouse position, a timer) | Update the ref a few times a second with `Rivue.utils.throttle` |
| Big data that you replace, never edit | Use `Rivue.shallowRef` instead of `ref` |
| Many Instances created and destroyed (kill feed, damage numbers) | `createApp(App, { usePool = true })` reuses Instances |

### Skipping a row with `memo`

`memo` takes a list of values. While they're the same as last render, Rivue skips that element
and everything inside it:

```lua
Rivue.hFor(ctx.items, function(item)
	return h("Frame", {
		key = item.id,
		memo = { item.id, item.version }, -- only re-check this row when its version changes
	}, {
		h("TextLabel", { Text = item.name }),
		h("ImageLabel", { Image = item.icon }),
	})
end)
```

Only use it when you know which values the row depends on. If you leave one out, the row won't
update when that value changes.

### Updating less often with `throttle`

The mouse moves every frame. A crosshair label doesn't need to update 60 times a second:

```lua
setup = function()
	local mouse = Rivue.ref(Vector2.zero)

	-- Runs at most once every 50 ms, however often it's called
	local update = Rivue.utils.throttle(function(position: Vector2)
		mouse.value = position
	end, 50)

	Rivue.onRenderStepped(function()
		update(game:GetService("UserInputService"):GetMouseLocation())
	end)

	return { mouse = mouse }
end,
```

## What Rivue already does for you

You don't need to optimise these yourself:

- **Unchanged properties aren't set.** A re-render where nothing changed doesn't touch any
  Instance.
- **Child components with the same props are skipped** when their parent re-renders.
- **Inline handlers are fine.** `onClick = function() ... end` creates a new function every
  render, but Rivue swaps it into the existing connection instead of reconnecting.
- **Reordering lists is cheap.** Adding, removing or moving a row updates one `LayoutOrder`,
  not one per row.
- **Changes are batched.** Setting ten values in a row re-renders each affected component once.

---

**Reference:** [onRenderTriggered()](../api/lifecycle.md#onrendertriggered) ·
[VirtualList](../api/builtins.md#virtuallist) · [Pooling options](../api/application.md#pooling-options) ·
[utils.throttle()](../api/utilities.md#utilsthrottle) · [Element props: memo](../api/render-function.md#element-props)

[← 14. Organising state](14-state-architecture.md) · [Guide contents](../GUIDE.md) · [16. Testing UI →](16-testing-ui.md)
