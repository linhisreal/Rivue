--[[
	Builds the distributables into build/.

	lune run build              Rivue.rbxm, RivueRemote.rbxm, the test place and the examples place
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

exec("rojo", { "build", "default.project.json", "-o", `{OUT}/Rivue.rbxm` })
exec("rojo", { "build", "rivue-remote.project.json", "-o", `{OUT}/RivueRemote.rbxm` })
exec("rojo", { "build", "place.project.json", "-o", `{OUT}/RivueTestPlace.rbxl` })
exec("rojo", { "build", "examples.project.json", "-o", `{OUT}/RivueExamples.rbxl` })

if table.find(process.args, "minify") then
	local dir = `{OUT}/minified`
	exec("darklua", { "process", "src/shared/Rivue", `{dir}/Rivue`, "--config", ".darklua.json" })
	fs.writeFile(
		`{dir}/rivue.project.json`,
		[[{ "name": "Rivue", "tree": { "$path": "Rivue/Rivue.luau", "runtime": { "$path": "Rivue/runtime" } } }]]
	)
	exec("rojo", { "build", `{dir}/rivue.project.json`, "-o", `{OUT}/Rivue.min.rbxm` })
end

print(`Built into {OUT}/`)
