[Docs](../README.md) › [API](../API.md) › **Array Helpers**

# Array Helpers

**Learn it:** [Guide 2: State](../guide/02-state.md)

`table.insert`, `table.remove`, `table.sort` and `table.find` work on a table's raw contents, so
on a reactive array they do nothing, or read nothing. `Rivue.array` has the same operations for
reactive arrays: they change the array and notify everything that read it, like Vue's array
methods. They also work on plain arrays.

All examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local array = Rivue.array
```

- [array.push()](#arraypush)
- [array.insert()](#arrayinsert)
- [array.remove()](#arrayremove)
- [array.removeValue()](#arrayremovevalue)
- [array.removeWhere()](#arrayremovewhere)
- [array.splice()](#arraysplice)
- [array.move()](#arraymove)
- [array.sort()](#arraysort)
- [array.clear()](#arrayclear)
- [array.indexOf()](#arrayindexof)
- [array.find()](#arrayfind)
- [array.filter() / array.map() / array.count()](#arrayfilter--arraymap--arraycount)

---

## array.push()

Adds one or more items to the end of a list, like `table.insert(list, value)`.

- **Type**

  ```lua
  function array.push<T>(list: { T }, ...: T): number -- new length
  ```

- **Example**

  ```lua
  local todos = Rivue.ref({})

  array.push(todos.value, { id = 1, text = "Milk" })
  array.push(todos.value, { id = 2, text = "Eggs" }, { id = 3, text = "Bread" })
  ```

---

## array.insert()

Adds an item at a position and moves the rest down, like `table.insert(list, index, value)`.

- **Type**

  ```lua
  function array.insert<T>(list: { T }, index: number, value: T)
  ```

- **Example**

  ```lua
  local queue = Rivue.reactive({ "b", "c" })
  array.insert(queue, 1, "a") -- { "a", "b", "c" }
  ```

---

## array.remove()

Takes an item out by position and gives it back. Without a position it takes the last one, like
`table.remove`.

- **Type**

  ```lua
  function array.remove<T>(list: { T }, index: number?): T?
  ```

- **Example**

  ```lua
  local stack = Rivue.reactive({ 1, 2, 3 })
  print(array.remove(stack)) -- 3
  print(array.remove(stack, 1)) -- 1
  ```

---

## array.removeValue()

Takes out the first item equal to the one you pass, when you have the item but not its index.
Returns `true` if it was there.

- **Type**

  ```lua
  function array.removeValue<T>(list: { T }, value: T): boolean
  ```

- **Details**

  A reactive item and its raw table count as the same value, so you can pass an item you got from
  the reactive array.

- **Example**

  ```lua
  local selected = Rivue.reactive({ "Sword", "Shield" })
  array.removeValue(selected, "Sword")
  ```

---

## array.removeWhere()

Takes out every item matching a test, like "every finished todo". The UI updates once, not once per
item. Returns how many were removed.

- **Type**

  ```lua
  function array.removeWhere<T>(list: { T }, predicate: (item: T, index: number) -> boolean): number
  ```

- **Example**

  ```lua
  local todos = Rivue.reactive({
  	{ id = 1, done = true },
  	{ id = 2, done = false },
  })

  array.removeWhere(todos, function(todo)
  	return todo.done
  end)
  ```

---

## array.splice()

The all-in-one edit, like JavaScript's `splice`: remove some items at a position and insert new ones
in their place. Returns what was removed.

- **Type**

  ```lua
  function array.splice<T>(list: { T }, start: number, deleteCount: number?, ...: T): { T }
  ```

- **Details**

  Without `deleteCount`, everything from `start` to the end is removed.

- **Example**

  ```lua
  local letters = Rivue.reactive({ "a", "b", "c", "d" })
  local removed = array.splice(letters, 2, 2, "x") -- letters: a, x, d; removed: b, c
  ```

---

## array.move()

Moves an item to a new position, for reordering things like hotbar slots or a queue.

- **Type**

  ```lua
  function array.move<T>(list: { T }, from: number, to: number)
  ```

- **Example**

  ```lua
  local hotbar = Rivue.reactive({ "Sword", "Bow", "Potion" })
  array.move(hotbar, 3, 1) -- Potion, Sword, Bow
  ```

---

## array.sort()

Sorts a list in place, like `table.sort`, and updates everything that shows it.

- **Type**

  ```lua
  function array.sort<T>(list: { T }, comparator: ((a: T, b: T) -> boolean)?)
  ```

- **Example**

  ```lua
  local scores = Rivue.reactive({ { name = "A", score = 5 }, { name = "B", score = 9 } })

  array.sort(scores, function(a, b)
  	return a.score > b.score
  end)
  ```

---

## array.clear()

Empties a list.

- **Type**

  ```lua
  function array.clear<T>(list: { T })
  ```

- **Example**

  ```lua
  local notifications = Rivue.reactive({ "Saved", "Level up!" })
  array.clear(notifications)
  ```

---

## array.indexOf()

Finds where an item is, or `nil` if it isn't there. Unlike `table.find`, it works on reactive lists,
and a computed that uses it updates when items come and go.

- **Type**

  ```lua
  function array.indexOf<T>(list: { T }, value: T): number?
  ```

- **Example**

  ```lua
  local party = Rivue.reactive({ "Ada", "Grace" })
  print(array.indexOf(party, "Grace")) -- 2
  ```

---

## array.find()

Gives you the first item matching a test, and its index. You get the reactive item, so changing its
fields updates the UI.

- **Type**

  ```lua
  function array.find<T>(list: { T }, predicate: (item: T, index: number) -> boolean): (T?, number?)
  ```

- **Example**

  ```lua
  local todos = Rivue.reactive({ { id = 1, done = false } })

  local todo = array.find(todos, function(t)
  	return t.id == 1
  end)
  if todo then
  	todo.done = true -- reactive
  end
  ```

---

## array.filter() / array.map() / array.count()

Read-only helpers for building something new from a list: a filtered copy, a transformed copy, or a
count. They're tracked, so they work inside computeds and render.

- **Type**

  ```lua
  function array.filter<T>(list: { T }, predicate: (item: T, index: number) -> boolean): { T }
  function array.map<T, U>(list: { T }, mapper: (item: T, index: number) -> U): { U }
  function array.count<T>(list: { T }, predicate: ((item: T, index: number) -> boolean)?): number
  ```

- **Example**

  ```lua
  local todos = Rivue.reactive({
  	{ text = "Milk", done = true },
  	{ text = "Eggs", done = false },
  })

  local remaining = Rivue.computed(function()
  	return array.count(todos, function(t)
  		return not t.done
  	end)
  end)

  local open = array.filter(todos, function(t)
  	return not t.done
  end)
  local labels = array.map(todos, function(t)
  	return t.text
  end)
  ```

---

[← Reactivity: Utilities](reactivity-utilities.md) · [API reference](../API.md) · [Reactivity: Advanced →](reactivity-advanced.md)
