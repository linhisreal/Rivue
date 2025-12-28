--!strict
--!optimize 2
--!native

--[[
	main.luau
	=========
	
	Public API entrypoint that assembles and exports the complete Rivue API.
	This module aggregates all runtime modules and provides a cohesive interface
	for building reactive UI applications in Roblox.
	
	Public API Surface:
	-------------------
	
	Reactivity API:

		ref(value: any) -> Ref
			Creates a reactive reference. Changes to .value trigger updates.
			
		reactive(obj: table) -> Reactive
			Creates a deeply reactive proxy. All nested objects are automatically reactive.
			
		shallowReactive(obj: table) -> ShallowReactive
			Creates a shallow reactive proxy. Only top-level properties are reactive.
			
		computed(getter: () -> any) -> Computed
			Creates a cached computed value that only re-computes when dependencies change.
			
		watch(source, callback, options?) -> StopHandle
			Watches a reactive source and executes callback on changes.
			Auto-cleanup on component unmount when called during setup().
			
		watchEffect(fn: () -> (), options?) -> StopHandle
			Runs a reactive effect with automatic dependency tracking and immediate execution.
			Simpler alternative to watch() when you don't need old/new value comparison.
			Auto-cleanup on component unmount when called during setup().
			
		effect(fn: () -> any, options?) -> Effect
			Creates a reactive effect that re-runs when dependencies change.
			Auto-cleanup on component unmount when called during setup().
			
		readonly(target: any) -> any
			Creates a readonly reactive proxy that warns on mutation attempts.
			Useful for enforcing one-way data flow (props, injected state, public APIs).
			
		shallowReadonly(target: any) -> any
			Creates a shallow readonly reactive proxy. Top-level props are readonly, but nested objects are mutable.

		toRef(obj: table, key: string) -> Ref
			Creates a ref linked to a property on a reactive object.
			
		toRefs(obj: table) -> { [string]: Ref }
			Converts all properties of a reactive object to refs.
			
		markRaw(obj: any) -> any
			Marks an object as non-reactive (prevents proxy wrapping).
			
		toRaw(proxy: any) -> any
			Unwraps a proxy to get the original object.
			
		unref(ref: Ref | any) -> any
			Unwraps a ref to get its value, or returns value as-is if not a ref.
			
		isRef(val: any) -> boolean
			Checks if a value is a Ref.
	
	Rendering API:

		h(type, props?, children?) -> VNode
			Creates a virtual DOM node (hyperscript function).
			
		hIf(condition: boolean, vnode: VNode) -> VNode?
			Conditional rendering helper.
			
		hFor(items: table, renderFn: (item, index) -> VNode, keyFn?: (item) -> any) -> { VNode }
			List rendering helper with optional key function.
	
	Component API:

		defineComponent(opts: ComponentOptions) -> ComponentDef
			Defines a component with setup, render, and props schema.
			
		createApp(vnode: VNode, opts?) -> App
			Creates an application instance with mount/unmount capabilities.
			
		mount(componentOrVNode: VNode | ComponentDef, parent: Instance, opts?) -> App
			Convenience function to create and mount an app in one call.
	
	Lifecycle Hooks:

		onMounted(fn: () -> ()) -> ()
			Registers a callback to run after component is mounted.
			Must be called during setup().
			
		onUpdated(fn: () -> ()) -> ()
			Registers a callback to run after component updates.
			Must be called during setup().
			
		onUnmounted(fn: () -> ()) -> ()
			Registers a callback to run before component is unmounted.
			Must be called during setup().
	
	Directives:
	
		vModelText(ref: Ref) -> DirectiveValue
			Creates a v-model directive 'for' text input two-way binding.
			
		vModelProp(ref: Ref, propName: string, eventName?: string) -> DirectiveValue
			Creates a v-model directive 'for' custom property binding.
			
		directives.register(name, hooks) -> ()
			Registers a custom directive with mounted/unmounted hooks.
			
		directives.get(name) -> DirectiveHooks?
			Retrieves a registered directive by name.
	
	Roblox-Specific Utilities:

		attributeRef(instance: Instance, attributeName: string, defaultValue?: T) -> Ref<T>
			Creates a reactive ref synced with an Instance attribute (bidirectional).
			Changes to ref.value update the attribute, attribute changes update ref.value.
			Auto-disconnects on component unmount.
			
		useTag(tagName: string, onAdded: (instance: Instance) -> (() -> ())?) -> ()
			Registers callbacks 'for' CollectionService tagged instances.
			Handles tag addition/removal during component lifecycle.
			Auto-cleanup on component unmount.
			
		onRenderStepped(callback: (deltaTime: number) -> ()) -> ()
			Registers a callback for RunService.RenderStepped.
			Auto-disconnects on component unmount. Must be called during setup().
			
		onHeartbeat(callback: (deltaTime: number) -> ()) -> ()
			Registers a callback for RunService.Heartbeat.
			Auto-disconnects on component unmount. Must be called during setup().
			
		onStepped(callback: (time: number, deltaTime: number) -> ()) -> ()
			Registers a callback for RunService.Stepped.
			Auto-disconnects on component unmount. Must be called during setup().
	
	Utilities:

		utils.debounce(fn, ms) -> DebouncedFn
			Creates a debounced version of a function.
			
		utils.shallowEqual(a, b) -> boolean
			Performs shallow equality comparison.
			
		utils.profiler.mark(name) -> ()
			Marks a performance measurement point.
			
		utils.profiler.measure(name) -> number?
			Measures time between marked points.
	
	Remote Communication:

		Remote.new(name: string, opts?) -> RemoteAPI
			Creates a remote event/function wrapper for client-server communication.
	
	Global Properties:

		Rivue.dev: boolean
			True in Studio, false in published game. Use for dev-mode features.
	
	Module Structure:
	-----------------
	
	This file acts as the aggregation layer:
	1. Requires all runtime modules from script.Parent
	2. Exposes selected APIs from each module
	3. Provides convenience wrappers (defineComponent, mount)
	4. Wraps effect/watch to enable auto-cleanup tracking
	5. Detects dev mode automatically
	
	Usage Example:
	--------------
	
		local Rivue = require(game.ReplicatedStorage.Rivue)
		
		local Counter = Rivue.defineComponent({
			setup = function(props)
				local count = Rivue.ref(0)
				local healthRef = Rivue.attributeRef(props.character, "Health", 100)
				
				Rivue.onMounted(function()
					print("Counter mounted!")
				end)
				
				-- Auto-cleanup: effect stops on unmount
				Rivue.effect(function()
					print("Count is now:", count.value)
				end)
				
				-- Auto-cleanup: watch stops on unmount
				Rivue.watch(healthRef, function(newHealth)
					print("Health changed:", newHealth)
				end)
				
				-- Auto-cleanup: connection disconnects on unmount
				Rivue.onHeartbeat(function(dt)
					-- Update every frame
				end)
				
				-- Template ref for DOM element access
				local buttonRef = Rivue.ref(nil)
				
				return function()
					return Rivue.h("Frame", {}, {
						Rivue.h("TextLabel", {
							Text = "Count: " .. tostring(count.value)
						}),
						Rivue.h("TextButton", {
							ref = buttonRef,  -- Populate buttonRef.value with Instance
							Text = "Increment",
							onClick = function()
								count.value = count.value + 1
							end
						})
					})
				end
			end
		})
		
		Rivue.mount(Counter, game.Players.LocalPlayer.PlayerGui)
	
	Implementation Notes:
	---------------------
	
	- All modules are required via script.Parent:WaitForChild() for safety
	- Dev mode detection uses RunService:IsStudio()
	- The Rivue table is the single exported API surface
	- defineComponent is a lightweight wrapper that adds metadata
	- mount() is a convenience that handles component → vnode conversion
	- effect() and watch() are wrapped to track for auto-cleanup
	- Template refs automatically populate/clear on mount/unmount
	- Roblox utilities auto-disconnect on component unmount
	- All v-model helpers are pass-throughs to directives module
]]

