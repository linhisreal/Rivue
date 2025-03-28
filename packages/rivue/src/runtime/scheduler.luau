--!strict
--!optimize 2
--!native

local Types = require("./types")

type QueueOptions = Types.QueueOptions
type JobHandle = Types.JobHandle

type Job = {
	fn: () -> (),
	cancelled: boolean,
}

local RS = game:GetService("RunService")
local debugModule = require("./debug")

local scheduler = {}
local microQueue: { Job } = {}
local microQueueSet: { [() -> ()]: true } = {}
local microScheduled: boolean = false
local isFlushingMicro: boolean = false
local reentrancyDepth = 0
const MAX_REENTRANCY_DEPTH = 100

local NOOP_HANDLE: JobHandle = table.freeze({ cancel = function() end })

-- Roblox drops a task.defer more than 80 deferred levels deep (a loop of nextTick() calls gets
-- there), and it only logs, so pcall can't see it. The flush would never run and updateScheduled
-- would stay true forever, so count our own depth and move to the next Heartbeat well before that.
const MAX_DEFER_DEPTH = 60
local deferDepth = 0
local overflow: { thread | () -> () } = {}

local function runOverflow(): ()
	local items = overflow
	overflow = {}
	for _, item in items do
		task.spawn(item)
	end
end

local function defer(item: thread | () -> ()): ()
	local depth = deferDepth + 1
	if depth > MAX_DEFER_DEPTH then
		table.insert(overflow, item)
		if #overflow == 1 then
			RS.Heartbeat:Once(runOverflow)
		end
		return
	end
	task.defer(function()
		local previous = deferDepth
		deferDepth = depth
		-- A thread cancelled while it waited is dead and can't be resumed
		if type(item) == "function" or coroutine.status(item) == "suspended" then
			task.spawn(item)
		end
		deferDepth = previous
	end)
end

-- One connection per mode, not per job
type FrameMode = "render" | "heartbeat"
local frameQueues: { [FrameMode]: { Job } } = { render = {}, heartbeat = {} }
-- Queuing the same function twice before its frame runs it once, as in micro mode
local frameQueued: { [FrameMode]: { [() -> ()]: Job } } = { render = {}, heartbeat = {} }
local frameConns: { [FrameMode]: RBXScriptConnection? } = {}

local function flushFrame(mode: FrameMode): ()
	local conn = frameConns[mode]
	if conn then
		conn:Disconnect()
		frameConns[mode] = nil
	end

	-- Swap first, jobs queued during flush run next frame
	local q = frameQueues[mode]
	frameQueues[mode] = {}
	frameQueued[mode] = {}

	for _, job in q do
		if not job.cancelled then
			local ok, err = pcall(job.fn :: () -> ...unknown)
			if not ok then
				warn(`[Rivue] Error in {mode} job: {err}`)
			end
		end
	end
end

local function queueFrameJob(mode: FrameMode, job: Job): ()
	table.insert(frameQueues[mode], job)
	if not frameConns[mode] then
		local event = if mode == "render" and RS:IsClient() then RS.RenderStepped else RS.Heartbeat
		frameConns[mode] = event:Connect(function()
			flushFrame(mode)
		end)
	end
end

