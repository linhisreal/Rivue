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
  <a href="docs/README.md"><img src="docs/assets/badges/docs.webp" height="32" alt="Read the docs"></a>
</p>

Vue-style components and fine-grained reactivity for Roblox UI. Only components that read a
changed value re-render, and only changed properties are written.

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

| | |
|---|---|
| RivueUI | the framework |
| [RivueRemote](docs/api/remote.md) | client/server calls, events and replicated state |
| [RivueRouter](docs/api/router.md) | screens, history and guards, after Vue Router 4 |
| [RivueDevTools](docs/DEVTOOLS.md) | Studio plugin for inspecting components |

## Installation

```toml
# wally.toml
[dependencies]
RivueUI = "linhisreal/rivue-ui@0.10.0-rc.1"
RivueRemote = "linhisreal/rivue-remote@0.8.0-beta.1" # optional
RivueRouter = "linhisreal/rivue-router@0.3.0-beta.1" # optional
```

pesde: `pesde add linhisreal/rivue_ui` (and `rivue_remote`, `rivue_router`). Or grab the `.rbxm`
files from the latest release and put them in `ReplicatedStorage`.

## Docs

[Docs home](docs/README.md) · [Guide](docs/GUIDE.md) · [API](docs/API.md) ·
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

[PolyForm Noncommercial 1.0.0](LICENSE.md), with an extra permission for games. You can use, fork,
port and change Rivue for noncommercial purposes, in closed or open source, as long as you keep the
credit notice and the license. Games built with Rivue may make money from their players, you can be
paid to build one, and you can sell a whole game to a new owner. What you can't do is make money
from Rivue itself: selling it or a fork, a framework or UI kit made from it, copies of a game's
project files, or paid services around it outside game work. Apps that only borrow game features
don't count as games. Forks stay under the same license. [LICENSE](LICENSE.md) has the exact terms.

Credit Rivue in the game's public description, or in an in-game credits screen any player can open
for free from the main menu or settings, for example:

```
UI built with Rivue by linhisreal
```
