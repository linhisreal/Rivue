# Examples

Small, complete components that show how Rivue is meant to be used. Every one is mounted and
clicked through by `tests/Examples.test.luau`, so they stay working.

| Example | Shows |
|---------|-------|
| [Counter](components/Counter.luau) | `ref`, `computed`, props with defaults, events |
| [TodoList](components/TodoList.luau) | `model` on a TextBox, keyed lists, child components with `emits`, computed filters |
| [Inventory](components/Inventory.luau) | `VirtualList` for long lists, selection state, row components |
| [Modal](components/Modal.luau) | Named slots, `Teleport`, `Transition`, `vClickOutside` |
| [Tabs](components/Tabs.luau) | `KeepAlive` so tabs keep their state, slots per tab, `style` |
| [Shop](components/Shop.luau) | Loading from the server with `Remote`, loading/error/pending states, a swappable API for tests |
| [Hud](components/Hud.luau) | `attributeRef`, `useSpring`, `useInputType`/`useViewportSize` for responsive layout |

## Running them

**In a place of their own.** This needs [Rojo](https://rojo.space):

```sh
rojo serve examples.project.json
```

Connect from Studio and press Play.
[place/ExamplesRunner.client.luau](place/ExamplesRunner.client.luau) mounts a few of them
together.

**In your game.** Copy a file from `components/` and require it like any ModuleScript:

```lua
local TodoList = require(path.to.TodoList)
Rivue.createApp(TodoList):mountToPlayerGui(game.Players.LocalPlayer)
```

The examples use `--!nonstrict` because the old Luau type solver can't type mixed children
lists (`{ header, Rivue.hFor(...), Rivue.hIf(...) }`). With the new type solver, `--!strict`
works.
