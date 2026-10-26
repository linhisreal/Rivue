[Docs](../README.md) › [Guide](../GUIDE.md) › **15. Performance in depth**

# 15. Performance in depth

**You'll learn:** where render time goes, how to find what re-renders, and the fixes beyond the
basics in [chapter 9](09-performance-and-debugging.md#performance).

## Where the time goes

A state change costs the render functions that read it, plus a diff against the Instances.
Rivue only writes properties that changed, so engine calls stay small. What you control is how
often renders run and how big they are.

## Keep fast-changing reads small

Only components whose render read a changed value re-render. Children whose props didn't change
are skipped. So a value that changes 10 times a second should be read in the smallest component
that shows it:

![moving a fast-changing read into a small component](../images/rerender-split.svg)

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

## Finding what re-renders

On top of `onRenderTriggered` and `app:printTree()` from
[chapter 9](09-performance-and-debugging.md#debugging):

- `Rivue.onRenderTracked(fn)` lists every value a render read, i.e. everything that can
  re-render it.
- `Rivue.debug.measure("label", fn)` logs how long `fn` took, when `Rivue.debug.enabled` is on.

## memo and throttle

`memo` skips an element and its subtree while the listed values are unchanged:

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

A value missing from the list won't update the row, so list everything it renders from.

For per-frame sources, throttle the writes to the ref rather than the render:

```lua
setup = function()
	local mouse = Rivue.ref(Vector2.zero)

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

No need to work around these:

- **Inline handlers.** A new `onClick` closure each render is swapped into the existing
  connection, not reconnected.
- **Reordering.** Adding, removing or moving a row writes one `LayoutOrder`, not one per row.
- **Many writes in a row.** Updates are batched; each affected component renders once, parents
  first.

---

**Reference:** [onRenderTriggered()](../api/lifecycle.md#onrendertriggered) ·
[VirtualList](../api/builtins.md#virtuallist) · [Pooling options](../api/application.md#pooling-options) ·
[utils.throttle()](../api/utilities.md#utilsthrottle) · [Element props: memo](../api/render-function.md#element-props)

[← 14. Organising state](14-state-architecture.md) · [Guide contents](../GUIDE.md) · [16. Testing UI →](16-testing-ui.md)
