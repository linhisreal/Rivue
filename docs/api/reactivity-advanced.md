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

A ref that only notices when you replace `.value`, not when you change things inside it. Use it for
big data you swap out wholesale, like a server response or a 1,000-row table.

- **Example**

  ```lua
  local state = Rivue.shallowRef({ count = 1 })

  state.value.count = 2 -- doesn't trigger anything
  state.value = { count = 2 } -- triggers
  ```

- **Details**

  The value is stored as is, without wrapping it in a proxy. Use it:
  - for large data you replace rather than edit,
  - for values that shouldn't be proxied: Instances, component definitions, data from the
    server.

- **Type**

  ```lua
  function shallowRef<T>(value: T): Ref<T>
  ```

- **See also** [`triggerRef()`](#triggerref)

---

## triggerRef()

Tells everything using a [`shallowRef`](#shallowref) to update, after you changed what's inside it
without replacing `.value`.

- **Example**

  ```lua
  local inventory = Rivue.shallowRef({ "Sword" })

  Rivue.watchEffect(function()
  	print(#inventory.value)
  end)

  table.insert(inventory.value, "Shield") -- not tracked
  Rivue.triggerRef(inventory) -- prints 2
  ```

- **Type**

  ```lua
  function triggerRef<T>(ref: Ref<T>)
  ```

---

## customRef()

Builds a ref with your own rules for when it updates. A common use is a debounced value that only
updates after the player stops typing.

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

- **Details**

  `factory` receives `track` and `trigger`. Call `track()` in `get` and `trigger()` when the
  value should be considered changed.

- **Type**

  ```lua
  function customRef<T>(factory: (track: () -> (), trigger: () -> ()) -> {
  	get: () -> T,
  	set: (value: T) -> (),
  }): Ref<T>
  ```

---

## shallowReactive()

Like [`reactive()`](reactivity-core.md#reactive), but only the top-level keys are watched. Nested
tables are left as plain tables.

- **Example**

  ```lua
  local state = Rivue.shallowReactive({ count = 1, nested = { bar = 2 } })

  state.count += 1 -- reactive
  state.nested.bar += 1 -- not reactive
  state.nested = { bar = 10 } -- reactive (top-level key)
  ```

- **Details**

  Nested tables are returned as they are, without proxies. Component props are shallow reactive.

- **Type**

  ```lua
  function shallowReactive<T>(target: T): T
  ```

---

## shallowReadonly()

Like [`readonly()`](reactivity-core.md#readonly), but only the top-level keys are protected.

- **Example**

  ```lua
  local state = Rivue.shallowReadonly({ count = 1, nested = { bar = 2 } })

  state.count += 1 -- ignored
  state.nested.bar += 1 -- works
  ```

- **Type**

  ```lua
  function shallowReadonly<T>(target: T): T
  ```

---

## isShallow()

Tells you whether a table came from `shallowReactive()` or `shallowReadonly()`.

- **Example**

  ```lua
  print(Rivue.isShallow(Rivue.shallowReactive({}))) -- true
  print(Rivue.isShallow(Rivue.reactive({}))) -- false
  ```

- **Type**

  ```lua
  function isShallow(value: unknown): boolean
  ```

---

## toRaw()

Gets the plain table behind a reactive one. Use it to read or pass data without tracking, for
example when sending state to the server.

- **Example**

  ```lua
  local original = { 3, 1, 2 }
  local list = Rivue.reactive(original)

  print(Rivue.toRaw(list) == original) -- true

  local sorted = table.clone(Rivue.toRaw(list))
  table.sort(sorted)
  ```

- **Details**

  Reading or writing the raw table bypasses tracking and triggering. It's also what to pass to
  `table.*` functions, which don't work through proxies.

- **Type**

  ```lua
  function toRaw<T>(proxy: T): T
  ```

---

## markRaw()

Tells Rivue to never make a table reactive. Use it for things that shouldn't be watched, like
Instances, class objects or large static data.

- **Example**

  ```lua
  local itemDatabase = Rivue.markRaw({ sword = { damage = 10 } })
  local state = Rivue.reactive({ items = itemDatabase })

  print(Rivue.isReactive(state.items)) -- false
  ```

- **Details**

  Use it for big static data, or for tables owned by another library, so they aren't wrapped
  when they end up inside reactive state.

- **Type**

  ```lua
  function markRaw<T>(value: T): T
  ```

---

## effect()

The low-level building block under watchers and component renders: a function that re-runs when what
it read changes. Prefer [`watchEffect()`](reactivity-core.md#watcheffect) in app code.

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

- **Details**

  In a component's `setup()`, the effect stops on unmount.

  Unlike Vue's `effect()`, the first run is deferred to the next flush. With a `scheduler` it's
  passed to the scheduler right away, and with `lazy = true` nothing runs until you call
  `effect.run()`.

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

---

## effectScope()

A container that collects the computeds and watchers created inside it, so you can stop them all at
once. Useful for state that lives outside components.

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

- **Details**

  A scope created inside another scope is stopped with its parent unless `detached` is true.
  Each component's `setup()` runs in its own scope.

- **Type**

  ```lua
  function effectScope(detached: boolean?): EffectScope

  type EffectScope = {
  	run: (self: EffectScope, fn: () -> unknown) -> unknown,
  	stop: (self: EffectScope) -> (),
  	active: boolean,
  }
  ```

---

## getCurrentScope()

The effect scope that's active right now, if any.

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

- **Type**

  ```lua
  function getCurrentScope(): EffectScope?
  ```

---

## onScopeDispose()

Runs your clean-up when the current scope stops. Inside a component, that's when it unmounts, which
makes it the composable-friendly version of `onUnmounted`.

- **Example**

  ```lua
  local function useHeartbeat(callback: (dt: number) -> ())
  	local conn = game:GetService("RunService").Heartbeat:Connect(callback)
  	Rivue.onScopeDispose(function()
  		conn:Disconnect()
  	end)
  end
  ```

- **Details**

  It works in a component's `setup()`
  (the component's scope stops on unmount) and inside `effectScope():run()`. Outside a scope it
  does nothing.

- **Type**

  ```lua
  function onScopeDispose(fn: () -> (), failSilently: boolean?)
  ```

---

[← Array helpers](array.md) · [API reference](../API.md) · [Render function →](render-function.md)
