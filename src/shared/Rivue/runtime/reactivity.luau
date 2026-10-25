--!strict
--!optimize 2
--!native

--[[
	Reactivity.luau
    ===============

	Provides reactive state management with automatic dependency tracking.
	Implements a Vue 3-inspired reactivity system for Roblox.

	@module reactivity

	@author Rivue

	@version 1.0.0
]]

local Types = require(script.Parent:WaitForChild("types"))

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
type WatchStopHandle = Types.WatchStopHandle
type CustomRefFactory<T> = Types.CustomRefFactory<T>

type RawTable = { [unknown]: unknown }
-- Internal ref fields (public type only has .value)
type RefInternal = {
	_is_ref: true,
	_value: unknown,
	_shallow: boolean?,
}

-- Module imports
local scheduler = require(script.Parent:WaitForChild("scheduler"))
local debugModule = require(script.Parent:WaitForChild("debug"))
local utils = require(script.Parent:WaitForChild("utils"))
local RunService = game:GetService("RunService")

const IS_STUDIO = RunService:IsStudio()

--- Creates a weak-keyed table
--- @return { [K]: V } -- Empty weak-keyed table
local function weakKeyed<K, V>(): { [K]: V }
	return setmetatable({}, { __mode = "k" }) :: any
end

-- Weak keys: a target nobody references can't be triggered anymore
local depMap: { [unknown]: { [unknown]: Dep } } = weakKeyed()
local effectStack: { Effect } = {}
local activeEffect: Effect? = nil

-- Keys for structural changes (keys added/removed, length)
const ITERATE_KEY = newproxy(false)
const LENGTH_KEY = "__len"
const REF_VALUE_KEY = "value"
const COMPUTED_KEY = "computed"

local scopeStack: { EffectScope } = {}
local activeScope: EffectScope? = nil

