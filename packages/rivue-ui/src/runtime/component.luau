--!strict
--!optimize 2

local Types = require("./types")
local _reactivity = require("./reactivity")
local RunService = game:GetService("RunService")
local debugModule = require("./debug")

type VNode = Types.VNode
type Props = Types.Props
type Child = Types.Child
type PropSchema = Types.PropSchema
type ComponentDef = Types.ComponentDef
type SetupContext = Types.SetupContext
type RenderFunction = Types.RenderFunction
type Effect = Types.Effect
type EffectScope = Types.EffectScope
type JobHandle = Types.JobHandle
type WatchStopHandle = Types.WatchStopHandle
type AppContext = Types.AppContext

export type ErrorCapturedHook = (err: string, instance: ComponentInstance, info: string) -> boolean?

type HookList =
	"beforeMountCbs"
	| "mountedCbs"
	| "beforeUpdateCbs"
	| "updatedCbs"
	| "beforeUnmountCbs"
	| "unmountedCbs"
	| "activatedCbs"
	| "deactivatedCbs"
	| "renderTrackedCbs"
	| "renderTriggeredCbs"

local ComponentInstance = {}
ComponentInstance.__index = ComponentInstance

type InstanceData = {
	-- Creation order, used to update parents before children
	uid: number,
	vnode: VNode,
	type: ComponentDef,
	props: Props,
	attrs: Props,
	parent: ComponentInstance?,
	provides: { [unknown]: unknown },
	appContext: AppContext,
	isMounted: boolean,
	isUnmounted: boolean,
	isDeactivated: boolean,
	subTree: VNode?,
	el: Instance?,
	container: Instance?,
	refs: { [string]: unknown },
	templateRefs: { [string]: Types.Ref<unknown> },
	cleanupCbs: { () -> () },
	beforeMountCbs: { () -> () },
	mountedCbs: { () -> () },
	beforeUpdateCbs: { () -> () },
	updatedCbs: { () -> () },
	beforeUnmountCbs: { () -> () },
	unmountedCbs: { () -> () },
	activatedCbs: { () -> () },
	deactivatedCbs: { () -> () },
	renderTrackedCbs: { (event: Types.DebuggerEvent) -> () },
	renderTriggeredCbs: { (event: Types.DebuggerEvent) -> () },
	errorCapturedCbs: { ErrorCapturedHook },
	slots: { Child },
	namedSlots: Types.Slots,
	render: RenderFunction?,
	setupState: { render: RenderFunction, [string]: unknown }?,
	exposed: { [string]: unknown }?,
	ctx: SetupContext,
	_effects: { WatchStopHandle | Types.WatchHandle | Effect },
	_schedulerJobs: { JobHandle },
	_scope: EffectScope?,
	_renderEffect: Effect?,
	_transitionHooks: { [string]: { (el: Instance) -> () } }?,
	_pendingUpdate: boolean,
	_idCount: number,
	_keepAliveRenderer: { unmount: (vnode: VNode) -> () }?,
	-- What made the next render happen, for app.config.devtools
	_devtoolsTriggers: { string }?,
}

export type ComponentInstance = typeof(setmetatable({} :: InstanceData, ComponentInstance))

const IS_STUDIO = RunService:IsStudio()

local currentInstance: ComponentInstance? = nil
local createRenderContext: (self: ComponentInstance) -> { [string]: any }
local currentRenderingInstance: ComponentInstance? = nil
local uidCounter = 0

-- Used when a component is mounted outside createApp (e.g. renderer.patch directly)
const EMPTY_APP_CONTEXT: AppContext =
	{ provides = {}, config = { globalProperties = {} }, components = {}, styles = {} }

local function setCurrentInstance(i: ComponentInstance?): ()
	currentInstance = i
end

local function getCurrentInstance(): ComponentInstance?
	return currentInstance
end

local function setRenderingInstance(i: ComponentInstance?): ComponentInstance?
	local prev = currentRenderingInstance
	currentRenderingInstance = i
	return prev
end

local function getRenderingInstance(): ComponentInstance?
	return currentRenderingInstance
end

local function createHook(hookName: string, list: HookList): (fn: () -> ()) -> ()
	return function(fn: () -> ())
		if type(fn) ~= "function" then
			error(`{hookName}() expects a function`, 2)
		end
		local inst = currentInstance
		if not inst then
			error(
				`{hookName}() must be called inside a component's setup(), it registers on the component being set up`,
				2
			)
		end

		if debugModule.enabled then
			debugModule.log(
				"Component",
				`Registered {hookName} callback`,
				{ component = inst.type.__name or "Anonymous" }
			)
		end
		table.insert(inst[list], fn)
	end
