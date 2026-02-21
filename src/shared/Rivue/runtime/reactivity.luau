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

-- Type definitions
type EffectScheduler = (fn: () -> ()) -> ()

type EffectOptions = {
	scheduler: EffectScheduler?,
	lazy: boolean?,
}

type Dep = { [Effect]: boolean }

type Effect = {
	fn: (...any) -> ...any,
	scheduler: EffectScheduler?,
	deps: { Dep },
	active: boolean,
	run: (...any) -> ...any,
	stop: (self: Effect) -> (),
}

type Ref<T> = {
	_is_ref: boolean,
	value: T,
}

type ComputedRef<T> = {
	get: () -> T,
	value: T,
}

type WatchCallback = (newValue: any, oldValue: any, onCleanup: (fn: () -> ()) -> ()) -> ()

type WatchOptions = {
	immediate: boolean?,
	deep: boolean?,
	flush: ("pre" | "post" | "sync")?, -- Flush timing: "pre" (before render), "post" (after render), "sync" (immediate)
}

type WatchStopHandle = () -> ()

-- Module imports
local scheduler = require(script.Parent:WaitForChild("scheduler")) :: any
local debugModule = require(script.Parent:WaitForChild("debug"))
local utils = require(script.Parent:WaitForChild("utils"))
local RunService = game:GetService("RunService")

-- CRITICAL: Do NOT use weak keys for depMap - the raw table must stay in memory
-- or trigger() won't find dependencies after garbage collection
-- CRITICAL: Do NOT use weak keys for depMap - the raw table must stay in memory
-- or trigger() won't find dependencies after garbage collection
local depMap: { [any]: { [any]: Dep } } = {}
local effectStack: { Effect } = {}
local activeEffect: Effect? = nil

-- Effect scope management for grouping effects and batch cleanup
type EffectScope = {
	active: boolean,
	effects: { Effect },
	cleanups: { () -> () },
	scopes: { EffectScope },
	parent: EffectScope?,
	run: <T>(self: EffectScope, fn: () -> T) -> T?,
	stop: (self: EffectScope) -> (),
}

local scopeStack: { EffectScope } = {}
local activeScope: EffectScope? = nil

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
		run = nil :: any,
		stop = nil :: any,
	}

	function scope:run<T>(fn: () -> T): T?
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

	function scope:stop()
		if not self.active then
			return
		end

		self.active = false

		-- Stop all child scopes first
		for _, childScope in ipairs(self.scopes) do
			childScope:stop()
		end

		-- Stop all effects in this scope
		for _, eff in ipairs(self.effects) do
			eff:stop()
		end

		-- Run all cleanup callbacks
		for _, cleanup in ipairs(self.cleanups) do
			pcall(cleanup)
		end

		-- Clear arrays
		self.effects = {}
		self.cleanups = {}
		self.scopes = {}
	end

	-- Register with parent scope if not detached
	if scope.parent then
		table.insert(scope.parent.scopes, scope)
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
		if not failSilently and RunService and RunService:IsStudio() then
			debugModule.log("Reactivity", "onScopeDispose called without an active effect scope")
		end
		return
	end

	table.insert(activeScope.cleanups, fn)
end

--- Checks if a value is a table
--- @param t any -- Value to check
--- @return boolean -- True if value is a table
local function isTable(t: any): boolean
	return type(t) == "table"
end

--- Checks if a value is a function
--- @param f any -- Value to check
--- @return boolean -- True if value is a function
local function isFunction(f: any): boolean
	return type(f) == "function"
end

-- Reactivity markers (stored with weak keys to avoid memory leaks)
local rawMarker: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local reactiveMarker: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local readonlyMarker: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- local shallowRefMarker: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

--- Marks an object as raw (non-reactive)
--- Prevents the object from being converted to a reactive proxy
--- @param obj T -- Object to mark as raw
--- @return T -- The same object, now marked as raw
local function markRaw<T>(obj: T): T
	if type(obj) == "table" then
		(rawMarker :: any)[obj] = true
	end
	return obj
end

