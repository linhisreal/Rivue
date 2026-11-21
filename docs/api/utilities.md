[Docs](../README.md) › [API](../API.md) › **Utilities and debugging**

# Utilities and debugging

**Learn it:** [Guide 9: Performance and debugging](../guide/09-performance-and-debugging.md) · [Guide 16: Testing UI](../guide/16-testing-ui.md)

Debugging helpers, timing utilities, test helpers and storybook stories. Examples assume
`local Rivue = require(game.ReplicatedStorage.RivueUI)` and `local h = Rivue.h`.

---

## Rivue.dev

`true` when running in Studio. Rivue's own warnings, such as unknown props, bad keys and invalid
props, only run when it's true.

```lua signature
Rivue.dev: boolean
```

### Example

```lua
if Rivue.dev then
	print("running in Studio")
end
```

---

## Rivue.version

The version of RivueUI that's running, such as `"0.10.0-rc.2"`. RivueRemote and RivueRouter have
their own, `Remote.version` and `Router.version`.

```lua signature
Rivue.version: string
```

### Example

```lua
print(`Running Rivue {Rivue.version}`)
```

---

## printTree()

Prints what's mounted under an element as a tree. [`app:printTree()`](application.md#appprinttree)
does the same for the whole app.

```lua signature
function printTree(vnode: VNode): string
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `vnode` | `VNode` | | a mounted vnode |

**Returns** the same text it printed.

### Example

```lua
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

Turns on detailed logging of everything Rivue does: every element, mount, update and remote call.

```lua signature
Rivue.debug.enabled: boolean -- default false
```

> [!WARNING]
> It's very noisy and slows rendering down, so only turn it on briefly to trace a problem. Studio
> warnings don't depend on it.

### Example

```lua
Rivue.debug.enabled = true
-- reproduce the problem, then
Rivue.debug.enabled = false
```

---

## inspect()

Turns any value into a readable string. A reactive table shows its data, where `print` would show
an empty proxy.

