--[[
	Sets the version of one package. Each package has its own version; the repo's releases are
	tagged separately (see docs/RELEASING.md).

	lune run version rivue-ui 0.9.0-rc.2
	lune run version rivue-remote 0.5.0-beta.2

	Updates that package's wally.toml and pesde.toml (and lockfiles, if you have them locally), the
	version field in its source, and its install line in the README.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local packageName = process.args[1]
local version = process.args[2]

local function usage()
	local names = {}
	for _, name in fs.readDir("packages") do
		if fs.isFile(`packages/{name}/wally.toml`) or fs.isFile(`packages/{name}/pesde.toml`) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	print("Usage: lune run version <package> <version>, for example lune run version rivue-ui 0.9.0-rc.2")
	print(`Packages: {table.concat(names, ", ")}`)
	process.exit(1)
end

local dir = if packageName then `packages/{packageName}` else ""
if not packageName or not fs.isDir(dir) then
	usage()
end
if not version or not string.match(version, "^%d+%.%d+%.%d+[%w%.%-]*$") then
	usage()
end

local function update(path: string, pattern: string, replacement: string, required: boolean)
	if not fs.isFile(path) then
		return
	end
	local source = fs.readFile(path)
	local changed, count = string.gsub(source, pattern, replacement)
	if count == 0 then
		if required then
			print(`No version found in {path}`)
			process.exit(1)
		end
		return
	end
	fs.writeFile(path, changed)
	print(`{path}: {version}`)
end

local function escape(text: string): string
	return (string.gsub(text, "[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%0"))
end

for _, manifest in { "wally.toml", "pesde.toml" } do
	update(`{dir}/{manifest}`, '\nversion = "[^"]*"', `\nversion = "{version}"`, true)
end
for _, lockfile in { "wally.lock", "pesde.lock" } do
	update(`{dir}/{lockfile}`, '\nversion = "[^"]*"', `\nversion = "{version}"`, false)
end

-- The `.version = "..."` field each package exposes at runtime
for _, source in { `{dir}/src/runtime/main.luau`, `{dir}/src/init.luau` } do
	update(source, '([%.%s]version = )"[^"]*"', `%1"{version}"`, false)
end

-- The Wally install line in the README, matched by this package's exact Wally name
local wallyToml = if fs.isFile(`{dir}/wally.toml`) then fs.readFile(`{dir}/wally.toml`) else ""
local wallyName = string.match(wallyToml, 'name = "([^"]+)"')
if wallyName then
	update("README.md", `({escape(wallyName)}@)[%w%.%-]+"`, `%1{version}"`, false)
end
