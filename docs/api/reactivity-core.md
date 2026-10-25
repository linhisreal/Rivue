[Docs](../README.md) › [API](../API.md) › **Reactivity: Core**

# Reactivity: Core

**Learn it:** [Guide 2: State](../guide/02-state.md) · [Guide 7: Effects and animation](../guide/07-effects-and-animation.md)

The building blocks of state in Rivue. All examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h
```

- [ref()](#ref)
- [computed()](#computed)
- [reactive()](#reactive)
- [readonly()](#readonly)
- [watchEffect()](#watcheffect)
- [watchPostEffect()](#watchposteffect)
- [watchSyncEffect()](#watchsynceffect)
- [watch()](#watch)
- [onWatcherCleanup()](#onwatchercleanup)

---

## ref()

Takes an inner value and returns a reactive, mutable ref object, with a single property `.value`
that points to the inner value.

- **Type**

  ```lua
  function ref<T>(value: T): Ref<T>

  type Ref<T> = { value: T }
  ```

- **Details**

  Reading `.value` is tracked, and writing it triggers anything that read it. If the value is a
  table, it's made deeply reactive with [`reactive()`](#reactive). To avoid that, use
  [`shallowRef()`](reactivity-advanced.md#shallowref).

- **Example**

  ```lua
  local count = Rivue.ref(0)
  print(count.value) -- 0

  count.value += 1
  print(count.value) -- 1
  ```

- **See also** [Guide 2: State](../guide/02-state.md)

---

## computed()

Takes a getter function and returns a readonly ref for its result. It can also take an object with
`get` and `set` functions to make a writable ref.

- **Type**

  ```lua
  -- Readonly
  function computed<T>(getter: () -> T): ComputedRef<T>

  -- Writable
  function computed<T>(options: { get: () -> T, set: (value: T) -> () }): ComputedRef<T>
  ```

- **Details**

  The getter runs lazily: only when `.value` is read, and only again after something it read has
  changed. Keep getters free of side effects.

- **Example**

  Creating a readonly computed ref:

  ```lua
  local count = Rivue.ref(1)
  local plusOne = Rivue.computed(function()
  	return count.value + 1
  end)

  print(plusOne.value) -- 2
  ```

  Creating a writable computed ref:

  ```lua
  local count = Rivue.ref(1)
  local plusOne = Rivue.computed({
  	get = function()
  		return count.value + 1
  	end,
  	set = function(value)
  		count.value = value - 1
  	end,
  })

  plusOne.value = 1
  print(count.value) -- 0
  ```

---

## reactive()

Returns a reactive proxy of a table.

- **Type**

  ```lua
  function reactive<T>(target: T): T
  ```

- **Details**

  The conversion is deep: nested tables are made reactive when you read them. Passing a proxy
  returns that same proxy.

  Luau has no `__pairs`/`__ipairs`, so `pairs()`, `ipairs()` and the `table.*` functions see an
  empty table. Iterate with `for k, v in proxy do` (or a numeric loop) and append with
  `list[#list + 1] = value`.

  To keep the original table out of the reactivity system, use
  [`toRaw()`](reactivity-advanced.md#toraw) or [`markRaw()`](reactivity-advanced.md#markraw).

- **Example**

  ```lua
  local state = Rivue.reactive({ coins = 0, items = {} })
  state.coins += 10
  state.items[#state.items + 1] = "Sword"

  for index, item in state.items do
  	print(index, item)
  end
  ```

---

## readonly()

Takes a table (plain or reactive) or a ref and returns a readonly proxy to it.

- **Type**

  ```lua
  function readonly<T>(target: T): T
  ```

- **Details**

  Nested tables are readonly too. Writes are ignored and logged when debugging is on. Reads still
  track, so a readonly view of reactive state stays reactive.

- **Example**

  ```lua
  local original = Rivue.reactive({ count = 0 })
  local copy = Rivue.readonly(original)

  Rivue.watchEffect(function()
  	print(copy.count) -- tracked through the readonly view
  end)

  original.count += 1 -- triggers the effect
  copy.count += 1 -- ignored
  ```

- **See also** [`shallowReadonly()`](reactivity-advanced.md#shallowreadonly)

---

## watchEffect()

Runs a function immediately while tracking what it reads, and runs it again whenever any of that
changes.

- **Type**

  ```lua
  function watchEffect(effect: (onCleanup: OnCleanup) -> (), options: WatchEffectOptions?): WatchHandle

  type OnCleanup = (cleanupFn: () -> ()) -> ()

  type WatchEffectOptions = {
  	flush: ("pre" | "post" | "sync")?, -- default "pre"
  }

  type WatchHandle = {
  	stop: () -> (),
  	pause: () -> (),
  	resume: () -> (),
  } -- also callable: handle() stops it
  ```

- **Details**

  - **Cleanup.** `effect` receives `onCleanup`. The cleanup runs before the next run and when the
    watcher stops.
  - **Timing (`flush`).**
    - `"pre"` (the default) runs deferred, before component updates.
    - `"post"` runs on the next Heartbeat, after renders.
    - `"sync"` runs right away on every change.
  - **Stopping.** The returned handle stops the watcher when you call it.
    `handle.pause()` and `handle.resume()` suspend it; changes made while paused run once on
    resume. Watchers created in a component's `setup()` stop when the component unmounts.

  An effect that writes state it also reads doesn't re-trigger itself.

- **Example**

  ```lua
  local count = Rivue.ref(0)

  local stop = Rivue.watchEffect(function()
  	print(count.value) -- prints 0 right away
  end)

  count.value += 1 -- prints 1 (deferred)
  stop()
  ```

  Cleaning up a connection:

  ```lua
  local target = Rivue.shallowRef(workspace)

  Rivue.watchEffect(function(onCleanup)
  	local conn = target.value.ChildAdded:Connect(function(child)
  		print("added", child.Name)
  	end)
  	onCleanup(function()
  		conn:Disconnect()
  	end)
  end)
  ```

  Pausing and resuming:

  ```lua
  local count = Rivue.ref(0)
  local handle = Rivue.watchEffect(function()
  	print(count.value)
  end)

  handle.pause()
  count.value = 5 -- nothing printed
  handle.resume() -- prints 5
  ```

---

## watchPostEffect()

Alias of [`watchEffect()`](#watcheffect) with `flush = "post"`.

- **Type**

  ```lua
  function watchPostEffect(effect: (onCleanup: OnCleanup) -> ()): WatchHandle
  ```

- **Example**

  ```lua
  local open = Rivue.ref(false)
  local panel: Frame? = nil -- set by a template ref, for example

  Rivue.watchPostEffect(function()
  	if open.value and panel then
  		print(panel.AbsoluteSize) -- read after the UI updated
  	end
  end)
  ```

---

## watchSyncEffect()

Alias of [`watchEffect()`](#watcheffect) with `flush = "sync"`.

- **Type**

  ```lua
  function watchSyncEffect(effect: (onCleanup: OnCleanup) -> ()): WatchHandle
  ```

- **Example**

  ```lua
  local health = Rivue.ref(100)

  Rivue.watchSyncEffect(function()
  	if health.value <= 0 then
  		print("dead") -- runs inside the write, before the next line
  	end
  end)

  health.value = 0
  ```

---

## watch()

Watches one or more reactive sources and calls a callback when they change.

- **Type**

  ```lua
  function watch<T>(
  	source: WatchSource<T> | { WatchSource<unknown> },
  	callback: (newValue: T, oldValue: T?, onCleanup: OnCleanup) -> (),
  	options: WatchOptions?
  ): WatchHandle

  type WatchSource<T> = Ref<T> | () -> T | T -- T: a reactive table

  type WatchOptions = {
  	immediate: boolean?, -- default false
  	deep: (boolean | number)?, -- default false (true for reactive tables)
  	flush: ("pre" | "post" | "sync")?, -- default "pre"
  	once: boolean?, -- default false
  }
  ```

- **Details**

  Unlike [`watchEffect()`](#watcheffect), `watch()` only tracks the source, gives you the
  previous value, and is lazy: the callback doesn't run until the source changes (unless
  `immediate = true`).

  The source can be:
  - a ref (including a computed),
  - a getter function,
  - a reactive table (watched deeply),
  - a list of the above. The callback then receives lists of new and old values.

  Options:
  - **`immediate`**: run the callback right away. `oldValue` is `nil` the first time.
  - **`deep`**: traverse nested tables so nested changes count. A number limits how many levels
    deep it goes.
  - **`flush`**: same as [`watchEffect()`](#watcheffect).
  - **`once`**: stop after the first callback.

  The returned handle works like [`watchEffect()`](#watcheffect)'s.

- **Example**

  Watching a getter:

  ```lua
  local state = Rivue.reactive({ count = 0 })

  Rivue.watch(function()
  	return state.count
  end, function(count, prevCount)
  	print(prevCount, "->", count)
  end)
  ```

  Watching a ref, starting immediately:

  ```lua
  local userId = Rivue.ref(1)

  Rivue.watch(userId, function(id)
  	print("load profile", id)
  end, { immediate = true })
  ```

  Watching several sources:

  ```lua
  local hp = Rivue.ref(100)
  local maxHp = Rivue.ref(100)

  Rivue.watch({ hp, maxHp }, function(values, oldValues)
  	print(`{values[1]} / {values[2]}`)
  end)
  ```

  Deep watching and cleanup:

  ```lua
  local settings = Rivue.reactive({ audio = { volume = 1 } })

  Rivue.watch(settings, function(_, _, onCleanup)
  	local saving = task.delay(1, function()
  		print("save settings")
  	end)
  	onCleanup(function()
  		task.cancel(saving) -- a newer change replaces the pending save
  	end)
  end)

  settings.audio.volume = 0.5
  ```

---

## onWatcherCleanup()

Registers a cleanup for the watch callback or `watchEffect` that's currently running.

- **Type**

  ```lua
  function onWatcherCleanup(cleanupFn: () -> (), failSilently: boolean?)
  ```

- **Details**

  The cleanup runs before the next run and when the watcher stops. It must be called
  synchronously inside the callback, not after a yield.

- **Example**

  ```lua
  local query = Rivue.ref("")

  Rivue.watch(query, function(text)
  	local pending = task.delay(0.3, function()
  		print("search", text)
  	end)
  	Rivue.onWatcherCleanup(function()
  		task.cancel(pending)
  	end)
  end)
  ```

---

[API reference](../API.md) · [Reactivity: Utilities →](reactivity-utilities.md)