--- Unwraps a proxy to get the original object
--- Returns the original non-proxy object from reactive/readonly/shallow proxies
--- @param obj T -- Proxy or raw object
--- @return T -- Original object (non-proxy)
local function toRaw<T>(obj: T): T
	-- If it's marked with the original object reference, return that
	local original = (reactiveMarker :: any)[obj]
	if original then
		return original
	end
	-- Otherwise return as-is (already raw or primitive)
	return obj
end

--- Checks if a value is a reactive proxy (created by reactive or shallowReactive)
--- @param value any -- Value to check
--- @return boolean -- True if value is a reactive proxy
local function isReactive(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	return (reactiveMarker :: any)[value] ~= nil
end

--- Checks if a value is a readonly proxy
--- @param value any -- Value to check
--- @return boolean -- True if value is readonly
local function isReadonly(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	return (readonlyMarker :: any)[value] == true
end

--- Checks if a value is a proxy (reactive or readonly)
--- @param value any -- Value to check
--- @return boolean -- True if value is any kind of proxy
local function isProxy(value: any): boolean
	return isReactive(value) or isReadonly(value)
end

--- Creates a reactive effect that tracks dependencies and re-runs on changes
--- @param fn (...any) -> ...any -- Effect function to execute
--- @param opts EffectOptions? -- Optional scheduler and lazy execution settings
--- @return Effect -- Effect object with run and stop methods
local function createEffect(fn: (...any) -> ...any, opts: EffectOptions?): Effect
	local options: EffectOptions = opts or {}
	local effect: Effect = {
		fn = fn,
		scheduler = options.scheduler,
		deps = {},
		active = true,
		run = nil :: any,
		stop = nil :: any,
	}
	local function run(...: any): ...any
		if not effect.active then
			return fn(...)
		end

		-- Profile effect execution for performance monitoring
		local effectName = "effect_" .. tostring(effect)
		if utils.profiler.active then
			utils.profiler:start(effectName)
		end

		-- This ensures fresh dependency tracking on each execution (Vue 3 pattern)
		for _, dep in ipairs(effect.deps) do
			(dep :: any)[effect] = nil
		end
		effect.deps = {}

		table.insert(effectStack, effect)
		activeEffect = effect
		local ok, res = pcall(fn, ...)
		table.remove(effectStack)
		activeEffect = effectStack[#effectStack]

		if utils.profiler.active then
			utils.profiler:stop(effectName)
		end

		if not ok then
			debugModule.log("Reactivity", "Reactive effect error", { error = res })
		end
		return res
	end
	function effect:stop()
		if not self.active then
			return
		end
		self.active = false
		for _, dep in ipairs(self.deps) do
			(dep :: any)[self] = nil
		end
		self.deps = {}
	end
	effect.run = run

	-- Register effect with current scope (if any)
	if activeScope then
		table.insert(activeScope.effects, effect)
	end

	if not options.lazy then
		if effect.scheduler then
			effect.scheduler(effect.run)
		else
			(scheduler :: any).queueJob(effect.run)
		end
	end
	return effect
end

--- Tracks access to a property for reactive dependency collection
--- @param target any -- Object being accessed
--- @param key any -- Property key being accessed
local function track(target: any, key: any)
	if not activeEffect then
		return
	end
	local deps = depMap[target]
	if not deps then
		deps = {}
		depMap[target] = deps
	end
	local dep = deps[key]
	if not dep then
		dep = {} :: any
		deps[key] = dep
	end
	if not dep[activeEffect :: any] then
		dep[activeEffect :: any] = true
		table.insert((activeEffect :: Effect).deps, dep)
	end
end

--- Triggers all effects that depend on a property
--- @param target any -- Object that changed
--- @param key any -- Property key that changed
local function trigger(target: any, key: any)
	local deps = depMap[target]
	if not deps then
		return
	end
	local dep = deps[key]
	if not dep then
		return
	end
	for eff: any, _ in pairs(dep) do
		if not eff.active then continue end
		if eff.scheduler then
			eff.scheduler(eff.run)
		else
			(scheduler :: any).queueJob(eff.run)
		end
	end
end

local proxyCache: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local shallowProxyCache: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local readonlyCache: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

--- Creates a deeply reactive proxy of an object.
---  All nested objects are automatically made reactive
--- @param target T -- Table to make reactive
--- @return T -- Reactive proxy of the table
local function reactive<T>(target: T & {}): T
	assert(isTable(target), "reactive expects a table")
	local tbl: any = target
	if rawMarker[tbl] then
		return target
	end
	local cached = proxyCache[tbl]
	if cached then
		return cached
	end

	local proxy = {}

	-- Store reference to original object for toRaw()
	reactiveMarker[proxy] = tbl

	local mt = {}
	function mt.__index(_: any, k: any): any
		track(target, k)
		local v = tbl[k]
		if isTable(v) and not rawMarker[v] then
			return reactive(v)
		end
		return v
	end
	function mt.__newindex(_: any, k: any, v: any)
		local old = tbl[k]
		tbl[k] = v
		--print("[REACTIVE] __newindex called - key:", k, "old:", old, "new:", v, "different?", old ~= v)
		if old ~= v then
			trigger(target, k)
		end
	end
	function mt.__pairs(): any
		track(target, "__pairs")
		return pairs(tbl)
	end
	-- NOTE: __ipairs metamethod is defined but won't be called by Luau's ipairs()
	-- Luau's ipairs() performs a preliminary check for table[1] existence BEFORE
	-- invoking __ipairs. Since this proxy is an empty table (all data in 'tbl'),
	-- the check fails and iteration stops immediately without calling this metamethod.
	--
	-- SOLUTION: Use numeric iteration instead: for i = 1, #array do ... end
	-- This triggers __len and __index metamethods properly and tracks dependencies.
	-- See docs/RUNTIME_REFERENCE.md "Iterating Reactive Arrays" for details.
	function mt.__ipairs(): any
		track(target, "__ipairs")
		return ipairs(tbl)
	end
	function mt.__len(): number
		track(target, "__len")
		return #tbl
	end
	function mt.__tostring(): string
		-- In dev mode, show a helpful representation
		local isDev = RunService and RunService:IsStudio() or false
		if isDev then
			return "<Reactive Proxy>" -- Hints that this is a proxy, use toRaw() or dev_utils.inspect()
		end
		return tostring(tbl)
	end
	setmetatable(proxy, mt)
	proxyCache[tbl] = proxy
	return proxy :: any
end

--- Creates a shallow reactive proxy (only top-level properties are reactive)
--- @param target T -- Table to make shallow reactive
--- @return T -- Shallow reactive proxy
local function shallowReactive<T>(target: T & {}): T
	assert(isTable(target), "shallowReactive expects a table")
	local tbl: any = target
	if rawMarker[tbl] then
		return target
	end
	local cached = shallowProxyCache[tbl]
	if cached then
		return cached
	end

	local proxy = {}

	-- Mark as reactive for isReactive() check
	reactiveMarker[proxy] = tbl

	local mt = {}
	function mt.__index(_: any, k: any): any
		track(target, k)
		return tbl[k]
	end
	function mt.__newindex(_: any, k: any, v: any)
		local old = tbl[k]
		tbl[k] = v
		if old ~= v then
			trigger(target, k)
		end
	end
	function mt.__tostring(): string
		local isDev = RunService and RunService:IsStudio() or false
		if isDev then
			return "<ShallowReactive Proxy>"
		end
		return tostring(tbl)
	end
	setmetatable(proxy, mt)
	shallowProxyCache[tbl] = proxy
	return proxy :: any
end

--- Creates a reactive reference to a value
--- @param initial T -- Initial value
--- @return Ref<T> -- Reactive reference with .value property
local function ref<T>(initial: T): Ref<T>
	local wrappedValue: any = initial
	if isTable(initial) and not (rawMarker :: any)[initial] then
		wrappedValue = reactive(initial :: any)
	end

	local r: any = { _is_ref = true, _value = wrappedValue }
	return setmetatable(r, {
		__index = function(t: any, k: any): any
			if k == "value" then
				track(t, "value")
				return rawget(t, "_value")
			end
			return rawget(t, k)
		end,
		__tostring = function(t: any): string
			local isDev = RunService and RunService:IsStudio() or false
			if isDev then
				local val = rawget(t, "_value")
				return "<Ref: " .. tostring(val) .. ">"
			end
			return tostring(rawget(t, "_value"))
		end,
		__newindex = function(t: any, k: any, v: any)
			if k == "value" then
				local old = rawget(t, "_value")
				-- Auto-wrap new table values in reactive()
				local newValue: any = v
				if isTable(v) and not (rawMarker :: any)[v] then
					newValue = reactive(v :: any)
				end
				rawset(t, "_value", newValue)
				if old ~= newValue then
					trigger(t, "value")
				end
				return
			end
			rawset(t, k, v)
		end,
	}) :: any
end

--- Creates a shallow reactive reference (doesn't auto-wrap objects)
--- @param initial T -- Initial value
--- @return Ref<T> -- Shallow reactive reference with .value property
local function shallowRef<T>(initial: T): Ref<T>
	-- Unlike ref(), shallowRef does NOT wrap objects in reactive()
	local r: any = { _is_ref = true, _value = initial }
	return setmetatable(r, {
		__index = function(t: any, k: any): any
			if k == "value" then
				track(t, "value")
				return rawget(t, "_value")
			end
			return rawget(t, k)
		end,
		__newindex = function(t: any, k: any, v: any)
			if k == "value" then
				local old = rawget(t, "_value")
				-- Shallow: Don't wrap in reactive(), just store as-is
				rawset(t, "_value", v)
				if old ~= v then
					trigger(t, "value")
				end
				return
			end
			rawset(t, k, v)
		end,
	}) :: any
end

--- Checks if a value is a Ref
--- @param r any -- Value to check
--- @return boolean -- True if value is a Ref
local function isRef(r: any): boolean
	return type(r) == "table" and r._is_ref == true
end

--- Unwraps a Ref to get its value, or returns the value as-is
--- @param r T | Ref<T> -- Ref or plain value
--- @return T -- Unwrapped value
local function unref<T>(r: T | Ref<T>): T
	return if isRef(r) then (r :: any).value else r :: any
end

--- Creates a computed value that caches the result and only re-computes when dependencies change
--- @param getter () -> T -- Function that computes the value
--- @return ComputedRef<T> -- Computed reference with cached .value property
local function computed<T>(getter: () -> T): ComputedRef<T>
	assert(isFunction(getter), "computed expects a function")
	local dirty = true
	local value: T = nil :: any
	local runner: Effect = nil :: any
	runner = createEffect(function(): ()
		value = getter()
	end, {
		lazy = true,
		scheduler = function(_: any)
			if not dirty then
				dirty = true
				trigger(obj, "value")
			end
		end,
	})
	local obj: any = {}
	function obj.get(): T
		if dirty then
			runner.run()
			dirty = false
		end
		if activeEffect then
			track(runner, "computed")
		end
		return value
	end
	setmetatable(obj, {
		__index = function(_: any, k: any): any
			if k == "value" then
				return obj.get()
			end
			return rawget(obj, k)
		end,
	})
	return obj
end

--- Creates a Ref that's linked to a property on a reactive object
--- @param obj any -- Source reactive object
--- @param key any -- Property key to link
--- @return Ref<T> -- Ref linked to the property
local function toRef<T>(obj: any, key: any): Ref<T>
	local r: any = { _is_ref = true }
	setmetatable(r, {
		__index = function(_: any, k: any): any
			if k == "value" then
				track(obj, key)
				return obj[key]
			end
			return rawget(r, k)
		end,
		__newindex = function(_: any, k: any, v: any)
			if k == "value" then
				local old = obj[key]
				obj[key] = v
				if old ~= v then
					trigger(obj, key)
				end
				return
			end
			rawset(r, k, v)
		end,
	})
	return r
end

--- Converts all properties of a reactive object to Refs
--- @param obj any -- Reactive object to convert
--- @return { [any]: Ref<any> } -- Table of Refs for each property
local function toRefs(obj: any): { [any]: Ref<any> }
	local res: { [any]: Ref<any> } = {}
	-- Get the raw object to iterate over (works around Luau's __pairs limitation)
	local raw = toRaw(obj)
	for k, _ in pairs(raw) do
		res[k] = toRef(obj, k)
	end
	return res
end

--- Deeply traverses an object to trigger all reactive dependencies (for deep watching)
--- @param value any -- Value to traverse
--- @param seen { [any]: boolean }? -- Set of already-seen tables to prevent infinite loops
--- @return any -- The traversed value
local function _traverse(value: any, seen: { [any]: boolean }?): any
	if type(value) ~= "table" then
		return value
	end
	local seenTables: { [any]: boolean } = seen or {}
	if seenTables[value] then
		return value
	end
	seenTables[value] = true
	local raw = toRaw(value)
	for k, _ in pairs(raw) do
		_traverse((value :: any)[k], seenTables)
	end
	return value
end

--- Watches a reactive source and executes callback when it changes
--- @param source (() -> any) | Ref<any> | any -- Reactive source to watch (getter function, Ref, or reactive object)
--- @param cb WatchCallback -- Callback (newValue, oldValue, onCleanup) => void
--- @param opts WatchOptions? -- Options: immediate (run immediately), deep (traverse nested objects)
--- @return WatchStopHandle -- Function to stop watching
local function watch(source: (() -> any) | Ref<any> | any, cb: WatchCallback, opts: WatchOptions?): WatchStopHandle
	local options: WatchOptions = opts or {}
	local getter: () -> any
	if type(source) == "function" then
		getter = source :: () -> any
	else
		getter = function(): any
			if isRef(source) then
				return (source :: any).value
			end
			return source
		end
	end
	local cleanups: { () -> () } = {}
	local function onCleanup(fn: () -> ())
		table.insert(cleanups, fn)
	end
	local oldValue: any = nil
	local function job()
		local new = getter()
		if options.deep then
			_traverse(new, nil)
		end
		if options.immediate then
			for _, cleanup in ipairs(cleanups) do
				pcall(cleanup)
			end
			cleanups = {}
			cb(new, oldValue, onCleanup)
			options.immediate = false
			oldValue = new
			return
		end
		if oldValue ~= nil then
			for _, cleanup in ipairs(cleanups) do
				pcall(cleanup)
			end
			cleanups = {}
			cb(new, oldValue, onCleanup)
		end
		oldValue = new
	end
	local eff = createEffect(function(): ()
		if options.deep then
			_traverse(getter(), nil)
		else
			getter()
		end
	end, {
		lazy = false,
		scheduler = function(run)
			-- Must call run() to set activeEffect, then queue the callback
			-- Flush timing controls when the watcher executes
			local flushMode = options.flush or "pre" -- Default to "pre" (before component updates)

			run()

			if flushMode == "sync" then
				-- Execute immediately (synchronous)
				job()
			elseif flushMode == "post" then
				-- Execute after render (heartbeat mode)
				(scheduler :: any).queueJob(job, { mode = "heartbeat" })
			else
				-- Execute before render (default - micro mode)
				(scheduler :: any).queueJob(job, { mode = "micro" })
			end
		end,
	})
	if options.immediate then
		job()
	else
		oldValue = getter()
		if options.deep then
			_traverse(oldValue, nil)
		end
	end
	local function stop()
		eff:stop()
		for _, cleanup in ipairs(cleanups) do
			pcall(cleanup)
		end
		cleanups = {}
	end
	return stop
end

--- Creates and runs a reactive effect
--- @param fn (...any) -> ...any -- Effect function to execute
--- @param opts EffectOptions? -- Options: scheduler (custom scheduler), lazy (don't run immediately)
--- @return Effect -- Effect object with stop method
local function effect(fn: (...any) -> ...any, opts: EffectOptions?): Effect
	return createEffect(fn, opts)
end

--- Runs a reactive effect with automatic dependency tracking and immediate execution
--- Simpler alternative to watch() when you don't need the old/new value comparison
--- @param fn () -> () -- Effect function to execute (dependencies are auto-tracked)
--- @param _opts { flush: "pre" | "post" | "sync"? }? -- Options: flush timing (currently ignored, always deferred)
--- @return WatchStopHandle -- Function to stop the effect
local function watchEffect(fn: () -> (), _opts: any?): WatchStopHandle
	local eff = createEffect(fn, { lazy = false })
	return function()
		eff:stop()
	end
end

--- Creates a readonly reactive proxy that throws warnings on mutation attempts
--- Useful for enforcing one-way data flow (props, injected state, public APIs)
--- @param target T -- Object to make readonly
--- @return T -- Readonly reactive proxy
local function readonly<T>(target: T): T
	if type(target) ~= "table" then
		return target
	end

	-- Check if already marked as raw (non-reactive)
	if rawMarker[target :: any] then
		return target
	end

	local cached = readonlyCache[target :: any]
	if cached then
		return cached
	end

	local proxy = {}

	-- Mark as readonly for isReadonly() check
	readonlyMarker[proxy] = true
	-- Also store original for toRaw()
	reactiveMarker[proxy] = target
	readonlyCache[target :: any] = proxy

	setmetatable(proxy, {
		__index = function(_: any, k: any): any
			-- Track reads for reactivity
			track(target, k)
			local v = (target :: any)[k]

			-- Recursively make nested objects readonly
			if type(v) == "table" and not rawMarker[v] then
				return readonly(v)
			end

			return v
		end,
		__newindex = function(_: any, k: any, _v: any)
			-- Prevent mutations in dev mode
			if RunService and RunService:IsStudio() then
				debugModule.log("Reactivity", "Cannot mutate readonly reactive object", { key = k })
			end
		end,
		__len = function(_: any): number
			track(target, "length")
			return #(target :: any)
		end,
		__pairs = function(_: any)
			return pairs(target :: any)
		end,
		__ipairs = function(_: any)
			return ipairs(target :: any)
		end,
	})

	return proxy :: any
end

--- Manually triggers effects that depend on a shallowRef
--- Useful when you mutate the internal value of a shallowRef without replacing .value
--- @param refObj Ref<any> -- ShallowRef to trigger
local function triggerRef(refObj: Ref<any>)
	if not isRef(refObj) then
		if RunService and RunService:IsStudio() then
			debugModule.log("Reactivity", "triggerRef expects a ref object", { type = type(refObj) })
		end
		return
	end

	-- Manually trigger the "value" dependency
	trigger(refObj, "value")
end

--- Creates a customized ref with explicit control over dependency tracking and updates
--- Useful for debounced inputs, validation, custom state sync, etc.
--- @param factory (track: () -> (), trigger: () -> ()) -> { get: () -> T, set: (value: T) -> () } -- Factory function
--- @return Ref<T> -- Custom ref with manual tracking control
local function customRef<T>(
	factory: (track: () -> (), trigger: () -> ()) -> { get: () -> T, set: (value: T) -> () }
): Ref<T>
	local refTable: any = { _is_ref = true }

	local trackFn = function()
		track(refTable, "value")
	end

	local triggerFn = function()
		trigger(refTable, "value")
	end

	local accessor = factory(trackFn, triggerFn)

	if type(accessor) ~= "table" or type(accessor.get) ~= "function" or type(accessor.set) ~= "function" then
		error("[Rivue] customRef factory must return { get: () -> T, set: (T) -> () }")
	end

	return setmetatable(refTable, {
		__index = function(_: any, k: any): any
			if k == "value" then
				return accessor.get()
			end
			return rawget(refTable, k)
		end,
		__newindex = function(_: any, k: any, v: any)
			if k == "value" then
				accessor.set(v)
				return
			end
			rawset(refTable, k, v)
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

	-- Computed values
	computed = computed,

	-- Watchers and effects
	watch = watch,
	watchEffect = watchEffect,
	effect = effect,

	-- Type checking utilities
	isRef = isRef,
	isReactive = isReactive,
	isReadonly = isReadonly,
	isProxy = isProxy,

	-- Conversion utilities
	unref = unref,
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
