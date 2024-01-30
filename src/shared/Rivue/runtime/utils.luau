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

type RafHandle = { stop: () -> () }
type DebouncedHandle = { cancel: () -> () }
type Profiler = {
	active: boolean,
	records: { [string]: number },
	start: (self: Profiler, name: string) -> (),
	stop: (self: Profiler, name: string) -> number?,
}

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local debugModule = require(script.Parent:WaitForChild("debug"))

local utils: any = {}

--- Creates a debounced function that delays execution until after ms milliseconds
--- @param fn (...any) -> () -- Function to debounce
--- @param ms number -- Delay in milliseconds (values < 1 auto-converted from seconds)
--- @return (...any) -> DebouncedHandle -- Debounced function
function utils.debounce(fn: (...any) -> (), ms: number): (...any) -> DebouncedHandle
	-- Auto-convert if user passed seconds (< 1) instead of milliseconds
	if ms > 0 and ms < 1 then
		ms = ms * 1000
	end
	debugModule.log("Utils", "Creating debounced function", { delayMs = ms })
	local timer: thread? = nil
	return function(...: any): DebouncedHandle
		-- table.pack keeps trailing/embedded nils that `{ ... }` + unpack() would drop
		local args = table.pack(...)
		if timer then
			pcall(task.cancel, timer :: thread)
		end
		timer = task.delay(ms / 1000, function()
			pcall(fn :: any, table.unpack(args, 1, args.n))
		end)
		return {
			cancel = function()
				if timer then
					pcall(task.cancel, timer :: thread)
				end
			end,
		}
	end
end

--- Creates a throttled function that executes at most once per ms milliseconds
--- @param fn (...any) -> () -- Function to throttle
--- @param ms number -- Minimum interval in milliseconds (values < 1 auto-converted from seconds)
--- @return (...any) -> () -- Throttled function
function utils.throttle(fn: (...any) -> (), ms: number): (...any) -> ()
	-- Auto-convert if user passed seconds (< 1) instead of milliseconds
	if ms > 0 and ms < 1 then
		ms = ms * 1000
	end
	debugModule.log("Utils", "Creating throttled function", { intervalMs = ms })
	local last = -math.huge
	local scheduled = false
	local pendingArgs: any = nil
	return function(...: any): ()
		-- os.clock() is monotonic and high resolution; tick() is deprecated
		local now = os.clock() * 1000
		local args = table.pack(...)
		if now - last >= ms then
			last = now
			pcall(fn :: any, table.unpack(args, 1, args.n))
			return
		end
		-- Trailing call uses the most recent arguments, not the first throttled ones
		pendingArgs = args
		if not scheduled then
			scheduled = true
			task.delay((ms - (now - last)) / 1000, function()
				scheduled = false
				last = os.clock() * 1000
				pcall(fn :: any, table.unpack(pendingArgs, 1, pendingArgs.n))
			end)
		end
	end
end

--- Defers execution to next micro-task using task.defer
--- @param fn () -> () -- Function to defer
--- @return
function utils.nextTick(fn: () -> ()): ()
	task.defer(fn)
end

--- Defers execution to next Heartbeat frame
--- @param fn () -> () -- Function to defer
--- @return
function utils.nextFrame(fn: () -> ()): ()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		conn:Disconnect()
		pcall(fn)
	end)
end

--- Runs a function every RenderStepped frame
--- @param fn (dt: number) -> () -- Callback receiving delta time
--- @return RafHandle -- Handle with stop() method
function utils.useRaf(fn: (dt: number) -> ()): RafHandle
	debugModule.log("Utils", "Starting RenderStepped RAF")
	local conn: RBXScriptConnection? = RunService.RenderStepped:Connect(function(dt: number)
		pcall(fn :: any, dt)
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
	debugModule.log("Utils", "Filtering text for client", { userId = player.UserId, textLength = #str })
	local ok, token = pcall(function()
		return TextService:FilterStringAsync(str, player.UserId)
	end)
	if not ok then
		return str
	end
	local ok2, filtered = pcall(function()
		return (token :: any):GetNonChatStringForBroadcastAsync()
	end)
	if not ok2 then
		return str
	end
	return filtered :: string
end

local profiler: Profiler = {
	active = false,
	records = {},
	start = function(self: Profiler, name: string): ()
		if not self.active then
			self.active = true
		end
		self.records[name] = os.clock()
	end,
	stop = function(self: Profiler, name: string): number?
		if self.records[name] then
			local elapsed = os.clock() - self.records[name]
			self.records[name] = elapsed
			return elapsed
		end
		return nil
	end,
}
utils.profiler = profiler

--- Iterator for reactive arrays that provides ipairs-like syntax with reactivity tracking
--- Works around Luau's ipairs() limitation with reactive proxies
--- @param array { T } -- Array to iterate (reactive or non-reactive)
--- @return () -> (number?, T?) -- Iterator function
function utils.iterArray<T>(array: { T }): () -> (number?, T?)
	local i = 0
	return function(): (number?, T?)
		i = i + 1
		local value = array[i]
		if value ~= nil then
			return i, value
		end
		return nil, nil
	end
end

--- Performs shallow equality comparison between two tables
--- Only compares top-level keys and values (no deep comparison)
--- @param a any -- First table to compare
--- @param b any -- Second table to compare
--- @return boolean -- True if shallowly equal, false otherwise
function utils.shallowEqual(a: any, b: any): boolean
	if a == b then
		return true
	end

	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	local keysA = 0
	local keysB = 0

	for key, value in pairs(a) do
		keysA += 1
		if (b :: any)[key] ~= value then
			return false
		end
	end

	for _ in pairs(b) do
		keysB += 1
	end

	return keysA == keysB
end

return utils