--- Runs fn inside the scope so its effects get collected
--- @param self EffectScope -- Scope to activate
--- @param fn () -> unknown -- Function to run
--- @return unknown -- fn's result, or nil if the scope is inactive or fn errored
local function scopeRun(self: EffectScope, fn: () -> unknown): unknown
	if not self.active then
		debugModule.log("Reactivity", "Cannot run() on inactive effect scope")
		return nil
	end

	-- Push this scope onto the stack
	table.insert(scopeStack, self)
	activeScope = self

	local ok, result = pcall(fn)

	-- Pop the scope
	table.remove(scopeStack)
	activeScope = scopeStack[#scopeStack]

	if not ok then
		debugModule.log("Reactivity", "Error in effect scope", { error = result })
		return nil
	end

	return result
end

--- Stops child scopes, effects, then runs cleanups
--- @param self EffectScope -- Scope to stop
local function scopeStop(self: EffectScope)
	if not self.active then
		return
	end

	self.active = false

	-- Stop all child scopes first
	for _, childScope in self.scopes do
		childScope:stop()
	end

	-- Stop all effects in this scope
	for _, eff in self.effects do
		eff:stop()
	end

	-- Run all cleanup callbacks
	for _, cleanup in self.cleanups do
		pcall(cleanup)
	end

	table.clear(self.effects)
	table.clear(self.cleanups)
	table.clear(self.scopes)
end

--- Creates an effect scope for grouping effects and enabling batch cleanup
--- Useful for plugin systems, composable lifecycle management
--- @param detached boolean? -- If true, scope won't be collected by parent scope
--- @return EffectScope -- Effect scope object with run() and stop() methods
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

	-- Register with parent scope if not detached
	local parent = scope.parent
	if parent then
		table.insert(parent.scopes, scope)
	end

	return scope
end

--- Returns the currently active effect scope (or nil if none)
--- @return EffectScope? -- Current scope or nil
local function getCurrentScope(): EffectScope?
	return activeScope
end

--- Registers a cleanup callback on the current active effect scope
--- Called when the scope is stopped (e.g., component unmount)
--- @param fn () -> () -- Cleanup callback
--- @param failSilently boolean? -- If true, don't warn when no active scope (default: false)
local function onScopeDispose(fn: () -> (), failSilently: boolean?)
	if not activeScope then
		if not failSilently and IS_STUDIO then
			debugModule.log("Reactivity", "onScopeDispose called without an active effect scope")
		end
		return
	end

	table.insert(activeScope.cleanups, fn)
end

-- Reactivity markers (stored with weak keys to avoid memory leaks)
local rawMarker: { [unknown]: true } = weakKeyed()
local reactiveMarker: { [unknown]: RawTable } = weakKeyed()
local readonlyMarker: { [unknown]: true } = weakKeyed()
local shallowMarker: { [unknown]: true } = weakKeyed()

--- Marks an object as raw (non-reactive)
--- Prevents the object from being converted to a reactive proxy
--- @param obj T -- Object to mark as raw
--- @return T -- The same object, now marked as raw
local function markRaw<T>(obj: T): T
	if type(obj) == "table" then
		rawMarker[obj] = true
	end
	return obj
end

--- Unwraps a proxy to get the original object
--- Returns the original non-proxy object from reactive/readonly/shallow proxies
--- @param obj T -- Proxy or raw object
--- @return T -- Original object (non-proxy)
local function toRaw<T>(obj: T): T
	local original = reactiveMarker[obj]
	if original then
		return original :: any
	end
	-- Otherwise return as-is (already raw or primitive)
	return obj
end

--- Checks if a value is a reactive proxy (created by reactive or shallowReactive)
--- @param value unknown -- Value to check
--- @return boolean -- True if value is a reactive proxy
local function isReactive(value: unknown): boolean
	return type(value) == "table" and reactiveMarker[value] ~= nil
end

--- Checks if a value is a readonly proxy
--- @param value unknown -- Value to check
--- @return boolean -- True if value is readonly
local function isReadonly(value: unknown): boolean
	return type(value) == "table" and readonlyMarker[value] == true
end

--- Checks if a value is a proxy (reactive or readonly)
--- @param value unknown -- Value to check
--- @return boolean -- True if value is any kind of proxy
local function isProxy(value: unknown): boolean
	return isReactive(value) or isReadonly(value)
end

--- Checks if a value should be wrapped in a proxy
--- @param value unknown -- Value read from a raw table
--- @return boolean -- True for non-raw tables
local function shouldWrap(value: unknown): boolean
	return type(value) == "table" and not rawMarker[value]
end

--- Creates a reactive effect that tracks dependencies and re-runs on changes
--- @param fn () -> () -- Effect function to execute
--- @param opts EffectOptions? -- Optional scheduler and lazy execution settings
--- @return Effect -- Effect object with run and stop methods
local function createEffect(fn: () -> (), opts: EffectOptions?): Effect
	local options: EffectOptions = opts or {}
	local effect = {
		fn = fn,
		scheduler = options.scheduler,
		deps = {} :: { Dep },
		active = true,
	}
	local typedEffect: Effect = effect :: any

	function effect.run()
		if not effect.active then
			fn()
			return
		end

		-- Profile effect execution for performance monitoring
		local effectName = if utils.profiler.active then "effect_" .. tostring(effect) else nil
		if effectName then
			utils.profiler:start(effectName)
		end

		-- This ensures fresh dependency tracking on each execution (Vue 3 pattern)
		for _, dep in effect.deps do
			dep[typedEffect] = nil
		end
		table.clear(effect.deps)

		table.insert(effectStack, typedEffect)
		activeEffect = typedEffect
		local ok, err = pcall(fn :: () -> ...unknown)
		table.remove(effectStack)
		activeEffect = effectStack[#effectStack]

		if effectName then
			utils.profiler:stop(effectName)
		end

		if not ok then
			debugModule.log("Reactivity", "Reactive effect error", { error = err })
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

	-- Register effect with current scope (if any)
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

--- Tracks access to a property for reactive dependency collection
--- @param target unknown -- Object being accessed
--- @param key unknown -- Property key being accessed
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
		table.insert(current.deps, dep)
	end
end

local triggerScratch: { { Effect } } = {}
local triggerDepth = 0

--- Triggers all effects that depend on a property
--- @param target unknown -- Object that changed
--- @param key unknown -- Property key that changed
local function trigger(target: unknown, key: unknown)
	local deps = depMap[target]
	if not deps then
		return
	end
	local dep = deps[key]
	if not dep then
		return
	end
	-- Copy first, sync effects modify dep while we iterate. Scratch arrays are reused per
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
		if not eff.active then
			continue
		end
		local effectScheduler = eff.scheduler
		if effectScheduler then
			effectScheduler(eff.run)
		else
			scheduler.queueEffect(eff.job)
		end
	end
	triggerDepth -= 1
end

--- Triggers a key, plus length/iteration when a key is added or removed
--- @param target RawTable -- Raw object that changed
--- @param key unknown -- Property key that changed
--- @param old unknown -- Previous value
--- @param new unknown -- New value
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

--- Creates a deeply reactive proxy of an object.
---  All nested objects are automatically made reactive
--- @param target T -- Table to make reactive
--- @return T -- Reactive proxy of the table
local function reactive<T>(target: T): T
	assert(type(target) == "table", "reactive expects a table")
	local tbl: RawTable = target :: any
	if rawMarker[tbl] then
		return target
	end
	local cached = proxyCache[tbl]
	if cached then
		return cached :: any
	end

	local proxy: RawTable = {}

	-- Store reference to original object for toRaw()
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
		if old ~= v then
			triggerSet(tbl, k, old, v)
		end
	end
	-- Luau ignores __pairs/__ipairs, use `for k, v in proxy do` or `for i = 1, #proxy do`
	function mt.__iter(_: RawTable)
		track(tbl, ITERATE_KEY)
		return function(_: RawTable, k: unknown): (unknown, unknown)
			local nk, nv = next(tbl, k)
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
		-- In dev mode, show a helpful representation
		return if IS_STUDIO then "<Reactive Proxy>" else tostring(tbl)
	end
	setmetatable(proxy :: any, mt)
	proxyCache[tbl] = proxy
	return proxy :: any
end

--- Creates a shallow reactive proxy (only top-level properties are reactive)
--- @param target T -- Table to make shallow reactive
--- @return T -- Shallow reactive proxy
local function shallowReactive<T>(target: T): T
	assert(type(target) == "table", "shallowReactive expects a table")
	local tbl: RawTable = target :: any
	if rawMarker[tbl] then
		return target
	end
	local cached = shallowProxyCache[tbl]
	if cached then
		return cached :: any
	end

	local proxy: RawTable = {}

	-- Mark as reactive for isReactive() check
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
		if old ~= v then
			triggerSet(tbl, k, old, v)
		end
	end
	function mt.__iter(_: RawTable)
		track(tbl, ITERATE_KEY)
		return next, tbl
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

-- Shared metatable for all refs, value lives in _value
local RefMT = {}

function RefMT.__index(self: RefInternal, k: unknown): unknown
	if k == REF_VALUE_KEY then
		track(self, REF_VALUE_KEY)
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
	-- Auto-wrap new table values in reactive() (not for shallowRef)
	local newValue = if not self._shallow and shouldWrap(v) then reactive(v) else v
	self._value = newValue
	if old ~= newValue then
		trigger(self, REF_VALUE_KEY)
	end
end

function RefMT.__tostring(self: RefInternal): string
	return if IS_STUDIO then `<Ref: {self._value}>` else tostring(self._value)
end

table.freeze(RefMT)

--- Creates a reactive reference to a value
--- @param initial T -- Initial value
--- @return Ref<T> -- Reactive reference with .value property
local function ref<T>(initial: T): Ref<T>
	local wrapped: unknown = if shouldWrap(initial) then reactive(initial) else initial
	local r: RefInternal = { _is_ref = true, _value = wrapped }
	return setmetatable(r :: any, RefMT)
end

--- Creates a shallow reactive reference (doesn't auto-wrap objects)
--- @param initial T -- Initial value
--- @return Ref<T> -- Shallow reactive reference with .value property
local function shallowRef<T>(initial: T): Ref<T>
	local r: RefInternal = { _is_ref = true, _value = initial, _shallow = true }
	return setmetatable(r :: any, RefMT)
end

--- Checks if a value is a Ref
--- @param r unknown -- Value to check
--- @return boolean -- True if value is a Ref
local function isRef(r: unknown): boolean
	return type(r) == "table" and (r :: any)._is_ref == true
end

--- Unwraps a Ref to get its value, or returns the value as-is
--- @param r MaybeRef<T> -- Ref or plain value
--- @return T -- Unwrapped value
local function unref<T>(r: MaybeRef<T>): T
	return if isRef(r) then (r :: Ref<T>).value else r :: T
end

--- Creates a computed value that caches the result and only re-computes when dependencies change
--- Pass { get, set } for a writable computed.
--- @param getterOrOptions (() -> T) | WritableComputedOptions<T> -- Getter, or get/set pair
--- @return ComputedRef<T> -- Computed reference with cached .value property
local function computed<T>(getterOrOptions: (() -> T) | WritableComputedOptions<T>): ComputedRef<T>
	local getter: () -> T
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
		value = getter()
	end, {
		lazy = true,
		scheduler = function()
			if not dirty then
				dirty = true
				trigger(runner, COMPUTED_KEY)
			end
		end,
	})

	local function get(): T
		if dirty then
			runner.run()
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

--- Creates a Ref that's linked to a property on a reactive object
--- @param obj { [K]: V } -- Source reactive object
--- @param key K -- Property key to link
--- @return Ref<V> -- Ref linked to the property
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
				if old ~= v then
					trigger(obj, key)
				end
				return
			end
			rawset(r :: any, k, v)
		end,
	})
	return r :: any
