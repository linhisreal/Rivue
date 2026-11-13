[Docs](../README.md) › [API](../API.md) › **Reactivity: Utilities**

# Reactivity: Utilities

**Learn it:** [Guide 2: State](../guide/02-state.md)

Checks and conversions between refs, reactive tables and plain values. Examples assume
`local Rivue = require(game.ReplicatedStorage.RivueUI)`.

---

## isRef()

Whether a value is a ref. Computeds count.

```lua signature
function isRef(value: unknown): boolean
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `unknown` | | anything |

### Example

```lua
print(Rivue.isRef(Rivue.ref(1))) -- true
print(Rivue.isRef(Rivue.computed(function() return 1 end))) -- true
print(Rivue.isRef(1)) -- false
```

---

## unref()

The value inside a ref, or the value itself if it isn't one. Use it in functions that take either.

```lua signature
function unref<T>(value: T | Ref<T>): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `T \| Ref<T>` | | a ref or a plain value |

### Example

```lua
local function double(n: number | Rivue.Ref<number>): number
	return Rivue.unref(n) * 2
end

print(double(2)) -- 4
print(double(Rivue.ref(3))) -- 6
```

---

## toRef()

A ref linked to one field of a table: reading or writing the ref reads or writes the field. Use it
to hand a single prop or field to a composable that expects a ref.

```lua signature
function toRef<K, V>(object: { [K]: V }, key: K): Ref<V>
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `object` | `{ [K]: V }` | | a reactive table, or `props` |
| `key` | `K` | | the field to link to |

**Returns** a `Ref<V>` that stays linked both ways.

### Example

```lua
local state = Rivue.reactive({ foo = 1, bar = 2 })
local fooRef = Rivue.toRef(state, "foo")

fooRef.value += 1
print(state.foo) -- 2

state.foo += 1
print(fooRef.value) -- 3
```

Keeping a prop reactive inside setup:

```lua
local Label = Rivue.defineComponent({
	name = "Label",
	props = { text = { type = "string" } },
	setup = function(props)
		local text = Rivue.toRef(props, "text")
		return function()
			return Rivue.h("TextLabel", { Text = text.value })
		end
	end,
})
```

---

## toValue()

The value from a plain value, a ref or a getter. Composables use it to accept any of the three.

```lua signature
function toValue<T>(source: T | Ref<T> | () -> T): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source` | `T \| Ref<T> \| () -> T` | | a value, a ref, or a function to call |

### Example

```lua
local function useDoubled(source: Rivue.MaybeRefOrGetter<number>)
	return Rivue.computed(function()
		return Rivue.toValue(source) * 2
	end)
end

local count = Rivue.ref(2)
print(useDoubled(count).value) -- 4
print(useDoubled(function() return count.value + 1 end).value) -- 6
print(useDoubled(10).value) -- 20
```

### Details

- Like [`unref()`](#unref), but it also calls functions. Read it inside a computed or watcher
  source so the read is tracked.

---

## toRefs()

Turns each field of a reactive table into its own linked ref, so you can return or pass the fields
separately without losing reactivity.

```lua signature
function toRefs<K, V>(object: { [K]: V }): { [K]: Ref<V> }
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `object` | `{ [K]: V }` | | a reactive table |

**Returns** a plain table with one linked ref per field.

> [!NOTE]
> Only the fields that exist when you call it get a ref. Fields added later aren't included.

### Example

```lua
local function usePosition()
	local state = Rivue.reactive({ x = 0, y = 0 })
	return Rivue.toRefs(state)
end

local position = usePosition()
position.x.value = 10 -- still reactive
```

---

## proxyRefs()

Lets you use a table of refs without writing `.value`. `render(ctx)` uses it for what `setup()`
returns.

```lua signature
function proxyRefs<T>(object: T): T
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `object` | `T` | | a table whose fields may be refs |

**Returns** a proxy: reading a ref field gives its value, and assigning a plain value to a ref field
sets the ref. Other fields pass through.

### Example

```lua
local count = Rivue.ref(1)
local state = Rivue.proxyRefs({ count = count, label = "Coins" })

print(state.count) -- 1
state.count = 5
print(count.value) -- 5
```

---

## isProxy()

Whether a table is any kind of reactive or read-only proxy.

```lua signature
function isProxy(value: unknown): boolean
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `unknown` | | anything |

### Example

```lua
print(Rivue.isProxy(Rivue.reactive({}))) -- true
print(Rivue.isProxy(Rivue.readonly({}))) -- true
print(Rivue.isProxy({})) -- false
```

---

## isReactive()

Whether a table is reactive: made by `reactive()` or `shallowReactive()`, or a read-only view of
one.

```lua signature
function isReactive(value: unknown): boolean
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `unknown` | | anything |

### Example

```lua
print(Rivue.isReactive(Rivue.reactive({}))) -- true
print(Rivue.isReactive({})) -- false
```

---

## isReadonly()

Whether a table is a read-only view.

```lua signature
function isReadonly(value: unknown): boolean
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `unknown` | | anything |

### Example

```lua
print(Rivue.isReadonly(Rivue.readonly({}))) -- true
print(Rivue.isReadonly(Rivue.reactive({}))) -- false
```

---

[← Reactivity: Core](reactivity-core.md) · [API reference](../API.md) · [Array helpers →](array.md)
