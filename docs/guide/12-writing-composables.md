[Docs](../README.md) › [Guide](../GUIDE.md) › **12. Writing composables**

# 12. Writing composables

**You'll learn:** how to move logic out of a component so several components can use it, and how
to make that logic follow changing values, clean up after itself and load data safely.

## The problem

Your round timer counts down from 90:

```lua
local RoundTimer = Rivue.defineComponent({
	name = "RoundTimer",
	setup = function()
		local left = Rivue.ref(90)
		Rivue.onHeartbeat(function(dt)
			left.value = math.max(0, left.value - dt)
		end)
		return { left = left }
	end,
	render = function(ctx)
		return h("TextLabel", { Text = tostring(math.ceil(ctx.left)) })
	end,
})
```

Now the shop wants a banner that counts down to the end of a sale. You could copy those five
lines. But then a fix to one copy won't reach the other.

Instead, move them into a function. A function like this is called a **composable**. By
convention its name starts with `use`:

```lua
-- UI/composables/useCountdown.luau
local function useCountdown(seconds: number)
	local left = Rivue.ref(seconds)
	Rivue.onHeartbeat(function(dt)
		left.value = math.max(0, left.value - dt)
	end)
	return left
end
```

Both components call it in `setup`:

```lua
-- RoundTimer
setup = function()
	return { left = useCountdown(90) }
end,

-- SaleBanner
setup = function()
	return { left = useCountdown(3600) }
end,
```

That's all a composable is: a function you call from `setup`. Rivue's own `useSpring`,
`useInputType` and `attributeRef` work the same way.

![each call to a composable makes its own state](../images/composable-calls.svg)

Each call creates its own ref and its own heartbeat connection, so the two timers don't share
anything. Because they're created while `setup` runs, they belong to that component. When the
sale banner unmounts, its heartbeat stops by itself.

The rest of this chapter improves `useCountdown` step by step.

## Accept a ref, not only a number

Say the round length comes from the server and can change mid-round. The caller has it as a ref.
`useCountdown(roundLength.value)` would only read it once, so the timer would never notice the
change.

Let the composable take a number, a ref or a function, and read it with `Rivue.toValue()`:

```lua
local function useCountdown(seconds: Rivue.MaybeRefOrGetter<number>)
	local left = Rivue.ref(Rivue.toValue(seconds))

	-- When the caller's value changes, start counting from the new value
	Rivue.watch(function()
		return Rivue.toValue(seconds)
	end, function(value)
		left.value = value
	end)

	Rivue.onHeartbeat(function(dt)
		left.value = math.max(0, left.value - dt)
	end)

	return left
end
```

`toValue(x)` gives you the plain value whatever `x` is: a number stays a number, a ref gives its
`.value`, and a function is called. Inside the `watch`, reading it this way also tracks it, so the
watcher re-runs when it changes.

Callers can now pass whatever they have:

```lua
useCountdown(90) -- a fixed number
useCountdown(roundLength) -- a ref: restarts when it changes
useCountdown(function() -- a prop: restarts when the parent passes a new one
	return props.seconds
end)
```

## Return the ref itself

Return the ref, not its `.value`. A number is a copy, so it never changes after you return it:

```lua
setup = function()
	return { left = useCountdown(90) } -- ✓ the ref: render sees it count down
	-- return { left = useCountdown(90).value } -- ✗ the number 90, forever
end,
render = function(ctx)
	return h("TextLabel", { Text = tostring(math.ceil(ctx.left)) }) -- ctx.left reads the ref for you
end,
```

When a composable has several things to give back, return a table of refs and functions, like
`{ data = data, loading = loading, refresh = refresh }`.

## Clean up your own connections

Watchers, computeds and `onHeartbeat` made inside a composable are stopped for you. Connections
you make yourself with `:Connect()` are not. Disconnect them in `Rivue.onScopeDispose`, which runs
when the component that called the composable unmounts.

This composable tells the UI whether the player is standing on a shop pad:

```lua
local function usePartTouched(part: BasePart)
	local touching = Rivue.ref(false)

	local began = part.Touched:Connect(function()
		touching.value = true
	end)
	local ended = part.TouchEnded:Connect(function()
		touching.value = false
	end)

	Rivue.onScopeDispose(function()
		began:Disconnect()
		ended:Disconnect()
	end)

	return touching
end
```

