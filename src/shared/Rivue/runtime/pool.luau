--!strict
--!optimize 2
--!native

--[[
	Pool.luau
    =========
	
	Advanced object pooling system for Roblox Instances to reduce GC pressure.
	
	@module pool

	@author Rivue

	@version 2.0.0
	
	Type Definitions:
    -----------------

		type PoolConfig = {
			maxPoolSize: number?,
			maxTotalSize: number?,
			enableMetrics: boolean?,
			enableDebug: boolean?,
			defaultTTL: number?,
			enableAutoWarmup: boolean?
		}

		type PoolMetrics = {
			acquires: number,
			releases: number,
			creates: number,
			hits: number,
			misses: number,
			destroyed: number,
			evictions: number
		}

		type PoolStatistics = {
			totalInstances: number,
			poolsByClass: { [string]: number },
			metrics: PoolMetrics,
			hitRate: number
		}

		type ResetHandler = (inst: Instance) -> ()

		type PoolEventHooks = {
			onAcquire: ((inst: Instance, fromPool: boolean) -> ())?,
			onRelease: ((inst: Instance, pooled: boolean) -> ())?,
			onClear: ((totalCleared: number) -> ())?,
			onEvict: ((inst: Instance, reason: string) -> ())?
		}

		type Pool = {
			store: { [string]: { Instance } },
			config: PoolConfig,
			metrics: PoolMetrics,
			customResetHandlers: { [string]: ResetHandler },
			eventHooks: PoolEventHooks,
			instanceMetadata: { [Instance]: { acquiredAt: number, releasedAt: number? } },
			
			acquire: (className: string) -> Instance,
			acquireMultiple: (className: string, count: number) -> { Instance },
			release: (inst: Instance, touched: { [string]: boolean }?) -> (),
			releaseMultiple: (instances: { Instance }) -> (),
			clear: (className: string?) -> (),
			
			configure: (config: PoolConfig) -> (),
			warmup: (className: string, count: number) -> (),
			getStatistics: () -> PoolStatistics,
			validateHealth: () -> boolean,
			createSnapshot: () -> { [string]: { Instance } },
			restoreSnapshot: (snapshot: { [string]: { Instance } }) -> (),
			
			setResetHandler: (className: string, handler: ResetHandler) -> (),
			setEventHook: (hookName: string, handler: (...any) -> ()) -> (),
			
			_debugMode: boolean,
			_typeCheckCache: { [string]: { isGuiObject: boolean, isText: boolean, isImage: boolean } }
		}
	
	Public API:
    -----------

		acquire(className: string) -> Instance
			Gets an Instance from the pool or creates a new one
			
		acquireMultiple(className: string, count: number) -> { Instance }
			Bulk acquire multiple instances
			
		release(inst: Instance)
			Returns an Instance to the pool after resetting it
			
		releaseMultiple(instances: { Instance })
			Bulk release multiple instances
			
		clear(className: string?)
			Destroys pooled Instances (all or specific class)
			
		configure(config: PoolConfig)
			Update pool configuration
			
		warmup(className: string, count: number)
			Pre-populate pool with instances
			
		getStatistics() -> PoolStatistics
			Get detailed pool statistics and metrics
			
		validateHealth() -> boolean
			Check pool health and remove invalid instances
			
		createSnapshot() -> { [string]: { Instance } }
			Create a snapshot of current pool state
			
		restoreSnapshot(snapshot)
			Restore pool from a snapshot
			
		setResetHandler(className: string, handler: ResetHandler)
			Set custom reset logic for a class
			
		setEventHook(hookName: string, handler: function)
			Register event callbacks (onAcquire, onRelease, onClear, onEvict)
		
	Usage:
    ------
		
		-- Basic usage
		local frame = Pool.acquire("Frame")
		Pool.release(frame)
		
		-- Configuration
		Pool.configure({
			maxPoolSize = 50,
			maxTotalSize = 500,
			enableMetrics = true,
			defaultTTL = 300
		})
		
		-- Warmup
		Pool.warmup("Frame", 10)
		
		-- Bulk operations
		local frames = Pool.acquireMultiple("Frame", 5)
		Pool.releaseMultiple(frames)
		
		-- Custom reset handler
		Pool.setResetHandler("Frame", function(inst)
			inst.BackgroundColor3 = Color3.new(1, 1, 1)
		end)
		
		-- Event hooks
		Pool.setEventHook("onAcquire", function(inst, fromPool)
			print("Acquired:", inst.ClassName, "from pool:", fromPool)
		end)
		
		-- Statistics
		local stats = Pool.getStatistics()
		print("Hit rate:", stats.hitRate)
]]

