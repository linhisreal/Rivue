--[[
	Sets one version on every package, like Vue's single version for all of its packages.

	lune run version 2.57.0

	Updates packages/*/wally.toml and pesde.toml, Rivue.version, and the install lines in the README.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local version = process.args[1]
if not version or not string.match(version, "^%d+%.%d+%.%d+[%w%.%-]*$") then
	print("Usage: lune run version <major.minor.patch>, for example lune run version 2.57.0")
	process.exit(1)
end

local function update(path: string, pattern: string, replacement: string)
	local source = fs.readFile(path)
	local changed, count = string.gsub(source, pattern, replacement)
	if count == 0 then
		print(`No version found in {path}`)
		process.exit(1)
	end
	fs.writeFile(path, changed)
	print(`{path}: {version}`)
end

for _, name in fs.readDir("packages") do
	local dir = `packages/{name}`
	for _, manifest in { "wally.toml", "pesde.toml" } do
		if fs.isFile(`{dir}/{manifest}`) then
			update(`{dir}/{manifest}`, '\nversion = "[^"]*"', `\nversion = "{version}"`)
		end
	end
end

update("packages/rivue/src/runtime/main.luau", 'Rivue%.version = "[^"]*"', `Rivue.version = "{version}"`)
update("README.md", "(linhisreal/rivue[%w_%-]*@)[%w%.%-]+", `%1{version}`)
