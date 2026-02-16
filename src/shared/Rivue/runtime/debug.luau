--!strict
--!optimize 2

-- Debug & Development Utilities
-- ==============================
--
-- Unified debugging, logging, and development utilities for the Rivue.
-- Combines performance measurement, pretty-printing, inspection, and assertions.
--
-- @module debug
-- @author Rivue
-- @version 2.0.0
--
-- Public API:
-- -----------
--
-- Logging & Performance:
-- 	debug.enabled: boolean
-- 		--- Global debug flag. Set to true to enable verbose logging.
-- 		--- Automatically set to RunService:IsStudio() by default.
--
-- 	debug.log(component: string, message: string, data: any?)
-- 		--- Logs a debug message for a specific component.
-- 		--- Only logs when debug.enabled is true.
--
-- 	debug.measure(name: string, fn: () -> T) -> T
-- 		--- Measures execution time of a function (only when debug.enabled).
--
-- Pretty Printing & Inspection:
-- 	debug.prettyPrint(value: any, options: PrettyPrintOptions?)
-- 		--- Pretty-prints any value, unwrapping reactive proxies automatically.
-- 		--- Works with nested tables, proxies, and circular references.
--
-- 	debug.inspect(value: any, depth: number?) -> string
-- 		--- Returns a string representation of a value for debugging.
--
-- Assertions & Error Formatting:
-- 	debug.assertInvariant(condition: boolean, message: string)
-- 		--- Asserts an invariant in dev mode. Throws if condition is false.
--
-- 	debug.formatError(component: string, message: string, context: any?) -> string
-- 		--- Creates a formatted error message with context.
--
-- Usage Example:
-- --------------
--
-- 	local debug = require(script.Parent.debug)
--
-- 	-- Logging & Performance
-- 	debug.enabled = true
-- 	debug.log("Scheduler", "Flushing micro queue", { jobCount = 5 })
-- 	local result = debug.measure("FlushMicro", function() return 42 end)
--
-- 	-- Pretty Printing
-- 	local state = Rivue.reactive({ user = { name = "Alice" } })
-- 	debug.prettyPrint(state)
-- 	print(debug.inspect(state, 2))
--
-- 	-- Assertions
-- 	debug.assertInvariant(state.user.name == "Alice", "Name must be Alice")

local RunService = game:GetService("RunService")

local debug = {}

type PrettyPrintOptions = {
	indent: number?,
	maxDepth: number?,
	unwrapProxies: boolean?,
}

-- Internal reference to toRaw function (set by main.luau to avoid circular dependency)
debug._toRaw = nil :: ((unknown) -> unknown)?

-- Automatically enable debug mode in Studio, disable in published games
-- Verbose runtime logging. Off by default: it prints for every vnode, mount and job.
-- Studio warnings (unknown props, bad keys, ...) don't depend on it.
debug.enabled = false

const IS_STUDIO = RunService:IsStudio()

-- =============================================================================
-- LOGGING & PERFORMANCE
-- =============================================================================

--- Logs a debug message for a specific component
--- Only logs when debug.enabled is true
--- @param component string -- Component name (e.g., "Scheduler", "Reactivity")
--- @param message string -- Debug message
--- @param data unknown? -- Optional additional data to log
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

--- Measures execution time of a function (only when debug.enabled)
--- Logs the duration automatically
--- @param name string -- Name for the measurement
--- @param fn () -> R... -- Function to measure
--- @return R... -- Return values of fn (generic pack, so callers keep their types)
function debug.measure<R...>(name: string, fn: () -> R...): R...
	if not debug.enabled then
		return fn()
	end

	local startTime = os.clock()
	local results = table.pack(fn())
	local duration = (os.clock() - startTime) * 1000 -- Convert to milliseconds

	debug.log("Performance", `{name} took {string.format("%.3f", duration)}ms`)

	return (table.unpack :: any)(results, 1, results.n)
end

-- =============================================================================
-- PRETTY PRINTING & INSPECTION
-- =============================================================================

--- Unwraps a reactive proxy to its raw table
--- @param value unknown -- Value to unwrap
--- @return unknown -- Raw value or the original value
local function unwrapProxy(value: unknown): unknown
	local toRaw = debug._toRaw
	if toRaw and type(value) == "table" then
		return toRaw(value)
	end
	return value
end

--- Formats a table key for display
--- @param key unknown -- Table key
--- @return string -- `name` for string keys, `[key]` otherwise
local function formatKey(key: unknown): string
	return if type(key) == "string" then key else `[{tostring(key)}]`
end

--- Formats a non-table value for display
--- @param v unknown -- Value
--- @return string -- Display text
local function formatScalar(v: unknown): string
	return if type(v) == "string" then `"{v}"` else tostring(v)
end

--- Pretty-prints a value with proper formatting, unwrapping proxies
--- @param value unknown -- Value to print
--- @param options PrettyPrintOptions? -- Formatting options
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

--- Returns a string representation of a value for debugging
--- @param value unknown -- Value to inspect
--- @param depth number? -- Maximum depth (default: 3)
--- @return string -- String representation
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

--- Asserts an invariant in Studio. Throws if condition is false.
--- @param condition boolean -- Condition that must be true
--- @param message string -- Error message if condition fails
function debug.assertInvariant(condition: boolean, message: string)
	if (IS_STUDIO or debug.enabled) and not condition then
		error("[Rivue:Invariant] " .. message, 2)
	end
end

--- Creates a formatted error message with context
--- @param component string -- Component name
--- @param message string -- Error message
--- @param context any? -- Optional context data
--- @return string -- Formatted error message
function debug.formatError(component: string, message: string, context: unknown?): string
	local parts = { "[Rivue:" .. component .. "] " .. message }

	if context then
		table.insert(parts, "\nContext: " .. debug.inspect(context, 2))
	end

	return table.concat(parts)
end

return debug
