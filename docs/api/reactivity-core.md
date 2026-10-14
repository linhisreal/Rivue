[Docs](../README.md) › [API](../API.md) › **Reactivity: Core**

# Reactivity: Core

**Learn it:** [Guide 2: State](../guide/02-state.md) · [Guide 7: Effects and animation](../guide/07-effects-and-animation.md)

State, derived values and watchers. Examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
local h = Rivue.h
```

---

## ref()

Holds one value that the UI can follow. Read and write it through `.value`; anything that read it
updates when it changes.

```lua signature
function ref<T>(value: T): Ref<T>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `T` | | the starting value |

**Returns** [`Ref<T>`](#type-ref), a table with one field, `value`.

### Example

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

### Details

- A table value is made deeply reactive with [`reactive()`](#reactive). Use
  [`shallowRef()`](reactivity-advanced.md#shallowref) to keep it as is.
- Setting `.value` to the value it already holds does nothing.

---

## computed()

A value derived from other state, like a total or a filtered list. It's cached and only recomputed
after something it read changes.

```lua signature
function computed<T>(getter: (previous: T?) -> T): ComputedRef<T>
function computed<T>(options: { get: (previous: T?) -> T, set: (value: T) -> () }): ComputedRef<T>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `getter` | `(previous: T?) -> T` | | works out the value; gets the last value it returned, `nil` the first time |
| `options.get` | `(previous: T?) -> T` | | the getter, for a writable computed |
| `options.set` | `(value: T) -> ()` | | runs when `.value` is assigned |

**Returns** `ComputedRef<T>`: read `.value`; assign it only when you passed `set`.

> [!NOTE]
> Assigning `.value` on a computed without `set` is ignored. It only logs when
> `Rivue.debug.enabled` is on.

### Example

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

A volume slider that shows 0 to 100 but stores 0 to 1:

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

### Details

- The getter only runs when `.value` is read. Keep it free of side effects.
- Effects, watchers and components that read a computed re-run only when its value changes, as in
  Vue 3.5. A getter that runs again and returns an equal value doesn't make anything re-run.
- Returning `previous` when nothing you care about changed, as in Vue 3.4, keeps a new table from
  counting as a change, so a `watch` on the computed doesn't fire and nothing re-renders.

```lua
local items = Rivue.reactive({ 1, 2, 3 })
local evens = Rivue.computed(function(previous)
	local out = {}
	for i = 1, #items do
		if items[i] % 2 == 0 then
			table.insert(out, items[i])
		end
	end
	if previous and #previous == #out then
		for i, v in out do
			if previous[i] ~= v then
				return out
			end
		end
		return previous
	end
	return out
end)
```

---

## reactive()

Makes a table reactive, nested tables included. Read and write its fields directly, with no
`.value`.

```lua signature
function reactive<T>(target: T): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `target` | `T` | | the table to wrap; it stays the storage behind the proxy |

**Returns** a proxy of `target`. Passing a proxy returns that same proxy.

> [!WARNING]
> Luau has no `__pairs`, so `pairs()`, `ipairs()`, `next()` and the `table.*` functions see an
> empty table. Loop with `for k, v in proxy do` or `for i = 1, #proxy do`, and change lists with
> [`Rivue.array`](array.md).

### Example

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

### Details

- Nested tables are made reactive when you first read them.
- To keep a table out of reactivity, use [`toRaw()`](reactivity-advanced.md#toraw) or
  [`markRaw()`](reactivity-advanced.md#markraw).

---

## readonly()

A read-only view of some state, for when other code should see it but only your module should
change it.

```lua signature
function readonly<T>(target: T): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `target` | `T` | | a plain or reactive table |

**Returns** a read-only proxy. Reads still track, so a view of reactive state stays reactive.

> [!NOTE]
> Writes are ignored without an error. In Studio they're logged only when `Rivue.debug.enabled`
> is on.

### Example

```lua
local state = Rivue.reactive({ coins = 0 })

local PlayerData = {
	state = Rivue.readonly(state), -- what components see
}

function PlayerData.addCoins(amount: number)
	state.coins += amount -- the only place coins change
end

PlayerData.addCoins(25)
PlayerData.state.coins = 999 -- ignored
print(PlayerData.state.coins) -- 25
```

### Details

- Nested tables are read-only too. For the top level only, use
  [`shallowReadonly()`](reactivity-advanced.md#shallowreadonly).

---

## watchEffect()

Runs a function now, and again whenever anything it read changes. For side effects that follow
state, like saving settings.

```lua signature
function watchEffect(effect: (onCleanup: OnCleanup) -> (), options: WatchEffectOptions?): WatchHandle
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `effect` | `(onCleanup) -> ()` | | the function to run; `onCleanup(fn)` registers cleanup for this run |
| `options.flush` | `"pre" \| "post" \| "sync"` | `"pre"` | when it runs: before re-renders, on the next Heartbeat after them, or inside the write |

**Returns** a [`WatchHandle`](#type-watchhandle).

> [!NOTE]
> Watchers made in a component's `setup()` stop when it unmounts. Anywhere else, keep the handle
> and stop it yourself, or run it inside an [`effectScope()`](reactivity-advanced.md#effectscope).

### Example

```lua
local settings = Rivue.reactive({ music = 0.8, sfx = 1, showFps = false })

local stop = Rivue.watchEffect(function()
	-- reads every field, so a change to any of them runs this again
	Remote.fire("settings:save", {
		music = settings.music,
		sfx = settings.sfx,
		showFps = settings.showFps,
	})
end)

settings.music = 0.3 -- saved again
stop()
```

Following whichever model is selected, and disconnecting from the old one:

```lua
local selected = Rivue.shallowRef(workspace)

Rivue.watchEffect(function(onCleanup)
	local conn = selected.value.ChildAdded:Connect(function(child)
		print("added", child.Name)
	end)
	onCleanup(function()
		conn:Disconnect() -- before the next run, and when stopped
	end)
end)
```

Paused while a menu is closed:

```lua
local count = Rivue.ref(0)
local handle = Rivue.watchEffect(function()
	print("badge shows", count.value)
end)

handle.pause()
count.value = 5 -- nothing runs
handle.resume() -- runs once with 5
```

### Details

- Changes made while paused run once on `resume()`.
- An effect that writes state it also reads doesn't trigger itself again.

---

## watchPostEffect()

[`watchEffect()`](#watcheffect) with `flush = "post"`: it runs on the next Heartbeat, after the UI
has updated. Use it to read the new Instances.

```lua signature
function watchPostEffect(effect: (onCleanup: OnCleanup) -> ()): WatchHandle
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `effect` | `(onCleanup) -> ()` | | the function to run |

**Returns** a [`WatchHandle`](#type-watchhandle).

### Example

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

[`watchEffect()`](#watcheffect) with `flush = "sync"`: it runs inside every write, with no
batching. Rarely needed.

```lua signature
function watchSyncEffect(effect: (onCleanup: OnCleanup) -> ()): WatchHandle
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `effect` | `(onCleanup) -> ()` | | the function to run |

**Returns** a [`WatchHandle`](#type-watchhandle).

### Example

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

Calls a function when a specific source changes, with the new and old values. Reach for it when
you care what changed, like loading a profile when the selected user changes.

```lua signature
function watch<T>(
	source: WatchSource<T> | { WatchSource<unknown> },
	callback: (newValue: T, oldValue: T?, onCleanup: OnCleanup) -> (),
	options: WatchOptions?
): WatchHandle
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source` | `WatchSource<T>` | | a ref or computed, a getter, a reactive table, or a list of these |
| `callback` | `(new, old, onCleanup) -> ()` | | runs after the source changes; gets lists of values for a list source |
| `options.immediate` | `boolean` | `false` | also run the callback straight away, with `oldValue` as `nil` |
| `options.deep` | `boolean \| number` | `false`, `true` for a reactive table | count changes inside nested tables; a number limits the depth |
| `options.flush` | `"pre" \| "post" \| "sync"` | `"pre"` | as in [`watchEffect()`](#watcheffect) |
| `options.once` | `boolean` | `false` | stop after the first callback |

**Returns** a [`WatchHandle`](#type-watchhandle).

> [!NOTE]
> Unlike [`watchEffect()`](#watcheffect), it only tracks `source`, and the callback doesn't run
> until the source changes unless `immediate` is set. It stops on unmount only when made in
> `setup()`.

### Example

```lua
local state = Rivue.reactive({ count = 0 })

Rivue.watch(function()
	return state.count
end, function(count, prevCount)
	print(prevCount, "->", count)
end)
```

Starting straight away:

```lua
local userId = Rivue.ref(1)

Rivue.watch(userId, function(id)
	print("load profile", id)
end, { immediate = true })
```

Several sources at once:

```lua
local hp = Rivue.ref(100)
local maxHp = Rivue.ref(100)

Rivue.watch({ hp, maxHp }, function(values, oldValues)
	print(`{values[1]} / {values[2]}`)
end)
```

A reactive table, saved a second after the last change:

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

Registers cleanup for the watcher callback that's running, such as cancelling a pending request
or timer. It runs before the callback runs again and when the watcher stops.

```lua signature
function onWatcherCleanup(cleanupFn: () -> (), failSilently: boolean?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `cleanupFn` | `() -> ()` | | the cleanup |
| `failSilently` | `boolean` | `false` | don't warn when there's no watcher to attach to |

> [!WARNING]
> Call it before any yield in the callback. After a yield there's no running watcher, so it warns
> and the cleanup never runs.

### Example

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

## getCurrentWatcher()

Returns the effect of the watcher whose callback (or `watchEffect` body) is running, as in Vue 3.5,
so a watcher can stop or pause itself. Anywhere else it returns `nil`.

```lua signature
function getCurrentWatcher(): Effect?
```

> [!WARNING]
> Like `onWatcherCleanup()`, it only works before the first yield in the callback.

### Example

```lua
local score = Rivue.ref(0)

Rivue.watch(score, function(value)
	if value >= 100 then
		print("goal reached")
		Rivue.getCurrentWatcher():stop()
	end
end, { flush = "sync" })

score.value = 100 -- prints once, then the watcher stops
score.value = 200 -- nothing
```

---

## onEffectCleanup()

Registers cleanup for the effect that's running, as in Vue 3.5. It runs before the effect runs
again and when it stops.

```lua signature
function onEffectCleanup(cleanupFn: () -> (), failSilently: boolean?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `cleanupFn` | `() -> ()` | | the cleanup |
| `failSilently` | `boolean` | `false` | don't warn when there's no effect to attach to |

> [!WARNING]
> Like `onWatcherCleanup()`, it warns and does nothing when called after a yield or outside an
> effect.

### Example

```lua
local target = Rivue.ref(1)

Rivue.watchEffect(function()
	local id = target.value
	local timer = task.delay(1, function()
		print("still showing", id)
	end)
	Rivue.onEffectCleanup(function()
		task.cancel(timer)
	end)
end)
```

### Details

- Works in [`effect()`](reactivity-advanced.md#effect), `watchEffect()` and computeds. Inside a
  `watch()` callback it does the same as `onWatcherCleanup()`.

---

## type Ref

```lua signature
type Ref<T> = { value: T }
```

---

## type WatchHandle

```lua signature
type WatchHandle = {
	stop: () -> (),
	pause: () -> (),
	resume: () -> (),
}
```

Calling the handle itself, `handle()`, also stops the watcher.

---

## type WatchSource

```lua signature
type WatchSource<T> = Ref<T> | () -> T | T -- T: a reactive table
```

---

## type OnCleanup

```lua signature
type OnCleanup = (cleanupFn: () -> ()) -> ()
```

---

[API reference](../API.md) · [Reactivity: Utilities →](reactivity-utilities.md)