```lua signature
function inspect(value: unknown, depth: number?): string
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `unknown` | | anything |
| `depth` | `number?` | `3` | how many levels of nested tables to show |

### Example

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

Prints a value across several lines, indented, with reactive tables unwrapped.

```lua signature
function prettyPrint(value: unknown, options: { indent: number?, maxDepth: number?, unwrapProxies: boolean? }?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `unknown` | | anything |
| `options.indent` | `number?` | | spaces per level |
| `options.maxDepth` | `number` | `10` | how deep to go |
| `options.unwrapProxies` | `boolean` | `true` | show reactive tables' data |

### Example

```lua
local state = Rivue.reactive({ player = { name = "Ada", level = 3 } })
Rivue.prettyPrint(state, { maxDepth = 2 })
```

---

## assertInvariant()

_Studio only_

Checks something you expect to always be true, and errors in Studio if it isn't.

```lua signature
function assertInvariant(condition: boolean, message: string)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `condition` | `boolean` | | what should be true |
| `message` | `string` | | the error message |

> [!NOTE]
> It only checks in Studio, or with `debug.enabled` on. In live servers it does nothing.

### Example

```lua
local function setVolume(volume: number)
	Rivue.assertInvariant(volume >= 0 and volume <= 1, "volume must be between 0 and 1")
end
```

---

## debug.measure()

Times a function and logs how long it took, when `debug.enabled` is on.

```lua signature
function debug.measure<R...>(name: string, fn: () -> R...): R...
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | the label in the log |
| `fn` | `() -> R...` | | the work to time |

**Returns** whatever `fn` returned.

### Example

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

Prints a message with a category tag, only when `debug.enabled` is on.

```lua signature
function debug.log(category: string, message: string, data: unknown?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `category` | `string` | | the tag, as in `[Rivue:DEBUG:Shop]` |
| `message` | `string` | | the message |
| `data` | `unknown?` | | printed after the message |

### Example

```lua
Rivue.debug.log("Shop", "Opened", { items = 12 })
-- prints "[Rivue:DEBUG:Shop] Opened" followed by the data
```

---

## debug.formatError()

Builds an error message in Rivue's format, with a category and optional details.

```lua signature
function debug.formatError(category: string, message: string, context: unknown?): string
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `category` | `string` | | the area, such as `"Shop"` |
| `message` | `string` | | what went wrong |
| `context` | `unknown?` | | details to include |

### Example

```lua
local message = Rivue.debug.formatError("Shop", "Item not found", { id = "sword" })
warn(message)
```

---

## utils.debounce()

Waits until calls stop for a moment before running, for example to search once the player stops
typing.

```lua signature
function utils.debounce<A...>(fn: (A...) -> (), ms: number): (A...) -> { cancel: () -> () }
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fn` | `(A...) -> ()` | | runs with the last call's arguments |
| `ms` | `number` | | milliseconds to wait; values below 1 are read as seconds |

**Returns** the debounced function. Each call returns a handle whose `cancel()` drops the pending
call.

### Example

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

Runs at most once per interval, however often it's called. For things that fire every frame, like
mouse movement.

```lua signature
function utils.throttle<A...>(fn: (A...) -> (), ms: number): (A...) -> ()
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fn` | `(A...) -> ()` | | the function to limit |
| `ms` | `number` | | the interval in milliseconds |

**Returns** the throttled function. The first call runs right away; calls during the wait collapse
into one trailing call with the latest arguments.

### Example

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

```lua signature
function utils.nextFrame(fn: () -> ())
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fn` | `() -> ()` | | the function to run |

### Example

```lua
Rivue.utils.nextFrame(function()
	print("one frame later")
end)
```

---

## utils.useRaf()

Runs a function every frame until you stop it.

```lua signature
function utils.useRaf(fn: (deltaTime: number) -> ()): { stop: () -> () }
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fn` | `(deltaTime) -> ()` | | runs each frame |

**Returns** a handle whose `stop()` ends the loop.

> [!WARNING]
> It doesn't stop on its own, even in a component. Inside components,
> [`onRenderStepped()`](roblox.md#onrenderstepped--onheartbeat--onstepped) stops on unmount.

### Example

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

_server · yields_

Filters text with TextService before a player sees it.

```lua signature
function utils.filterForClient(player: Player, text: string): string
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `player` | `Player` | | who wrote the text |
| `text` | `string` | | the text to filter |

**Returns** the filtered text, or `""` if filtering fails, so unfiltered text is never shown.

> [!WARNING]
> It yields, and only works on the server.

### Example

<!-- server -->
```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	local safe = Rivue.utils.filterForClient(player, "user-written pet name")
	player:SetAttribute("PetName", safe)
end)
```

---

## utils.shallowEqual()

Whether two tables have the same keys and values, one level deep.

```lua signature
function utils.shallowEqual(a: unknown, b: unknown): boolean
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `a`, `b` | `unknown` | | the values to compare |

### Example

```lua
print(Rivue.utils.shallowEqual({ a = 1 }, { a = 1 })) -- true
print(Rivue.utils.shallowEqual({ a = {} }, { a = {} })) -- false, different inner tables
```

---

## utils.profiler

Named timers for finding slow code. While it's active, every effect run is timed too.

```lua signature
utils.profiler: {
	active: boolean,
	records: { [string]: number },
	start: (self, name: string) -> (),
	stop: (self, name: string) -> number?,
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `start` | `(self, name) -> ()` | | starts a timer and turns `active` on |
| `stop` | `(self, name) -> number?` | | stops it and returns the elapsed seconds |
| `active` | `boolean` | `false` | set it back to `false` when you're done |
| `records` | `{ [string]: number }` | | timings by name |

### Example

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

Loops over a reactive list the way `ipairs` would, which plain `ipairs` can't do with proxies.

```lua signature
function iterArray<T>(array: { T }): () -> (number?, T?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `array` | `{ T }` | | a plain or reactive list |

### Example

```lua
local list = Rivue.reactive({ "a", "b", "c" })

for index, value in Rivue.iterArray(list) do
	print(index, value)
end
```

### Details

- The same as `for i = 1, #list do`. Generalized iteration, `for i, v in list do`, also works on
  proxies.

---

## testing.render()

Mounts a component for a test, with ways to find elements by what the player would see, like
Testing Library on the web.

```lua signature
function testing.render(component: ComponentDef | VNode, props: { [string]: any }?): RenderResult
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `component` | `ComponentDef \| VNode` | | what to mount |
| `props` | `{ [string]: any }?` | | its props |

**Returns** `{ container, app, getByText, queryByText, getAllByText, getByName, queryByName, unmount }`.

| Field | Type | Default | Description |
|---|---|---|---|
| `getByText` | `(text \| (string) -> boolean) -> Instance` | | the one TextLabel, TextButton or TextBox showing that text; errors if there's none or more than one |
| `queryByText` | `(text) -> Instance?` | | the same, but `nil` when there's none |
| `getAllByText` | `(text) -> { Instance }` | | every match |
| `getByName`, `queryByName` | `(name: string) -> Instance` | | find by Instance `Name` |
| `unmount` | `() -> ()` | | unmounts and destroys the container |

### Example

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

---

## testing.click() and testing.typeInto()

Act like the player, then wait for the re-render, so the next line can check the result.

```lua signature
function testing.click(inst: Instance)
function testing.typeInto(box: TextBox, text: string)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `inst` | `Instance` | | runs its `onClick`, `onActivated` or `onMouseButton1Click` handler |
| `box` | `TextBox` | | sets its `Text`, then runs `onFocusLost` as if the player pressed Enter |
| `text` | `string` | | what to type |

> [!WARNING]
> `click` errors when the element has no click handler, and `typeInto` errors on anything but a
> TextBox, so a test that acts on the wrong element fails.

### Example

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

---

## testing.trigger()

Calls an element's event handler as if the event fired. Scripts can't fire engine events like
`Activated` or `FocusLost`, so tests use this for any event `click` and `typeInto` don't cover.

```lua signature
function testing.trigger(element: Instance, key: string, ...: any)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `element` | `Instance` | | the element |
| `key` | `string` | | the event prop as written in `h()`: `"onClick"`, `"onFocusLost"`, ... |
| `...` | `any` | | passed to the handler; `trigger(box, "onFocusLost", true)` is pressing Enter |

> [!NOTE]
> It doesn't wait for the re-render; call `Rivue.nextTick()` before checking. It errors when the
> element has no handler for `key`.

### Example

```lua
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

### Details

- Input from `UserInputService` (`vClickOutside`, `vDrag`, the input-type composables) can't be
  faked this way. Test the logic behind it in a composable instead; see
  [Guide 16](../guide/16-testing-ui.md#what-a-script-cant-test).

---

## testing.setInteraction()

Turns an element's hover, pressed or selected state on or off, as if the player did it. For testing
[style class variants](application.md#appstyles), since scripts can't move the mouse.

```lua signature
function testing.setInteraction(element: Instance, state: "hover" | "pressed" | "selected", on: boolean)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `element` | `Instance` | | an element whose classes have state variants; others are ignored |
| `state` | `"hover" \| "pressed" \| "selected"` | | which state |
| `on` | `boolean` | | turn it on or off |

> [!NOTE]
> The change applies straight away, without `nextTick()`.

### Example

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

---

## story()

Turns a component into a storybook story, to preview it in Studio without pressing Play. Works with
[UI Labs](https://github.com/PepeElToro41/ui-labs), [Hoarcekat](https://github.com/Kampfkarren/hoarcekat)
and other plugins that take function stories.

```lua signature
function story(component: ComponentDef, options: {
	props: Props | ((controls) -> Props)?,
	controls: { [string]: any }?,
	styles: { [string]: Props }?,
}?): any
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `component` | `ComponentDef` | | what to preview |
| `options.props` | `Props \| (controls) -> Props` | | props, or a function that turns the controls into props |
| `options.controls` | `{ [string]: any }?` | | values you can change in UI Labs' panel, passed as props |
| `options.styles` | `{ [string]: Props }?` | | style classes for the preview, like `app:styles()` |

**Returns** without `controls`, a function story: `function(target)` that mounts into `target` and
returns a cleanup function. With `controls`, a UI Labs generic story, `{ controls, render }`, that
re-renders when a control changes.

### Example

A ModuleScript named `ShopItem.story.luau` next to the component returns `story` or `withControls`:

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

local story = Rivue.story(ShopItem, { props = { name = "Iron Sword", price = 40 } })

local withControls = Rivue.story(ShopItem, {
	controls = { name = "Iron Sword", price = 40 },
})

-- what the plugin does with a story
local preview = Instance.new("Frame")
local cleanup = story(preview)
assert((preview:FindFirstChild("Item") :: TextLabel).Text == "Iron Sword: 40 coins")
cleanup()
```

---

## Types

Exported types, available as `Rivue.<Name>` in type annotations.

| Field | Type | Default | Description |
|---|---|---|---|
| `Ref<T>`, `ComputedRef<T>` | | | refs |
| `MaybeRef<T>`, `MaybeRefOrGetter<T>` | | | a value or a ref, or a getter too |
| `WatchOptions`, `WatchSource<T>`, `WatchCallback<T>`, `WatchHandle`, `OnCleanup` | | | watchers |
| `Effect`, `EffectScope`, `DebuggerEvent` | | | effects |
| `VNode`, `Props`, `Child`, `ChildInput`, `Children` | | | render functions |
| `ComponentDef`, `ComponentOptions`, `PropSchema`, `EmitsOptions`, `SetupContext`, `ComponentInstance` | | | components |
| `TransitionConfig` | | | the `transition` prop and Transition |
| `Directive` | | | custom directives |
| `App`, `AppOptions`, `Plugin` | | | apps |
| `QueueOptions`, `JobHandle` | | | the scheduler |

### Example

```lua
type Item = { id: number, name: string }

local selected: Rivue.Ref<Item?> = Rivue.ref(nil :: Item?)

local function useCount(initial: number): Rivue.Ref<number>
	return Rivue.ref(initial)
end
```

---

[← Instance pool](pool.md) · [API reference](../API.md)
