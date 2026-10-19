--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local h = Rivue.h

const RUNS = 5
const ROWS = 1000

local clock: () -> number = (__realClock :: any) or os.clock

local function median(values: { number }): number
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[math.ceil(#sorted / 2)]
end

local function measure(name: string, setup: () -> (() -> (), (() -> ())?))
	local times, heaps = {}, {}
	for run = 0, RUNS do
		local body, teardown = setup()
		local heapBefore = collectgarbage("count")
		local started = clock()
		body()
		local elapsed = (clock() - started) * 1000
		local heapGrowth = collectgarbage("count") - heapBefore
		if teardown then
			teardown()
		end
		if run > 0 then
			table.insert(times, elapsed)
			table.insert(heaps, heapGrowth)
		end
	end
	print(string.format("BENCH %s %.3f %.1f", name, median(times), median(heaps)))
end

local function makeRows(count: number, prefix: string?): { { id: number, name: string } }
	local list = table.create(count)
	for i = 1, count do
		list[i] = { id = i, name = `{prefix or "Item"} {i}` }
	end
	return list
end

local function mountList(items: any)
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
	end, { name = "BenchList" })
	local app = Rivue.createApp(App)
	app:mount(Instance.new("Frame"))
	return app
end

return function()
	print("\n========== RENDER BENCHMARK ==========\n")

	measure("mount-1000-rows", function()
		local items = Rivue.ref(makeRows(ROWS))
		local app
		return function()
			app = mountList(items)
		end, function()
			app:unmount()
		end
	end)

	measure("rerender-unchanged-1000", function()
		local items = Rivue.ref(makeRows(ROWS))
		local app = mountList(items)
		return function()
			for _ = 1, 10 do
				items.value = table.clone(items.value)
				Rivue.nextTick()
			end
		end, function()
			app:unmount()
		end
	end)

	measure("update-one-of-1000", function()
		local items = Rivue.ref(makeRows(ROWS))
		local app = mountList(items)
		return function()
			for i = 1, 10 do
				local list = table.clone(items.value)
				list[500] = { id = 500, name = `Changed {i}` }
				items.value = list
				Rivue.nextTick()
			end
		end, function()
			app:unmount()
		end
	end)

	measure("reorder-1000", function()
		local items = Rivue.ref(makeRows(ROWS))
		local app = mountList(items)
		return function()
			for _ = 1, 4 do
				local list = items.value
				local reversed = table.create(#list)
				for i = #list, 1, -1 do
					table.insert(reversed, list[i])
				end
				items.value = reversed
				Rivue.nextTick()
			end
		end, function()
			app:unmount()
		end
	end)

	measure("binding-1000-updates", function()
		local text = Rivue.ref("0")
		local App = Rivue.defineComponent(function()
			return function()
				return h("TextLabel", { Text = text })
			end
		end, { name = "BenchBinding" })
		local app = Rivue.createApp(App)
		app:mount(Instance.new("Frame"))
		return function()
			for i = 1, 1000 do
				text.value = tostring(i)
				Rivue.nextTick()
			end
		end, function()
			app:unmount()
		end
	end)

	measure("computed-chain-100", function()
		local base = Rivue.ref(0)
		local chain: { any } = { base }
		for i = 2, 100 do
			local previous = chain[i - 1]
			chain[i] = Rivue.computed(function()
				return previous.value + 1
			end)
		end
		local seen = 0
		local stop = Rivue.watchEffect(function()
			seen = chain[100].value
		end)
		return function()
			for i = 1, 200 do
				base.value = i
				Rivue.nextTick()
			end
		end, function()
			stop()
		end
	end)

	print("\n========== RENDER BENCHMARK COMPLETE ==========\n")
end
