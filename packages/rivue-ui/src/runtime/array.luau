--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local reactivity = require("./reactivity")

local toRaw = reactivity.toRaw
local triggerListChange = reactivity._triggerListChange

local array = {}

local function rawOf<T>(list: { T }): { T }
	if reactivity.isReadonly(list) then
		error("[Rivue] Can't change a readonly array", 3)
	end
	return toRaw(list)
end

function array.push<T>(list: { T }, ...: T): number
	local raw = rawOf(list)
	local first = #raw + 1
	for i = 1, select("#", ...) do
		raw[#raw + 1] = toRaw((select(i, ...)))
	end
	triggerListChange(raw, first, #raw, true)
	return #raw
end

function array.insert<T>(list: { T }, index: number, value: T)
	local raw = rawOf(list)
	table.insert(raw, index, toRaw(value))
	triggerListChange(raw, index, #raw, true)
end

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

function array.removeValue<T>(list: { T }, value: T): boolean
	local raw = rawOf(list)
	local index = table.find(raw, toRaw(value))
	if not index then
		return false
	end
	array.remove(list, index)
	return true
end

function array.removeWhere<T>(list: { T }, predicate: (item: T, index: number) -> boolean): number
	local raw = rawOf(list)
	local count = #raw
	-- Decided up front, so a predicate that errors leaves the list intact
	local keep = table.create(count)
	for i = 1, count do
		local item = raw[i]
		local view = if type(item) == "table" and list ~= raw then (list :: any)[i] else item
		keep[i] = not predicate(view, i)
	end
	local kept = 0
	for i = 1, count do
		if keep[i] then
			kept += 1
			raw[kept] = raw[i]
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

function array.splice<T>(list: { T }, start: number, deleteCount: number?, ...: T): { T }
	local raw = rawOf(list)
	local count = #raw
	start = math.clamp(start, 1, count + 1)
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

function array.move<T>(list: { T }, from: number, to: number)
	if from == to then
		return
	end
	local raw = rawOf(list)
	local item = table.remove(raw, from)
	table.insert(raw, to, item :: T)
	triggerListChange(raw, math.min(from, to), math.max(from, to), false)
end

function array.sort<T>(list: { T }, comparator: ((a: T, b: T) -> boolean)?)
	local raw = rawOf(list)
	table.sort(raw, comparator)
	triggerListChange(raw, 1, #raw, false)
end

function array.clear<T>(list: { T })
	local raw = rawOf(list)
	local count = #raw
	if count == 0 then
		return
	end
	table.clear(raw)
	triggerListChange(raw, 1, count, true)
end

--- table.find doesn't see through proxies, this does
function array.indexOf<T>(list: { T }, value: T): number?
	local target = toRaw(value)
	for i = 1, #list do
		if toRaw(list[i]) == target then
			return i
		end
	end
	return nil
end

function array.find<T>(list: { T }, predicate: (item: T, index: number) -> boolean): (T?, number?)
	for i = 1, #list do
		local item = list[i]
		if predicate(item, i) then
			return item, i
		end
	end
	return nil, nil
end

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

function array.map<T, U>(list: { T }, mapper: (item: T, index: number) -> U): { U }
	local out = table.create(#list)
	for i = 1, #list do
		out[i] = mapper(list[i], i)
	end
	return out
end

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
