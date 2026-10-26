Pre-release. Everything since `v2.1.2c`. The API can still change before the next stable release.

## Install

Drag `Rivue.rbxm` into `ReplicatedStorage`. `Rivue.min.rbxm` is the same without comments. With Rojo, point at `rivue.project.json` (see the [README](https://github.com/linhisreal/Rivue#installation)).

## License change

Rivue is now under **PolyForm Noncommercial 1.0.0** with an extra permission for games (previously GPL-3.0). You can use, fork and port it, closed source or open, if you keep the credit notice. Selling Rivue's code is not allowed. Games built with Rivue may make money if they credit it. See [LICENSE.md](https://github.com/linhisreal/Rivue/blob/main/LICENSE.md).

## New

- **Components:** `setup` + `render(ctx)`, named and scoped slots, `defineModel`, `expose`, more of Vue's APIs, every lifecycle hook.
- **Built-ins:** `Transition`, `TransitionGroup`, `KeepAlive` (keeps state), `Teleport`, `Suspense`, `VirtualList`, async components.
- **Styling and layout:** style classes per app or component (`class = "card"`), `layout` and `flex` props, `cornerRadius`, `padding`, `stroke`.
- **Lists:** `Rivue.array` helpers (`push`, `removeWhere`, `sort`, …) that update the UI.
- **Roblox:** `useViewportSize`, `useInputType`, `useSafeArea`, `useSelection`, `useTween`, `useSpring`, `attributeRef`, tags; `Remote` with a server side and per-player rate limits.
- **Testing:** `Rivue.testing.trigger(element, "onClick")` to click buttons and submit text boxes from tests.
- **Debugging:** errors and warnings name the component chain, roots are named after their component, `app:printTree()`.
- **Types:** strict Luau throughout, with exported types like `Rivue.Ref<T>`.

## Faster

- Component updates are batched and run parents first, once per change set.
- Fewer engine calls: unchanged props aren't written, `IsA` results are cached, handlers are swapped instead of reconnected.
- Prepending or moving a list row writes one `LayoutOrder` instead of renumbering every row.
- Pooled Instances are reused correctly.

## Fixed

- Computed invalidation, watch semantics, and deep watchers missing added keys.
- Props are reactive; slots and fallthrough attrs update when the parent re-renders.
- Mixed keyed lists, list `LayoutOrder`, TextBox `Text` handling.
- `array.indexOf`, `removeWhere` and `splice` edge cases.
- Drag directive leak, click-outside hit testing, KeepAlive and async component state.

## Docs

- A 16-chapter Guide: basics (1–11) and advanced topics (12–16: composables, component patterns, state, performance, testing).
- An API reference where every entry has a runnable example, checked in CI.
- A Vue cheat sheet, tested examples, and a demo app.

## Tooling

- Toolchain pinned with Rokit; tests run outside Studio with Lune, and in CI with format, type and docs checks.
