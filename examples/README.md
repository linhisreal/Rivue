[Docs](../docs/README.md) › **Examples**

# Examples

Small, complete components that show how Rivue is meant to be used. Every one is mounted and
clicked through by `tests/Examples.test.luau`, so they stay working.

They all follow the [style rules](../docs/guide/11-style-rules.md): state and functions in `setup()`,
markup in `render(ctx)`, visuals in a `styles` table applied with `class`, and `layout` instead of
absolute positions. For a multi-file app (views, components, app-wide styles), see
[dev/Demo](../dev/Demo).

| Example | Shows | Guide chapters |
|---------|-------|----------------|
| [Counter](components/Counter.luau) | `ref`, `computed`, props with defaults, events | [1](../docs/guide/01-introduction.md), [2](../docs/guide/02-state.md) |
| [TodoList](components/TodoList.luau) | `model = "draft"`, keyed lists, local `components` with `emits`, `Rivue.array`, `flex` | [2](../docs/guide/02-state.md), [4](../docs/guide/04-components.md), [5](../docs/guide/05-forms-and-input.md) |
| [Inventory](components/Inventory.luau) | `VirtualList` for long lists, selection state, row components | [3](../docs/guide/03-describing-ui.md), [9](../docs/guide/09-performance-and-debugging.md) |
| [Modal](components/Modal.luau) | Building your own modal from named slots, `Teleport`, `Transition` and `vClickOutside` (for a ready-made one, see `Dialog` in GameMenu) | [4](../docs/guide/04-components.md), [7](../docs/guide/07-effects-and-animation.md) |
| [Tabs](components/Tabs.luau) | `KeepAlive` so tabs keep their state, slots per tab, `class` maps for the active tab | [4](../docs/guide/04-components.md), [6](../docs/guide/06-styling-and-layout.md) |
| [Shop](components/Shop.luau) | Loading from the server with `useAsync` and `Remote`: loading, error and retry, pending buys, a swappable API for tests | [8](../docs/guide/08-state-and-server.md) |
| [Hud](components/Hud.luau) | `attributeRef`, `useSpring` on a `Rivue.bind` binding so the bar moves without re-renders, `useInputType`/`useViewportSize` for responsive layout | [6](../docs/guide/06-styling-and-layout.md), [7](../docs/guide/07-effects-and-animation.md) |
| [GameMenu](components/GameMenu.luau) | RivueRouter: a back button on Escape/B, shop tabs as child routes with `RouterLink`, `meta` titles, a fade between screens, and a settings screen whose `onBeforeRouteLeave` guard waits on a `Dialog` | [13](../docs/guide/13-advanced-components.md), [17](../docs/guide/17-screens-and-navigation.md) |

## Running them

**In the dev place.** This needs [Rojo](https://rojo.space). From the repo root:

```sh
rojo serve
```

Connect from Studio, set the attribute `RivueExamples = true` on Workspace, and press Play.
[dev/client/Examples.client.luau](../dev/client/Examples.client.luau) mounts a few of them
together.

**In your game.** Copy a file from `components/` and require it like any ModuleScript:

```lua
local TodoList = require(path.to.TodoList)
Rivue.createApp(TodoList):mountToPlayerGui(game.Players.LocalPlayer)
```

GameMenu also needs RivueRouter next to RivueUI, and returns its app component, router and styles
instead of a single component. Its header comment shows how to mount it.

The examples use `--!nonstrict` because the old Luau type solver can't type mixed children
lists (`{ header, Rivue.hFor(...), Rivue.hIf(...) }`). With the new type solver, `--!strict`
works.
