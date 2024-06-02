# Rivue

A Vue-style UI framework for Roblox, written in Luau.

[![Build](https://github.com/linhisreal/Rivue/actions/workflows/build.yml/badge.svg)](https://github.com/linhisreal/Rivue/actions/workflows/build.yml)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)

Rivue gives you Vue 3's model for Roblox UI: reactive state, components with `setup()`, and
render functions that return a virtual tree. When state changes, the affected components re-render and
Rivue patches the real Instances. You only describe the UI; Rivue keeps the Instances in sync.

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h

local Counter = Rivue.defineComponent({
	name = "Counter",
	setup = function()
		local count = Rivue.ref(0)
		local doubled = Rivue.computed(function()
			return count.value * 2
		end)

		return function()
			return h("TextButton", {
				Size = UDim2.fromOffset(200, 50),
				Text = `Clicked {count.value} times ({doubled.value})`,
				cornerRadius = 8,
				onClick = function()
					count.value += 1
				end,
			})
		end
	end,
})

Rivue.createApp(h(Counter)):mountToPlayerGui(game.Players.LocalPlayer)
```

## Features

- **Reactivity**: `ref`, `reactive`, `computed`, `watch`, `watchEffect`, effect scopes, readonly
  and shallow variants. It works the same way as Vue's reactivity system.
- **Components**: `setup()` with props validation, emits, attrs fallthrough, named and scoped
  slots, provide/inject, `expose`, and the full set of lifecycle hooks.
- **Rendering**: keyed diffing, batched updates (parents before children), fragments, and
  memoized subtrees. Elements are parented only after their children are built.
- **Built-in components**: `Transition`, `TransitionGroup`, `KeepAlive`, `Teleport`, `Suspense`,
  `VirtualList`, async components.
- **Roblox-specific APIs**: TweenService transitions, `useTween`/`useSpring`, `useViewportSize`,
  `useInputType`, gamepad selection, attribute refs, CollectionService tags. Props like
  `cornerRadius`, `padding` and `stroke` create the matching `UICorner`/`UIPadding`/`UIStroke`.
- **Extras**: Instance pooling, a client/server `Remote` helper with rate limiting, directives,
  and Studio-only dev warnings.
- **Typed**: strict Luau throughout, with exported types (`Rivue.Ref<T>`, `Rivue.VNode`, ...).

## Installation

Rivue is a ModuleScript (`Rivue`) with a `runtime` folder of modules. Put it in
`ReplicatedStorage`.

**Rojo**: add this repo as a git submodule (or copy it), then point your project at
`rivue.project.json`:

```json
"ReplicatedStorage": {
  "Rivue": { "$path": "vendor/Rivue/rivue.project.json" }
}
```

**Model file**: build `Rivue.rbxm` and insert it into ReplicatedStorage in Studio:

```sh
rojo build rivue.project.json -o Rivue.rbxm
```

Then require it from any LocalScript:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
```

## Basics

### Elements and props

`h(className, props, children)` describes an Instance. Props set properties on it. Keys that
start with `on` connect events, and a few prop names are handled by Rivue itself:

```lua
h("Frame", {
	Size = UDim2.fromScale(1, 1),          -- any property (camelCase works too: size)
	onMouseEnter = function() end,         -- events
	onClick = function() end,              -- Activated / MouseButton1Click
	onSizeChanged = function(size) end,    -- property changes get the new value
	padding = 8,                           -- UIPadding child
	key = item.id,                         -- identity in lists
	ref = frameRef,                        -- template ref
}, {
	h("TextLabel", { Text = "Hello" }),
})
```

### Lists and conditionals

```lua
local rows = Rivue.hFor(items.value, function(item)
	return h("TextLabel", { key = item.id, Text = item.name })
end)
table.insert(rows, 1, h("UIListLayout"))

h("ScrollingFrame", nil, rows)

h("Frame", nil, {
	h("TextLabel", { Text = "Inventory" }),
	Rivue.hIf(loading.value, h("TextLabel", { Text = "Loading..." })),
})
```

Keyed list items keep their Instances when the list is reordered. With a `UIListLayout`, Rivue
also keeps `LayoutOrder` in sync. For long lists, use `Rivue.VirtualList`, which only renders the
rows in view.

### Components with props and events

```lua
local ItemRow = Rivue.defineComponent({
	name = "ItemRow",
	props = {
		item = { type = "table", required = true },
		selected = { type = "boolean", default = false },
	},
	emits = { "select" },
	setup = function(props, ctx)
		return function()
			return h("TextButton", {
				Text = props.item.name,
				BackgroundColor3 = if props.selected then Color3.new(0.2, 0.5, 1) else Color3.new(0.15, 0.15, 0.15),
				onClick = function()
					ctx.emit("select", props.item.id)
				end,
			})
		end
	end,
})

h(ItemRow, { item = item, selected = selectedId.value == item.id, onSelect = function(id) selectedId.value = id end })
```

### Animating

```lua
h(Rivue.Transition, { tweenInfo = TweenInfo.new(0.2), from = { BackgroundTransparency = 1 } }, {
	Rivue.hIf(open.value, h("Frame", { BackgroundTransparency = 0.1 })),
})
```

See [docs/API.md](docs/API.md) for the full API.

## Documentation

- [API reference](docs/API.md): every public function, prop and component, with examples.
- [Architecture](docs/ARCHITECTURE.md): how reactivity, scheduling and patching work, for
  contributors.

## Development

Tools are pinned in `aftman.toml` (Rojo, StyLua, Selene, luau-lsp, darklua).

```sh
aftman install
rojo serve                     # sync the test place into Studio
stylua src tests               # format
scripts/test-offline.sh        # run every test suite with the Luau CLI, no Studio needed
```

`scripts/test-offline.sh` needs the [Luau CLI](https://github.com/luau-lang/luau/releases) on
`PATH` (or set `LUAU=/path/to/luau`). Pass test files to run only those:
`scripts/test-offline.sh tests/Renderer.test.luau`.

In Studio, the `TestRunner` LocalScript runs the same suites when you play the place.

CI checks formatting, lints, type checks with luau-lsp, and runs the offline suites on every
push.

### Layout

```
src/shared/Rivue/          the library (Rivue.luau + runtime/)
src/client, src/server     test place scripts
tests/                     test suites (*.test.luau), tests/offline has the CLI harness
docs/                      API reference and architecture notes
```

## License

[GPL-3.0](LICENSE)