local Types = require(script.Parent:WaitForChild("types"))

export type PoolConfig = Types.PoolConfig

export type PoolMetrics = {
	acquires: number,
	releases: number,
	creates: number,
	hits: number,
	misses: number,
	destroyed: number,
	evictions: number,
}

export type PoolStatistics = {
	totalInstances: number,
	poolsByClass: { [string]: number },
	metrics: PoolMetrics,
	hitRate: number,
}

export type ResetHandler = (inst: Instance) -> ()

export type PoolEventHooks = {
	onAcquire: ((inst: Instance, fromPool: boolean) -> ())?,
	onRelease: ((inst: Instance, pooled: boolean) -> ())?,
	onClear: ((totalCleared: number) -> ())?,
	onEvict: ((inst: Instance, reason: string) -> ())?,
}

type PoolStore = { [string]: { Instance } }
type PoolType = {
	store: PoolStore,
	config: PoolConfig,
	metrics: PoolMetrics,
	customResetHandlers: { [string]: ResetHandler },
	eventHooks: PoolEventHooks,
	instanceMetadata: { [Instance]: { acquiredAt: number, releasedAt: number? } },

	acquire: (className: string) -> Instance,
	acquireMultiple: (className: string, count: number) -> { Instance },
	release: (inst: Instance, touched: { [string]: boolean }?) -> (),
	restoreDefaults: (inst: Instance, props: { [string]: boolean }) -> (),
	releaseMultiple: (instances: { Instance }) -> (),
	clear: (className: string?) -> (),

	configure: (config: PoolConfig) -> (),
	warmup: (className: string, count: number) -> (),
	getStatistics: () -> PoolStatistics,
	validateHealth: () -> boolean,
	createSnapshot: () -> { [string]: { Instance } },
	restoreSnapshot: (snapshot: { [string]: { Instance } }) -> (),

	setResetHandler: (className: string, handler: ResetHandler) -> (),
	setEventHook: (hookName: string, handler: (...any) -> ()) -> (),

	_debugMode: boolean,
	_typeCheckCache: { [string]: { isGuiObject: boolean, isText: boolean, isImage: boolean } },
}

local debugModule = require(script.Parent:WaitForChild("debug"))

-- Default configuration
local DEFAULT_CONFIG: PoolConfig = {
	maxPoolSize = 50, -- Max instances per class
	maxTotalSize = 500, -- Max total instances across all classes
	enableMetrics = true, -- Track usage statistics
	enableDebug = false, -- Enhanced debug logging
	defaultTTL = nil, -- Time-to-live in seconds (nil = infinite)
	enableAutoWarmup = false, -- Auto-warmup on first acquire
}

local Pool: PoolType = {} :: any
Pool.store = {} :: PoolStore

-- Running count of pooled Instances across all classes. Kept in sync by every push/pop below
-- (and recounted after bulk operations), so release() no longer walks every class list via
-- getStatistics() just to enforce maxTotalSize.
local pooledCount = 0

--- Recomputes pooledCount from the store (after bulk operations)
local function recountPooled(): ()
	pooledCount = 0
	for _, list in Pool.store do
		pooledCount += #list
	end
end
Pool.config = table.clone(DEFAULT_CONFIG)
Pool.metrics = {
	acquires = 0,
	releases = 0,
	creates = 0,
	hits = 0,
	misses = 0,
	destroyed = 0,
	evictions = 0,
}
Pool.customResetHandlers = {}
Pool.eventHooks = {}
Pool.instanceMetadata = {}
Pool._debugMode = false
Pool._typeCheckCache = {}

--- Gets cached type information for a class
--- @param className string -- Class name to check
--- @return table -- Cached type info
local function getTypeInfo(className: string): { isGuiObject: boolean, isText: boolean, isImage: boolean }
	if not Pool._typeCheckCache[className] then
		local success, testInst = pcall(Instance.new, className)
		if success and testInst then
			Pool._typeCheckCache[className] = {
				isGuiObject = testInst:IsA("GuiObject"),
				isText = testInst:IsA("TextLabel") or testInst:IsA("TextButton") or testInst:IsA("TextBox"),
				isImage = testInst:IsA("ImageLabel") or testInst:IsA("ImageButton"),
			}
			testInst:Destroy()
		else
			Pool._typeCheckCache[className] = {
				isGuiObject = false,
				isText = false,
				isImage = false,
			}
		end
	end
	return Pool._typeCheckCache[className]
