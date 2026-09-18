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
}

local RunService = game:GetService("RunService")
local debugModule = require("./debug")

local scheduler = {}

const MAX_FLUSH_PASSES = 100
-- Roblox silently drops a task.defer nested over 80 deep, so past 60 we wait for Heartbeat
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

local function cancelHandle(job: Job, queued: { [() -> ()]: Job }): JobHandle
	return {
		cancel = function()
			job.cancelled = true
			if queued[job.fn] == job then
				queued[job.fn] = nil
			end
		end,
	}
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
	local existing = queued[fn]
	if existing then
		return cancelHandle(existing, queued)
	end
	local job: Job = { fn = fn, cancelled = false }
	queued[fn] = job
	table.insert(frameQueues[mode], job)
	if not frameScheduled[mode] then
		frameScheduled[mode] = true
		local event = if mode == "render" and RunService:IsClient() then RunService.PreRender else RunService.Heartbeat
		event:Once(function()
			flushFrame(mode)
		end)
	end
	return cancelHandle(job, queued)
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

local function byId(a: UpdateJob, b: UpdateJob): boolean
	return a.id < b.id
end

local function runMicroJobs(): ()
	local q = microQueue
	microQueue = {}
	table.clear(microQueued)
	for _, job in q do
		if not job.cancelled then
			debugModule.safeCall("queued job", job.fn :: () -> ...unknown)
		end
	end
end

local function runUpdates(): ()
	local q = updateQueue
	updateQueue = {}
	table.sort(q, byId)
	for _, job in q do
		updateQueued[job] = nil
		local ok, err = pcall(job.run :: () -> ...unknown)
		if not ok then
			warn(`[Rivue] Error in component update: {err}`)
		end
	end
end

local function dropQueues(): ()
	table.clear(microQueue)
	table.clear(microQueued)
	table.clear(updateQueue)
	table.clear(updateQueued)
end

local function flush(): ()
	flushScheduled = false
	isFlushing = true
	flushThread = coroutine.running()
	local passes = 0
	while #microQueue > 0 or #updateQueue > 0 do
		passes += 1
		if passes > MAX_FLUSH_PASSES then
			warn(
				"[Rivue] Effects or updates kept re-queuing each other, so the scheduler stopped them. Check for state that two effects write back and forth."
			)
			dropQueues()
			break
		end
		if #microQueue > 0 then
			runMicroJobs()
		else
			runUpdates()
		end
	end
	isFlushing = false
	flushThread = nil

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
	local existing = microQueued[fn]
	if existing then
		return existing
	end
	local job: Job = { fn = fn, cancelled = false }
	microQueued[fn] = job
	table.insert(microQueue, job)
	scheduleFlush()
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
	return cancelHandle(queueMicro(fn), microQueued)
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
		-- a job yielding here would suspend the flush that has to resume it
		defer(thread)
	else
		table.insert(tickQueue, thread)
		scheduleFlush()
	end
	coroutine.yield()
end

return scheduler
