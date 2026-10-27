Pre-release.

| Package | Version | Stage |
|---|---|---|
| RivueUI | 0.10.0-rc.1 | release candidate |
| RivueRemote | 0.8.0-beta.1 | beta |
| RivueRouter | 0.3.0-beta.1 | beta |

## Changed behaviour

- RivueUI: errors in event handlers and in watchers created in `setup()` now reach `onErrorCaptured`, `ErrorBoundary` and `app.config.errorHandler`, as in Vue. They used to only be logged, and a failing handler threw out of the event.
- RivueUI: `emit()` after a component unmounts does nothing, as in Vue.
- RivueRemote: `Remote.on()` called inside `setup()` disconnects when the component unmounts.
- RivueRouter: pushing the same route with a different `query` is a new navigation, not a `duplicated` failure.

## RivueUI

- `computed` getters get the value they returned last time, as in Vue 3.4.
- `Suspense` emits `pending`, `fallback` and `resolve`.
- `onEffectCleanup()`, from Vue 3.5.
- Kebab-case events: `emit("change-value")` calls an `onChangeValue` handler, as in Vue.
- `app.config.performance` marks each component's setup, render and patch in the MicroProfiler.
- With `app.config.devtools`, each app gets a `RivueDevTools` channel with a timeline of renders, emits, navigations and requests, and component roots list what they provide and inject.

## RivueRemote

- `Remote.state(name, initial)` on the server, with `set`, `setFor` and `get`. Clients read it with `Remote.useState`, `getState` or `onState`, and players who join later load the current values.
- `Remote.useRequest(name, options)` wraps `useAsync` around `Remote.request`.
- Requests show on the DevTools timeline.

## RivueRouter

- `route.query`, as in Vue Router.
- `backKeys` binds keys like `ButtonB` to `router.back()` while there's history.
- `Router.lazy(loader)` loads a route's component the first time it's visited.
- Navigations and the current route show in the DevTools.

## RivueDevTools

- A new look: tabs with counts, render and time pills on each row, details as cards, and a split you can drag.
- Highlight updates flashes an outline around components as they re-render.
- A Timeline tab with filters per kind and duration bars, and a Router tab with the route's params, query, meta and history.
- The details list what a component provides and injects.
- The filter keeps the parents of matching components.
- Settings for the slow-render threshold and timeline length, saved with the plugin.

## Fixed

- RivueUI: a `class` on slot content was looked up in the styles of the component it was passed to, such as `Row` or `Column`, instead of the component that wrote it.
- RivueUI: a `VirtualList` that shrank while scrolled down rendered nothing until the engine clamped its scroll.
- RivueUI: `array.move` to a position past the end deleted the item, and `array.insert` outside the list dropped it silently. `move` now moves to the end, and `insert` errors.
- RivueUI: `array.splice` with a negative start removed from the front. It now counts from the end, as in JavaScript.
- RivueRouter: a route `meta` that refers to itself crashed navigation when DevTools was on.
- RivueRouter: a router used by two apps went back two screens per press of a back key.
- RivueRemote: requests only showed on the DevTools timeline after something else had called `Remote.on`.
- RivueUI: `onEffectCleanup` inside a computed never ran, and `emit()` inside `onBeforeUnmount` or `onUnmounted` was dropped.
- RivueUI: a keyed list with duplicate keys left an extra Instance behind that was never removed.
- RivueUI: `onUpdated` ran on a parent before its children. Children now run first, as in Vue.
- RivueDevTools: releasing the mouse outside the window while dragging the divider kept the drag going.

## Install

Drag `RivueUI.rbxm` into `ReplicatedStorage`. `RivueRemote.rbxm` and `RivueRouter.rbxm` are optional and go next to it. `RivueDevTools.rbxm` goes in your Plugins folder.
