--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local Types = require("./types")

type QueueOptions = Types.QueueOptions
type JobHandle = Types.JobHandle

type Job = {
	fn: () -> (),
	cancelled: boolean,
	holders: number,
}

local RunService = game:GetService("RunService")
local debugModule = require("./debug")

local scheduler = {}

const MAX_JOB_RUNS = 100
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
			RunService.Heartbeat:Once(runOverflow)
		end
		return
	end
	task.defer(function()
		local previous = deferDepth
		deferDepth = depth
		if type(item) == "function" or coroutine.status(item) == "suspended" then
			task.spawn(item)
		end
		deferDepth = previous
	end)
end

local function holdJob(job: Job, queued: { [() -> ()]: Job }): JobHandle
	local released = false
	return {
		cancel = function()
			if released then
				return
			end
			released = true
			job.holders -= 1
			if job.holders > 0 then
				return
			end
			job.cancelled = true
			if queued[job.fn] == job then
				queued[job.fn] = nil
			end
		end,
	}
end

local function enqueue(fn: () -> (), queue: { Job }, queued: { [() -> ()]: Job }): (Job, boolean)
	local existing = queued[fn]
	if existing then
		existing.holders += 1
		return existing, false
	end
	local job: Job = { fn = fn, cancelled = false, holders = 1 }
	queued[fn] = job
	table.insert(queue, job)
	return job, true
end

local freeRunner: thread? = nil

local function runOnRunner(label: string, fn: () -> ()): ()
	local runner = freeRunner
	freeRunner = nil
	debugModule.safeCall(label, fn :: () -> ...unknown)
	freeRunner = runner
end

local function runnerLoop(label: string, fn: () -> ()): ()
	runOnRunner(label, fn)
	while true do
		runOnRunner(coroutine.yield())
	end
end

local function runJob(label: string, fn: () -> ()): ()
	local runner = freeRunner
	if not runner then
		runner = coroutine.create(runnerLoop)
		freeRunner = runner
	end
	task.spawn(runner :: thread, label, fn)
end

type FrameMode = "render" | "heartbeat"
local frameQueues: { [FrameMode]: { Job } } = { render = {}, heartbeat = {} }
local frameQueued: { [FrameMode]: { [() -> ()]: Job } } = { render = {}, heartbeat = {} }
local frameScheduled: { [FrameMode]: boolean } = { render = false, heartbeat = false }

local function flushFrame(mode: FrameMode): ()
	frameScheduled[mode] = false
	local q = frameQueues[mode]
	frameQueues[mode] = {}
	table.clear(frameQueued[mode])

	for _, job in q do
		if not job.cancelled then
			debugModule.safeCall(`{mode} job`, job.fn :: () -> ...unknown)
		end
	end
end

local function queueFrameJob(mode: FrameMode, fn: () -> ()): JobHandle
	local queued = frameQueued[mode]
	local job = enqueue(fn, frameQueues[mode], queued)
	if not frameScheduled[mode] then
		frameScheduled[mode] = true
		local event = if mode == "render" and RunService:IsClient() then RunService.PreRender else RunService.Heartbeat
		event:Once(function()
			flushFrame(mode)
		end)
	end
	return holdJob(job, queued)
end

export type UpdateJob = {
	id: number,
	run: () -> (),
}

local microQueue: { Job } = {}
local microQueued: { [() -> ()]: Job } = {}
local updateQueue: { UpdateJob } = {}
local updateQueued: { [UpdateJob]: true } = {}
local tickQueue: { thread | () -> () } = {}
local flushScheduled = false
local isFlushing = false
local flushThread: thread? = nil
local runCounts: { [unknown]: number } = {}

local function byId(a: UpdateJob, b: UpdateJob): boolean
	return a.id < b.id
end

local function withinRunLimit(key: unknown): boolean
	local count = (runCounts[key] or 0) + 1
	runCounts[key] = count
	if count == MAX_JOB_RUNS + 1 then
		warn(
			"[Rivue] An effect or update kept re-queuing itself, so the scheduler stopped it. Check for state that two effects write back and forth."
		)
	end
	return count <= MAX_JOB_RUNS
end

local function runMicroJobs(): ()
	local q = microQueue
	microQueue = {}
	table.clear(microQueued)
	for _, job in q do
		if not job.cancelled and withinRunLimit(job.fn) then
			runJob("queued job", job.fn)
		end
	end
end

local function runUpdates(): ()
	local q = updateQueue
	updateQueue = {}
	table.sort(q, byId)
	for _, job in q do
		updateQueued[job] = nil
		if withinRunLimit(job) then
			debugModule.safeCall("component update", job.run :: () -> ...unknown)
		end
	end
end

local function flush(): ()
	flushScheduled = false
	isFlushing = true
	flushThread = coroutine.running()
	while #microQueue > 0 or #updateQueue > 0 do
		if #microQueue > 0 then
			runMicroJobs()
		else
			runUpdates()
		end
	end
	isFlushing = false
	flushThread = nil
	table.clear(runCounts)

	local ticks = tickQueue
	tickQueue = {}
	for _, item in ticks do
		if type(item) == "function" or coroutine.status(item) == "suspended" then
			task.spawn(item)
		end
	end
end

local function scheduleFlush(): ()
	if not flushScheduled and not isFlushing then
		flushScheduled = true
		defer(flush)
	end
end

local function queueMicro(fn: () -> ()): Job
	local job, added = enqueue(fn, microQueue, microQueued)
	if added then
		scheduleFlush()
	end
	return job
end

function scheduler.queueJob(fn: () -> (), opts: QueueOptions?): JobHandle
	local mode = if opts and opts.mode then opts.mode else "micro"
	if debugModule.enabled then
		debugModule.log("Scheduler", "Queueing job", { mode = mode })
	end
	if mode == "render" or mode == "heartbeat" then
		return queueFrameJob(mode, fn)
	end
	return holdJob(queueMicro(fn), microQueued)
end

function scheduler.queueEffect(fn: () -> ()): ()
	queueMicro(fn)
end

--- Queues a component re-render. Updates are batched and run parents first, so a child
--- re-rendered by its parent this flush doesn't render twice.
function scheduler.queueUpdate(job: UpdateJob): ()
	if updateQueued[job] then
		return
	end
	updateQueued[job] = true
	table.insert(updateQueue, job)
	scheduleFlush()
end

--- Runs fn after pending effects and updates, or yields the current thread until then when
--- called without fn. Effects and updates those queue in turn also run first.
function scheduler.nextTick(fn: (() -> ())?): ()
	if fn then
		table.insert(tickQueue, fn)
		scheduleFlush()
		return
	end
	local thread = coroutine.running()
	if thread == flushThread then
		defer(thread)
	else
		table.insert(tickQueue, thread)
		scheduleFlush()
	end
	coroutine.yield()
end

return scheduler
