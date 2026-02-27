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
		return {
			count = count,
			doubled = Rivue.computed(function()
				return count.value * 2
			end),
			increment = function()
				count.value += 1
			end,
		}
	end,
	render = function(ctx)
		return h("TextButton", {
			Size = UDim2.fromOffset(200, 50),
			Text = `Clicked {ctx.count} times ({ctx.doubled})`,
			cornerRadius = 8,
			onClick = ctx.increment,
		})
	end,
})

Rivue.createApp(Counter):mountToPlayerGui(game.Players.LocalPlayer)
```

## Features

- **Reactivity**: `ref`, `reactive`, `computed`, `watch`, `watchEffect`, effect scopes, readonly
  and shallow variants. It works the same way as Vue's reactivity system.
- **Components**: `setup()` plus `render(ctx)`, props validation, emits, local `components`,
  attrs fallthrough, named and scoped slots, provide/inject, `expose`, and the full set of
  lifecycle hooks.
- **Styling and layout**: named style classes (`class = "card"`) registered app-wide or per
  component, and `layout`/`flex` props that build list, grid and flex layouts.
- **Rendering**: keyed diffing, batched updates (parents before children), fragments, and
  memoized subtrees. Elements are parented only after their children are built.
- **Built-in components**: `Transition`, `TransitionGroup`, `KeepAlive`, `Teleport`, `Suspense`,
  `VirtualList`, async components.
- **Roblox-specific APIs**: TweenService transitions, `useTween`/`useSpring`, `useViewportSize`,
  `useInputType`, gamepad selection, attribute refs, CollectionService tags. Props like
  `cornerRadius`, `padding` and `stroke` create the matching `UICorner`/`UIPadding`/`UIStroke`.
- **Extras**: reactive array helpers (`Rivue.array.push`, `removeWhere`, ...), Instance pooling, a client/server `Remote` helper with rate limiting, directives,
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
- **[Style Guide](docs/STYLE_GUIDE.md)**: project structure and conventions that keep UI code
  flat and readable as a game grows.
- **[Coming from Vue](docs/VUE.md)**: a template-to-Luau cheat sheet and the differences.
- **[API reference](docs/API.md)**: every function, prop and component.
- **[Architecture](docs/ARCHITECTURE.md)**: how it works inside, for contributors.

## A quick tour

```lua
local array = Rivue.array

local TodoList = Rivue.defineComponent({
	name = "TodoList",
	styles = {
		panel = { Size = UDim2.fromOffset(300, 400), padding = 8, cornerRadius = 8 },
	},
	setup = function()
		local todos = Rivue.ref({})
		local draft = Rivue.ref("")
		local nextId = 0

		return {
			todos = todos,
			draft = draft,
			add = function()
				nextId += 1
				array.push(todos.value, { id = nextId, text = draft.value })
				draft.value = ""
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { class = "panel", layout = { gap = 6 } }, {
			h("TextBox", {
				model = "draft", -- two-way binding to the draft ref
				vFocus = true, -- directive
				onFocusLost = function(enter)
					if enter then
						ctx.add()
					end
				end,
			}),
			Rivue.hIf(#ctx.todos == 0, h("TextLabel", { Text = "Nothing yet" })),
			Rivue.hFor(ctx.todos, function(todo)
				return h("TextLabel", { key = todo.id, Text = todo.text })
			end),
		})
	end,
})
```

- **Props** set Instance properties. `on*` props connect events (`onClick`, `onMouseEnter`,
  `onSizeChanged`), and `v*` props apply directives (`vShow`, `vFocus`, `vClickOutside`).
- **Children** can mix single elements, `nil` from `hIf`, and lists from `hFor`. Keyed list items
  keep their Instances when the list changes, and `LayoutOrder` follows the render order.
- **Modifier props** `cornerRadius`, `padding`, `stroke`, `aspectRatio`, `layout` and `flex`
  manage the matching UI objects for you. `class` applies named styles.
- **`render(ctx)`** reads what `setup()` returned without `.value`, then props, then `ctx.emit`
  and friends. `Rivue.array` edits reactive lists.
- **Components** take typed `props`, emit events (`emits`), receive slots, and can be animated
  with `Transition`, cached with `KeepAlive`, or virtualized with `VirtualList`.

When something goes wrong, errors name the component chain
(`Error in render of <TodoItem> in <TodoList>`). Component roots are named after their
component in the Explorer, and `app:printTree()` prints the live tree.

## Development

Tools are pinned in `rokit.toml` (Rojo, Lune, darklua, StyLua, luau-lsp). Install
[Rokit](https://github.com/rojo-rbx/rokit), then:

```sh
rokit install
rojo serve                        # sync the test place into Studio
rojo serve examples.project.json  # or the examples place
lune run test                     # every test suite, no Studio needed
lune run test tests/Renderer.test.luau
lune run check-docs               # doc links resolve and every API example runs
lune run build                    # build/Rivue.rbxm and the places (add `minify` for Rivue.min.rbxm)
stylua src tests examples .lune   # format
```

In Studio, the `TestRunner` LocalScript runs the same suites when you play the place. CI runs
the format check, luau-lsp type check, tests, docs check and build on every push. Opening the
repo in VS Code suggests the Rojo, luau-lsp and StyLua extensions.

### Layout

```
src/shared/Rivue/          the library (Rivue.luau + runtime/)
src/shared/Demo/           demo app, laid out as the Style Guide recommends
src/client, src/server     test place scripts (Demo, TestRunner, opt-in stress test)
.vscode/                   editor settings and snippets (rcomponent, rview, rstyles, ...)
examples/                  example components and the examples place
tests/                     test suites (*.test.luau), tests/offline has the offline harness
.lune/                     Lune scripts: test, check-docs, build
docs/                      guide, API reference, Vue cheat sheet, architecture
```

## License

[GPL-3.0](LICENSE)
