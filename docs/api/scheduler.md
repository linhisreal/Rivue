[Docs](../README.md) › [API](../API.md) › **Scheduler**

# Scheduler

**Learn it:** [Guide 7: Effects and animation](../guide/07-effects-and-animation.md)

When updates happen, and how to run code after them. All examples assume
`local Rivue = require(game.ReplicatedStorage.Rivue)`.

- [nextTick()](#nexttick)
- [queueJob()](#queuejob)
- [Update timing](#update-timing)

---

## nextTick()

Waits until Rivue has applied pending updates to the screen. Use it when you change state and then
need to read the updated Instances.

- **Example**

  Read an Instance right after changing state:

  ```lua
  local count = Rivue.ref(0)

  local Counter = Rivue.defineComponent({
  	name = "Counter",
  	render = function()
  		return h("TextLabel", { Text = tostring(count.value) })
  	end,
  })

  local screen = Instance.new("ScreenGui")
  Rivue.createApp(Counter):mount(screen)
  local label = screen:FindFirstChild("Counter") :: TextLabel

  count.value = 5
  print(label.Text) -- "0": updates are batched, not applied yet
  Rivue.nextTick()
  print(label.Text) -- "5"
  ```

- **Details**

  Changing state doesn't update the UI right away: renders are batched and run deferred. With a
  callback, `nextTick` runs it after that flush. Without one, it yields the current thread until
  then.

- **Type**

  ```lua
  function nextTick(callback: (() -> ())?)
  ```

---

## queueJob()

Runs a function on the next update. Queuing the same function again before then does nothing,
so it's a cheap way to batch expensive work.

- **Example**

  ```lua
  local dirty = {}

  local function flushSaves()
  	for key in dirty do
  		print("save", key)
  	end
  	table.clear(dirty)
  end

  local function markDirty(key: string)
  	dirty[key] = true
  	Rivue.queueJob(flushSaves) -- many calls this frame, one save
  end

  markDirty("volume")
  markDirty("sensitivity")
  ```

- **Details**

  - **Modes.**
    - `"micro"` (the default) runs deferred, in the same frame.
    - `"render"` runs on the next RenderStepped.
    - `"heartbeat"` runs on the next Heartbeat.
  - **Deduplicated.** Queuing the same function twice before it runs only runs it once.
  - **In components.** Jobs queued in `setup()` are cancelled when the component unmounts.

  `Rivue.scheduler.queueJob` is the same function without the automatic cancel.

- **Type**

  ```lua
  function queueJob(job: () -> (), options: { mode: ("micro" | "render" | "heartbeat")? }?): JobHandle

  type JobHandle = { cancel: () -> () }
  ```

---

## Update timing

The order in which work runs after you change state.

1. **`"sync"` watchers** run right away, inside the write.
2. **`"pre"` watchers and effects** (the default) run deferred, in the same frame.
3. **Component re-renders** run deferred and batched, **parents before children**. Each
   component renders at most once per batch, even if several of its dependencies changed.
4. **`onMounted`, directive `mounted` and enter transitions** run once the patch that created the
   Instances has finished.
5. **`"post"` watchers** run on the next Heartbeat.

- **Example**

  ```lua
  local count = Rivue.ref(0)

  Rivue.watch(count, function() print("sync") end, { flush = "sync" })
  Rivue.watch(count, function() print("pre") end)
  Rivue.watch(count, function() print("post") end, { flush = "post" })

  count.value = 1
  print("after write")
  -- sync, after write, pre, (next Heartbeat) post
  ```

---

[← Application](application.md) · [API reference](../API.md) · [Roblox Composables →](roblox.md)
