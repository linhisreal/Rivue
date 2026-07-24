[Docs](../README.md) › [API](../API.md) › **Utilities and debugging**

# Utilities and debugging

**Learn it:** [Guide 9: Performance and debugging](../guide/09-performance-and-debugging.md)

All examples assume `local Rivue = require(game.ReplicatedStorage.RivueUI)`.

- [Rivue.dev](#rivuedev)
- [Rivue.version](#rivueversion)
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
- [testing.trigger()](#testingtrigger)
- [testing.setInteraction()](#testingsetinteraction)
- [testing.render()](#testingrender)
- [testing.click() and testing.typeInto()](#testingclick-and-testingtypeinto)
- [story()](#story)
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

## Rivue.version

The version of Rivue that's running, such as `"0.9.0-rc.2"`. RivueRemote and RivueRouter have their
own, in `Remote.version` and `Router.version`.

- **Example**

  ```lua
  print(`Running Rivue {Rivue.version}`)
  ```

- **Type**

  ```lua
  Rivue.version: string
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
Off by default.

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

## testing.trigger()

Calls an element's event handler as if the event fired. Scripts can't fire engine events like
`Activated` or `FocusLost`, so tests use this to click buttons and submit text boxes.

- **Example**

  ```lua
  local h = Rivue.h

  local Counter = Rivue.defineComponent({
  	name = "Counter",
  	setup = function()
  		return { count = Rivue.ref(0) }
  	end,
  	render = function(ctx)
  		return h("TextButton", {
  			Name = "Add",
  			Text = `Clicked {ctx.count}`,
  			onClick = function()
  				ctx.count += 1
  			end,
  		})
  	end,
  })

  local screen = Instance.new("Frame")
  local app = Rivue.mount(Counter, screen)
  local button = screen:FindFirstChild("Add") :: TextButton

  Rivue.testing.trigger(button, "onClick")
  Rivue.nextTick() -- re-renders are batched, wait for them
  assert(button.Text == "Clicked 1")

  app:unmount()
  ```

- **Details**

  `key` is the event prop as written in `h()`: `"onClick"`, `"onFocusLost"`, `"onTextChanged"`. Extra
  arguments are passed to the handler, so `trigger(box, "onFocusLost", true)` is pressing Enter.
  It calls the handler the element has now, after any re-renders. It errors if the element has no
  handler for `key`, which catches a test clicking the wrong thing.

  Input that comes from `UserInputService` (`vClickOutside`, `vDrag`, the input-type composables)
  can't be faked this way. Test the logic behind it in a composable instead, see
  [Guide 16](../guide/16-testing-ui.md).

- **Type**

  ```lua
  function testing.trigger(element: Instance, key: string, ...: any)
  ```

---

## testing.setInteraction()

Turns an element's hover, pressed or selected state on or off, as if the player did it. Use it to
test [style class variants](application.md#appstyles), since scripts can't move the mouse.

- **Example**

  ```lua
  local hoverColor = Color3.fromRGB(200, 200, 200)

  local Button = Rivue.defineComponent({
  	name = "HoverButton",
  	styles = {
  		button = {
  			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
  			hover = { BackgroundColor3 = hoverColor },
  		},
  	},
  	render = function()
  		return h("TextButton", { Name = "Play", class = "button" })
  	end,
  })

  local screen = Instance.new("Frame")
  local app = Rivue.mount(Button, screen)
  local button = screen:FindFirstChild("Play") :: TextButton

  Rivue.testing.setInteraction(button, "hover", true)
  assert(button.BackgroundColor3 == hoverColor)

  app:unmount()
  ```

- **Details**

  `state` is `"hover"`, `"pressed"` or `"selected"`. It does nothing on elements whose classes have
  no state variants. The change applies straight away,
  without waiting for `nextTick()`.

- **Type**

  ```lua
  function testing.setInteraction(element: Instance, state: "hover" | "pressed" | "selected", on: boolean)
  ```


## testing.render()

Mounts a component for a test and gives you ways to find things by what the player would see,
the way Testing Library does on the web.

- **Example**

  ```lua
  local Counter = Rivue.defineComponent({
  	name = "Counter",
  	props = { start = { type = "number", default = 0 } },
  	setup = function(props)
  		local count = Rivue.ref(props.start)
  		return {
  			count = count,
  			add = function()
  				count.value += 1
  			end,
  		}
  	end,
  	render = function(ctx)
  		return h("Frame", nil, {
  			h("TextLabel", { Text = `Count: {ctx.count}` }),
  			h("TextButton", { Text = "Add", onActivated = ctx.add }),
  		})
  	end,
  })

  local screen = Rivue.testing.render(Counter, { start = 5 })
  Rivue.testing.click(screen.getByText("Add"))
  assert(screen.queryByText("Count: 6"), "the count went up")
  screen.unmount()
  ```

- **Details**

  - The second argument is the component's props. A vnode works too: `render(h(Counter))`.
  - `getByText` finds the one TextLabel, TextButton or TextBox showing that text, and errors if
    there's none or more than one. `queryByText` returns nil instead of erroring when there's
    none. `getAllByText` returns every match.
  - A text match can be a function: `getAllByText(function(text) return text:find("Coins") end)`.
  - `getByName` and `queryByName` find by Instance `Name`.
  - `unmount()` unmounts and destroys the container.

- **Type**

  ```lua
  function testing.render(component: ComponentDef | VNode, props: { [string]: any }?): {
  	container: Instance,
  	app: App,
  	getByText: (text: string | (string) -> boolean) -> Instance,
  	queryByText: (text: string | (string) -> boolean) -> Instance?,
  	getAllByText: (text: string | (string) -> boolean) -> { Instance },
  	getByName: (name: string) -> Instance,
  	queryByName: (name: string) -> Instance?,
  	unmount: () -> (),
  }
  ```

---

## testing.click() and testing.typeInto()

Act like the player, then wait for the re-render, so the next line can check the result.

- **Example**

  ```lua
  local NameForm = Rivue.defineComponent({
  	name = "NameForm",
  	setup = function()
  		return { name = Rivue.ref("") }
  	end,
  	render = function(ctx)
  		return h("Frame", nil, {
  			h("TextBox", { Name = "NameBox", model = "name" }),
  			h("TextLabel", { Text = `Hi {ctx.name}` }),
  		})
  	end,
  })

  local screen = Rivue.testing.render(NameForm)
  Rivue.testing.typeInto(screen.getByName("NameBox"), "Ana")
  assert(screen.queryByText("Hi Ana"))
  screen.unmount()
  ```

- **Details**

  - `click` runs the button's `onClick`, `onActivated` or `onMouseButton1Click` handler, and
    errors if it has none.
  - `typeInto` sets the TextBox's `Text`, then runs its `onFocusLost` handler as if the player
    pressed Enter.
  - For any other event, use [`testing.trigger()`](#testingtrigger).

- **Type**

  ```lua
  function testing.click(inst: Instance)
  function testing.typeInto(box: TextBox, text: string)
  ```

---

## story()

Turns a component into a storybook story, so you can preview it in Studio without pressing Play.
Works with [UI Labs](https://github.com/PepeElToro41/ui-labs), [Hoarcekat](https://github.com/Kampfkarren/hoarcekat)
and other plugins that take function stories.

- **Example**

  A ModuleScript named `ShopItem.story.luau` next to the component:

  ```lua
  local ShopItem = Rivue.defineComponent({
  	name = "ShopItem",
  	props = {
  		name = { type = "string", required = true },
  		price = { type = "number", required = true },
  	},
  	render = function(ctx)
  		return h("TextLabel", { Name = "Item", Text = `{ctx.name}: {ctx.price} coins` })
  	end,
  })

  -- A plain story
  local story = Rivue.story(ShopItem, { props = { name = "Iron Sword", price = 40 } })

  -- With controls you can change in UI Labs' panel
  local withControls = Rivue.story(ShopItem, {
  	controls = { name = "Iron Sword", price = 40 },
  })

  -- What the plugin does with them
  local preview = Instance.new("Frame")
  local cleanup = story(preview)
  assert((preview:FindFirstChild("Item") :: TextLabel).Text == "Iron Sword: 40 coins")
  cleanup()
  ```

  The module returns `story` (or `withControls`).

- **Details**

  Without `controls`, `story()` returns a function story: `function(target)` that mounts the
  component into `target` and returns a cleanup function. That's the format UI Labs and Hoarcekat
  both take.

  With `controls`, it returns a UI Labs generic story (`{ controls, render }`). The controls are
  passed as props, and the component re-renders when you change one.

  `props` can be a table, or a function that gets the controls and returns props, to name or
  convert them. `styles` registers style classes for the preview, like `app:styles()`.

- **Type**

  ```lua
  function story(component: ComponentDef, options: {
  	props: Props | ((controls) -> Props)?,
  	controls: { [string]: any }?,
  	styles: { [string]: Props }?,
  }?): any
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

[← Instance pool](pool.md) · [API reference](../API.md)
