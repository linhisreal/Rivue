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

  The events live in `ReplicatedStorage.RemoteEvents`. Clients wait up to 5 seconds for them, and
  warn if the server never created them.

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
    30, `0` disables it). Extra calls get `"rate_limited"`.
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

  The server sends with [`send()` or `sendAll()`](#remotesend-and-remotesendall), which create
  the event in `ReplicatedStorage.RemoteEvents`. Disconnect the connection when you're done, for
  example in `onUnmounted`.

- **Type**

  ```lua
  function Remote.on(name: string, callback: (payload: any) -> ()): RBXScriptConnection
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

  - The first send creates the event in `ReplicatedStorage.RemoteEvents`, so the client's
    `Remote.on()` finds it. Call it once at startup for events clients listen to straight away.
  - The payload is checked like a request's. If it can't be sent, it warns and returns the reason.
  - `unreliable = true` uses an `UnreliableRemoteEvent`. Updates can be dropped or arrive out of
    order, and Roblox drops unreliable payloads over about 900 bytes, but they cost less. Use it
    for values that change many times a second. A name is either reliable or unreliable, not both.
  - `"Request"` and `"Response"` are RivueRemote's own events and can't be used as names.

- **Type**

  ```lua
  function Remote.send(player: Player, name: string, payload: unknown, options: { unreliable: boolean? }?): string?
  function Remote.sendAll(name: string, payload: unknown, options: { unreliable: boolean? }?): string?
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
  - tables up to 10 levels deep, and about 20 KB in total,
  - Instances,
  - Roblox datatypes such as Vector3, CFrame, Color3, UDim2 and EnumItem.

  Functions and threads are rejected before anything is sent.

- **Errors** returned by `request()`:

  | Error | Meaning |
  |-------|---------|
  | `"timeout"` | No response in time |
  | `"unknown_action"` | No `handle()` for that action on the server (at most 30 of these replies a second per player) |
  | `"rate_limited"` | Over the action's `maxPerSecond` |
  | `"rejected"` | A [`use()`](#remoteuse) function returned `false` |
  | `"invalid_payload"` | The action's `check` didn't return `true` |
  | `"handler_error"` | The server handler errored |
  | `"invalid_action_name"` | Not a non-empty string of at most 100 characters |
  | `"payload_unsafe_type"` | The payload contains something RemoteEvents can't send |
  | `"payload_too_large"` / `"payload_too_deep"` | Over the size or nesting limit |

---

[← Roblox composables](roblox.md) · [API reference](../API.md) · [RivueRouter →](router.md)
