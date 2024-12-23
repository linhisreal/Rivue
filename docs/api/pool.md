[Docs](../README.md) › [API](../API.md) › **Instance Pool**

# Instance Pool

**Learn it:** [Guide 9: Performance and debugging](../guide/09-performance-and-debugging.md)

Reuses Instances instead of destroying and creating them. Most apps only need the
[pooling options](application.md#pooling-options) of `createApp`. These functions are for tuning
and for using the pool directly. All examples assume
`local Rivue = require(game.ReplicatedStorage.Rivue)` and `local Pool = Rivue.pool`.

- [Pool.configure()](#poolconfigure)
- [Pool.warmup()](#poolwarmup)
- [Pool.acquire() / Pool.acquireMultiple()](#poolacquire--poolacquiremultiple)
- [Pool.release() / Pool.releaseMultiple()](#poolrelease--poolreleasemultiple)
- [Pool.clear()](#poolclear)
- [Pool.getStatistics()](#poolgetstatistics)
- [Pool.validateHealth()](#poolvalidatehealth)
- [Pool.setResetHandler()](#poolsetresethandler)
- [Pool.setEventHook()](#poolseteventhook)
- [Pool.createSnapshot() / Pool.restoreSnapshot()](#poolcreatesnapshot--poolrestoresnapshot)

---

## Pool.configure()

Sets how big the pool can get and how long unused Instances are kept.

- **Example**

  ```lua
  local Pool = Rivue.pool

  Pool.configure({ maxPoolSize = 200, maxTotalSize = 1000, defaultTTL = 60 })
  ```

- **Type**

  ```lua
  function Pool.configure(config: {
  	maxPoolSize: number?, -- per class (default 50)
  	maxTotalSize: number?, -- across all classes (default 500)
  	defaultTTL: number?, -- seconds an unused Instance is kept
  	enableMetrics: boolean?,
  	enableDebug: boolean?,
  	enableAutoWarmup: boolean?, -- create 5 the first time a class is acquired
  })
  ```

---

## Pool.warmup()

Creates Instances ahead of time, during loading, so the first time the UI needs them there's no
creation cost.

- **Example**

  ```lua
  local Pool = Rivue.pool

  -- Before a round with lots of damage numbers
  Pool.warmup("TextLabel", 100)
  ```

- **Type**

  ```lua
  function Pool.warmup(className: string, count: number)
  ```

---

## Pool.acquire() / Pool.acquireMultiple()

Gets ready-to-use Instances from the pool, creating new ones only when it's empty. Rivue does this
for you when the app uses pooling.

- **Example**

  ```lua
  local Pool = Rivue.pool
  local screen = Instance.new("ScreenGui")

  local label = Pool.acquire("TextLabel") :: TextLabel
  label.Text = "-25"
  label.Parent = screen
  ```

- **Type**

  ```lua
  function Pool.acquire(className: string): Instance
  function Pool.acquireMultiple(className: string, count: number): { Instance }
  ```

---

## Pool.release() / Pool.releaseMultiple()

Gives Instances back to the pool. They're reset to their defaults so the next user gets a clean one.

- **Example**

  ```lua
  local Pool = Rivue.pool

  local label = Pool.acquire("TextLabel") :: TextLabel
  label.Text = "-25"
  label.TextColor3 = Color3.new(1, 0, 0)

  task.delay(1, function()
  	Pool.release(label, { TextColor3 = true })
  end)
  ```

- **Details**

  A released Instance:
  - is unparented,
  - gets its common properties, attributes and name reset,
  - also gets each property in `touched` reset to its default.

  When the pool is full, it's destroyed instead.

- **Type**

  ```lua
  function Pool.release(instance: Instance, touched: { [string]: boolean }?)
  function Pool.releaseMultiple(instances: { Instance })
  ```

---

## Pool.clear()

Destroys pooled Instances of one class, or all of them, to free memory, for example when the player
leaves a UI-heavy area.

- **Example**

  ```lua
  local Pool = Rivue.pool

  Pool.clear("TextLabel") -- one class
  Pool.clear() -- everything
  ```

- **Type**

  ```lua
  function Pool.clear(className: string?)
  ```

---

## Pool.getStatistics()

How the pool is doing: how many Instances it holds, and how often it could reuse one instead of
creating it.

- **Example**

  ```lua
  local Pool = Rivue.pool

  local stats = Pool.getStatistics()
  print(`{stats.totalInstances} pooled, hit rate {math.floor(stats.hitRate * 100)}%`)
  ```

- **Type**

  ```lua
  function Pool.getStatistics(): {
  	totalInstances: number,
  	poolsByClass: { [string]: number },
  	hitRate: number, -- 0 to 1
  	metrics: { acquires: number, releases: number, creates: number, hits: number, misses: number, destroyed: number, evictions: number },
  }
  ```

---

## Pool.validateHealth()

Cleans out Instances something else destroyed while they sat in the pool. Returns `true` if it found
none.

- **Example**

  ```lua
  local Pool = Rivue.pool

  if not Pool.validateHealth() then
  	warn("pool had destroyed Instances, cleaned up")
  end
  ```

- **Type**

  ```lua
  function Pool.validateHealth(): boolean
  ```

---

## Pool.setResetHandler()

Your own clean-up for one class, run when an Instance of it goes back into the pool. Use it for
custom attributes or children the default reset doesn't know about.

- **Example**

  ```lua
  local Pool = Rivue.pool

  Pool.setResetHandler("ImageLabel", function(instance)
  	local image = instance :: ImageLabel
  	image.ImageRectOffset = Vector2.zero
  	image.ImageRectSize = Vector2.zero
  end)
  ```

- **Type**

  ```lua
  function Pool.setResetHandler(className: string, handler: (instance: Instance) -> ())
  ```

---

## Pool.setEventHook()

Lets you watch pool activity (acquire, release, clear, evict), for logging or metrics.

- **Example**

  ```lua
  local Pool = Rivue.pool

  Pool.setEventHook("onEvict", function(instance, reason)
  	print("evicted", instance.ClassName, reason)
  end)
  ```

- **Type**

  ```lua
  function Pool.setEventHook(
  	hook: "onAcquire" | "onRelease" | "onClear" | "onEvict",
  	handler: (...any) -> ()
  )

  -- onAcquire(instance, fromPool: boolean)
  -- onRelease(instance, pooled: boolean)
  -- onClear(totalCleared: number)
  -- onEvict(instance, reason: string)
  ```

---

## Pool.createSnapshot() / Pool.restoreSnapshot()

Saves what's in the pool and puts it back later. Mostly useful in tests.

- **Example**

  ```lua
  local Pool = Rivue.pool

  local snapshot = Pool.createSnapshot()
  -- ... a scene that churns through Instances ...
  Pool.restoreSnapshot(snapshot)
  ```

- **Type**

  ```lua
  function Pool.createSnapshot(): { [string]: { Instance } }
  function Pool.restoreSnapshot(snapshot: { [string]: { Instance } })
  ```

---

[← Remote](remote.md) · [API reference](../API.md) · [Utilities and Debugging →](utilities.md)
