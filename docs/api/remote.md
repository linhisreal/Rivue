[Docs](../README.md) › [API](../API.md) › **Remote**

# Remote

**Learn it:** [Guide 8: Sharing state and the server](../guide/08-state-and-server.md)

Request/response and events between client and server over RemoteEvents, with payload validation
and per-player rate limits. All examples assume
`local Rivue = require(game.ReplicatedStorage.Rivue)`.

- [Remote.setupServer()](#remotesetupserver)
- [Remote.handle()](#remotehandle)
- [Remote.request()](#remoterequest)
- [Remote.fire()](#remotefire)
- [Remote.on()](#remoteon)
- [Payloads and errors](#payloads-and-errors)

---

## Remote.setupServer()

Creates the RemoteEvents Rivue uses. Call it once on the server at startup.

- **Type**

  ```lua
  function Remote.setupServer()
  ```

- **Details**

  The events live in `ReplicatedStorage.RemoteEvents`. Clients wait up to 5 seconds for them, and
  warn if the server never created them.

- **Example**

  <!-- server -->
  ```lua
  -- ServerScriptService/Main.server.luau
  Rivue.Remote.setupServer()
  ```

---

## Remote.handle()

Registers the server handler for an action sent with [`request()`](#remoterequest) or
[`fire()`](#remotefire).

- **Type**

  ```lua
  function Remote.handle(
  	action: string,
  	handler: (player: Player, payload: unknown) -> unknown,
  	options: { maxPerSecond: number? }?
  )
  ```

- **Details**

  - **Responses.** What the handler returns is sent back as the response.
  - **Errors.** If the handler errors, the error is logged on the server and the client gets
    `"handler_error"`, so internal details never leak to clients.
  - **Rate limits.** Each player can call each action `maxPerSecond` times per second (default
    30, `0` disables it). Extra calls get `"rate_limited"`.
  - **Payloads come from the client.** Validate everything before using it.

- **Example**

  <!-- server -->
  ```lua
  local Players = game:GetService("Players")
  local PRICES = { sword = 100, shield = 75 }

  Rivue.Remote.setupServer()

  Rivue.Remote.handle("shop:buy", function(player, payload)
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

---

## Remote.request()

Sends a request to the server and yields until the response arrives.

- **Type**

  ```lua
  function Remote.request(action: string, payload: unknown, timeout: number?): (unknown?, string?)
  ```

- **Details**

  Returns `(data, nil)` on success or `(nil, err)` on failure. `timeout` is in seconds (default
  10). It yields, so call it from an event handler or `task.spawn`, never from a render function.

- **Example**

  ```lua
  local h = Rivue.h

  local BuyButton = Rivue.defineComponent(function()
  	local pending = Rivue.ref(false)
  	local message = Rivue.ref("")

  	local function buy()
  		pending.value = true
  		task.spawn(function()
  			local result, err = Rivue.Remote.request("shop:buy", { id = "sword" })
  			pending.value = false
  			if err then
  				message.value = `Error: {err}`
  			elseif result and (result :: any).ok then
  				message.value = "Bought!"
  			else
  				message.value = `Can't buy: {(result :: any).reason}`
  			end
  		end)
  	end

  	return function()
  		return h("TextButton", {
  			Text = if pending.value then "Buying..." else `Buy sword {message.value}`,
  			onClick = buy,
  		})
  	end
  end, { name = "BuyButton" })
  ```

---

## Remote.fire()

Sends an action to the server without waiting for a response.

- **Type**

  ```lua
  function Remote.fire(action: string, payload: unknown)
  ```

- **Details**

  The server's [`handle()`](#remotehandle) runs as usual, and its return value is discarded.

- **Example**

  ```lua
  -- Client
  Rivue.Remote.fire("settings:save", { music = 0.5, sfx = 1 })
  ```

  <!-- server -->
  ```lua
  -- Server
  Rivue.Remote.handle("settings:save", function(player, payload)
  	print(player.Name, "saved settings", payload)
  	return nil
  end)
  ```

---

## Remote.on()

Listens on the client for a named RemoteEvent the server fires.

- **Type**

  ```lua
  function Remote.on(name: string, callback: (...any) -> ()): RBXScriptConnection
  ```

- **Details**

  The event is `ReplicatedStorage.RemoteEvents[name]`. Create it on the server, and fire it with
  `FireClient` or `FireAllClients`.

- **Example**

  ```lua
  -- Client: show announcements
  local announcement = Rivue.ref("")

  local conn = Rivue.Remote.on("Announcement", function(text)
  	announcement.value = text
  end)

  -- Server
  -- local event = Instance.new("RemoteEvent")
  -- event.Name = "Announcement"
  -- event.Parent = game.ReplicatedStorage:WaitForChild("RemoteEvents")
  -- event:FireAllClients("Double coins for 10 minutes!")
  ```

---

## Payloads and errors

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
  | `"unknown_action"` | No `handle()` for that action on the server |
  | `"rate_limited"` | Over the action's `maxPerSecond` |
  | `"handler_error"` | The server handler errored |
  | `"invalid_action_name"` | Not a non-empty string of at most 100 characters |
  | `"payload_unsafe_type"` | The payload contains something RemoteEvents can't send |
  | `"payload_too_large"` / `"payload_too_deep"` | Over the size or nesting limit |

- **Example**

  ```lua
  local data, err = Rivue.Remote.request("inventory:get", nil, 5)
  if err == "timeout" then
  	warn("server didn't answer")
  elseif err then
  	warn("request failed:", err)
  else
  	print("inventory", data)
  end
  ```

---

[← Roblox Composables](roblox.md) · [API reference](../API.md) · [Instance Pool →](pool.md)
