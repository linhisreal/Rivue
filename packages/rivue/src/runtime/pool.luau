--!strict
--!optimize 2

local Types = require("./types")

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

local debugModule = require("./debug")

local DEFAULT_CONFIG: PoolConfig = {
	maxPoolSize = 50,
	maxTotalSize = 500,
	enableMetrics = true,
	enableDebug = false,
	defaultTTL = nil, -- Time-to-live in seconds (nil = infinite)
	enableAutoWarmup = false,
}

local Pool: PoolType = {} :: any
Pool.store = {} :: PoolStore

local pooledCount = 0

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
-- Weak keys: an Instance destroyed without being released (a leave transition) mustn't stay here
Pool.instanceMetadata = setmetatable({}, { __mode = "k" }) :: any
Pool._debugMode = false
Pool._typeCheckCache = {}

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

local function isInstanceValid(inst: Instance): boolean
	return pcall(function()
		inst.Parent = nil
	end)
end

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

-- One untouched instance per class, used for default property values
local defaultTemplates: { [string]: Instance | false } = {}

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

const GUI_RESET = table.freeze({
	LayoutOrder = true,
	Visible = true,
	Size = true,
	Position = true,
	AnchorPoint = true,
	BackgroundTransparency = true,
})
local function withProp(base: { [string]: boolean }, prop: string): { [string]: boolean }
	local set = table.clone(base)
	set[prop] = true
	return table.freeze(set)
end
local TEXT_RESET = withProp(GUI_RESET, "Text")
local IMAGE_RESET = withProp(GUI_RESET, "Image")

local function resetInstance(inst: Instance, touched: { [string]: boolean }?): ()
	if not inst then
		return
	end

	if touched then
		restoreTouchedProps(inst, touched)
	end

	local handler = Pool.customResetHandlers[inst.ClassName]
	if handler then
		pcall(handler, inst)
		return
	end

	local typeInfo = getTypeInfo(inst.ClassName)

	pcall(function()
		inst.Parent = nil

		local children = inst:GetChildren()
		for _, child in ipairs(children) do
			pcall(function()
				child:Destroy()
			end)
		end

		-- Class defaults, so a pooled element looks like a new one
		if typeInfo.isGuiObject then
			restoreTouchedProps(
				inst,
				if typeInfo.isText then TEXT_RESET elseif typeInfo.isImage then IMAGE_RESET else GUI_RESET
			)
		end

		inst.Name = inst.ClassName

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
	end)
end

function Pool.restoreDefaults(inst: Instance, props: { [string]: boolean }): ()
	restoreTouchedProps(inst, props)
end

function Pool.acquire(className: string): Instance
	if Pool.config.enableMetrics then
		Pool.metrics.acquires += 1
	end

	if Pool.config.enableAutoWarmup and not Pool.store[className] then
		Pool.warmup(className, 5)
	end

	Pool.store[className] = Pool.store[className] or {}
	local list = Pool.store[className]

	if Pool.config.defaultTTL then
		evictStaleInstances(className)
	end

	local fromPool = false
	local inst: Instance

	if #list > 0 then
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
				Pool.instanceMetadata[inst] = nil
				attempts += 1
				if Pool.config.enableMetrics then
					Pool.metrics.destroyed += 1
				end
			end
		end
	end

	if not fromPool then
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

	Pool.instanceMetadata[inst] = {
		acquiredAt = os.clock(),
		releasedAt = nil,
	}

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

function Pool.acquireMultiple(className: string, count: number): { Instance }
	local instances = table.create(count)
	for i = 1, count do
		instances[i] = Pool.acquire(className)
	end
	return instances
end

function Pool.release(inst: Instance, touched: { [string]: boolean }?): ()
	if not inst or not inst.ClassName then
		warn("[Pool] Attempted to release invalid instance")
		return
	end

	if Pool.config.enableMetrics then
		Pool.metrics.releases += 1
	end

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
		if not Pool.instanceMetadata[inst] then
			Pool.instanceMetadata[inst] = {
				acquiredAt = os.clock(),
				releasedAt = nil,
			}
		end
		Pool.instanceMetadata[inst].releasedAt = os.clock()

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

	if Pool.eventHooks.onRelease then
		pcall(function()
			Pool.eventHooks.onRelease(inst, shouldPool)
		end)
	end
end

function Pool.releaseMultiple(instances: { Instance }): ()
	for _, inst in ipairs(instances) do
		Pool.release(inst)
	end
end

function Pool.clear(className: string?): ()
	local totalCleared = 0

	if className then
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

-- defaultTTL starts as nil, so known keys can't be found by reading the current config
const CONFIG_KEYS = table.freeze({
	maxPoolSize = true,
	maxTotalSize = true,
	enableMetrics = true,
	enableDebug = true,
	defaultTTL = true,
	enableAutoWarmup = true,
})

function Pool.configure(config: PoolConfig): ()
	for key, value in pairs(config) do
		if CONFIG_KEYS[key] then
			(Pool.config :: any)[key] = value
		end
	end

	Pool._debugMode = Pool.config.enableDebug == true

	if Pool._debugMode then
		debugModule.log("Pool", "Configuration updated", config)
	end
end

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

function Pool.restoreSnapshot(snapshot: { [string]: { Instance } }): ()
	Pool.clear()

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

function Pool.setResetHandler(className: string, handler: ResetHandler): ()
	Pool.customResetHandlers[className] = handler

	if Pool._debugMode then
		debugModule.log("Pool", "Custom reset handler registered", {
			className = className,
		})
	end
end

--- hookName: onAcquire, onRelease, onClear or onEvict
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
