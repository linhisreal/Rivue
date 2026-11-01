Pre-release.

| Package | Version | Stage |
|---|---|---|
| RivueUI | 0.10.0-rc.1 | release candidate |
| RivueRemote | 0.8.0-beta.1 | beta |
| RivueRouter | 0.3.0-beta.1 | beta |

## RivueUI

- `Transition` takes `mode = "in-out"`, as in Vue: the new child enters first, then the old one leaves.
- `TransitionGroup` takes `moveInfo`: items that change place slide there, including inside a `UIListLayout` or `UIGridLayout`, like Vue's move transition.

## Fixed

- RivueUI: rows built with `Rivue.hFor` inside a `TransitionGroup`, as in its docs example, didn't animate when added or removed.
- RivueUI: every copy of a `defineAsyncComponent` called the loader again, so a component shown a second time flashed its loading state. Copies now share one load, and later copies render straight away, as in Vue.
- RivueUI: an async component that finished loading after its timeout kept showing the error. It now shows the component.
- RivueUI: `vPreload` with a reactive list preloaded nothing.
- RivueUI: `array.sort` with a comparator that errored left the list half sorted, without updating the UI. The list now stays as it was.
- RivueUI: in strict mode, the old type solver rejected a `setup()` that returns a table, like `return { count = count }`.
- RivueUI: Luau's new type solver, which Studio uses, rejected typed child lists like `{ VNode }`, `watch()` with a getter and an options table, and an `app:styles()` table from another module. Rivue's own source now type checks cleanly with both solvers.

## Install

Drag `RivueUI.rbxm` into `ReplicatedStorage`. `RivueRemote.rbxm` and `RivueRouter.rbxm` are optional and go next to it. `RivueDevTools.rbxm` goes in your Plugins folder.
