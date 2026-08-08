[Docs](../README.md) › [API](../API.md) › **RivueRemote**

# RivueRemote

**Learn it:** [Guide 8: Sharing state and the server](../guide/08-state-and-server.md)

Request/response and events between client and server over RemoteEvents, with payload validation
and per-player rate limits. It's a separate package from Rivue, which only does UI: put
`RivueRemote` next to `RivueUI` in ReplicatedStorage. All examples assume
`local Remote = require(game.ReplicatedStorage.RivueRemote)`.

- [Remote.setupServer()](#remotesetupserver)
- [Remote.handle()](#remotehandle)
- [Remote.request()](#remoterequest)
- [Remote.fire()](#remotefire)
- [Remote.on()](#remoteon)
- [Remote.send() and Remote.sendAll()](#remotesend-and-remotesendall)
- [Remote.use()](#remoteuse)
- [Remote.action()](#remoteaction)
- [Remote.state()](#remotestate)
- [Remote.useState(), getState() and onState()](#remoteusestate-getstate-and-onstate)
- [Remote.useRequest()](#remoteuserequest)
- [Remote.configure()](#remoteconfigure)
- [Remote.stats()](#remotestats)
- [Payloads and errors](#payloads-and-errors)

---

## Remote.setupServer()

Creates the RemoteEvents RivueRemote uses. Call it once in a server script at startup, so clients
never wait for them.

- **Example**

  <!-- server -->
  ```lua
  -- ServerScriptService/Main.server.luau
  Remote.setupServer()
  ```

- **Details**

  The events live in `ReplicatedStorage.RemoteEvents`: two for requests and replies, and two that
  carry everything `send()` and `sendAll()` push, however many event names the game uses. Clients
  wait up to 5 seconds for them, and warn if the server never created them.

- **Type**

  ```lua
  function Remote.setupServer()
  ```

---

## Remote.handle()

Defines what the server does when a client sends an action, like `"shop:buy"`. Whatever your handler
returns is sent back as the response.

- **Example**

  <!-- server -->
  ```lua
  local Players = game:GetService("Players")
  local PRICES = { sword = 100, shield = 75 }

  Remote.setupServer()

  Remote.handle("shop:buy", function(player, payload)
  	local price = PRICES[payload.id]
  	local coins = player:GetAttribute("Coins") or 0
  	if not price or coins < price then
  		return { ok = false, reason = "not_enough_coins" }
  	end
  	player:SetAttribute("Coins", coins - price)
  	return { ok = true }
  end, {
  	maxPerSecond = 5,
  	check = function(payload)
  		return type(payload) == "table" and type(payload.id) == "string"
  	end,
  })
  ```

- **Details**

  - **Errors.** If the handler errors, the error is logged on the server and the client gets
    `"handler_error"`, so internal details never leak to clients.
  - **Rate limits.** Each player can call each action `maxPerSecond` times per second (default
    30, `0` disables it). On top of that, each player has a budget across all actions, set with
    [`configure()`](#remoteconfigure). Calls over either limit get `"rate_limited"`.
  - **Payloads come from the client.** Never trust them. `check` gets the payload before the
    handler does; if it returns anything but `true` (or errors), the client gets
    `"invalid_payload"` and the handler doesn't run.

- **Type**

  ```lua
  function Remote.handle(
  	action: string,
  	handler: (player: Player, payload: unknown) -> unknown,
  	options: {
  		maxPerSecond: number?,
  		check: ((payload: unknown) -> boolean)?,
  	}?
  )
  ```

---

## Remote.request()

Asks the server something and waits for the answer, like a function call across the network. It
yields, so call it from `task.spawn` or a watcher, never from render.

- **Example**

  A buy button with a pending state and an error message:

  ```lua
  local BuyButton = Rivue.defineComponent({
  	name = "BuyButton",
  	props = { itemId = { type = "string", required = true } },
  	setup = function(props)
  		local pending = Rivue.ref(false)
  		local message = Rivue.ref("")
  		return {
  			pending = pending,
  			message = message,
  			buy = function()
  				pending.value = true
  				task.spawn(function() -- request yields, so never call it from render
  					local result, err = Remote.request("shop:buy", { id = props.itemId })
  					pending.value = false
  					if err then
  						message.value = `Error: {err}`
  					elseif (result :: any).ok then
  						message.value = "Bought!"
  					else
  						message.value = `Can't buy: {(result :: any).reason}`
  					end
  				end)
  			end,
  		}
  	end,
  	render = function(ctx)
  		return h("TextButton", {
  			Text = if ctx.pending then "Buying..." else `Buy {ctx.message}`,
  			Active = not ctx.pending,
  			onClick = ctx.buy,
  		})
  	end,
  })
  ```

- **Details**

  Returns `(data, nil)` on success or `(nil, err)` on failure. `timeout` is in seconds (default
  10).

- **Type**

  ```lua
  function Remote.request(action: string, payload: unknown, timeout: number?): (unknown?, string?)
  ```

---

## Remote.fire()

Tells the server something without waiting for a reply, like "the player opened the shop".

- **Example**

  ```lua
  -- Client
  Remote.fire("settings:save", { music = 0.5, sfx = 1 })
  ```

  <!-- server -->
  ```lua
  -- Server
  Remote.handle("settings:save", function(player, payload)
  	print(player.Name, "saved settings", payload)
  	return nil
  end)
  ```

- **Details**

  The server's [`handle()`](#remotehandle) runs as usual, and its return value is discarded.
  The payload is checked the same way `request()` checks it. If it can't be sent, `fire()` warns
  and returns the reason, such as `"payload_unsafe_type"`, instead of sending it.

- **Type**

  ```lua
  function Remote.fire(action: string, payload: unknown): string?
  ```

---

## Remote.on()

Listens on the client for events the server sends, like a new message or a price update.

- **Example**

  ```lua
  -- Client: show announcements
  local announcement = Rivue.ref("")

  local conn = Remote.on("Announcement", function(text)
  	announcement.value = text
  end)

  -- Server
  -- Remote.sendAll("Announcement", "Double coins for 10 minutes!")
  ```

- **Details**

  The server sends with [`send()` or `sendAll()`](#remotesend-and-remotesendall). Each callback
  runs in its own thread, as with a RemoteEvent.

  Called inside a component's `setup()` (or an effect scope), the listener disconnects when the
  component unmounts, like a Vue composable. RivueRemote finds the game's RivueUI for this the
  same way RivueRouter does. Anywhere else, call `Disconnect()` when you're done.

- **Type**

  ```lua
  type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }

  function Remote.on(name: string, callback: (payload: any) -> ()): Connection
  ```

---

## Remote.send() and Remote.sendAll()

Sends something from the server to one player, or to everyone, without waiting for a reply.
Clients receive it with [`Remote.on()`](#remoteon).

- **Example**

  <!-- server -->
  ```lua
  local Players = game:GetService("Players")

  Remote.setupServer()

  -- One player: their inventory changed
  local function giveItem(player: Player, id: string)
  	Remote.send(player, "inventory:added", id)
  end

  -- Everyone: a server-wide announcement
  Remote.sendAll("Announcement", "Double coins for 10 minutes!")

  -- Many times a second: the round timer, where a dropped update doesn't matter
  Remote.sendAll("round:time", 90, { unreliable = true })
  ```

- **Details**

  - Sends wait until the end of the frame, and everything one player is sent in a frame goes as
    one network message, in the order it was sent. `Remote.flush()` sends the queue straight away.
  - The payload is checked like a request's. If it can't be sent, it warns and returns the reason.
  - `unreliable = true` sends at once through an `UnreliableRemoteEvent`, outside the batch.
    Updates can be dropped or arrive out of order, and Roblox drops unreliable payloads over about
    900 bytes, but they cost less. Use it for values that change many times a second.

- **Type**

  ```lua
  function Remote.send(player: Player, name: string, payload: unknown, options: { unreliable: boolean? }?): string?
  function Remote.sendAll(name: string, payload: unknown, options: { unreliable: boolean? }?): string?
  function Remote.flush()
  ```

---

## Remote.use()

Runs a function on the server before every handler, for checks every action shares: banned
players, data that hasn't loaded yet, logging.

- **Example**

  <!-- server -->
  ```lua
  local loaded: { [Player]: boolean } = {}

  Remote.use(function(player, action, _payload)
  	if not loaded[player] then
  		return false -- the client gets "rejected"
  	end
  	return true
  end)
  ```

- **Details**

  It runs after the rate limit and the payload checks, and before the action's `check`. Returning
  `false` rejects the request with `"rejected"`. An error is logged and the client gets
  `"handler_error"`. It returns a function that removes it.

- **Type**

  ```lua
  function Remote.use(middleware: (player: Player, action: string, payload: unknown) -> boolean?): () -> ()
  ```

---

## Remote.action()

One action that both sides share, so the client's request and the server's handler agree on its
name and its types. Put it in a ModuleScript in ReplicatedStorage and require it from both.

- **Example**

  ```lua
  -- ReplicatedStorage/Actions.luau
  local Actions = {
  	buy = Remote.action("shop:buy") :: Remote.Action<{ id: string }, boolean>,
  }

  -- Client
  task.spawn(function()
  	local bought, err = Actions.buy.request({ id = "sword" })
  end)

  -- Server
  -- Actions.buy.handle(function(player, payload)
  -- 	return payload.id == "sword"
  -- end)
  ```

- **Details**

  `request`, `fire` and `handle` work like `Remote.request`, `Remote.fire` and `Remote.handle`,
  with the action's name filled in and its payload and result typed.

- **Type**

  ```lua
  type Action<Req, Res> = {
  	name: string,
  	request: (payload: Req, timeout: number?) -> (Res?, string?),
  	fire: (payload: Req) -> string?,
  	handle: (handler: (player: Player, payload: Req) -> Res, options: HandleOptions?) -> (),
  }

  function Remote.action<Req, Res>(name: string): Action<Req, Res>
  ```

---

## Remote.state()

A value on the server that every client can read and follow, like the round phase, a timer or a
player's coins. Changes reach clients with the frame's other sends.

- **Example**

  <!-- server -->
  ```lua
  local round = Remote.state("round", { phase = "lobby", endsAt = 0 })
  local coins = Remote.state("coins", 0)

  round.set({ phase = "playing", endsAt = os.time() + 120 })

  Players.PlayerAdded:Connect(function(player)
  	coins.setFor(player, 100) -- this player's own value
  end)
  ```

- **Details**

  - `set(value)` changes the value for everyone who doesn't have their own.
  - `setFor(player, value)` gives one player their own value. `setFor(player, nil)` goes back to
    the shared one. It's forgotten when the player leaves.
  - `get(player?)` reads it on the server.
  - Values are checked like payloads. `set` and `setFor` return the reason when one can't be sent.
  - A player who joins later loads the current values when their client first reads state.

- **Type**

  ```lua
  type State<T> = {
  	set: (value: T) -> string?,
  	setFor: (player: Player, value: T?) -> string?,
  	get: (player: Player?) -> T,
  }

  function Remote.state<T>(name: string, initial: T): State<T>
  ```

---

## Remote.useState(), getState() and onState()

Read a [`Remote.state()`](#remotestate) on the client. `useState` gives a read-only ref, so a
component re-renders when the server changes the value.

- **Example**

  ```lua
  local CoinsLabel = Rivue.defineComponent({
  	name = "CoinsLabel",
  	setup = function()
  		return { coins = Remote.useState("coins", 0) }
  	end,
  	render = function(ctx)
  		return h("TextLabel", { Text = `{ctx.coins} coins` })
  	end,
  })
  ```

- **Details**

  - `useState(name, default)` returns a read-only ref. It starts at `default` until the value has
    loaded, so it never yields in `setup()`. It needs RivueUI.
  - `getState(name)` returns the current value. The first call yields while the values load.
  - `onState(name, callback)` calls back with each new value. In `setup()` it disconnects when
    the component unmounts.

- **Type**

  ```lua
  function Remote.useState<T>(name: string, default: T?): { value: T }
  function Remote.getState(name: string): any
  function Remote.onState(name: string, callback: (value: any) -> ()): Connection
  ```

---

## Remote.useRequest()

[`useAsync()`](component.md#useasync) around [`Remote.request()`](#remoterequest): the result,
`loading` and `error` as refs, and an answer to an old request never overwrites a newer one.

- **Example**

  ```lua
  local Inventory = Rivue.defineComponent({
  	name = "Inventory",
  	setup = function()
  		local items = Remote.useRequest("inventory:list", { initial = {} })
  		return { items = items.data, loading = items.loading, reload = items.refresh }
  	end,
  	render = function(ctx)
  		return h("TextLabel", { Text = if ctx.loading then "Loading..." else `{#ctx.items} items` })
  	end,
  })
  ```

- **Details**

  It sends straight away unless `immediate = false`, with `payload` if you give one. `run(payload)`
  sends again with a new payload and `refresh()` repeats the last one. A request error such as
  `"rate_limited"` or `"timeout"` ends up in `error`. Like `useAsync`, it holds a surrounding
  Suspense while loading unless `suspense = false`. It needs RivueUI.

- **Type**

  ```lua
  type RequestOptions = {
  	payload: unknown?,
  	immediate: boolean?, -- default true
  	timeout: number?, -- seconds, default 10
  	initial: unknown?,
  	suspense: boolean?, -- default true
  }

  function Remote.useRequest(name: string, options: RequestOptions?): AsyncState
  ```

---

## Remote.configure()

Changes RivueRemote's limits. Call it from a ModuleScript both sides require, so the client checks
payloads against the same limits the server does.

- **Example**

  ```lua
  -- ReplicatedStorage/RemoteConfig.luau, required by a server script and a client script
  Remote.configure({
  	maxPayloadSize = 4000, -- this game never sends more
  	maxRequestsPerSecond = 40,
  })
  ```

- **Details**

  | Setting | Default | |
  |---|---|---|
  | `maxPayloadSize` | 20000 | largest payload, in bytes, roughly as the network sends it |
  | `maxPayloadDepth` | 10 | how deep tables can nest |
  | `maxRequestsPerSecond` | 60 | requests one player can send per second, all actions together |
  | `maxBytesPerSecond` | 50000 | payload bytes one player can send per second, all actions together |

  `0` turns off `maxRequestsPerSecond` or `maxBytesPerSecond`. Without the totals, a client could
  spread its spam across every action and stay under each action's own `maxPerSecond`. An unknown
  setting errors.

- **Type**

  ```lua
  function Remote.configure(config: {
  	maxPayloadSize: number?,
  	maxPayloadDepth: number?,
  	maxRequestsPerSecond: number?,
  	maxBytesPerSecond: number?,
  })
  ```

---

## Remote.stats()

Counts per action on the server, for finding slow or failing handlers in a live game.

- **Example**

  <!-- server -->
  ```lua
  task.spawn(function()
  	while task.wait(60) do
  		for action, s in Remote.stats() do
  			if s.calls > 0 then
  				print(action, s.calls, "calls,", s.failed, "failed,", s.rejected, "refused,",
  					math.round(s.totalTime / s.calls * 1000), "ms on average")
  			end
  		end
  		Remote.resetStats()
  	end
  end)
  ```

- **Details**

  - `calls` counts handler runs, and `failed` the ones that errored (a `use()` function that
    errored counts too).
  - `rejected` counts requests refused before the handler: rate limits, payload checks, `check`
    and `use()`.
  - `totalTime` and `maxTime` are the handler's time in seconds, including any time it spent
    yielding, for example on a DataStore call.
  - The counts add up until `resetStats()`. `stats()` returns a copy.

- **Type**

  ```lua
  type ActionStats = { calls: number, failed: number, rejected: number, totalTime: number, maxTime: number }

  function Remote.stats(): { [string]: ActionStats }
  function Remote.resetStats()
  ```

---

## Payloads and errors

- **Example**

  ```lua
  local data, err = Remote.request("inventory:get", nil, 5)
  if err == "timeout" then
  	warn("server didn't answer")
  elseif err then
  	warn("request failed:", err)
  else
  	print("inventory", data)
  end
  ```

- **Payloads** can contain:
  - strings, numbers and booleans,
  - tables up to 10 levels deep, and about 20 KB in total (both can be changed with
    [`configure()`](#remoteconfigure)),
  - Instances,
  - Roblox datatypes such as Vector3, CFrame, Color3, UDim2 and EnumItem.

  Functions and threads are rejected before anything is sent.

- **Errors** returned by `request()`:

  | Error | Meaning |
  |-------|---------|
  | `"timeout"` | No response in time |
  | `"unknown_action"` | No `handle()` for that action on the server (at most 30 of these replies a second per player) |
  | `"rate_limited"` | Over the action's `maxPerSecond`, or the player's total request or byte budget |
  | `"rejected"` | A [`use()`](#remoteuse) function returned `false` |
  | `"invalid_payload"` | The action's `check` didn't return `true` |
  | `"handler_error"` | The server handler errored |
  | `"invalid_action_name"` | Not a non-empty string of at most 100 characters |
  | `"payload_unsafe_type"` | The payload contains something RemoteEvents can't send |
  | `"payload_too_large"` / `"payload_too_deep"` | Over the size or nesting limit |

---

[← Roblox composables](roblox.md) · [API reference](../API.md) · [RivueRouter →](router.md)
