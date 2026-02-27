--!strict
--!optimize 2

-- Helpers: debounce, throttle, frame callbacks, text filtering, shallow equality and a simple
-- profiler.

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
local debugModule = require("./debug")

local utils = {}

--- Values below 1 are treated as seconds
local function toMilliseconds(ms: number): number
	return if ms > 0 and ms < 1 then ms * 1000 else ms
end

--- Creates a debounced function that delays execution until after ms milliseconds
--- `ms`: delay in milliseconds (values < 1 auto-converted from seconds)
function utils.debounce<A...>(fn: (A...) -> (), ms: number): (A...) -> DebouncedHandle
	local delayMs = toMilliseconds(ms)
	local timer: thread? = nil

	local function cancel()
		if timer then
			pcall(task.cancel, timer)
			timer = nil
		end
	end
	local handle: DebouncedHandle = table.freeze({ cancel = cancel })

	return function(...: A...): DebouncedHandle
		-- table.pack keeps nil arguments
		local args = table.pack(...)
		cancel()
		timer = task.delay(delayMs / 1000, function()
			timer = nil
			pcall(fn :: (...any) -> (), table.unpack(args, 1, args.n))
		end)
		return handle
	end
end

--- Creates a throttled function that executes at most once per interval
--- `ms`: interval in milliseconds (values < 1 auto-converted from seconds)
function utils.throttle<A...>(fn: (A...) -> (), ms: number): (A...) -> ()
	local intervalMs = toMilliseconds(ms)
	local last = -math.huge
	local scheduled = false
	local pendingArgs: { n: number, [number]: any }? = nil
	return function(...: A...)
		local now = os.clock() * 1000
		if now - last >= intervalMs then
			last = now
			pcall(fn, ...)
			return
		end
		-- Trailing call uses the latest arguments
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
function utils.nextTick(fn: () -> ()): ()
	task.defer(fn)
end

--- Defers execution to next Heartbeat frame
function utils.nextFrame(fn: () -> ()): ()
	RunService.Heartbeat:Once(function()
		pcall(fn)
	end)
end

--- Runs a function every RenderStepped frame
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
--- Returns filtered text (original if filtering fails)
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
