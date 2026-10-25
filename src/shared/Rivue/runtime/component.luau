--!strict
--!optimize 2

--[[
	component.luau
	==============
	
	Component instance lifecycle management with prop schema validation, dependency injection,
	and lifecycle hook registration for Vue.js-inspired component architecture.

    @module component

	@author Rivue

	@version 1.0.0
	
	
	Type Definitions:
	-----------------
	
	type PropSchema = {
		[string]: {
			type: string?,          -- Expected type: "string" | "number" | "boolean" | "function" | "table"
			required: boolean?      -- Whether prop is required
		}
	}
	
	type ComponentDef = {
		__is_component: boolean,
		setup: ((props: any, ctx: ComponentContext) -> any)?,
		render: ((props: any) -> VNode)?,
		props: PropSchema?,
		__name: string?
	}
	
	type ComponentInstance = {
		vnode: VNode,
		type: ComponentDef,
		props: { [string]: any },
		parent: ComponentInstance?,
		provides: { [string]: any },
		isMounted: boolean,
		subTree: VNode?,
		el: Instance?,
		cleanupCbs: { () -> () },
		mountedCbs: { () -> () },
		updatedCbs: { () -> () },
		unmountedCbs: { () -> () },
		slots: { VNode },
		pendingJobs: { any },
		setupComponent: (self: ComponentInstance) -> (),
		runMounted: (self: ComponentInstance) -> (),
		runUpdated: (self: ComponentInstance) -> (),
		runUnmounted: (self: ComponentInstance) -> ()
	}
	
	type ComponentContext = {
		emit: (eventName: string, ...any) -> (),
		provide: (key: string, value: any) -> (),
		inject: (key: string, default: any?) -> any?,
		slots: { VNode },
		onUnmounted: (fn: () -> ()) -> ()
	}
	
	Public API:
	-----------
	
	createComponentInstance(vnode: VNode, parent: ComponentInstance?) -> (ComponentInstance, ComponentContext)
		Creates a new component instance with lifecycle hooks and dependency injection.
		Validates props in Studio mode if schema is provided.
	
	onMounted(fn: () -> ()) -> ()
		Registers a callback to run after component is mounted to DOM.
		Must be called during setup() phase.
	
	onUpdated(fn: () -> ()) -> ()
		Registers a callback to run after component updates and re-renders.
		Must be called during setup() phase.
	
	onUnmounted(fn: () -> ()) -> ()
		Registers a callback to run before component is unmounted.
		Must be called during setup() phase.
	
	setCurrentInstance(instance: ComponentInstance?) -> ()
		Sets the active component instance for lifecycle hook registration.
		Internal API - used by renderer during setup phase.
	
	getCurrentInstance() -> ComponentInstance?
		Returns the currently active component instance.
		Used by lifecycle hooks to register callbacks.
	
	Usage Example:
	--------------
	
	local MyButton = {
		__is_component = true,
		props = {
			label = { type = "string", required = true },
			onClick = { type = "function" }
		},
		setup = function(props, ctx)
			onMounted(function()
				print("Button mounted!")
			end)
			
			ctx.onUnmounted(function()
				print("Button unmounted!")
			end)
			
			return function()
				return h("TextButton", {
					Text = props.label,
					onClick = props.onClick
				})
			end
		end
	}
	
	Implementation Notes:
	---------------------
	
	- Component instances maintain parent-child hierarchy for provide/inject
	- Prop validation only runs in Studio mode (dev mode)
	- Lifecycle hooks execute in registration order
	- All lifecycle callbacks are pcall-wrapped for error safety
	- Current instance tracking enables hook registration during setup
	- Context object provides scoped utilities: emit, provide/inject, slots
]]

local Types = require(script.Parent:WaitForChild("types"))
local _reactivity = require(script.Parent:WaitForChild("reactivity"))
local RunService = game:GetService("RunService")
local debugModule = require(script.Parent:WaitForChild("debug"))

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

