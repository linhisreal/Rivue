--!strict
--!optimize 2

--[[
	Types.luau
	==========

	Shared public types for the Rivue runtime. Every runtime module imports its types from here
	so the public surface has one definition, and consumers can annotate their own code:

	```lua
	local Types = require(ReplicatedStorage.Rivue.runtime.types)
	local count: Types.Ref<number> = Rivue.ref(0)
	```

	(The same types are re-exported from main, e.g. `Rivue.Ref<number>` once main is required statically.)

	Conventions:
	- `unknown` for values Rivue stores but never inspects; callers must refine with `type()`/`typeof()`.
	- `any` only where Luau's type system can't express the shape (dynamic proxies, heterogeneous prop bags).
	- Singleton types (`"pre" | "post" | "sync"`, `true`) instead of plain strings/booleans for closed sets.

	@module types
]]

-- ===== Reactivity =====

--- Reactive reference. Reading `.value` tracks, writing `.value` triggers.
export type Ref<T> = {
	value: T,
}

--- Cached derived value. `.value` (or `get()`) re-computes only when a dependency changed.
export type ComputedRef<T> = {
	value: T,
	get: () -> T,
}

--- Anything `unref`/`watch` accept: a ref or a plain value.
export type MaybeRef<T> = T | Ref<T>

--- How an effect is re-run when one of its dependencies changes. Receives the effect's runner.
export type EffectScheduler = (run: () -> ()) -> ()

export type EffectOptions = {
	scheduler: EffectScheduler?,
	--- When true the effect doesn't run until `effect.run()` is called.
	lazy: boolean?,
}

--- Set of effects subscribed to one (target, key) pair.
export type Dep = { [Effect]: true }

export type Effect = {
	fn: () -> (),
	scheduler: EffectScheduler?,
	deps: { Dep },
	active: boolean,
	--- Runs the effect now, re-collecting its dependencies.
	run: () -> (),
	stop: (self: Effect) -> (),
}

export type EffectScope = {
	active: boolean,
	effects: { Effect },
	cleanups: { () -> () },
	scopes: { EffectScope },
	parent: EffectScope?,
	--- Returns fn's result (nil on error). Typed `unknown`: the old type solver can't keep a generic
	--- method inside a recursive type, so refine or cast the result at the call site.
	run: (self: EffectScope, fn: () -> unknown) -> unknown,
	stop: (self: EffectScope) -> (),
}

--- "pre" (default): deferred before render, "post": next Heartbeat, "sync": immediately on change.
export type FlushMode = "pre" | "post" | "sync"

export type WatchOptions = {
	immediate: boolean?,
	deep: boolean?,
	flush: FlushMode?,
}

export type OnCleanup = (fn: () -> ()) -> ()

export type WatchCallback<T> = (newValue: T, oldValue: T?, onCleanup: OnCleanup) -> ()

--- A getter function or a ref. Plain reactive objects are also accepted (use `deep = true`).
export type WatchSource<T> = (() -> T) | Ref<T>

export type WatchStopHandle = () -> ()

--- Returned by `customRef`'s factory.
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

--- Props passed to an element or component. Values are heterogeneous by nature (Instance
--- properties, event handlers, refs, directives), so this is the one intentionally loose bag.
export type Props = { [string]: any }

--- What `h()` accepts as children before normalization.
export type Child = VNode | string | number | () -> VNode?
export type Children = { Child } | Child

--- Functional component: props in, tree out.
export type FunctionalComponent = (props: Props) -> VNode?

--- `type` of a vnode: a ClassName ("Frame"), a component definition, or a functional component.
export type VNodeType = string | ComponentDef | FunctionalComponent

export type VNode = {
	type: VNodeType,
	props: Props?,
	children: { Child },
	key: unknown?,
	_uid: number,
	-- Renderer bookkeeping (internal; filled in while mounted)
	el: Instance?,
	--- ComponentInstance for component vnodes (typed in component.luau; cast at use)
	_instance: unknown?,
	_conns: { [string]: RBXScriptConnection }?,
	_dirs: { [string]: unknown }?,
	--- Props written to the Instance, restored to class defaults when pooled
	_touched: { [string]: boolean }?,
	--- Output tree of a functional component vnode
	_fnTree: VNode?,
}

-- ===== Components =====

--- Runtime prop type names understood by prop validation.
export type PropTypeName = "string" | "number" | "boolean" | "table" | "function"

export type PropSpec = {
	type: PropTypeName?,
	required: boolean?,
	--- Literal default, or a factory for tables (so instances don't share one table).
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

--- `setup` returns either a render function or a table that contains one.
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

-- ===== Directives =====

export type DirectiveHook = (el: Instance, value: any) -> unknown

export type Directive = {
	mounted: DirectiveHook?,
	updated: ((el: Instance, value: any, state: unknown) -> ())?,
	unmounted: ((el: Instance, state: unknown) -> ())?,
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
	--- Seconds an idle pooled Instance may live before eviction
	defaultTTL: number?,
	enableAutoWarmup: boolean?,
}

export type AppOptions = {
	usePool: boolean?,
	poolConfig: PoolConfig?,
	--- ClassName -> number of Instances to pre-create
	poolWarmup: { [string]: number }?,
}

return {}
