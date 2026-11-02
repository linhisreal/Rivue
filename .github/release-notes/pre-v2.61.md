Pre-release.

| Package | Version | Stage |
|---|---|---|
| RivueUI | 0.10.0-rc.1 | release candidate |
| RivueRemote | 0.8.0-beta.1 | beta |
| RivueRouter | 0.3.0-beta.1 | beta |

## RivueUI

- `Transition` takes `mode = "in-out"`, as in Vue: the new child enters first, then the old one leaves.
- `TransitionGroup` takes `moveInfo`: items that change place slide there, including inside a `UIListLayout` or `UIGridLayout`, like Vue's move transition.

## RivueDevTools

- A redesigned window: four tabs (Components, Activity, Perf, Network), with search, Highlight, Pause and settings in the status bar. Events, the timeline, warnings and the route now share the Activity tab.
- One toolbar: the filter holds the Slow and Changed chips, and Sort, Reset, Fold, Pick and Export live in the ⋯ menu.
- Rows show a ten-second render sparkline; slow times are a red pill instead of red text, and drawn icons replace font glyphs.
- The details have breadcrumbs to parent components and a Recent card with the last five renders and their causes.
- Ctrl+K (or Search) finds components, state keys, network actions and warnings at once.
- Wide windows put the details beside the tree, and a compact row density is in settings.
- The tree and Activity list are virtualised, so long sessions and big trees stay fast.
- A **Perf** tab: record a session and see which components rendered most, for how long, and why, plus the slowest single updates.
- A **Network** tab for RivueRemote: requests, sends, events and replicated state, with payload sizes, totals per action and failures.
- A **Warnings** tab that collects Rivue warnings and errors and opens the component they came from.
- **Pick**: select a GUI object in the Explorer, or click it in the game, to open its component.
- Tree tools: expand and collapse all, Slow and Changed filters, pinned components, and folded branches and pins remembered between sessions.
- Better state editing: booleans are toggles, tables open into editable fields, changed fields show their previous value, and values can be copied.
- **Export** saves the tree and timeline to `ServerStorage.RivueSnapshot`.
- Keyboard shortcuts: Ctrl+F, Up and Down, Enter and Esc.
- Tables in props and state show their fields instead of `table`.

## Fixed

- RivueUI: classes, local components and template refs inside a `VirtualList` `render` callback or a scoped slot were looked up in the component that rendered them (VirtualList, or the slot's host) instead of the one that wrote them. They now use the author's, as Vue does with scoped slots.
- RivueUI: `onBeforeUpdate` ran after the render instead of before it, so state it changed cost an extra render. It now runs first, untracked, as in Vue.
- RivueUI: rows built with `Rivue.hFor` inside a `TransitionGroup`, as in its docs example, didn't animate when added or removed.
- RivueUI: every copy of a `defineAsyncComponent` called the loader again, so a component shown a second time flashed its loading state. Copies now share one load, and later copies render straight away, as in Vue.
- RivueUI: an async component that finished loading after its timeout kept showing the error. It now shows the component.
- RivueUI: `vPreload` with a reactive list preloaded nothing.
- RivueUI: `array.sort` with a comparator that errored left the list half sorted, without updating the UI. The list now stays as it was.
- RivueUI: in strict mode, the old type solver rejected a `setup()` that returns a table, like `return { count = count }`.
- RivueUI: Luau's new type solver, which Studio uses, rejected typed child lists like `{ VNode }`, `watch()` with a getter and an options table, and an `app:styles()` table from another module. Rivue's own source now type checks cleanly with both solvers.
- RivueUI: `utils.filterForClient` returned the unfiltered text when filtering failed. It now returns `""`.
- RivueRemote: payloads with NaN or infinity were accepted. They're now refused with `"payload_bad_number"`.
- RivueRemote: requests with a non-number id or an over-long action name were still processed and answered. They're now dropped.
- RivueRemote: `handle("__rivueStateSync", ...)` replaced the internal state sync handler. Names starting with `__rivue` are now reserved.
- RivueRemote: a client spamming an erroring action flooded the server log. Errors now warn at most once every 10 seconds per action.
- RivueRemote: a client spamming requests got a `"rate_limited"` reply for every one, so the server sent as much as it received. Refusals are now answered at most 30 times a second per player.
- RivueRemote: payloads that failed validation didn't count toward the byte budget, so a client could make the server scan large payloads for free. They now count.
- RivueRemote: the server had no listener on the `Response`, `Events` and `UnreliableEvents` remotes, so client fires to them were queued. They're now dropped.
- RivueRemote: new `exclusive` option for `handle()`. A player's second call while the first is running gets `"busy"`, which stops duplicate purchases and trades from overlapping calls.

## Install

Drag `RivueUI.rbxm` into `ReplicatedStorage`. `RivueRemote.rbxm` and `RivueRouter.rbxm` are optional and go next to it. `RivueDevTools.rbxm` goes in your Plugins folder.
