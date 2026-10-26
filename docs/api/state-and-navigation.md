[Docs](../README.md) › [API](../API.md) › **State and navigation**

# State and navigation

**Learn it:** [Guide 14: Organising state](../guide/14-state-architecture.md)

Shared stores, moving between screens, and loading data that takes a while to arrive.

- [defineStore()](#definestore)
- [createRouter()](#createrouter)
- [RouterView](#routerview)
- [useRouter()](#userouter)
- [useAsync()](#useasync)

---

## defineStore()

Shared state for the whole game UI, like Vue's Pinia. You write a setup function once; every
component that calls the store gets the same one.

- **Example**

  A wallet any screen can read and spend from:

  ```lua
  local useWallet = Rivue.defineStore("wallet", function()
  	local coins = Rivue.ref(100)
  	local canAffordSword = Rivue.computed(function()
  		return coins.value >= 50
  	end)
  	return {
  		coins = coins,
  		canAffordSword = canAffordSword,
  		spend = function(amount: number)
  			coins.value -= amount
  		end,
  	}
  end)

  local CoinLabel = Rivue.defineComponent({
  	name = "CoinLabel",
  	render = function()
  		local wallet = useWallet()
  		return h("TextLabel", { Text = `{wallet.coins} coins` })
  	end,
  })

  useWallet().spend(30)
  print(useWallet().coins) -- 70
  ```

- **Details**

  - The setup function runs the first time the store is used. Refs, computeds and watchers in it
    live as long as the store, not as long as whichever component used it first.
  - Refs and computeds read and write without `.value`: `wallet.coins`, `wallet.coins = 5`.
  - `store["$id"]` is the id. `store["$dispose"]()` stops the store's watchers and forgets it,
    so the next call starts fresh, which is handy between tests.
  - Two `defineStore` calls with the same id share one store. Studio warns about it.

- **Type**

  ```lua
  function defineStore<T>(id: string, setup: () -> T): () -> T
  ```

---

## createRouter()

Screens with history, like a small Vue Router: you name each screen, move between them with
`push`, and go `back` and `forward`. There are no URLs, since Roblox UI has none.

- **Example**

  A menu that opens an item screen and comes back:

  ```lua
  local Home = Rivue.defineComponent({
  	name = "Home",
  	setup = function()
  		local router = Rivue.useRouter()
  		return {
  			open = function()
  				router.push("item", { id = 7 })
  			end,
  		}
  	end,
  	render = function(ctx)
  		return h("TextButton", { Text = "Open item 7", onClick = ctx.open })
  	end,
  })

  local Item = Rivue.defineComponent({
  	name = "Item",
  	props = { id = { type = "number", required = true } },
  	setup = function()
  		local router = Rivue.useRouter()
  		return { back = router.back }
  	end,
  	render = function(ctx)
  		return h("TextButton", { Text = `Item {ctx.id}, tap to go back`, onClick = ctx.back })
  	end,
  })

  local router = Rivue.createRouter({
  	routes = { home = Home, item = Item },
  	initial = "home",
  })

  local App = Rivue.defineComponent({
  	name = "App",
  	render = function()
  		return h("ScreenGui", { ResetOnSpawn = false }, { h(Rivue.RouterView) })
  	end,
  })

  local app = Rivue.createApp(App)
  app:use(router)
  app:mount(Instance.new("Folder"))
  ```

- **Details**

  - `push(name, params)` adds a screen to the history. `params` reach the screen's component as
    props. Pushing after going back drops the screens you could have gone forward to.
  - `replace(name, params)` swaps the current screen, so `back` skips it. Good for a login screen
    you never want to return to.
  - `back()` and `forward()` return `false` when there's nowhere to go. `canGoBack` and
    `canGoForward` are refs, for greying out buttons.
  - `current` is a ref holding `{ name, params }`.
  - `beforeEach(guard)` runs before every move. Return `false` from it to cancel, for example
    while a form has unsaved changes. It returns a function that removes the guard.
  - An unknown route name errors and lists the routes there are.

- **Type**

  ```lua
  function createRouter(options: {
  	routes: { [string]: ComponentDef },
  	initial: string,
  	initialParams: { [string]: any }?,
  }): Router

  type Router = {
  	current: Ref<{ name: string, params: { [string]: any } }>,
  	canGoBack: Ref<boolean>,
  	canGoForward: Ref<boolean>,
  	push: (name: string, params: { [string]: any }?) -> boolean,
  	replace: (name: string, params: { [string]: any }?) -> boolean,
  	back: () -> boolean,
  	forward: () -> boolean,
  	beforeEach: (guard: (to: Route, from: Route) -> boolean?) -> () -> (),
  }
  ```

---

## RouterView

Renders the current screen, with the route's params as props. Put it where screens should appear.

- **Example**

  Keep the shop's scroll position and search when the player opens an item and comes back:

  ```lua
  local Layout = Rivue.defineComponent({
  	name = "Layout",
  	render = function()
  		return h("Frame", { Size = UDim2.fromScale(1, 1) }, {
  			h(Rivue.RouterView, { keepAlive = true }),
  		})
  	end,
  })
  ```

- **Details**

  With `keepAlive = true`, screens you leave stay alive in a [KeepAlive](builtins.md#keepalive),
  so their state is still there when you come back. Two routes that share a component still get
  separate instances.

- **Props**

  ```lua
  type RouterViewProps = {
  	keepAlive: boolean?,
  }
  ```

---

## useRouter()

The router installed with `app:use(router)`. Call it in `setup()`.

- **Example**

  A back button that hides when there's nothing to go back to:

  ```lua
  local BackButton = Rivue.defineComponent({
  	name = "BackButton",
  	setup = function()
  		local router = Rivue.useRouter()
  		return { canGoBack = router.canGoBack, back = router.back }
  	end,
  	render = function(ctx)
  		return h("TextButton", { Text = "Back", Visible = ctx.canGoBack, onClick = ctx.back })
  	end,
  })
  ```

- **Details**

  Errors if no router was installed, so a missing `app:use(router)` shows up straight away.

- **Type**

  ```lua
  function useRouter(): Router
  ```

---

## useAsync()

Runs something that yields, like a RemoteFunction call or a
[RivueRemote request](remote.md#remoterequest), and keeps its result, loading state and error
in refs.

- **Example**

  A shop that loads its items, with a loading label and a retry button:

  ```lua
  local function fetchItems(category: string): { string }
  	task.wait(0.1) -- stands in for a request to the server
  	return { `{category} sword`, `{category} shield` }
  end

  local Shop = Rivue.defineComponent({
  	name = "Shop",
  	setup = function()
  		local items = Rivue.useAsync(fetchItems, { args = { "Iron" }, initial = {} })
  		return { items = items.data, loading = items.loading, failed = items.error, retry = items.refresh }
  	end,
  	render = function(ctx)
  		if ctx.loading then
  			return h("TextLabel", { Text = "Loading..." })
  		elseif ctx.failed then
  			return h("TextButton", { Text = "Couldn't load, tap to retry", onClick = ctx.retry })
  		end
  		return h("TextLabel", { Text = table.concat(ctx.items, ", ") })
  	end,
  })
  ```

- **Details**

  - It runs straight away with `args`, unless `immediate = false`. `run(...)` runs it again
    with new arguments, `refresh()` with the last ones.
  - Only the newest run's result lands. A slow answer to an old request never overwrites a
    newer one.
  - An error goes into `error` as a string, and `data` keeps its last good value.
  - Called in `setup()`, results that arrive after the component unmounts are dropped.

- **Type**

  ```lua
  function useAsync<T>(fn: (...any) -> T, options: {
  	immediate: boolean?, -- default true
  	args: { any }?,
  	initial: T?,
  }?): {
  	data: Ref<T?>,
  	loading: Ref<boolean>,
  	error: Ref<string?>,
  	run: (...any) -> (),
  	refresh: () -> (),
  }
  ```
