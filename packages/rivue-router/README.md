# RivueRouter

Screen navigation for [Rivue](https://github.com/linhisreal/Rivue), like a small Vue Router: named
routes, params passed to the screen as props, back and forward history, and guards that can cancel
a move.

Install Rivue too. RivueRouter uses the copy of Rivue your game already has, so keep both in the
same Packages folder (Wally and pesde do this), or both in ReplicatedStorage.

```lua
local Router = require(ReplicatedStorage.Packages.RivueRouter)

local router = Router.createRouter({
	routes = { lobby = Lobby, shop = Shop },
	initial = "lobby",
})
app:use(router)
```

Docs: https://linhisreal.github.io/Rivue/api/router
