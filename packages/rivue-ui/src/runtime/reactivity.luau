--!strict
--!optimize 2
--!native

local Types = require("./types")

type Ref<T> = Types.Ref<T>
type ComputedRef<T> = Types.ComputedRef<T>
type WritableComputedOptions<T> = Types.WritableComputedOptions<T>
type MaybeRef<T> = Types.MaybeRef<T>
type Effect = Types.Effect
type EffectOptions = Types.EffectOptions
type EffectScheduler = Types.EffectScheduler
type EffectScope = Types.EffectScope
type Dep = Types.Dep
type WatchOptions = Types.WatchOptions
type WatchCallback<T> = Types.WatchCallback<T>
type WatchSource<T> = Types.WatchSource<T>
type WatchHandle = Types.WatchHandle
type OnCleanup = Types.OnCleanup
type CustomRefFactory<T> = Types.CustomRefFactory<T>

type RawTable = { [unknown]: unknown }
type RefInternal = {
	_is_ref: true,
	_value: unknown,
	_shallow: boolean?,
	_dep: Dep | false,
}

local scheduler = require("./scheduler")
local debugModule = require("./debug")
local utils = require("./utils")
local RunService = game:GetService("RunService")

const IS_STUDIO = RunService:IsStudio()

local function weakKeyed<K, V>(): { [K]: V }
	return setmetatable({}, { __mode = "k" }) :: any
end

-- Weak keys: a target nobody references can't be triggered anymore
local depMap: { [unknown]: { [unknown]: Dep } } = weakKeyed()
local effectStack: { Effect } = {}
local activeEffect: Effect? = nil

const ITERATE_KEY = newproxy(false)
const LENGTH_KEY = "__len"
const REF_VALUE_KEY = "value"
const COMPUTED_KEY = "computed"

-- NaN ~= NaN in Luau, so a plain ~= would re-trigger on every NaN write. Same rule as Vue's Object.is
local function hasChanged(a: unknown, b: unknown): boolean
	return a ~= b and (a == a or b == b)
end

local scopeStack: { EffectScope } = {}
local activeScope: EffectScope? = nil