local function flushMicro(): ()
	if isFlushingMicro then
		debugModule.log("Scheduler", "Already flushing micro queue, deferring")
		return
	end

	reentrancyDepth += 1
	if reentrancyDepth > MAX_REENTRANCY_DEPTH then
		reentrancyDepth = 0
		error("Scheduler: Maximum reentrancy depth exceeded. Possible infinite loop detected.")
	end

	isFlushingMicro = true
	local q = microQueue
	microQueue = {}
	microQueueSet = {}
	microScheduled = false

	if debugModule.enabled then
		debugModule.log("Scheduler", "Flushing micro queue", { jobCount = #q, reentrancyDepth = reentrancyDepth })
	end

	for _, job in q do
		if not job.cancelled then
			local ok, err = pcall(job.fn :: () -> ...unknown)
			if not ok then
				-- Watch callbacks and queued jobs land here, always report
				warn(`[Rivue] Error in queued job: {err}`)
			end
		end
	end

	isFlushingMicro = false
	reentrancyDepth -= 1

	if debugModule.enabled then
		debugModule.log("Scheduler", "Micro queue flush complete", { executed = #q, reentrancyDepth = reentrancyDepth })
	end

	if #microQueue > 0 and not microScheduled then
		microScheduled = true
		debugModule.log("Scheduler", "New jobs added during flush, scheduling another flush")
		defer(flushMicro)
	end
end

function scheduler.queueJob(fn: () -> (), opts: QueueOptions?): JobHandle
	local mode = if opts and opts.mode then opts.mode else "micro"
	if mode == "micro" and microQueueSet[fn] then
		return NOOP_HANDLE
	end
	local job: Job = { fn = fn, cancelled = false }

	if debugModule.enabled then
		debugModule.log("Scheduler", "Queueing job", { mode = mode })
	end

	if mode == "render" or mode == "heartbeat" then
		local queued = frameQueued[mode]
		local existing = queued[fn]
		if existing and not existing.cancelled then
			job = existing
		else
			queued[fn] = job
			queueFrameJob(mode, job)
		end
		return {
			cancel = function()
				job.cancelled = true
				if frameQueued[mode][fn] == job then
					frameQueued[mode][fn] = nil
				end
			end,
		}
	else
		microQueueSet[fn] = true
		table.insert(microQueue, job)

		if not microScheduled then
			microScheduled = true
			defer(flushMicro)
		end

		return {
			cancel = function()
				job.cancelled = true
				microQueueSet[fn] = nil
			end,
		}
	end
end

--- Runs fn after pending updates, or yields the current thread until then when called without fn
--- Component re-renders and "pre" watchers are deferred, so a defer queued now runs after them.
function scheduler.nextTick(fn: (() -> ())?): ()
	if fn then
		defer(fn)
		return
	end
	defer(coroutine.running())
	coroutine.yield()
end

function scheduler.queueEffect(fn: () -> ()): ()
	if microQueueSet[fn] then
		return
	end
	microQueueSet[fn] = true
	table.insert(microQueue, { fn = fn, cancelled = false })
	if not microScheduled then
		microScheduled = true
		defer(flushMicro)
	end
end

export type UpdateJob = {
	-- Creation order, parents have lower ids than their children
	id: number,
	run: () -> (),
}

local updateQueue: { UpdateJob } = {}
local updateQueued: { [UpdateJob]: true } = {}
local updateScheduled = false

local function byId(a: UpdateJob, b: UpdateJob): boolean
	return a.id < b.id
end

local function flushUpdates(): ()
	updateScheduled = false
	local passes = 0
	while #updateQueue > 0 do
		passes += 1
		if passes > MAX_REENTRANCY_DEPTH then
			warn("[Rivue] Component updates kept re-queuing, possible infinite update loop")
			table.clear(updateQueue)
			table.clear(updateQueued)
			return
		end

		local q = updateQueue
		updateQueue = {}
		table.sort(q, byId)
		for _, job in q do
			-- Cleared first so a parent's re-render can queue this job again if needed
			updateQueued[job] = nil
			local ok, err = pcall(job.run :: () -> ...unknown)
			if not ok then
				warn(`[Rivue] Error in component update: {err}`)
			end
		end
	end
end

--- Queues a component re-render. Updates are batched and run parents first, so a child
--- re-rendered by its parent this flush doesn't render twice.
function scheduler.queueUpdate(job: UpdateJob): ()
	if updateQueued[job] then
		return
	end
	updateQueued[job] = true
	table.insert(updateQueue, job)
	if not updateScheduled then
		updateScheduled = true
		defer(flushUpdates)
	end
end

return scheduler
