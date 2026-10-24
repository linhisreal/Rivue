[Docs](../README.md) › [API](../API.md) › **RivueRemote**

# RivueRemote

**Learn it:** [Guide 8: Sharing state and the server](../guide/08-state-and-server.md)

Requests, events and replicated state between client and server, with payload checks and
per-player limits. Put `RivueRemote` next to `RivueUI` in ReplicatedStorage. Examples assume
`local Remote = require(game.ReplicatedStorage.RivueRemote)`.

- [Remote.setupServer()](#remotesetupserver)
- [Remote.handle()](#remotehandle)
- [Remote.request()](#remoterequest)
- [Remote.fire()](#remotefire)
- [Remote.on()](#remoteon)
- [Remote.send() and Remote.sendAll()](#remotesend-and-remotesendall)
- [Remote.use()](#remoteuse)
- [Remote.schema()](#remoteschema)
- [Remote.onSuspicious() and Remote.trap()](#remoteonsuspicious-and-remotetrap)
- [Remote.action()](#remoteaction)
- [Remote.state()](#remotestate)
- [Remote.useState(), getState() and onState()](#remoteusestate-getstate-and-onstate)
- [Remote.useRequest()](#remoteuserequest)
- [Remote.configure()](#remoteconfigure)
- [Remote.stats()](#remotestats)
- [Payloads and errors](#payloads-and-errors)

---

## Remote.setupServer()

Creates the remotes in `ReplicatedStorage.RemoteEvents`. Call it once at server startup; clients
wait up to 5 seconds for them.

- **Example**

  <!-- server -->
  ```lua
  Remote.setupServer()
  ```

- **Type**

  ```lua
  function Remote.setupServer()
  ```

---

## Remote.handle()

Handles an action on the server. The return value is the reply.

- **Example**

  <!-- server -->
  ```lua
  local PRICES = { sword = 100, shield = 75 }

  Remote.handle("shop:buy", function(player, payload)
  	local price = PRICES[payload.id]
  	local coins = player:GetAttribute("Coins") or 0
  	if not price or coins < price then
  		return false
  	end
  	player:SetAttribute("Coins", coins - price)
  	return true
  end, {
  	check = Remote.schema({ id = "string 1..32" }),
  	exclusive = true,
  })
  ```

- **Options**

  - `maxPerSecond`: calls per player per second (default 30, `0` for no limit).
  - `check`: gets the payload; anything but `true` refuses it with `"invalid_payload"`. See
    [`schema()`](#remoteschema).
  - `allow`: gets the player and runs before the payload is read; anything but `true` refuses
    with `"rejected"`. For admin and dev actions.
  - `exclusive`: a player's second call while the first is running gets `"busy"`. For handlers
    that yield between reading and writing, like purchases and trades.

- **Details**

  - A handler error is logged (at most once per 10 seconds per action) and the client only gets
    `"handler_error"`.
  - An Instance in a payload can be anything the client can see. Check the player owns it.
  - Names starting with `__rivue` are reserved.

- **Type**

  ```lua
  function Remote.handle(
  	action: string,
  	handler: (player: Player, payload: unknown) -> unknown,
  	options: {
  		maxPerSecond: number?,
  		check: ((payload: unknown) -> boolean)?,
  		allow: ((player: Player) -> boolean)?,
  		exclusive: boolean?,
  	}?
  )
  ```

---

## Remote.request()

Sends an action and yields for the reply. Returns `(data, nil)` or `(nil, err)`. `timeout` is in
seconds (default 10). In components, [`useRequest()`](#remoteuserequest) is usually simpler.

- **Example**

  ```lua
  task.spawn(function()
  	local bought, err = Remote.request("shop:buy", { id = "sword" })
  	if err then
  		warn("buy failed:", err)
  	end
  end)
  ```

- **Type**

  ```lua
  function Remote.request(action: string, payload: unknown, timeout: number?): (unknown?, string?)
  ```

---

## Remote.fire()

Sends an action without waiting. The handler's return value is dropped. Returns the reason if the
payload can't be sent.

- **Example**

  ```lua
  Remote.fire("settings:save", { music = 0.5, sfx = 1 })
  ```

- **Type**

  ```lua
  function Remote.fire(action: string, payload: unknown): string?
  ```

---

## Remote.on()

Listens on the client for events from [`send()` and `sendAll()`](#remotesend-and-remotesendall).
Inside `setup()` it disconnects on unmount.

- **Example**

  ```lua
  local announcement = Rivue.ref("")

  Remote.on("Announcement", function(text)
  	announcement.value = text
  end)
  ```

- **Type**

  ```lua
  type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }

  function Remote.on(name: string, callback: (payload: any) -> ()): Connection
  ```

---

## Remote.send() and Remote.sendAll()

Sends an event from the server to one player or everyone.

- **Example**

  <!-- server -->
  ```lua
  game.Players.PlayerAdded:Connect(function(player)
  	Remote.send(player, "welcome", "Hi!")
  end)
  Remote.sendAll("Announcement", "Double coins for 10 minutes!")
  Remote.sendAll("round:time", 90, { unreliable = true })
  ```

- **Details**

  - Sends are batched per player until the end of the frame, in order. `Remote.flush()` sends now.
  - `unreliable = true` goes straight out on an `UnreliableRemoteEvent`. It can drop or reorder,
    and Roblox drops payloads over about 900 bytes.
  - Returns the reason if the payload can't be sent.

- **Type**

  ```lua
  function Remote.send(player: Player, name: string, payload: unknown, options: { unreliable: boolean? }?): string?
  function Remote.sendAll(name: string, payload: unknown, options: { unreliable: boolean? }?): string?
  function Remote.flush()
  ```

---

## Remote.use()

Middleware that runs before every handler, after the rate limits and payload checks and before
`check`. Return `false` to refuse with `"rejected"`. Returns a remover.

- **Example**

  <!-- server -->
  ```lua
  local loaded: { [Player]: boolean } = {}

  Remote.use(function(player, _action, _payload)
  	return loaded[player] == true
  end)
  ```

- **Type**

  ```lua
  function Remote.use(middleware: (player: Player, action: string, payload: unknown) -> boolean?): () -> ()
  ```

---

## Remote.schema()

Builds a `check` function. The spec is compiled once and a bad spec errors straight away.

- **Example**

  <!-- server -->
  ```lua
  local check = Remote.schema({
  	id = "string 1..32",
  	amount = "integer 1..99",
  	gift = "Player?",
  	tags = { "string ..16" },
  })
  ```

- **Specs**

  | Spec | Matches |
  |---|---|
  | `"string"`, `"number"`, `"integer"`, `"boolean"`, `"any"` | that type (`"any"` is anything but `nil`) |
  | `"number 0..1"`, `"string 1..32"` | a range, or a length for strings; either end can be left out |
  | `"Vector3"`, `"CFrame"`, ... | that datatype |
  | `"Player"`, `"BasePart"`, ... | an Instance that `IsA` that class |
  | `"string?"` | also allows `nil` |
  | `{ field = spec }` | a table with exactly these fields |
  | `{ spec }` | an array without holes |
  | a function | your own check |

- **Type**

  ```lua
  function Remote.schema(spec: any): (payload: unknown) -> boolean
  ```

---

## Remote.onSuspicious() and Remote.trap()

`onSuspicious` reports players who send what a normal client wouldn't. `trap` registers an action
your game never calls; calling it reports `"trap"` and replies `"unknown_action"`.

- **Example**

  <!-- server -->
  ```lua
  Remote.trap("admin:giveCoins")

  Remote.onSuspicious(function(player, reason, count)
  	if reason == "trap" then
  		player:Kick()
  	end
  end)
  ```

- **Details**

  - Reasons: `"malformed"`, `"unknown_action"`, `"rate_limited"`, `"forbidden"`,
    `"invalid_payload"`, `"trap"` and the payload errors.
  - Called at most once a second per player and reason; `count` is how many happened since the
    last call.
  - Lag can cause the odd `"rate_limited"`, so act on counts. Traps are never hit by accident.
  - `onSuspicious` returns a remover.

- **Type**

  ```lua
  function Remote.onSuspicious(listener: (player: Player, reason: string, count: number) -> ()): () -> ()
  function Remote.trap(action: string)
  ```

---

## Remote.action()

A typed action shared by both sides. Put it in a ModuleScript in ReplicatedStorage.

- **Example**

  ```lua
  local Actions = {
  	buy = Remote.action("shop:buy") :: Remote.Action<{ id: string }, boolean>,
  }

  task.spawn(function()
  	local bought, err = Actions.buy.request({ id = "sword" })
  end)
  ```

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

A server value that clients can read, shared or per player.

- **Example**

  <!-- server -->
  ```lua
  local round = Remote.state("round", { phase = "lobby" })
  local coins = Remote.state("coins", 0)

  round.set({ phase = "playing" })
  game.Players.PlayerAdded:Connect(function(player)
  	coins.setFor(player, 100)
  end)
  ```

- **Details**

  - `set` changes the shared value; `setFor(player, value)` overrides it for one player, and
    `nil` removes the override.
  - Values are checked like payloads; `set` and `setFor` return the reason if one can't be sent.
  - Late joiners get the current values.

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

Read a [`Remote.state()`](#remotestate) on the client.

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

  - `useState` returns a read-only ref that holds `default` until the value loads. Needs RivueUI.
  - `getState` yields on first use while values load.
  - `onState` calls back on each change, and disconnects on unmount inside `setup()`.

- **Type**

  ```lua
  function Remote.useState<T>(name: string, default: T?): { value: T }
  function Remote.getState(name: string): any
  function Remote.onState(name: string, callback: (value: any) -> ()): Connection
  ```

---

## Remote.useRequest()

[`useAsync()`](component.md#useasync) around [`Remote.request()`](#remoterequest). Request errors
end up in `error`. Needs RivueUI.

- **Example**

  ```lua
  local Inventory = Rivue.defineComponent({
  	name = "Inventory",
  	setup = function()
  		local items = Remote.useRequest("inventory:list", { initial = {} })
  		return { items = items.data, loading = items.loading }
  	end,
  	render = function(ctx)
  		return h("TextLabel", { Text = if ctx.loading then "Loading..." else `{#ctx.items} items` })
  	end,
  })
  ```

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

  `run(payload)` sends again with a new payload, `refresh()` repeats the last one.

---

## Remote.configure()

Changes the limits. Call it from a module both sides require.

- **Example**

  ```lua
  Remote.configure({ maxPayloadSize = 4000, maxRequestsPerSecond = 40 })
  ```

- **Settings**

  | Setting | Default | Per player |
  |---|---|---|
  | `maxPayloadSize` | 20000 | bytes in one payload |
  | `maxPayloadDepth` | 10 | table nesting |
  | `maxRequestsPerSecond` | 60 | requests per second, all actions |
  | `maxBytesPerSecond` | 50000 | payload bytes per second, all actions |
  | `maxConcurrentRequests` | 10 | handlers running at once; more get `"busy"` |

  `0` turns off the last three. Unknown settings error.

- **Type**

  ```lua
  function Remote.configure(config: {
  	maxPayloadSize: number?,
  	maxPayloadDepth: number?,
  	maxRequestsPerSecond: number?,
  	maxBytesPerSecond: number?,
  	maxConcurrentRequests: number?,
  })
  ```

---

## Remote.stats()

Per-action counts on the server. They add up until `resetStats()`.

- **Example**

  <!-- server -->
  ```lua
  for action, s in Remote.stats() do
  	print(action, s.calls, s.failed, s.rejected, s.maxTime)
  end
  Remote.resetStats()
  ```

- **Details**

  - `failed` counts handler and middleware errors; `rejected` counts requests refused before the
    handler.
  - Times are in seconds and include yields.

- **Type**

  ```lua
  type ActionStats = { calls: number, failed: number, rejected: number, totalTime: number, maxTime: number }

  function Remote.stats(): { [string]: ActionStats }
  function Remote.resetStats()
  ```

---

## Payloads and errors

- **Payloads** can hold strings, finite numbers, booleans, tables, Instances and datatypes like
  Vector3 and CFrame (also finite). Functions and threads are refused before sending.

- **Limits.** Refused requests get at most 30 replies a second per player; the rest get none.
  Refused payloads still count toward the byte budget.

- **Errors** from `request()`:

  | Error | Meaning |
  |-------|---------|
  | `"timeout"` | No reply in time |
  | `"unknown_action"` | No handler for that action |
  | `"rate_limited"` | Over `maxPerSecond` or a per-player budget |
  | `"rejected"` | Refused by `allow` or `use()` |
  | `"invalid_payload"` | Refused by `check` |
  | `"busy"` | `exclusive` call still running, or `maxConcurrentRequests` reached |
  | `"handler_error"` | The handler errored |
  | `"invalid_action_name"` | Empty, not a string, or over 100 characters |
  | `"payload_bad_number"` | NaN or infinity, including inside a datatype |
  | `"payload_unsafe_type"` | Something RemoteEvents can't send |
  | `"payload_too_large"` / `"payload_too_deep"` | Over the size or nesting limit |

---

[← Roblox composables](roblox.md) · [API reference](../API.md) · [RivueRouter →](router.md)
