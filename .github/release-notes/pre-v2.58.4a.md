Pre-release. From this release on, each package has its own version:

| Package | Version | Stage |
|---|---|---|
| RivueUI (the UI framework) | 0.9.0-rc.1 | release candidate |
| RivueRemote | 0.5.0-beta.1 | beta |
| RivueRouter | 0.1.0-beta.1 | beta, new |

## Breaking changes

- The UI package is now called **RivueUI**: `require(ReplicatedStorage.Packages.RivueUI)`, Wally `linhisreal/rivue-ui`, pesde `linhisreal/rivue_ui`, release file `RivueUI.rbxm`. The variable in examples is still `Rivue`.
- The router is its own package, **RivueRouter**, next to RivueUI the way Vue Router sits next to Vue. `Rivue.createRouter`, `RouterView` and `useRouter` are now `Router.createRouter`, `Router.RouterView` and `Router.useRouter`.
- `onErrorCaptured` stops an error when it returns `false`, as in Vue. It used to be `true`.
- Children run `onUnmounted` before their parent, as in Vue.

## New

- `Rivue.bind(fn)`, or a ref as a property value, updates that one property without re-rendering the component. Good for timers, springs and bars.
- Built-in components: `Dialog`, `ErrorBoundary`, and `Row`, `Column` and `Spacer` for layout.
- `Rivue.transitions.fade`, `slide` and `pop`, ready-made props for `Transition`.
- `useAsync` for server calls, which also holds a surrounding `Suspense` on its fallback while loading.
- `useGamepadFocus` selects a button when a menu opens on a gamepad, and gives the selection back after.
- `defineAsyncComponent` takes `onError(err, retry, fail, attempts)`, so a failed load can try again.
- Several models on one component: `models = { color = colorRef, opacity = opacityRef }`.
- `defineModel` works as local state when the parent passes no model, and `useSpring` animates UDim, UDim2 and Color3.
- Test helpers: `Rivue.testing.render`, `getByText`, `click` and `typeInto`.
- DevTools: render time and cause, sort, pause and reset, an Events tab, live state editing, hover outlines, Open source, folding, and Studio's light or dark theme.

## Fixed

- A watcher that wrote NaN back to its own ref ran every frame.
- `useStyles` ignored a theme provided as a ref.
- With DevTools on, state read by attribute listeners became a dependency of the render.
- A transition whose goals included a property the element doesn't have didn't play at all.

## Install

Drag `RivueUI.rbxm` into `ReplicatedStorage`. `RivueRemote.rbxm` and `RivueRouter.rbxm` are optional and go next to it. `RivueDevTools.rbxm` goes in your Plugins folder.
