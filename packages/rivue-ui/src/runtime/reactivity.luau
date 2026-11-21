--!strict
--!optimize 2
--!native
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

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
	_isRef: true,
	_value: unknown,
	_shallow: boolean?,
	_dep: Dep | false,
}

local scheduler = require("./scheduler")
local debugModule = require("./debug")
local utils = require("./utils")
local RunService = game:GetService("RunService")

const IS_STUDIO = RunService:IsStudio()

local function weakKeyed(): any
	return setmetatable({}, { __mode = "k" }) :: any
end

local depMap: { [unknown]: { [unknown]: Dep } } = weakKeyed()
local isDirty: (eff: Effect) -> boolean
local effectStack: { Effect } = {}
local activeEffect: Effect? = nil

const ITERATE_KEY = newproxy(false)
const LENGTH_KEY = "__len"
const REF_VALUE_KEY = "value"
const COMPUTED_KEY = "computed"

-- NaN ~= NaN in Luau, so compare like Object.is
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
		debugModule.safeCall("cleanup", cleanup)
	end

	table.clear(self.effects)
	table.clear(self.cleanups)
	table.clear(self.scopes)
end

local function scopePause(self: EffectScope)
	if not self.active then
		return
	end
	self.paused = true
	for _, childScope in table.clone(self.scopes) do
		childScope:pause()
	end
	for _, eff in self.effects do
		if not eff.computed then
			eff:pause()
		end
	end
end

local function scopeResume(self: EffectScope)
	if not self.active or not self.paused then
		return
	end
	self.paused = false
	for _, childScope in table.clone(self.scopes) do
		childScope:resume()
	end
	for _, eff in table.clone(self.effects) do
		if not eff.computed then
			eff:resume()
		end
	end
end

