--!strict
--!optimize 2

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
local Types = require(runtime:WaitForChild("types"))
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

-- Public types
export type Ref<T> = Types.Ref<T>
export type ComputedRef<T> = Types.ComputedRef<T>
export type MaybeRef<T> = Types.MaybeRef<T>
export type MaybeRefOrGetter<T> = Types.MaybeRefOrGetter<T>
export type DebuggerEvent = Types.DebuggerEvent
export type Effect = Types.Effect
export type EffectScope = Types.EffectScope
export type FlushMode = Types.FlushMode
export type WatchOptions = Types.WatchOptions
export type WatchCallback<T> = Types.WatchCallback<T>
export type WatchSource<T> = Types.WatchSource<T>
export type WatchStopHandle = Types.WatchStopHandle
export type WatchHandle = Types.WatchHandle
export type OnCleanup = Types.OnCleanup
export type TransitionConfig = Types.TransitionConfig
export type EmitsOptions = Types.EmitsOptions
export type QueueOptions = Types.QueueOptions
export type JobHandle = Types.JobHandle
export type VNode = Types.VNode
export type Props = Types.Props
export type Child = Types.Child
export type ChildInput = Types.ChildInput
export type Children = Types.Children
export type ComponentDef = Types.ComponentDef
export type ComponentOptions = Types.ComponentOptions
export type PropSchema = Types.PropSchema
export type SetupContext = Types.SetupContext
export type Directive = Types.Directive
export type AppOptions = Types.AppOptions
export type App = renderer.App
export type Plugin = renderer.Plugin
export type WritableComputedOptions<T> = Types.WritableComputedOptions<T>
export type ComponentInstance = componentAPI.ComponentInstance

local Rivue = {}

-- detect studio/dev mode without writing to global environment
Rivue.dev = RunService:IsStudio()

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
Rivue.isShallow = reactivity.isShallow

-- Conversion utilities
Rivue.toRef = reactivity.toRef
Rivue.toRefs = reactivity.toRefs
Rivue.unref = reactivity.unref
Rivue.toValue = reactivity.toValue
Rivue.toRaw = reactivity.toRaw
Rivue.markRaw = reactivity.markRaw

-- Advanced reactivity
Rivue.triggerRef = reactivity.triggerRef
Rivue.customRef = reactivity.customRef

-- Effect scope system
Rivue.effectScope = reactivity.effectScope
Rivue.getCurrentScope = reactivity.getCurrentScope
Rivue.onScopeDispose = reactivity.onScopeDispose
Rivue.onWatcherCleanup = reactivity.onWatcherCleanup

--- Tracks a stop handle/effect on the current component for cleanup on unmount
--- @param handle WatchHandle | Effect -- Handle to track
local function trackForCleanup(handle: WatchHandle | Effect)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance then
		table.insert(currentInstance._effects, handle)
	end
end

--- Creates a reactive watcher with auto-cleanup for components
--- @param source WatchSource<T> | T -- Getter, ref, or reactive object to watch
--- @param callback WatchCallback<T> -- Callback to run on change
--- @param options WatchOptions? -- immediate, deep, flush
--- @return WatchHandle -- Call it (or .stop()) to stop, .pause()/.resume() to suspend
function Rivue.watch<T>(source: WatchSource<T> | T, callback: WatchCallback<T>, options: WatchOptions?): WatchHandle
	local stopHandle = reactivity.watch(source, callback, options)
	trackForCleanup(stopHandle)
	return stopHandle
end

--- Runs an effect now and again when its dependencies change
--- @param fn (onCleanup: OnCleanup) -> () -- Effect function to run
--- @param opts WatchOptions? -- flush timing
--- @return WatchHandle -- Stop handle with pause/resume
function Rivue.watchEffect(fn: (onCleanup: OnCleanup) -> (), opts: WatchOptions?): WatchHandle
	local stopHandle = reactivity.watchEffect(fn, opts)
	trackForCleanup(stopHandle)
	return stopHandle
end

--- Creates a reactive effect with auto-cleanup for components
--- @param fn () -> () -- Effect function to run
--- @param opts Types.EffectOptions? -- Effect options
--- @return Effect -- Effect handle to manually stop effect
function Rivue.effect(fn: () -> (), opts: Types.EffectOptions?): Effect
	local eff = reactivity.effect(fn, opts)
	trackForCleanup(eff)
	return eff
end

--- watchEffect() that re-runs on Heartbeat, after renders (auto-cleanup in components)
--- @param fn (onCleanup: OnCleanup) -> () -- Effect function
--- @return WatchHandle -- Stop handle
function Rivue.watchPostEffect(fn: (onCleanup: OnCleanup) -> ()): WatchHandle
	return Rivue.watchEffect(fn, { flush = "post" })
end

--- watchEffect() that re-runs immediately on every change (auto-cleanup in components)
--- @param fn (onCleanup: OnCleanup) -> () -- Effect function
--- @return WatchHandle -- Stop handle
function Rivue.watchSyncEffect(fn: (onCleanup: OnCleanup) -> ()): WatchHandle
	return Rivue.watchEffect(fn, { flush = "sync" })
end

Rivue.nextTick = schedulerModule.nextTick

-- h and helpers
Rivue.h = hModule.h
Rivue.Fragment = hModule.Fragment
Rivue.hIf = hModule.hIf
Rivue.hFor = hModule.hFor
Rivue.hForParallel = hModule.hForParallel
Rivue.mergeProps = hModule.mergeProps
Rivue.cloneVNode = hModule.cloneVNode
Rivue.isVNode = hModule.isVNode

