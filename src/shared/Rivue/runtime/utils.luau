--!strict
--!optimize 2
--!native

--[[
	Utilities
    =========
	
	Common utility functions for async operations, profiling, and text filtering.
	
	@module utils

	@author Rivue

	@version 1.0.0
	
	Type Definitions:
    -----------------

		type RafHandle = { stop: () -> () }
		type DebouncedHandle = { cancel: () -> () }
		type Profiler = {
			active: boolean,
			records: { [string]: number },
			start: (name: string) -> (),
			stop: (name: string) -> number?
		}
	
	Public API:
    -----------

		debounce(fn: (...any) -> (), ms: number) -> (...any) -> DebouncedHandle
			'Creates a debounced function that delays execution'
			
		throttle(fn: (...any) -> (), ms: number) -> (...any) -> ()
			'Creates a throttled function that executes at most once per interval'
			
		nextTick(fn: () -> ())
			'Defers execution to next micro-task'
			
		nextFrame(fn: () -> ())
			'Defers execution to next Heartbeat frame'
			
		useRaf(fn: (dt: number) -> ()) -> RafHandle
			'Runs a function every RenderStepped frame'
			
		filterForClient(player: Player, str: string) -> string
			'Filters text using TextService for chat/display'
			
		profiler: Profiler
			'Simple performance profiler'
			
		iterArray<T>(array: { T }) -> () -> (number?, T?)
			'Iterator for reactive arrays with ipairs-like syntax'
]]

export type RafHandle = { stop: () -> () }
export type DebouncedHandle = { cancel: () -> () }
export type Profiler = {
	active: boolean,
	records: { [string]: number },
	start: (self: Profiler, name: string) -> (),
	stop: (self: Profiler, name: string) -> number?,
}

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local debugModule = require(script.Parent:WaitForChild("debug"))

local utils = {}

--- Normalizes a delay to milliseconds (values in (0, 1) are treated as seconds for backwards compatibility)
--- @param ms number -- Delay in milliseconds, or seconds when below 1
--- @return number -- Delay in milliseconds
local function toMilliseconds(ms: number): number
	return if ms > 0 and ms < 1 then ms * 1000 else ms
end

--- Creates a debounced function that delays execution until after ms milliseconds
--- Generic over the argument pack, so the returned function keeps fn's parameter types.
--- @param fn (A...) -> () -- Function to debounce
--- @param ms number -- Delay in milliseconds (values < 1 auto-converted from seconds)
--- @return (A...) -> DebouncedHandle -- Debounced function
function utils.debounce<A...>(fn: (A...) -> (), ms: number): (A...) -> DebouncedHandle
	local delayMs = toMilliseconds(ms)
	local timer: thread? = nil

	local function cancel()
		if timer then
			pcall(task.cancel, timer)
			timer = nil
		end
	end
	-- One shared handle instead of a new table + closure per call
	local handle: DebouncedHandle = table.freeze({ cancel = cancel })

	return function(...: A...): DebouncedHandle
		-- table.pack keeps trailing/embedded nils that `{ ... }` + unpack() would drop
		local args = table.pack(...)
		cancel()
		timer = task.delay(delayMs / 1000, function()
			timer = nil
			-- A packed table erases the pack type, so re-widen fn at this one boundary
			pcall(fn :: (...any) -> (), table.unpack(args, 1, args.n))
		end)
		return handle
	end
end

