[Docs](../README.md) › [API](../API.md) › **Reactivity: Advanced**

# Reactivity: Advanced

**Learn it:** [Guide 2: State](../guide/02-state.md) · [Guide 9: Performance and debugging](../guide/09-performance-and-debugging.md)

Lower-level reactivity for performance work and library code. Examples assume
`local Rivue = require(game.ReplicatedStorage.RivueUI)`.

---

## shallowRef()

A ref that only notices when `.value` is replaced, not when something inside it changes. Good for
big data you swap out whole, like a server response, and for values that shouldn't be proxied, like
Instances or component definitions.

```lua signature
function shallowRef<T>(value: T): Ref<T>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `T` | | the starting value, stored as is |

**Returns** a [`Ref<T>`](reactivity-core.md#type-ref).

### Example

```lua
local state = Rivue.shallowRef({ count = 1 })

state.value.count = 2 -- doesn't trigger anything
state.value = { count = 2 } -- triggers
```

### Details

- After changing what's inside without replacing `.value`, call [`triggerRef()`](#triggerref).

---

## triggerRef()

Tells everything using a [`shallowRef`](#shallowref) to update, after you changed what's inside it.

```lua signature
function triggerRef<T>(ref: Ref<T>)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `ref` | `Ref<T>` | | the ref whose contents changed |

> [!NOTE]
> Passing something that isn't a ref does nothing. It's only logged when `Rivue.debug.enabled` is
> on.

### Example

```lua
local inventory = Rivue.shallowRef({ "Sword" })

Rivue.watchEffect(function()
	print(#inventory.value)
end)

table.insert(inventory.value, "Shield") -- not tracked
Rivue.triggerRef(inventory) -- prints 2
```

---

## customRef()

A ref with your own rules for when it counts as changed, such as a value that only updates after
the player stops typing.

```lua signature
function customRef<T>(factory: (track: () -> (), trigger: () -> ()) -> {
	get: () -> T,
	set: (value: T) -> (),
}): Ref<T>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `factory` | `(track, trigger) -> { get, set }` | | call `track()` in `get`, and `trigger()` when readers should update |

**Returns** a `Ref<T>` that reads through `get` and writes through `set`. A factory that doesn't
return both errors.

### Example

```lua
local function useDebouncedRef<T>(value: T, delaySeconds: number)
	local pending: thread? = nil
	return Rivue.customRef(function(track, trigger)
		return {
			get = function()
				track()
				return value
			end,
			set = function(newValue)
				if pending then
					task.cancel(pending)
				end
				pending = task.delay(delaySeconds, function()
					value = newValue
					trigger()
				end)
			end,
		}
	end)
end

local search = useDebouncedRef("", 0.3)
```

### Details

- `get` runs on every read. Rivue keeps the value it last returned, as Vue 3.5 does, so the
  [DevTools plugin](../DEVTOOLS.md) can show and edit a customRef without calling `get` itself.

---

## shallowReactive()

Like [`reactive()`](reactivity-core.md#reactive), but only the top-level fields are reactive.
Nested tables stay plain.

```lua signature
function shallowReactive<T>(target: T): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `target` | `T` | | the table to wrap |

### Example

```lua
local state = Rivue.shallowReactive({ count = 1, nested = { bar = 2 } })

state.count += 1 -- reactive
state.nested.bar += 1 -- not reactive
state.nested = { bar = 10 } -- reactive: a top-level field
```

### Details

- Component props are shallow reactive.

---

## shallowReadonly()