--- Returns fn's result, or nil if the scope is inactive or fn errored
local function scopeRun(self: EffectScope, fn: () -> unknown): unknown
	if not self.active then
		debugModule.log("Reactivity", "Cannot run() on inactive effect scope")
		return nil
	end

	table.insert(scopeStack, self)
	activeScope = self

	local ok, result = pcall(fn)

	table.remove(scopeStack)
	activeScope = scopeStack[#scopeStack]

	if not ok then
		debugModule.log("Reactivity", "Error in effect scope", { error = result })
		return nil
	end

	return result
end

local function scopeStop(self: EffectScope)
	if not self.active then
		return
	end

	self.active = false

	for _, childScope in self.scopes do
		childScope:stop()
	end

	for _, eff in self.effects do
		eff:stop()
	end

	for _, cleanup in self.cleanups do
		pcall(cleanup)
	end

	table.clear(self.effects)
	table.clear(self.cleanups)
	table.clear(self.scopes)
end

--- A detached scope isn't stopped with its parent scope
local function effectScope(detached: boolean?): EffectScope
	local scope: EffectScope = {
		active = true,
		effects = {},
		cleanups = {},
		scopes = {},
		parent = if detached then nil else activeScope,
		run = scopeRun,
		stop = scopeStop,
	}

	local parent = scope.parent
	if parent then
		table.insert(parent.scopes, scope)
	end

	return scope
end

local function getCurrentScope(): EffectScope?
	return activeScope
end

local function onScopeDispose(fn: () -> (), failSilently: boolean?)
	if not activeScope then
		if not failSilently and IS_STUDIO then
			debugModule.log("Reactivity", "onScopeDispose called without an active effect scope")
		end
		return
	end

	table.insert(activeScope.cleanups, fn)
end

local rawMarker: { [unknown]: true } = weakKeyed()
local reactiveMarker: { [unknown]: RawTable } = weakKeyed()
local readonlyMarker: { [unknown]: true } = weakKeyed()
local shallowMarker: { [unknown]: true } = weakKeyed()

local function markRaw<T>(obj: T): T
	if type(obj) == "table" then
		rawMarker[obj] = true
	end
	return obj
end

local function toRaw<T>(obj: T): T
	local original = reactiveMarker[obj]
	if original then
		return original :: any
	end
	return obj
end

local function isReactive(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local target = reactiveMarker[value]
	if target == nil then
		return false
	end
	-- A readonly view is only reactive when what it wraps is
	if readonlyMarker[value] then
		return isReactive(target)
	end
	return true
end

local function isReadonly(value: unknown): boolean
	return type(value) == "table" and readonlyMarker[value] == true
end

local function isProxy(value: unknown): boolean
	return isReactive(value) or isReadonly(value)
end

local function shouldWrap(value: unknown): boolean
	return type(value) == "table" and not rawMarker[value]
end

local function clearDeps(eff: Effect)
	for _, dep in eff.deps do
		dep[eff] = nil
	end
	table.clear(eff.deps)
end

-- component.luau fills these in, so errors in a component's watchers reach its onErrorCaptured
local errorOwner: () -> any = function()
	return nil
end
local reportError: (owner: any, err: string, info: string) -> () = function() end

local function setErrorHandling(getOwner: () -> any, report: (owner: any, err: string, info: string) -> ())
	errorOwner, reportError = getOwner, report
end

local function createEffect(fn: () -> (), opts: EffectOptions?, onError: ((err: string) -> ())?): Effect
	local options: EffectOptions = opts or {}
	local effect = {
		fn = fn,
		scheduler = options.scheduler,
		deps = {} :: { Dep },
		active = true,
		onTrack = options.onTrack,
		onTrigger = options.onTrigger,
		allowRecurse = options.allowRecurse,
	}
	local typedEffect: Effect = effect :: any

	function effect.run()
		if not effect.active then
			fn()
			return
		end

		local effectName = if utils.profiler.active then "effect_" .. tostring(effect) else nil
		if effectName then
			utils.profiler:start(effectName)
		end

		clearDeps(typedEffect)
		local depth = #effectStack
		effectStack[depth + 1] = typedEffect
		activeEffect = typedEffect
		local ok, err = pcall(fn :: () -> ...unknown)
		-- Computeds inside run without a pcall of their own, so one that threw left its entry here
		for i = #effectStack, depth + 1, -1 do
			effectStack[i] = nil
		end
		activeEffect = effectStack[depth]

		if effectName then
			utils.profiler:stop(effectName)
		end

		if not ok then
			if onError then
				onError(tostring(err))
			else
				warn(`[Rivue] Error in effect: {err}`)
			end
		end
	end

	-- Queued runs skip stopped effects (run() itself still works for manual calls)
	local function job()
		if effect.active then
			effect.run()
		end
	end
	effect.job = job

	function effect.stop(self: Effect)
		if not self.active then
			return
		end
		self.active = false
		for _, dep in self.deps do
			dep[self] = nil
		end
		table.clear(self.deps)
	end

	if activeScope then
		table.insert(activeScope.effects, typedEffect)
	end

	if not options.lazy then
		local effectScheduler = typedEffect.scheduler
		if effectScheduler then
			effectScheduler(typedEffect.run)
		else
			scheduler.queueEffect(job)
		end
	end
	return typedEffect
end

local function trackDep(dep: Dep, current: Effect, target: unknown, key: unknown)
	if not dep[current] then
		dep[current] = true
		local deps = current.deps
		deps[#deps + 1] = dep
		local onTrack = current.onTrack
		if onTrack then
			onTrack({ target = target, key = key })
		end
	end
end

local function track(target: unknown, key: unknown)
	local current = activeEffect
	if not current then
		return
	end
	local deps = depMap[target]
	if not deps then
		deps = {}
		depMap[target] = deps
	end
	local dep = deps[key]
	if not dep then
		dep = {}
		deps[key] = dep
	end
	if not dep[current] then
		dep[current] = true
		local effectDeps = current.deps
		effectDeps[#effectDeps + 1] = dep
		local onTrack = current.onTrack
		if onTrack then
			onTrack({ target = target, key = key })
		end
	end
end

-- For engine calls made mid-render: in Immediate signal mode their handlers run right away, and
-- whatever state those handlers read would otherwise become a dependency of the render
local function untracked(fn: () -> ())
	local prev = activeEffect
	activeEffect = nil
	local ok, err = pcall(fn :: () -> ...unknown)
	activeEffect = prev
	if not ok then
		error(err, 0)
	end
end

local triggerScratch: { { Effect } } = {}
local triggerDepth = 0

local function dispatch(eff: Effect, target: unknown, key: unknown)
	-- An effect writing state it reads doesn't re-trigger itself (same as Vue)
	if not eff.active or (eff == activeEffect and not eff.allowRecurse) then
		return
	end
	local onTrigger = eff.onTrigger
	if onTrigger then
		onTrigger({ target = target, key = key })
	end
	local effectScheduler = eff.scheduler
	if effectScheduler then
		effectScheduler(eff.run)
	else
		scheduler.queueEffect(eff.job)
	end
end

local function triggerDep(dep: Dep, target: unknown, key: unknown)
	-- Copy first, sync effects change dep during the loop. Scratch arrays are reused per
	-- nesting depth so a write doesn't allocate.
	triggerDepth += 1
	local effects = triggerScratch[triggerDepth]
	if not effects then
		effects = {}
		triggerScratch[triggerDepth] = effects
	end
	local count = 0
	for eff in dep do
		count += 1
		effects[count] = eff
	end
	for i = 1, count do
		local eff = effects[i]
		effects[i] = nil
		dispatch(eff, target, key)
	end
	triggerDepth -= 1
end

local function trigger(target: unknown, key: unknown)
	local deps = depMap[target]
	if not deps then
		return
	end
	local dep = deps[key]
	if dep then
		triggerDep(dep, target, key)
	end
end

local function triggerSet(target: RawTable, key: unknown, old: unknown, new: unknown)
	trigger(target, key)
	if old == nil or new == nil then
		trigger(target, ITERATE_KEY)
		if type(key) == "number" then
			trigger(target, LENGTH_KEY)
		end
	end
end

local proxyCache: { [RawTable]: RawTable } = weakKeyed()
local shallowProxyCache: { [RawTable]: RawTable } = weakKeyed()
local readonlyCache: { [RawTable]: RawTable } = weakKeyed()
local shallowReadonlyCache: { [RawTable]: RawTable } = weakKeyed()

--- Nested tables become reactive when they're read
local function reactive<T>(target: T): T
	assert(type(target) == "table", "reactive expects a table")
	local tbl: RawTable = target :: any
	if rawMarker[tbl] or reactiveMarker[tbl] or readonlyMarker[tbl] then
		return target
	end
	local cached = proxyCache[tbl]
	if cached then
		return cached :: any
	end

	local proxy: RawTable = {}

	reactiveMarker[proxy] = tbl

	local mt = {}
	function mt.__index(_: RawTable, k: unknown): unknown
		track(tbl, k)
		local v = tbl[k]
		if shouldWrap(v) then
			return reactive(v)
		end
		return v
	end
	function mt.__newindex(_: RawTable, k: unknown, v: unknown)
		-- Keep proxies out of the raw table
		v = toRaw(v)
		local old = tbl[k]
		tbl[k] = v
		if hasChanged(old, v) then
			triggerSet(tbl, k, old, v)
		end
	end
	-- Luau ignores __pairs/__ipairs, use `for k, v in proxy do` or `for i = 1, #proxy do`
	function mt.__iter(_: RawTable)
		track(tbl, ITERATE_KEY)
		return function(_: RawTable, k: unknown): (unknown, unknown)
			local nk, nv = next(tbl, k)
			-- Each value read by a loop is a read, so changing it re-runs the loop like it does in Vue
			if nk ~= nil then
				track(tbl, nk)
			end
			if shouldWrap(nv) then
				nv = reactive(nv)
			end
			return nk, nv
		end,
			proxy,
			nil
	end
	function mt.__len(_: RawTable): number
		track(tbl, LENGTH_KEY)
		return #tbl
	end
	function mt.__tostring(_: RawTable): string
		return if IS_STUDIO then "<Reactive Proxy>" else tostring(tbl)
	end
	setmetatable(proxy :: any, mt)
	proxyCache[tbl] = proxy
	return proxy :: any
end

local function shallowReactive<T>(target: T): T
	assert(type(target) == "table", "shallowReactive expects a table")
	local tbl: RawTable = target :: any
	if rawMarker[tbl] or reactiveMarker[tbl] or readonlyMarker[tbl] then
		return target
	end
	local cached = shallowProxyCache[tbl]
	if cached then
		return cached :: any
	end

	local proxy: RawTable = {}

	reactiveMarker[proxy] = tbl
	shallowMarker[proxy] = true

	local mt = {}
	function mt.__index(_: RawTable, k: unknown): unknown
		track(tbl, k)
		return tbl[k]
	end
	function mt.__newindex(_: RawTable, k: unknown, v: unknown)
		local old = tbl[k]
		tbl[k] = v
		if hasChanged(old, v) then
			triggerSet(tbl, k, old, v)
		end
	end
	function mt.__iter(_: RawTable)
		track(tbl, ITERATE_KEY)
		return function(_: RawTable, k: unknown): (unknown, unknown)
			local nk, nv = next(tbl, k)
			if nk ~= nil then
				track(tbl, nk)
			end
			return nk, nv
		end,
			proxy,
			nil
	end
	function mt.__len(_: RawTable): number
		track(tbl, LENGTH_KEY)
		return #tbl
	end
	function mt.__tostring(_: RawTable): string
		return if IS_STUDIO then "<ShallowReactive Proxy>" else tostring(tbl)
	end
	setmetatable(proxy :: any, mt)
	shallowProxyCache[tbl] = proxy
	return proxy :: any
end

local RefMT = {}

-- Like Vue's RefImpl, a ref keeps its own dep instead of going through depMap
function RefMT.__index(self: RefInternal, k: unknown): unknown
	if k == REF_VALUE_KEY then
		local current = activeEffect
		if current then
			local dep = self._dep
			if dep == false then
				local created: Dep = {}
				self._dep = created
				trackDep(created, current, self, REF_VALUE_KEY)
			else
				trackDep(dep :: Dep, current, self, REF_VALUE_KEY)
			end
		end
		return self._value
	end
	return nil
end

function RefMT.__newindex(self: RefInternal, k: unknown, v: unknown)
	if k ~= REF_VALUE_KEY then
		rawset(self :: any, k, v)
		return
	end
	local old = self._value
	local newValue = if not self._shallow and shouldWrap(v) then reactive(v) else v
	self._value = newValue
	local dep = self._dep
	if dep ~= false and hasChanged(old, newValue) then
		triggerDep(dep :: Dep, self, REF_VALUE_KEY)
	end
end

function RefMT.__tostring(self: RefInternal): string
	return if IS_STUDIO then `<Ref: {self._value}>` else tostring(self._value)
end

table.freeze(RefMT)

local function ref<T>(initial: T): Ref<T>
	local wrapped: unknown = if shouldWrap(initial) then reactive(initial) else initial
	local r: RefInternal = { _is_ref = true, _value = wrapped, _dep = false }
	return setmetatable(r :: any, RefMT)
end

local function shallowRef<T>(initial: T): Ref<T>
	local r: RefInternal = { _is_ref = true, _value = initial, _shallow = true, _dep = false }
	return setmetatable(r :: any, RefMT)
end

local function isRef(r: unknown): boolean
	return type(r) == "table" and (r :: any)._is_ref == true
end

local function unref<T>(r: MaybeRef<T>): T
	return if isRef(r) then (r :: Ref<T>).value else r :: T
end

const PROTECTED_COMPUTED_DEPTH = 16
local computedDepth = 0

local function computed<T>(getterOrOptions: ((previous: T?) -> T) | WritableComputedOptions<T>): ComputedRef<T>
	local getter: (previous: T?) -> T
	local setter: ((T) -> ())? = nil
	if type(getterOrOptions) == "function" then
		getter = getterOrOptions
	elseif type(getterOrOptions) == "table" and type(getterOrOptions.get) == "function" then
		getter = getterOrOptions.get
		setter = getterOrOptions.set
	else
		error("computed expects a getter or { get, set }")
	end

	local dirty = true
	local value: T
	local runner: Effect
	runner = createEffect(function()
		value = getter(value)
	end, {
		lazy = true,
		scheduler = function()
			if not dirty then
				dirty = true
				trigger(runner, COMPUTED_KEY)
			end
		end,
	})

	local function evaluate()
		if not runner.active then
			value = getter(value)
			return
		end
		clearDeps(runner)
		local depth = #effectStack
		effectStack[depth + 1] = runner
		activeEffect = runner
		-- Past this depth a pcall per level would hit Luau's limit of about 200 nested C calls. A
		-- level without one relies on the protected level below it to restore the effect stack
		if computedDepth >= PROTECTED_COMPUTED_DEPTH then
			value = getter(value)
			effectStack[depth + 1] = nil
			activeEffect = effectStack[depth]
			return
		end
		computedDepth += 1
		local ok, result = pcall(getter :: (T?) -> ...unknown, value)
		computedDepth -= 1
		for i = #effectStack, depth + 1, -1 do
			effectStack[i] = nil
		end
		activeEffect = effectStack[depth]
		-- Like Vue, a getter's error reaches whoever read the value
		if not ok then
			error(result, 0)
		end
		value = result :: T
	end

	local function get(): T
		if dirty then
			evaluate()
			dirty = false
		end
		if activeEffect then
			track(runner, COMPUTED_KEY)
		end
		return value
	end

	local obj = { _is_ref = true, get = get }
	setmetatable(obj, {
		__index = function(_: unknown, k: unknown): unknown
			if k == REF_VALUE_KEY then
				return get()
			end
			return nil
		end,
		__newindex = function(_: unknown, k: unknown, v: unknown)
			if k ~= REF_VALUE_KEY then
				rawset(obj :: any, k, v)
			elseif setter then
				setter(v :: T)
			elseif IS_STUDIO then
				debugModule.log("Reactivity", "Write to a readonly computed was ignored")
			end
		end,
	})
	return obj :: any
end

local function toRef<K, V>(obj: { [K]: V }, key: K): Ref<V>
	local r = { _is_ref = true }
	setmetatable(r, {
		__index = function(_: unknown, k: unknown): unknown
			if k == REF_VALUE_KEY then
				track(obj, key)
				return obj[key]
			end
			return nil
		end,
		__newindex = function(_: unknown, k: unknown, v: unknown)
			if k == REF_VALUE_KEY then
				local old = obj[key]
				obj[key] = v :: V
				if hasChanged(old, v) then
					trigger(obj, key)
				end
				return
			end
			rawset(r :: any, k, v)
		end,
	})
	return r :: any
end

local function toRefs<K, V>(obj: { [K]: V }): { [K]: Ref<V> }
	local res: { [K]: Ref<V> } = {}
	for k in toRaw(obj) do
		res[k] = toRef(obj, k)
	end
	return res
end

local function _traverse<T>(value: T, seen: { [unknown]: true }?, depth: number?): T
	local remaining = depth or math.huge
	if type(value) ~= "table" or remaining <= 0 then
		return value
	end
	local seenTables: { [unknown]: true } = seen or {}
	if seenTables[value] then
		return value
	end
	seenTables[value] = true
	local proxyOrRaw: RawTable = value :: any
	local raw = toRaw(proxyOrRaw)
	if raw ~= proxyOrRaw then
		-- Added and removed keys only trigger iteration, so a deep watcher has to track it too
		track(raw, ITERATE_KEY)
	end
	-- Read through the proxy so nested keys get tracked
	for k in raw do
		_traverse(proxyOrRaw[k], seenTables, remaining - 1)
	end
	return value
end

local function readSource(item: unknown): unknown
	if isRef(item) then
		return (item :: Ref<unknown>).value
	elseif type(item) == "function" then
		return (item :: () -> unknown)()
	elseif isReactive(item) then
		_traverse(item, nil)
	end
	return item
end

local function isMultiSourceList(list: { [unknown]: unknown }): boolean
	local count = #list
	if count == 0 then
		return false
	end
	for i = 1, count do
		local item = list[i]
		if not (isRef(item) or type(item) == "function" or isReactive(item)) then
			return false
		end
	end
	return true
end

local function arrayShallowEqual(a: { unknown }?, b: { unknown }?): boolean
	if a == nil or b == nil then
		return a == b
	end
	if #a ~= #b then
		return false
	end
	for i, v in a do
		if hasChanged(b[i], v) then
			return false
		end
	end
	return true
end

local WatchHandleMT = {
	__call = function(self: any)
		self.stop()
	end,
}

local function createWatchHandle(stop: () -> (), pause: () -> (), resume: () -> ()): WatchHandle
	return setmetatable({
		stop = function(_: any?)
			stop()
		end,
		pause = pause,
		resume = resume,
	}, WatchHandleMT) :: any
end

local activeWatcherCleanup: OnCleanup? = nil

local function onWatcherCleanup(fn: () -> (), failSilently: boolean?)
	local register = activeWatcherCleanup
	if register then
		register(fn)
	elseif not failSilently then
		warn("[Rivue] onWatcherCleanup() was called outside a watcher callback")
	end
end

local function watch<T>(source: WatchSource<T> | T, cb: WatchCallback<T>, opts: WatchOptions?): WatchHandle
	local options: WatchOptions = opts or {}
	local deepOption = options.deep
	local deep = deepOption == true or (type(deepOption) == "number" and deepOption > 0)
	local deepLevels: number? = if type(deepOption) == "number" then deepOption else nil
	local isMultiSource = false
	-- A reactive item in a source list is the same table after a change, so any trigger counts
	local forceTrigger = false
	local getter: () -> T
	if type(source) == "function" then
		getter = source :: () -> T
	elseif isRef(source) then
		local sourceRef = source :: Ref<T>
		getter = function(): T
			return sourceRef.value
		end
	elseif isReactive(source) then
		-- Same as Vue: watching a reactive object is deep, otherwise it never looks changed
		deep = deepOption ~= false and deepOption ~= 0
		getter = function(): T
			return source :: T
		end
	elseif type(source) == "table" and isMultiSourceList(source) then
		isMultiSource = true
		local sources = source :: { unknown }
		for _, item in sources do
			if isReactive(item) then
				forceTrigger = true
			end
		end
		getter = function(): T
			local values = table.create(#sources)
			for i, item in sources do
				values[i] = readSource(item)
			end
			return values :: any
		end
	else
		getter = function(): T
			return source :: T
		end
	end

	local cleanups: { () -> () } = {}
	local function onCleanup(fn: () -> ())
		table.insert(cleanups, fn)
	end

	local oldValue: T? = nil
	local initialized = false
	local immediate = options.immediate == true
	local flushMode = options.flush or "pre"

	local function runCleanups()
		for _, cleanup in cleanups do
			pcall(cleanup)
		end
		table.clear(cleanups)
	end

	-- Set by the effect so the getter only runs once per change
	local currentValue: T

	local stop: () -> ()
	local paused = false
	local dirty = false

	local function sourceChanged(new: T): boolean
		if deep then
			return true
		elseif isMultiSource then
			return forceTrigger or not arrayShallowEqual(new :: any, oldValue :: any)
		end
		return hasChanged(new, oldValue)
	end

	local stopped = false
	local owner = errorOwner()

	local function job()
		if stopped then
			return
		end
		local new = currentValue
		if initialized and not sourceChanged(new) then
			return
		end
		local shouldCall = initialized or immediate
		initialized = true
		local old = oldValue
		oldValue = new
		if shouldCall then
			runCleanups()
			local prevCleanup = activeWatcherCleanup
			activeWatcherCleanup = onCleanup
			local ok, err = pcall(cb :: (T, T?, OnCleanup) -> ...unknown, new, old, onCleanup)
			activeWatcherCleanup = prevCleanup
			if not ok then
				if owner then
					reportError(owner, tostring(err), "watcher callback")
				else
					error(err, 0)
				end
			end
			if options.once then
				stop()
			end
		end
	end

	local function onTrigger(run: () -> ())
		if paused then
			dirty = true
			return
		end
		run()

		if flushMode == "sync" then
			-- Thrown from here it would reach the code that wrote the value and skip the other effects
			local ok, err = pcall(job :: () -> ...unknown)
			if not ok then
				warn(`[Rivue] Error in sync watcher: {err}`)
			end
		elseif flushMode == "post" then
			scheduler.queueJob(job, { mode = "heartbeat" })
		else
			scheduler.queueJob(job, { mode = "micro" })
		end
	end

	local eff = createEffect(
		function()
			currentValue = getter()
			if deep then
				_traverse(currentValue, nil, deepLevels)
			end
		end,
		{
			lazy = true,
			scheduler = onTrigger,
		},
		if owner
			then function(err: string)
				reportError(owner, err, "watcher getter")
			end
			else nil
	)
	stop = function()
		stopped = true
		eff:stop()
		runCleanups()
	end

	eff.run()
	job()

	return createWatchHandle(stop, function()
		paused = true
	end, function()
		paused = false
		if dirty and not stopped then
			dirty = false
			onTrigger(eff.run)
		end
	end)
end

local function effect(fn: () -> (), opts: EffectOptions?): Effect
	return createEffect(fn, opts)
end

local function watchEffect(fn: (onCleanup: OnCleanup) -> (), opts: WatchOptions?): WatchHandle
	local flushMode = if opts then opts.flush else nil
	local cleanups: { () -> () } = {}
	local function onCleanup(cleanup: () -> ())
		table.insert(cleanups, cleanup)
	end
	local function runCleanups()
		for _, cleanup in cleanups do
			pcall(cleanup)
		end
		table.clear(cleanups)
	end

	local eff: Effect
	local paused = false
	local dirty = false
	local owner = errorOwner()
	local function onTrigger(run: () -> ())
		if paused then
			dirty = true
		elseif flushMode == "sync" then
			run()
		elseif flushMode == "post" then
			scheduler.queueJob(eff.job, { mode = "heartbeat" })
		else
			scheduler.queueEffect(eff.job)
		end
	end
	eff = createEffect(
		function()
			runCleanups()
			local prevCleanup = activeWatcherCleanup
			activeWatcherCleanup = onCleanup
			local ok, err = pcall(fn :: (OnCleanup) -> ...unknown, onCleanup)
			activeWatcherCleanup = prevCleanup
			if not ok then
				error(err, 0)
			end
		end,
		{ lazy = true, scheduler = onTrigger },
		if owner
			then function(err: string)
				reportError(owner, err, "watcher callback")
			end
			else nil
	)
	eff.run()
	return createWatchHandle(function()
		eff:stop()
		runCleanups()
	end, function()
		paused = true
	end, function()
		paused = false
		if dirty and eff.active then
			dirty = false
			onTrigger(eff.run)
		end
	end)
end

local function watchPostEffect(fn: (onCleanup: OnCleanup) -> ()): WatchHandle
	return watchEffect(fn, { flush = "post" })
end

local function watchSyncEffect(fn: (onCleanup: OnCleanup) -> ()): WatchHandle
	return watchEffect(fn, { flush = "sync" })
end

local function createReadonly<T>(target: T, shallow: boolean): T
	if type(target) ~= "table" or rawMarker[target] or readonlyMarker[target] then
		return target
	end

	local source: RawTable = target :: any
	local cache = if shallow then shallowReadonlyCache else readonlyCache
	local cached = cache[source]
	if cached then
		return cached :: any
	end
	-- A view of a reactive table reads its raw table: deps are keyed by raw tables, and next() on
	-- the proxy itself would find nothing
	local tbl: RawTable = reactiveMarker[source] or source

	local proxy: RawTable = {}

	readonlyMarker[proxy] = true
	reactiveMarker[proxy] = source
	if shallow then
		shallowMarker[proxy] = true
	end
	cache[source] = proxy

	-- Nested tables of a deep reactive source stay reactive under the readonly view, as in Vue
	local deepReactive = tbl ~= source and not shallowMarker[source]
	local function wrap(v: unknown): unknown
		if shallow or not shouldWrap(v) then
			return v
		end
		return createReadonly(if deepReactive then reactive(v) else v, false)
	end

	setmetatable(proxy :: any, {
		__index = function(_: RawTable, k: unknown): unknown
			track(tbl, k)
			return wrap(tbl[k])
		end,
		__newindex = function(_: RawTable, k: unknown, _v: unknown)
			if IS_STUDIO then
				debugModule.log("Reactivity", "Cannot mutate readonly reactive object", { key = k })
			end
		end,
		__len = function(_: RawTable): number
			track(tbl, LENGTH_KEY)
			return #tbl
		end,
		__iter = function(_: RawTable)
			track(tbl, ITERATE_KEY)
			return function(_: RawTable, k: unknown): (unknown, unknown)
				local nk, nv = next(tbl, k)
				if nk ~= nil then
					track(tbl, nk)
				end
				return nk, wrap(nv)
			end,
				proxy,
				nil
		end,
	})

	return proxy :: any
end

local function readonly<T>(target: T): T
	return createReadonly(target, false)
end

local function shallowReadonly<T>(target: T): T
	return createReadonly(target, true)
end

local function isShallow(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	return shallowMarker[value] == true or (isRef(value) and rawget(value :: any, "_shallow") == true)
end

local function toValue<T>(source: MaybeRef<T> | () -> T): T
	if type(source) == "function" then
		return (source :: () -> T)()
	end
	return unref(source :: MaybeRef<T>)
end

--- For when you change what a shallowRef holds without replacing .value
local function triggerRef<T>(refObj: Ref<T>)
	if not isRef(refObj) then
		if IS_STUDIO then
			debugModule.log("Reactivity", "triggerRef expects a ref object", { type = type(refObj) })
		end
		return
	end

	if getmetatable(refObj :: any) == RefMT then
		local dep = (refObj :: any)._dep
		if dep then
			triggerDep(dep, refObj, REF_VALUE_KEY)
		end
	else
		trigger(refObj, REF_VALUE_KEY)
	end
end

local function customRef<T>(factory: CustomRefFactory<T>): Ref<T>
	local refTable = { _is_ref = true }

	local accessor = factory(function()
		track(refTable, REF_VALUE_KEY)
	end, function()
		trigger(refTable, REF_VALUE_KEY)
	end)

	if type(accessor) ~= "table" or type(accessor.get) ~= "function" or type(accessor.set) ~= "function" then
		error("[Rivue] customRef factory must return { get: () -> T, set: (T) -> () }")
	end

	return setmetatable(refTable, {
		__index = function(_: unknown, k: unknown): unknown
			if k == REF_VALUE_KEY then
				return accessor.get()
			end
			return nil
		end,
		__newindex = function(_: unknown, k: unknown, v: unknown)
			if k == REF_VALUE_KEY then
				accessor.set(v :: T)
				return
			end
			rawset(refTable :: any, k, v)
		end,
	}) :: any
end

local function proxyRefs<T>(object: T): T
	local target = object :: any
	return setmetatable({}, {
		__index = function(_: unknown, key: unknown): unknown
			local value = target[key]
			if isRef(value) then
				return (value :: Ref<unknown>).value
			end
			return value
		end,
		__newindex = function(_: unknown, key: unknown, value: unknown)
			local current = target[key]
			if isRef(current) and not isRef(value) then
				(current :: Ref<unknown>).value = value
			else
				target[key] = value
			end
		end,
		__iter = function(_: unknown)
			local function iterate(_: unknown, key: unknown): (unknown, unknown)
				local nextKey, value = next(target, key)
				if isRef(value) then
					value = (value :: Ref<unknown>).value
				end
				return nextKey, value
			end
			return iterate, nil, nil
		end,
	}) :: any
end

local function triggerListChange(raw: RawTable, first: number, last: number, lengthChanged: boolean)
	local deps = depMap[raw]
	if not deps then
		return
	end
	-- One array operation is one change: an effect that read several of these keys runs once
	local firstKey: { [Effect]: unknown } = {}
	local order: { Effect } = {}
	local function collect(key: unknown)
		local dep = deps[key]
		if dep then
			for eff in dep do
				if firstKey[eff] == nil then
					firstKey[eff] = key
					table.insert(order, eff)
				end
			end
		end
	end
	for i = first, last do
		collect(i)
	end
	collect(ITERATE_KEY)
	if lengthChanged then
		collect(LENGTH_KEY)
	end
	for _, eff in order do
		dispatch(eff, raw, firstKey[eff])
	end
end

return {
	_setErrorHandling = setErrorHandling,
	_triggerListChange = triggerListChange,
	_untracked = untracked,

	reactive = reactive,
	shallowReactive = shallowReactive,
	ref = ref,
	shallowRef = shallowRef,
	readonly = readonly,
	shallowReadonly = shallowReadonly,

	computed = computed,

	watch = watch,
	watchEffect = watchEffect,
	watchPostEffect = watchPostEffect,
	watchSyncEffect = watchSyncEffect,
	onWatcherCleanup = onWatcherCleanup,
	effect = effect,

	isRef = isRef,
	isReactive = isReactive,
	isReadonly = isReadonly,
	isProxy = isProxy,
	isShallow = isShallow,

	proxyRefs = proxyRefs,
	unref = unref,
	toValue = toValue,
	toRef = toRef,
	toRefs = toRefs,
	toRaw = toRaw,

	markRaw = markRaw,
	triggerRef = triggerRef,
	customRef = customRef,

	effectScope = effectScope,
	getCurrentScope = getCurrentScope,
	onScopeDispose = onScopeDispose,
}
