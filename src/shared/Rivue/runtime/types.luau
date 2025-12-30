--!strict
--!optimize 2

--[[
	types.luau
	==========

	Shared types for the runtime. Also re-exported from main.

	Usage:
	------

		local Types = require(ReplicatedStorage.Rivue.runtime.types)
		local count: Types.Ref<number> = Rivue.ref(0)

	@module types

	@author Rivue

	@version 1.0.0
]]

-- ===== Reactivity =====

export type Ref<T> = {
	value: T,
}

export type ComputedRef<T> = {
	value: T,
	get: () -> T,
}

export type MaybeRef<T> = T | Ref<T>

export type EffectScheduler = (run: () -> ()) -> ()

export type EffectOptions = {
	scheduler: EffectScheduler?,
	lazy: boolean?,
}

export type Dep = { [Effect]: true }

export type Effect = {
	fn: () -> (),
	scheduler: EffectScheduler?,
	deps: { Dep },
	active: boolean,
	run: () -> (),
	stop: (self: Effect) -> (),
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
	deep: boolean?,
	flush: FlushMode?,
}

export type OnCleanup = (fn: () -> ()) -> ()

export type WatchCallback<T> = (newValue: T, oldValue: T?, onCleanup: OnCleanup) -> ()

export type WatchSource<T> = (() -> T) | Ref<T>

export type WatchStopHandle = () -> ()

export type CustomRefAccessor<T> = {
	get: () -> T,
	set: (value: T) -> (),
}

export type CustomRefFactory<T> = (track: () -> (), trigger: () -> ()) -> CustomRefAccessor<T>

-- ===== Scheduler =====

export type QueueMode = "micro" | "render" | "heartbeat"

export type QueueOptions = {
	mode: QueueMode?,
}

export type JobHandle = {
	cancel: () -> (),
}

-- ===== Virtual DOM =====

export type Props = { [string]: any }

export type Child = VNode | string | number | () -> VNode?
export type Children = { Child } | Child

export type FunctionalComponent = (props: Props) -> VNode?

export type VNodeType = string | ComponentDef | FunctionalComponent

export type VNode = {
	type: VNodeType,
	props: Props?,
	children: { Child },
	key: unknown?,
	_uid: number,
	-- Set by the renderer
	el: Instance?,
	_instance: unknown?,
	_conns: { [string]: RBXScriptConnection }?,
	_dirs: { [string]: unknown }?,
	_touched: { [string]: boolean }?,
	_fnTree: VNode?,
}

-- ===== Components =====

export type PropTypeName = "string" | "number" | "boolean" | "table" | "function"

export type PropSpec = {
	type: PropTypeName?,
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
	slots: { Child },
	attrs: Props,
	expose: (exposed: { [string]: unknown }?) -> (),
	onUnmounted: (fn: () -> ()) -> (),
}

export type RenderFunction = () -> VNode?

export type SetupResult = RenderFunction | { render: RenderFunction, [string]: unknown }

export type ComponentOptions = {
	name: string?,
	props: PropSchema?,
	setup: ((props: Props, ctx: SetupContext) -> SetupResult)?,
	render: ((props: Props) -> VNode?)?,
	inheritAttrs: boolean?,
}

export type ComponentDef = {
	__is_component: true,
	__name: string?,
	props: PropSchema?,
	setup: ((props: Props, ctx: SetupContext) -> SetupResult)?,
	render: ((props: Props) -> VNode?)?,
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

-- ===== Directives =====

-- Whatever mounted/updated return is passed back to later hooks
export type Directive = {
	mounted: ((el: Instance, value: any) -> any)?,
	updated: ((el: Instance, value: any, state: any) -> any)?,
	unmounted: ((el: Instance, state: any) -> ())?,
}

-- ===== App =====

export type PoolOptions = {
	usePool: boolean?,
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
