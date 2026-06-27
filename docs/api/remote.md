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
  	if type(payload) ~= "table" or type(payload.id) ~= "string" then
  		return { ok = false, reason = "bad_request" }
  	end
  	local price = PRICES[payload.id]
  	local coins = player:GetAttribute("Coins") or 0
  	if not price or coins < price then
  		return { ok = false, reason = "not_enough_coins" }
  	end
  	player:SetAttribute("Coins", coins - price)
  	return { ok = true }
  end, { maxPerSecond = 5 })
  ```

- **Details**

  
  - **Errors.** If the handler errors, the error is logged on the server and the client gets
    `"handler_error"`, so internal details never leak to clients.
  - **Rate limits.** Each player can call each action `maxPerSecond` times per second (default
    30, `0` disables it). Extra calls get `"rate_limited"`.
  - **Payloads come from the client.** Validate everything before using it.

- **Type**

  ```lua
  function Remote.handle(
  	action: string,
  	handler: (player: Player, payload: unknown) -> unknown,
  	options: { maxPerSecond: number? }?
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

- **Type**

  ```lua
  function Remote.fire(action: string, payload: unknown)
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
  -- local event = Instance.new("RemoteEvent")
  -- event.Name = "Announcement"
  -- event.Parent = game.ReplicatedStorage:WaitForChild("RemoteEvents")
  -- event:FireAllClients("Double coins for 10 minutes!")
  ```

- **Details**

  The event is `ReplicatedStorage.RemoteEvents[name]`. Create it on the server, and fire it with
  `FireClient` or `FireAllClients`.

- **Type**

  ```lua
  function Remote.on(name: string, callback: (...any) -> ()): RBXScriptConnection
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
  | `"handler_error"` | The server handler errored |
  | `"invalid_action_name"` | Not a non-empty string of at most 100 characters |
  | `"payload_unsafe_type"` | The payload contains something RemoteEvents can't send |
  | `"payload_too_large"` / `"payload_too_deep"` | Over the size or nesting limit |

---

[← Roblox composables](roblox.md) · [API reference](../API.md) · [RivueRouter →](router.md)
