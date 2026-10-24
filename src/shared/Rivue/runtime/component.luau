--!strict
--!optimize 2
--!native

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

export type ErrorCapturedHook = (err: string, instance: ComponentInstance, info: string) -> boolean?

--- Names of the lifecycle callback lists on an instance (singleton union, so typos fail type checking)
type HookList = "beforeMountCbs" | "mountedCbs" | "beforeUpdateCbs" | "updatedCbs" | "beforeUnmountCbs" | "unmountedCbs"

-- Component instances are a class: methods live once on this metatable instead of being
-- recreated as closures for every mounted component.
local ComponentInstance = {}
ComponentInstance.__index = ComponentInstance

type InstanceData = {
	vnode: VNode,
	type: ComponentDef,
	props: Props,
	attrs: Props,
	parent: ComponentInstance?,
	provides: { [string]: unknown },
	isMounted: boolean,
	subTree: VNode?,
	el: Instance?,
	cleanupCbs: { () -> () },
	beforeMountCbs: { () -> () },
	mountedCbs: { () -> () },
	beforeUpdateCbs: { () -> () },
	updatedCbs: { () -> () },
	beforeUnmountCbs: { () -> () },
	unmountedCbs: { () -> () },
	errorCapturedCbs: { ErrorCapturedHook },
	slots: { Child },
	render: RenderFunction?,
	setupState: { render: RenderFunction, [string]: unknown }?,
	exposed: { [string]: unknown }?,
	ctx: SetupContext,
	-- Cleanup bookkeeping (filled by main's watch/effect/queueJob wrappers and the renderer)
	_effects: { WatchStopHandle | Effect },
	_schedulerJobs: { JobHandle },
	_scope: EffectScope?,
	_renderEffect: Effect?,
	_transitionHooks: { [string]: { (el: Instance) -> () } }?,
}

export type ComponentInstance = typeof(setmetatable({} :: InstanceData, ComponentInstance))

const IS_STUDIO = RunService:IsStudio()

local currentInstance: ComponentInstance? = nil

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

--- Builds a lifecycle hook registration function (onMounted, onUpdated, ...)
--- @param hookName string -- Public name, used in error messages
--- @param list HookList -- Instance callback list the hook appends to
--- @return (fn: () -> ()) -> () -- Registration function
local function createHook(hookName: string, list: HookList): (fn: () -> ()) -> ()
	return function(fn: () -> ())
		local inst = currentInstance
		if not inst then
			error(`{hookName} must be called in setup`, 2)
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
			-- Factory defaults give each instance its own table
			props[name] = if type(defaultVal) == "function" then (defaultVal :: () -> unknown)() else defaultVal
		end
	end
end

--- Separates declared props from non-declared attrs
--- @param schema PropSchema? -- Prop schema definition
--- @param allProps Props -- All incoming props
--- @return Props -- Declared props
--- @return Props -- Non-declared attrs
local function separatePropsAndAttrs(schema: PropSchema?, allProps: Props): (Props, Props)
	if not schema then
		return allProps, {}
	end

	local props: Props = {}
	local attrs: Props = {}

	for key, value in allProps do
		if schema[key] then
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

		-- PropTypeName values match type() results, so a direct comparison is enough
		local expected = spec.type
		if val ~= nil and expected and type(val) ~= expected then
			table.insert(errs, `prop '{name}' expected {expected} got {type(val)}`)
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

--- Runs a list of lifecycle callbacks, isolating errors per callback
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

--- Runs setup() (or resolves render) and stores the component's render function
function ComponentInstance.setupComponent(self: ComponentInstance)
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
				debugModule.log("Component", `Prop validation failed: {err}`)
			end
		end
	end

	-- Effects/computeds/watchers created in setup belong to this scope and stop on unmount
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
			setCurrentInstance(nil)
			error(setupErr, 0)
		end
	end
	setCurrentInstance(nil)

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
		error("Component must provide setup() or render()")
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

function ComponentInstance.runBeforeUnmount(self: ComponentInstance)
	runCallbacks(self, self.beforeUnmountCbs, "beforeUnmount hook")
end

--- Runs unmounted callbacks, then tears down everything the component created
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
			-- Stop handle from watch()/watchEffect()
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

--- Propagates an error up the parent chain until an onErrorCaptured handler returns true
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
	-- If no handler consumed it, log it
	debugModule.log("Component", `Unhandled component error: {err}`, { info = info })
end

--- Creates the setup() context bound to an instance
--- @param instance ComponentInstance -- Owning instance
--- @return SetupContext -- Context passed as setup's second argument
local function createSetupContext(instance: ComponentInstance): SetupContext
	return {
		emit = function(eventName: string, ...: any): ()
			local handlerName = `on{eventName:sub(1, 1):upper()}{eventName:sub(2)}`
			local handler = instance.props[handlerName] or instance.attrs[handlerName]

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
			local cur: ComponentInstance? = instance

			while cur do
				local provided = cur.provides[key]
				if provided ~= nil then
					return provided
				end
				cur = cur.parent
			end

			return default
		end,
		slots = instance.slots,
		attrs = instance.attrs,
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
--- @return ComponentInstance -- New component instance
--- @return SetupContext -- Component context for setup
local function createComponentInstance(vnode: VNode, parent: ComponentInstance?): (ComponentInstance, SetupContext)
	local def = vnode.type :: ComponentDef
	if debugModule.enabled then
		debugModule.log("Component", "Creating component instance", {
			type = def.__name or "AnonymousComponent",
			hasParent = parent ~= nil,
			childCount = #vnode.children,
		})
	end

	-- Copy parent provides so siblings never share (and mutate) one provides table
	local provides: { [string]: unknown } = if parent then table.clone(parent.provides) else {}

	-- Separate declared props from attrs
	local declaredProps, attrs = separatePropsAndAttrs(def.props, vnode.props or {})
	-- Props are shallow-reactive so the render effect re-runs when a parent passes new values.
	-- Cloned so updates never write into the parent's vnode.props table.
	local props = _reactivity.shallowReactive(table.clone(declaredProps))

	local data: InstanceData = {
		vnode = vnode,
		type = def,
		props = props,
		attrs = attrs,
		parent = parent,
		provides = provides,
		isMounted = false,
		subTree = nil,
		el = nil,
		cleanupCbs = {},
		beforeMountCbs = {},
		mountedCbs = {},
		beforeUpdateCbs = {},
		updatedCbs = {},
		beforeUnmountCbs = {},
		unmountedCbs = {},
		errorCapturedCbs = {},
		slots = vnode.children,
		render = nil,
		setupState = nil,
		exposed = nil,
		ctx = nil :: any, -- assigned right below (needs the instance)
		_effects = {},
		_schedulerJobs = {},
		_scope = nil,
		_renderEffect = nil,
		_transitionHooks = nil,
	}
	local instance = setmetatable(data, ComponentInstance)
	instance.ctx = createSetupContext(instance)

	return instance, instance.ctx
end

--- Applies new incoming props to a mounted component instance
--- Only changed keys are written, so only render effects that read them re-run
--- @param instance ComponentInstance -- Mounted component instance
--- @param rawProps Props? -- New props from the parent's vnode
local function updateComponentProps(instance: ComponentInstance, rawProps: Props?): ()
	local schema = instance.type.props
	local nextProps, nextAttrs = separatePropsAndAttrs(schema, rawProps or {})
	local props = instance.props
	local current = _reactivity.toRaw(props)

	for key in current do
		if nextProps[key] == nil then
			local spec = if schema then schema[key] else nil
			local default = if spec then spec.default else nil
			if default ~= nil then
				-- Fall back to the default; keep factory defaults as-is to avoid needless re-renders
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

	-- attrs is shared with ctx.attrs, so update it in place
	table.clear(instance.attrs)
	for key, value in nextAttrs do
		instance.attrs[key] = value
	end
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
	onBeforeMount = onBeforeMount,
	onMounted = onMounted,
	onBeforeUpdate = onBeforeUpdate,
	onUpdated = onUpdated,
	onBeforeUnmount = onBeforeUnmount,
	onUnmounted = onUnmounted,
	onErrorCaptured = onErrorCaptured,
	onTransition = onTransition,
	setCurrentInstance = setCurrentInstance,
	getCurrentInstance = getCurrentInstance,
	Teleport = Teleport,
}
