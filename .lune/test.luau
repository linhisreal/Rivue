-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

--[[
	Runs the test suites outside Studio.

	lune run test                              every suite
	lune run test tests/Renderer.test.luau     only these files
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local bundle = require("./lib/bundle")
local run = require("./lib/run")

local function suites(): { string }
	if #process.args > 0 then
		return process.args
	end
	local files = {}
	for _, dir in { "tests", "tests/offline" } do
		local names = fs.readDir(dir)
		table.sort(names)
		for _, name in names do
			if string.sub(name, -10) == ".test.luau" then
				table.insert(files, `{dir}/{name}`)
			end
		end
	end
	return files
end

local failed = 0
for _, file in suites() do
	local name = string.match(file, "[^/\\]+$") or file
	local result = run(bundle({ { name = name, source = fs.readFile(file) } }), name)
	if result.ok and table.find(result.output, "RESULT: 1 passed, 0 failed") then
		print(string.format("%-40s ok", name))
	else
		failed += 1
		print(string.format("%-40s FAILED", name))
		-- Failures first: a passing line that mentions "error" mustn't push the real one out of view
		local shown = 0
		for _, patterns in { { "FAIL", "TIMEOUT", "THREAD ERROR" }, { "error" } } do
			for _, line in result.output do
				local hit = false
				for _, pattern in patterns do
					if string.find(line, pattern, 1, true) then
						hit = true
					end
				end
				if hit and shown < 5 and not string.find(line, "✓", 1, true) then
					print("  " .. line)
					shown += 1
				end
			end
		end
	end
end

process.exit(if failed > 0 then 1 else 0)
