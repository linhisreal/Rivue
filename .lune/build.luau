--[[
	Builds the distributables into build/.

	lune run build              Rivue.rbxm, RivueRemote.rbxm, RivueRouter.rbxm, RivueDevTools.rbxm and the dev place
	lune run build minify       also Rivue.min.rbxm: comments and whitespace stripped by darklua
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local OUT = "build"

local function exec(program: string, args: { string })
	print(`> {program} {table.concat(args, " ")}`)
	local result = process.exec(program, args, { stdio = "inherit" })
	if not result.ok then
		print(`{program} failed with exit code {result.code}`)
		process.exit(1)
	end
end

if fs.isDir(OUT) then
	fs.removeDir(OUT)
end
fs.writeDir(OUT)

exec("rojo", { "build", "packages/rivue", "-o", `{OUT}/Rivue.rbxm` })
exec("rojo", { "build", "packages/rivue-remote", "-o", `{OUT}/RivueRemote.rbxm` })
exec("rojo", { "build", "packages/rivue-router", "-o", `{OUT}/RivueRouter.rbxm` })
exec("rojo", { "build", "packages/rivue-devtools", "-o", `{OUT}/RivueDevTools.rbxm` })
exec("rojo", { "build", "default.project.json", "-o", `{OUT}/RivueDevPlace.rbxl` })

if table.find(process.args, "minify") then
	local dir = `{OUT}/minified`
	exec("darklua", { "process", "packages/rivue/src", `{dir}/src`, "--config", ".darklua.json" })
	fs.writeFile(`{dir}/default.project.json`, [[{ "name": "Rivue", "tree": { "$path": "src" } }]])
	exec("rojo", { "build", dir, "-o", `{OUT}/Rivue.min.rbxm` })
end

print(`Built into {OUT}/`)
