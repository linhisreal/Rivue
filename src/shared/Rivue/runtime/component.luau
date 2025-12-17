--!strict
--!optimize 2
--!native

--[[
	component.luau
	==============
	
	Component instance lifecycle management with prop schema validation, dependency injection,
	and lifecycle hook registration for Vue.js-inspired component architecture.

    @module directives

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

type PropSpec = {
	type: string?,
	required: boolean?,
	default: any?,
	validator: ((value: any) -> boolean)?,
}

type PropSchema = { [string]: PropSpec }

type ComponentDef = {
	__is_component: boolean,
	setup: ((props: any, ctx: any) -> any)?,
	render: ((props: any) -> any)?,
	props: PropSchema?,
	__name: string?,
	inheritAttrs: boolean?,
}

type VNode = {
	type: any,
	props: { [string]: any }?,
	children: { any },
	key: any?,
}

type ComponentInstance = {
	vnode: VNode,
	type: ComponentDef | any,
	props: { [string]: any },
	attrs: { [string]: any },
	parent: ComponentInstance?,
	provides: { [string]: any },
	isMounted: boolean,
	subTree: any,
	el: Instance?,
	cleanupCbs: { () -> () },
	beforeMountCbs: { () -> () },
	mountedCbs: { () -> () },
	beforeUpdateCbs: { () -> () },
	updatedCbs: { () -> () },
	beforeUnmountCbs: { () -> () },
	unmountedCbs: { () -> () },
	slots: { any },
	pendingJobs: { any },
	render: ((any) -> any)?,
	setupState: any,
	exposed: { [string]: any }?,
	setupComponent: (self: ComponentInstance) -> (),
	runBeforeMount: (self: ComponentInstance) -> (),
	runMounted: (self: ComponentInstance) -> (),
	runBeforeUpdate: (self: ComponentInstance) -> (),
	runUpdated: (self: ComponentInstance) -> (),
	runBeforeUnmount: (self: ComponentInstance) -> (),
	runUnmounted: (self: ComponentInstance) -> (),
	handleError: (self: ComponentInstance, err: string, info: string) -> (),
	errorCapturedCbs: { (err: string, instance: any, info: string) -> boolean? },
}

type ComponentContext = {
	emit: (eventName: string, ...any) -> (),
	provide: (key: string, value: any) -> (),
	inject: (key: string, default: any?) -> any?,
	slots: { any },
	attrs: { [string]: any },
	expose: (exposed: { [string]: any }?) -> (),
	onUnmounted: (fn: () -> ()) -> (),
}

local _reactivity = require(script.Parent:WaitForChild("reactivity"))
local RunService = game:GetService("RunService")
local debugModule = require(script.Parent:WaitForChild("debug"))

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

--- Registers a callback to run after component is mounted
--- @param fn () -> () -- Callback function
local function onMounted(fn: () -> ()): ()
	local inst = getCurrentInstance()

	if not inst then
		error("onMounted must be called in setup")
	end

	debugModule.log(
		"Component",
		"Registered onMounted callback",
		{ component = inst.type.__name or "Anonymous", totalCallbacks = #inst.mountedCbs + 1 }
	)
	table.insert(inst.mountedCbs, fn)
end

--- Registers a callback to run before component is mounted
--- @param fn () -> () -- Callback function
local function onBeforeMount(fn: () -> ()): ()
	local inst = getCurrentInstance()

	if not inst then
		error("onBeforeMount must be called in setup")
	end

	debugModule.log("Component", "Registered onBeforeMount callback", { component = inst.type.__name or "Anonymous" })
	table.insert((inst :: any).beforeMountCbs, fn)
end

--- Registers a callback to run after component updates
--- @param fn () -> () -- Callback function
local function onUpdated(fn: () -> ()): ()
	local inst = getCurrentInstance()

	if not inst then
		error("onUpdated must be called in setup")
	end

	debugModule.log("Component", "Registered onUpdated callback", { component = inst.type.__name or "Anonymous" })
	table.insert(inst.updatedCbs, fn)
end

--- Registers a callback to run before component updates
--- @param fn () -> () -- Callback function
local function onBeforeUpdate(fn: () -> ()): ()
	local inst = getCurrentInstance()

	if not inst then
		error("onBeforeUpdate must be called in setup")
	end

	debugModule.log("Component", "Registered onBeforeUpdate callback", { component = inst.type.__name or "Anonymous" })
	table.insert((inst :: any).beforeUpdateCbs, fn)
end

--- Registers a callback to run before component unmounts
--- @param fn () -> () -- Callback function
local function onUnmounted(fn: () -> ()): ()
	local inst = getCurrentInstance()

	if not inst then
		error("onUnmounted must be called in setup")
	end

	debugModule.log(
		"Component",
		"Registered onUnmounted callback",
		{ component = inst.type.__name or "Anonymous", totalCallbacks = #inst.unmountedCbs + 1 }
	)
	table.insert(inst.unmountedCbs, fn)
end

--- Registers a callback to run before component unmounts (before cleanup)
--- @param fn () -> () -- Callback function
local function onBeforeUnmount(fn: () -> ()): ()
	local inst = getCurrentInstance()

	if not inst then
		error("onBeforeUnmount must be called in setup")
	end

	debugModule.log("Component", "Registered onBeforeUnmount callback", { component = inst.type.__name or "Anonymous" })
	table.insert((inst :: any).beforeUnmountCbs, fn)
end

--- Registers an error handler to catch errors in child components
--- @param fn (err: string, instance: ComponentInstance, info: string) -> boolean? -- Error handler (return true to stop propagation)
local function onErrorCaptured(fn: (err: string, instance: any, info: string) -> boolean?): ()
	local inst = getCurrentInstance()

	if not inst then
		error("onErrorCaptured must be called in setup")
	end

	debugModule.log("Component", "Registered onErrorCaptured handler", { component = inst.type.__name or "Anonymous" })
	table.insert((inst :: any).errorCapturedCbs, fn)
end

--- Applies default values to props based on schema
--- @param schema PropSchema -- Prop schema definition
--- @param props { [string]: any } -- Props object to apply defaults to
local function applyPropDefaults(schema: PropSchema, props: { [string]: any }): ()
	for name, spec in pairs(schema) do
		if props[name] == nil and spec.default ~= nil then
			local defaultVal = spec.default
			if type(defaultVal) == "function" then
				props[name] = (defaultVal :: any)()
			else
				props[name] = defaultVal
			end
		end
	end
end

--- Separates declared props from non-declared attrs
--- @param schema PropSchema? -- Prop schema definition
--- @param allProps { [string]: any } -- All incoming props
--- @return { [string]: any } -- Declared props
--- @return { [string]: any } -- Non-declared attrs
local function separatePropsAndAttrs(
	schema: PropSchema?,
	allProps: { [string]: any }
): ({ [string]: any }, { [string]: any })
	if not schema then
		return allProps, {}
	end

	local props = {}
	local attrs = {}

	for key, value in pairs(allProps) do
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
--- @param props { [string]: any } -- Props to validate
--- @return boolean -- True if valid
--- @return string? -- Error message if invalid
local function validateProps(schema: PropSchema?, props: { [string]: any }): (boolean, string?)
	if not schema then
		return true, nil
	end

	local errs: { string } = {}

	for name, spec in pairs(schema) do
		local val = props[name]

		if spec.required and val == nil then
			table.insert(errs, ("prop '%s' required"):format(name))
		end

		if val ~= nil and spec.type then
			local t = type(val)
			local ok = false

			if spec.type == "table" then
				ok = t == "table"
			elseif spec.type == "number" then
				ok = t == "number"
			elseif spec.type == "string" then
				ok = t == "string"
			elseif spec.type == "boolean" then
				ok = t == "boolean"
			elseif spec.type == "function" then
				ok = t == "function"
			else
				ok = true
			end

			if not ok then
				table.insert(errs, ("prop '%s' expected %s got %s"):format(name, spec.type, t))
			end
		end

		-- Run custom validator if provided
		if val ~= nil and spec.validator then
			local ok, result = pcall(spec.validator, val)

			if not ok or result == false then
				table.insert(errs, ("prop '%s' failed custom validation"):format(name))
			end
		end
	end

	if #errs > 0 then
		return false, table.concat(errs, "; ")
	end

	return true, nil
end

--- Creates a new component instance with lifecycle management
--- @param vnode VNode -- Virtual node representing the component
--- @param parent ComponentInstance? -- Parent component instance
--- @return ComponentInstance -- New component instance
--- @return ComponentContext -- Component context for setup
local function createComponentInstance(vnode: VNode, parent: ComponentInstance?): (ComponentInstance, ComponentContext)
	if debugModule.enabled then
		debugModule.log("Component", "Creating component instance", {
			type = vnode.type.__name or "AnonymousComponent",
			hasParent = parent ~= nil,
			childCount = vnode.children and #vnode.children or 0,
		})
	end
	-- Create new provides table with parent provides as prototype (shallow copy)
	-- This prevents sibling components from sharing the same provides reference
	local provides = {}
	if parent and parent.provides then
		for k, v in pairs(parent.provides) do
			provides[k] = v
		end
	end

	-- Separate declared props from attrs
	local allProps = vnode.props or {}
	local declaredProps, attrs = separatePropsAndAttrs(vnode.type.props, allProps)
	-- Props are shallow-reactive so the render effect re-runs when a parent passes new values.
	-- Cloned so updates never write into the parent's vnode.props table.
	local props = _reactivity.shallowReactive(table.clone(declaredProps))

	local instance: ComponentInstance = {
		vnode = vnode,
		type = vnode.type,
		props = props,
		attrs = attrs,
		parent = parent,
		provides = provides,
		isMounted = false,
		subTree = nil :: any,
		el = nil,
		cleanupCbs = {},
		beforeMountCbs = {},
		mountedCbs = {},
		beforeUpdateCbs = {},
		updatedCbs = {},
		beforeUnmountCbs = {},
		unmountedCbs = {},
		errorCapturedCbs = {},
		slots = vnode.children or {},
		pendingJobs = {},
		render = nil,
		setupState = nil,
		exposed = nil,
		setupComponent = nil :: any,
		runBeforeMount = nil :: any,
		runMounted = nil :: any,
		runBeforeUpdate = nil :: any,
		runUpdated = nil :: any,
		runBeforeUnmount = nil :: any,
		runUnmounted = nil :: any,
		handleError = nil :: any,
	}

	-- Track effects/watchers created during setup for auto-cleanup
	(instance :: any)._effects = {}
	-- Track scheduler jobs created during setup for auto-cleanup
	(instance :: any)._schedulerJobs = {}

	local ctx: ComponentContext = {
		emit = function(eventName: string, ...: any): ()
			local handlerName = "on" .. (eventName:sub(1, 1):upper() .. eventName:sub(2))
			local handler = instance.props and instance.props[handlerName]

			if type(handler) == "function" then
				pcall(handler :: any, ...)
			end
		end,
		provide = function(key: string, val: any): ()
			instance.provides = instance.provides or {}
			instance.provides[key] = val
		end,
		inject = function(key: string, default: any?): any?
			local cur: ComponentInstance? = instance

			while cur do
				if cur.provides and cur.provides[key] ~= nil then
					return cur.provides[key]
				end

				cur = cur.parent
			end

			return default
		end,
		slots = instance.slots,
		attrs = instance.attrs,
		expose = function(exposed: { [string]: any }?): ()
			instance.exposed = exposed
		end,
		onUnmounted = function(fn: () -> ()): ()
			table.insert(instance.unmountedCbs, fn)
		end,
	}

	function instance:setupComponent()
		setCurrentInstance(instance)

		-- Apply default prop values
		if type(self.type.props) == "table" then
			applyPropDefaults(self.type.props, self.props)
		end

		-- Validate props in Studio mode
		if type(self.type.props) == "table" and RunService and RunService:IsStudio() then
			local ok, err = validateProps(self.type.props, self.props)

			if not ok then
				debugModule.log("Component", "Prop validation failed: " .. tostring(err))
			end
		end

		-- Effects/computeds/watchers created in setup belong to this scope and stop on unmount
		local scope = _reactivity.effectScope(true);
		(self :: any)._scope = scope

		local setupResult
		if type(self.type.setup) == "function" then
			local setupErr: any = nil
			setupResult = scope:run(function()
				local ok, result = pcall(self.type.setup :: any, self.props, ctx)
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
		elseif type(self.type) == "function" then
			setupResult = self.type
		end
		setCurrentInstance(nil)

		if type(setupResult) == "function" then
			self.render = setupResult
		elseif type(setupResult) == "table" and type(setupResult.render) == "function" then
			self.render = setupResult.render
			self.setupState = setupResult
		elseif type(self.type.render) == "function" then
			self.render = function()
				return (self.type.render :: any)(self.props)
			end
		else
			error("Component must provide setup() or render()")
		end
	end

	function instance:runBeforeMount()
		if #self.beforeMountCbs > 0 then
			debugModule.log(
				"Component",
				"Running beforeMount callbacks",
				{ component = self.type.__name or "Anonymous", count = #self.beforeMountCbs }
			)
		end
		for _, fn in ipairs(self.beforeMountCbs) do
			pcall(fn)
		end
	end

	function instance:runMounted()
		if #self.mountedCbs > 0 then
			debugModule.log(
				"Component",
				"Running mounted callbacks",
				{ component = self.type.__name or "Anonymous", count = #self.mountedCbs }
			)
		end
		self.isMounted = true
		for _, fn in ipairs(self.mountedCbs) do
			pcall(fn)
		end
	end

	function instance:runBeforeUpdate()
		if #self.beforeUpdateCbs > 0 then
			debugModule.log(
				"Component",
				"Running beforeUpdate callbacks",
				{ component = self.type.__name or "Anonymous", count = #self.beforeUpdateCbs }
			)
		end
		for _, fn in ipairs(self.beforeUpdateCbs) do
			pcall(fn)
		end
	end

	function instance:runUpdated()
		if #self.updatedCbs > 0 then
			debugModule.log(
				"Component",
				"Running updated callbacks",
				{ component = self.type.__name or "Anonymous", count = #self.updatedCbs }
			)
		end
		for _, fn in ipairs(self.updatedCbs) do
			pcall(fn)
		end
	end

	function instance:runBeforeUnmount()
		if #self.beforeUnmountCbs > 0 then
			debugModule.log(
				"Component",
				"Running beforeUnmount callbacks",
				{ component = self.type.__name or "Anonymous", count = #self.beforeUnmountCbs }
			)
		end
		for _, fn in ipairs(self.beforeUnmountCbs) do
			pcall(fn)
		end
	end

	function instance:runUnmounted()
		local totalCallbacks = #self.unmountedCbs + #self.cleanupCbs
		local effectCount = (self :: any)._effects and #(self :: any)._effects or 0
		local jobCount = (self :: any)._schedulerJobs and #(self :: any)._schedulerJobs or 0
		if totalCallbacks > 0 or effectCount > 0 or jobCount > 0 then
			debugModule.log("Component", "Running unmounted callbacks and cleanup", {
				component = self.type.__name or "Anonymous",
				unmountedCbs = #self.unmountedCbs,
				cleanupCbs = #self.cleanupCbs,
				effects = effectCount,
				schedulerJobs = jobCount,
			})
		end

		for _, fn in ipairs(self.unmountedCbs) do
			pcall(fn)
		end

		for _, fn in ipairs(self.cleanupCbs) do
			pcall(fn)
		end

		-- Auto-cleanup: Cancel all tracked scheduler jobs
		if (self :: any)._schedulerJobs then
			for _, jobHandle in ipairs((self :: any)._schedulerJobs) do
				if jobHandle and type(jobHandle) == "table" and jobHandle.cancel then
					pcall(function()
						jobHandle.cancel()
					end)
				end
			end
			(self :: any)._schedulerJobs = {}
		end

		-- Auto-cleanup: Stop all tracked effects/watchers
		if (self :: any)._effects then
			for _, effect in ipairs((self :: any)._effects) do
				if effect and type(effect) == "function" then
					-- It's a stop handle from watch()
					pcall(effect)
				elseif effect and type(effect) == "table" and effect.stop then
					-- It's an Effect object from effect()
					pcall(function()
						effect:stop()
					end)
				end
			end
			(self :: any)._effects = {}
		end

		if (self :: any)._scope then
			(self :: any)._scope:stop();
			(self :: any)._scope = nil
		end
	end

	function instance:handleError(err: string, info: string)
		local cur: any = self.parent
		while cur do
			if cur.errorCapturedCbs then
				for _, handler in ipairs(cur.errorCapturedCbs) do
					local ok, stop = pcall(handler, err, self, info)
					if ok and stop == true then
						return
					end
				end
			end
			cur = cur.parent
		end
		-- If no handler consumed it, log it
		debugModule.log("Component", "Unhandled component error: " .. tostring(err), { info = info })
	end

	return instance, ctx
end

--- Applies new incoming props to a mounted component instance
--- Only changed keys are written, so only render effects that read them re-run
--- @param instance ComponentInstance -- Mounted component instance
--- @param rawProps { [string]: any }? -- New props from the parent's vnode
local function updateComponentProps(instance: ComponentInstance, rawProps: { [string]: any }?): ()
	local schema = instance.type.props
	local nextProps, nextAttrs = separatePropsAndAttrs(schema, rawProps or {})
	local props = instance.props
	local current = _reactivity.toRaw(props)

	for key in current do
		if nextProps[key] == nil then
			local spec = if type(schema) == "table" then schema[key] else nil
			if spec and spec.default ~= nil then
				-- Fall back to the default; keep factory defaults as-is to avoid needless re-renders
				if type(spec.default) ~= "function" then
					props[key] = spec.default
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
--- @param fn function -- Callback function (el: Instance) -> ()
local function onTransition(name: string, fn: (el: Instance) -> ()): ()
	if not currentInstance then
		error("onTransition must be called within setup()")
	end

	local inst: any = currentInstance
	if not inst._transitionHooks then
		inst._transitionHooks = {}
	end

	if not inst._transitionHooks[name] then
		inst._transitionHooks[name] = {}
	end

	table.insert(inst._transitionHooks[name], fn)
end

--- Built-in Teleport component for rendering content in a different location
--- Usage: h(Teleport, { to = targetInstance }, children)
--- Note: Teleport is handled specially by the renderer, not through normal render flow
local Teleport = {
	__is_component = true,
	__name = "Teleport",
}

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