-- Shared methods for component instances
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
	-- Inherits parent provides through __index
	provides: { [unknown]: unknown },
	appContext: AppContext,
	isMounted: boolean,
	isUnmounted: boolean,
	-- Cached by KeepAlive and detached
	isDeactivated: boolean,
	subTree: VNode?,
	el: Instance?,
	-- Instance the subtree is patched into
	container: Instance?,
	-- String template refs (ref = "name") and their useTemplateRef() refs
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
	-- Debug hooks, called with what a render read / what made it re-render
	renderTrackedCbs: { (event: Types.DebuggerEvent) -> () },
	renderTriggeredCbs: { (event: Types.DebuggerEvent) -> () },
	errorCapturedCbs: { ErrorCapturedHook },
	slots: { Child },
	namedSlots: Types.Slots,
	render: RenderFunction?,
	setupState: { render: RenderFunction, [string]: unknown }?,
	exposed: { [string]: unknown }?,
	ctx: SetupContext,
	-- Cleanup tracking (filled by main.luau wrappers and the renderer)
	_effects: { WatchStopHandle | Types.WatchHandle | Effect },
	_schedulerJobs: { JobHandle },
	_scope: EffectScope?,
	_renderEffect: Effect?,
	_transitionHooks: { [string]: { (el: Instance) -> () } }?,
	-- A render was skipped while deactivated
	_pendingUpdate: boolean,
	-- useId() counter
	_idCount: number,
	-- Set by the renderer on KeepAlive instances
	_keepAliveRenderer: { unmount: (vnode: VNode) -> () }?,
}

export type ComponentInstance = typeof(setmetatable({} :: InstanceData, ComponentInstance))

const IS_STUDIO = RunService:IsStudio()

local currentInstance: ComponentInstance? = nil
-- Component whose render() is running, owner of the vnodes it creates
local currentRenderingInstance: ComponentInstance? = nil
local uidCounter = 0

-- Used when a component is mounted outside createApp (e.g. renderer.patch directly)
const EMPTY_APP_CONTEXT: AppContext = { provides = {}, config = { globalProperties = {} }, components = {} }

--- Sets the current active component instance for lifecycle hook registration
--- @param i ComponentInstance? -- Instance to set as current (or nil)
local function setCurrentInstance(i: ComponentInstance?): ()
	currentInstance = i
end

--- Gets the currently active component instance
--- @return ComponentInstance? -- Current instance or nil
local function getCurrentInstance(): ComponentInstance?
	return currentInstance
end

--- Sets the component whose render() is running
--- @param i ComponentInstance? -- Rendering instance (or nil)
--- @return ComponentInstance? -- Previous one, to restore after
local function setRenderingInstance(i: ComponentInstance?): ComponentInstance?
	local prev = currentRenderingInstance
	currentRenderingInstance = i
	return prev
end

--- Gets the component whose render() is running
--- @return ComponentInstance? -- Rendering instance or nil
local function getRenderingInstance(): ComponentInstance?
	return currentRenderingInstance
end

--- Creates a lifecycle hook registrar (onMounted, onUpdated, ...)
--- @param hookName string -- Public name, used in error messages
--- @param list HookList -- Instance callback list the hook appends to
--- @return (fn: () -> ()) -> () -- Registration function
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
-- KeepAlive: runs on mount and every time the component comes back from the cache
local onActivated = createHook("onActivated", "activatedCbs")
local onDeactivated = createHook("onDeactivated", "deactivatedCbs")
-- Debugging: what the render read, and what made it re-render
local onRenderTracked =
	createHook("onRenderTracked", "renderTrackedCbs") :: (fn: (event: Types.DebuggerEvent) -> ()) -> ()
local onRenderTriggered =
	createHook("onRenderTriggered", "renderTriggeredCbs") :: (fn: (event: Types.DebuggerEvent) -> ()) -> ()

-- App context set by app:runWithContext(), so inject() works outside components
local injectionContext: AppContext? = nil

--- Runs fn with an app's provides available to inject()
--- @param context AppContext -- App context
--- @param fn () -> T -- Work
--- @return T -- fn's result
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

--- True when inject() can be called here (in setup, or inside app:runWithContext())
--- @return boolean -- Has an injection context
local function hasInjectionContext(): boolean
	return currentInstance ~= nil or injectionContext ~= nil
end

--- Formats the component chain for error messages: <Button> in <Toolbar> in <App>
--- @param inst ComponentInstance? -- Innermost component
--- @return string -- Readable trace
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

--- Returns an id that's unique for this app session, handy for Instance names
--- @return string -- e.g. "r12-1"
local function useId(): string
	local inst = currentInstance
	if inst then
		inst._idCount += 1
		return `r{inst.uid}-{inst._idCount}`
	end
	idCounter += 1
	return `r0-{idCounter}`
end

--- Gets a ref filled with the element rendered with `ref = name` (call in setup)
--- @param name string -- Ref name used in h()
--- @return Ref<T?> -- Holds the Instance (or exposed component API) while mounted
local function useTemplateRef<T>(name: string): Types.Ref<T?>
	local inst = currentInstance
	if not inst then
		error("useTemplateRef() must be called in setup", 2)
	end
	local r = _reactivity.shallowRef(inst.refs[name] :: T?)
	inst.templateRefs[name] = r :: any
	return r
