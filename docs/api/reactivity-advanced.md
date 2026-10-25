[Docs](../README.md) › [API](../API.md) › **Reactivity: Advanced**

# Reactivity: Advanced

**Learn it:** [Guide 2: State](../guide/02-state.md) · [Guide 9: Performance and debugging](../guide/09-performance-and-debugging.md)

Lower-level reactivity APIs for performance and library code. All examples assume
`local Rivue = require(game.ReplicatedStorage.Rivue)`.

- [shallowRef()](#shallowref)
- [triggerRef()](#triggerref)
- [customRef()](#customref)
- [shallowReactive()](#shallowreactive)
- [shallowReadonly()](#shallowreadonly)
- [isShallow()](#isshallow)
- [toRaw()](#toraw)
- [markRaw()](#markraw)
- [effect()](#effect)
- [effectScope()](#effectscope)
- [getCurrentScope()](#getcurrentscope)
- [onScopeDispose()](#onscopedispose)

---

## shallowRef()

Shallow version of [`ref()`](reactivity-core.md#ref): only replacing `.value` is tracked.

- **Type**

  ```lua
  function shallowRef<T>(value: T): Ref<T>
  ```

- **Details**

  The value is stored as is, without wrapping it in a proxy. Use it:
  - for large data you replace rather than edit,
  - for values that shouldn't be proxied: Instances, component definitions, data from the
    server.

- **Example**

  ```lua
  local state = Rivue.shallowRef({ count = 1 })

  state.value.count = 2 -- does NOT trigger anything
  state.value = { count = 2 } -- triggers
  ```

- **See also** [`triggerRef()`](#triggerref)

---

## triggerRef()

Forces effects that depend on a [`shallowRef`](#shallowref) to run. Use it after mutating the
inner value.

- **Type**

  ```lua
  function triggerRef<T>(ref: Ref<T>)
  ```

- **Example**

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

Creates a ref with explicit control over when it tracks and triggers.

- **Type**

  ```lua
  function customRef<T>(factory: (track: () -> (), trigger: () -> ()) -> {
  	get: () -> T,
  	set: (value: T) -> (),
  }): Ref<T>
  ```

- **Details**

  `factory` receives `track` and `trigger`. Call `track()` in `get` and `trigger()` when the
  value should be considered changed.

- **Example**

  A ref that only updates after writes stop for a while:

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

---

## shallowReactive()

Shallow version of [`reactive()`](reactivity-core.md#reactive): only top-level keys are
reactive.

- **Type**

  ```lua
  function shallowReactive<T>(target: T): T
  ```

- **Details**

  Nested tables are returned as they are, without proxies. Component props are shallow reactive.

- **Example**

  ```lua
  local state = Rivue.shallowReactive({ count = 1, nested = { bar = 2 } })

  state.count += 1 -- reactive
  state.nested.bar += 1 -- not reactive
  state.nested = { bar = 10 } -- reactive (top-level key)
  ```

---

## shallowReadonly()

Shallow version of [`readonly()`](reactivity-core.md#readonly): only top-level keys are
readonly.

- **Type**

  ```lua
  function shallowReadonly<T>(target: T): T
  ```

- **Example**

  ```lua
  local state = Rivue.shallowReadonly({ count = 1, nested = { bar = 2 } })

  state.count += 1 -- ignored
  state.nested.bar += 1 -- works
  ```

---

## isShallow()

Checks if a table is a proxy from `shallowReactive()` or `shallowReadonly()`.

- **Type**

  ```lua
  function isShallow(value: unknown): boolean
  ```

- **Example**

  ```lua
  print(Rivue.isShallow(Rivue.shallowReactive({}))) -- true
  print(Rivue.isShallow(Rivue.reactive({}))) -- false
  ```

---

## toRaw()

Returns the original table behind a proxy.

- **Type**

  ```lua
  function toRaw<T>(proxy: T): T
  ```

- **Details**

  Reading or writing the raw table bypasses tracking and triggering. It's also what to pass to
  `table.*` functions, which don't work through proxies.

- **Example**

  ```lua
  local original = { 3, 1, 2 }
  local list = Rivue.reactive(original)

  print(Rivue.toRaw(list) == original) -- true

  local sorted = table.clone(Rivue.toRaw(list))
  table.sort(sorted)
  ```

---

## markRaw()

Marks a table so it's never converted to a proxy.

- **Type**

  ```lua
  function markRaw<T>(value: T): T
  ```

- **Details**

  Use it for big static data, or for tables owned by another library, so they aren't wrapped
  when they end up inside reactive state.

- **Example**

  ```lua
  local itemDatabase = Rivue.markRaw({ sword = { damage = 10 } })
  local state = Rivue.reactive({ items = itemDatabase })

  print(Rivue.isReactive(state.items)) -- false
  ```

---

## effect()

The low-level reactive effect that watchers and component renders are built on.

- **Type**

  ```lua
  function effect(fn: () -> (), options: EffectOptions?): Effect

  type EffectOptions = {
  	scheduler: ((run: () -> ()) -> ())?, -- called instead of running on change
  	lazy: boolean?, -- don't run until effect.run() is called
  	onTrack: ((event: DebuggerEvent) -> ())?,
  	onTrigger: ((event: DebuggerEvent) -> ())?,
  	allowRecurse: boolean?,
  }

  type Effect = { run: () -> (), stop: (self: Effect) -> (), active: boolean }
  type DebuggerEvent = { target: unknown, key: unknown }
  ```

- **Details**

  Prefer [`watchEffect()`](reactivity-core.md#watcheffect) in app code. In a component's
  `setup()`, the effect stops on unmount.

  Unlike Vue's `effect()`, the first run is deferred to the next flush. With a `scheduler` it's
  passed to the scheduler right away, and with `lazy = true` nothing runs until you call
  `effect.run()`.

- **Example**

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

---

## effectScope()

Creates a scope that captures the effects created inside it (computeds, watchers) so they can be
stopped together.

- **Type**

  ```lua
  function effectScope(detached: boolean?): EffectScope

  type EffectScope = {
  	run: (self: EffectScope, fn: () -> unknown) -> unknown,
  	stop: (self: EffectScope) -> (),
  	active: boolean,
  }
  ```

- **Details**

  A scope created inside another scope is stopped with its parent unless `detached` is true.
  Each component's `setup()` runs in its own scope.

- **Example**

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

  -- stops the computed and both watchers
  scope:stop()
  ```

---

## getCurrentScope()

Returns the active effect scope, if any.

- **Type**

  ```lua
  function getCurrentScope(): EffectScope?
  ```

- **Example**

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

Registers a callback that runs when the active effect scope stops.

- **Type**

  ```lua
  function onScopeDispose(fn: () -> (), failSilently: boolean?)
  ```

- **Details**

  This is the composable-friendly version of `onUnmounted`. It works in a component's `setup()`
  (the component's scope stops on unmount) and inside `effectScope():run()`. Outside a scope it
  does nothing.

- **Example**

  ```lua
  local function useHeartbeat(callback: (dt: number) -> ())
  	local conn = game:GetService("RunService").Heartbeat:Connect(callback)
  	Rivue.onScopeDispose(function()
  		conn:Disconnect()
  	end)
  end
  ```

---

[← Array Helpers](array.md) · [API reference](../API.md) · [Render Function →](render-function.md)