--- A detached scope isn't stopped with its parent scope
local function effectScope(detached: boolean?): EffectScope
	local scope: EffectScope = {
		active = true,
		paused = false,
		effects = {},
		cleanups = {},
		scopes = {},
		parent = if detached then nil else activeScope,
		run = scopeRun,
		stop = scopeStop,
		pause = scopePause,
		resume = scopeResume,
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

local function newDep(): Dep
	return { subs = {}, version = 0, refresh = nil }
end

const STALE = -1

-- A rerun keeps last run's deps linked, and drops only those it didn't read again
local function markDeps(eff: Effect)
	local seenVersions = eff.seenVersions
	for _, dep in eff.deps do
		seenVersions[dep] = STALE
	end
end

local function pruneDeps(eff: Effect)
	local deps, seenVersions = eff.deps, eff.seenVersions
	local count = #deps
	local kept = 0
	for i = 1, count do
		local dep = deps[i]
		if seenVersions[dep] == STALE then
			seenVersions[dep] = nil
			dep.subs[eff] = nil
		else
			kept += 1
			deps[kept] = dep
		end
	end
	for i = count, kept + 1, -1 do
		deps[i] = nil
	end
end

local errorOwner: () -> any = function()
	return nil
end
local reportError: (owner: any, err: string, info: string) -> () = function() end

local function setErrorHandling(getOwner: () -> any, report: (owner: any, err: string, info: string) -> ())
	errorOwner, reportError = getOwner, report
end

local function runEffectCleanups(cleanups: { () -> () })
	for _, cleanup in cleanups do
		local ok, err = pcall(cleanup :: () -> ...unknown)
		if not ok then
			warn(`[Rivue] Error in effect cleanup: {err}`)
		end
	end
end

local function schedule(eff: Effect)
	local effectScheduler = eff.scheduler
	if effectScheduler then
		effectScheduler(eff.runIfDirty)
	else
		scheduler.queueEffect(eff.job)
	end
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
		cleanups = nil :: { () -> () }?,
		paused = nil :: boolean?,
		pendingTrigger = nil :: boolean?,
		seenVersions = {} :: { [Dep]: number },
		evaluated = false,
		onStop = nil :: (() -> ())?,
	}
	local typedEffect: Effect = effect :: any

	function effect.run(): boolean
		if not effect.active then
			fn()
			return true
		end

		effect.evaluated = true
		local effectName = if utils.profiler.active then `effect_{effect}` else nil
		if effectName then
			utils.profiler:start(effectName)
		end

		local cleanups = effect.cleanups
		if cleanups then
			effect.cleanups = nil
			runEffectCleanups(cleanups)
		end
		markDeps(typedEffect)
		local depth = #effectStack
		effectStack[depth + 1] = typedEffect
		activeEffect = typedEffect
		local ok, err = pcall(fn :: () -> ...unknown)
		for i = #effectStack, depth + 1, -1 do
			effectStack[i] = nil
		end
		activeEffect = effectStack[depth]
		pruneDeps(typedEffect)

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
		return true
	end

	function effect.runIfDirty(): boolean
		if not effect.active then
			return false
		end
		if effect.evaluated and not isDirty(typedEffect) then
			return false
		end
		effect.run()
		return true
	end

	local function job()
		effect.runIfDirty()
	end
	effect.job = job

	function effect.pause(self: Effect)
		self.paused = true
	end

	function effect.resume(self: Effect)
		if not self.paused then
			return
		end
		self.paused = nil
		if self.pendingTrigger and self.active then
			self.pendingTrigger = nil
			schedule(self)
		end
	end

	function effect.stop(self: Effect)
		if not self.active then
			return
		end
		self.active = false
		self.pendingTrigger = nil
		for _, dep in self.deps do
			dep.subs[self] = nil
		end
		table.clear(self.deps)
		table.clear(self.seenVersions)
		local cleanups = self.cleanups
		if cleanups then
			self.cleanups = nil
			runEffectCleanups(cleanups)
		end
		local onStop = self.onStop
		if onStop then
			onStop()
		end
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
	local seenVersions = current.seenVersions
	local previous = seenVersions[dep]
	seenVersions[dep] = dep.version
	if previous == nil then
		dep.subs[current] = true
		local deps = current.deps
		deps[#deps + 1] = dep
	end
	if previous == nil or previous == STALE then
		local onTrack = current.onTrack
		if onTrack then
			onTrack({ target = target, key = key })
		end
	end
end

local function track(target: unknown, key: unknown): Dep?
	local current = activeEffect
	if not current then
		return nil
	end
	local deps = depMap[target]
	if not deps then
		deps = {}
		depMap[target] = deps
	end
	local dep = deps[key]
	if not dep then
		dep = newDep()
		deps[key] = dep
	end
	trackDep(dep, current, target, key)
	return dep
end

-- In Immediate signal mode, handlers fired by engine calls here would become render deps
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
	if not eff.active or (eff == activeEffect and not eff.allowRecurse) then
		return
	end
	if eff.paused then
		eff.pendingTrigger = true
		return
	end
	local onTrigger = eff.onTrigger
	if onTrigger then
		onTrigger({ target = target, key = key })
	end
	schedule(eff)
end

local function bumpDep(dep: Dep)
	dep.version += 1
end

local function notifyDep(dep: Dep, target: unknown, key: unknown)
	triggerDepth += 1
	local effects = triggerScratch[triggerDepth]
	if not effects then
		effects = {}
		triggerScratch[triggerDepth] = effects
	end
	local count = 0
	for eff in dep.subs do
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

local function triggerDep(dep: Dep, target: unknown, key: unknown)
	bumpDep(dep)
	notifyDep(dep, target, key)
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
	assert(type(target) == "table", "[Rivue] reactive() expects a table")
	local tbl: RawTable = target :: any
	if rawMarker[tbl] or reactiveMarker[tbl] or readonlyMarker[tbl] then
		return target :: any
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
		local v: any = tbl[k]
		if type(v) == "table" then
			local cachedProxy = proxyCache[v]
			if cachedProxy then
				return cachedProxy
			elseif not rawMarker[v] then
				return reactive(v)
			end
		end
		return v
	end
	function mt.__newindex(_: RawTable, k: unknown, v: unknown)
		v = toRaw(v)
		local old = tbl[k]
		tbl[k] = v
		if hasChanged(old, v) then
			triggerSet(tbl, k, old, v)
		end
	end
	-- Luau has no __pairs: loop with `for k, v in proxy do`
	function mt.__iter(_: RawTable)
		track(tbl, ITERATE_KEY)
		return function(_: RawTable, k: unknown): (unknown, unknown)
			local nk, nv = next(tbl, k)
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
	assert(type(target) == "table", "[Rivue] shallowReactive() expects a table")
	local tbl: RawTable = target :: any
	if rawMarker[tbl] or reactiveMarker[tbl] or readonlyMarker[tbl] then
		return target :: any
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

function RefMT.__index(self: RefInternal, k: unknown): unknown
	if k == REF_VALUE_KEY then
		local current = activeEffect
		if current then
			local dep = self._dep
			if dep == false then
				local created: Dep = newDep()
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
	local r: RefInternal = { _isRef = true, _value = wrapped, _dep = false }
	return setmetatable(r :: any, RefMT) :: any
end

local function shallowRef<T>(initial: T): Ref<T>
	local r: RefInternal = { _isRef = true, _value = initial, _shallow = true, _dep = false }
	return setmetatable(r :: any, RefMT) :: any
end

local function isRef(r: unknown): boolean
	return type(r) == "table" and (r :: any)._isRef == true
end

local function unref<T>(r: MaybeRef<T>): T
	return if isRef(r) then (r :: Ref<T>).value else r :: T
end

const PROTECTED_COMPUTED_DEPTH = 16
local computedDepth = 0
-- True while a computed tells its readers it may have changed
local notifyingFromComputed = false

isDirty = function(eff: Effect): boolean
	local seenVersions = eff.seenVersions
	for _, dep in eff.deps do
		local seen = seenVersions[dep] or 0
		local refresh = dep.refresh
		if refresh then
			if computedDepth < PROTECTED_COMPUTED_DEPTH then
				computedDepth += 1
				local ok = pcall(refresh)
				computedDepth -= 1
				if not ok then
					return true
				end
			else
				refresh()
			end
		end
		if dep.version ~= seen then
			return true
		end
	end
	return false
end

local function computed<T>(getterOrOptions: ((previous: T?) -> T) | WritableComputedOptions<T>): ComputedRef<T>
	local getter: (previous: T?) -> T
	local setter: ((T) -> ())? = nil
	if type(getterOrOptions) == "function" then
		getter = getterOrOptions
	elseif type(getterOrOptions) == "table" and type(getterOrOptions.get) == "function" then
		getter = getterOrOptions.get
		setter = getterOrOptions.set
	else
		error("[Rivue] computed() expects a getter or { get, set }", 2)
	end

	local dirty = true
	-- A ref or reactive table this computed reads changed, so skip the version check
	local surelyDirty = false
	local evaluatedOnce = false
	local lastFailed = false
	local value: T
	local runner: Effect
	local ownDep = newDep()
	runner = createEffect(function()
		value = getter(value)
	end, {
		lazy = true,
		scheduler = function()
			if not notifyingFromComputed then
				surelyDirty = true
			end
			if dirty then
				return
			end
			dirty = true
			local previous = notifyingFromComputed
			notifyingFromComputed = true
			notifyDep(ownDep, runner, COMPUTED_KEY)
			notifyingFromComputed = previous
		end,
	})

	runner.computed = true

	local function evaluate()
		if not runner.active then
			value = getter(value)
			return
		end
		local cleanups = runner.cleanups
		if cleanups then
			runner.cleanups = nil
			runEffectCleanups(cleanups)
		end
		markDeps(runner)
		local depth = #effectStack
		effectStack[depth + 1] = runner
		activeEffect = runner
		-- Luau allows about 200 nested C calls, so deeper levels skip the pcall
		if computedDepth >= PROTECTED_COMPUTED_DEPTH then
			value = getter(value)
			effectStack[depth + 1] = nil
			activeEffect = effectStack[depth]
			pruneDeps(runner)
			return
		end
		computedDepth += 1
		local ok, result = pcall(getter :: (T?) -> ...unknown, value)
		computedDepth -= 1
		for i = #effectStack, depth + 1, -1 do
			effectStack[i] = nil
		end
		activeEffect = effectStack[depth]
		pruneDeps(runner)
		if not ok then
			error(result, 0)
		end
		value = result :: T
	end

	local function refresh()
		if not dirty then
			return
		end
		local sure = surelyDirty
		surelyDirty = false
		if evaluatedOnce and not lastFailed and not sure and not isDirty(runner) then
			dirty = false
			return
		end
		local previous = value
		local first = not evaluatedOnce
		lastFailed = true
		evaluate()
		lastFailed = false
		evaluatedOnce = true
		dirty = false
		if first or hasChanged(value, previous) then
			ownDep.version += 1
		end
	end

	ownDep.refresh = refresh

	local function get(): T
		refresh()
		local current = activeEffect
		if current then
			trackDep(ownDep, current, runner, COMPUTED_KEY)
		end
		return value
	end

	local obj = { _isRef = true, get = get }
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
	local r = { _isRef = true }
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
		return value :: any
	end
	seenTables[value] = true
	local proxyOrRaw: RawTable = value :: any
	local raw = toRaw(proxyOrRaw)
	if raw ~= proxyOrRaw then
		track(raw, ITERATE_KEY)
	end
	for k in raw do
		_traverse(proxyOrRaw[k], seenTables, remaining - 1)
	end
	return value :: any
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
local activeWatcher: Effect? = nil

local function getCurrentWatcher(): Effect?
	return activeWatcher
end

local function onWatcherCleanup(fn: () -> (), failSilently: boolean?)
	local register = activeWatcherCleanup
	if register then
		register(fn)
	elseif not failSilently then
		warn("[Rivue] onWatcherCleanup() was called outside a watcher callback")
	end
end

local function onEffectCleanup(fn: () -> (), failSilently: boolean?)
	local register = activeWatcherCleanup
	if register then
		register(fn)
		return
	end
	local eff = activeEffect
	if eff then
		local cleanups: { () -> () } = eff.cleanups or {}
		eff.cleanups = cleanups
		table.insert(cleanups, fn)
	elseif not failSilently then
		warn("[Rivue] onEffectCleanup() was called outside an effect")
	end
end

local function watch<T>(source: WatchSource<T> | { [any]: any }, cb: WatchCallback<T>, opts: WatchOptions?): WatchHandle
	local options: WatchOptions = opts or {}
	local deepOption = options.deep
	local deep = deepOption == true or (type(deepOption) == "number" and deepOption > 0)
	local deepLevels: number? = if type(deepOption) == "number" then deepOption else nil
	local isMultiSource = false
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
		deep = deepOption ~= false and deepOption ~= 0
		getter = function(): T
			return source :: any
		end
	elseif type(source) == "table" and isMultiSourceList(source :: any) then
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
			return source :: any
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
			debugModule.safeCall("cleanup", cleanup)
		end
		table.clear(cleanups)
	end

	local currentValue: T

	local stop: () -> ()
	local eff: Effect

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
			local prevWatcher = activeWatcher
			activeWatcherCleanup = onCleanup
			activeWatcher = eff
			local ok, err = pcall(cb :: (T, T?, OnCleanup) -> ...unknown, new, old, onCleanup)
			activeWatcherCleanup = prevCleanup
			activeWatcher = prevWatcher
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

	local function onTrigger(run: () -> boolean)
		if not run() then
			return
		end

		if flushMode == "sync" then
			local ok, err = pcall(job :: () -> ...unknown)
			if not ok then
				warn(`[Rivue] Error in sync watcher: {err}`)
			end
		elseif flushMode == "post" then
			scheduler.queueJob(job, { mode = "heartbeat" })
		else
			scheduler.queueEffect(job)
		end
	end

	eff = createEffect(
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
	eff.onStop = function()
		stopped = true
		runCleanups()
	end
	stop = function()
		eff:stop()
	end

	eff.run()
	job()

	return createWatchHandle(stop, function()
		eff:pause()
	end, function()
		eff:resume()
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
			debugModule.safeCall("cleanup", cleanup)
		end
		table.clear(cleanups)
	end

	local eff: Effect
	local owner = errorOwner()
	local function onTrigger(run: () -> boolean)
		if flushMode == "sync" then
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
			local prevWatcher = activeWatcher
			activeWatcherCleanup = onCleanup
			activeWatcher = eff
			local ok, err = pcall(fn :: (OnCleanup) -> ...unknown, onCleanup)
			activeWatcherCleanup = prevCleanup
			activeWatcher = prevWatcher
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
	eff.onStop = runCleanups
	eff.run()
	return createWatchHandle(function()
		eff:stop()
	end, function()
		eff:pause()
	end, function()
		eff:resume()
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
	local tbl: RawTable = reactiveMarker[source] or source

	local proxy: RawTable = {}

	readonlyMarker[proxy] = true
	reactiveMarker[proxy] = source
	if shallow then
		shallowMarker[proxy] = true
	end
	cache[source] = proxy

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
	local refTable = { _isRef = true }

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
				local value = accessor.get()
				rawset(refTable :: any, "_value", value)
				return value
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

local function triggerListChange(raw: { [any]: any }, first: number, last: number, lengthChanged: boolean)
	local deps = depMap[raw]
	if not deps then
		return
	end
	local firstKey: { [Effect]: unknown } = {}
	local order: { Effect } = {}
	local function collect(key: unknown)
		local dep = deps[key]
		if dep then
			bumpDep(dep)
			for eff in dep.subs do
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
	getCurrentWatcher = getCurrentWatcher,
	onEffectCleanup = onEffectCleanup,
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
