--!strict
--!optimize 2

-- Shared types for the runtime, re-exported from main.

-- Reactivity

export type Ref<T> = {
	value: T,
}

export type ComputedRef<T> = {
	value: T,
	get: () -> T,
}

export type WritableComputedOptions<T> = {
	get: () -> T,
	set: (value: T) -> (),
}

export type MaybeRef<T> = T | Ref<T>
export type MaybeRefOrGetter<T> = T | Ref<T> | () -> T

export type EffectScheduler = (run: () -> ()) -> ()

-- What a debug hook (onTrack/onTrigger, onRenderTracked/onRenderTriggered) receives
export type DebuggerEvent = {
	-- The reactive table (raw) or ref that was read or written
	target: unknown,
	key: unknown,
}

export type EffectOptions = {
	scheduler: EffectScheduler?,
	lazy: boolean?,
	-- Debug hooks: a dependency was tracked / triggered this effect
	onTrack: ((event: DebuggerEvent) -> ())?,
	onTrigger: ((event: DebuggerEvent) -> ())?,
	-- Let the effect re-trigger itself while running (component renders: state set during patch)
	allowRecurse: boolean?,
}

export type Dep = { [Effect]: true }

export type Effect = {
	fn: () -> (),
	scheduler: EffectScheduler?,
	deps: { Dep },
	active: boolean,
	run: () -> (),
	-- run() that skips stopped effects, used for queued runs
	job: () -> (),
	stop: (self: Effect) -> (),
	onTrack: ((event: DebuggerEvent) -> ())?,
	onTrigger: ((event: DebuggerEvent) -> ())?,
	allowRecurse: boolean?,
}

export type EffectScope = {
	active: boolean,
	effects: { Effect },
	cleanups: { () -> () },
	scopes: { EffectScope },
	parent: EffectScope?,
	-- Returns unknown, the type checker can't handle a generic method here
	run: (self: EffectScope, fn: () -> unknown) -> unknown,
	stop: (self: EffectScope) -> (),
}

-- "pre" (default): before render, "post": next Heartbeat, "sync": immediately
export type FlushMode = "pre" | "post" | "sync"

export type WatchOptions = {
	immediate: boolean?,
	-- true, or how many levels to traverse
	deep: (boolean | number)?,
	flush: FlushMode?,
	-- Stop after the first callback
	once: boolean?,
}

export type OnCleanup = (fn: () -> ()) -> ()

export type WatchCallback<T> = (newValue: T, oldValue: T?, onCleanup: OnCleanup) -> ()

export type WatchSource<T> = (() -> T) | Ref<T>

export type WatchStopHandle = () -> ()

-- Callable like a stop handle, plus pause/resume
export type WatchHandle = typeof(setmetatable(
	{} :: {
		stop: (...any) -> (),
		pause: () -> (),
		resume: () -> (),
	},
	{} :: { __call: (self: any) -> () }
))

export type CustomRefAccessor<T> = {
	get: () -> T,
	set: (value: T) -> (),
}

export type CustomRefFactory<T> = (track: () -> (), trigger: () -> ()) -> CustomRefAccessor<T>

-- Scheduler

export type QueueMode = "micro" | "render" | "heartbeat"

export type QueueOptions = {
	mode: QueueMode?,
}

export type JobHandle = {
	cancel: () -> (),
}

-- Virtual DOM

export type Props = { [string]: any }

export type Child = VNode | string | number | () -> VNode?

-- Named/scoped slot: receives the scope passed to ctx.renderSlot()
export type SlotFunction = (scope: any) -> ({ ChildInput } | Child)?
export type Slots = { [string]: SlotFunction }

-- What h() accepts as a child: nested lists ({ header, hFor(...) }) and nil/false (from hIf
-- or `cond and h(...)`) are fine
export type ChildInput = (Child | { ChildInput } | boolean)?

-- A list of ChildInput (default slot), a single child, or for components a table of named slot
-- functions. Typed as any table so mixed list literals type-check under the old solver.
export type Children = { [unknown]: unknown } | string | number | () -> VNode?

export type FunctionalComponent = (props: Props) -> VNode?

-- Renders its children without a wrapper Instance
export type FragmentType = { __fragment: true, __name: "Fragment" }

export type VNodeType = string | ComponentDef | FunctionalComponent | FragmentType

export type VNode = {
	type: VNodeType,
	props: Props?,
	-- Named slot functions passed to a component
	slots: Slots?,
	children: { Child },
	key: unknown?,
	_uid: number,
	-- Set by the renderer
	el: Instance?,
	_instance: unknown?,
	_conns: { [string]: RBXScriptConnection }?,
	-- Current handler per event, the connection calls whatever is here
	_handlers: { [string]: (...any) -> () }?,
	_dirs: { [string]: unknown }?,
	_touched: { [string]: boolean }?,
	_fnTree: VNode?,
	-- Component that rendered this vnode, for string refs
	_owner: unknown?,
	-- Set by <Transition>/<TransitionGroup>
	_transition: TransitionConfig?,
	_transitionHooks: { [string]: { (el: Instance) -> () } }?,
	-- Running enter tween, cancelled if the element leaves first
	_tween: Tween?,
	-- Generated UICorner/UIPadding/... children
	_sugar: { [string]: Instance }?,
	-- KeepAlive bookkeeping
	_keepAlive: { disposed: boolean }?,
	_kept: boolean?,
	_teleportTarget: Instance?,
	-- Teleport with defer, waiting for the post-mount flush
	_deferred: boolean?,
	-- class prop already merged into props
	_classApplied: boolean?,
}

