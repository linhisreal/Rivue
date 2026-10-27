--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

export type Ref<T> = {
	value: T,
}

export type ComputedRef<T> = {
	value: T,
	get: () -> T,
}

export type WritableComputedOptions<T> = {
	get: (previous: T?) -> T,
	set: (value: T) -> (),
}

export type MaybeRef<T> = T | Ref<T>
export type MaybeRefOrGetter<T> = T | Ref<T> | () -> T

export type EffectScheduler = (run: () -> ()) -> ()

export type DebuggerEvent = {
	target: unknown,
	key: unknown,
}

export type EffectOptions = {
	scheduler: EffectScheduler?,
	lazy: boolean?,
	onTrack: ((event: DebuggerEvent) -> ())?,
	onTrigger: ((event: DebuggerEvent) -> ())?,
	allowRecurse: boolean?,
}

export type Dep = { [Effect]: true }

export type Effect = {
	fn: () -> (),
	scheduler: EffectScheduler?,
	deps: { Dep },
	active: boolean,
	run: () -> (),
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
	run: (self: EffectScope, fn: () -> unknown) -> unknown,
	stop: (self: EffectScope) -> (),
}

export type FlushMode = "pre" | "post" | "sync"

export type WatchOptions = {
	immediate: boolean?,
	deep: (boolean | number)?,
	flush: FlushMode?,
	once: boolean?,
}

export type OnCleanup = (fn: () -> ()) -> ()

export type WatchCallback<T> = (newValue: T, oldValue: T?, onCleanup: OnCleanup) -> ()

export type WatchSource<T> = (() -> T) | Ref<T>

export type WatchStopHandle = () -> ()

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

export type QueueMode = "micro" | "render" | "heartbeat"

export type QueueOptions = {
	mode: QueueMode?,
}

export type JobHandle = {
	cancel: () -> (),
}

export type Props = { [string]: any }

export type Child = VNode | string | number | () -> VNode?

export type SlotFunction = (scope: any) -> ({ ChildInput } | Child)?
export type Slots = { [string]: SlotFunction }

export type ChildInput = (Child | { ChildInput } | boolean)?

export type Children = { [unknown]: unknown } | string | number | () -> VNode?

export type FunctionalComponent = (props: Props) -> VNode?

export type FragmentType = { __fragment: true, __name: "Fragment" }

export type VNodeType = string | ComponentDef | FunctionalComponent | FragmentType

export type VNode = {
	type: VNodeType,
	props: Props?,
	slots: Slots?,
	children: { Child },
	key: unknown?,
	_uid: number,
	el: Instance?,
	_instance: unknown?,
	_conns: { [string]: RBXScriptConnection }?,
	_handlers: { [string]: (...any) -> () }?,
	_dirs: { [string]: unknown }?,
	_touched: { [string]: boolean }?,
	_bindings: { [any]: any }?,
	_fnTree: VNode?,
	_owner: unknown?,
	_transition: TransitionConfig?,
	_transitionHooks: { [string]: { (el: Instance) -> () } }?,
	_tween: Tween?,
	_sugar: { [string]: Instance }?,
	_keepAlive: { disposed: boolean }?,
	_kept: boolean?,
	_teleportTarget: Instance?,
	_deferred: boolean?,
	_classApplied: boolean?,
}

export type TransitionConfig = {
	tweenInfo: TweenInfo?,
	info: TweenInfo?,
	enterInfo: TweenInfo?,
	leaveInfo: TweenInfo?,
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

export type PropTypeName = string

export type PropSpec = {
	type: (PropTypeName | { PropTypeName })?,
	required: boolean?,
	default: unknown?,
	validator: ((value: any) -> boolean)?,
}

export type PropSchema = { [string]: PropSpec }

export type SetupContext = {
	emit: (eventName: string, ...any) -> (),
	provide: (key: string, value: unknown) -> (),
	inject: (key: string, default: unknown?) -> unknown?,
	slots: { Child },
	renderSlot: (name: string, scope: any?, fallback: { Child }?) -> { Child },
	hasSlot: (name: string) -> boolean,
	attrs: Props,
	globals: { [string]: unknown },
	expose: (exposed: { [string]: unknown }?) -> (),
	onUnmounted: (fn: () -> ()) -> (),
}

export type RenderFunction = () -> VNode?

export type SetupResult = RenderFunction | { [string]: unknown }

export type EmitsOptions = { string } | { [string]: (...any) -> boolean }

export type RenderContext = { [string]: any }

export type ComponentOptions = {
	name: string?,
	props: PropSchema?,
	emits: EmitsOptions?,
	components: { [string]: ComponentDef }?,
	styles: { [string]: Props }?,
	setup: ((props: Props, ctx: SetupContext) -> SetupResult)?,
	render: ((ctx: RenderContext) -> VNode?)?,
	inheritAttrs: boolean?,
}

export type ComponentDef = {
	__is_component: true,
	__name: string?,
	__source: string?,
	props: PropSchema?,
	emits: EmitsOptions?,
	components: { [string]: ComponentDef }?,
	styles: { [string]: Props }?,
	__isKeepAlive: true?,
	setup: ((props: Props, ctx: SetupContext) -> SetupResult)?,
	render: ((ctx: RenderContext) -> VNode?)?,
	inheritAttrs: boolean?,
}

export type AsyncComponentOptions = {
	loadingComponent: VNode?,
	errorComponent: VNode?,
	delay: number?,
	timeout: number?,
	onError: ((err: string, retry: () -> (), fail: () -> (), attempts: number) -> ())?,
}

export type SuspenseContext = {
	register: () -> (),
	resolve: () -> (),
	reject: (err: string) -> (),
}

export type Directive = {
	mounted: ((el: Instance, value: any) -> any)?,
	updated: ((el: Instance, value: any, state: any) -> any)?,
	unmounted: ((el: Instance, state: any) -> ())?,
}

export type PoolOptions = {
	usePool: boolean?,
}

export type AppConfig = {
	errorHandler: ((err: string, instance: unknown, info: string) -> ())?,
	globalProperties: { [string]: unknown }?,
	warnHandler: ((message: string, instance: unknown, trace: string) -> ())?,
	devtools: boolean?,
}

export type AppContext = {
	provides: { [unknown]: unknown },
	config: AppConfig,
	components: { [string]: ComponentDef },
	styles: { [string]: Props },
}

export type PoolConfig = {
	maxPoolSize: number?,
	maxTotalSize: number?,
	enableMetrics: boolean?,
	enableDebug: boolean?,
	defaultTTL: number?,
	enableAutoWarmup: boolean?,
}

export type AppOptions = {
	usePool: boolean?,
	poolConfig: PoolConfig?,
	poolWarmup: { [string]: number }?,
}

return {}
