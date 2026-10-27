<p align="center">
  <img src="docs/assets/icon.webp" width="128" height="128" alt="Rivue logo">
</p>

<h1 align="center">Rivue</h1>

<p align="center">
  Vue 3's component model for Roblox UI, in Luau.
</p>

<p align="center">
  <a href="https://create.roblox.com/store/models?keyword=Rivue"><img src="docs/assets/badges/creator-store.webp" height="32" alt="Get it on the Roblox Creator Store"></a>
  <a href="https://wally.run/package/linhisreal/rivue-ui"><img src="docs/assets/badges/wally.webp" height="32" alt="Install with Wally"></a>
  <a href="https://pesde.dev/packages/linhisreal/rivue_ui"><img src="docs/assets/badges/pesde.webp" height="32" alt="Install with pesde"></a>
  <a href="rokit.toml"><img src="docs/assets/badges/rokit.webp" height="32" alt="Tools pinned with Rokit"></a>
  <a href="https://luau.org"><img src="docs/assets/badges/luau.webp" height="32" alt="Written in Luau"></a>
  <a href="https://linhisreal.github.io/Rivue/"><img src="docs/assets/badges/docs.webp" height="32" alt="Read the docs"></a>
</p>

<p align="center">
  <a href="https://github.com/linhisreal/Rivue/actions/workflows/build.yml"><img src="https://github.com/linhisreal/Rivue/actions/workflows/build.yml/badge.svg" alt="CI"></a>
</p>

Stop writing `label.Text = ...` by hand. Write what the screen should look like for the current
state, and Rivue keeps the Instances in sync: when a value changes, only the components that read
it re-render, and only the properties that changed get written.

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
local h = Rivue.h

local Counter = Rivue.defineComponent({
	name = "Counter",
	setup = function()
		local count = Rivue.ref(0)
		return {
			count = count,
			increment = function()
				count.value += 1
			end,
		}
	end,
	render = function(ctx)
		return h("TextButton", {
			Size = UDim2.fromOffset(200, 50),
			Text = `Clicked {ctx.count} times`,
			onClick = ctx.increment,
		})
	end,
})