end

--- Checks if an instance is valid (not destroyed)
--- @param inst Instance -- Instance to check
--- @return boolean -- True if valid
local function isInstanceValid(inst: Instance): boolean
	-- Destroyed Instances stay readable (ClassName etc.) but their Parent is locked,
	-- so writing it is the cheap, reliable check. Pooled instances are unparented anyway.
	return pcall(function()
		inst.Parent = nil
	end)
end

--- Evicts old instances based on TTL
--- @param className string -- Class name to check
local function evictStaleInstances(className: string): ()
	if not Pool.config.defaultTTL then
		return
	end

	local list = Pool.store[className]
	if not list then
		return
	end

	local now = os.clock()
	local i = 1
	while i <= #list do
		local inst = list[i]
		local metadata = Pool.instanceMetadata[inst]
		if metadata and metadata.releasedAt then
			local age = now - metadata.releasedAt
			if age > Pool.config.defaultTTL then
				-- Evict stale instance
				table.remove(list, i)
				pooledCount -= 1
				Pool.instanceMetadata[inst] = nil
				pcall(function()
					inst:Destroy()
				end)

				if Pool.config.enableMetrics then
					Pool.metrics.evictions += 1
					Pool.metrics.destroyed += 1
				end

				if Pool.eventHooks.onEvict then
					pcall(function()
						Pool.eventHooks.onEvict(inst, "TTL_EXPIRED")
					end)
				end

				if Pool._debugMode then
					debugModule.log("Pool", "Evicted stale instance", {
						className = className,
						age = age,
						ttl = Pool.config.defaultTTL,
					})
				end
				continue
			end
		end
		i += 1
	end
end

-- One pristine Instance per class, used as the source of default property values
local defaultTemplates: { [string]: Instance | false } = {}

--- Restores properties the renderer wrote back to their class defaults
--- @param inst Instance -- Instance being pooled
--- @param touched { [string]: boolean } -- Property names that were set while it was mounted
local function restoreTouchedProps(inst: Instance, touched: { [string]: boolean }): ()
	local className = inst.ClassName
	local template = defaultTemplates[className]
	if template == nil then
		local ok, created = pcall(Instance.new, className)
		local resolved: Instance | false = false
		if ok then
			resolved = created :: any
		end
		template = resolved
		defaultTemplates[className] = resolved
	end
	if not template then
		return
	end
	for prop in touched do
		pcall(function()
			(inst :: any)[prop] = (template :: any)[prop]
		end)
	end
end

--- Resets an Instance to its default state
--- @param inst Instance -- Instance to reset
--- @param touched { [string]: boolean }? -- Properties set while mounted (restored to class defaults)
local function resetInstance(inst: Instance, touched: { [string]: boolean }?): ()
	if not inst then
		return
	end

	-- Without this, a reused Instance keeps stale colors/fonts/etc. from its previous owner
	if touched then
		restoreTouchedProps(inst, touched)
	end

	-- Use custom handler if available
	local handler = Pool.customResetHandlers[inst.ClassName]
	if handler then
		pcall(handler, inst)
		return
	end

	-- Get cached type information
	local typeInfo = getTypeInfo(inst.ClassName)

	pcall(function()
		-- Clear parent first
		inst.Parent = nil

		-- Destroy all children
		local children = inst:GetChildren()
		for _, child in ipairs(children) do
			pcall(function()
				child:Destroy()
			end)
		end

		-- Clear text properties (using cached type check)
		if typeInfo.isText then
			-- TextLabel stands in for TextLabel | TextButton | TextBox (all have Text)
			(inst :: TextLabel).Text = ""
		end

		-- Clear image properties (using cached type check)
		if typeInfo.isImage then
			(inst :: ImageLabel).Image = ""
		end

		-- Reset GuiObject properties in a single pcall
		if typeInfo.isGuiObject then
			local guiObj = inst :: GuiObject
			guiObj.LayoutOrder = 0
			guiObj.Visible = true
			guiObj.Size = UDim2.new(0, 0, 0, 0)
			guiObj.Position = UDim2.new(0, 0, 0, 0)
			guiObj.AnchorPoint = Vector2.new(0, 0)
			guiObj.BackgroundTransparency = 0
		end

		-- Reset name
		inst.Name = "Pooled" .. inst.ClassName

		-- Clear all attributes (synchronous for immediate cleanup)
		if inst.GetAttributes then
			pcall(function()
				local attrs = inst:GetAttributes()
				for attrName, _ in pairs(attrs) do
					pcall(function()
						inst:SetAttribute(attrName, nil)
					end)
				end
			end)
		end
		-- Event connections live on the vnode (vnode._conns) and are cleared by the renderer;
		-- Instances can't hold Lua fields, so there is nothing else to disconnect here.
	end)
