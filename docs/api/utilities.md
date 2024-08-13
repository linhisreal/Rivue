# Utilities and Debugging

All examples assume `local Rivue = require(game.ReplicatedStorage.Rivue)`.

- [Rivue.dev](#rivuedev)
- [printTree()](#printtree)
- [debug.enabled](#debugenabled)
- [inspect()](#inspect)
- [prettyPrint()](#prettyprint)
- [assertInvariant()](#assertinvariant)
- [debug.measure()](#debugmeasure)
- [debug.log()](#debuglog)
- [debug.formatError()](#debugformaterror)
- [utils.debounce()](#utilsdebounce)
- [utils.throttle()](#utilsthrottle)
- [utils.nextFrame()](#utilsnextframe)
- [utils.useRaf()](#utilsuseraf)
- [utils.filterForClient()](#utilsfilterforclient)
- [utils.shallowEqual()](#utilsshallowequal)
- [utils.profiler](#utilsprofiler)
- [iterArray()](#iterarray)
- [hForParallel()](#hforparallel)
- [Types](#types)

---

## Rivue.dev

`true` when running in Studio. Rivue's own warnings (unknown props, bad keys, invalid props, ...)
only run when this is true.

- **Type**

  ```lua
  Rivue.dev: boolean
  ```

- **Example**

  ```lua
  if Rivue.dev then
  	print("running in Studio")
  end
  ```

---

## printTree()

Prints and returns the tree under a mounted vnode. `app:printTree()` does the same for a whole
app.

- **Type**

  ```lua
  function printTree(vnode: VNode): string
  ```

- **Example**

  ```lua
  local h = Rivue.h
  local root = h("Frame", { Name = "Root" }, { h("TextLabel", { Text = "Hi" }) })
  Rivue.createApp(root):mount(Instance.new("ScreenGui"))

  Rivue.printTree(root)
  --[[
  Frame "Root"
    TextLabel "TextLabel"
  ]]
  ```

---

## debug.enabled

Turns on verbose runtime logging: every vnode, mount, job and remote call. Off by default.

- **Type**

  ```lua
  Rivue.debug.enabled: boolean
  ```

- **Details**

  This is very noisy and slows rendering down, so only turn it on briefly to trace a problem.
  Studio warnings don't depend on it.

- **Example**

  ```lua
  Rivue.debug.enabled = true
  -- reproduce the problem, then
  Rivue.debug.enabled = false
  ```

---

## inspect()

Returns a readable string for any value. Reactive proxies are unwrapped, so you see the data and
not an empty proxy.

- **Type**

  ```lua
  function inspect(value: unknown, depth: number?): string -- depth defaults to 3
  ```

- **Example**

  ```lua
  local state = Rivue.reactive({ coins = 10, items = { "Sword" } })
  print(Rivue.inspect(state))
  --[[
  {
    items = {
      [1] = "Sword"
    }
    coins = 10
  }
  ]]
  ```

---

## prettyPrint()

Prints a value over several lines, with proxies unwrapped.

- **Type**

  ```lua
  function prettyPrint(value: unknown, options: {
  	indent: number?,
  	maxDepth: number?, -- default 10
  	unwrapProxies: boolean?, -- default true
  }?)
  ```

- **Example**

  ```lua
  local state = Rivue.reactive({ player = { name = "Ada", level = 3 } })
  Rivue.prettyPrint(state, { maxDepth = 2 })
  ```

---

## assertInvariant()

Errors in Studio when a condition is false. Does nothing in live servers.

- **Type**

  ```lua
  function assertInvariant(condition: boolean, message: string)
  ```

- **Example**

  ```lua
  local function setVolume(volume: number)
  	Rivue.assertInvariant(volume >= 0 and volume <= 1, "volume must be between 0 and 1")
  end
  ```

---

## debug.measure()

Runs a function and logs how long it took, when `debug.enabled` is on. Returns the function's
results.

- **Type**

  ```lua
  function debug.measure<R...>(name: string, fn: () -> R...): R...
  ```

- **Example**

  ```lua
  local total = Rivue.debug.measure("sum", function()
  	local sum = 0
  	for i = 1, 1e6 do
  		sum += i
  	end
  	return sum
  end)
  ```

---

## debug.log()

Prints a message tagged with a category, only when `debug.enabled` is on.

- **Type**

  ```lua
  function debug.log(category: string, message: string, data: unknown?)
  ```

- **Example**

  ```lua
  Rivue.debug.log("Shop", "Opened", { items = 12 })
  -- prints "[Rivue:DEBUG:Shop] Opened" followed by the data
  ```

---

## debug.formatError()

Builds an error message with a category and optional context.

- **Type**

  ```lua
  function debug.formatError(category: string, message: string, context: unknown?): string
  ```

- **Example**

  ```lua
  local message = Rivue.debug.formatError("Shop", "Item not found", { id = "sword" })
  warn(message)
  ```

---

## utils.debounce()

Returns a function that runs `fn` once calls stop for `ms` milliseconds.

- **Type**

  ```lua
  function utils.debounce<A...>(fn: (A...) -> (), ms: number): (A...) -> { cancel: () -> () }
  ```

- **Details**

  The last call's arguments are used. Values below 1 are treated as seconds. Calling the debounced
  function returns a handle whose `cancel()` drops the pending call.

- **Example**

  ```lua
  local save = Rivue.utils.debounce(function(text: string)
  	print("save", text)
  end, 500)

  save("H")
  save("He")
  save("Hey") -- only "Hey" is saved, 500 ms after the last call
  ```

---

## utils.throttle()

Returns a function that runs `fn` at most once every `ms` milliseconds.

- **Type**

  ```lua
  function utils.throttle<A...>(fn: (A...) -> (), ms: number): (A...) -> ()
  ```

- **Details**

  The first call runs right away. Calls during the wait are collapsed into one trailing call
  with the latest arguments.

- **Example**

  ```lua
  local UserInputService = game:GetService("UserInputService")

  local onMove = Rivue.utils.throttle(function(position: Vector3)
  	print("mouse at", position)
  end, 100)

  UserInputService.InputChanged:Connect(function(input)
  	if input.UserInputType == Enum.UserInputType.MouseMovement then
  		onMove(input.Position)
  	end
  end)
  ```

---

## utils.nextFrame()

Runs a function on the next Heartbeat.

- **Type**

  ```lua
  function utils.nextFrame(fn: () -> ())
  ```

- **Example**

  ```lua
  Rivue.utils.nextFrame(function()
  	print("one frame later")
  end)
  ```

---

## utils.useRaf()

Calls a function every RenderStepped until stopped.

- **Type**

  ```lua
  function utils.useRaf(fn: (deltaTime: number) -> ()): { stop: () -> () }
  ```

- **Details**

  Outside components, remember to call `stop()`. Inside components,
  [`onRenderStepped()`](roblox.md#onrenderstepped--onheartbeat--onstepped) stops on its own.

- **Example**

  ```lua
  local elapsed = 0
  local loop
  loop = Rivue.utils.useRaf(function(dt)
  	elapsed += dt
  	if elapsed > 2 then
  		loop.stop()
  	end
  end)
  ```

---

## utils.filterForClient()

Filters text with TextService before showing it to a player. Returns the original text if
filtering fails. It yields, and only works on the server.

- **Type**

  ```lua
  function utils.filterForClient(player: Player, text: string): string
  ```

- **Example**

  <!-- server -->
  ```lua
  -- Server
  local Players = game:GetService("Players")

  Players.PlayerAdded:Connect(function(player)
  	local safe = Rivue.utils.filterForClient(player, "user-written pet name")
  	player:SetAttribute("PetName", safe)
  end)
  ```

---

## utils.shallowEqual()

Compares two tables one level deep.

- **Type**

  ```lua
  function utils.shallowEqual(a: unknown, b: unknown): boolean
  ```

- **Example**

  ```lua
  print(Rivue.utils.shallowEqual({ a = 1 }, { a = 1 })) -- true
  print(Rivue.utils.shallowEqual({ a = {} }, { a = {} })) -- false, different inner tables
  ```

---

## utils.profiler

Simple named timers. Once started, effect runs are timed too.

- **Type**

  ```lua
  utils.profiler: {
  	active: boolean,
  	records: { [string]: number },
  	start: (self, name: string) -> (),
  	stop: (self, name: string) -> number?, -- elapsed seconds
  }
  ```

- **Details**

  `start()` turns `active` on, which also times every effect run. Set `active = false` when
  you're done.

- **Example**

  ```lua
  local profiler = Rivue.utils.profiler

  profiler:start("buildList")
  -- ... work ...
  local seconds = profiler:stop("buildList")
  print(`buildList took {seconds}s`)
  profiler.active = false
  ```

---

## iterArray()

An `ipairs`-style iterator that works on reactive arrays and tracks reads.

- **Type**

  ```lua
  function iterArray<T>(array: { T }): () -> (number?, T?)
  ```

- **Details**

  Same as `for i = 1, #list do`. Generalized iteration (`for i, v in list do`) also works on
  proxies.

- **Example**

  ```lua
  local list = Rivue.reactive({ "a", "b", "c" })

  for index, value in Rivue.iterArray(list) do
  	print(index, value)
  end
  ```

---

## hForParallel()

**Deprecated.** Use [`hFor()`](render-function.md#hfor) and set `key` in the mapper. It's still
here so existing code keeps working, and warns once in Studio.

- **Type**

  ```lua
  function hForParallel<T>(items: { T }, mapper: (item: T, index: number) -> VNode?, keyFn: ((item: T) -> unknown)?): { VNode }
  ```

- **Example**

  ```lua
  local h = Rivue.h
  local items = { { id = 1, name = "Sword" } }

  -- Before
  Rivue.hForParallel(items, function(item)
  	return h("TextLabel", { Text = item.name })
  end, function(item)
  	return item.id
  end)

  -- After
  Rivue.hFor(items, function(item)
  	return h("TextLabel", { key = item.id, Text = item.name })
  end)
  ```

---

## Types

Exported types, available as `Rivue.<Name>` in type annotations.

| Type | Description |
|------|-------------|
| `Ref<T>`, `ComputedRef<T>` | Refs |
| `MaybeRef<T>`, `MaybeRefOrGetter<T>` | A value or a ref (or a getter) |
| `WatchOptions`, `WatchSource<T>`, `WatchCallback<T>`, `WatchHandle`, `OnCleanup` | Watchers |
| `Effect`, `EffectScope`, `DebuggerEvent` | Effects |
| `VNode`, `Props`, `Child`, `ChildInput`, `Children` | Render functions |
| `ComponentDef`, `ComponentOptions`, `PropSchema`, `EmitsOptions`, `SetupContext`, `ComponentInstance` | Components |
| `TransitionConfig` | `transition` prop and Transition config |
| `Directive` | Custom directives |
| `App`, `AppOptions`, `Plugin` | Apps |
| `QueueOptions`, `JobHandle` | Scheduler |

- **Example**

  ```lua
  type Item = { id: number, name: string }

  local selected: Rivue.Ref<Item?> = Rivue.ref(nil :: Item?)

  local function useCount(initial: number): Rivue.Ref<number>
  	return Rivue.ref(initial)
  end
  ```
