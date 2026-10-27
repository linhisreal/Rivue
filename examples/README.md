[Docs](../docs/README.md) › **Examples**

# Examples

Each file in `components/` is one component you can copy into a game. `tests/Examples.test.luau`
mounts every one and clicks through it, so they keep working as Rivue changes.

They follow the [style rules](../docs/guide/11-style-rules.md): state and functions in `setup()`,
markup in `render(ctx)`, colours and sizes in a `styles` table applied with `class`, and `layout`
instead of absolute positions. [dev/Demo](../dev/Demo) is a bigger app split over several files.

| Example | What's in it | Guide chapters |
|---------|-------|----------------|
| [Counter](components/Counter.luau) | `ref`, `computed`, a prop with a default, a click handler | [1](../docs/guide/01-introduction.md), [2](../docs/guide/02-state.md) |
| [TodoList](components/TodoList.luau) | a text box with `model = "draft"`, a keyed list, a child component with `emits`, `Rivue.array`, `flex` | [2](../docs/guide/02-state.md), [4](../docs/guide/04-components.md), [5](../docs/guide/05-forms-and-input.md) |
| [Inventory](components/Inventory.luau) | a long list in a `VirtualList`, selection, one component per row | [3](../docs/guide/03-describing-ui.md), [9](../docs/guide/09-performance-and-debugging.md) |
| [Modal](components/Modal.luau) | a modal made from named slots, `Teleport`, `Transition` and `vClickOutside` | [4](../docs/guide/04-components.md), [7](../docs/guide/07-effects-and-animation.md) |
| [Tabs](components/Tabs.luau) | `KeepAlive` so tabs keep their state, a slot per tab, a `class` map for the open tab | [4](../docs/guide/04-components.md), [6](../docs/guide/06-styling-and-layout.md) |
| [Shop](components/Shop.luau) | `useAsync` and `Remote`: loading, an error with a retry button, "Buying..." while a purchase is pending | [8](../docs/guide/08-state-and-server.md), [12](../docs/guide/12-writing-composables.md) |
| [Hud](components/Hud.luau) | `attributeRef`, a `useSpring` health bar written through `Rivue.bind`, `useInputType` and `useViewportSize` | [6](../docs/guide/06-styling-and-layout.md), [7](../docs/guide/07-effects-and-animation.md) |
| [GameMenu](components/GameMenu.luau) | RivueRouter: a back button on Escape and B, shop tabs as child routes with `RouterLink`, titles from `meta`, a fade between screens, and a leave guard that waits on a `Dialog` | [13](../docs/guide/13-advanced-components.md), [17](../docs/guide/17-screens-and-navigation.md) |

## Running them

In the dev place you need [Rojo](https://rojo.space). From the repo root:

```sh
rojo serve
```

Connect from Studio, set the attribute `RivueExamples = true` on Workspace, and press Play.
[dev/client/Examples.client.luau](../dev/client/Examples.client.luau) mounts a few of them side by
side.

In your own game, copy a file from `components/` and require it like any ModuleScript:

```lua
local TodoList = require(path.to.TodoList)
Rivue.createApp(TodoList):mountToPlayerGui(game.Players.LocalPlayer)
```

GameMenu is the exception. It needs RivueRouter next to RivueUI, and it returns a table with the
app component, the router and the styles. The comment at the top of the file shows how to mount it.

The files start with `--!nonstrict` because the old Luau type solver can't type mixed children
lists like `{ header, Rivue.hFor(...), Rivue.hIf(...) }`. They pass `--!strict` under the new
solver.