end

local onBeforeMount = createHook("onBeforeMount", "beforeMountCbs")
local onMounted = createHook("onMounted", "mountedCbs")
local onBeforeUpdate = createHook("onBeforeUpdate", "beforeUpdateCbs")
local onUpdated = createHook("onUpdated", "updatedCbs")
local onBeforeUnmount = createHook("onBeforeUnmount", "beforeUnmountCbs")
local onUnmounted = createHook("onUnmounted", "unmountedCbs")
local onActivated = createHook("onActivated", "activatedCbs")
local onDeactivated = createHook("onDeactivated", "deactivatedCbs")
local onRenderTracked =
	createHook("onRenderTracked", "renderTrackedCbs") :: (fn: (event: Types.DebuggerEvent) -> ()) -> ()
local onRenderTriggered =
	createHook("onRenderTriggered", "renderTriggeredCbs") :: (fn: (event: Types.DebuggerEvent) -> ()) -> ()

local injectionContext: AppContext? = nil

local function runWithInjectionContext<T>(context: AppContext, fn: () -> T): T
	local prev = injectionContext
	injectionContext = context
	local ok, result = pcall(fn)
	injectionContext = prev
	if not ok then
		error(result, 0)
	end
	return result
end

local function hasInjectionContext(): boolean
	return currentInstance ~= nil or injectionContext ~= nil
end

local function formatComponentTrace(inst: ComponentInstance?): string
	local parts: { string } = {}
	local cur = inst
	while cur and #parts < 12 do
		table.insert(parts, `<{cur.type.__name or "Anonymous"}>`)
		cur = cur.parent
	end
	return if #parts > 0 then table.concat(parts, " in ") else "<root>"
end

local idCounter = 0

local function useId(): string
	local inst = currentInstance
	if inst then
		inst._idCount += 1
		return `r{inst.uid}-{inst._idCount}`
	end
	idCounter += 1
	return `r0-{idCounter}`
end

local function useTemplateRef<T>(name: string): Types.Ref<T?>
	local inst = currentInstance
	if not inst then
		error("useTemplateRef() must be called in setup", 2)
	end
	local r = _reactivity.shallowRef(inst.refs[name] :: T?)
	inst.templateRefs[name] = r :: any
	return r
end

local function provide(key: unknown, value: unknown): ()
	local inst = currentInstance
	if not inst then
		error("provide() must be called in setup", 2)
	end
	inst.provides[key] = value
end

--- Like Vue, inject() looks above the component, so it can read a key and provide a new value for it
local function providedAbove(inst: ComponentInstance, key: unknown): unknown
	local parent = inst.parent
	return if parent then parent.provides[key] else inst.appContext.provides[key]
end

local function inject<T>(key: unknown, default: T?): T?
	local inst = currentInstance
	local provided: unknown
	if inst then
		provided = providedAbove(inst, key)
	elseif injectionContext then
		provided = injectionContext.provides[key]
	else
		error("inject() must be called inside setup() or app:runWithContext()", 2)
	end
	return if provided ~= nil then provided :: T else default
end

local function onErrorCaptured(fn: ErrorCapturedHook): ()
	local inst = currentInstance
	if not inst then
		error("onErrorCaptured must be called in setup", 2)
	end

	table.insert(inst.errorCapturedCbs, fn)
end

local function applyPropDefaults(schema: PropSchema, props: Props): ()
	for name, spec in schema do
		local defaultVal = spec.default
		if props[name] == nil and defaultVal ~= nil then
			props[name] = if type(defaultVal) == "function" then (defaultVal :: () -> unknown)() else defaultVal
		end
	end
end

local function toHandlerKey(eventName: string): string
	return `on{eventName:sub(1, 1):upper()}{eventName:sub(2)}`
end

