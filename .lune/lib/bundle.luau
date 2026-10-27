-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

--[[
	Builds one script out of the offline prelude, the runtime, the examples, the demo app and
	the given test suites, so they run outside Studio. Replaces Instance-based requires with
	__defineModule (see tests/offline/prelude.luau).
]]

local fs = require("@lune/fs")

local function luauFiles(dir: string): { string }
	local names = {}
	for _, name in fs.readDir(dir) do
		if string.sub(name, -5) == ".luau" then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

local function moduleName(file: string): string
	return string.sub(file, 1, -6)
end

local function defineModule(out: { string }, parentVar: string, name: string, source: string)
	table.insert(
		out,
		`__defineModule({parentVar}, "{name}", function(script)\nlocal require = __requireFrom(script)\n{source}\nend)`
	)
end

local function addFolder(out: { string }, path: string, var: string, parentVar: string, name: string)
	table.insert(out, `local {var} = makeFolder("{name}", {parentVar})\n{parentVar}._children["{name}"] = {var}`)
	local entries = fs.readDir(path)
	table.sort(entries)
	for _, entry in entries do
		local full = `{path}/{entry}`
		if fs.isDir(full) then
			addFolder(out, full, `{var}_{entry}`, var, entry)
		elseif string.sub(entry, -5) == ".luau" then
			defineModule(out, var, moduleName(entry), fs.readFile(full))
		end
	end
end

export type Suite = { name: string, source: string }

local function bundle(suites: { Suite }): string
	local out = { fs.readFile("tests/offline/prelude.luau") }

	local runtime = "packages/rivue-ui/src/runtime"
	for _, file in luauFiles(runtime) do
		defineModule(out, "runtimeFolder", moduleName(file), fs.readFile(`{runtime}/{file}`))
	end

	addFolder(out, "examples/components", "examplesFolder", "ReplicatedStorage", "Examples")
	addFolder(out, "dev/Demo", "demoFolder", "ReplicatedStorage", "Demo")
	addFolder(out, "packages/rivue-devtools/src", "devtoolsFolder", "ReplicatedStorage", "RivueDevTools")
	-- The plugin requires its own copy of Rivue next to it
	table.insert(out, "devtoolsFolder._children.RivueUI = rivueScript")
	defineModule(out, "nil", "RivueUI", fs.readFile("packages/rivue-ui/src/init.luau"))
	defineModule(out, "ReplicatedStorage", "RivueRemote", fs.readFile("packages/rivue-remote/src/init.luau"))
	defineModule(out, "ReplicatedStorage", "RivueRouter", fs.readFile("packages/rivue-router/src/init.luau"))

	for _, suite in suites do
		table.insert(out, `__runTest("{suite.name}", function(script)\n{suite.source}\nend)`)
	end
	table.insert(out, "__finish()")
	return table.concat(out, "\n")
end

return bundle
