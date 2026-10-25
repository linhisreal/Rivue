--!strict
--!optimize 2

-- Rivue.debug: opt-in verbose logging, measure(), prettyPrint()/inspect() that see through
-- proxies, assertInvariant() and formatError().

local RunService = game:GetService("RunService")

local debug = {}

type PrettyPrintOptions = {
	indent: number?,
	maxDepth: number?,
	unwrapProxies: boolean?,
}

-- Set by main (requiring reactivity here would be circular)
debug._toRaw = nil :: ((unknown) -> unknown)?

-- Verbose runtime logging. Off by default: it prints for every vnode, mount and job.
-- Studio warnings (unknown props, bad keys, ...) don't depend on it.
debug.enabled = false

const IS_STUDIO = RunService:IsStudio()

function debug.log(component: string, message: string, data: unknown?)
	if not debug.enabled then
		return
	end

	local prefix = "[Rivue:DEBUG:" .. component .. "] "

	if data ~= nil then
		print(prefix .. message, data)
	else
		print(prefix .. message)
	end
end

--- Logs how long fn took, when debug.enabled is on
function debug.measure<R...>(name: string, fn: () -> R...): R...
	if not debug.enabled then
		return fn()
	end

	local startTime = os.clock()
	local results = table.pack(fn())
	local duration = (os.clock() - startTime) * 1000

	debug.log("Performance", `{name} took {string.format("%.3f", duration)}ms`)

	return (table.unpack :: any)(results, 1, results.n)
end

local function unwrapProxy(value: unknown): unknown
	local toRaw = debug._toRaw
	if toRaw and type(value) == "table" then
		return toRaw(value)
	end
	return value
end

local function formatKey(key: unknown): string
	return if type(key) == "string" then key else `[{tostring(key)}]`
end

local function formatScalar(v: unknown): string
	return if type(v) == "string" then `"{v}"` else tostring(v)
end

function debug.prettyPrint(value: unknown, options: PrettyPrintOptions?)
	local opts: PrettyPrintOptions = options or {}
	local indent = opts.indent or 0
	local maxDepth = opts.maxDepth or 10
	local unwrapProxies = opts.unwrapProxies ~= false
	local visited: { [unknown]: true } = {}

	local function printValue(input: unknown, currentIndent: number, currentDepth: number)
		local v = if unwrapProxies then unwrapProxy(input) else input
		local pad = string.rep("  ", currentIndent)

		if type(v) ~= "table" then
			print(pad .. formatScalar(v))
			return
		end
		if visited[v] then
			print(pad .. "<circular reference>")
			return
		end
		if currentDepth >= maxDepth then
			print(pad .. "<max depth reached>")
			return
		end

		visited[v] = true
		print(pad .. "{")
		for key, val in v :: { [unknown]: unknown } do
			print(`{pad}  {formatKey(key)} = `)
			printValue(val, currentIndent + 1, currentDepth + 1)
		end
		print(pad .. "}")
		visited[v] = nil
	end

	printValue(value, indent, 0)
end

function debug.inspect(value: unknown, depth: number?): string
	local maxDepth = depth or 3
	local visited: { [unknown]: true } = {}

	local function inspectValue(input: unknown, currentDepth: number, indent: string): string
		local v = unwrapProxy(input)
		if type(v) ~= "table" then
			return formatScalar(v)
		end
		if visited[v] then
			return "<circular>"
		end
		if currentDepth >= maxDepth then
			return "<...>"
		end

		visited[v] = true
		local nextIndent = indent .. "  "
		local parts = { "{" }
		for key, val in v :: { [unknown]: unknown } do
			table.insert(parts, `\n{nextIndent}{formatKey(key)} = {inspectValue(val, currentDepth + 1, nextIndent)}`)
		end
		visited[v] = nil

		if #parts == 1 then
			return "{}"
		end
		table.insert(parts, `\n{indent}}`)
		return table.concat(parts)
	end

	return inspectValue(value, 0, "")
end

--- Only checked in Studio
function debug.assertInvariant(condition: boolean, message: string)
	if (IS_STUDIO or debug.enabled) and not condition then
		error("[Rivue:Invariant] " .. message, 2)
	end
end

function debug.formatError(component: string, message: string, context: unknown?): string
	local parts = { "[Rivue:" .. component .. "] " .. message }

	if context then
		table.insert(parts, "\nContext: " .. debug.inspect(context, 2))
	end

	return table.concat(parts)
end

return debug
