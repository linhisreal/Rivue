--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local Types = require("./types")
local reactivity = require("./reactivity")
local hModule = require("./h")
local renderer = require("./renderer")
local componentAPI = require("./component")
local utils = require("./utils")
local directives = require("./directives")
local robloxUtils = require("./roblox")
local debugModule = require("./debug")
local schedulerModule = require("./scheduler")
local poolModule = require("./pool")
local builtins = require("./builtins")
local composables = require("./composables")
local array = require("./array")
local testingModule = require("./testing")
local uiModule = require("./ui")
local transitionsModule = require("./transitions")

local RunService = game:GetService("RunService")

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
export type AsyncState<T> = composables.AsyncState<T>

local Rivue = {}

Rivue.dev = RunService:IsStudio()

debugModule._toRaw = reactivity.toRaw
Rivue.debug = debugModule
Rivue.prettyPrint = debugModule.prettyPrint
Rivue.inspect = debugModule.inspect
Rivue.assertInvariant = debugModule.assertInvariant

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
Rivue.onEffectCleanup = reactivity.onEffectCleanup

local function trackForCleanup(handle: WatchHandle | Effect)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance then
		table.insert(currentInstance._effects, handle)
	end
end

function Rivue.watch<T>(source: WatchSource<T> | T, callback: WatchCallback<T>, options: WatchOptions?): WatchHandle
	local stopHandle = reactivity.watch(source, callback, options)
	trackForCleanup(stopHandle)
	return stopHandle
end

function Rivue.watchEffect(fn: (onCleanup: OnCleanup) -> (), opts: WatchOptions?): WatchHandle
	local stopHandle = reactivity.watchEffect(fn, opts)
	trackForCleanup(stopHandle)
	return stopHandle
end

function Rivue.effect(fn: () -> (), opts: Types.EffectOptions?): Effect
	local eff = reactivity.effect(fn, opts)
	trackForCleanup(eff)
	return eff
end

function Rivue.watchPostEffect(fn: (onCleanup: OnCleanup) -> ()): WatchHandle
	return Rivue.watchEffect(fn, { flush = "post" })
end

function Rivue.watchSyncEffect(fn: (onCleanup: OnCleanup) -> ()): WatchHandle
	return Rivue.watchEffect(fn, { flush = "sync" })
end

Rivue.nextTick = schedulerModule.nextTick

Rivue.h = hModule.h
Rivue.Fragment = hModule.Fragment
Rivue.hIf = hModule.hIf
Rivue.hFor = hModule.hFor
Rivue.mergeProps = hModule.mergeProps
Rivue.cloneVNode = hModule.cloneVNode
Rivue.isVNode = hModule.isVNode

--- Call in setup or render: it needs the current app
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

function Rivue.printTree(vnode: VNode): string
	local tree = renderer.formatTree(vnode)
	print(tree)
	return tree
end

type SetupFunction = (props: Props, ctx: SetupContext) -> Types.SetupResult

function Rivue.defineComponent(opts: ComponentOptions | SetupFunction, extra: ComponentOptions?): ComponentDef
	local options: ComponentOptions
	if type(opts) == "function" then
		options = if extra then table.clone(extra) else {}
		options.setup = opts
	else
		options = (opts or {}) :: ComponentOptions
	end
	if Rivue.dev and options.setup == nil and options.render == nil then
		warn(`[Rivue] defineComponent({options.name or "Anonymous"}) needs a setup() or render()`)
	end
	local source, line = debug.info(2, "sl")
	return {
		__is_component = true :: true,
		__name = options.name,
		__source = if source and line then `{source}:{line}` else nil,
		setup = options.setup,
		render = options.render,
		props = options.props,
		emits = options.emits,
		components = options.components,
		styles = options.styles,
		inheritAttrs = options.inheritAttrs,
	}
end

export type StoryOptions = {
	props: Props | ((controls: { [string]: any }) -> Props)?,
	controls: { [string]: any }?,
	styles: { [string]: Props }?,
}

--- A storybook story for UI Labs, Hoarcekat or any plugin that takes function stories. With
--- controls it's a UI Labs generic story, and the component re-renders when a control changes
function Rivue.story(component: ComponentDef, options: StoryOptions?): any
	local opts: StoryOptions = options or {}
	local function mount(target: Instance, controls: { [string]: any }?): App
		local Story = Rivue.defineComponent({
			name = `{component.__name or "Anonymous"}Story`,
			render = function()
				local props = opts.props
				if type(props) == "function" then
					return hModule.h(component, props(controls or {}))
				end
				if controls then
					local merged: Props = if props then table.clone(props :: Props) else {}
					for k, v in controls do
						merged[k] = v
					end
					return hModule.h(component, merged)
				end
				return hModule.h(component, props :: Props?)
			end,
		})
		local app = renderer.createApp(Story)
		if opts.styles then
			app:styles(opts.styles)
		end
		app:mount(target)
		return app
	end

	local initialControls = opts.controls
	if initialControls == nil then
		return function(target: Instance)
			local app = mount(target, nil)
			return function()
				app:unmount()
			end
		end
	end

	return {
		controls = initialControls,
		render = function(storyProps: any)
			local values = reactivity.reactive(table.clone(storyProps.controls)) :: { [string]: any }
			local app = mount(storyProps.target, values)
			local disconnect = storyProps.subscribe(function(newValues: { [string]: any })
				for k, v in newValues do
					values[k] = v
				end
			end)
			return function()
				disconnect()
				app:unmount()
			end
		end,
	}
