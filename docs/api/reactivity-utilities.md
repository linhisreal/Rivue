# Reactivity: Utilities

All examples assume `local Rivue = require(game.ReplicatedStorage.Rivue)`.

- [isRef()](#isref)
- [unref()](#unref)
- [toRef()](#toref)
- [toValue()](#tovalue)
- [toRefs()](#torefs)
- [isProxy()](#isproxy)
- [isReactive()](#isreactive)
- [isReadonly()](#isreadonly)

---

## isRef()

Checks if a value is a ref (including computed refs).

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

Returns the inner value if the argument is a ref, otherwise the argument itself.

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

Creates a ref that reads and writes one key of a table, usually a reactive one.

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

Normalizes values, refs and getters into values.

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

Converts a reactive table into a plain table where each key is a ref linked to the source.

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

## isProxy()

Checks if a table is a proxy created by `reactive()`, `readonly()`, `shallowReactive()` or
`shallowReadonly()`.

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

Checks if a table is a proxy created by `reactive()` or `shallowReactive()`, or a readonly
view of one.

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

Checks if a table is a readonly proxy.

- **Type**

  ```lua
  function isReadonly(value: unknown): boolean
  ```

- **Example**

  ```lua
  print(Rivue.isReadonly(Rivue.readonly({}))) -- true
  print(Rivue.isReadonly(Rivue.reactive({}))) -- false
  ```
