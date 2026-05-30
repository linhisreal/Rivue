[Docs](../README.md) › [API](../API.md) › **Instance pool**

# Instance pool

**Learn it:** [Guide 15: Performance in depth](../guide/15-performance-in-depth.md#long-lists-and-many-instances)

Reuses Instances instead of destroying and creating them. Most apps only need the
[pooling options](application.md#pooling-options) of `createApp`; these functions are for tuning
and for using the pool directly. Examples assume
`local Rivue = require(game.ReplicatedStorage.RivueUI)` and `local Pool = Rivue.pool`.

---

## Pool.configure()

Sets how big the pool can get and how long unused Instances are kept.

```lua signature
function Pool.configure(config: PoolConfig)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `config.maxPoolSize` | `number` | `50` | Instances kept per class |
| `config.maxTotalSize` | `number` | `500` | Instances kept across all classes |
| `config.defaultTTL` | `number?` | none | seconds an unused Instance is kept before it's destroyed |
| `config.enableMetrics` | `boolean` | `true` | count hits, misses and evictions for `getStatistics()` |
| `config.enableDebug` | `boolean` | `false` | print pool activity |
| `config.enableAutoWarmup` | `boolean` | `false` | create 5 the first time a class is acquired |

### Example

```lua
local Pool = Rivue.pool

Pool.configure({ maxPoolSize = 200, maxTotalSize = 1000, defaultTTL = 60 })
```

---

## Pool.warmup()

Creates Instances ahead of time, during loading, so the first time the UI needs them there's no
creation cost.

```lua signature
function Pool.warmup(className: string, count: number)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `className` | `string` | | the class to create |
| `count` | `number` | | how many |

### Example

```lua
local Pool = Rivue.pool

Pool.warmup("TextLabel", 100) -- before a round with lots of damage numbers
```

---

## Pool.acquire() / Pool.acquireMultiple()

Takes ready-to-use Instances from the pool, creating new ones only when it's empty. Rivue does this
for you when the app uses pooling.

```lua signature
function Pool.acquire(className: string): Instance
function Pool.acquireMultiple(className: string, count: number): { Instance }
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `className` | `string` | | the class you want |
| `count` | `number` | | `acquireMultiple` only: how many |

> [!WARNING]
> A class that can't be created warns and gives you a Frame instead.

### Example

```lua
local Pool = Rivue.pool
local screen = Instance.new("ScreenGui")

local label = Pool.acquire("TextLabel") :: TextLabel
label.Text = "-25"
label.Parent = screen
```

---

## Pool.release() / Pool.releaseMultiple()

Gives Instances back. A released Instance is unparented, and its name, attributes and common
properties are reset, so the next user gets a clean one.

```lua signature
function Pool.release(instance: Instance, touched: { [string]: boolean }?)
function Pool.releaseMultiple(instances: { Instance })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `instance` | `Instance` | | the Instance to give back |
| `touched` | `{ [string]: boolean }?` | | more properties you changed, reset to their defaults too |
| `instances` | `{ Instance }` | | `releaseMultiple` only |

> [!NOTE]
> When the pool for that class is full, the Instance is destroyed instead.

### Example

```lua
local Pool = Rivue.pool

local label = Pool.acquire("TextLabel") :: TextLabel
label.Text = "-25"
label.TextColor3 = Color3.new(1, 0, 0)

task.delay(1, function()
	Pool.release(label, { TextColor3 = true })
end)
```

---

## Pool.clear()

Destroys pooled Instances of one class, or all of them, to free memory, for example when the player
leaves a UI-heavy area.

```lua signature
function Pool.clear(className: string?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `className` | `string?` | every class | the class to clear |

### Example

```lua
local Pool = Rivue.pool

Pool.clear("TextLabel") -- one class
Pool.clear() -- everything
```

---

## Pool.getStatistics()

How many Instances the pool holds, and how often it reused one instead of creating it.

```lua signature
function Pool.getStatistics(): PoolStatistics
```

**Returns** `{ totalInstances, poolsByClass, hitRate, metrics }`. `hitRate` goes from 0 to 1;
`metrics` counts acquires, releases, creates, hits, misses, destroyed and evictions, and stays at
zero with `enableMetrics` off.

### Example

```lua
local Pool = Rivue.pool

local stats = Pool.getStatistics()
print(`{stats.totalInstances} pooled, hit rate {math.floor(stats.hitRate * 100)}%`)
```

---

## Pool.validateHealth()

Removes Instances that something else destroyed while they sat in the pool.

```lua signature
function Pool.validateHealth(): boolean
```

**Returns** `true` if every pooled Instance was fine.

### Example

```lua
local Pool = Rivue.pool

if not Pool.validateHealth() then
	warn("pool had destroyed Instances, cleaned up")
end
```

---

## Pool.setResetHandler()

Your own cleanup for one class, run when an Instance of it goes back into the pool. Use it for
attributes or children the default reset doesn't know about.

```lua signature
function Pool.setResetHandler(className: string, handler: (instance: Instance) -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `className` | `string` | | the class it applies to |
| `handler` | `(instance) -> ()` | | runs after the default reset |

### Example

```lua
local Pool = Rivue.pool

Pool.setResetHandler("ImageLabel", function(instance)
	local image = instance :: ImageLabel
	image.ImageRectOffset = Vector2.zero
	image.ImageRectSize = Vector2.zero
end)
```

---

## Pool.setEventHook()

Watch pool activity for logging or metrics.

```lua signature
function Pool.setEventHook(hook: "onAcquire" | "onRelease" | "onClear" | "onEvict", handler: (...any) -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `hook` | `"onAcquire" \| "onRelease" \| "onClear" \| "onEvict"` | | which activity |
| `handler` | `(...any) -> ()` | | gets `(instance, fromPool)`, `(instance, pooled)`, `(totalCleared)` or `(instance, reason)` |

> [!NOTE]
> Any other hook name warns and is ignored.

### Example

```lua
local Pool = Rivue.pool

Pool.setEventHook("onEvict", function(instance, reason)
	print("evicted", instance.ClassName, reason)
end)
```

---

## Pool.createSnapshot() / Pool.restoreSnapshot()

Saves what's in the pool and puts it back later. Mostly for tests.

```lua signature
function Pool.createSnapshot(): { [string]: { Instance } }
function Pool.restoreSnapshot(snapshot: { [string]: { Instance } })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `snapshot` | `{ [string]: { Instance } }` | | from `createSnapshot()` |

### Example

```lua
local Pool = Rivue.pool

local snapshot = Pool.createSnapshot()
-- ... a scene that churns through Instances ...
Pool.restoreSnapshot(snapshot)
```

---

[← RivueRouter](router.md) · [API reference](../API.md) · [Utilities and debugging →](utilities.md)