end

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

Rivue.provide = componentAPI.provide
Rivue.inject = componentAPI.inject
Rivue.hasInjectionContext = componentAPI.hasInjectionContext

Rivue.getCurrentInstance = componentAPI.getCurrentInstance
Rivue.useId = componentAPI.useId
Rivue.useTemplateRef = componentAPI.useTemplateRef

Rivue.Teleport = componentAPI.Teleport
Rivue.Suspense = builtins.Suspense
Rivue.KeepAlive = builtins.KeepAlive
Rivue.Transition = builtins.Transition
Rivue.TransitionGroup = builtins.TransitionGroup
Rivue.VirtualList = builtins.VirtualList
Rivue.ViewportModel = builtins.ViewportModel

Rivue.ErrorBoundary = uiModule.ErrorBoundary
Rivue.Dialog = uiModule.Dialog
Rivue.Row = uiModule.Row
Rivue.Column = uiModule.Column
Rivue.Spacer = uiModule.Spacer
Rivue.transitions = transitionsModule

Rivue.defineAsyncComponent = builtins.defineAsyncComponent

Rivue.useAttrs = composables.useAttrs
Rivue.useSlots = composables.useSlots
Rivue.defineModel = composables.defineModel
Rivue.useModel = composables.useModel
Rivue.useTheme = composables.useTheme
Rivue.useStyles = composables.useStyles
Rivue.useAsync = composables.useAsync

Rivue.scheduler = schedulerModule

function Rivue.queueJob(fn: () -> (), opts: QueueOptions?): JobHandle
	local jobHandle = schedulerModule.queueJob(fn, opts)
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance then
		table.insert(currentInstance._schedulerJobs, jobHandle)
	end
	return jobHandle
end

Rivue.pool = poolModule

Rivue.utils = utils
Rivue.directives = directives

Rivue.iterArray = utils.iterArray

Rivue.attributeRef = robloxUtils.attributeRef
Rivue.useTag = robloxUtils.useTag
Rivue.onRenderStepped = robloxUtils.onRenderStepped
Rivue.onHeartbeat = robloxUtils.onHeartbeat
Rivue.onStepped = robloxUtils.onStepped
Rivue.useViewportSize = robloxUtils.useViewportSize
Rivue.useDevice = robloxUtils.useDevice
Rivue.useKeybind = robloxUtils.useKeybind
Rivue.useLocale = robloxUtils.useLocale
Rivue.useTranslator = robloxUtils.useTranslator
Rivue.useScroll = robloxUtils.useScroll
Rivue.useInputType = robloxUtils.useInputType
Rivue.useSafeArea = robloxUtils.useSafeArea
Rivue.useSelection = robloxUtils.useSelection
Rivue.useGamepadFocus = robloxUtils.useGamepadFocus
Rivue.useTween = robloxUtils.useTween
Rivue.useSpring = robloxUtils.useSpring

Rivue.version = "0.9.0-rc.2"

function Rivue.bind<T>(getter: () -> T): T
	assert(type(getter) == "function", "Rivue.bind expects a function")
	return table.freeze({ __rivueBinding = getter }) :: any
end

Rivue.createApp = renderer.createApp
Rivue._devtools = table.freeze({ event = renderer.devtoolsEvent, route = renderer.devtoolsRoute })
Rivue.testing = table.freeze({
	trigger = renderer.trigger,
	setInteraction = renderer.setInteraction,
	render = testingModule.render,
	click = testingModule.click,
	typeInto = testingModule.typeInto,
})

function Rivue.mount(componentOrVNode: ComponentDef | VNode, parent: Instance, opts: AppOptions?): App
	local vnode: VNode = if (componentOrVNode :: ComponentDef).__is_component
		then hModule.h(componentOrVNode :: ComponentDef)
		else componentOrVNode :: VNode

	local app = renderer.createApp(vnode, opts)
	app:mount(parent)
	return app
end

Rivue.vModelText = directives.vModelText
Rivue.vModelProp = directives.vModelProp

return Rivue