-- main.luau
-- Public API entrypoint for the runtime (ModuleScript)

local runtime = script.Parent
local reactivity = require(runtime:WaitForChild("reactivity"))
local hModule = require(runtime:WaitForChild("h"))
local renderer = require(runtime:WaitForChild("renderer"))
local componentAPI = require(runtime:WaitForChild("component"))
local utils = require(runtime:WaitForChild("utils"))
local directives = require(runtime:WaitForChild("directives"))
local remote = require(runtime:WaitForChild("remote"))
local robloxUtils = require(runtime:WaitForChild("roblox"))
local debugModule = require(runtime:WaitForChild("debug"))
local schedulerModule = require(runtime:WaitForChild("scheduler"))
local poolModule = require(runtime:WaitForChild("pool"))
local builtins = require(runtime:WaitForChild("builtins"))
local composables = require(runtime:WaitForChild("composables"))

local RunService = game:GetService("RunService")

local Rivue = {}

-- detect studio/dev mode without writing to global environment
Rivue.dev = RunService and RunService:IsStudio() or false

-- Sync dev mode to debug module
debugModule.enabled = Rivue.dev

-- Provide toRaw to debug module (avoid circular dependency)
debugModule._toRaw = reactivity.toRaw

-- Export unified debug module (includes prettyPrint, inspect, assertInvariant, formatError)
Rivue.debug = debugModule

