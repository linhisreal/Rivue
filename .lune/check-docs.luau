--[[
	Checks the docs: relative links and #anchors resolve, and every API example runs.

	lune run check-docs

	Examples are the ```lua blocks in docs/api/*.md, except the ones under a **Type**, **Props**
	or **Expects** heading (those are signatures). Each one runs in the offline test harness with
	`Rivue`, `h`, `array` and `Players` defined, the same as the docs assume. Put
	<!-- server --> on the line before an example that should run as the server.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local bundle = require("./lib/bundle")
local run = require("./lib/run")

local PREAMBLE = [[
local Rivue = require(game:GetService("ReplicatedStorage"):WaitForChild("Rivue"))
local h = Rivue.h
local Players = game:GetService("Players")
local array = Rivue.array
]]

local function markdownIn(dir: string): { string }
	local files = {}
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		if string.sub(name, -3) == ".md" then
			table.insert(files, `{dir}/{name}`)
		end
	end
	return files
end

local docFiles = { "README.md" }
for _, dir in { "docs", "docs/guide", "docs/api", "examples" } do
	for _, file in markdownIn(dir) do
		table.insert(docFiles, file)
	end
end

local function lines(text: string): { string }
	return string.split(text, "\n")
end

local function trimStart(line: string): string
	return (string.gsub(line, "^%s+", ""))
end

local function isFence(line: string): boolean
	return string.sub(trimStart(line), 1, 3) == "```"
end

-- Resolves "a/b/../c" style paths
local function normalize(path: string): string
	local parts = {}
	for _, part in string.split(path, "/") do
		if part == ".." then
			table.remove(parts)
		elseif part ~= "." and part ~= "" then
			table.insert(parts, part)
		end
	end
	return table.concat(parts, "/")
end

local function dirname(path: string): string
	return string.match(path, "^(.*)/[^/]*$") or ""
end

local function exists(path: string): boolean
	return fs.isFile(path) or fs.isDir(path)
end

-- GitHub's anchor for a heading
local function slug(heading: string): string
	local text = string.lower((string.gsub(heading, "^%s+", "")))
	text = string.gsub(text, "%s+$", "")
	text = string.gsub(text, "[^%w%-_ ]", "")
	return (string.gsub(text, " ", "-"))
end

local anchorCache: { [string]: { [string]: boolean } } = {}
local function anchorsOf(path: string): { [string]: boolean }
	if anchorCache[path] then
		return anchorCache[path]
	end
	local seen: { [string]: number } = {}
	local result = {}
	local inCode = false
	for _, line in lines(fs.readFile(path)) do
		if isFence(line) then
			inCode = not inCode
		elseif not inCode then
			local heading = string.match(line, "^#+%s+(.*)")
			if heading then
				local base = slug(heading)
				local count = seen[base] or 0
				result[if count == 0 then base else `{base}-{count}`] = true
				seen[base] = count + 1
			end
		end
	end
	anchorCache[path] = result
	return result
end

local function checkLinks(errors: { string })
	for _, path in docFiles do
		local text = string.gsub(fs.readFile(path), "```.-```", "")
		for target in string.gmatch(text, "%]%(([^)%s]+)%)") do
			if string.match(target, "^%a+://") or string.sub(target, 1, 7) == "mailto:" then
				continue
			end
			local filePart, anchor = string.match(target, "^([^#]*)#?(.*)$")
			local dest = if filePart ~= "" then normalize(`{dirname(path)}/{filePart}`) else path
			if not exists(dest) then
				table.insert(errors, `{path}: broken link {target}`)
			elseif anchor ~= "" and string.sub(dest, -3) == ".md" and not anchorsOf(dest)[anchor] then
				table.insert(errors, `{path}: missing anchor {target}`)
			end
		end
	end
end

type Example = { label: string, code: string, server: boolean }

local function collectExamples(): { Example }
	local out = {}
	for _, path in markdownIn("docs/api") do
		local name = string.match(path, "[^/]+$") :: string
		local text = lines(fs.readFile(path))
		local section: string? = nil
		local seenHeading = false
		local server = false
		local i = 1
		while i <= #text do
			local line = text[i]
			if string.sub(line, 1, 3) == "## " then
				seenHeading = true
			end
			local label = string.match(line, "^%s*%- %*%*(%w+)")
			if label then
				section = label
			end
			if string.match(line, "^%s*<!%-%- server %-%->%s*$") then
				server = true
			end
			if string.sub(trimStart(line), 1, 6) == "```lua" then
				local indent = #line - #trimStart(line)
				local start = i + 1
				local body = {}
				i += 1
				while not isFence(text[i]) do
					table.insert(body, string.sub(text[i], indent + 1))
					i += 1
				end
				-- Blocks before the first entry are the page's "examples assume" preamble
				if seenHeading and section ~= "Type" and section ~= "Props" and section ~= "Expects" then
					table.insert(out, { label = `{name}:{start}`, code = table.concat(body, "\n"), server = server })
				end
				server = false
			end
			i += 1
		end
	end
	return out
end

local function checkExamples(errors: { string }): number
	local examples = collectExamples()
	-- One closure per example, so locals don't pile up in a single function
	local source = { "local examples = {}" }
	for _, example in examples do
		table.insert(
			source,
			`table.insert(examples, \{ "{example.label}", function()\n{PREAMBLE}\n{example.code}\nend, {example.server} })`
		)
	end
	table.insert(
		source,
		[[
return function()
	local RunService = game:GetService("RunService")
	for _, example in examples do
		if example[3] then
			RunService.IsServer = function() return true end
			RunService.IsClient = function() return false end
		end
		local ok, err = pcall(example[2])
		RunService.IsServer = function() return false end
		RunService.IsClient = function() return true end
		if not ok then print("DOCFAIL " .. example[1] .. ": " .. tostring(err)) end
		task.wait(0.05)
	end
end]]
	)

	local result = run(bundle({ { name = "DocExamples", source = table.concat(source, "\n") } }), "DocExamples")
	local finished = false
	for _, line in result.output do
		if string.sub(line, 1, 7) == "DOCFAIL" or string.find(line, "THREAD ERROR", 1, true) then
			table.insert(errors, line)
		end
		if string.find(line, "RESULT: 1 passed", 1, true) then
			finished = true
		end
	end
	if not finished then
		local tail = table.move(result.output, math.max(1, #result.output - 7), #result.output, 1, {})
		table.insert(errors, "examples didn't run to completion:\n" .. table.concat(tail, "\n"))
	end
	return #examples
end

local errors = {}
checkLinks(errors)
local count = checkExamples(errors)
for _, err in errors do
	print(err)
end
print(`{count} examples, {#docFiles} docs checked, {#errors} problems`)
process.exit(if #errors > 0 then 1 else 0)