--- Looks up a component registered with app:component() (call in setup or render)
--- @param name string -- Registered name
--- @return ComponentDef? -- The component, nil if it isn't registered
function Rivue.resolveComponent(name: string): ComponentDef?
	local inst = componentAPI.getCurrentInstance() or componentAPI.getRenderingInstance()
	if not inst then
		error("resolveComponent() must be called in setup() or a render function", 2)
	end
	local def = inst.appContext.components[name]
	if not def and Rivue.dev then
		warn(`[Rivue] Component '{name}' isn't registered, use app:component("{name}", Component)`)
	end
	return def
end

--- Prints (and returns) the tree under a mounted vnode, like app:printTree()
--- @param vnode VNode -- Mounted vnode
--- @return string -- Outline
function Rivue.printTree(vnode: VNode): string
	local tree = renderer.formatTree(vnode)
	print(tree)
	return tree
end

type SetupFunction = (props: Props, ctx: SetupContext) -> Types.SetupResult

--- Defines a component with setup, render, props, and lifecycle hooks
--- @param opts ComponentOptions | SetupFunction -- Options, or just the setup function
--- @param extra ComponentOptions? -- Options when the first argument is a setup function
--- @return ComponentDef -- Component definition object
function Rivue.defineComponent(opts: ComponentOptions | SetupFunction, extra: ComponentOptions?): ComponentDef
	local options: ComponentOptions
	if type(opts) == "function" then
		-- defineComponent(function(props, ctx) ... end, { name = "Counter" })
		options = if extra then table.clone(extra) else {}
		options.setup = opts
	else
		options = (opts or {}) :: ComponentOptions
	end
	if Rivue.dev and options.setup == nil and options.render == nil then
		warn(`[Rivue] defineComponent({options.name or "Anonymous"}) needs a setup() or render()`)
	end
	return {
		__is_component = true :: true,
		__name = options.name,
		setup = options.setup,
		render = options.render,
		props = options.props,
		emits = options.emits,
		inheritAttrs = options.inheritAttrs,
	}
end

-- lifecycle
Rivue.onBeforeMount = componentAPI.onBeforeMount
Rivue.onMounted = componentAPI.onMounted
Rivue.onBeforeUpdate = componentAPI.onBeforeUpdate
Rivue.onUpdated = componentAPI.onUpdated
Rivue.onBeforeUnmount = componentAPI.onBeforeUnmount
Rivue.onUnmounted = componentAPI.onUnmounted
Rivue.onActivated = componentAPI.onActivated
Rivue.onDeactivated = componentAPI.onDeactivated
Rivue.onRenderTracked = componentAPI.onRenderTracked
Rivue.onRenderTriggered = componentAPI.onRenderTriggered
Rivue.onErrorCaptured = componentAPI.onErrorCaptured
Rivue.onTransition = componentAPI.onTransition

-- provide/inject
Rivue.provide = componentAPI.provide
Rivue.inject = componentAPI.inject
Rivue.hasInjectionContext = componentAPI.hasInjectionContext

-- Instance helpers
Rivue.getCurrentInstance = componentAPI.getCurrentInstance
Rivue.useId = componentAPI.useId
Rivue.useTemplateRef = componentAPI.useTemplateRef

-- Built-in components
Rivue.Teleport = componentAPI.Teleport
Rivue.Suspense = builtins.Suspense
Rivue.KeepAlive = builtins.KeepAlive
Rivue.Transition = builtins.Transition
Rivue.TransitionGroup = builtins.TransitionGroup
Rivue.VirtualList = builtins.VirtualList

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

--- Queues a job (auto-cancelled on unmount when called in setup)
--- @param fn () -> () -- Job to run
--- @param opts QueueOptions? -- Queue mode ("micro" | "render" | "heartbeat")
--- @return JobHandle -- Handle with cancel()
function Rivue.queueJob(fn: () -> (), opts: QueueOptions?): JobHandle
	local jobHandle = schedulerModule.queueJob(fn, opts)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance then
		table.insert(currentInstance._schedulerJobs, jobHandle)
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
Rivue.useViewportSize = robloxUtils.useViewportSize
Rivue.useInputType = robloxUtils.useInputType
Rivue.useSafeArea = robloxUtils.useSafeArea
Rivue.useSelection = robloxUtils.useSelection
Rivue.useTween = robloxUtils.useTween
Rivue.useSpring = robloxUtils.useSpring

-- createApp
Rivue.createApp = renderer.createApp

--- Convenience method to mount a component or VNode to a parent Instance
--- @param componentOrVNode ComponentDef | VNode -- Component definition or VNode
--- @param parent Instance -- Parent Instance to mount to
--- @param opts AppOptions? -- Mount options
--- @return App -- Mounted app instance
function Rivue.mount(componentOrVNode: ComponentDef | VNode, parent: Instance, opts: AppOptions?): App
	local vnode: VNode = if (componentOrVNode :: ComponentDef).__is_component
		then hModule.h(componentOrVNode :: ComponentDef)
		else componentOrVNode :: VNode

	local app = renderer.createApp(vnode, opts)
	app:mount(parent)
	return app
end

-- v-model helpers
Rivue.vModelText = directives.vModelText
Rivue.vModelProp = directives.vModelProp

return Rivue
