<p align="center">
  <img src="docs/assets/icon.webp" width="128" height="128" alt="Rivue logo">
</p>

<h1 align="center">Rivue</h1>

<p align="center">
  The Vue-style framework for Roblox UI.
</p>

<p align="center">
  <a href="https://create.roblox.com/store/models?keyword=Rivue"><img src="docs/assets/badges/creator-store.webp" height="32" alt="Get it on the Roblox Creator Store"></a>
  <a href="https://wally.run/package/linhisreal/rivue-ui"><img src="docs/assets/badges/wally.webp" height="32" alt="Install with Wally"></a>
  <a href="https://pesde.dev/packages/linhisreal/rivue_ui"><img src="docs/assets/badges/pesde.webp" height="32" alt="Install with pesde"></a>
  <a href="rokit.toml"><img src="docs/assets/badges/rokit.webp" height="32" alt="Tools pinned with Rokit"></a>
  <a href="https://luau.org"><img src="docs/assets/badges/luau.webp" height="32" alt="Written in Luau"></a>
  <a href="docs/README.md"><img src="docs/assets/badges/docs.webp" height="32" alt="Read the docs"></a>
</p>

Build Roblox UI with Vue 3's components, refs and computed values. Change state and Rivue writes
only the properties that changed.

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

More in [examples](examples). Runs in LocalScripts. The API can still change between releases.

## Features

| | |
|---|---|
| Reactivity | `ref`, `reactive`, `computed`, `watch`, `watchEffect`, effect scopes, readonly/shallow variants |
| Components | `setup` + `render(ctx)`, props, emits, slots, provide/inject, all lifecycle hooks |
| Styling | style classes; `layout`, `flex`, `cornerRadius`, `padding`, `stroke` props |
| Built-ins | `Transition`, `TransitionGroup`, `KeepAlive`, `Teleport`, `Suspense`, `VirtualList`, `Dialog`, `ErrorBoundary`, `Row`/`Column`/`Spacer` |
| Roblox | tweens, springs, viewport/input composables, gamepad selection, attribute refs |
| Tooling | strict types, a DevTools plugin, `testing.render` |

Differences from Vue are in the [cheat sheet](docs/VUE.md).

## Packages

<table>
<tr><td width="72"><img src="docs/assets/packages/rivue-ui.webp" width="56" height="56" alt="RivueUI"></td>
<td>RivueUI: components, reactivity, styling and the built-ins.</td></tr>
<tr><td><img src="docs/assets/packages/rivue-remote.webp" width="56" height="56" alt="RivueRemote"></td>
<td><a href="docs/api/remote.md">RivueRemote</a>: checked client/server calls, events and replicated state.</td></tr>
<tr><td><img src="docs/assets/packages/rivue-router.webp" width="56" height="56" alt="RivueRouter"></td>
<td><a href="docs/api/router.md">RivueRouter</a>: screens with history, guards and nested routes.</td></tr>
<tr><td><img src="docs/assets/packages/rivue-devtools.webp" width="56" height="56" alt="RivueDevTools"></td>
<td><a href="docs/DEVTOOLS.md">RivueDevTools</a>: props, state, renders and network, live during a playtest.</td></tr>
</table>

## Installation

Wally, pesde, Rojo or a Studio model file: see [Installation](docs/INSTALLATION.md). With Wally:

```toml
RivueUI = "linhisreal/rivue-ui@0.10.0-rc.2"
```

## Docs

[Docs home](docs/README.md) · [Installation](docs/INSTALLATION.md) · [Guide](docs/GUIDE.md) · [API](docs/API.md) ·
[Coming from Vue](docs/VUE.md) · [Coming from React-lua or Fusion](docs/COMING-FROM-REACT.md) ·
[Architecture](docs/ARCHITECTURE.md)

## Contributing

```sh
rokit install
lune run test         # all suites, offline
lune run check-docs   # links and API examples
lune run build        # packages and the dev place into build/
rojo serve            # the dev place in Studio
```

`lune run version <package> <version>` bumps a package, and `lune run license` copies LICENSE.md
into each package. Releases: [docs/RELEASING.md](docs/RELEASING.md).

## License

<a href="LICENSE.md">
<img src="docs/assets/license-lockup.webp" height="110" alt="Rivue License, based on PolyForm Noncommercial 1.0.0, with the games permission">
</a>

[PolyForm Noncommercial 1.0.0](LICENSE.md) with a games permission:

- Games made with Rivue can earn money, and you can be paid to build one or sell one.
- You can't make money from Rivue itself: selling it, a fork, a UI kit made from it, a game's
  project files, or paid services around it outside game work. Apps aren't games.
- Keep the license and credit notice. Forks stay under the same license.

Credit it in the game's description or an in-game credits screen any player can open, like
`UI built with Rivue by linhisreal`. [LICENSE](LICENSE.md) has the exact terms.
