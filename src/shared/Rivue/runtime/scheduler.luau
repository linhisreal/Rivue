--!strict
--!optimize 2
--!native

--[[
	Scheduler
    =========
	
	Job scheduling system for deferred and batched execution.
	
	@module scheduler

	@author Rivue

	@version 1.0.0

	Type Definitions:
    -----------------

		type QueueOptions = {
			mode: "micro" | "render" | "heartbeat"?
		}
		
		type JobHandle = {
			cancel: () -> ()
		}
		
		type Job = {
			fn: () -> (),
			cancelled: boolean
		}
	
	Public API:
    -----------
    
		queueJob(fn: () -> (), options?: QueueOptions) -> JobHandle
			--- Queues a job for execution with different scheduling modes:
			---   "micro" (default): Deferred via task.defer with deduplication
			---   "render": Next RenderStepped frame
			---   "heartbeat": Next Heartbeat frame
]]

local Types = require(script.Parent:WaitForChild("types"))

type QueueOptions = Types.QueueOptions
type JobHandle = Types.JobHandle

type Job = {
	fn: () -> (),
	cancelled: boolean,
}

local RS = game:GetService("RunService")
local debugModule = require(script.Parent:WaitForChild("debug"))

local scheduler = {}
local microQueue: { Job } = {}
local microQueueSet: { [() -> ()]: true } = {}
local microScheduled: boolean = false
local isFlushingMicro: boolean = false
local reentrancyDepth = 0
const MAX_REENTRANCY_DEPTH = 100 -- Prevent infinite loops

-- Returned for deduplicated jobs
local NOOP_HANDLE: JobHandle = table.freeze({ cancel = function() end })

-- One connection per mode, not per job
type FrameMode = "render" | "heartbeat"
local frameQueues: { [FrameMode]: { Job } } = { render = {}, heartbeat = {} }
local frameConns: { [FrameMode]: RBXScriptConnection? } = {}

--- Runs queued jobs for a frame mode
--- @param mode FrameMode -- Which frame queue to flush
local function flushFrame(mode: FrameMode): ()
	local conn = frameConns[mode]
	if conn then
		conn:Disconnect()
		frameConns[mode] = nil
	end

	-- Swap first, jobs queued during flush run next frame
	local q = frameQueues[mode]
	frameQueues[mode] = {}

	for _, job in q do
		if not job.cancelled then
			local ok, err = pcall(job.fn :: () -> ...unknown)
			if not ok then
				debugModule.log("Scheduler", "Frame queue job error", { mode = mode, error = err })
			end
		end
	end
end

--- Queues a job onto the next RenderStepped/Heartbeat frame
--- @param mode FrameMode -- Frame mode
--- @param job Job -- Job to run
local function queueFrameJob(mode: FrameMode, job: Job): ()
	table.insert(frameQueues[mode], job)
	if not frameConns[mode] then
		local event = if mode == "render" and RS:IsClient() then RS.RenderStepped else RS.Heartbeat
		frameConns[mode] = event:Connect(function()
			flushFrame(mode)
		end)
	end
end

--- Flushes all queued micro jobs
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
				debugModule.log("Scheduler", "Micro queue job error", { error = err })
			end
		end
	end

	isFlushingMicro = false
	reentrancyDepth -= 1

	if debugModule.enabled then
		debugModule.log("Scheduler", "Micro queue flush complete", { executed = #q, reentrancyDepth = reentrancyDepth })
	end

	-- If new jobs were added during flush, schedule another flush
	if #microQueue > 0 and not microScheduled then
		microScheduled = true
		debugModule.log("Scheduler", "New jobs added during flush, scheduling another flush")
		task.defer(flushMicro)
	end
end

--- Queues a job for execution
--- @param fn () -> () -- Job function to execute
--- @param opts QueueOptions? -- Queue options (mode: "micro" | "render" | "heartbeat")
--- @return JobHandle -- Handle with cancel function
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
		queueFrameJob(mode, job)
		return {
			cancel = function()
				job.cancelled = true
			end,
		}
	else
		microQueueSet[fn] = true
		table.insert(microQueue, job)

		if not microScheduled then
			microScheduled = true
			task.defer(flushMicro)
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
--- @param fn (() -> ())? -- Callback (optional)
function scheduler.nextTick(fn: (() -> ())?): ()
	if fn then
		task.defer(fn)
		return
	end
	task.defer(coroutine.running())
	coroutine.yield()
end

--- Queues fn on the micro queue without allocating a handle (used by effects)
--- @param fn () -> () -- Job function (deduplicated)
function scheduler.queueEffect(fn: () -> ()): ()
	if microQueueSet[fn] then
		return
	end
	microQueueSet[fn] = true
	table.insert(microQueue, { fn = fn, cancelled = false })
	if not microScheduled then
		microScheduled = true
		task.defer(flushMicro)
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

--- Runs queued component updates, parents first
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
				debugModule.log("Scheduler", "Component update error", { error = err })
			end
		end
	end
end

--- Queues a component re-render. Updates are batched and run parents first, so a child
--- re-rendered by its parent this flush doesn't render twice.
--- @param job UpdateJob -- Update job (deduplicated)
function scheduler.queueUpdate(job: UpdateJob): ()
	if updateQueued[job] then
		return
	end
	updateQueued[job] = true
	table.insert(updateQueue, job)
	if not updateScheduled then
		updateScheduled = true
		task.defer(flushUpdates)
	end
end

return scheduler