--- Creates a throttled function that executes at most once per interval (leading + trailing call)
--- @param fn (A...) -> () -- Function to throttle
--- @param ms number -- Interval in milliseconds (values < 1 auto-converted from seconds)
--- @return (A...) -> () -- Throttled function
function utils.throttle<A...>(fn: (A...) -> (), ms: number): (A...) -> ()
	local intervalMs = toMilliseconds(ms)
	local last = -math.huge
	local scheduled = false
	local pendingArgs: { n: number, [number]: any }? = nil
	return function(...: A...)
		-- os.clock() is monotonic and high resolution; tick() is deprecated
		local now = os.clock() * 1000
		if now - last >= intervalMs then
			last = now
			pcall(fn, ...)
			return
		end
		-- Trailing call uses the most recent arguments, not the first throttled ones
		pendingArgs = table.pack(...)
		if not scheduled then
			scheduled = true
			task.delay((intervalMs - (now - last)) / 1000, function()
				scheduled = false
				last = os.clock() * 1000
				local args = pendingArgs
				pendingArgs = nil
				if args then
					pcall(fn :: (...any) -> (), table.unpack(args, 1, args.n))
				end
			end)
		end
	end
end

--- Defers execution to next micro-task
--- @param fn () -> () -- Function to defer
function utils.nextTick(fn: () -> ()): ()
	task.defer(fn)
end

--- Defers execution to next Heartbeat frame
--- @param fn () -> () -- Function to defer
function utils.nextFrame(fn: () -> ()): ()
	RunService.Heartbeat:Once(function()
		pcall(fn)
	end)
end

--- Runs a function every RenderStepped frame
--- @param fn (dt: number) -> () -- Callback receiving delta time
--- @return RafHandle -- Handle with stop() method
function utils.useRaf(fn: (dt: number) -> ()): RafHandle
	if debugModule.enabled then
		debugModule.log("Utils", "Starting RenderStepped RAF")
	end
	local conn: RBXScriptConnection? = RunService.RenderStepped:Connect(function(dt: number)
		pcall(fn, dt)
	end)
	return {
		stop = function()
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end,
	}
end

--- Filters text using TextService for safe display to players
--- @param player Player -- Player to filter for
--- @param str string -- Text to filter
--- @return string -- Filtered text (original if filtering fails)
function utils.filterForClient(player: Player, str: string): string
	local ok, result = pcall(TextService.FilterStringAsync, TextService, str, player.UserId)
	if not ok then
		return str
	end
	local filterResult = result :: TextFilterResult
	local ok2, filtered = pcall(filterResult.GetNonChatStringForBroadcastAsync, filterResult)
	return if ok2 then filtered else str
end

local profiler: Profiler = {
	active = false,
	records = {},
	start = function(self: Profiler, name: string): ()
		self.active = true
		self.records[name] = os.clock()
	end,
	stop = function(self: Profiler, name: string): number?
		local startedAt = self.records[name]
		if startedAt then
			local elapsed = os.clock() - startedAt
			self.records[name] = elapsed
			return elapsed
		end
		return nil
	end,
}
utils.profiler = profiler

--- Iterator for reactive arrays that provides ipairs-like syntax with reactivity tracking
--- Works around Luau's ipairs() limitation with reactive proxies
--- (`for i = 1, #array do` or `for k, v in proxy do` also work now that proxies implement __len/__iter.)
--- @param array { T } -- Array to iterate (reactive or non-reactive)
--- @return () -> (number?, T?) -- Iterator function
function utils.iterArray<T>(array: { T }): () -> (number?, T?)
	local i = 0
	return function(): (number?, T?)
		i += 1
		local value = array[i]
		if value ~= nil then
			return i, value
		end
		return nil, nil
	end
end

--- Performs shallow equality comparison between two tables
--- Only compares top-level keys and values (no deep comparison)
--- @param a unknown -- First value to compare
--- @param b unknown -- Second value to compare
--- @return boolean -- True if shallowly equal, false otherwise
function utils.shallowEqual(a: unknown, b: unknown): boolean
	if a == b then
		return true
	end

	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	local ta = a :: { [unknown]: unknown }
	local tb = b :: { [unknown]: unknown }
	local keysA = 0
	for key, value in ta do
		keysA += 1
		if tb[key] ~= value then
			return false
		end
	end

	local keysB = 0
	for _ in tb do
		keysB += 1
	end

	return keysA == keysB
end

return utils
