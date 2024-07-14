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

Rivue.createApp(Counter):mountToPlayerGui(game.Players.LocalPlayer)
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

## Learn

- **[Guide](docs/GUIDE.md)**: build UI step by step, from the first component to debugging a
  real screen, plus a table of common mistakes.
- **[Examples](examples)**: complete components (todo list, inventory, modal, tabs, shop, HUD).
  They run in their own place with `rojo serve examples.project.json` and are covered by the
  test suite.
- **[Coming from Vue](docs/VUE.md)**: a template-to-Luau cheat sheet and the differences.
- **[API reference](docs/API.md)**: every function, prop and component.
- **[Architecture](docs/ARCHITECTURE.md)**: how it works inside, for contributors.

## A quick tour

```lua
local TodoList = Rivue.defineComponent({
	name = "TodoList",
	setup = function()
		local todos = Rivue.ref({})
		local draft = Rivue.ref("")

		local nextId = 0
		local function add()
			nextId += 1
			local list = table.clone(Rivue.toRaw(todos.value))
			table.insert(list, { id = nextId, text = draft.value })
			todos.value = list
			draft.value = ""
		end

		return function()
			return h("Frame", { Size = UDim2.fromOffset(300, 400), padding = 8, cornerRadius = 8 }, {
				h("UIListLayout"),
				h("TextBox", {
					model = draft, -- two-way binding
					vFocus = true, -- directive
					onFocusLost = function(enter)
						if enter then
							add()
						end
					end,
				}),
				Rivue.hIf(#todos.value == 0, h("TextLabel", { Text = "Nothing yet" })),
				Rivue.hFor(todos.value, function(todo)
					return h("TextLabel", { key = todo.id, Text = todo.text })
				end),
			})
		end
	end,
})
```

- **Props** set Instance properties. `on*` props connect events (`onClick`, `onMouseEnter`,
  `onSizeChanged`), and `v*` props apply directives (`vShow`, `vFocus`, `vClickOutside`).
- **Children** can mix single elements, `nil` from `hIf`, and lists from `hFor`. Keyed list items
  keep their Instances when the list changes, and `LayoutOrder` follows the render order.
- **Modifier props** `cornerRadius`, `padding`, `stroke` and `aspectRatio` manage the matching
  UI objects for you, and `style` merges shared prop tables.
- **Components** take typed `props`, emit events (`emits`), receive slots, and can be animated
  with `Transition`, cached with `KeepAlive`, or virtualized with `VirtualList`.

When something goes wrong, errors name the component chain
(`Error in render of <TodoItem> in <TodoList>`). Component roots are named after their
component in the Explorer, and `app:printTree()` prints the live tree.

## Development

Tools are pinned in `aftman.toml` (Rojo, StyLua, Selene, luau-lsp, darklua).

```sh
aftman install
rojo serve                     # sync the test place into Studio
rojo serve examples.project.json  # or the examples place
stylua src tests examples      # format
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
examples/                  example components and the examples place
tests/                     test suites (*.test.luau), tests/offline has the CLI harness
docs/                      guide, API reference, Vue cheat sheet, architecture
```

## License

[GPL-3.0](LICENSE)
