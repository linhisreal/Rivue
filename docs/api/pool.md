# Instance Pool

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

Sets the pool's limits and options.

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

- **Example**

  ```lua
  local Pool = Rivue.pool

  Pool.configure({ maxPoolSize = 200, maxTotalSize = 1000, defaultTTL = 60 })
  ```

---

## Pool.warmup()

Creates Instances up front, so the first use doesn't pay for creating them.

- **Type**

  ```lua
  function Pool.warmup(className: string, count: number)
  ```

- **Example**

  ```lua
  local Pool = Rivue.pool

  -- Before a round with lots of damage numbers
  Pool.warmup("TextLabel", 100)
  ```

---

## Pool.acquire() / Pool.acquireMultiple()

Takes Instances from the pool, creating new ones if it's empty.

- **Type**

  ```lua
  function Pool.acquire(className: string): Instance
  function Pool.acquireMultiple(className: string, count: number): { Instance }
  ```

- **Example**

  ```lua
  local Pool = Rivue.pool
  local screen = Instance.new("ScreenGui")

  local label = Pool.acquire("TextLabel") :: TextLabel
  label.Text = "-25"
  label.Parent = screen
  ```

---

## Pool.release() / Pool.releaseMultiple()

Returns Instances to the pool.

- **Type**

  ```lua
  function Pool.release(instance: Instance, touched: { [string]: boolean }?)
  function Pool.releaseMultiple(instances: { Instance })
  ```

- **Details**

  A released Instance:
  - is unparented,
  - gets its common properties, attributes and name reset,
  - also gets each property in `touched` reset to its default.

  When the pool is full, it's destroyed instead.

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

---

## Pool.clear()

Destroys pooled Instances of one class, or of every class.

- **Type**

  ```lua
  function Pool.clear(className: string?)
  ```

- **Example**

  ```lua
  local Pool = Rivue.pool

  Pool.clear("TextLabel") -- one class
  Pool.clear() -- everything
  ```

---

## Pool.getStatistics()

Returns counts and hit rate.

- **Type**

  ```lua
  function Pool.getStatistics(): {
  	totalInstances: number,
  	poolsByClass: { [string]: number },
  	hitRate: number, -- 0 to 1
  	metrics: { acquires: number, releases: number, creates: number, hits: number, misses: number, destroyed: number, evictions: number },
  }
  ```

- **Example**

  ```lua
  local Pool = Rivue.pool

  local stats = Pool.getStatistics()
  print(`{stats.totalInstances} pooled, hit rate {math.floor(stats.hitRate * 100)}%`)
  ```

---

## Pool.validateHealth()

Removes destroyed Instances from the pool. Returns `true` if everything was healthy.

- **Type**

  ```lua
  function Pool.validateHealth(): boolean
  ```

- **Example**

  ```lua
  local Pool = Rivue.pool

  if not Pool.validateHealth() then
  	warn("pool had destroyed Instances, cleaned up")
  end
  ```

---

## Pool.setResetHandler()

Adds custom reset logic for a class, run when an Instance of that class is released.

- **Type**

  ```lua
  function Pool.setResetHandler(className: string, handler: (instance: Instance) -> ())
  ```

- **Example**

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

Observes pool activity.

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

- **Example**

  ```lua
  local Pool = Rivue.pool

  Pool.setEventHook("onEvict", function(instance, reason)
  	print("evicted", instance.ClassName, reason)
  end)
  ```

---

## Pool.createSnapshot() / Pool.restoreSnapshot()

Saves which Instances are pooled, and restores that state later.

- **Type**

  ```lua
  function Pool.createSnapshot(): { [string]: { Instance } }
  function Pool.restoreSnapshot(snapshot: { [string]: { Instance } })
  ```

- **Example**

  ```lua
  local Pool = Rivue.pool

  local snapshot = Pool.createSnapshot()
  -- ... a scene that churns through Instances ...
  Pool.restoreSnapshot(snapshot)
  ```
