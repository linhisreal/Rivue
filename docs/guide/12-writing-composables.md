[Docs](../README.md) › [Guide](../GUIDE.md) › **12. Writing composables**

# 12. Writing composables

**You'll learn:** how to write `use*` functions that accept refs, clean up after themselves, and
load server data without race conditions.

## From component to composable

A round timer:

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

A sale banner needs the same countdown, so move it into a **composable**, a `use*` function
called from `setup`:

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

![each call to a composable makes its own state](../images/composable-calls.svg)

Everything a composable creates during `setup` belongs to the calling component and stops when it
unmounts. Each call creates new state, so if two components must share the *same* state, use a
store ([chapter 14](14-state-architecture.md)).

## Accept a ref, not only a number

If the round length is a ref, `useCountdown(roundLength.value)` reads it once and never sees it
change. Accept a number, ref or getter (`MaybeRefOrGetter`) and read it with `Rivue.toValue()`:

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

`toValue` unwraps a ref, calls a getter, or returns a plain value as is. Inside the `watch` source
it also tracks the read:

```lua
useCountdown(90) -- a fixed number
useCountdown(roundLength) -- a ref: restarts when it changes
useCountdown(function() -- a prop: restarts when the parent passes a new one
	return props.seconds
end)
```

## Return the ref itself

Return refs, not `.value`, or the caller gets a snapshot:

```lua
setup = function()
	return { left = useCountdown(90) } -- ✓ the ref: render sees it count down
	-- return { left = useCountdown(90).value } -- ✗ the number 90, forever
end,
render = function(ctx)
	return h("TextLabel", { Text = tostring(math.ceil(ctx.left)) }) -- ctx.left reads the ref for you
end,
```

For several values, return a table of refs and functions:
`{ data = data, loading = loading, refresh = refresh }`.

## Clean up your own connections

Watchers, computeds and `onHeartbeat` stop automatically. Your own `:Connect()` calls don't, so
disconnect them in `Rivue.onScopeDispose`:

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

Prefer it over `onUnmounted`, which only works in a component: `onScopeDispose` also runs when
the composable is used in a store or test [`effectScope`](../api/reactivity-advanced.md#effectscope).

## A debounced ref with customRef

`customRef` lets you decide when a ref notifies its readers. A debounced one for a search box:

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

It works anywhere a ref does, including `model`:

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

## Loading server data

A loader returns data, loading and error refs, and a refresh function. It also has to handle
answers arriving out of order:

![an old answer arriving after a newer one](../images/stale-response.svg)

Numbering requests and dropping any answer that isn't the latest fixes it:

```lua
local Remote = require(game.ReplicatedStorage.RivueRemote)

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
			local result, err = Remote.request(action, Rivue.toValue(payload))
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

A paged shop screen:

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

---

**Reference:** [toValue()](../api/reactivity-utilities.md#tovalue) ·
[customRef()](../api/reactivity-advanced.md#customref) ·
[onScopeDispose()](../api/reactivity-advanced.md#onscopedispose) · [watch()](../api/reactivity-core.md#watch)

[← 11. Style rules](11-style-rules.md) · [Guide contents](../GUIDE.md) · [13. Component patterns →](13-advanced-components.md)