end

--- Restores the given properties to their class defaults (used by the renderer when a prop is removed)
--- @param inst Instance -- Instance to update
--- @param props { [string]: boolean } -- Property names to restore
function Pool.restoreDefaults(inst: Instance, props: { [string]: boolean }): ()
	restoreTouchedProps(inst, props)
end

--- Acquires an Instance from the pool
--- @param className string -- Class name to acquire
--- @return Instance -- Acquired or newly created Instance
function Pool.acquire(className: string): Instance
	if Pool.config.enableMetrics then
		Pool.metrics.acquires += 1
	end

	-- Auto-warmup on first acquire
	if Pool.config.enableAutoWarmup and not Pool.store[className] then
		Pool.warmup(className, 5)
	end

	Pool.store[className] = Pool.store[className] or {}
	local list = Pool.store[className]

	-- Evict stale instances if TTL is enabled
	if Pool.config.defaultTTL then
		evictStaleInstances(className)
	end

	local fromPool = false
	local inst: Instance

	if #list > 0 then
		-- Try to get from pool, validate it's not destroyed
		local attempts = 0
		while #list > 0 and attempts < 3 do
			inst = table.remove(list) :: Instance
			pooledCount -= 1
			if isInstanceValid(inst) then
				fromPool = true
				if Pool.config.enableMetrics then
					Pool.metrics.hits += 1
				end
				break
			else
				-- Instance was destroyed, try next
				Pool.instanceMetadata[inst] = nil
				attempts += 1
				if Pool.config.enableMetrics then
					Pool.metrics.destroyed += 1
				end
			end
		end
	end

	if not fromPool then
		-- Create new instance
		if Pool.config.enableMetrics then
			Pool.metrics.misses += 1
			Pool.metrics.creates += 1
		end

		local ok, result = pcall(function()
			return Instance.new(className)
		end)
		if ok and result then
			inst = result :: Instance
		else
			warn("[Pool] Failed to create instance of class:", className)
			inst = Instance.new("Frame")
		end
	end

	-- Track metadata
	Pool.instanceMetadata[inst] = {
		acquiredAt = os.clock(),
		releasedAt = nil,
	}

	-- Fire event hook
	if Pool.eventHooks.onAcquire then
		pcall(function()
			Pool.eventHooks.onAcquire(inst, fromPool)
		end)
	end

	if Pool._debugMode or (not fromPool and Pool.config.enableDebug) then
		debugModule.log("Pool", "Acquired instance", {
			className = className,
			fromPool = fromPool,
			poolSize = #list,
			totalInstances = pooledCount,
		})
	end

	return inst
end

--- Acquires multiple instances from the pool
--- @param className string -- Class name to acquire
--- @param count number -- Number of instances to acquire
--- @return { Instance } -- Array of acquired instances
function Pool.acquireMultiple(className: string, count: number): { Instance }
	local instances = table.create(count)
	for i = 1, count do
		instances[i] = Pool.acquire(className)
	end
	return instances
end