end

--- Converts all properties of a reactive object to Refs
--- @param obj { [K]: V } -- Reactive object to convert
--- @return { [K]: Ref<V> } -- Table of Refs for each property
local function toRefs<K, V>(obj: { [K]: V }): { [K]: Ref<V> }
	local res: { [K]: Ref<V> } = {}
	-- Get the raw object to iterate over
	for k in toRaw(obj) do
		res[k] = toRef(obj, k)
	end
	return res
end

--- Deeply traverses an object to trigger all reactive dependencies (for deep watching)
--- @param value T -- Value to traverse
--- @param seen { [unknown]: true }? -- Set of already-seen tables to prevent infinite loops
--- @return T -- The traversed value
local function _traverse<T>(value: T, seen: { [unknown]: true }?): T
	if type(value) ~= "table" then
		return value
	end
	local seenTables: { [unknown]: true } = seen or {}
	if seenTables[value] then
		return value
	end
	seenTables[value] = true
	local proxyOrRaw: RawTable = value :: any
	-- Read through the proxy so nested keys get tracked
	for k in toRaw(proxyOrRaw) do
		_traverse(proxyOrRaw[k], seenTables)
	end
	return value
end

--- Reads a single watch source (ref, getter, or reactive object)
--- @param item unknown -- Source
--- @return unknown -- Current value
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