Like [`readonly()`](reactivity-core.md#readonly), but only the top-level fields are protected.

```lua signature
function shallowReadonly<T>(target: T): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `target` | `T` | | the table to wrap |

### Example

```lua
local state = Rivue.shallowReadonly({ count = 1, nested = { bar = 2 } })

state.count += 1 -- ignored
state.nested.bar += 1 -- works
```

---

## isShallow()

Whether a table came from `shallowReactive()` or `shallowReadonly()`.

```lua signature
function isShallow(value: unknown): boolean
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `unknown` | | anything |

### Example

```lua
print(Rivue.isShallow(Rivue.shallowReactive({}))) -- true
print(Rivue.isShallow(Rivue.reactive({}))) -- false
```

---

## toRaw()

The plain table behind a reactive one. Read or pass data through it without tracking, for example
when sending state to the server, or to use `table.*` functions.

```lua signature
function toRaw<T>(proxy: T): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `proxy` | `T` | | a reactive or read-only proxy; anything else is returned as is |

> [!WARNING]
> Writes to the raw table don't trigger anything, so the UI won't update from them.

### Example

```lua
local original = { 3, 1, 2 }
local list = Rivue.reactive(original)

print(Rivue.toRaw(list) == original) -- true

local sorted = table.clone(Rivue.toRaw(list))
table.sort(sorted)
```

---

## markRaw()

Marks a table so Rivue never makes it reactive, even when it ends up inside reactive state. Use it
for big static data and for tables another library owns.

```lua signature
function markRaw<T>(value: T): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `T` | | the table to mark; other values pass through |

**Returns** the same table.

### Example

```lua
local itemDatabase = Rivue.markRaw({ sword = { damage = 10 } })
local state = Rivue.reactive({ items = itemDatabase })

print(Rivue.isReactive(state.items)) -- false
```

---

## effect()

The building block under watchers and component renders: a function that runs again when what it
read changes. In app code, use [`watchEffect()`](reactivity-core.md#watcheffect).

```lua signature
function effect(fn: () -> (), options: EffectOptions?): Effect
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fn` | `() -> ()` | | the function to run |
| `options` | `EffectOptions?` | | |
| `options.lazy` | `boolean` | `false` | don't run until you call `effect.run()` |
| `options.scheduler` | `(run: () -> boolean) -> ()` | | called instead of running on a change; decide when to call `run`, which returns `false` when nothing the effect read changed |
| `options.onTrack` | `(event: DebuggerEvent) -> ()` | | called for each value it starts tracking |
| `options.onTrigger` | `(event: DebuggerEvent) -> ()` | | called with the change that made it run again |
| `options.allowRecurse` | `boolean` | `false` | let it trigger itself by writing what it reads |

**Returns** an `Effect`: `{ run: () -> boolean, stop: (self) -> (), pause: (self) -> (), resume: (self) -> (), active: boolean }`. A
`DebuggerEvent` is `{ target, key }`.

> [!NOTE]
> Unlike Vue's `effect()`, the first run is deferred to the next flush, not immediate. With a
> `scheduler`, the first run goes to it straight away.

### Example

```lua
local count = Rivue.ref(0)

local runner = Rivue.effect(function()
	print("count is", count.value)
end, {
	lazy = true,
	onTrigger = function(event)
		print("changed key", event.key)
	end,
})

runner.run() -- count is 0
count.value += 1 -- changed key value, then (deferred) count is 1
runner:stop()
```

### Details

- Made in a component's `setup()`, it stops on unmount.

---

## effectScope()

Collects the computeds and watchers made inside it, so you can stop them all at once. Mostly for
state that lives outside components, and for tests.

```lua signature
function effectScope(detached: boolean?): EffectScope
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `detached` | `boolean?` | `false` | don't stop when the scope it was made in stops |

**Returns** an `EffectScope`:
`{ run: (self, fn: () -> unknown) -> unknown, stop: (self) -> (), pause: (self) -> (), resume: (self) -> (), active: boolean, paused: boolean }`.

### Example

```lua
local count = Rivue.ref(0)
local scope = Rivue.effectScope()

scope:run(function()
	local doubled = Rivue.computed(function()
		return count.value * 2
	end)
	Rivue.watch(doubled, function(value)
		print(value)
	end)
	Rivue.watchEffect(function()
		print("count:", count.value)
	end)
	return nil
end)

scope:stop() -- stops the computed and both watchers
```

Pause a scope while its UI is hidden, so its watchers stop reacting:

```lua
local health = Rivue.ref(100)
local hud = Rivue.effectScope()

hud:run(function()
	Rivue.watchEffect(function()
		print("health:", health.value)
	end)
	return nil
end)

hud:pause()
health.value = 80 -- nothing runs
health.value = 60
hud:resume() -- runs once, with 60
```

### Details

- `pause()` holds the watchers and effects in the scope and its child scopes. Anything that changed
  while paused runs once on `resume()`.
- Computeds keep updating while paused, so reading one gives the current value.
- `resume()` also resumes watchers that were paused on their own handle.
- A scope created inside a paused scope starts unpaused.
- Each component's `setup()` runs in its own scope.
- A store module required first from a component's setup would otherwise belong to that component;
  `effectScope(true)` keeps its computeds alive for the whole game.

---

## getCurrentScope()

The effect scope that's active right now, if any. Composables use it to check they were called
somewhere that cleans up.

```lua signature
function getCurrentScope(): EffectScope?
```

### Example

```lua
local function useClock()
	if not Rivue.getCurrentScope() then
		warn("useClock() should be called in setup() or effectScope():run()")
	end
	local now = Rivue.ref(os.clock())
	local conn = game:GetService("RunService").Heartbeat:Connect(function()
		now.value = os.clock()
	end)
	Rivue.onScopeDispose(function()
		conn:Disconnect()
	end)
	return now
end
```

---

## onScopeDispose()

Runs cleanup when the current scope stops. In a component's `setup()` that's on unmount, which makes
it the version of `onUnmounted` that also works in stores and tests.

```lua signature
function onScopeDispose(fn: () -> (), failSilently: boolean?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fn` | `() -> ()` | | the cleanup |
| `failSilently` | `boolean?` | `false` | skip the debug log when there's no scope |

> [!WARNING]
> Outside a scope it does nothing and the cleanup never runs. The only sign is a log when
> `Rivue.debug.enabled` is on.

### Example

```lua
local function useHeartbeat(callback: (dt: number) -> ())
	local conn = game:GetService("RunService").Heartbeat:Connect(callback)
	Rivue.onScopeDispose(function()
		conn:Disconnect()
	end)
end
```

---

[← Array helpers](array.md) · [API reference](../API.md) · [Render function →](render-function.md)
