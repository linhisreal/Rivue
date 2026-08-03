-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

--[[
	Runs a bundled script (see bundle.luau) in its own global environment and captures what it
	prints. The prelude replaces task, os, game and the rest inside that environment only, so
	suites can't leak globals into each other or into Lune.
]]

local luau = require("@lune/luau")

export type RunResult = {
	ok: boolean,
	output: { string },
}

local function run(source: string, name: string): RunResult
	local output = {}
	local function capture(...: any)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = tostring(parts[i])
		end
		table.insert(output, table.concat(parts, "\t", 1, parts.n))
	end

	-- Lune adds the standard globals to this table; print and warn stay captured
	local env = { print = capture, warn = capture }
	local ok, err = pcall(function()
		luau.load(source, { debugName = name, environment = env })()
	end)
	if not ok then
		table.insert(output, tostring(err))
	end
	return { ok = ok, output = output }
end

return run