--- Releases an Instance back to the pool
--- @param inst Instance -- Instance to release
function Pool.release(inst: Instance, touched: { [string]: boolean }?): ()
	if not inst or not inst.ClassName then
		warn("[Pool] Attempted to release invalid instance")
		return
	end

	if Pool.config.enableMetrics then
		Pool.metrics.releases += 1
	end

	-- Validate instance is not destroyed
	if not isInstanceValid(inst) then
		Pool.instanceMetadata[inst] = nil
		if Pool.config.enableMetrics then
			Pool.metrics.destroyed += 1
		end
		if Pool._debugMode then
			debugModule.log("Pool", "Cannot release destroyed instance", {
				className = inst.ClassName,
			})
		end

		if Pool.eventHooks.onRelease then
			pcall(function()
				Pool.eventHooks.onRelease(inst, false)
			end)
		end
		return
	end

	Pool.store[inst.ClassName] = Pool.store[inst.ClassName] or {}
	local list = Pool.store[inst.ClassName]

	-- Check pool size limits
	local shouldPool = true
	local evictionReason = ""

	if Pool.config.maxPoolSize and #list >= Pool.config.maxPoolSize then
		shouldPool = false
		evictionReason = "MAX_POOL_SIZE"
	elseif Pool.config.maxTotalSize and pooledCount >= Pool.config.maxTotalSize then
		shouldPool = false
		evictionReason = "MAX_TOTAL_SIZE"
	end

	if shouldPool then
		-- Update metadata
		if not Pool.instanceMetadata[inst] then
			Pool.instanceMetadata[inst] = {
				acquiredAt = os.clock(),
				releasedAt = nil,
			}
		end
		Pool.instanceMetadata[inst].releasedAt = os.clock()

		-- Reset and pool
		resetInstance(inst, touched)
		table.insert(list, inst)
		pooledCount += 1

		if Pool._debugMode then
			debugModule.log("Pool", "Released instance to pool", {
				className = inst.ClassName,
				poolSize = #list,
			})
		end
	else
		-- Destroy instead of pooling
		Pool.instanceMetadata[inst] = nil
		pcall(function()
			inst:Destroy()
		end)

		if Pool.config.enableMetrics then
			Pool.metrics.evictions += 1
			Pool.metrics.destroyed += 1
		end

		if Pool.eventHooks.onEvict then
			pcall(function()
				Pool.eventHooks.onEvict(inst, evictionReason)
			end)
		end

		if Pool._debugMode then
			debugModule.log("Pool", "Evicted instance (limit reached)", {
				className = inst.ClassName,
				reason = evictionReason,
				poolSize = #list,
			})
		end
	end

	-- Fire release event hook
	if Pool.eventHooks.onRelease then
		pcall(function()
			Pool.eventHooks.onRelease(inst, shouldPool)
		end)
	end
end

--- Releases multiple instances back to the pool
--- @param instances { Instance } -- Array of instances to release
function Pool.releaseMultiple(instances: { Instance }): ()
	for _, inst in ipairs(instances) do
		Pool.release(inst)
	end
end

--- Clears Instances from the pool
--- @param className string? -- Optional class name to clear (nil = clear all)
function Pool.clear(className: string?): ()
	local totalCleared = 0

	if className then
		-- Clear specific class
		local list = Pool.store[className]
		if list then
			totalCleared = #list
			for _, inst in ipairs(list) do
				Pool.instanceMetadata[inst] = nil
				pcall(function()
					inst:Destroy()
				end)
			end
			Pool.store[className] = {}
		end
	else
		-- Clear all
		for cls, list in pairs(Pool.store) do
			totalCleared += #list
			for _, inst in ipairs(list) do
				Pool.instanceMetadata[inst] = nil
				pcall(function()
					inst:Destroy()
				end)
			end
			Pool.store[cls] = {}
		end
	end
	recountPooled()

	if Pool.config.enableMetrics then
		Pool.metrics.destroyed += totalCleared
	end

	-- Fire event hook
	if Pool.eventHooks.onClear then
		pcall(function()
			Pool.eventHooks.onClear(totalCleared)
		end)
	end

	if Pool._debugMode or Pool.config.enableDebug then
		debugModule.log("Pool", "Cleared pool", {
			className = className or "ALL",
			instancesDestroyed = totalCleared,
		})
	end
end

--- Updates pool configuration
--- @param config PoolConfig -- Configuration options
function Pool.configure(config: PoolConfig): ()
	for key, value in pairs(config) do
		if Pool.config[key] ~= nil then
			(Pool.config :: any)[key] = value
		end
	end

	Pool._debugMode = Pool.config.enableDebug == true

	if Pool._debugMode then
		debugModule.log("Pool", "Configuration updated", config)
	end
end

--- Pre-populates the pool with instances
--- @param className string -- Class name to warmup
--- @param count number -- Number of instances to create
function Pool.warmup(className: string, count: number): ()
	Pool.store[className] = Pool.store[className] or {}
	local list = Pool.store[className]

	local created = 0
	for _ = 1, count do
		local ok, inst = pcall(function()
			return Instance.new(className)
		end)
		if ok and inst then
			resetInstance(inst :: Instance)
			table.insert(list, inst :: Instance)
			pooledCount += 1
			created += 1
		end
	end

	if Pool.config.enableMetrics then
		Pool.metrics.creates += created
	end

	if Pool._debugMode or Pool.config.enableDebug then
		debugModule.log("Pool", "Warmup completed", {
			className = className,
			requested = count,
			created = created,
			poolSize = #list,
		})
	end
