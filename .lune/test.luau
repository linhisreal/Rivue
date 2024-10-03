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
		local shown = 0
		for _, line in result.output do
			if
				shown < 5
				and (
					string.find(line, "FAIL")
					or string.find(line, "TIMEOUT")
					or string.find(line, "THREAD ERROR")
					or string.find(line, "error")
				)
			then
				print("  " .. line)
				shown += 1
			end
		end
	end
end

process.exit(if failed > 0 then 1 else 0)