--- Checks if a table is a list of watch sources (refs, getters, reactive objects)
--- @param list { [unknown]: unknown } -- Candidate
--- @return boolean -- True for a non-empty array of sources
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

--- Compares two arrays element by element
--- @param a { unknown }? -- First array
--- @param b { unknown }? -- Second array
--- @return boolean -- True if same length and elements
local function arrayShallowEqual(a: { unknown }?, b: { unknown }?): boolean
	if a == nil or b == nil then
		return a == b
	end
	if #a ~= #b then
		return false
	end
	for i, v in a do
		if b[i] ~= v then
			return false
		end
	end
	return true
end

--- Watches a reactive source and executes callback when it changes
--- @param source WatchSource<T> -- Reactive source to watch (getter function, Ref, or reactive object)
--- @param cb WatchCallback<T> -- Callback (newValue, oldValue, onCleanup) => void
--- @param opts WatchOptions? -- Options: immediate (run immediately), deep (traverse nested objects), flush
--- @return WatchStopHandle -- Function to stop watching
local function watch<T>(source: WatchSource<T> | T, cb: WatchCallback<T>, opts: WatchOptions?): WatchStopHandle
	local options: WatchOptions = opts or {}
	local deep = options.deep == true
	local isMultiSource = false
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
		deep = options.deep ~= false
		getter = function(): T
			return source :: T
		end
	elseif type(source) == "table" and isMultiSourceList(source) then
		isMultiSource = true
		local sources = source :: { unknown }
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
	local flushMode = options.flush or "pre" -- Default to "pre" (before component updates)

	local function runCleanups()
		for _, cleanup in cleanups do
			pcall(cleanup)
		end
		table.clear(cleanups)
	end

	-- Set by the effect so the getter only runs once per change
	local currentValue: T

	local stop: WatchStopHandle

	local function hasChanged(new: T): boolean
		-- Deep watchers fire even if the table is the same
		if deep then
			return true
		elseif isMultiSource then
			return not arrayShallowEqual(new :: any, oldValue :: any)
		end
		return new ~= oldValue
	end

	local stopped = false

	local function job()
		if stopped then
			return
		end
		local new = currentValue
		if initialized and not hasChanged(new) then
			return
		end
		local shouldCall = initialized or immediate
		initialized = true
		local old = oldValue
		oldValue = new
		if shouldCall then
			runCleanups()
			cb(new, old, onCleanup)
			if options.once then
				stop()
			end
		end
	end

	local eff = createEffect(function()
		currentValue = getter()
		if deep then
			_traverse(currentValue, nil)
		end
	end, {
		-- Lazy, run manually below
		lazy = true,
		scheduler = function(run)
			-- Refresh dependencies, then run the callback based on flush mode
			run()

			if flushMode == "sync" then
				job()
			elseif flushMode == "post" then
				-- Execute after render (heartbeat mode)
				scheduler.queueJob(job, { mode = "heartbeat" })
			else
				-- Execute before render (default - micro mode)
				scheduler.queueJob(job, { mode = "micro" })
			end
		end,
	})
	stop = function()
		stopped = true
		eff:stop()
		runCleanups()
	end

	-- Collect dependencies and store the initial value
	eff.run()
	job()

	return stop