end

--- Provides a value to all descendants (call in setup)
--- @param key unknown -- Injection key
--- @param value unknown -- Provided value
local function provide(key: unknown, value: unknown): ()
	local inst = currentInstance
	if not inst then
		error("provide() must be called in setup", 2)
	end
	inst.provides[key] = value
end

--- Gets a value provided by an ancestor or the app (call in setup)
--- @param key unknown -- Injection key
--- @param default T? -- Returned when nothing was provided
--- @return T? -- Provided value or default
local function inject<T>(key: unknown, default: T?): T?
	local inst = currentInstance
	local provided: unknown
	if inst then
		provided = inst.provides[key]
	elseif injectionContext then
		provided = injectionContext.provides[key]
	else
		error("inject() must be called inside setup() or app:runWithContext()", 2)
	end
	return if provided ~= nil then provided :: T else default
end

--- Registers an error handler to catch errors in child components
--- @param fn ErrorCapturedHook -- Error handler (return true to stop propagation)
local function onErrorCaptured(fn: ErrorCapturedHook): ()
	local inst = currentInstance
	if not inst then
		error("onErrorCaptured must be called in setup", 2)
	end

	table.insert(inst.errorCapturedCbs, fn)
end

--- Applies default values to props based on schema
--- @param schema PropSchema -- Prop schema definition
--- @param props Props -- Props object to apply defaults to
local function applyPropDefaults(schema: PropSchema, props: Props): ()
	for name, spec in schema do
		local defaultVal = spec.default
		if props[name] == nil and defaultVal ~= nil then
			props[name] = if type(defaultVal) == "function" then (defaultVal :: () -> unknown)() else defaultVal
		end
	end
end

--- Turns an event name into its handler prop ("select" -> "onSelect")
--- @param eventName string -- Event name
--- @return string -- Handler prop name
local function toHandlerKey(eventName: string): string
	return `on{eventName:sub(1, 1):upper()}{eventName:sub(2)}`
end

