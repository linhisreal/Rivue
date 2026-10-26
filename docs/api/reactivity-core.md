[Docs](../README.md) › [API](../API.md) › **Reactivity: Core**

# Reactivity: Core

**Learn it:** [Guide 2: State](../guide/02-state.md) · [Guide 7: Effects and animation](../guide/07-effects-and-animation.md)

The building blocks of state in Rivue. All examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
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

Holds a single value that the UI can follow: a number, a string, a table. Read and write it through
`.value`, and anything that read it updates when it changes.

- **Example**

  Coins the player has, shown in a label that updates by itself:

  ```lua
  local coins = Rivue.ref(0)

  local CoinLabel = Rivue.defineComponent({
  	name = "CoinLabel",
  	render = function()
  		return h("TextLabel", { Text = `{coins.value} coins` }) -- reading coins.value tracks it
  	end,
  })

  coins.value += 50 -- the label re-renders to "50 coins"
  ```

- **Details**

  Reading `.value` is tracked, and writing it triggers anything that read it. If the value is a
  table, it's made deeply reactive with [`reactive()`](#reactive). To avoid that, use
  [`shallowRef()`](reactivity-advanced.md#shallowref).

- **Type**

  ```lua
  function ref<T>(value: T): Ref<T>

  type Ref<T> = { value: T }
  ```

- **See also** [Guide 2: State](../guide/02-state.md)

---

## computed()

A value worked out from other state, like a total or a filtered list. It's cached and only
recalculated when something it used changes.

- **Example**

  A label that's worked out from other state, and only recalculated when that state changes:

  ```lua
  local inventory = Rivue.reactive({
  	{ name = "Sword", weight = 4 },
  	{ name = "Shield", weight = 6 },
  })
  local capacity = Rivue.ref(20)

  local load = Rivue.computed(function()
  	local total = 0
  	for i = 1, #inventory do
  		total += inventory[i].weight
  	end
  	return `{total} / {capacity.value} kg`
  end)

  print(load.value) -- "10 / 20 kg"
  Rivue.array.push(inventory, { name = "Potion", weight = 1 })
  print(load.value) -- "11 / 20 kg"
  ```

  A writable computed: a volume slider that shows 0–100 but stores 0–1:

  ```lua
  local volume = Rivue.ref(0.5)

  local percent = Rivue.computed({
  	get = function()
  		return math.round(volume.value * 100)
  	end,
  	set = function(value)
  		volume.value = math.clamp(value, 0, 100) / 100
  	end,
  })

  percent.value = 80
  print(volume.value) -- 0.8
  ```

- **Details**

  The getter runs lazily: only when `.value` is read, and only again after something it read has
  changed. Keep getters free of side effects.

- **Type**

  ```lua
  -- Readonly
  function computed<T>(getter: () -> T): ComputedRef<T>

  -- Writable
  function computed<T>(options: { get: () -> T, set: (value: T) -> () }): ComputedRef<T>
  ```

---

## reactive()

Makes a whole table reactive, nested tables included. You read and write fields directly, no
`.value`. Use it for objects you update field by field, like a player's stats.

- **Example**

  A player's stats as one reactive table: change fields directly, no `.value`:

  ```lua
  local stats = Rivue.reactive({
  	level = 1,
  	xp = 0,
  	equipped = { weapon = "Sword" },
  })

  local StatsPanel = Rivue.defineComponent({
  	name = "StatsPanel",
  	render = function()
  		return h("TextLabel", { Text = `Level {stats.level} · {stats.equipped.weapon}` })
  	end,
  })

  stats.xp += 120
  stats.equipped.weapon = "Bow" -- nested tables are reactive too
  ```

- **Details**

  The conversion is deep: nested tables are made reactive when you read them. Passing a proxy
  returns that same proxy.

  Luau has no `__pairs`/`__ipairs`, so `pairs()`, `ipairs()` and the `table.*` functions see an
  empty table. Iterate with `for k, v in proxy do` (or a numeric loop) and append with
  `list[#list + 1] = value`.

  To keep the original table out of the reactivity system, use
  [`toRaw()`](reactivity-advanced.md#toraw) or [`markRaw()`](reactivity-advanced.md#markraw).

- **Type**

  ```lua
  function reactive<T>(target: T): T
  ```

---

## readonly()

A view of some state that can be read but not changed. Hand it out when other code should see the
state but only your module should change it.

- **Example**

  A data module that lets everyone read the player's data, but only its own functions change it:

  ```lua
  local state = Rivue.reactive({ coins = 0 })

  local PlayerData = {
  	state = Rivue.readonly(state), -- what components see
  }

  function PlayerData.addCoins(amount: number)
  	state.coins += amount -- the only place coins change
  end

  PlayerData.addCoins(25)
  print(PlayerData.state.coins) -- 25
  PlayerData.state.coins = 999 -- warns in Studio and does nothing
  print(PlayerData.state.coins) -- 25
  ```

- **Details**

  Nested tables are readonly too. Writes are ignored and logged when debugging is on. Reads still
  track, so a readonly view of reactive state stays reactive.

- **Type**

  ```lua
  function readonly<T>(target: T): T
  ```

- **See also** [`shallowReadonly()`](reactivity-advanced.md#shallowreadonly)

---

## watchEffect()

Runs a function now, and again whenever anything it read changes. Use it for side effects that
follow state, like saving settings or playing a sound.

- **Example**

  Save settings whenever any of them changes. It runs once right away, then after every change:

  ```lua
  local settings = Rivue.reactive({ music = 0.8, sfx = 1, showFps = false })

  local stop = Rivue.watchEffect(function()
  	-- Reads every field, so a change to any of them re-runs this
  	Remote.fire("settings:save", {
  		music = settings.music,
  		sfx = settings.sfx,
  		showFps = settings.showFps,
  	})
  end)

  settings.music = 0.3 -- saved again
  stop() -- stop saving
  ```

  Clean up before the next run with `onCleanup`, here to follow whichever model is selected:

  ```lua
  local selected = Rivue.shallowRef(workspace)

  Rivue.watchEffect(function(onCleanup)
  	local conn = selected.value.ChildAdded:Connect(function(child)
  		print("added", child.Name)
  	end)
  	onCleanup(function()
  		conn:Disconnect() -- runs before the next run, and when stopped
  	end)
  end)
  ```

  Pause it while a menu is closed, and catch up when it opens:

  ```lua
  local count = Rivue.ref(0)
  local handle = Rivue.watchEffect(function()
  	print("badge shows", count.value)
  end)

  handle.pause()
  count.value = 5 -- nothing runs
  handle.resume() -- runs once with 5
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

---

## watchPostEffect()

`watchEffect()` that waits until after the UI has updated, on the next Heartbeat. Use it when you
need to see the new Instances.

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

- **Type**

  ```lua
  function watchPostEffect(effect: (onCleanup: OnCleanup) -> ()): WatchHandle
  ```

---

## watchSyncEffect()

`watchEffect()` that runs immediately on every change, with no batching. Rarely needed.

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

- **Type**

  ```lua
  function watchSyncEffect(effect: (onCleanup: OnCleanup) -> ()): WatchHandle
  ```

---

## watch()

Calls your function when specific state changes, with the new and old values. Use it when you care
exactly what changed, like loading a profile when the selected user changes.

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

---

## onWatcherCleanup()

Registers clean-up for the watcher that's running, which runs before it runs again or stops. Use it
to cancel the previous request or timer.

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

- **Details**

  The cleanup runs before the next run and when the watcher stops. It must be called
  synchronously inside the callback, not after a yield.

- **Type**

  ```lua
  function onWatcherCleanup(cleanupFn: () -> (), failSilently: boolean?)
  ```

---

[API reference](../API.md) · [Reactivity: Utilities →](reactivity-utilities.md)