-- Convenience aliases for common debug utilities
Rivue.prettyPrint = debugModule.prettyPrint
Rivue.inspect = debugModule.inspect
Rivue.assertInvariant = debugModule.assertInvariant

-- reactivity
Rivue.ref = reactivity.ref
Rivue.shallowRef = reactivity.shallowRef
Rivue.reactive = reactivity.reactive
Rivue.shallowReactive = reactivity.shallowReactive
Rivue.computed = reactivity.computed
Rivue.readonly = reactivity.readonly
Rivue.shallowReadonly = reactivity.shallowReadonly

-- Type checking utilities
Rivue.isRef = reactivity.isRef
Rivue.isReactive = reactivity.isReactive
Rivue.isReadonly = reactivity.isReadonly
Rivue.isProxy = reactivity.isProxy

-- Conversion utilities
Rivue.toRef = reactivity.toRef
Rivue.toRefs = reactivity.toRefs
Rivue.unref = reactivity.unref
Rivue.toRaw = reactivity.toRaw
Rivue.markRaw = reactivity.markRaw

-- Advanced reactivity
Rivue.triggerRef = reactivity.triggerRef
Rivue.customRef = reactivity.customRef

-- Effect scope system
Rivue.effectScope = reactivity.effectScope
Rivue.getCurrentScope = reactivity.getCurrentScope
Rivue.onScopeDispose = reactivity.onScopeDispose

--- Creates a reactive watcher with auto-cleanup for components
--- @param source any -- Reactive source to watch
--- @param callback function -- Callback to run on change
--- @param options any? -- Watch options (immediate, deep, etc.)
--- @return any -- Stop handle to manually stop watcher
-- watch with auto-cleanup tracking
Rivue.watch = function(source, callback, options)
	local stopHandle = reactivity.watch(source, callback, options)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance and (currentInstance :: any)._effects then
		table.insert((currentInstance :: any)._effects, stopHandle)
	end
	return stopHandle
end

--- Creates a reactive effect with automatic dependency tracking and immediate execution
--- Simpler alternative to watch() when you don't need old/new value comparison
--- @param fn function -- Effect function to run
--- @param opts any? -- Options (currently unused, for future flush timing)
--- @return any -- Stop handle to manually stop effect
-- watchEffect with auto-cleanup tracking
Rivue.watchEffect = function(fn, opts)
	local stopHandle = reactivity.watchEffect(fn, opts)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance and (currentInstance :: any)._effects then
		table.insert((currentInstance :: any)._effects, stopHandle)
	end
	return stopHandle
end

--- Creates a reactive effect with auto-cleanup for components
--- @param fn function -- Effect function to run
--- @param opts any? -- Effect options
--- @return any -- Effect handle to manually stop effect
-- effect with auto-cleanup tracking
Rivue.effect = function(fn, opts)
	local eff = reactivity.effect(fn, opts)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance and (currentInstance :: any)._effects then
		table.insert((currentInstance :: any)._effects, eff)
	end
	return eff
end

-- h and helpers
Rivue.h = hModule.h
Rivue.hIf = hModule.hIf
Rivue.hFor = hModule.hFor
Rivue.hForParallel = hModule.hForParallel

