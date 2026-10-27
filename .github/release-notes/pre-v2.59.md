Pre-release.

| Package | Version | Stage |
|---|---|---|
| RivueUI | 0.9.0-rc.2 | release candidate |
| RivueRemote | 0.6.0-beta.1 | beta |
| RivueRouter | 0.2.0-beta.1 | beta |

## Breaking changes

- RivueRouter: `push`, `replace`, `back`, `forward` and `go` return `nil` when they moved, or a navigation failure that says why they didn't. They used to return `true` or `false`.
- RivueRouter: the first screen is entered when you call `app:use(router)`, and it goes through the guards. Until then `currentRoute` is `Router.START_LOCATION`.
- RivueRouter: pushing the route that's already open, with the same params, does nothing and returns a `duplicated` failure, as in Vue Router.
- RivueUI: an error in a computed's getter now reaches the code that read it, as in Vue. It used to be logged, and the value became `nil`.

## RivueRouter

Most of Vue Router 4, without paths or URLs:

- Route records with nested `children`, named views, `meta`, `redirect`, `alias`, a `props` option and `beforeEnter`.
- Guards in Vue Router's order: `onBeforeRouteLeave`, `beforeEach`, `onBeforeRouteUpdate`, `beforeEnter`, `beforeResolve`, then `afterEach`. A guard can redirect, and it can yield, for example while a dialog waits for the player.
- `RouterLink`, with `router-link-active` and `router-link-exact-active` style classes and a `custom` slot.
- A `RouterView` slot for wrapping screens in `Transition`, and a `name` prop for named views.
- `useRoute`, `useLink`, `go(n)`, `resolve`, `addRoute`, `removeRoute`, `hasRoute`, `getRoutes`, `scrollBehavior` (with `el`), `isReady` and `onError`.

## RivueRemote

- `Remote.send(player, name, payload)` and `Remote.sendAll(name, payload)` push from the server to `Remote.on()`. `{ unreliable = true }` uses an `UnreliableRemoteEvent`.
- `handle(..., { check = fn })` rejects a bad payload with `"invalid_payload"` before the handler runs.
- `Remote.use(fn)` runs before every handler. Returning `false` rejects the request with `"rejected"`.
- `Remote.action(name)` gives client and server one typed action.
- Requests carry a small number as their id instead of a GUID.

## RivueUI

- A component whose props didn't change skips the props update when its parent re-renders, like Vue's `shouldUpdateComponent`. Re-rendering 1000 unchanged rows takes about 40% less time.
- Refs keep their own dependency set, like Vue's `RefImpl`. Reading and writing `.value` is about 25% faster.

## Fixed

- RivueUI: a `Row` inside a `Column` lost its children when a sibling with prop defaults mounted during an update.
- RivueUI: a chain of more than about 98 computeds hit Luau's limit of about 200 nested C calls and read `nil`. Chains of 170 now work.
- RivueRemote: `fire()` sent payloads without checking them, so a function in the payload made `FireServer` error. It now checks them like `request()` and returns the reason.

## Docs and examples

- Guide 17, Screens and navigation, and a new GameMenu example built on RivueRouter.
- Shop now loads with `useAsync`, and Hud moves its health bar through a binding.
- An icon for each package.

## Install

Drag `RivueUI.rbxm` into `ReplicatedStorage`. `RivueRemote.rbxm` and `RivueRouter.rbxm` are optional and go next to it. `RivueDevTools.rbxm` goes in your Plugins folder.
