[Docs](../README.md) › [API](../API.md) › **RivueRemote**

# RivueRemote

**Learn it:** [Guide 8: Sharing state and the server](../guide/08-state-and-server.md)

Requests, events and replicated state between client and server, with payload checks and
per-player limits. Put `RivueRemote` next to `RivueUI` in ReplicatedStorage. Examples assume
`local Remote = require(game.ReplicatedStorage.RivueRemote)`.

> [!WARNING]
> `setupServer`, `handle`, `send`, `sendAll`, `use`, `trap`, `onSuspicious` and `state` run on the
> server only, and error on the client.

---

## Remote.setupServer()

_server_

Creates the remotes in `ReplicatedStorage.RemoteEvents`. Call it once when the server starts.

```lua signature
function Remote.setupServer()
```

> [!NOTE]
> Clients wait up to 5 seconds for the remotes. If they never appear, the client warns that
> `setupServer()` wasn't called.

### Example

<!-- server -->
```lua
Remote.setupServer()
```

---

## Remote.handle()

_server_

Handles an action on the server. Whatever the handler returns is the reply.

```lua signature
function Remote.handle(action: string, handler: (player: Player, payload: unknown) -> unknown, options: HandleOptions?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `action` | `string` | | the action name, up to 100 characters; names starting with `__rivue` are reserved |
| `handler` | `(player, payload) -> unknown` | | runs for each call; returns the reply |
| `options.maxPerSecond` | `number` | `30` | calls per player per second; `0` for no limit |
| `options.check` | `(payload) -> boolean` | | anything but `true` refuses the call with `"invalid_payload"`; see [`schema()`](#remoteschema) |
| `options.allow` | `(player) -> boolean` | | runs before the payload is read; anything but `true` refuses with `"rejected"`, for admin and dev actions |
| `options.exclusive` | `boolean` | `false` | a player's second call while the first is running gets `"busy"`; for handlers that yield between reading and writing |

> [!WARNING]
> The client can send anything. Check every payload, and check that the player owns any Instance
> in it: a payload can name any Instance the client can see.

> [!NOTE]
> Calling it again for the same action replaces the handler and its options. A handler error is
> logged at most once per 10 seconds per action, and the client only gets `"handler_error"`.

### Example

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

---

## Remote.request()

_yields_

Sends an action and yields until the reply. In components, [`useRequest()`](#remoteuserequest) is
usually simpler.

```lua signature
function Remote.request(action: string, payload: unknown, timeout: number?): (unknown?, string?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `action` | `string` | | the action name |
| `payload` | `unknown` | | what to send; see [Payloads and errors](#payloads-and-errors) |
| `timeout` | `number?` | `10` | seconds to wait |

**Returns** `(data, nil)`, or `(nil, err)` with one of the [errors](#payloads-and-errors).

> [!WARNING]
> It yields. Call it from a spawned thread, never from a render function or a computed.

### Example

```lua
task.spawn(function()
	local bought, err = Remote.request("shop:buy", { id = "sword" })
	if err then
		warn("buy failed:", err)
	end
end)
```

---

## Remote.fire()

Sends an action without waiting. The handler's return value is dropped.

```lua signature
function Remote.fire(action: string, payload: unknown): string?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `action` | `string` | | the action name |
| `payload` | `unknown` | | what to send |

**Returns** the reason if the payload couldn't be sent, which is also warned.

### Example

```lua
Remote.fire("settings:save", { music = 0.5, sfx = 1 })
```

---

## Remote.on()

Listens on the client for events from [`send()` and `sendAll()`](#remotesend-and-remotesendall).

```lua signature
function Remote.on(name: string, callback: (payload: any) -> ()): Connection
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | the event name |
| `callback` | `(payload) -> ()` | | runs for each event |

**Returns** a `Connection`. Called in a component's `setup()`, it disconnects on unmount.

### Example

```lua
local announcement = Rivue.ref("")

Remote.on("Announcement", function(text)
	announcement.value = text
end)
```

---

## Remote.send() and Remote.sendAll()

_server_

Sends an event from the server to one player or to everyone.

```lua signature
function Remote.send(player: Player, name: string, payload: unknown, options: { unreliable: boolean? }?): string?
function Remote.sendAll(name: string, payload: unknown, options: { unreliable: boolean? }?): string?
function Remote.flush()
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `player` | `Player` | | `send` only: who gets it |
| `name` | `string` | | the event name |
| `payload` | `unknown` | | what to send |
| `options.unreliable` | `boolean` | `false` | send now on an `UnreliableRemoteEvent`; it can drop or arrive out of order |

**Returns** the reason if the payload couldn't be sent.

> [!NOTE]
> Sends are batched per player until the end of the frame, in order; `Remote.flush()` sends now.
> Roblox drops unreliable payloads over about 900 bytes.

### Example

<!-- server -->
```lua
game.Players.PlayerAdded:Connect(function(player)
	Remote.send(player, "welcome", "Hi!")
end)
Remote.sendAll("Announcement", "Double coins for 10 minutes!")
Remote.sendAll("round:time", 90, { unreliable = true })
```

---

## Remote.use()

_server_

Middleware that runs before every handler: after the rate limits and payload checks, before
`check`.

```lua signature
function Remote.use(middleware: (player: Player, action: string, payload: unknown) -> boolean?): () -> ()
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `middleware` | `(player, action, payload) -> boolean?` | | return `false` to refuse the call with `"rejected"` |

**Returns** a function that removes the middleware.

### Example

<!-- server -->
```lua
local loaded: { [Player]: boolean } = {}

Remote.use(function(player, _action, _payload)
	return loaded[player] == true
end)
```

---

## Remote.schema()

Builds a `check` function from a short spec. The spec is compiled once, so a bad spec errors
straight away.

```lua signature
function Remote.schema(spec: any): (payload: unknown) -> boolean
```

| Field | Type | Default | Description |
|---|---|---|---|
| `"string"`, `"number"`, `"integer"`, `"boolean"`, `"any"` | | | that type; `"any"` is anything but `nil` |
| `"number 0..1"`, `"string 1..32"` | | | a range, or a length for strings; either end can be left out |
| `"Vector3"`, `"CFrame"`, ... | | | that datatype |
| `"Player"`, `"BasePart"`, ... | | | an Instance that `IsA` that class |
| `"string?"` | | | also allows `nil` |
| `{ field = spec }` | | | a table with exactly these fields |
| `{ spec }` | | | an array without holes |
| a function | | | your own check |

### Example

<!-- server -->
```lua
local check = Remote.schema({
	id = "string 1..32",
	amount = "integer 1..99",
	gift = "Player?",
	tags = { "string ..16" },
})
```

---

## Remote.onSuspicious() and Remote.trap()

_server_

`onSuspicious` reports players who send what a normal client wouldn't. `trap` registers an action
your game never calls; calling it reports `"trap"` and replies `"unknown_action"`.

```lua signature
function Remote.onSuspicious(listener: (player: Player, reason: string, count: number) -> ()): () -> ()
function Remote.trap(action: string)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `listener` | `(player, reason, count) -> ()` | | called at most once a second per player and reason; `count` is how many happened since the last call |
| `action` | `string` | | a name no real client sends; one that already has a handler errors |

**Returns** `onSuspicious` returns a function that removes the listener.

> [!NOTE]
> Lag can cause the odd `"rate_limited"`, so act on counts. A trap is never hit by accident.

### Example

<!-- server -->
```lua
Remote.trap("admin:giveCoins")

Remote.onSuspicious(function(player, reason, count)
	if reason == "trap" then
		player:Kick()
	end
end)
```

### Details

- Reasons: `"malformed"`, `"unknown_action"`, `"rate_limited"`, `"forbidden"`,
  `"invalid_payload"`, `"trap"` and the payload errors.

---

## Remote.action()

A typed action both sides share. Put it in a ModuleScript in ReplicatedStorage.

```lua signature
function Remote.action<Req, Res>(name: string): Action<Req, Res>

type Action<Req, Res> = {
	name: string,
	request: (payload: Req, timeout: number?) -> (Res?, string?),
	fire: (payload: Req) -> string?,
	handle: (handler: (player: Player, payload: Req) -> Res, options: HandleOptions?) -> (),
}
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | the action name |

**Returns** an `Action` whose `request`, `fire` and `handle` work like the functions of the same
name, typed by `Req` and `Res`.

### Example

```lua
local Actions = {
	buy = Remote.action("shop:buy") :: Remote.Action<{ id: string }, boolean>,
}

task.spawn(function()
	local bought, err = Actions.buy.request({ id = "sword" })
end)
```

---

## Remote.state()

_server_

A server value that clients can read, shared or set per player. Players who join late get the
current value.

```lua signature
function Remote.state<T>(name: string, initial: T): State<T>

type State<T> = {
	set: (value: T) -> string?,
	setFor: (player: Player, value: T?) -> string?,
	get: (player: Player?) -> T,
}
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | unique; a second state with the same name errors |
| `initial` | `T` | | the starting value; checked like a payload |

**Returns** a `State<T>`. `set` changes the shared value; `setFor(player, value)` overrides it for
one player, and `nil` removes the override. Both return the reason if the value can't be sent,
and warn.

### Example

<!-- server -->
```lua
local round = Remote.state("round", { phase = "lobby" })
local coins = Remote.state("coins", 0)

round.set({ phase = "playing" })
game.Players.PlayerAdded:Connect(function(player)
	coins.setFor(player, 100)
end)
```

---

## Remote.useState(), getState() and onState()

_getState yields · useState needs RivueUI_

Read a [`Remote.state()`](#remotestate) on the client.

```lua signature
function Remote.useState<T>(name: string, default: T?): { value: T }
function Remote.getState(name: string): any
function Remote.onState(name: string, callback: (value: any) -> ()): Connection
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | the state's name |
| `default` | `T?` | | `useState`: the value until the real one loads |
| `callback` | `(value) -> ()` | | `onState`: runs on each change |

**Returns** `useState` returns a read-only ref. `getState` returns the current value. `onState`
returns a `Connection`, which disconnects on unmount when made in `setup()`.

> [!WARNING]
> `getState` yields the first time while values load. `useState` needs RivueUI and errors without
> it.

### Example

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

---

## Remote.useRequest()

_needs RivueUI_

[`useAsync()`](component.md#useasync) around [`Remote.request()`](#remoterequest): it sends the
request and keeps the reply, the loading state and the error in refs. Request errors land in
`error`.

```lua signature
function Remote.useRequest(name: string, options: RequestOptions?): AsyncState
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | the action name |
| `options.payload` | `unknown` | | what to send |
| `options.immediate` | `boolean` | `true` | send straight away |
| `options.timeout` | `number` | `10` | seconds to wait |
| `options.initial` | `unknown` | | `data` until the first reply |
| `options.suspense` | `boolean` | `true` | hold a surrounding `Suspense` until the first reply |

**Returns** the same `AsyncState` as `useAsync()`: `data`, `loading` and `error` refs, `run(payload)`
to send again with a new payload, and `refresh()` to repeat the last one. A late reply to an older
request is dropped.

> [!WARNING]
> It needs RivueUI, and errors without it.

### Example

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

---

## Remote.configure()

Changes the limits. Call it from a module both sides require.

```lua signature
function Remote.configure(config: RemoteConfig)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `config.maxPayloadSize` | `number` | `20000` | bytes in one payload |
| `config.maxPayloadDepth` | `number` | `10` | table nesting |
| `config.maxRequestsPerSecond` | `number` | `60` | requests per player per second, all actions |
| `config.maxBytesPerSecond` | `number` | `50000` | payload bytes per player per second, all actions |
| `config.maxConcurrentRequests` | `number` | `10` | a player's handlers running at once; more get `"busy"` |

> [!NOTE]
> `0` turns off the last three. An unknown setting, or a value below 0, errors.

### Example

```lua
Remote.configure({ maxPayloadSize = 4000, maxRequestsPerSecond = 40 })
```

---

## Remote.stats()

Counts per action on the server. They add up until `resetStats()`.

```lua signature
function Remote.stats(): { [string]: ActionStats }
function Remote.resetStats()

type ActionStats = { calls: number, failed: number, rejected: number, totalTime: number, maxTime: number }
```

**Returns** a table of action name to its counts. `failed` counts handler and middleware errors;
`rejected` counts calls refused before the handler. Times are in seconds and include yields.

### Example

<!-- server -->
```lua
for action, s in Remote.stats() do
	print(action, s.calls, s.failed, s.rejected, s.maxTime)
end
Remote.resetStats()
```

---

## Payloads and errors

Payloads can hold strings, finite numbers, booleans, tables, Instances and datatypes like Vector3
and CFrame (also finite). Functions and threads are refused before sending.

> [!NOTE]
> Refused requests get at most 30 replies a second per player; the rest get none. Refused payloads
> still count toward the byte budget.

The errors `request()` can return:

| Field | Type | Default | Description |
|---|---|---|---|
| `"timeout"` | | | no reply in time |
| `"unknown_action"` | | | no handler for that action |
| `"rate_limited"` | | | over `maxPerSecond` or a per-player budget |
| `"rejected"` | | | refused by `allow` or `use()` |
| `"invalid_payload"` | | | refused by `check` |
| `"busy"` | | | an `exclusive` call is still running, or `maxConcurrentRequests` was reached |
| `"handler_error"` | | | the handler errored |
| `"invalid_action_name"` | | | empty, not a string, or over 100 characters |
| `"payload_bad_number"` | | | NaN or infinity, including inside a datatype |
| `"payload_unsafe_type"` | | | something RemoteEvents can't send |
| `"payload_too_large"`, `"payload_too_deep"` | | | over the size or nesting limit |

---

[← Roblox composables](roblox.md) · [API reference](../API.md) · [RivueRouter →](router.md)