end

--- Gets detailed pool statistics
--- @return PoolStatistics -- Current statistics
function Pool.getStatistics(): PoolStatistics
	local totalInstances = 0
	local poolsByClass = {}

	for cls, list in pairs(Pool.store) do
		poolsByClass[cls] = #list
		totalInstances += #list
	end

	local hitRate = 0
	if Pool.metrics.acquires > 0 then
		hitRate = Pool.metrics.hits / Pool.metrics.acquires
	end

	return {
		totalInstances = totalInstances,
		poolsByClass = poolsByClass,
		metrics = table.clone(Pool.metrics),
		hitRate = hitRate,
	}
end

--- Validates pool health and removes invalid instances
--- @return boolean -- True if pool is healthy
function Pool.validateHealth(): boolean
	local removedCount = 0
	local totalChecked = 0

	for _, list in pairs(Pool.store) do
		local i = 1
		while i <= #list do
			totalChecked += 1
			local inst = list[i]
			if not isInstanceValid(inst) then
				table.remove(list, i)
				pooledCount -= 1
				Pool.instanceMetadata[inst] = nil
				removedCount += 1

				if Pool.config.enableMetrics then
					Pool.metrics.destroyed += 1
				end

				if Pool.eventHooks.onEvict then
					pcall(function()
						Pool.eventHooks.onEvict(inst, "HEALTH_CHECK_FAILED")
					end)
				end
			else
				i += 1
			end
		end
	end

	local isHealthy = removedCount == 0

	if Pool._debugMode or (not isHealthy and Pool.config.enableDebug) then
		debugModule.log("Pool", "Health check completed", {
			totalChecked = totalChecked,
			removedCount = removedCount,
			isHealthy = isHealthy,
		})
	end

	return isHealthy
end

--- Creates a snapshot of the current pool state
--- @return { [string]: { Instance } } -- Pool snapshot
function Pool.createSnapshot(): { [string]: { Instance } }
	local snapshot = {}
	for className, list in pairs(Pool.store) do
		snapshot[className] = table.clone(list)
	end

	if Pool._debugMode then
		local totalInstances = 0
		local classNames = {}
		for className, list in pairs(snapshot) do
			totalInstances += #list
			table.insert(classNames, className)
		end
		debugModule.log("Pool", "Snapshot created", {
			classes = table.concat(classNames, ", "),
			totalInstances = totalInstances,
		})
	end

	return snapshot
end

--- Restores pool from a snapshot
--- @param snapshot { [string]: { Instance } } -- Pool snapshot to restore
function Pool.restoreSnapshot(snapshot: { [string]: { Instance } }): ()
	-- Clear current pool
	Pool.clear()

	-- Restore from snapshot
	for className, list in pairs(snapshot) do
		Pool.store[className] = table.clone(list)
	end
	recountPooled()

	if Pool._debugMode then
		local totalInstances = 0
		local classNames = {}
		for className, list in pairs(Pool.store) do
			totalInstances += #list
			table.insert(classNames, className)
		end
		debugModule.log("Pool", "Snapshot restored", {
			classes = table.concat(classNames, ", "),
			totalInstances = totalInstances,
		})
	end
end

--- Sets a custom reset handler for a class
--- @param className string -- Class name
--- @param handler ResetHandler -- Custom reset function
function Pool.setResetHandler(className: string, handler: ResetHandler): ()
	Pool.customResetHandlers[className] = handler

	if Pool._debugMode then
		debugModule.log("Pool", "Custom reset handler registered", {
			className = className,
		})
	end
end

--- Sets an event hook
--- @param hookName string -- Hook name (onAcquire, onRelease, onClear, onEvict)
--- @param handler function -- Callback function
function Pool.setEventHook(hookName: string, handler: (...any) -> ()): ()
	if hookName == "onAcquire" or hookName == "onRelease" or hookName == "onClear" or hookName == "onEvict" then
		(Pool.eventHooks :: any)[hookName] = handler

		if Pool._debugMode then
			debugModule.log("Pool", "Event hook registered", {
				hookName = hookName,
			})
		end
	else
		warn("[Pool] Invalid hook name:", hookName)
	end
end

return Pool
