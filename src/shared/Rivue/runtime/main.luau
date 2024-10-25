--!strict
--!optimize 2

-- Assembles the public Rivue API from the runtime modules. Studio-only checks key off Rivue.dev.

local Types = require("./types")
local reactivity = require("./reactivity")
local hModule = require("./h")
local renderer = require("./renderer")
local componentAPI = require("./component")
local utils = require("./utils")
local directives = require("./directives")
local remote = require("./remote")
local robloxUtils = require("./roblox")
local debugModule = require("./debug")
local schedulerModule = require("./scheduler")
local poolModule = require("./pool")
local builtins = require("./builtins")
local composables = require("./composables")
local array = require("./array")

local RunService = game:GetService("RunService")

-- Public types
export type Ref<T> = Types.Ref<T>
export type ComputedRef<T> = Types.ComputedRef<T>
export type MaybeRef<T> = Types.MaybeRef<T>
export type MaybeRefOrGetter<T> = Types.MaybeRefOrGetter<T>
export type DebuggerEvent = Types.DebuggerEvent
export type RenderContext = Types.RenderContext
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

-- True in Studio: enables dev warnings and prop validation
Rivue.dev = RunService:IsStudio()

debugModule._toRaw = reactivity.toRaw
Rivue.debug = debugModule
Rivue.prettyPrint = debugModule.prettyPrint
Rivue.inspect = debugModule.inspect
Rivue.assertInvariant = debugModule.assertInvariant

-- Reactivity
Rivue.ref = reactivity.ref
Rivue.shallowRef = reactivity.shallowRef
Rivue.reactive = reactivity.reactive
Rivue.shallowReactive = reactivity.shallowReactive
Rivue.computed = reactivity.computed
Rivue.readonly = reactivity.readonly
Rivue.shallowReadonly = reactivity.shallowReadonly

Rivue.isRef = reactivity.isRef
Rivue.isReactive = reactivity.isReactive
Rivue.isReadonly = reactivity.isReadonly
Rivue.isProxy = reactivity.isProxy
Rivue.isShallow = reactivity.isShallow

Rivue.toRef = reactivity.toRef
Rivue.toRefs = reactivity.toRefs
Rivue.unref = reactivity.unref
Rivue.toValue = reactivity.toValue
Rivue.proxyRefs = reactivity.proxyRefs
Rivue.array = array

Rivue.toRaw = reactivity.toRaw
Rivue.markRaw = reactivity.markRaw
Rivue.triggerRef = reactivity.triggerRef
Rivue.customRef = reactivity.customRef

Rivue.effectScope = reactivity.effectScope
Rivue.getCurrentScope = reactivity.getCurrentScope
Rivue.onScopeDispose = reactivity.onScopeDispose
Rivue.onWatcherCleanup = reactivity.onWatcherCleanup

--- Tracks a stop handle/effect on the current component for cleanup on unmount
local function trackForCleanup(handle: WatchHandle | Effect)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance then
		table.insert(currentInstance._effects, handle)
	end
end

--- watch(), stopped automatically when called in a component's setup()
--- The handle stops it when called (or .stop()), and has .pause()/.resume()
function Rivue.watch<T>(source: WatchSource<T> | T, callback: WatchCallback<T>, options: WatchOptions?): WatchHandle
	local stopHandle = reactivity.watch(source, callback, options)
	trackForCleanup(stopHandle)
	return stopHandle
end

--- Runs an effect now and again when its dependencies change
function Rivue.watchEffect(fn: (onCleanup: OnCleanup) -> (), opts: WatchOptions?): WatchHandle
	local stopHandle = reactivity.watchEffect(fn, opts)
	trackForCleanup(stopHandle)
	return stopHandle
end

--- effect(), stopped automatically when called in a component's setup()
function Rivue.effect(fn: () -> (), opts: Types.EffectOptions?): Effect
	local eff = reactivity.effect(fn, opts)
	trackForCleanup(eff)
	return eff
end

--- watchEffect() that re-runs on Heartbeat, after renders (auto-cleanup in components)
function Rivue.watchPostEffect(fn: (onCleanup: OnCleanup) -> ()): WatchHandle
	return Rivue.watchEffect(fn, { flush = "post" })
end

--- watchEffect() that re-runs immediately on every change (auto-cleanup in components)
function Rivue.watchSyncEffect(fn: (onCleanup: OnCleanup) -> ()): WatchHandle
	return Rivue.watchEffect(fn, { flush = "sync" })
end

Rivue.nextTick = schedulerModule.nextTick

-- Rendering
Rivue.h = hModule.h
Rivue.Fragment = hModule.Fragment
Rivue.hIf = hModule.hIf
Rivue.hFor = hModule.hFor
Rivue.hForParallel = hModule.hForParallel
Rivue.mergeProps = hModule.mergeProps
Rivue.cloneVNode = hModule.cloneVNode
Rivue.isVNode = hModule.isVNode

--- Looks up a component registered with app:component() (call in setup or render)
--- Returns the component, nil if it isn't registered
function Rivue.resolveComponent(name: string): ComponentDef?
	local inst = componentAPI.getCurrentInstance() or componentAPI.getRenderingInstance()
	if not inst then
		error("resolveComponent() must be called in setup() or a render function", 2)
	end
	local localComponents = inst.type.components
	local def = (if localComponents then localComponents[name] else nil) or inst.appContext.components[name]
	if not def and Rivue.dev then
		warn(`[Rivue] Component '{name}' isn't registered, use app:component("{name}", Component)`)
	end
	return def
end

--- Prints (and returns) the tree under a mounted vnode, like app:printTree()
function Rivue.printTree(vnode: VNode): string
	local tree = renderer.formatTree(vnode)
	print(tree)
	return tree
end

type SetupFunction = (props: Props, ctx: SetupContext) -> Types.SetupResult

--- Defines a component from options, or from a setup function plus options
--- `extra`: options when the first argument is a setup function
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
		components = options.components,
		styles = options.styles,
		inheritAttrs = options.inheritAttrs,
	}
end

-- Lifecycle
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

-- Provide / inject
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

Rivue.defineAsyncComponent = builtins.defineAsyncComponent

Rivue.useAttrs = composables.useAttrs
Rivue.useSlots = composables.useSlots
Rivue.defineModel = composables.defineModel
Rivue.useTheme = composables.useTheme
Rivue.useStyles = composables.useStyles

-- Scheduler
Rivue.scheduler = schedulerModule

--- Queues a job (auto-cancelled on unmount when called in setup)
--- `opts`: queue mode ("micro" | "render" | "heartbeat")
function Rivue.queueJob(fn: () -> (), opts: QueueOptions?): JobHandle
	local jobHandle = schedulerModule.queueJob(fn, opts)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance then
		table.insert(currentInstance._schedulerJobs, jobHandle)
	end
	return jobHandle
end

Rivue.pool = poolModule

-- Utilities
Rivue.utils = utils
Rivue.directives = directives
Rivue.Remote = remote

Rivue.iterArray = utils.iterArray

-- Roblox
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

-- Apps
Rivue.createApp = renderer.createApp

--- Shorthand for createApp(root, opts):mount(parent)
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
