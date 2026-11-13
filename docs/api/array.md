[Docs](../README.md) › [API](../API.md) › **Array helpers**

# Array helpers

**Learn it:** [Guide 2: State](../guide/02-state.md)

`table.insert`, `table.remove`, `table.sort` and `table.find` work on a table's raw contents, so on
a reactive array they change or read nothing. `Rivue.array` has the same operations for reactive
arrays: they change the array and notify everything that read it, like Vue's array methods. They
work on plain arrays too. Examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.RivueUI)
local array = Rivue.array
```

> [!WARNING]
> The helpers that change a list error on a read-only one, such as a `readonly()` view.

---

## array.push()

Adds items to the end of a list, like `table.insert(list, value)`.

```lua signature
function array.push<T>(list: { T }, ...: T): number
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to change |
| `...` | `T` | | one or more items |

**Returns** the new length.

### Example

```lua
local todos = Rivue.ref({})

array.push(todos.value, { id = 1, text = "Milk" })
array.push(todos.value, { id = 2, text = "Eggs" }, { id = 3, text = "Bread" })
```

---

## array.insert()

Adds an item at a position and moves the rest down, like `table.insert(list, index, value)`.

```lua signature
function array.insert<T>(list: { T }, index: number, value: T)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to change |
| `index` | `number` | | from 1 to one past the end |
| `value` | `T` | | the item |

> [!WARNING]
> Any other `index` errors, instead of dropping the item without a word.

### Example

```lua
local queue = Rivue.reactive({ "b", "c" })
array.insert(queue, 1, "a") -- { "a", "b", "c" }
```

---

## array.remove()

Takes an item out by position and gives it back, like `table.remove`.

```lua signature
function array.remove<T>(list: { T }, index: number?): T?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to change |
| `index` | `number?` | the last item | the position to take out |

**Returns** the removed item, or `nil`.

### Example

```lua
local stack = Rivue.reactive({ 1, 2, 3 })
print(array.remove(stack)) -- 3
print(array.remove(stack, 1)) -- 1
```

---

## array.removeValue()

Takes out the first item equal to the one you pass, for when you have the item but not its index.

```lua signature
function array.removeValue<T>(list: { T }, value: T): boolean
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to change |
| `value` | `T` | | the item; a reactive item and its raw table count as the same |

**Returns** `true` if the item was there.

### Example

```lua
local selected = Rivue.reactive({ "Sword", "Shield" })
array.removeValue(selected, "Sword")
```

---

## array.removeWhere()

Takes out every item that passes a test, such as every finished todo. The UI updates once, not once
per item.

```lua signature
function array.removeWhere<T>(list: { T }, predicate: (item: T, index: number) -> boolean): number
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to change |
| `predicate` | `(item, index) -> boolean` | | return `true` to remove the item |

**Returns** how many items were removed.

### Example

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

Removes items at a position and inserts new ones in their place, like JavaScript's `splice`.

```lua signature
function array.splice<T>(list: { T }, start: number, deleteCount: number?, ...: T): { T }
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to change |
| `start` | `number` | | where to start; negative counts from the end, `-1` being the last item |
| `deleteCount` | `number?` | everything to the end | how many items to remove |
| `...` | `T` | | items to insert at `start` |

**Returns** the removed items.

### Example

```lua
local letters = Rivue.reactive({ "a", "b", "c", "d" })
local removed = array.splice(letters, 2, 2, "x") -- letters: a, x, d; removed: b, c
```

---

## array.move()

Moves an item to a new position, for reordering things like hotbar slots.

```lua signature
function array.move<T>(list: { T }, from: number, to: number)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to change |
| `from` | `number` | | the item's position; outside the list does nothing |
| `to` | `number` | | the new position; past either end moves it to that end |

### Example

```lua
local hotbar = Rivue.reactive({ "Sword", "Bow", "Potion" })
array.move(hotbar, 3, 1) -- Potion, Sword, Bow
```

---

## array.sort()

Sorts a list in place, like `table.sort`, and updates everything that shows it.

```lua signature
function array.sort<T>(list: { T }, comparator: ((a: T, b: T) -> boolean)?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to sort |
| `comparator` | `((a, b) -> boolean)?` | `<` | return `true` when `a` goes first |

### Example

```lua
local scores = Rivue.reactive({ { name = "A", score = 5 }, { name = "B", score = 9 } })

array.sort(scores, function(a, b)
	return a.score > b.score
end)
```

---

## array.clear()

Empties a list.

```lua signature
function array.clear<T>(list: { T })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to empty |

### Example

```lua
local notifications = Rivue.reactive({ "Saved", "Level up!" })
array.clear(notifications)
```

---

## array.indexOf()

Where an item is in a list. Unlike `table.find`, it works on reactive lists, and a computed that
uses it updates when items come and go.

```lua signature
function array.indexOf<T>(list: { T }, value: T): number?
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to search |
| `value` | `T` | | the item |

**Returns** the index, or `nil` if it isn't there.

### Example

```lua
local party = Rivue.reactive({ "Ada", "Grace" })
print(array.indexOf(party, "Grace")) -- 2
```

---

## array.find()

The first item that passes a test, and its index. You get the reactive item, so changing its fields
updates the UI.

```lua signature
function array.find<T>(list: { T }, predicate: (item: T, index: number) -> boolean): (T?, number?)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to search |
| `predicate` | `(item, index) -> boolean` | | return `true` for the item you want |

**Returns** the item and its index, or `nil`.

### Example

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

Build something new from a list without changing it: a filtered copy, a transformed copy, or a
count. The reads are tracked, so they work inside computeds and render.

```lua signature
function array.filter<T>(list: { T }, predicate: (item: T, index: number) -> boolean): { T }
function array.map<T, U>(list: { T }, mapper: (item: T, index: number) -> U): { U }
function array.count<T>(list: { T }, predicate: ((item: T, index: number) -> boolean)?): number
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `list` | `{ T }` | | the list to read |
| `predicate` | `(item, index) -> boolean` | | `filter` keeps and `count` counts the items it returns `true` for; `count` without it counts every item |
| `mapper` | `(item, index) -> U` | | `map` puts its result in the new list |

**Returns** a new plain list, or a number for `count`.

### Example

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
