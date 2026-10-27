--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

-- Offline only: counts engine calls (Instance property reads/writes and method lookups), which
-- is what costs the most in Roblox, and fails if a common update gets more expensive

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local h = Rivue.h

local function engineCalls(fn: () -> ()): number
	__instanceOps = 0
	fn()
	return __instanceOps
end

local function assertAtMost(actual: number, limit: number, message: string)
	if actual > limit then
		error(`Assertion failed: {message}\nLimit: {limit}\nActual: {actual}`)
	end
	print("✓", `{message} ({actual} engine calls)`)
end

return function()
	print("\n========== PERFORMANCE TEST SUITE ==========\n")

	local rows = 1000
	local items = Rivue.ref({})
	local list = {}
	for i = 1, rows do
		list[i] = { id = i, name = `Item {i}` }
	end
	items.value = list

	local App = Rivue.defineComponent(function()
		return function()
			return h("Frame", nil, {
				h("UIListLayout"),
				Rivue.hFor(items.value, function(item)
					return h("TextButton", {
						key = item.id,
						Text = item.name,
						Size = UDim2.new(1, 0, 0, 20),
						onClick = function() end,
					})
				end),
			})
		end
	end, { name = "PerfApp" })

	local app
	assertAtMost(
		engineCalls(function()
			app = Rivue.createApp(App)
			app:mount(Instance.new("Frame"))
		end),
		rows * 8,
		"Mounting 1000 rows"
	)

	assertAtMost(
		engineCalls(function()
			items.value[5].name = "changed"
			Rivue.nextTick()
		end),
		20,
		"Re-rendering 1000 rows with one changed"
	)

	assertAtMost(
		engineCalls(function()
			local copy = table.clone(Rivue.toRaw(items.value))
			table.remove(copy, 10)
			items.value = copy
			Rivue.nextTick()
		end),
		20,
		"Removing one row"
	)

	assertAtMost(
		engineCalls(function()
			local raw = Rivue.toRaw(items.value)
			local reversed = {}
			for i = #raw, 1, -1 do
				table.insert(reversed, raw[i])
			end
			items.value = reversed
			Rivue.nextTick()
		end),
		rows + 20,
		"Reversing 1000 rows (one LayoutOrder write each)"
	)

	assertAtMost(
		engineCalls(function()
			local raw = Rivue.toRaw(items.value)
			local renamed = table.create(#raw)
			for i, item in raw do
				renamed[i] = { id = item.id, name = `Renamed {item.id}` }
			end
			items.value = renamed
			Rivue.nextTick()
		end),
		rows + 20,
		"Changing every row's text (one Text write each, no IsA per row)"
	)

	assertAtMost(
		engineCalls(function()
			local raw = Rivue.toRaw(items.value)
			local prepended = table.clone(raw)
			table.insert(prepended, 1, { id = 100000, name = "New" })
			items.value = prepended
			Rivue.nextTick()
		end),
		20,
		"Prepending one row (one LayoutOrder write, not one per row)"
	)

	assertAtMost(
		engineCalls(function()
			local raw = table.clone(Rivue.toRaw(items.value))
			table.insert(raw, 1, table.remove(raw))
			items.value = raw
			Rivue.nextTick()
		end),
		20,
		"Moving the last row to the front"
	)

	app:unmount()
	print("\n========== PERFORMANCE TESTS COMPLETE ==========\n")
end
