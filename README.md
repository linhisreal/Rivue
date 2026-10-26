<p align="center">
  <img src="assets/icon.svg" width="128" height="128" alt="Rivue logo">
</p>

<h1 align="center">Rivue</h1>

<p align="center">
  Vue 3's component model for Roblox UI, in Luau.
</p>

<p align="center">
  <a href="https://github.com/linhisreal/Rivue/actions/workflows/build.yml"><img src="https://github.com/linhisreal/Rivue/actions/workflows/build.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial-blue.svg" alt="License: PolyForm Noncommercial 1.0.0"></a>
</p>

You write components that describe the UI for the current state. When the state changes,
Rivue re-renders the components that used it and updates only the Instance properties that
changed. No more finding a label to set its `Text`.

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h

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
				if draft.value == "" then
					return
				end
				nextId += 1
				Rivue.array.push(todos.value, { id = nextId, text = draft.value })
				draft.value = ""
			end,
		}
	end,

	render = function(ctx)
		return h("Frame", { class = "panel", layout = { gap = 6 } }, {
			h("TextBox", {
				model = "draft", -- two-way binding
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

Rivue.createApp(TodoList):mountToPlayerGui(game.Players.LocalPlayer)
```

## Features

- **Vue's reactivity**: `ref`, `reactive`, `computed`, `watch`, `watchEffect`, effect scopes,
  readonly and shallow variants.
- **Components**: `setup()` with `render(ctx)`, validated props, emits, slots, provide/inject,
  local `components` and every lifecycle hook.
- **Styling and layout**: style classes (`class = "card"`) per app or per component, and
  `layout`/`flex` props that build list, grid and flex layouts. `cornerRadius`, `padding` and
  `stroke` create the matching UI objects.
- **Fast updates**: keyed diffing, batched re-renders (parents first), memoized subtrees, and an
  optional Instance pool.
- **Built-ins**: `Transition`, `TransitionGroup`, `KeepAlive`, `Teleport`, `Suspense`,
  `VirtualList` and async components.
- **Made for Roblox**: tweens and springs, viewport and input-type composables, gamepad
  selection, attribute refs, CollectionService tags, and a rate-limited `Remote` for
  client/server calls.
- **Helpful in Studio**: warnings that name the component chain
  (`<TodoItem> in <TodoList>`), roots named after their component in the Explorer, and
  `app:printTree()`.
- **Typed**: strict Luau, with exported types such as `Rivue.Ref<T>` and `Rivue.VNode`.

## Installation

Rivue is a ModuleScript with a `runtime` folder. Put it in `ReplicatedStorage`.

**With Rojo**, add this repo as a git submodule and point your project at its
`rivue.project.json`:

```json
"ReplicatedStorage": {
  "Rivue": { "$path": "vendor/Rivue/rivue.project.json" }
}
```

**Without Rojo**, open the latest successful
[CI run](https://github.com/linhisreal/Rivue/actions/workflows/build.yml), download the `rivue`
artifact, and drag `Rivue.rbxm` into `ReplicatedStorage` in Studio. `Rivue.min.rbxm` is the same
without comments. You can also build both with `lune run build minify`.

## Docs

Start at the [docs home](docs/README.md), which has an "I want to…" index.

[Guide](docs/GUIDE.md) · [Examples](examples) · [API reference](docs/API.md) ·
[Coming from Vue](docs/VUE.md) · [Architecture](docs/ARCHITECTURE.md)

## Contributing

Tools are pinned in `rokit.toml` ([Rokit](https://github.com/rojo-rbx/rokit)):

```sh
rokit install
lune setup                        # editor types for the Lune scripts
lune run test                     # all suites, without Studio
lune run check-docs               # links resolve and every API example runs
lune run build                    # Rivue.rbxm and places, into build/
```

CI also runs StyLua and luau-lsp.

```
src/shared/Rivue/    the library
src/shared/Demo/     demo app, laid out as Guide chapter 10 recommends
src/client/          test place scripts (Demo, TestRunner, Stress)
tests/offline/       the Lune harness that runs tests outside Studio
```

## License

[PolyForm Noncommercial 1.0.0](LICENSE), with an extra permission for games. You can use, fork,
port and change Rivue, closed source or open, as long as you keep the credit notice. You can't
sell Rivue's code or use it commercially. Games built with Rivue may make money, if they credit
it. See [LICENSE](LICENSE) for the exact terms.