-- Tween-based enter/leave animation, as the `transition` prop or from <Transition>
export type TransitionConfig = {
	tweenInfo: TweenInfo?,
	info: TweenInfo?,
	enterInfo: TweenInfo?,
	leaveInfo: TweenInfo?,
	-- Applied before enter and tweened to on leave (the "hidden" state)
	from: { [string]: any }?,
	enterFrom: { [string]: any }?,
	enterGoals: { [string]: any }?,
	leaveGoals: { [string]: any }?,
	goals: { [string]: any }?,
	enter: boolean?,
	leave: boolean?,
	onBeforeEnter: ((el: Instance) -> ())?,
	onAfterEnter: ((el: Instance) -> ())?,
	onBeforeLeave: ((el: Instance) -> ())?,
	onAfterLeave: ((el: Instance) -> ())?,
}

-- Components

-- type() or typeof() name: "string", "number", "table", "UDim2", "Color3", "Instance", ...
export type PropTypeName = string

export type PropSpec = {
	-- One type name or a list of allowed ones
	type: (PropTypeName | { PropTypeName })?,
	required: boolean?,
	-- Use a function for table defaults
	default: unknown?,
	validator: ((value: any) -> boolean)?,
}

export type PropSchema = { [string]: PropSpec }

export type SetupContext = {
	emit: (eventName: string, ...any) -> (),
	provide: (key: string, value: unknown) -> (),
	inject: (key: string, default: unknown?) -> unknown?,
	-- Default slot children (array children passed to the component)
	slots: { Child },
	-- Renders a named or scoped slot, falling back to `fallback` when it wasn't passed
	renderSlot: (name: string, scope: any?, fallback: { Child }?) -> { Child },
	hasSlot: (name: string) -> boolean,
	attrs: Props,
	-- app.config.globalProperties
	globals: { [string]: unknown },
	expose: (exposed: { [string]: unknown }?) -> (),
	onUnmounted: (fn: () -> ()) -> (),
}

export type RenderFunction = () -> VNode?

-- A render function, or state for the render option
export type SetupResult = RenderFunction | { [string]: unknown }

-- Event names, or event name -> payload validator
export type EmitsOptions = { string } | { [string]: (...any) -> boolean }

-- What render(ctx) receives: setup's state (refs unwrapped), props, then emit/slots/attrs/...
export type RenderContext = { [string]: any }

export type ComponentOptions = {
	name: string?,
	props: PropSchema?,
	emits: EmitsOptions?,
	-- Local components, used as h("Name") inside this component
	components: { [string]: ComponentDef }?,
	-- Named prop tables for the class prop, checked before the app's styles
	styles: { [string]: Props }?,
	setup: ((props: Props, ctx: SetupContext) -> SetupResult)?,
	-- With setup returning state, render gets that state (see RenderContext)
	render: ((ctx: RenderContext) -> VNode?)?,
	inheritAttrs: boolean?,
}

export type ComponentDef = {
	__is_component: true,
	__name: string?,
	props: PropSchema?,
	emits: EmitsOptions?,
	components: { [string]: ComponentDef }?,
	styles: { [string]: Props }?,
	-- Renderer keeps this component's children alive (KeepAlive)
	__isKeepAlive: true?,
	setup: ((props: Props, ctx: SetupContext) -> SetupResult)?,
	-- With setup returning state, render gets that state (see RenderContext)
	render: ((ctx: RenderContext) -> VNode?)?,
	inheritAttrs: boolean?,
}

export type AsyncComponentOptions = {
	loadingComponent: VNode?,
	errorComponent: VNode?,
	-- ms
	delay: number?,
	-- ms
	timeout: number?,
}

export type SuspenseContext = {
	register: () -> (),
	resolve: () -> (),
	reject: (err: string) -> (),
}

-- Directives

-- Whatever mounted/updated return is passed back to later hooks
export type Directive = {
	mounted: ((el: Instance, value: any) -> any)?,
	updated: ((el: Instance, value: any, state: any) -> any)?,
	unmounted: ((el: Instance, state: any) -> ())?,
}

-- App

export type PoolOptions = {
	usePool: boolean?,
}

export type AppConfig = {
	-- Called for errors no onErrorCaptured handler stopped
	errorHandler: ((err: string, instance: unknown, info: string) -> ())?,
	-- Shared values every component can read through ctx.globals
	globalProperties: { [string]: unknown }?,
	-- Receives Studio warnings instead of warn(): (message, instance, componentTrace)
	warnHandler: ((message: string, instance: unknown, trace: string) -> ())?,
}

export type AppContext = {
	provides: { [unknown]: unknown },
	config: AppConfig,
	-- Registered with app:component(), used for string types in h()
	components: { [string]: ComponentDef },
	-- Registered with app:styles(), used by the class prop
	styles: { [string]: Props },
}

export type PoolConfig = {
	maxPoolSize: number?,
	maxTotalSize: number?,
	enableMetrics: boolean?,
	enableDebug: boolean?,
	-- seconds
	defaultTTL: number?,
	enableAutoWarmup: boolean?,
}

export type AppOptions = {
	usePool: boolean?,
	poolConfig: PoolConfig?,
	-- ClassName -> count
	poolWarmup: { [string]: number }?,
}

return {}
