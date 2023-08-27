--!strict
--!optimize 2
--!native

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
debug._toRaw = nil :: ((any) -> any)?

-- Automatically enable debug mode in Studio, disable in published games
debug.enabled = RunService and RunService:IsStudio() or false

-- =============================================================================
-- LOGGING & PERFORMANCE
-- =============================================================================

--- Logs a debug message for a specific component
--- Only logs when debug.enabled is true
--- @param component string -- Component name (e.g., "Scheduler", "Reactivity")
--- @param message string -- Debug message
--- @param data any? -- Optional additional data to log
function debug.log(component: string, message: string, data: any?)
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
--- @param fn () -> T -- Function to measure
--- @return ...any -- Return values of fn
function debug.measure(name: string, fn: (...any) -> ...any): ...any
	if not debug.enabled then
		return fn()
	end

	local startTime = os.clock()
	local results = table.pack(fn())
	local duration = (os.clock() - startTime) * 1000 -- Convert to milliseconds

	debug.log("Performance", name .. " took " .. string.format("%.3f", duration) .. "ms")

	return table.unpack(results, 1, results.n)
end

-- =============================================================================
-- PRETTY PRINTING & INSPECTION
-- =============================================================================

--- Checks if a value is a reactive proxy
--- @param value any -- Value to check
--- @return boolean -- True if value appears to be a reactive proxy
local function isReactiveProxy(value: any): boolean
	if type(value) ~= "table" then
		return false
	end

	local mt = getmetatable(value)
	if mt and (mt.__isReactive or mt.__isProxy or mt.__isRef) then
		return true
	end

	return false
end

--- Unwraps a reactive proxy to get the raw underlying value
--- @param value any -- Value to unwrap
--- @return any -- Raw value or original value if not a proxy
local function unwrapProxy(value: any): any
	if not isReactiveProxy(value) then
		return value
	end

	-- Try to access raw value from metatable directly (avoid circular dependency)
	local mt = getmetatable(value)
	if mt and mt.__raw then
		return mt.__raw
	end

	-- Fallback: try toRaw if available via shared state
	-- This will be set by main.luau after initialization
	if debug._toRaw then
		return debug._toRaw(value)
	end

	return value
end

--- Pretty-prints a value with proper formatting, unwrapping proxies
--- @param value any -- Value to print
--- @param options PrettyPrintOptions? -- Optional formatting options
function debug.prettyPrint(value: any, options: PrettyPrintOptions?)
	local opts: PrettyPrintOptions = options or {} :: PrettyPrintOptions
	local indent: number = opts.indent or 0
	local maxDepth: number = opts.maxDepth or 10
	local unwrapProxies: boolean = opts.unwrapProxies ~= false

	local visited = {}

	local function printValue(v: any, currentIndent: number, currentDepth: number)
		if unwrapProxies and isReactiveProxy(v) then
			v = unwrapProxy(v)
		end

		local vType = type(v)

		if vType ~= "table" then
			if vType == "string" then
				print(string.rep("  ", currentIndent) .. '"' .. tostring(v) .. '"')
			else
				print(string.rep("  ", currentIndent) .. tostring(v))
			end
			return
		end

		if visited[v] then
			print(string.rep("  ", currentIndent) .. "<circular reference>")
			return
		end

		if currentDepth >= maxDepth then
			print(string.rep("  ", currentIndent) .. "<max depth reached>")
			return
		end

		visited[v] = true

		print(string.rep("  ", currentIndent) .. "{")

		for key, val in pairs(v) do
			local keyStr = type(key) == "string" and key or "[" .. tostring(key) .. "]"
			print(string.rep("  ", currentIndent + 1) .. keyStr .. " = ")
			printValue(val, currentIndent + 1, currentDepth + 1)
		end

		print(string.rep("  ", currentIndent) .. "}")

		visited[v] = nil
	end

	printValue(value, indent, 0)
end

--- Returns a string representation of a value for debugging
--- @param value any -- Value to inspect
--- @param depth number? -- Maximum depth (default: 3)
--- @return string -- String representation
function debug.inspect(value: any, depth: number?): string
	depth = depth or 3
	local visited = {}

	local function inspectValue(v: any, currentDepth: number, indent: string): string
		if isReactiveProxy(v) then
			v = unwrapProxy(v)
		end

		local vType = type(v)

		if vType ~= "table" then
			if vType == "string" then
				return '"' .. tostring(v) .. '"'
			else
				return tostring(v)
			end
		end

		if visited[v] then
			return "<circular>"
		end

		if currentDepth >= (depth or 5) then
			return "<...>"
		end

		visited[v] = true

		local parts = {}
		local nextIndent = indent .. "  "

		table.insert(parts, "{")

		for key, val in pairs(v) do
			local keyStr = type(key) == "string" and key or "[" .. tostring(key) .. "]"
			local valStr = inspectValue(val, currentDepth + 1, nextIndent)
			table.insert(parts, "\n" .. nextIndent .. keyStr .. " = " .. valStr)
		end

		if #parts > 1 then
			table.insert(parts, "\n" .. indent .. "}")
		else
			parts[1] = "{}"
		end

		visited[v] = nil

		return table.concat(parts)
	end

	return inspectValue(value, 0, "")
end

-- =============================================================================
-- ASSERTIONS & ERROR FORMATTING
-- =============================================================================

--- Asserts an invariant in dev mode. Throws if condition is false.
--- Only active when debug.enabled is true.
--- @param condition boolean -- Condition that must be true
--- @param message string -- Error message if condition fails
function debug.assertInvariant(condition: boolean, message: string)
	if debug.enabled and not condition then
		error("[Rivue:Invariant] " .. message, 2)
	end
end

--- Creates a formatted error message with context
--- @param component string -- Component name
--- @param message string -- Error message
--- @param context any? -- Optional context data
--- @return string -- Formatted error message
function debug.formatError(component: string, message: string, context: any?): string
	local parts = { "[Rivue:" .. component .. "] " .. message }

	if context then
		table.insert(parts, "\nContext: " .. debug.inspect(context, 2))
	end

	return table.concat(parts)
end

return debug
