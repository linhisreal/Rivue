-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

--[[
	Runs the benchmarks in tests/bench outside Studio and prints a table of median wall time
	and heap growth per scenario. It reports and never fails, so compare runs by eye.

	lune run bench
]]

local fs = require("@lune/fs")

local bundle = require("./lib/bundle")
local run = require("./lib/run")

local rows = {}
local names = fs.readDir("tests/bench")
table.sort(names)
for _, name in names do
	if string.sub(name, -11) == ".bench.luau" then
		local result = run(bundle({ { name = name, source = fs.readFile(`tests/bench/{name}`) } }), name)
		for _, line in result.output do
			local scenario, ms, kb = string.match(line, "^BENCH (%S+) (%S+) (%S+)$")
			if scenario then
				table.insert(rows, { scenario, ms, kb })
			end
		end
		if not result.ok then
			print(`{name} failed:`)
			for _, line in result.output do
				print("  " .. line)
			end
		end
	end
end

print(string.format("%-28s %12s %12s", "scenario", "median ms", "heap kb"))
for _, row in rows do
	print(string.format("%-28s %12s %12s", row[1], row[2], row[3]))
end
