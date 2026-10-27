<img src="../../docs/assets/packages/rivue-router.webp" width="96" height="96" alt="RivueRouter">

# RivueRouter

Screen navigation for [Rivue](../../README.md), modelled on Vue Router 4:
named and nested routes, named views, `RouterView` and `RouterLink`, navigation guards that can
wait for the player, `redirect`, `alias`, `meta`, dynamic routes and `scrollBehavior`. Routes have
names instead of paths, since Roblox UI has no URLs.

Install RivueUI too. RivueRouter uses the copy of RivueUI your game already has, so keep both in the
same Packages folder (Wally and pesde do this), or both in ReplicatedStorage.

```lua
local Router = require(ReplicatedStorage.Packages.RivueRouter)

local router = Router.createRouter({
	routes = { lobby = Lobby, shop = Shop },
	initial = "lobby",
})
app:use(router)
```

Docs: [RivueRouter API](../../docs/api/router.md)
