[Docs](README.md) › **Coming from Roact, React-lua or Fusion**

# Coming from Roact, React-lua or Fusion

All three describe UI as a tree, like Rivue. What differs is how they update it:

- **Roact and React-lua** follow React: a component's render function runs again on every state
  change, and you use `shouldUpdate`, `memo` or bindings to avoid work.
- **Fusion** tracks state per value and updates Instance properties directly, but has no
  component system: components are plain functions.
- **Rivue** follows Vue: state is tracked per value like Fusion, and components have props,
  events, slots and lifecycle hooks like React. Only components that read the changed value
  re-render.

## The same counter in each

Roact:

```lua
local Counter = Roact.Component:extend("Counter")

function Counter:init()
	self:setState({ count = 0 })
end

function Counter:render()
	return Roact.createElement("TextButton", {
		Text = `Clicked {self.state.count} times`,
		[Roact.Event.Activated] = function()
			self:setState({ count = self.state.count + 1 })
		end,
	})
end
```

React-lua:

```lua
local function Counter()
	local count, setCount = React.useState(0)
	return React.createElement("TextButton", {
		Text = `Clicked {count} times`,
		[React.Event.Activated] = function()
			setCount(count + 1)
		end,
	})
end
```

Fusion 0.3:

```lua
local function Counter(scope)
	local count = scope:Value(0)
	return scope:New "TextButton" {
		Text = scope:Computed(function(use)
			return `Clicked {use(count)} times`
		end),
		[OnEvent "Activated"] = function()
			count:set(peek(count) + 1)
		end,
	}
end
```

Rivue:

```lua
local Counter = Rivue.defineComponent({
	name = "Counter",
	setup = function()
		local count = Rivue.ref(0)
		return {
			count = count,
			increment = function()
				count.value += 1
			end,
		}
	end,
	render = function(ctx)
		return h("TextButton", { Text = `Clicked {ctx.count} times`, onClick = ctx.increment })
	end,
})
```

## API map

| Roact | React-lua | Fusion | Rivue |
|---|---|---|---|
| `Roact.createElement(class, props, children)` | `React.createElement` | `scope:New "Frame" { ... }` | `h("Frame", props, children)` |
| `Component:extend("Name")` | function component | function taking `scope` | `Rivue.defineComponent({ name, props, setup, render })` |
| `self.state` / `setState` | `useState` | `scope:Value` / `:set()` | `Rivue.ref` / `Rivue.reactive`, assign to change |
| derived values in `render` | `useMemo` | `scope:Computed` | `Rivue.computed` |
| `didMount` / `willUnmount` | `useEffect(fn, {})` | `scope` cleanup | `onMounted` / `onUnmounted` |
| `didUpdate` | `useEffect(fn, { deps })` | `scope:Observer` | `Rivue.watch(source, fn)` |
| `shouldUpdate`, `PureComponent` | `React.memo` | not needed | not needed: children with equal props are skipped. `memo = { deps }` for the rest |
| `[Roact.Event.Activated]` | `[React.Event.Activated]` | `[OnEvent "Activated"]` | `onClick` / `onActivated` |
| `[Roact.Change.Text]` | `[React.Change.Text]` | `[OnChange "Text"]` | `onTextChanged` (any `on<Property>Changed`) |
| `Roact.createRef` + `[Roact.Ref]` | `useRef` + `ref` | `[Out]` / `Value` | `ref = "name"` + `Rivue.useTemplateRef("name")` |
| `createBinding` | `useBinding` | `Value` | `Rivue.ref`. Only readers re-render, so no binding is needed for speed |
| `createContext` / `Provider` / `Consumer` | `createContext` / `useContext` | pass values down | `Rivue.provide` / `Rivue.inject` |
| `Roact.Portal` | `ReactRoblox.createPortal` | parent elsewhere | `Rivue.Teleport` |
| `Roact.createFragment` | `React.Fragment` | a table of children | `Rivue.Fragment`, or return a list |
| `self.props[Roact.Children]` | `props.children` | `[Children]` | slots: `ctx.renderSlot("default")` |
| `defaultProps`, `validateProps` | `defaultProps`, `propTypes` | — | `props = { name = { type, default, required, validator } }` |
| `Roact.mount(tree, parent)` | `ReactRoblox.createRoot(parent):render(el)` | `scope:New` with `Parent` | `Rivue.createApp(App):mount(parent)` |
| `Roact.unmount(handle)` | `root:unmount()` | `scope:doCleanup()` | `app:unmount()` |
| `useReducer` | `useReducer` | — | a store module ([Guide 14](guide/14-state-architecture.md)) |
| — | `Suspense`, `React.lazy` | — | `Rivue.Suspense`, `Rivue.defineAsyncComponent` |
| `Otter` / `Flipper` | `ReactSpring` | `scope:Tween`, `scope:Spring` | `Rivue.useTween`, `Rivue.useSpring`, `Rivue.Transition` |
| children by name `{ Title = ... }` | same | `[Children] = { ... }` | a list. Set `Name` for the Explorer, `key` for lists |

## Things that work differently

- **Children are a list, not a dictionary.** Rivue orders them with `LayoutOrder` in render
  order. Give list items a `key` and anything you look up a `Name`.
- **`setup` runs once.** Create state and watchers there. `render` only describes the UI and runs
  whenever state it read changes. There are no hook rules or dependency arrays.
- **Reads are tracked, writes are batched.** Changing several values in a row re-renders each
  affected component once. Call `Rivue.nextTick()` to wait for it.
- **Styling has classes.** Instead of repeating properties, register style classes with
  `app:styles()` and use `class = "button"`. Classes also handle hover, pressed and per-device
  variants ([Guide 6](guide/06-styling-and-layout.md)).
- **Lists change through `Rivue.array`.** `table.insert` on reactive state isn't seen. Use
  `Rivue.array.push`, `removeWhere`, `sort` and the rest.

## Tooling

The usual Roblox tools work the same:

| | Roact / React-lua / Fusion projects | Rivue |
|---|---|---|
| Syncing files | Rojo | Rojo: point `$path` at the Rivue folder |
| Packages | Wally | Wally (see [Releasing](RELEASING.md)), or the `.rbxm` from a release |
| Storybook | UI Labs, Hoarcekat, Flipbook | `Rivue.story()` for UI Labs and Hoarcekat ([API](api/utilities.md#story)) |
| Tests | TestEZ, Jest-Lua | either runner: mount, `Rivue.testing.trigger`, `Rivue.nextTick()` ([Guide 16](guide/16-testing-ui.md)) |
| Types and formatting | luau-lsp, StyLua | luau-lsp, StyLua; Rivue is `--!strict` with exported types |

Selene can't parse the Luau `const` declarations Rivue uses yet, so exclude the Rivue folder (or
your `Packages` folder) from Selene.