-- def -> handler prop names of its declared emits
local emitKeysCache: { [ComponentDef]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any

--- Gets the handler props ("onSelect") of a component's declared emits
--- @param def ComponentDef -- Component definition
--- @return { [string]: string }? -- Handler prop -> event name, nil when emits isn't declared
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

--- Separates declared props from non-declared attrs (declared emit listeners go to neither)
--- @param def ComponentDef -- Component definition
--- @param allProps Props -- All incoming props
--- @return Props -- Declared props
--- @return Props -- Non-declared attrs
local function separatePropsAndAttrs(def: ComponentDef, allProps: Props): (Props, Props)
	local schema = def.props
	local emitKeys = getEmitKeys(def)
	if not schema and not emitKeys then
		return allProps, {}
	end

	local props: Props = {}
	local attrs: Props = {}

	for key, value in allProps do
		if emitKeys and emitKeys[key] then
			continue
		end
		-- Without a schema every prop is declared
		if not schema or schema[key] then
			props[key] = value
		else
			attrs[key] = value
		end
	end

	return props, attrs
end

--- Validates props against schema (only in Studio mode)
--- @param schema PropSchema? -- Prop schema definition
--- @param props Props -- Props to validate
--- @return boolean -- True if valid
--- @return string? -- Error message if invalid
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

		-- Run custom validator if provided
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

--- Runs lifecycle callbacks, reporting errors through handleError
--- @param self ComponentInstance -- Owning instance (for error reporting)
--- @param callbacks { () -> () } -- Callbacks to run
--- @param info string -- Lifecycle phase name
local function runCallbacks(self: ComponentInstance, callbacks: { () -> () }, info: string)
	for _, fn in callbacks do
		local ok, err = pcall(fn :: () -> ...unknown)
		if not ok then
			self:handleError(tostring(err), info)
		end
	end
end

--- Runs setup() and resolves the render function
function ComponentInstance.setupComponent(self: ComponentInstance)
	-- Restored after, setup can mount other components
	local prevInstance = currentInstance
	setCurrentInstance(self)

	local def = self.type
	local schema = def.props

	-- Apply default prop values
	if schema then
		applyPropDefaults(schema, self.props)

		-- Validate props in Studio mode
		if IS_STUDIO then
			local ok, err = validateProps(schema, self.props)
			if not ok then
				warn(`[Rivue] Invalid props for {formatComponentTrace(self)}: {err}`)
			end
		end
	end

	-- Effects created in setup are stopped on unmount
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
		self.render = function()
			return render(self.props)
		end
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

--- True when a parent (or this component) is cached by KeepAlive
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

--- Runs unmounted callbacks and cleans up effects/jobs
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

	-- Auto-cleanup: Cancel all tracked scheduler jobs
	for _, jobHandle in self._schedulerJobs do
		pcall(jobHandle.cancel)
	end
	table.clear(self._schedulerJobs)

	-- Auto-cleanup: Stop all tracked effects/watchers
	for _, tracked in self._effects do
		if type(tracked) == "function" then
			-- Stop handle from watch()
			pcall(tracked)
		else
			-- Effect object from effect()
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

--- Passes an error up the parent chain until a handler returns true
--- @param err string -- Error message
--- @param info string -- Where the error happened
function ComponentInstance.handleError(self: ComponentInstance, err: string, info: string)
	local cur = self.parent
	while cur do
		for _, handler in cur.errorCapturedCbs do
			local ok, stop = pcall(handler, err, self, info)
			if ok and stop == true then
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
	-- Nothing handled it, always report
	warn(`[Rivue] Error in {info} of {formatComponentTrace(self)}: {err}`)
end

--- Normalizes what a slot function returned to a list of children
--- @param result unknown -- Slot return value
--- @return { Child } -- Children list
local function toChildList(result: unknown): { Child }
	if result == nil then
		return {}
	elseif type(result) == "table" and (result :: { [unknown]: unknown }).type == nil then
		return result :: { Child }
	end
	return { result :: Child }
end

--- Creates the setup() context for an instance
--- @param instance ComponentInstance -- Owning instance
--- @return SetupContext -- Context passed as setup's second argument
local function createSetupContext(instance: ComponentInstance): SetupContext
	return {
		emit = function(eventName: string, ...: any): ()
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
			local provided = instance.provides[key]
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

--- Creates a new component instance with lifecycle management
--- @param vnode VNode -- Virtual node representing the component
--- @param parent ComponentInstance? -- Parent component instance (for provide/inject and error propagation)
--- @param appContext AppContext? -- App context for root components (children inherit the parent's)
--- @return ComponentInstance -- New component instance
--- @return SetupContext -- Component context for setup
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

	-- Separate declared props from attrs
	local declaredProps, attrs = separatePropsAndAttrs(def, vnode.props or {})
	-- Shallow reactive so the component re-renders on new props
	local props = _reactivity.shallowReactive(table.clone(declaredProps))
	-- Reactive too, so fallthrough attrs re-render the component when they change
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
		ctx = nil :: any, -- set below
		_effects = {},
		_schedulerJobs = {},
		_scope = nil,
		_renderEffect = nil,
		_transitionHooks = nil,
		_pendingUpdate = false,
		_idCount = 0,
		_keepAliveRenderer = nil,
	}
	local instance = setmetatable(data, ComponentInstance)
	instance.ctx = createSetupContext(instance)

	return instance, instance.ctx
end

--- Applies new incoming props to a mounted component instance
--- @param instance ComponentInstance -- Mounted component instance
--- @param rawProps Props? -- New props from the parent's vnode
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
				-- Fall back to the default (factory defaults keep their current value)
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
--- @param instance ComponentInstance -- Mounted component instance
--- @param children { Child } -- New default children from the parent's vnode
--- @param slots Types.Slots? -- New named slot functions
--- @return boolean -- True if the component had or now has slot content
local function updateComponentSlots(instance: ComponentInstance, children: { Child }, slots: Types.Slots?): boolean
	local defaultSlots = instance.slots
	local namedSlots = instance.namedSlots
	if #defaultSlots == 0 and #children == 0 and next(namedSlots) == nil and slots == nil then
		return false
	end
	table.clear(defaultSlots)
	table.move(children, 1, #children, 1, defaultSlots)
	table.clear(namedSlots)
	if slots then
		for name, fn in slots do
			namedSlots[name] = fn
		end
	end
	return true
end

--- Registers a transition hook to run before/after element transitions
--- Transition hooks allow coordinated animations across multiple elements
--- @param name string -- Hook name: "before-enter", "enter", "after-enter", "before-leave", "leave", "after-leave"
--- @param fn (el: Instance) -> () -- Callback function
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

--- Built-in Teleport component for rendering content in a different location
--- Usage: h(Teleport, { to = targetInstance }, children)
--- Note: Teleport is handled specially by the renderer, not through normal render flow
local Teleport: ComponentDef = table.freeze({
	__is_component = true :: true,
	__name = "Teleport",
})

return {
	createComponentInstance = createComponentInstance,
	updateComponentProps = updateComponentProps,
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
