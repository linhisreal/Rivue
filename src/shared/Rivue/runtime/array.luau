--!strict
--!optimize 2

--[[
	array.luau
	==========

	Array helpers that work on reactive arrays. Luau's table.insert/remove/sort read and write
	the raw table, so on a proxy they do nothing (or the wrong thing). These change the array
	behind the proxy and notify everything that read it, like Vue's array methods.

	Usage:
	------

		local array = Rivue.array
		array.push(state.todos, { id = 1, text = "Milk" })
		array.removeWhere(state.todos, function(todo) return todo.done end)

	@module array
]]

local reactivity = require(script.Parent:WaitForChild("reactivity"))

local toRaw = reactivity.toRaw
local triggerListChange = reactivity._triggerListChange

local array = {}

--- Gets the raw array to edit, refusing readonly proxies
--- @param list { T } -- Plain array or reactive proxy
--- @return { T } -- Raw array
local function rawOf<T>(list: { T }): { T }
	if reactivity.isReadonly(list) then
		error("[Rivue] Can't change a readonly array", 3)
	end
	return toRaw(list)
end

--- Adds values to the end
--- @param list { T } -- Array (plain or reactive)
--- @param ... T -- Values to add
--- @return number -- New length
function array.push<T>(list: { T }, ...: T): number
	local raw = rawOf(list)
	local first = #raw + 1
	for i = 1, select("#", ...) do
		raw[#raw + 1] = toRaw((select(i, ...)))
	end
	triggerListChange(raw, first, #raw, true)
	return #raw
end

--- Inserts a value at a position, shifting the rest up
--- @param list { T } -- Array
--- @param index number -- Position (1 to #list + 1)
--- @param value T -- Value
function array.insert<T>(list: { T }, index: number, value: T)
	local raw = rawOf(list)
	table.insert(raw, index, toRaw(value))
	triggerListChange(raw, index, #raw, true)
end

--- Removes the value at a position (the last one by default), shifting the rest down
--- @param list { T } -- Array
--- @param index number? -- Position, default #list
--- @return T? -- Removed value
function array.remove<T>(list: { T }, index: number?): T?
	local raw = rawOf(list)
	local count = #raw
	if count == 0 then
		return nil
	end
	local at = index or count
	local removed = table.remove(raw, at)
	triggerListChange(raw, at, count, true)
	return removed
end

--- Removes the first occurrence of a value
--- @param list { T } -- Array
--- @param value T -- Value to remove (proxies match their raw table)
--- @return boolean -- True if it was found
function array.removeValue<T>(list: { T }, value: T): boolean
	local raw = rawOf(list)
	local index = table.find(raw, toRaw(value))
	if not index then
		return false
	end
	array.remove(list, index)
	return true
end

--- Removes every item the predicate returns true for, in one update
--- @param list { T } -- Array
--- @param predicate (item: T, index: number) -> boolean -- Called with reactive items
--- @return number -- How many were removed
function array.removeWhere<T>(list: { T }, predicate: (item: T, index: number) -> boolean): number
	local raw = rawOf(list)
	local count = #raw
	local kept = 0
	for i = 1, count do
		local item = raw[i]
		-- Pass the reactive version, so reads inside are tracked like normal reads
		local view = if type(item) == "table" and list ~= raw then (list :: any)[i] else item
		if not predicate(view, i) then
			kept += 1
			raw[kept] = item
		end
	end
	for i = kept + 1, count do
		raw[i] = nil
	end
	if kept ~= count then
		triggerListChange(raw, 1, count, true)
	end
	return count - kept
end

--- Removes `deleteCount` items at `start` and inserts the given values there (like JavaScript's splice)
--- @param list { T } -- Array
--- @param start number -- First position
--- @param deleteCount number? -- How many to remove (default: everything from start)
--- @param ... T -- Values to insert
--- @return { T } -- Removed values
function array.splice<T>(list: { T }, start: number, deleteCount: number?, ...: T): { T }
	local raw = rawOf(list)
	local count = #raw
	local removeCount = math.clamp(deleteCount or (count - start + 1), 0, math.max(count - start + 1, 0))
	local removed = table.move(raw, start, start + removeCount - 1, 1, {})
	local inserted = table.pack(...)
	local tail = table.move(raw, start + removeCount, count, 1, {})
	for i = start, count do
		raw[i] = nil
	end
	for i = 1, inserted.n do
		raw[start + i - 1] = toRaw(inserted[i])
	end
	table.move(tail, 1, #tail, start + inserted.n, raw)
	triggerListChange(raw, start, math.max(count, #raw), count ~= #raw)
	return removed
end

--- Moves an item from one position to another
--- @param list { T } -- Array
--- @param from number -- Current position
--- @param to number -- New position
function array.move<T>(list: { T }, from: number, to: number)
	if from == to then
		return
	end
	local raw = rawOf(list)
	local item = table.remove(raw, from)
	table.insert(raw, to, item :: T)
	triggerListChange(raw, math.min(from, to), math.max(from, to), false)
end

--- Sorts in place
--- @param list { T } -- Array
--- @param comparator ((a: T, b: T) -> boolean)? -- Like table.sort's
function array.sort<T>(list: { T }, comparator: ((a: T, b: T) -> boolean)?)
	local raw = rawOf(list)
	table.sort(raw, comparator)
	triggerListChange(raw, 1, #raw, false)
end

--- Removes everything
--- @param list { T } -- Array
function array.clear<T>(list: { T })
	local raw = rawOf(list)
	local count = #raw
	if count == 0 then
		return
	end
	table.clear(raw)
	triggerListChange(raw, 1, count, true)
end

--- Position of a value, or nil (table.find doesn't work on proxies)
--- @param list { T } -- Array
--- @param value T -- Value (proxies match their raw table)
--- @return number? -- Index
function array.indexOf<T>(list: { T }, value: T): number?
	-- Reading the length tracks it, so this re-runs when items are added or removed
	local _ = #list
	return table.find(toRaw(list), toRaw(value))
end

--- First item the predicate returns true for, as its reactive version
--- @param list { T } -- Array
--- @param predicate (item: T, index: number) -> boolean -- Test
--- @return T? -- Item
--- @return number? -- Its index
function array.find<T>(list: { T }, predicate: (item: T, index: number) -> boolean): (T?, number?)
	for i = 1, #list do
		local item = list[i]
		if predicate(item, i) then
			return item, i
		end
	end
	return nil, nil
end

--- Items the predicate returns true for, as a new plain array
--- @param list { T } -- Array
--- @param predicate (item: T, index: number) -> boolean -- Test
--- @return { T } -- Matching items
function array.filter<T>(list: { T }, predicate: (item: T, index: number) -> boolean): { T }
	local out = {}
	for i = 1, #list do
		local item = list[i]
		if predicate(item, i) then
			table.insert(out, item)
		end
	end
	return out
end

--- Maps every item to a new plain array
--- @param list { T } -- Array
--- @param mapper (item: T, index: number) -> U -- Transform
--- @return { U } -- Results
function array.map<T, U>(list: { T }, mapper: (item: T, index: number) -> U): { U }
	local out = table.create(#list)
	for i = 1, #list do
		out[i] = mapper(list[i], i)
	end
	return out
end

--- Counts the items the predicate returns true for (all items without one)
--- @param list { T } -- Array
--- @param predicate ((item: T, index: number) -> boolean)? -- Test
--- @return number -- Count
function array.count<T>(list: { T }, predicate: ((item: T, index: number) -> boolean)?): number
	if not predicate then
		return #list
	end
	local total = 0
	for i = 1, #list do
		if predicate(list[i], i) then
			total += 1
		end
	end
	return total
end

return table.freeze(array)