end

--- Creates and runs a reactive effect
--- @param fn () -> () -- Effect function to execute
--- @param opts EffectOptions? -- Options: scheduler (custom scheduler), lazy (don't run immediately)
--- @return Effect -- Effect object with stop method
local function effect(fn: () -> (), opts: EffectOptions?): Effect
	return createEffect(fn, opts)
end

--- Runs a reactive effect with automatic dependency tracking and immediate execution
--- Simpler alternative to watch() when you don't need the old/new value comparison
--- @param fn () -> () -- Effect function to execute (dependencies are auto-tracked)
--- @param opts WatchOptions? -- flush: "pre" (default, deferred), "post" (Heartbeat), "sync"
--- @return WatchStopHandle -- Function to stop the effect
local function watchEffect(fn: () -> (), opts: WatchOptions?): WatchStopHandle
	local flushMode = if opts then opts.flush else nil
	local eff: Effect
	local effectScheduler: EffectScheduler? = nil
	if flushMode == "sync" then
		effectScheduler = function(run)
			run()
		end
	elseif flushMode == "post" then
		effectScheduler = function()
			scheduler.queueJob(eff.job, { mode = "heartbeat" })
		end
	end
	eff = createEffect(fn, { lazy = true, scheduler = effectScheduler })
	-- Run now so dependencies are tracked
	eff.run()
	return function()
		eff:stop()
	end
end

--- watchEffect() that re-runs on Heartbeat (after renders)
--- @param fn () -> () -- Effect function
--- @return WatchStopHandle -- Stop handle
local function watchPostEffect(fn: () -> ()): WatchStopHandle
	return watchEffect(fn, { flush = "post" })
end

--- watchEffect() that re-runs immediately on every change
--- @param fn () -> () -- Effect function
--- @return WatchStopHandle -- Stop handle
local function watchSyncEffect(fn: () -> ()): WatchStopHandle
	return watchEffect(fn, { flush = "sync" })
end

--- Creates a readonly proxy (nested tables are readonly too unless shallow)
--- @param target T -- Object to wrap
--- @param shallow boolean -- Only the top level is readonly
--- @return T -- Readonly proxy
local function createReadonly<T>(target: T, shallow: boolean): T
	if type(target) ~= "table" or rawMarker[target] then
		return target
	end

	local tbl: RawTable = target :: any
	local cache = if shallow then shallowReadonlyCache else readonlyCache
	local cached = cache[tbl]
	if cached then
		return cached :: any
	end

	local proxy: RawTable = {}

	-- Mark as readonly, store original for toRaw()
	readonlyMarker[proxy] = true
	reactiveMarker[proxy] = tbl
	if shallow then
		shallowMarker[proxy] = true
	end
	cache[tbl] = proxy

	local function wrap(v: unknown): unknown
		return if not shallow and shouldWrap(v) then createReadonly(v, false) else v
	end

	setmetatable(proxy :: any, {
		__index = function(_: RawTable, k: unknown): unknown
			track(tbl, k)
			return wrap(tbl[k])
		end,
		__newindex = function(_: RawTable, k: unknown, _v: unknown)
			-- Prevent mutations in dev mode
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
				return nk, wrap(nv)
			end,
				proxy,
				nil
		end,
	})

	return proxy :: any
end

--- Creates a readonly reactive proxy that warns on mutation attempts
--- Useful for enforcing one-way data flow (props, injected state, public APIs)
--- @param target T -- Object to make readonly
--- @return T -- Readonly reactive proxy
local function readonly<T>(target: T): T
	return createReadonly(target, false)
end

--- Like readonly(), but nested tables stay as they are
--- @param target T -- Object to make readonly
--- @return T -- Shallow readonly proxy
local function shallowReadonly<T>(target: T): T
	return createReadonly(target, true)
end

--- Checks if a value is a shallow ref or shallow proxy
--- @param value unknown -- Value to check
--- @return boolean -- True for shallowRef/shallowReactive/shallowReadonly
local function isShallow(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	return shallowMarker[value] == true or (isRef(value) and rawget(value :: any, "_shallow") == true)
end

--- Normalizes a ref, getter, or plain value to a value
--- @param source MaybeRef<T> | () -> T -- Ref, getter, or value
--- @return T -- Value
local function toValue<T>(source: MaybeRef<T> | () -> T): T
	if type(source) == "function" then
		return (source :: () -> T)()
	end
	return unref(source :: MaybeRef<T>)
end

--- Manually triggers effects that depend on a shallowRef
--- Useful when you mutate the internal value of a shallowRef without replacing .value
--- @param refObj Ref<T> -- ShallowRef to trigger
local function triggerRef<T>(refObj: Ref<T>)
	if not isRef(refObj) then
		if IS_STUDIO then
			debugModule.log("Reactivity", "triggerRef expects a ref object", { type = type(refObj) })
		end
		return
	end

	trigger(refObj, REF_VALUE_KEY)
end

--- Creates a customized ref with explicit control over dependency tracking and updates
--- Useful for debounced inputs, validation, custom state sync, etc.
--- @param factory CustomRefFactory<T> -- Receives track/trigger, returns { get, set }
--- @return Ref<T> -- Custom ref with manual tracking control
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

return {
	-- Core reactive primitives
	reactive = reactive,
	shallowReactive = shallowReactive,
	ref = ref,
	shallowRef = shallowRef,
	readonly = readonly,
	shallowReadonly = shallowReadonly,

	-- Computed values
	computed = computed,

	-- Watchers and effects
	watch = watch,
	watchEffect = watchEffect,
	watchPostEffect = watchPostEffect,
	watchSyncEffect = watchSyncEffect,
	effect = effect,

	-- Type checking utilities
	isRef = isRef,
	isReactive = isReactive,
	isReadonly = isReadonly,
	isProxy = isProxy,
	isShallow = isShallow,

	-- Conversion utilities
	unref = unref,
	toValue = toValue,
	toRef = toRef,
	toRefs = toRefs,
	toRaw = toRaw,

	-- Advanced features
	markRaw = markRaw,
	triggerRef = triggerRef,
	customRef = customRef,

	-- Effect scope system
	effectScope = effectScope,
	getCurrentScope = getCurrentScope,
	onScopeDispose = onScopeDispose,
}
