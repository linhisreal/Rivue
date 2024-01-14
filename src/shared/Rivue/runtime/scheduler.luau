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

type QueueOptions = {
	mode: ("micro" | "render" | "heartbeat")?,
}

type JobHandle = {
	cancel: () -> (),
}

type Job = {
	fn: () -> (),
	cancelled: boolean,
}

local RS = game:GetService("RunService")
local debugModule = require(script.Parent:WaitForChild("debug"))

local scheduler: { queueJob: (fn: () -> (), opts: QueueOptions?) -> JobHandle } = {} :: any
local microQueue: { Job } = {}
local microQueueSet: { [any]: boolean } = {}
local microScheduled: boolean = false
local isFlushingMicro: boolean = false
local reentrancyDepth: number = 0
local MAX_REENTRANCY_DEPTH: number = 100 -- Prevent infinite loops

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

	debugModule.log("Scheduler", "Flushing micro queue", { jobCount = #q, reentrancyDepth = reentrancyDepth })

	for _, job in ipairs(q) do
		if not job.cancelled then
			local ok, err = pcall(job.fn :: any)
			if not ok then
				debugModule.log("Scheduler", "Micro queue job error", { error = err })
			end
		end
	end

	isFlushingMicro = false
	reentrancyDepth -= 1

	debugModule.log("Scheduler", "Micro queue flush complete", { executed = #q, reentrancyDepth = reentrancyDepth })

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
	local options: QueueOptions = opts or { mode = "micro" }
	local mode = options.mode or "micro"
	local job: Job = { fn = fn, cancelled = false }

	debugModule.log("Scheduler", "Queueing job", { mode = mode })

	if mode == "render" then
		local event = if RS:IsClient() then RS.RenderStepped else RS.Heartbeat
		local conn: RBXScriptConnection? = nil
		conn = event:Connect(function()
			if conn then
				conn:Disconnect()
			end
			if not job.cancelled then
				debugModule.log("Scheduler", "Executing render job")
				local ok, err = pcall(fn :: any)
				if not ok then
					debugModule.log("Scheduler", "Render queue job error", { error = err })
				end
			end
		end)
		return {
			cancel = function()
				job.cancelled = true
				debugModule.log("Scheduler", "Cancelled render job")
				if conn then
					conn:Disconnect()
				end
			end,
		}
	elseif mode == "heartbeat" then
		local conn: RBXScriptConnection? = nil
		conn = RS.Heartbeat:Connect(function()
			if conn then
				conn:Disconnect()
			end
			if not job.cancelled then
				debugModule.log("Scheduler", "Executing heartbeat job")
				local ok, err = pcall(fn :: any)
				if not ok then
					debugModule.log("Scheduler", "Heartbeat queue job error", { error = err })
				end
			end
		end)
		return {
			cancel = function()
				job.cancelled = true
				debugModule.log("Scheduler", "Cancelled heartbeat job")
				if conn then
					conn:Disconnect()
				end
			end,
		}
	else
		-- O(1) deduplication via set lookup
		if microQueueSet[fn] then
			debugModule.log("Scheduler", "Deduplicated micro job (already queued)")
			return { cancel = function() end }
		end

		microQueueSet[fn] = true
		table.insert(microQueue, job)
		debugModule.log("Scheduler", "Added to micro queue", { queueSize = #microQueue })

		if not microScheduled then
			microScheduled = true
			debugModule.log("Scheduler", "Scheduling micro flush")
			task.defer(flushMicro)
		end

		return {
			cancel = function()
				job.cancelled = true
				microQueueSet[fn] = nil
				debugModule.log("Scheduler", "Cancelled micro job")
			end,
		}
	end
end

return scheduler
