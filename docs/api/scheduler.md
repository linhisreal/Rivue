[Docs](../README.md) › [API](../API.md) › **Scheduler**

# Scheduler

**Learn it:** [Guide 7: Effects and animation](../guide/07-effects-and-animation.md)

When updates happen, and how to run code after them. Examples assume
`local Rivue = require(game.ReplicatedStorage.RivueUI)`.

---

## nextTick()

_yields without a callback_

Waits until Rivue has applied pending updates, including the ones that watchers and effects queue
while they run. Call it after changing state when you need to read the updated Instances.

```lua signature
function nextTick(callback: (() -> ())?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `callback` | `(() -> ())?` | | runs after the updates; without it, the current thread yields until then |

> [!WARNING]
> Without a callback it yields. Don't call it that way from a render function, a computed or
> anywhere else that can't yield.

### Example

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

---

## queueJob()

Runs a function on the next update. Queuing the same function again before then doesn't queue it
twice, so it's a cheap way to batch expensive work. Every call returns a handle to the queued job.

```lua signature
function queueJob(job: () -> (), options: { mode: ("micro" | "render" | "heartbeat")? }?): JobHandle
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `job` | `() -> ()` | | the function to run |
| `options.mode` | `"micro" \| "render" \| "heartbeat"` | `"micro"` | deferred in the same frame, on the next RenderStepped, or on the next Heartbeat |

**Returns** a `JobHandle`, `{ cancel: () -> () }`.

> [!NOTE]
> Jobs queued in `setup()` are cancelled when the component unmounts.
> `Rivue.scheduler.queueJob` is the same function without that.

> [!WARNING]
> If jobs keep queuing each other, the scheduler warns after 100 passes in one flush and drops the
> pending micro jobs and updates.

### Example

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

---

## Update timing

The order work runs in after you change state:

1. `"sync"` watchers, right away, inside the write.
2. `"pre"` watchers and effects (the default), deferred in the same frame.
3. Component re-renders, deferred and batched, parents before children. Each component renders at
   most once per batch.
4. `onMounted`, directive `mounted` hooks and enter transitions, once the patch that created the
   Instances has finished.
5. `"post"` watchers, on the next Heartbeat.

> [!WARNING]
> Updates that keep queuing more updates stop after a limit, with a warning about a possible
> infinite update loop. It usually means a render or watcher writes state it also reads.

### Example

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

[← Application](application.md) · [API reference](../API.md) · [Roblox composables →](roblox.md)