Why not `onUnmounted`? It only works inside a component. `onScopeDispose` also works when the
composable is called from a store or a test, inside an
[`effectScope`](../api/reactivity-advanced.md#effectscope).

## A search box that waits for the player to stop typing

A search box that asks the server on every key press sends "S", "Sw", "Swo", "Swor", "Sword". You
only want the last one.

`customRef` makes a ref where you decide when it updates. This one waits until the player has
stopped typing for a moment:

```lua
local function useDebounced<T>(initial: T, delaySeconds: number)
	local value = initial
	local pending: thread? = nil

	return Rivue.customRef(function(track, trigger)
		return {
			get = function()
				track() -- whoever reads it will update when it changes
				return value
			end,
			set = function(new)
				-- A new key press cancels the one before it
				if pending then
					task.cancel(pending)
				end
				pending = task.delay(delaySeconds, function()
					value = new
					pending = nil
					trigger() -- now tell everything that read it
				end)
			end,
		}
	end)
end
```

Use it like any ref. Bind the text box to it, and watch it to search:

```lua
setup = function()
	local search = useDebounced("", 0.3)
	Rivue.watch(search, function(text)
		print("searching for", text) -- once, 0.3 s after the last key press
	end)
	return { search = search }
end,
render = function()
	return h("TextBox", { model = "search", PlaceholderText = "Search items" })
end,
```

## Loading data from the server

Most screens load something: a shop page, a leaderboard, the player's friends. A composable for
this needs four things: the data, whether it's loading, an error message, and a way to retry.

There's also a subtle bug to avoid. The player clicks page 1, then page 2 before page 1 has
loaded. If page 1's answer is slow, it can arrive *after* page 2's:

![an old answer arriving after a newer one](../images/stale-response.svg)

The fix is to number each request and ignore any answer that isn't for the latest one:

```lua
local function useRemoteData(action: string, payload: Rivue.MaybeRefOrGetter<any>?)
	local data = Rivue.shallowRef(nil) -- replaced as a whole, so no need to track inside it
	local loading = Rivue.ref(false)
	local errorText = Rivue.ref(nil :: string?)
	local latest = 0

	local function refresh()
		latest += 1
		local mine = latest -- this request's number
		loading.value = true
		errorText.value = nil

		task.spawn(function()
			local result, err = Rivue.Remote.request(action, Rivue.toValue(payload))
			if mine ~= latest then
				return -- a newer request was made while this one was waiting
			end
			loading.value = false
			if err then
				errorText.value = err
			else
				data.value = result
			end
		end)
	end

	-- Load now, and again whenever the payload changes (another page, a new filter)
	Rivue.watch(function()
		return Rivue.toValue(payload)
	end, refresh, { immediate = true })

	return { data = data, loading = loading, errorText = errorText, refresh = refresh }
end
```

A shop screen with pages then needs only this:

```lua
setup = function()
	local page = Rivue.ref(1)
	local shop = useRemoteData("shop:list", function()
		return { page = page.value }
	end)
	return {
		page = page, -- set ctx.page = 2 and the next page loads
		items = shop.data,
		loading = shop.loading,
		errorText = shop.errorText,
		retry = shop.refresh,
	}
end,
```

## Checklist

When you write a composable:

- Name it `use…` and call it at the top of `setup`. Not in `render`, and not in a click handler.
- Keep UI out of it. It returns state and functions, and the component decides how they look.
- Give it one job. `useCountdown` and `useInventory` are easy to reuse; `useShopScreen` isn't.
- Each call makes new state. If two components must see the *same* state, use a store instead
  (see [chapter 14](14-state-architecture.md)).

---

**Reference:** [toValue()](../api/reactivity-utilities.md#tovalue) ·
[customRef()](../api/reactivity-advanced.md#customref) ·
[onScopeDispose()](../api/reactivity-advanced.md#onscopedispose) · [watch()](../api/reactivity-core.md#watch)

[← 11. Style rules](11-style-rules.md) · [Guide contents](../GUIDE.md) · [13. Component patterns →](13-advanced-components.md)