Rivue.createApp(Counter):mountToPlayerGui(game.Players.LocalPlayer)
```

Want something bigger? [TodoList](examples/components/TodoList.luau) has a text box, a keyed list
and styles, and there are more in [examples](examples).

Rivue is still young, so the API can change between releases. It runs in LocalScripts.

## Why Rivue

Know Vue? Then you know most of Rivue already: `ref`, `computed`, `watch`, and components with
props, emits, slots and provide/inject. The [cheat sheet](docs/VUE.md) covers the differences.

Updates are tracked per value. A parent re-rendering doesn't drag its children along unless their
props changed, and you don't need `memo` to get that.

And it was made for Roblox UI from the start. Colours and fonts live in style classes, `layout`
and `flex` replace the usual UIListLayout boilerplate, and tweens, springs, `Transition` and
`VirtualList` come built in.

## Features

| | |
|---|---|
| Reactivity | `ref`, `reactive`, `computed`, `watch`, `watchEffect`, effect scopes, readonly and shallow variants |
| Components | `setup` + `render(ctx)`, validated props, emits, slots, provide/inject, every lifecycle hook |
| Styling | style classes per app or component; `layout`, `flex`, `cornerRadius`, `padding`, `stroke` props |
| Performance | keyed diffing, batched parent-first updates, `Rivue.bind` for properties that change every frame, `memo`, optional Instance pool |
| Built-ins | `Transition` with fade/slide/pop presets, `TransitionGroup`, `KeepAlive`, `Teleport`, `Suspense`, `VirtualList`, `Dialog`, `ErrorBoundary`, `Row`/`Column`/`Spacer`, `useAsync` |
| Roblox | tweens, springs, viewport and input-type composables, gamepad selection, attribute refs, tags |
| Studio | warnings that name the component chain, roots named after components, `app:printTree()`, a DevTools plugin, `testing.render` for tests |
| Types | strict Luau with exported types like `Rivue.Ref<T>` and `Rivue.VNode` |

## Packages

RivueUI is the framework. The others are optional, the way Vue Router is optional next to Vue, and
each has its own version.

<table>
<tr>
<td width="72"><img src="docs/assets/packages/rivue-ui.webp" width="56" height="56" alt="RivueUI"></td>
<td><b>RivueUI</b>: components, reactive state, style classes, layout, transitions and the
built-in components. Everything above is RivueUI.</td>
</tr>
<tr>
<td><img src="docs/assets/packages/rivue-remote.webp" width="56" height="56" alt="RivueRemote"></td>
<td><b><a href="docs/api/remote.md">RivueRemote</a></b>: calls between client and server over
RemoteEvents. The server answers actions with <code>Remote.handle</code>, and the client calls
<code>Remote.request</code> and gets the result back, or the reason it failed (a timeout, a rate
limit, an error in the handler). <code>fire</code> and <code>on</code> send events that need no
answer. Payloads are checked for size, depth and types before they're sent, and every action has a
per-player rate limit. It doesn't depend on RivueUI, so the server can use it alone.</td>
</tr>
<tr>
<td><img src="docs/assets/packages/rivue-router.webp" width="56" height="56" alt="RivueRouter"></td>
<td><b><a href="docs/api/router.md">RivueRouter</a></b>: screens with a history, following Vue
Router 4. Named and nested routes, <code>RouterView</code> and <code>RouterLink</code>, guards that
run before every move and can wait for the player to answer a dialog, redirects, aliases,
<code>meta</code>, routes added while the game runs, and scroll positions put back on Back. Routes
have names where Vue Router has URLs.</td>
</tr>
<tr>
<td><img src="docs/assets/packages/rivue-devtools.webp" width="56" height="56" alt="RivueDevTools"></td>
<td><b><a href="docs/DEVTOOLS.md">RivueDevTools</a></b>: a Studio plugin that lists the components
on screen during a playtest, with their props and state, how often and why they rendered, and the
events they emitted. You can edit state while the game runs.</td>
</tr>
</table>

## Installation

Rivue is a single ModuleScript with a `runtime` folder inside, and it goes in `ReplicatedStorage`.
Use whichever install you already use for other packages.

**With Wally**, add it to your `wally.toml` and run `wally install`:

```toml
[dependencies]
RivueUI = "linhisreal/rivue-ui@0.9.0-rc.1"
RivueRemote = "linhisreal/rivue-remote@0.5.0-beta.1" # optional, for client/server calls
RivueRouter = "linhisreal/rivue-router@0.1.0-beta.1" # optional, for screens and back/forward
```

**With pesde**, run `pesde add linhisreal/rivue_ui` (and `linhisreal/rivue_remote` or
`linhisreal/rivue_router` if you want them).

**With Rojo**, add this repo as a git submodule and point your project at the package:

```json
"ReplicatedStorage": {
  "RivueUI": { "$path": "vendor/Rivue/packages/rivue-ui" }
}
```

**Without Rojo**, download `RivueUI.rbxm` from the latest
[release](https://github.com/linhisreal/Rivue/releases) and drag it into `ReplicatedStorage`.
There's also `RivueUI.min.rbxm` (same code, comments stripped), and the optional `RivueRemote.rbxm`
and `RivueRouter.rbxm`, which go next to it.

## Docs

They're at [linhisreal.github.io/Rivue](https://linhisreal.github.io/Rivue/). If you'd rather read
them on GitHub, the [docs home](docs/README.md) has an "I want to…" table that points you at the
right page.

[Guide](docs/GUIDE.md) · [Examples](examples) · [API reference](docs/API.md) ·
[Coming from Vue](docs/VUE.md) ·
[Coming from React-lua or Fusion](docs/COMING-FROM-REACT.md) · [DevTools](docs/DEVTOOLS.md) ·
[Architecture](docs/ARCHITECTURE.md)

## Contributing

Tools are pinned in `rokit.toml` ([Rokit](https://github.com/rojo-rbx/rokit)):

```sh
rokit install
lune setup                        # editor types for the Lune scripts
lune run test                     # all suites, without Studio
lune run check-docs               # links resolve and every API example runs
lune run build                    # the packages and the dev place, into build/
lune run version rivue-ui 0.9.0-rc.2 # bump one package
rojo serve                        # the dev place in Studio
```

CI runs StyLua and luau-lsp, checks the packages for Wally and pesde, and runs every test suite a
second time inside a real Roblox server. How releases and publishing work is in
[docs/RELEASING.md](docs/RELEASING.md).

```
packages/rivue-ui/         the UI framework                 Wally, pesde, RivueUI.rbxm
packages/rivue-remote/     client/server calls              Wally, pesde, RivueRemote.rbxm
packages/rivue-router/     screens and history              Wally, pesde, RivueRouter.rbxm
packages/rivue-devtools/   Studio plugin                    RivueDevTools.rbxm
dev/                       the dev place: test runner, demo app, examples, stress test
examples/                  example components, tested in tests/Examples.test.luau
tests/                     test suites; tests/offline is the Lune harness
docs/                      the Guide, API reference and docs site
default.project.json       the dev place (rojo serve)
pesde.toml                 the pesde workspace
```

## License

<a href="https://polyformproject.org/licenses/noncommercial/1.0.0"><img src="docs/assets/polyform-logo.png" height="48" alt="PolyForm"></a>

[PolyForm Noncommercial 1.0.0](LICENSE.md), with an extra permission for games. You can use, fork,
port and change Rivue, closed source or open, as long as you keep the credit notice. You can't
sell Rivue's code or use it commercially. Games built with Rivue may make money, if they credit
it. See [LICENSE](LICENSE.md) for the exact terms.

Games that use Rivue need a credit in the description or an in-game credits screen, for
example:

```
UI built with Rivue (github.com/linhisreal/Rivue)
```