--- Defines a component with setup, render, props, and lifecycle hooks
--- @param opts any? -- Component options (setup, render, props, name, inheritAttrs)
--- @return any -- Component definition object
-- components
Rivue.defineComponent = function(opts): any
	local comp = {}
	comp.__is_component = true
	comp.setup = opts and opts.setup
	comp.render = opts and opts.render
	comp.props = opts and opts.props
	comp.__name = opts and opts.name
	comp.inheritAttrs = opts and opts.inheritAttrs
	return comp
end

-- lifecycle
Rivue.onBeforeMount = componentAPI.onBeforeMount
Rivue.onMounted = componentAPI.onMounted
Rivue.onBeforeUpdate = componentAPI.onBeforeUpdate
Rivue.onUpdated = componentAPI.onUpdated
Rivue.onBeforeUnmount = componentAPI.onBeforeUnmount
Rivue.onUnmounted = componentAPI.onUnmounted
Rivue.onErrorCaptured = componentAPI.onErrorCaptured
Rivue.onTransition = componentAPI.onTransition

-- Built-in components
Rivue.Teleport = componentAPI.Teleport
Rivue.Suspense = builtins.Suspense
Rivue.KeepAlive = builtins.KeepAlive

-- Async component helper
Rivue.defineAsyncComponent = builtins.defineAsyncComponent

-- Composition API helpers
Rivue.useAttrs = composables.useAttrs
Rivue.useSlots = composables.useSlots
Rivue.defineModel = composables.defineModel
Rivue.useTheme = composables.useTheme
Rivue.useStyles = composables.useStyles

-- Export scheduler
Rivue.scheduler = schedulerModule

-- Wrap scheduler.queueJob to enable auto-cleanup tracking
local originalQueueJob = schedulerModule.queueJob
Rivue.queueJob = function(fn, opts)
	local jobHandle = originalQueueJob(fn, opts)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance and (currentInstance :: any)._schedulerJobs then
		table.insert((currentInstance :: any)._schedulerJobs, jobHandle)
	end
	return jobHandle
end

-- Export pool
Rivue.pool = poolModule

-- utilities
Rivue.utils = utils
Rivue.directives = directives
Rivue.Remote = remote

-- Export iterArray directly for convenience
Rivue.iterArray = utils.iterArray

-- Roblox-specific utilities
Rivue.attributeRef = robloxUtils.attributeRef
Rivue.useTag = robloxUtils.useTag
Rivue.onRenderStepped = robloxUtils.onRenderStepped
Rivue.onHeartbeat = robloxUtils.onHeartbeat
Rivue.onStepped = robloxUtils.onStepped

--- Creates an application instance with mount/unmount API
--- @param vnode any -- Root VNode or component
--- @param opts any? -- App options (dev mode, pool options)
--- @return any -- App API with mount/unmount methods
-- createApp
Rivue.createApp = function(vnode, opts)
	return renderer.createApp(vnode, opts)
end

--- Convenience method to mount a component or VNode to a parent Instance
--- @param componentOrVNode any -- Component definition or VNode
--- @param parent Instance -- Parent Instance to mount to
--- @param opts any? -- Mount options
--- @return any -- Mounted app instance
-- convenience mount
function Rivue.mount(componentOrVNode: any, parent: Instance, opts: any?): any
	local vnode = componentOrVNode

	if type(componentOrVNode) == "table" and (componentOrVNode :: any).__is_component then
		vnode = Rivue.h(componentOrVNode)
	end

	local app = Rivue.createApp(vnode :: any, opts or {})
	app:mount(parent)
	return app
end

--- Creates a v-model directive for text input binding with optional debounce
--- @param r any -- Ref to bind to
--- @param opts any? -- Options table with debounce delay in ms
--- @return any -- Directive configuration
-- v-model helpers
Rivue.vModelText = function(r, opts)
	return directives.vModelText(r, opts)
end

--- Creates a v-model directive for custom property binding
--- @param r any -- Ref to bind to
--- @param propName any -- Property name to bind
--- @param eventName any -- Event name to listen to
--- @return any -- Directive configuration
Rivue.vModelProp = function(r, propName, eventName)
	return directives.vModelProp(r, propName, eventName)
end

return Rivue
