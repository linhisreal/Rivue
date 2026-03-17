[Docs](../README.md) › [API](../API.md) › **Utilities and Debugging**

# Utilities and Debugging

**Learn it:** [Guide 9: Performance and debugging](../guide/09-performance-and-debugging.md)

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

- **Example**

  ```lua
  if Rivue.dev then
  	print("running in Studio")
  end
  ```

- **Type**

  ```lua
  Rivue.dev: boolean
  ```

---

## printTree()

Prints what's on screen under a mounted element, as a tree. `app:printTree()` does the same for the
whole app.

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

- **Type**

  ```lua
  function printTree(vnode: VNode): string
  ```

---

## debug.enabled

Turns on detailed logging of everything Rivue does: every element, mount, update and remote call.
Very noisy, so it's off by default; switch it on briefly when you're hunting a bug.

- **Example**

  ```lua
  Rivue.debug.enabled = true
  -- reproduce the problem, then
  Rivue.debug.enabled = false
  ```

- **Details**

  This is very noisy and slows rendering down, so only turn it on briefly to trace a problem.
  Studio warnings don't depend on it.

- **Type**

  ```lua
  Rivue.debug.enabled: boolean
  ```

---

## inspect()

Turns any value into a readable string. Reactive tables show their data instead of an empty proxy,
which `print` would show.

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

- **Type**

  ```lua
  function inspect(value: unknown, depth: number?): string -- depth defaults to 3
  ```

---

## prettyPrint()

Prints a value across several lines, nicely indented, with reactive tables unwrapped.

- **Example**

  ```lua
  local state = Rivue.reactive({ player = { name = "Ada", level = 3 } })
  Rivue.prettyPrint(state, { maxDepth = 2 })
  ```

- **Type**

  ```lua
  function prettyPrint(value: unknown, options: {
  	indent: number?,
  	maxDepth: number?, -- default 10
  	unwrapProxies: boolean?, -- default true
  }?)
  ```

---

## assertInvariant()

Checks something you expect to always be true, and errors loudly in Studio if it isn't. Costs
nothing in live servers.

- **Example**

  ```lua
  local function setVolume(volume: number)
  	Rivue.assertInvariant(volume >= 0 and volume <= 1, "volume must be between 0 and 1")
  end
  ```

- **Type**

  ```lua
  function assertInvariant(condition: boolean, message: string)
  ```

---

## debug.measure()

Times a function and logs how long it took, when `debug.enabled` is on. Returns whatever the
function returned.

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

- **Type**

  ```lua
  function debug.measure<R...>(name: string, fn: () -> R...): R...
  ```

---

## debug.log()

Prints a message with a category tag, only when `debug.enabled` is on.

- **Example**

  ```lua
  Rivue.debug.log("Shop", "Opened", { items = 12 })
  -- prints "[Rivue:DEBUG:Shop] Opened" followed by the data
  ```

- **Type**

  ```lua
  function debug.log(category: string, message: string, data: unknown?)
  ```

---

## debug.formatError()

Builds a consistent error message with a category and optional details.

- **Example**

  ```lua
  local message = Rivue.debug.formatError("Shop", "Item not found", { id = "sword" })
  warn(message)
  ```

- **Type**

  ```lua
  function debug.formatError(category: string, message: string, context: unknown?): string
  ```

---

## utils.debounce()

Waits until calls stop for a moment before running. Use it for search boxes, so you search once the
player stops typing instead of on every key.

- **Example**

  ```lua
  local save = Rivue.utils.debounce(function(text: string)
  	print("save", text)
  end, 500)

  save("H")
  save("He")
  save("Hey") -- only "Hey" is saved, 500 ms after the last call
  ```

- **Details**

  The last call's arguments are used. Values below 1 are treated as seconds. Calling the debounced
  function returns a handle whose `cancel()` drops the pending call.

- **Type**

  ```lua
  function utils.debounce<A...>(fn: (A...) -> (), ms: number): (A...) -> { cancel: () -> () }
  ```

---

## utils.throttle()

Runs at most once per interval, however often it's called. Use it for things that fire every frame,
like mouse movement.

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

- **Details**

  The first call runs right away. Calls during the wait are collapsed into one trailing call
  with the latest arguments.

- **Type**

  ```lua
  function utils.throttle<A...>(fn: (A...) -> (), ms: number): (A...) -> ()
  ```

---

## utils.nextFrame()

Runs a function on the next Heartbeat.

- **Example**

  ```lua
  Rivue.utils.nextFrame(function()
  	print("one frame later")
  end)
  ```

- **Type**

  ```lua
  function utils.nextFrame(fn: () -> ())
  ```

---

## utils.useRaf()

Runs a function every frame until you stop it.

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

- **Details**

  Outside components, remember to call `stop()`. Inside components,
  [`onRenderStepped()`](roblox.md#onrenderstepped--onheartbeat--onstepped) stops on its own.

- **Type**

  ```lua
  function utils.useRaf(fn: (deltaTime: number) -> ()): { stop: () -> () }
  ```

---

## utils.filterForClient()

Filters text with TextService before showing it to a player. Returns the original text if
filtering fails. It yields, and only works on the server.

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

- **Type**

  ```lua
  function utils.filterForClient(player: Player, text: string): string
  ```

---

## utils.shallowEqual()

Tells you whether two tables have the same keys and values, one level deep.

- **Example**

  ```lua
  print(Rivue.utils.shallowEqual({ a = 1 }, { a = 1 })) -- true
  print(Rivue.utils.shallowEqual({ a = {} }, { a = {} })) -- false, different inner tables
  ```

- **Type**

  ```lua
  function utils.shallowEqual(a: unknown, b: unknown): boolean
  ```

---

## utils.profiler

Simple named timers for finding slow code. While it's running, effect runs are timed too.

- **Example**

  ```lua
  local profiler = Rivue.utils.profiler

  profiler:start("buildList")
  -- ... work ...
  local seconds = profiler:stop("buildList")
  print(`buildList took {seconds}s`)
  profiler.active = false
  ```

- **Details**

  `start()` turns `active` on, which also times every effect run. Set `active = false` when
  you're done.

- **Type**

  ```lua
  utils.profiler: {
  	active: boolean,
  	records: { [string]: number },
  	start: (self, name: string) -> (),
  	stop: (self, name: string) -> number?, -- elapsed seconds
  }
  ```

---

## iterArray()

Loops over a reactive list like `ipairs` would, which plain `ipairs` can't do with proxies.

- **Example**

  ```lua
  local list = Rivue.reactive({ "a", "b", "c" })

  for index, value in Rivue.iterArray(list) do
  	print(index, value)
  end
  ```

- **Details**

  Same as `for i = 1, #list do`. Generalized iteration (`for i, v in list do`) also works on
  proxies.

- **Type**

  ```lua
  function iterArray<T>(array: { T }): () -> (number?, T?)
  ```

---

## hForParallel()

**Deprecated.** Use [`hFor()`](render-function.md#hfor) and set `key` in the mapper. It's still
here so existing code keeps working, and warns once in Studio.

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

- **Type**

  ```lua
  function hForParallel<T>(items: { T }, mapper: (item: T, index: number) -> VNode?, keyFn: ((item: T) -> unknown)?): { VNode }
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

---

[← Instance Pool](pool.md) · [API reference](../API.md)
