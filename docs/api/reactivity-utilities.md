[Docs](../README.md) › [API](../API.md) › **Reactivity: Utilities**

# Reactivity: Utilities

**Learn it:** [Guide 2: State](../guide/02-state.md)

All examples assume `local Rivue = require(game.ReplicatedStorage.Rivue)`.

- [isRef()](#isref)
- [unref()](#unref)
- [toRef()](#toref)
- [toValue()](#tovalue)
- [toRefs()](#torefs)
- [proxyRefs()](#proxyrefs)
- [isProxy()](#isproxy)
- [isReactive()](#isreactive)
- [isReadonly()](#isreadonly)

---

## isRef()

Tells you whether a value is a ref (computeds count).

- **Type**

  ```lua
  function isRef(value: unknown): boolean
  ```

- **Example**

  ```lua
  print(Rivue.isRef(Rivue.ref(1))) -- true
  print(Rivue.isRef(Rivue.computed(function() return 1 end))) -- true
  print(Rivue.isRef(1)) -- false
  ```

---

## unref()

Gives you the value whether you have a ref or a plain value. Handy in functions that accept either.

- **Type**

  ```lua
  function unref<T>(value: T | Ref<T>): T
  ```

- **Example**

  ```lua
  local function double(n: number | Rivue.Ref<number>): number
  	return Rivue.unref(n) * 2
  end

  print(double(2)) -- 4
  print(double(Rivue.ref(3))) -- 6
  ```

---

## toRef()

A ref linked to one field of a table: reading and writing it reads and writes the field. Use it to
pass a single prop or field to a composable that expects a ref.

- **Type**

  ```lua
  function toRef<K, V>(object: { [K]: V }, key: K): Ref<V>
  ```

- **Details**

  The ref stays linked to the source: writing the ref writes the key, and the other way around.
  This is the way to pass one prop into a composable while keeping it reactive.

- **Example**

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

Gives you the value from a plain value, a ref or a getter function. The friendliest way for a
composable to accept "anything that holds a value".

- **Type**

  ```lua
  function toValue<T>(source: T | Ref<T> | () -> T): T
  ```

- **Details**

  Like [`unref()`](#unref), but also calls getter functions. Useful in composables that accept
  any of the three.

- **Example**

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

---

## toRefs()

Turns each field of a reactive table into its own linked ref, so you can return or pass the fields
separately without them losing reactivity.

- **Type**

  ```lua
  function toRefs<K, V>(object: { [K]: V }): { [K]: Ref<V> }
  ```

- **Details**

  Copying values out of a reactive table (`local x = state.x`) loses reactivity. `toRefs` keeps
  each one linked.

- **Example**

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

Lets you use a table of refs without writing `.value` everywhere. It's what `render(ctx)` uses for
the state `setup()` returns.

- **Type**

  ```lua
  function proxyRefs<T>(object: T): T
  ```

- **Details**

  Reading a key that holds a ref returns the ref's value. Assigning to it sets the ref. Other
  keys pass through. The [`render(ctx)`](component.md#render) context uses this for what
  `setup()` returns.

- **Example**

  ```lua
  local count = Rivue.ref(1)
  local state = Rivue.proxyRefs({ count = count, label = "Coins" })

  print(state.count) -- 1
  state.count = 5
  print(count.value) -- 5
  ```

---

## isProxy()

Tells you whether a table is any kind of reactive or readonly proxy.

- **Type**

  ```lua
  function isProxy(value: unknown): boolean
  ```

- **Example**

  ```lua
  print(Rivue.isProxy(Rivue.reactive({}))) -- true
  print(Rivue.isProxy(Rivue.readonly({}))) -- true
  print(Rivue.isProxy({})) -- false
  ```

---

## isReactive()

Tells you whether a table is reactive (from `reactive()` or `shallowReactive()`, or a readonly view
of one).

- **Type**

  ```lua
  function isReactive(value: unknown): boolean
  ```

- **Example**

  ```lua
  print(Rivue.isReactive(Rivue.reactive({}))) -- true
  print(Rivue.isReactive({})) -- false
  ```

---

## isReadonly()

Tells you whether a table is a readonly view.

- **Type**

  ```lua
  function isReadonly(value: unknown): boolean
  ```

- **Example**

  ```lua
  print(Rivue.isReadonly(Rivue.readonly({}))) -- true
  print(Rivue.isReadonly(Rivue.reactive({}))) -- false
  ```

---

[← Reactivity: Core](reactivity-core.md) · [API reference](../API.md) · [Array Helpers →](array.md)