local emitKeysCache: { [ComponentDef]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any

local function getEmitKeys(def: ComponentDef): { [string]: string }?
	local emits = def.emits
	if emits == nil then
		return nil
	end
	local cached = emitKeysCache[def]
	if cached then
		return cached
	end
	local keys: { [string]: string } = {}
	for k, v in emits :: { [unknown]: unknown } do
		local name: unknown = if type(k) == "number" then v else k
		if type(name) == "string" then
			keys[toHandlerKey(name)] = name
		end
	end
	emitKeysCache[def] = keys
	return keys
end

-- Like Vue's shouldUpdateComponent. Declared listeners are read from the vnode when emitted, so a
-- fresh closure for one doesn't count as a change
local function propsUnchanged(def: ComponentDef, oldProps: Props?, newProps: Props?): boolean
	if oldProps == newProps then
		return true
	end
	local old: Props = oldProps or {}
	local new: Props = newProps or {}
	local emitKeys = getEmitKeys(def)
	local count = 0
	for key, value in new do
		count += 1
		local previous = old[key]
		if
			previous ~= value
			and not (emitKeys and emitKeys[key] and type(previous) == "function" and type(value) == "function")
		then
			return false
		end
	end
	for _ in old do
		count -= 1
	end
	return count == 0
end

local function separatePropsAndAttrs(def: ComponentDef, allProps: Props): (Props, Props)
	local schema = def.props
	local emitKeys = getEmitKeys(def)
	if not schema and not emitKeys and allProps.class == nil then
		return allProps, {}
	end

	local props: Props = {}
	local attrs: Props = {}

	for key, value in allProps do
		if emitKeys and emitKeys[key] then
			continue
		end
		-- Like Vue, class goes to the root element unless the component declares it
		if key == "class" and not (schema and schema.class) then
			attrs[key] = value
		-- Without a schema every other prop is declared
		elseif not schema or schema[key] then
			props[key] = value
		else
			attrs[key] = value
		end
	end

	return props, attrs
end

local function validateProps(schema: PropSchema?, props: Props): (boolean, string?)
	if not schema then
		return true, nil
	end

	local errs: { string } = {}

	for name, spec in schema do
		local val = props[name]

		if spec.required and val == nil then
			table.insert(errs, `prop '{name}' required`)
		end

		local expected = spec.type
		if val ~= nil and expected then
			local actual = typeof(val)
			local allowed: { string } = if type(expected) == "table"
				then expected :: { string }
				else { expected :: string }
			local matches = false
			for _, t in allowed do
				-- type() names ("table") and typeof() names ("UDim2", "Instance") both work
				if t == actual or t == type(val) then
					matches = true
					break
				end
			end
			if not matches then
				table.insert(errs, `prop '{name}' should be {table.concat(allowed, " | ")}, got {actual}`)
			end
		end

		local validator = spec.validator
		if val ~= nil and validator then
			local ok, result = pcall(validator, val)

			if not ok or result == false then
				table.insert(errs, `prop '{name}' failed custom validation`)
			end
		end
	end

	if #errs > 0 then
		return false, table.concat(errs, "; ")
	end

	return true, nil
end

local function runCallbacks(self: ComponentInstance, callbacks: { () -> () }, info: string)
	for _, fn in callbacks do
		local ok, err = pcall(fn :: () -> ...unknown)
		if not ok then
			self:handleError(tostring(err), info)
		end
	end
end

function createRenderContext(self: ComponentInstance): { [string]: any }
	local state = self.setupState
	local stateView: { [string]: any }? = if state then _reactivity.proxyRefs(state) else nil
	local props = self.props
	local ctx = self.ctx :: any
	return setmetatable({}, {
		__index = function(_: unknown, key: string): any
			-- A key setup() returned belongs to setup state, even while its ref holds nil
			if stateView and (state :: any)[key] ~= nil then
				return stateView[key]
			end
			local prop = props[key]
			if prop ~= nil then
				return prop
			end
			return ctx[key]
		end,
		__newindex = function(_: unknown, key: string, value: any)
			if stateView and (state :: any)[key] ~= nil then
				stateView[key] = value
			elseif IS_STUDIO then
				warn(
					`[Rivue] Can't set '{key}' in render of {formatComponentTrace(self)}, it isn't returned by setup()`
				)
			end
		end,
	}) :: any
end

function ComponentInstance.setupComponent(self: ComponentInstance)
	local prevInstance = currentInstance
	setCurrentInstance(self)

	local def = self.type
	local schema = def.props

	if schema then
		applyPropDefaults(schema, self.props)

		if IS_STUDIO then
			local ok, err = validateProps(schema, self.props)
			if not ok then
				warn(`[Rivue] Invalid props for {formatComponentTrace(self)}: {err}`)
			end
		end
	end

	local scope = _reactivity.effectScope(true)
	self._scope = scope

	local setupResult: unknown = nil
	local setup = def.setup
	if setup then
		local setupErr: unknown = nil
		setupResult = scope:run(function()
			local ok, result = pcall(setup, self.props, self.ctx)
			if not ok then
				setupErr = result
				return nil
			end
			return result
		end)
		if setupErr ~= nil then
			setCurrentInstance(prevInstance)
			-- The component never mounts, so nothing else would stop what setup() started
			scope:stop()
			self._scope = nil
			error(`[Rivue] setup() of {formatComponentTrace(self)} failed: {setupErr}`, 0)
		end
	end
	setCurrentInstance(prevInstance)

	if type(setupResult) == "function" then
		self.render = setupResult :: RenderFunction
	elseif type(setupResult) == "table" and type((setupResult :: any).render) == "function" then
		local state = setupResult :: { render: RenderFunction, [string]: unknown }
		self.render = state.render
		self.setupState = state
	elseif def.render then
		local render = def.render
		if type(setupResult) == "table" then
			self.setupState = setupResult :: any
		end
		local renderContext = createRenderContext(self)
		self.render = function()
			return render(renderContext)
		end
	elseif setup then
		error(
			`[Rivue] setup() of {formatComponentTrace(self)} must return a render function, or state plus a render option`,
			0
		)
	else
		error(`[Rivue] {formatComponentTrace(self)} has no setup() or render()`, 0)
	end
end

function ComponentInstance.runBeforeMount(self: ComponentInstance)
	runCallbacks(self, self.beforeMountCbs, "beforeMount hook")
end

function ComponentInstance.runMounted(self: ComponentInstance)
	self.isMounted = true
	runCallbacks(self, self.mountedCbs, "mounted hook")
end

function ComponentInstance.runBeforeUpdate(self: ComponentInstance)
	runCallbacks(self, self.beforeUpdateCbs, "beforeUpdate hook")
end

function ComponentInstance.runUpdated(self: ComponentInstance)
	runCallbacks(self, self.updatedCbs, "updated hook")
end

function ComponentInstance.runActivated(self: ComponentInstance)
	runCallbacks(self, self.activatedCbs, "activated hook")
end

function ComponentInstance.runDeactivated(self: ComponentInstance)
	runCallbacks(self, self.deactivatedCbs, "deactivated hook")
end

function ComponentInstance.isInKeepAlive(self: ComponentInstance): boolean
	local cur: ComponentInstance? = self
	while cur do
		if cur.vnode._keepAlive then
			return true
		end
		cur = cur.parent
	end
	return false
end

function ComponentInstance.runBeforeUnmount(self: ComponentInstance)
	runCallbacks(self, self.beforeUnmountCbs, "beforeUnmount hook")
end

function ComponentInstance.runUnmounted(self: ComponentInstance)
	if debugModule.enabled then
		debugModule.log("Component", "Running unmounted callbacks and cleanup", {
			component = self.type.__name or "Anonymous",
			unmountedCbs = #self.unmountedCbs,
			cleanupCbs = #self.cleanupCbs,
			effects = #self._effects,
			schedulerJobs = #self._schedulerJobs,
		})
	end

	runCallbacks(self, self.unmountedCbs, "unmounted hook")
	runCallbacks(self, self.cleanupCbs, "cleanup")

	for _, jobHandle in self._schedulerJobs do
		pcall(jobHandle.cancel)
	end
	table.clear(self._schedulerJobs)

	for _, tracked in self._effects do
		if type(tracked) == "function" then
			pcall(tracked)
		else
			pcall(tracked.stop, tracked)
		end
	end
	table.clear(self._effects)

	local scope = self._scope
	if scope then
		scope:stop()
		self._scope = nil
	end
end

function ComponentInstance.handleError(self: ComponentInstance, err: string, info: string)
	local cur = self.parent
	while cur do
		for _, handler in cur.errorCapturedCbs do
			-- Like Vue: returning false means handled, so it goes no further up
			local ok, result = pcall(handler, err, self, info)
			if ok and result == false then
				return
			end
		end
		cur = cur.parent
	end
	local errorHandler = self.appContext.config.errorHandler
	if errorHandler then
		local ok, handlerErr = pcall(errorHandler :: (string, unknown, string) -> ...unknown, err, self, info)
		if ok then
			return
		end
		warn(`[Rivue] app.config.errorHandler failed: {handlerErr}`)
	end
	warn(`[Rivue] Error in {info} of {formatComponentTrace(self)}: {err}`)
end

_reactivity._setErrorHandling(getCurrentInstance, function(owner: any, err: string, info: string)
	(owner :: ComponentInstance):handleError(err, info)
end)

local function toChildList(result: unknown): { Child }
	if result == nil then
		return {}
	elseif type(result) == "table" and (result :: { [unknown]: unknown }).type == nil then
		return result :: { Child }
	end
	return { result :: Child }
end

-- The renderer fills this in: it owns the root Instance the DevTools read
local devtoolsHooks: { emit: ((instance: ComponentInstance, eventName: string, args: { unknown }) -> ())? } = {}

local function createSetupContext(instance: ComponentInstance): SetupContext
	return {
		emit = function(eventName: string, ...: any): ()
			if instance.isUnmounted then
				return
			end
			local handlerName = toHandlerKey(eventName)
			local def = instance.type
			local emits = def.emits
			if IS_STUDIO and emits then
				local validator = (emits :: { [string]: (...any) -> boolean })[eventName]
				local emitKeys = getEmitKeys(def)
				if not (emitKeys and emitKeys[handlerName]) then
					warn(`[Rivue] {def.__name or "Anonymous"} emitted '{eventName}' but it isn't declared in emits`)
				elseif type(validator) == "function" and validator(...) == false then
					warn(`[Rivue] Invalid payload for event '{eventName}' in {def.__name or "Anonymous"}`)
				end
			end
			local emitHook = devtoolsHooks.emit
			if emitHook and instance.appContext.config.devtools then
				emitHook(instance, eventName, { ... })
			end
			-- Declared listeners only live on the vnode
			local vnodeProps = instance.vnode.props
			local handler = if vnodeProps then vnodeProps[handlerName] else nil
			if handler == nil then
				handler = instance.props[handlerName] or instance.attrs[handlerName]
			end

			if type(handler) == "function" then
				local ok, err = pcall(handler, ...)
				if not ok then
					instance:handleError(tostring(err), `emit({eventName})`)
				end
			end
		end,
		provide = function(key: string, val: unknown): ()
			instance.provides[key] = val
		end,
		inject = function(key: string, default: unknown?): unknown?
			local provided = providedAbove(instance, key)
			return if provided ~= nil then provided else default
		end,
		slots = instance.slots,
		renderSlot = function(name: string, scope: any?, fallback: { Child }?): { Child }
			local slotFn = instance.namedSlots[name]
			if slotFn then
				return toChildList(slotFn(scope))
			elseif name == "default" and #instance.slots > 0 then
				return table.clone(instance.slots)
			end
			return if fallback then fallback else {}
		end,
		hasSlot = function(name: string): boolean
			return instance.namedSlots[name] ~= nil or (name == "default" and #instance.slots > 0)
		end,
		attrs = instance.attrs,
		globals = instance.appContext.config.globalProperties or {},
		expose = function(exposed: { [string]: unknown }?): ()
			instance.exposed = exposed
		end,
		onUnmounted = function(fn: () -> ()): ()
			table.insert(instance.unmountedCbs, fn)
		end,
	}
end

local function createComponentInstance(
	vnode: VNode,
	parent: ComponentInstance?,
	appContext: AppContext?
): (ComponentInstance, SetupContext)
	local def = vnode.type :: ComponentDef
	if debugModule.enabled then
		debugModule.log("Component", "Creating component instance", {
			type = def.__name or "AnonymousComponent",
			hasParent = parent ~= nil,
			childCount = #vnode.children,
		})
	end

	local context: AppContext = if parent then parent.appContext else appContext or EMPTY_APP_CONTEXT
	-- Own table so siblings don't share provides, parent values come through __index
	local provides: { [unknown]: unknown } = setmetatable(
		{},
		{ __index = if parent then parent.provides else context.provides }
	) :: any

	local declaredProps, attrs = separatePropsAndAttrs(def, vnode.props or {})
	local props = _reactivity.shallowReactive(table.clone(declaredProps))
	local reactiveAttrs = _reactivity.shallowReactive(attrs)

	uidCounter += 1
	local data: InstanceData = {
		uid = uidCounter,
		vnode = vnode,
		type = def,
		props = props,
		attrs = reactiveAttrs,
		parent = parent,
		provides = provides,
		appContext = context,
		isMounted = false,
		isUnmounted = false,
		isDeactivated = false,
		subTree = nil,
		el = nil,
		container = nil,
		refs = {},
		templateRefs = {},
		cleanupCbs = {},
		beforeMountCbs = {},
		mountedCbs = {},
		beforeUpdateCbs = {},
		updatedCbs = {},
		beforeUnmountCbs = {},
		unmountedCbs = {},
		activatedCbs = {},
		deactivatedCbs = {},
		renderTrackedCbs = {},
		renderTriggeredCbs = {},
		errorCapturedCbs = {},
		slots = vnode.children,
		namedSlots = if vnode.slots then table.clone(vnode.slots) else {},
		render = nil,
		setupState = nil,
		exposed = nil,
		ctx = nil :: any,
		_effects = {},
		_schedulerJobs = {},
		_scope = nil,
		_renderEffect = nil,
		_transitionHooks = nil,
		_pendingUpdate = false,
		_idCount = 0,
		_keepAliveRenderer = nil,
		_devtoolsTriggers = nil,
	}
	local instance = setmetatable(data, ComponentInstance)
	instance.ctx = createSetupContext(instance)

	return instance, instance.ctx
end

local function updateComponentProps(instance: ComponentInstance, rawProps: Props?): ()
	local schema = instance.type.props
	local nextProps, nextAttrs = separatePropsAndAttrs(instance.type, rawProps or {})
	local props = instance.props
	local current = _reactivity.toRaw(props)

	for key in current do
		if nextProps[key] == nil then
			local spec = if schema then schema[key] else nil
			local default = if spec then spec.default else nil
			if default ~= nil then
				-- Factory defaults keep their current value
				if type(default) ~= "function" then
					props[key] = default
				end
			else
				props[key] = nil
			end
		end
	end

	for key, value in nextProps do
		props[key] = value
	end

	-- Write through the proxy so only effects that read a changed attr re-run
	local attrs = instance.attrs
	for key in _reactivity.toRaw(attrs) do
		if nextAttrs[key] == nil then
			attrs[key] = nil
		end
	end
	for key, value in nextAttrs do
		attrs[key] = value
	end
end

--- Replaces a component's slots in place (ctx.slots points at the same table)
local function updateComponentSlots(instance: ComponentInstance, children: { Child }, slots: Types.Slots?): boolean
	local defaultSlots = instance.slots
	local namedSlots = instance.namedSlots
	if #defaultSlots == 0 and #children == 0 and next(namedSlots) == nil and slots == nil then
		return false
	end
	-- A vnode patched against itself passes the instance's own slot table, which clearing would empty
	if children ~= defaultSlots then
		table.clear(defaultSlots)
		table.move(children, 1, #children, 1, defaultSlots)
	end
	table.clear(namedSlots)
	if slots then
		for name, fn in slots do
			namedSlots[name] = fn
		end
	end
	return true
end

--- name: "before-enter", "enter", "after-enter", "before-leave", "leave" or "after-leave"
local function onTransition(name: string, fn: (el: Instance) -> ()): ()
	local inst = currentInstance
	if not inst then
		error("onTransition must be called within setup()", 2)
	end

	local hooks: { [string]: { (el: Instance) -> () } } = inst._transitionHooks or {}
	inst._transitionHooks = hooks

	local list = hooks[name] or {}
	hooks[name] = list
	table.insert(list, fn)
end

-- Only a marker: the renderer implements Teleport
local Teleport: ComponentDef = table.freeze({
	__is_component = true :: true,
	__name = "Teleport",
})

return {
	devtoolsHooks = devtoolsHooks,
	createComponentInstance = createComponentInstance,
	updateComponentProps = updateComponentProps,
	propsUnchanged = propsUnchanged,
	updateComponentSlots = updateComponentSlots,
	onBeforeMount = onBeforeMount,
	onMounted = onMounted,
	onBeforeUpdate = onBeforeUpdate,
	onUpdated = onUpdated,
	onBeforeUnmount = onBeforeUnmount,
	onUnmounted = onUnmounted,
	onActivated = onActivated,
	onDeactivated = onDeactivated,
	onRenderTracked = onRenderTracked,
	onRenderTriggered = onRenderTriggered,
	runWithInjectionContext = runWithInjectionContext,
	hasInjectionContext = hasInjectionContext,
	formatComponentTrace = formatComponentTrace,
	useId = useId,
	useTemplateRef = useTemplateRef,
	onErrorCaptured = onErrorCaptured,
	provide = provide,
	inject = inject,
	onTransition = onTransition,
	setCurrentInstance = setCurrentInstance,
	getCurrentInstance = getCurrentInstance,
	setRenderingInstance = setRenderingInstance,
	getRenderingInstance = getRenderingInstance,
	Teleport = Teleport,
}
