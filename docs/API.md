# Rivue API Documentation

A Vue.js-inspired reactive UI Rivue for Roblox, built with Luau.

## Table of Contents

- [Rivue API Documentation](#rivue-api-documentation)
  - [Table of Contents](#table-of-contents)
  - [Installation \& Setup](#installation--setup)
    - [Basic Usage](#basic-usage)
    - [Creating an Application](#creating-an-application)
  - [Core Concepts](#core-concepts)
    - [Virtual DOM (VNode)](#virtual-dom-vnode)
    - [Components](#components)
  - [Reactivity API](#reactivity-api)
    - [`ref<T>(initialValue: T): Ref<T>`](#reftinitialvalue-t-reft)
    - [`shallowRef<T>(initialValue: T): Ref<T>`](#shallowreftinitialvalue-t-reft)
    - [`reactive(target: table): table`](#reactivetarget-table-table)
    - [`shallowReactive(target: table): table`](#shallowreactivetarget-table-table)
    - [`computed<T>(getter: () -> T): ComputedRef<T>`](#computedtgetter----t-computedreft)
    - [`watch(source, callback, options?)`](#watchsource-callback-options)
    - [`watchEffect(fn: () -> ()): StopHandle`](#watcheffectfn-----stophandle)
    - [`effect(fn: () -> (), options?): Effect`](#effectfn-----options-effect)
    - [`readonly<T>(target: T): T`](#readonlyttarget-t-t)
    - [`toRef(object: table, key: string): Ref<any>`](#torefobject-table-key-string-refany)
    - [`toRefs(object: table): { [string]: Ref<any> }`](#torefsobject-table--string-refany-)
    - [`isRef(value: any): boolean`](#isrefvalue-any-boolean)
    - [`unref<T>(value: T | Ref<T>): T`](#unreftvalue-t--reft-t)
    - [`isReactive(value: any): boolean`](#isreactivevalue-any-boolean)
  - [Example: Defensive Utility Function](#example-defensive-utility-function)
    - [`isReadonly(value: any): boolean`](#isreadonlyvalue-any-boolean)
      - [Example: Prevent Accidental Mutations](#example-prevent-accidental-mutations)
    - [`isProxy(value: any): boolean`](#isproxyvalue-any-boolean)
      - [Example: Optimization Pattern](#example-optimization-pattern)
    - [`markRaw<T>(object: T): T`](#markrawtobject-t-t)
    - [`toRaw<T>(proxy: T): T`](#torawtproxy-t-t)
    - [`triggerRef(ref: Ref<any>)`](#triggerrefref-refany)
    - [`customRef<T>(factory: (track: () -> (), trigger: () -> ()) -> { get: () -> T, set: (value: T) -> () }): Ref<T>`](#customreftfactory-track-----trigger--------get----t-set-value-t-----reft)
      - [Example 1: Debounced Ref (Common Use Case)](#example-1-debounced-ref-common-use-case)
      - [Example 2: Validation Ref](#example-2-validation-ref)
      - [Example 3: Lazy Ref (Compute on First Access)](#example-3-lazy-ref-compute-on-first-access)
      - [Example 4: Roblox DataStore Sync](#example-4-roblox-datastore-sync)
      - [Example 5: Readonly Computed Re](#example-5-readonly-computed-re)
    - [`effectScope(detached?: boolean): EffectScope`](#effectscopedetached-boolean-effectscope)
      - [Example 1: Plugin System](#example-1-plugin-system)
      - [Example 2: Nested Scopes](#example-2-nested-scopes)
      - [Example 3: Detached Scopes](#example-3-detached-scopes)
      - [Example 4: Roblox Service Manager](#example-4-roblox-service-manager)
      - [Example 5: Temporary Scope for Testing](#example-5-temporary-scope-for-testing)
    - [`getCurrentScope(): EffectScope?`](#getcurrentscope-effectscope)
    - [`onScopeDispose(fn: () -> (), failSilently?: boolean)`](#onscopedisposefn-----failsilently-boolean)
      - [Example 1: Resource Cleanup](#example-1-resource-cleanup)
      - [Example 2: Multiple Cleanup Callbacks](#example-2-multiple-cleanup-callbacks)
    - [Example 3: Fail Silently (Advanced)](#example-3-fail-silently-advanced)
  - [Component API](#component-api)
    - [`defineComponent(options): ComponentDefinition`](#definecomponentoptions-componentdefinition)
      - [Default Values](#default-values)
      - [Prop Validators](#prop-validators)
      - [`context.attrs: { [string]: any }`](#contextattrs--string-any-)
      - [`context.expose(exposed: { [string]: any }?)`](#contextexposeexposed--string-any-)
      - [`context.emit(eventName: string, ...args)`](#contextemiteventname-string-args)
      - [`context.provide(key: any, value: any)`](#contextprovidekey-any-value-any)
      - [`context.inject(key: any, default: any?): any`](#contextinjectkey-any-default-any-any)
      - [`context.slots: { VNode }`](#contextslots--vnode-)
  - [Rendering API](#rendering-api)
    - [`h(type, props?, children?): VNode`](#htype-props-children-vnode)
    - [`hIf(condition: boolean, vnode: VNode): VNode?`](#hifcondition-boolean-vnode-vnode-vnode)
    - [`hFor<T>(list: { T }, mapper: (item: T, index: number) -> VNode?): { VNode }`](#hfortlist--t--mapper-item-t-index-number---vnode--vnode-)
    - [`hForParallel<T>(list: { T }, mapper: (item: T, index: number) -> VNode?, keyFn?: (item: T) -> any): { VNode }`](#hforparalleltlist--t--mapper-item-t-index-number---vnode-keyfn-item-t---any--vnode-)
    - [`createApp(rootVNode: VNode, options?): App`](#createapprootvnode-vnode-options-app)
    - [`Rivue.mount(componentOrVNode, parent, options?)`](#rivuemountcomponentorvnode-parent-options)
  - [Lifecycle Hooks](#lifecycle-hooks)
    - [`onBeforeMount(callback: () -> ())`](#onbeforemountcallback----)
    - [`onMounted(callback: () -> ())`](#onmountedcallback----)
    - [`onBeforeUpdate(callback: () -> ())`](#onbeforeupdatecallback----)
    - [`onUpdated(callback: () -> ())`](#onupdatedcallback----)
    - [`onBeforeUnmount(callback: () -> ())`](#onbeforeunmountcallback----)
    - [`onUnmounted(callback: () -> ())`](#onunmountedcallback----)
    - [`onErrorCaptured(callback: (err: string, instance: ComponentInstance, info: string) -> boolean?)`](#onerrorcapturedcallback-err-string-instance-componentinstance-info-string---boolean)
    - [`onTransition(name: string, callback: (el: Instance) -> ())`](#ontransitionname-string-callback-el-instance---)
  - [Directives](#directives)
    - [Built-in Directives](#built-in-directives)
      - [`v-focus`](#v-focus)
      - [`v-click-outside`](#v-click-outside)
      - [`v-drag`](#v-drag)
      - [`v-fade-in`](#v-fade-in)
      - [`v-show`](#v-show)
      - [`v-preload`](#v-preload)
      - [`v-memo`](#v-memo)
      - [`v-once`](#v-once)
    - [v-model Helpers](#v-model-helpers)
      - [`vModelText(ref: Ref<string>, options?: { debounce: number? }): { Text: string, onTextChanged: function }`](#vmodeltextref-refstring-options--debounce-number---text-string-ontextchanged-function-)
      - [`vModelProp(ref: Ref<any>, propName: string, eventName?: string)`](#vmodelpropref-refany-propname-string-eventname-string)
    - [Custom Directives](#custom-directives)
  - [Utilities](#utilities)
    - [Async Utilities](#async-utilities)
      - [`utils.debounce(fn: function, ms: number): function`](#utilsdebouncefn-function-ms-number-function)
      - [`utils.throttle(fn: function, ms: number): function`](#utilsthrottlefn-function-ms-number-function)
      - [`utils.nextTick(fn: () -> ())`](#utilsnexttickfn----)
      - [`utils.nextFrame(fn: () -> ())`](#utilsnextframefn----)
      - [`utils.useRaf(fn: (deltaTime: number) -> ()): { stop: () -> () }`](#utilsuseraffn-deltatime-number-----stop-----)
    - [Other Utilities](#other-utilities)
      - [`utils.filterForClient(player: Player, text: string): string`](#utilsfilterforclientplayer-player-text-string-string)
      - [`utils.profiler`](#utilsprofiler)
      - [`utils.shallowEqual(a: any, b: any): boolean`](#utilsshallowequala-any-b-any-boolean)
      - [`iterArray<T>(array: { T }): () -> (number?, T?)`](#iterarraytarray--t-----number-t)
    - [Scheduler](#scheduler)
      - [`scheduler.queueJob(fn: () -> (), mode?: "micro" | "render" | "heartbeat"): () -> ()`](#schedulerqueuejobfn-----mode-micro--render--heartbeat----)
  - [Luau \& Roblox Quirks](#luau--roblox-quirks)
    - [Reactive Proxies and `pairs()`](#reactive-proxies-and-pairs)
    - [Reactive Arrays and `ipairs()`](#reactive-arrays-and-ipairs)
    - [Operator on Reactive Arrays](#operator-on-reactive-arrays)
    - [Property Access on Reactive Objects](#property-access-on-reactive-objects)
    - [Time Units: Milliseconds vs Seconds](#time-units-milliseconds-vs-seconds)
    - [Instance Property Reactivity](#instance-property-reactivity)
    - [Table Mutation Detection](#table-mutation-detection)
  - [Rivue Configuration](#rivue-configuration)
    - [`Rivue.dev: boolean`](#rivuedev-boolean)
    - [`Rivue.debug: boolean`](#rivuedebug-boolean)
    - [`Rivue.log(level: string, message: string, data: any?)`](#rivueloglevel-string-message-string-data-any)
  - [Remote Communication](#remote-communication)
    - [`Remote.request(actionName: string, payload: any, timeout?: number): (data: any?, error: string?)`](#remoterequestactionname-string-payload-any-timeout-number-data-any-error-string)
    - [`Remote.fire(actionName: string, payload: any)`](#remotefireactionname-string-payload-any)
    - [`Remote.on(eventName: string, callback: function): RBXScriptConnection`](#remoteoneventname-string-callback-function-rbxscriptconnection)
  - [Advanced Features](#advanced-features)
    - [Keyed Children](#keyed-children)
    - [Transitions](#transitions)
    - [Object Pooling](#object-pooling)
    - [Teleport (Portal)](#teleport-portal)
      - [Example: Modal System](#example-modal-system)
    - [Suspense](#suspense)
    - [KeepAlive](#keepalive)
      - [Example: Tab System with State Preservation](#example-tab-system-with-state-preservation)
    - [defineAsyncComponent](#defineasynccomponent)
      - [Example: Lazy-Loded Settings Panel](#example-lazy-loded-settings-panel)
    - [Composition API Helpers](#composition-api-helpers)
      - [`useAttrs(): { [string]: any }`](#useattrs--string-any-)
      - [`useSlots(): { VNode }`](#useslots--vnode-)
      - [`defineModel(options?: { name: string?, event: string? }): (props, context) -> ComputedRef`](#definemodeloptions--name-string-event-string--props-context---computedref)
      - [`useTheme(): any?`](#usetheme-any)
      - [`useStyles(factory: (theme: any) -> table): ComputedRef<table>`](#usestylesfactory-theme-any---table-computedreftable)
    - [Scheduler API](#scheduler-api)
      - [Example: Batched State Updates](#example-batched-state-updates)
      - [Auto-Cleanup](#auto-cleanup)
    - [Roblox Integration Utilities](#roblox-integration-utilities)
      - [`attributeRef(instance: Instance, attributeName: string, defaultValue?: T, options?: { throttle: number? }): Ref<T>`](#attributerefinstance-instance-attributename-string-defaultvalue-t-options--throttle-number--reft)
      - [`useTag(tagName: string, onAdded: (instance: Instance) -> (() -> ())?)`](#usetagtagname-string-onadded-instance-instance------)
      - [`onRenderStepped(callback: (deltaTime: number) -> ())`](#onrendersteppedcallback-deltatime-number---)
      - [`onHeartbeat(callback: (deltaTime: number) -> ())`](#onheartbeatcallback-deltatime-number---)
      - [`onStepped(callback: (time: number, deltaTime: number) -> ())`](#onsteppedcallback-time-number-deltatime-number---)
    - [Error Boundaries \& Suspense](#error-boundaries--suspense)
    - [Async Components](#async-components)
  - [Performance Tips](#performance-tips)
  - [Type Definitions Summary](#type-definitions-summary)
  - [Examples](#examples)
  - [License \& Credits](#license--credits)

---

## Installation & Setup

### Basic Usage

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))

-- Rivue is now ready to use
local h = Rivue.h
local defineComponent = Rivue.defineComponent
local ref = Rivue.ref
-- ... other APIs
```

### Creating an Application

```lua
local App = defineComponent({
    setup = function()
        return function()
            return h("ScreenGui", { ResetOnSpawn = false }, {
                h("TextLabel", {
                    Size = UDim2.fromOffset(200, 50),
                    Text = "Hello, Rivue!"
                })
            })
        end
    end
})

-- Create and mount the app
local app = Rivue.createApp(h(App), { usePool = true })
app:mount(playerGui) -- or any Roblox Instance container
```

---

## Core Concepts

### Virtual DOM (VNode)

Rivue uses a virtual DOM to efficiently render and update UI elements. VNodes are plain Luau tables representing UI elements.

```lua
-- VNode structure
type VNode = {
    type: string | table | function,
    props: { [string]: any }?,
    children: { VNode | string }?,
    key: any?,
    el: Instance?,
    _uid: {}
}
```

### Components

Components are reusable, self-contained pieces of UI. They can have reactive state, props, and lifecycle hooks.

```lua
type ComponentDefinition = {
    setup: ((props: table, context: ComponentContext) -> (() -> VNode))?,
    render: ((props: table) -> VNode)?,
    props: PropSchema?,
    __name: string?
}
```

---

## Reactivity API

The reactivity system powers Rivue's automatic UI updates.

### `ref<T>(initialValue: T): Ref<T>`

Creates a reactive reference to a value. Access/modify the value via `.value`.

```lua
local count = ref(0)
print(count.value) -- 0

count.value = 5 -- Triggers reactivity
print(count.value) -- 5

-- With complex types
local user = ref({ name = "Alice", age = 25 })
user.value = { name = "Bob", age = 30 } -- Triggers update
```

**Type Definition:**

```lua
type Ref<T> = {
    value: T,
    _is_ref: true
}
```

**When to use:**

- For primitive values (numbers, strings, booleans)
- When you need to track a single value
- When you want explicit reactivity through `.value`

---

### `shallowRef<T>(initialValue: T): Ref<T>`

Creates a shallow reactive reference. Unlike `ref()`, it doesn't automatically wrap objects in `reactive()`.

```lua
local state = shallowRef({ count: 0, nested: { value: 10 } })

-- Changing the entire object triggers reactivity
state.value = { count: 5, nested: { value: 20 } } -- Triggers update

-- Modifying nested properties does NOT trigger reactivity
state.value.count = 10 -- Does NOT trigger update
state.value.nested.value = 30 -- Does NOT trigger update
```

**When to use:**

- For large objects where deep reactivity is expensive
- When you only need to detect complete replacements
- For performance optimization with complex data structures
- When integrating with external libraries that manage their own state

**Comparison:**

```lua
-- ref: Auto-wraps objects in reactive()
local deepRef = ref({ nested: { value: 1 } })
deepRef.value.nested.value = 2 -- Triggers reactivity

-- shallowRef: No auto-wrapping, only top-level changes tracked
local shallowRef = shallowRef({ nested: { value: 1 } })
shallowRef.value.nested.value = 2 -- Does NOT trigger
shallowRef.value = { nested: { value: 2 } } -- Triggers reactivity
```

---

### `reactive(target: table): table`

Creates a deeply reactive proxy of an object. All nested properties become reactive.

```lua
local state = reactive({
    count: 0,
    user: {
        name: "Alice",
        profile: {
            age: 25
        }
    }
})

state.count = 5 -- Triggers reactivity
state.user.name = "Bob" -- Triggers reactivity (deep)
state.user.profile.age = 30 -- Triggers reactivity (deep)
```

**Type Definition:**

```lua
type ReactiveProxy<T> = T -- Proxy with reactive tracking
```

**When to use:**

- For objects with multiple properties
- When you need deep reactivity
- When you want object-like syntax without `.value`

**Note:** Reactivity is deep - nested objects are automatically reactive.

---

### `shallowReactive(target: table): table`

Creates a reactive proxy that only tracks top-level properties (shallow).

```lua
local state = shallowReactive({
    count: 0,
    nested: { value: 10 }
})

state.count = 5 -- Triggers reactivity
state.nested.value = 20 -- Does NOT trigger reactivity
state.nested = { value: 30 } -- Triggers reactivity (replacing whole object)
```

**When to use:**

- For large objects where deep tracking is expensive
- When only top-level changes matter
- For performance optimization

---

### `computed<T>(getter: () -> T): ComputedRef<T>`

Creates a computed value that automatically updates when its dependencies change.

```lua
local count = ref(10)
local double = computed(function()
    return count.value * 2
end)

print(double.value) -- 20
count.value = 15
print(double.value) -- 30 (automatically updated)
```

**Type Definition:**

```lua
type ComputedRef<T> = {
    value: T, -- Read-only
    get: () -> T
}
```

**Features:**

- Lazy evaluation (only computes when accessed)
- Automatically tracks dependencies
- Cached until dependencies change

---

### `watch(source, callback, options?)`

Watches a reactive source and runs a callback when it changes.

```lua
-- Watch a ref
local count = ref(0)
local stop = watch(
    function() return count.value end,
    function(newVal, oldVal)
        print("count changed from", oldVal, "to", newVal)
    end
)

count.value = 5 -- Logs: "count changed from 0 to 5"

-- Stop watching
stop()

-- Watch with options
watch(
    function() return state.user end,
    function(newVal, oldVal)
        print("user changed")
    end,
    {
        immediate = true, -- Run callback immediately
        deep = true -- Deep watch for nested changes
    }
)
```

**Type Definition:**

```lua
type WatchSource = () -> any | Ref<any>
type WatchCallback = (newValue: any, oldValue: any, onCleanup: (fn: () -> ()) -> ()) -> ()
type WatchOptions = {
    immediate: boolean?, -- Run callback immediately
    deep: boolean?, -- Deep watch nested properties
    flush: "pre" | "post" | "sync"? -- Timing relative to component updates (default: "post")
}
type WatchStopHandle = () -> ()

function watch(
    source: WatchSource,
    callback: WatchCallback,
    options: WatchOptions?
): WatchStopHandle
```

**Cleanup Function:**

```lua
watch(
    function() return count.value end,
    function(newVal, oldVal, onCleanup)
        local connection = someEvent:Connect(function() end)
        
        -- Cleanup when watcher re-runs or stops
        onCleanup(function()
            connection:Disconnect()
        end)
    end
)
```

---

### `watchEffect(fn: () -> ()): StopHandle`

Runs a reactive effect with automatic dependency tracking and immediate execution. Simpler alternative to `watch()` when you don't need to explicitly specify the source or compare old/new values.

```lua
local count = ref(0)
local name = ref("Alice")

-- Automatically tracks both count and name
local stop = watchEffect(function()
    print("Count:", count.value, "Name:", name.value)
end)
-- Immediately prints: "Count: 0 Name: Alice"

count.value = 5 -- Prints: "Count: 5 Name: Alice"
name.value = "Bob" -- Prints: "Count: 5 Name: Bob"

-- Stop watching
stop()
```

**Comparison with watch():**

```lua
-- watch: Requires explicit source and callback
watch(
    function() return count.value end,
    function(newVal, oldVal)
        print("Count changed from", oldVal, "to", newVal)
    end
)

-- watchEffect: Automatically tracks all dependencies
watchEffect(function()
    print("Count is:", count.value) -- Auto-tracked
end)
```

**Type Definition:**

```lua
type WatchStopHandle = () -> ()

function watchEffect(fn: () -> ()): WatchStopHandle
```

**When to use:**

- Side effects that depend on multiple reactive sources
- You don't need old/new value comparison
- Immediate execution is desired
- Simpler syntax for common reactive patterns

**Auto-cleanup:** Like `watch()` and `effect()`, `watchEffect()` automatically stops when the component unmounts if called during `setup()`.

---

### `effect(fn: () -> (), options?): Effect`

Runs a function and automatically tracks its reactive dependencies. Re-runs when dependencies change.

```lua
local count = ref(0)
local name = ref("Alice")

local eff = effect(function()
    print("Count:", count.value, "Name:", name.value)
end)

count.value = 5 -- Re-runs effect: "Count: 5 Name: Alice"
name.value = "Bob" -- Re-runs effect: "Count: 5 Name: Bob"

-- Stop the effect
eff:stop()
```

**Type Definition:**

```lua
type Effect = {
    run: () -> (),
    stop: () -> (),
    active: boolean,
    deps: { any },
    fn: () -> (),
    scheduler: ((fn: () -> ()) -> ())?
}

type EffectOptions = {
    lazy: boolean?, -- Don't run immediately
    scheduler: ((fn: () -> ()) -> ())? -- Custom scheduler
}

function effect(fn: () -> (), options: EffectOptions?): Effect
```

---

### `readonly<T>(target: T): T`

Creates a readonly reactive proxy that prevents mutations. Useful for enforcing one-way data flow, protecting props, or creating immutable public APIs.

```lua
local state = reactive({ count: 0, user: { name: "Alice" } })
local readonlyState = readonly(state)

-- Reading works normally
print(readonlyState.count) -- 0
print(readonlyState.user.name) -- "Alice"

-- Mutations are blocked (warns in Studio)
readonlyState.count = 10 -- ⚠️ Warning: Cannot mutate readonly reactive object
readonlyState.user.name = "Bob" -- ⚠️ Warning: Cannot mutate readonly reactive object

-- Original state can still be mutated
state.count = 10 -- Works
print(readonlyState.count) -- 10 (reflects original state)
```

**Type Definition:**

```lua
function readonly<T>(target: T): T
```

**Use Cases:**

1. **Protect Props in Child Components:**

```lua
local ChildComponent = defineComponent({
    setup = function(props)
        -- Prevent accidental prop mutations
        local safeProps = readonly(props)
        
        -- This would warn instead of silently mutating parent's data
        -- safeProps.title = "Changed" -- ⚠️ Warning
        
        return function()
            return h("TextLabel", { Text = safeProps.title })
        end
    end
})
```

1. **Enforce One-Way Data Flow in Provide/Inject:**

```lua
-- Provider component
setup = function()
    local theme = reactive({ primaryColor: Color3.fromRGB(255, 0, 0) })
    
    -- Provide readonly version to prevent child mutations
    context.provide("theme", readonly(theme))
    
    -- Only this component can mutate theme
    local updateTheme = function()
        theme.primaryColor = Color3.fromRGB(0, 255, 0)
    end
end

-- Consumer component
setup = function(props, context)
    local theme = context.inject("theme")
    -- theme.primaryColor = Color3.new(0, 0, 1) -- ⚠️ Warning
end
```

**Public Store APIs:**

```lua
local store = reactive({ user: nil, items: {} })

-- Public API - readonly
return {
    state: readonly(store),
    
    -- Only allow mutations through actions
    setUser: function(user)
        store.user = user
    end,
    
    addItem: function(item)
        table.insert(store.items, item)
    end
}
```

**Features:**

- Deep readonly - nested objects are also readonly
- Maintains reactivity - reads still trigger dependency tracking
- Dev-mode warnings - attempts to mutate warn in Studio
- Works with refs, reactive, and plain objects

**Note:** In production (published games), mutation warnings are disabled for performance, but mutations still won't affect the original object.

---

### `toRef(object: table, key: string): Ref<any>`

Creates a ref that's linked to a property of a reactive object.

```lua
local state = reactive({ count: 0, name: "Alice" })
local countRef = toRef(state, "count")

print(countRef.value) -- 0
countRef.value = 10
print(state.count) -- 10 (state is updated)

state.count = 20
print(countRef.value) -- 20 (ref reflects state)
```

**Use case:** When you need to pass a single property from a reactive object as a ref to a child component.

---

### `toRefs(object: table): { [string]: Ref<any> }`

Converts all properties of a reactive object to refs.

```lua
local state = reactive({
    count: 0,
    name: "Alice",
    age: 25
})

local refs = toRefs(state)
-- refs.count, refs.name, refs.age are all Refs

refs.count.value = 10
print(state.count) -- 10
```

**Use case:** When destructuring reactive state for use in templates or child components.

---

### `isRef(value: any): boolean`

Checks if a value is a ref.

```lua
local count = ref(0)
local obj = { value: 10 }

print(isRef(count)) -- true
print(isRef(obj)) -- false
```

---

### `unref<T>(value: T | Ref<T>): T`

Returns the inner value if it's a ref, otherwise returns the value as-is.

```lua
local count = ref(10)
local num = 20

print(unref(count)) -- 10
print(unref(num)) -- 20
```

**Use case:** When you have a value that might or might not be a ref.

---

### `isReactive(value: any): boolean`

Checks if a value is a reactive proxy created by `reactive()` or `shallowReactive()`.

```lua
local state = reactive({ count = 0 })
local plainObj = { count = 0 }
local refVal = ref(0)

print(isReactive(state)) -- true
print(isReactive(plainObj)) -- false
print(isReactive(refVal)) -- false (refs are not proxies)
print(isReactive(refVal.value)) -- false
```

**Type Definition:**

```lua
function isReactive(value: any): boolean
```

**Use Cases:**

- Type guards for conditional logic
- Debugging reactive state issues
- Validation in utility functions
- Library code that accepts mixed input types

## Example: Defensive Utility Function

```lua
local function incrementCount(obj)
    if isReactive(obj) then
        obj.count = obj.count + 1 -- Direct mutation works
    else
        warn("Object is not reactive!")
    end
end
```

---

### `isReadonly(value: any): boolean`

Checks if a value is a readonly proxy created by `readonly()`.

```lua
local state = reactive({ count = 0 })
local readonlyState = readonly(state)

print(isReadonly(state)) -- false
print(isReadonly(readonlyState)) -- true
```

**Type Definition:**

```lua
function isReadonly(value: any): boolean
```

**Use Cases:**

- Verify props are readonly before passing to children
- Debugging why mutations aren't working
- Conditional logic for read/write access
- Type guards in generic utilities

#### Example: Prevent Accidental Mutations

```lua
local function updateConfig(config)
    if isReadonly(config) then
        error("Cannot modify readonly config! Use updateConfig action.")
    end
    
    config.theme = "dark"
end
```

---

### `isProxy(value: any): boolean`

Checks if a value is **any** kind of reactive proxy (reactive, readonly, or both).

```lua
local state = reactive({ count = 0 })
local readonlyState = readonly(state)
local plainObj = { count = 0 }

print(isProxy(state)) -- true
print(isProxy(readonlyState)) -- true
print(isProxy(plainObj)) -- false
```

**Type Definition:**

```lua
function isProxy(value: any): boolean
```

**Equivalent to:**

```lua
function isProxy(value)
    return isReactive(value) or isReadonly(value)
end
```

**Use Cases:**

- Check if value is tracked by reactivity system
- Distinguish proxies from plain objects
- Optimization: skip processing for non-reactive values
- Validation for functions that require reactive input

#### Example: Optimization Pattern

```lua
-- Skip expensive deep cloning for proxies
local function deepClone(obj)
    if isProxy(obj) then
        return toRaw(obj) -- Get original first
    end
    
    -- ... deep clone logic ...
end
```

---

### `markRaw<T>(object: T): T`

Marks an object so it will **never** be made reactive, even when nested inside a reactive object.

```lua
local instance = workspace.Part
local rawData = markRaw({ 
    robloxInstance = instance,
    largeDataset = {} -- thousands of entries
})

local state = reactive({
    raw = rawData,        -- Won't be reactive
    normal = { value = 10 } -- Will be reactive
})

-- Accessing rawData doesn't trigger reactivity
print(state.raw.robloxInstance) -- No tracking

-- Normal data is still reactive
state.normal.value = 20 -- Triggers reactivity
```

**Type Definition:**

```lua
function markRaw<T>(object: T): T
```

**Why it's needed:**

- **Roblox Instances:** Instances shouldn't be made reactive (use refs for specific properties instead)
- **Performance:** Large datasets with thousands of entries would be slow to make reactive
- **Third-party libraries:** Objects from external code that manage their own state
- **Immutable data:** Static configuration or constants that never change

**Use Cases in Roblox:**

1. **Storing Roblox Instances:**

```lua
local state = reactive({
    playerInstances = markRaw({
        Player1 = game.Players.Player1,
        Player2 = game.Players.Player2
    }),
    playerData = {
        Player1 = { score = 0 },
        Player2 = { score = 0 }
    }
})

-- Instances won't be made reactive (correct)
-- playerData will be reactive (correct)
```

**Large Static Data:**

```lua
local itemDatabase = markRaw({
    [1001] = { name = "Sword", damage = 50 },
    [1002] = { name = "Shield", defense = 30 },
    -- ... 10,000 more items
})

local inventory = reactive({
    items = itemDatabase, -- Not reactive (fast!)
    equipped = { weapon = 1001, armor = 1002 } -- Reactive (needed)
})
```

1. **CollectionService Tags:**

```lua
local CollectionService = game:GetService("CollectionService")

local state = reactive({
    taggedParts = markRaw(
        CollectionService:GetTagged("Interactable")
    )
})
```

**Note:** Only works on tables. Primitives (numbers, strings) can't be marked raw.

---

### `toRaw<T>(proxy: T): T`

Returns the original, non-reactive object from a reactive proxy.

```lua
local original = { count = 0, nested = { value = 10 } }
local state = reactive(original)

print(state == original) -- false (state is a proxy)

local raw = toRaw(state)
print(raw == original) -- true (gets the original back)
```

**Type Definition:**

```lua
function toRaw<T>(proxy: T): T
```

**Use Cases:**

1. **Pass to External Libraries:**

```lua
local state = reactive({ players = {} })

-- External library expects plain object
local function saveToDataStore(data)
    -- data must be serializable (proxies aren't)
    DataStoreService:SetAsync("key", data)
end

saveToDataStore(toRaw(state.players)) -- ✅ Works
-- saveToDataStore(state.players) -- ❌ Would fail
```

**Comparison with `==`:**

```lua
local obj1 = { count = 0 }
local obj2 = { count = 0 }
local state = reactive(obj1)

print(state == obj1) -- false (proxy ~= original)
print(toRaw(state) == obj1) -- true
print(toRaw(state) == obj2) -- false (different objects)
```

1. **Performance Optimization:**

```lua
-- Temporarily bypass reactivity for bulk updates
local state = reactive({ items = {} })

local function bulkAdd(items)
    local raw = toRaw(state)
    
    -- No reactivity overhead during loop
    for i, item in ipairs(items) do
        table.insert(raw.items, item)
    end
    
    -- Trigger single update at end
    state.items = raw.items
end
```

**Debugging:**

```lua
local state = reactive({ user = { name = "Alice" } })

-- Inspect original object structure
print("Original:", toRaw(state))
print("Proxy:", state)
```

**Note:** Returns the value as-is if it's not a proxy. Safe to call on any value.

---

### `triggerRef(ref: Ref<any>)`

Manually triggers dependency updates for a `shallowRef()`. Useful when you've mutated a shallowRef's internal data without replacing the entire value.

```lua
local state = shallowRef({ count = 0, items = {} })

-- Mutating doesn't trigger updates (shallow ref)
state.value.count = 10 -- No update triggered
table.insert(state.value.items, "new") -- No update triggered

-- Manually trigger update
triggerRef(state) -- Now all watchers/effects re-run

-- Alternative: Replace entire value (auto-triggers)
state.value = { count = 10, items = {"new"} } -- Triggers automatically
```

**Type Definition:**

```lua
function triggerRef(ref: Ref<any>)
```

**Use Cases:**

1. **Optimized Bulk Updates:**

```lua
local largeList = shallowRef({})

local function addManyItems(items)
    -- Batch mutations without triggering each time
    for _, item in ipairs(items) do
        table.insert(largeList.value, item)
    end
    
    -- Single update at the end
    triggerRef(largeList)
end
```

**External State Integration:**

```lua
-- Integrate with CollectionService
local CollectionService = game:GetService("CollectionService")
local taggedParts = shallowRef(CollectionService:GetTagged("Coin"))

CollectionService:GetInstanceAddedSignal("Coin"):Connect(function(part)
    table.insert(taggedParts.value, part)
    triggerRef(taggedParts) -- Notify UI to update
end)

CollectionService:GetInstanceRemovedSignal("Coin"):Connect(function(part)
    local index = table.find(taggedParts.value, part)
    if index then
        table.remove(taggedParts.value, index)
        triggerRef(taggedParts)
    end
end)
```

1. **Manual Invalidation:**

```lua
local cache = shallowRef({ data = nil, timestamp = 0 })

local function invalidateCache()
    cache.value.data = nil
    cache.value.timestamp = 0
    triggerRef(cache) -- Force UI to show loading state
end
```

**Comparison:**

```lua
-- Regular ref: Deep tracking
local deepRef = ref({ count = 0 })
deepRef.value.count = 5 -- Auto-triggers

-- Shallow ref: Manual trigger needed
local shallowRef = shallowRef({ count = 0 })
shallowRef.value.count = 5 -- Does NOT trigger
triggerRef(shallowRef) -- Now triggers
```

---

### `customRef<T>(factory: (track: () -> (), trigger: () -> ()) -> { get: () -> T, set: (value: T) -> () }): Ref<T>`

Creates a ref with **custom control** over dependency tracking and triggering. Enables advanced patterns like debouncing, validation, lazy loading, and custom state synchronization.

**Factory Pattern:**
The factory function receives two callbacks:

- `track()` - Call when the value is accessed (dependency tracking)
- `trigger()` - Call when the value changes (notify dependents)

And must return:

- `get()` - Custom getter logic
- `set(value)` - Custom setter logic

**Type Definition:**

```lua
type CustomRefFactory<T> = (
    track: () -> (),
    trigger: () -> ()
) -> {
    get: () -> T,
    set: (value: T) -> ()
}

function customRef<T>(factory: CustomRefFactory<T>): Ref<T>
```

#### Example 1: Debounced Ref (Common Use Case)

```lua
-- Useful for search inputs, auto-save, etc.
local function useDebouncedRef(value, delay)
    local actualValue = value
    local timer = nil
    
    return customRef(function(track, trigger)
        return {
            get = function()
                track() -- Track dependency
                return actualValue
            end,
            
            set = function(newValue)
                -- Cancel previous timer
                if timer then
                    timer:Cancel()
                end
                
                -- Delay the update
                timer = task.delay(delay, function()
                    actualValue = newValue
                    trigger() -- Notify dependents
                    timer = nil
                end)
            end
        }
    end)
end

-- Usage in search component
local searchQuery = useDebouncedRef("", 0.3) -- 300ms debounce

watchEffect(function()
    print("Search for:", searchQuery.value)
    -- API call happens only after 300ms of no typing
    searchAPI(searchQuery.value)
end)

-- User types fast
searchQuery.value = "h"
searchQuery.value = "he"
searchQuery.value = "hel"
searchQuery.value = "hello"
-- Only triggers once after 300ms with "hello"
```

#### Example 2: Validation Ref

```lua
local function useValidatedRef(initialValue, validator)
    local value = initialValue
    
    return customRef(function(track, trigger)
        return {
            get = function()
                track()
                return value
            end,
            
            set = function(newValue)
                if validator(newValue) then
                    value = newValue
                    trigger()
                else
                    warn("Validation failed for value:", newValue)
                end
            end
        }
    end)
end

-- Usage: Age must be between 0-120
local age = useValidatedRef(25, function(val)
    return type(val) == "number" and val >= 0 and val <= 120
end)

age.value = 30 -- ✅ Valid, triggers update
age.value = 150 -- ❌ Invalid, warns, doesn't update
```

#### Example 3: Lazy Ref (Compute on First Access)

```lua
local function useLazyRef(factory)
    local value = nil
    local computed = false
    
    return customRef(function(track, trigger)
        return {
            get = function()
                if not computed then
                    value = factory()
                    computed = true
                end
                track()
                return value
            end,
            
            set = function(newValue)
                value = newValue
                computed = true
                trigger()
            end
        }
    end)
end

-- Usage: Expensive computation only when needed
local expensiveData = useLazyRef(function()
    print("Computing...")
    task.wait(2)
    return { result = "expensive" }
end)

-- Not computed yet
print("Created ref")

-- First access triggers computation
print(expensiveData.value) -- Prints "Computing..." then result
print(expensiveData.value) -- Uses cached value
```

#### Example 4: Roblox DataStore Sync

```lua
local DataStoreService = game:GetService("DataStoreService")
local playerStore = DataStoreService:GetDataStore("PlayerData")

local function useDataStoreRef(player, key, defaultValue)
    local value = defaultValue
    
    -- Load initial value
    task.spawn(function()
        local success, data = pcall(function()
            return playerStore:GetAsync(player.UserId .. "_" .. key)
        end)
        
        if success and data ~= nil then
            value = data
        end
    end)
    
    return customRef(function(track, trigger)
        return {
            get = function()
                track()
                return value
            end,
            
            set = function(newValue)
                value = newValue
                trigger()
                
                -- Auto-save to DataStore (debounced in production)
                task.spawn(function()
                    pcall(function()
                        playerStore:SetAsync(
                            player.UserId .. "_" .. key, 
                            newValue
                        )
                    end)
                end)
            end
        }
    end)
end

-- Usage
local playerGold = useDataStoreRef(player, "gold", 0)

playerGold.value = 100 -- Auto-saves to DataStore
```

#### Example 5: Readonly Computed Re

```lua
local function useReadonlyComputed(getter)
    return customRef(function(track, trigger)
        return {
            get = function()
                track()
                return getter()
            end,
            
            set = function()
                warn("Cannot set readonly computed ref!")
            end
        }
    end)
end

local count = ref(0)
local double = useReadonlyComputed(function()
    return count.value * 2
end)

print(double.value) -- 0
count.value = 5
print(double.value) -- 10
double.value = 20 -- ⚠️ Warning: Cannot set
```

**Advanced Patterns:**

- **Throttling:** Like debounce, but ensures minimum interval between updates
- **Rate Limiting:** Limit number of updates per time window
- **Conditional Updates:** Only trigger on specific conditions (e.g., value changed by > 10%)
- **Sync to External State:** Two-way sync with external systems
- **Undo/Redo:** Track history in set(), provide undo() method
- **Logging:** Log all get/set operations for debugging

---

### `effectScope(detached?: boolean): EffectScope`

Creates a scope to collect and manage effects created within it. Enables batch cleanup, nested scopes, and plugin-like architectures. Essential for managing complex reactive logic that isn't tied to component lifecycles.

**Type Definition:**

```lua
type EffectScope = {
    active: boolean,           -- Is scope currently active
    effects: { Effect },       -- Effects created in this scope
    cleanups: { () -> () },    -- Cleanup callbacks registered
    scopes: { EffectScope },   -- Child scopes
    parent: EffectScope?,      -- Parent scope (if nested)
    
    -- Methods
    run: <T>(fn: () -> T) -> T,  -- Run function in scope context
    stop: () -> ()                -- Stop scope and all children
}

function effectScope(detached: boolean?): EffectScope
```

**Basic Usage:**

```lua
-- Create a scope
local scope = effectScope()

-- Run code inside the scope
scope:run(function()
    -- All effects created here are tracked by the scope
    local count = ref(0)
    
    watchEffect(function()
        print("Count:", count.value)
    end)
    
    effect(function()
        print("Effect running")
    end)
end)

-- Stop all effects at once
scope:stop() -- Cleans up both watchEffect and effect
```

#### Example 1: Plugin System

```lua
-- Composable plugin pattern
local function createPlugin()
    local scope = effectScope()
    local isActive = ref(false)
    
    return {
        activate = function()
            scope:run(function()
                isActive.value = true
                
                -- Register event handlers
                watchEffect(function()
                    if isActive.value then
                        print("Plugin active!")
                    end
                end)
                
                -- Setup timers
                local timer = setInterval(function()
                    print("Plugin tick")
                end, 1)
                
                -- Cleanup when scope stops
                onScopeDispose(function()
                    clearInterval(timer)
                    print("Plugin deactivated!")
                end)
            end)
        end,
        
        deactivate = function()
            scope:stop() -- Cleans up ALL effects and timers
            isActive.value = false
        end
    }
end

-- Usage
local plugin = createPlugin()
plugin.activate()   -- Starts plugin
plugin.deactivate() -- Cleans up everything
```

#### Example 2: Nested Scopes

```lua
local parentScope = effectScope()

parentScope:run(function()
    local count = ref(0)
    
    watchEffect(function()
        print("Parent:", count.value)
    end)
    
    -- Create child scope (non-detached by default)
    local childScope = effectScope()
    
    childScope:run(function()
        watchEffect(function()
            print("Child:", count.value * 2)
        end)
    end)
    
    -- Stopping parent also stops child
    task.delay(2, function()
        parentScope:stop() -- Both parent and child effects stop
    end)
end)
```

#### Example 3: Detached Scopes

```lua
local parentScope = effectScope()

parentScope:run(function()
    -- Detached scope is NOT linked to parent
    local detachedScope = effectScope(true) -- detached = true
    
    detachedScope:run(function()
        watchEffect(function()
            print("Detached effect")
        end)
    end)
    
    -- Stopping parent does NOT stop detached child
    parentScope:stop() -- Only parent effects stop
    
    -- Must manually stop detached scope
    detachedScope:stop()
end)
```

#### Example 4: Roblox Service Manager

```lua
local ServiceManager = {}
ServiceManager.scopes = {}

function ServiceManager.startService(name, setup)
    if ServiceManager.scopes[name] then
        warn("Service already running:", name)
        return
    end
    
    local scope = effectScope()
    ServiceManager.scopes[name] = scope
    
    scope:run(function()
        setup() -- Run service setup (creates effects, watches, etc.)
        
        onScopeDispose(function()
            print("Service stopped:", name)
        end)
    end)
    
    print("Service started:", name)
end

function ServiceManager.stopService(name)
    local scope = ServiceManager.scopes[name]
    if scope then
        scope:stop()
        ServiceManager.scopes[name] = nil
    end
end

function ServiceManager.stopAllServices()
    for name, scope in pairs(ServiceManager.scopes) do
        scope:stop()
    end
    ServiceManager.scopes = {}
end

-- Usage
ServiceManager.startService("Analytics", function()
    local events = ref(0)
    
    watchEffect(function()
        print("Total events:", events.value)
    end)
    
    game.Players.PlayerAdded:Connect(function()
        events.value = events.value + 1
    end)
end)

ServiceManager.startService("Chat", function()
    -- Chat service setup...
end)

-- Later: Stop specific service
ServiceManager.stopService("Analytics")

-- Or stop all
ServiceManager.stopAllServices()
```

#### Example 5: Temporary Scope for Testing

```lua
-- Create isolated scope for testing
local function withScope(fn)
    local scope = effectScope()
    
    local result = scope:run(function()
        return fn()
    end)
    
    -- Auto-cleanup after test
    scope:stop()
    
    return result
end

-- Usage in tests
withScope(function()
    local count = ref(0)
    
    watchEffect(function()
        print(count.value)
    end)
    
    count.value = 5
    -- Effects auto-clean up when function returns
end)
```

**Use Cases:**

- **Plugin Systems:** Enable/disable plugins with full cleanup
- **Service Managers:** Start/stop services dynamically
- **Feature Flags:** Conditionally activate reactive features
- **Testing:** Isolated reactive environments for unit tests
- **Dynamic Modules:** Load/unload modules with reactive logic
- **State Machines:** Manage state-specific reactive behavior

**Comparison with Components:**

- Components auto-cleanup on unmount
- Scopes allow cleanup outside component lifecycle
- Scopes enable shared reactive logic across components

---

### `getCurrentScope(): EffectScope?`

Returns the currently active effect scope, or `nil` if no scope is active.

```lua
local scope = effectScope()

scope:run(function()
    local currentScope = getCurrentScope()
    print(currentScope == scope) -- true
    
    watchEffect(function()
        print("Running in scope:", getCurrentScope())
    end)
end)

-- Outside scope
print(getCurrentScope()) -- nil
```

**Type Definition:**

```lua
function getCurrentScope(): EffectScope?
```

**Use Cases:**

1. **Conditional Scope Registration:**

```lua
local function createManagedEffect(fn)
    local scope = getCurrentScope()
    
    if scope then
        -- Register with current scope
        return effect(fn)
    else
        -- Create standalone effect
        local eff = effect(fn)
        
        -- Manual cleanup
        return {
            stop = function()
                eff:stop()
            end
        }
    end
end
```

**Scope-Aware Utilities:**

```lua
local function registerCleanup(fn)
    local scope = getCurrentScope()
    
    if scope then
        onScopeDispose(fn)
    else
        warn("No active scope - cleanup won't be registered!")
    end
end

-- Usage
effectScope():run(function()
    local connection = someEvent:Connect(function() end)
    
    registerCleanup(function()
        connection:Disconnect()
    end)
end)
```

1. **Debugging:**

```lua
local function debugScope()
    local scope = getCurrentScope()
    
    if scope then
        print("Active scope:", scope)
        print("Effects in scope:", #scope.effects)
        print("Cleanups registered:", #scope.cleanups)
    else
        print("No active scope")
    end
end
```

---

### `onScopeDispose(fn: () -> (), failSilently?: boolean)`

Registers a cleanup callback to run when the current effect scope stops. Must be called inside an active scope (inside `effectScope():run()`).

```lua
local scope = effectScope()

scope:run(function()
    local connection = someEvent:Connect(function()
        print("Event fired!")
    end)
    
    -- Register cleanup
    onScopeDispose(function()
        connection:Disconnect()
        print("Scope disposed, connection cleaned up!")
    end)
end)

-- Later: triggers cleanup
scope:stop() -- Prints: "Scope disposed, connection cleaned up!"
```

**Type Definition:**

```lua
function onScopeDispose(fn: () -> (), failSilently: boolean?)
```

#### Example 1: Resource Cleanup

```lua
local scope = effectScope()

scope:run(function()
    -- Create resources
    local part = Instance.new("Part")
    part.Parent = workspace
    
    local heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
        part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(1), 0)
    end)
    
    -- Register cleanup for ALL resources
    onScopeDispose(function()
        heartbeatConnection:Disconnect()
        part:Destroy()
        print("Cleanup complete!")
    end)
end)

scope:stop() -- Cleans up part and connection
```

#### Example 2: Multiple Cleanup Callbacks

```lua
local scope = effectScope()

scope:run(function()
    -- Each cleanup is independent
    onScopeDispose(function()
        print("Cleanup 1")
    end)
    
    onScopeDispose(function()
        print("Cleanup 2")
    end)
    
    onScopeDispose(function()
        print("Cleanup 3")
    end)
end)

scope:stop()
-- Prints:
-- "Cleanup 1"
-- "Cleanup 2"
-- "Cleanup 3"
```

### Example 3: Fail Silently (Advanced)

```lua
-- By default, warns if called outside scope
onScopeDispose(function()
    print("Cleanup")
end)
-- ⚠️ Warning: onScopeDispose called without active scope

-- Suppress warning with failSilently = true
onScopeDispose(function()
    print("Cleanup")
end, true) -- No warning
```

**Use Cases:**

- **Event Listener Cleanup:** Disconnect all event connections
- **Instance Cleanup:** Destroy created Instances
- **Timer Cleanup:** Cancel timers and intervals
- **External API Cleanup:** Close HTTP connections, stop streams
- **State Restoration:** Restore original state on scope disposal

**Execution Order:**

- Cleanups run in **registration order** (first registered, first executed)
- All cleanups execute when scope:stop() is called
- Child scope cleanups run before parent scope cleanups

**Comparison with Component Lifecycle:**

```lua
-- Component: Use onUnmounted
setup = function()
    onUnmounted(function()
        print("Component unmounting")
    end)
end

-- Effect Scope: Use onScopeDispose
effectScope():run(function()
    onScopeDispose(function()
        print("Scope stopping")
    end)
end)w
```

---

## Component API

### `defineComponent(options): ComponentDefinition`

Defines a component with setup, render, and props.

```lua
local MyComponent = defineComponent({
    -- Component name (for debugging)
    name = "MyComponent",
    
    -- Props schema (optional, validated in dev mode)
    props = {
        title = { type = "string", required = true },
        count = { type = "number", required = false }
    },
    
    -- Setup function
    setup = function(props, context)
        local count = ref(props.count or 0)
        
        local increment = function()
            count.value = count.value + 1
        end
        
        -- Return render function
        return function()
            return h("Frame", {}, {
                h("TextLabel", { Text = props.title }),
                h("TextButton", { 
                    Text = "Count: " .. count.value,
                    onClick = increment
                })
            })
        end
    end
})
```

**Type Definition:**

```lua
type PropSpec = {
    type: "string" | "number" | "boolean" | "table" | "function",
    required: boolean?,
    default: any?,  -- Default value (primitive or factory function)
    validator: ((value: any) -> boolean)?  -- Custom validation function
}

type PropSchema = { [string]: PropSpec }

type ComponentContext = {
    emit: (eventName: string, ...any) -> (),
    provide: (key: any, value: any) -> (),
    inject: (key: any, default: any?) -> any,
    slots: { VNode },
    attrs: { [string]: any },  -- Non-declared props
    expose: (exposed: { [string]: any }?) -> (),  -- Expose public API
    onUnmounted: (fn: () -> ()) -> ()
}

type ComponentOptions = {
    name: string?,
    props: PropSchema?,
    inheritAttrs: boolean?,  -- Whether to auto-apply attrs to root element
    setup: ((props: table, context: ComponentContext) -> (() -> VNode))?,
    render: ((props: table) -> VNode)?
}
```

**Prop Features:**

#### Default Values

Props can have default values (primitive or factory functions):

```lua
local MyComponent = defineComponent({
    props = {
        -- Primitive default
        count = {
            type = "number",
            default = 0
        },
        
        -- Factory function default (for objects/tables)
        config = {
            type = "table",
            default = function()
                return { enabled = true, timeout = 5000 }
            end
        },
        
        -- String default
        message = {
            type = "string",
            default = "Hello World"
        }
    },
    
    setup = function(props)
        -- props.count is 0 if not provided
        -- props.config is { enabled = true, timeout = 5000 } if not provided
        -- Each component instance gets its own config table
    end
})
```

**Why factory functions?** Factory functions create new instances for each component, preventing shared references:

```lua
-- BAD: All instances share the same table
default = { items = {} }

-- GOOD: Each instance gets its own table
default = function() return { items = {} } end
```

#### Prop Validators

Custom validation functions provide runtime type safety:

```lua
local UserProfile = defineComponent({
    props = {
        age = {
            type = "number",
            validator = function(val)
                return val >= 0 and val <= 120
            end
        },
        
        email = {
            type = "string",
            validator = function(val)
                return string.match(val, ".+@.+%.%w+") ~= nil
            end
        },
        
        role = {
            type = "string",
            validator = function(val)
                local validRoles = { "admin", "user", "guest" }
                for _, role in ipairs(validRoles) do
                    if val == role then return true end
                end
                return false
            end
        }
    }
})
```

**Validation behavior:**

- Only runs in Studio mode (dev mode)
- Warnings are logged to console
- Component continues to render even if validation fails

**Context Methods:**

#### `context.attrs: { [string]: any }`

Non-declared props are automatically separated into `attrs`. Useful for wrapper components and passing through attributes.

```lua
local Wrapper = defineComponent({
    props = {
        title = { type = "string" }  -- Only 'title' is declared
    },
    
    setup = function(props, context)
        -- context.attrs contains all non-declared props
        print("Title:", props.title)
        print("Attrs:", context.attrs)
        
        return function()
            -- Pass attrs to child
            return h("Frame", context.attrs, {
                h("TextLabel", { Text = props.title })
            })
        end
    end
})

-- Usage
h(Wrapper, {
    title = "My Title",  -- Goes to props
    id = "container",    -- Goes to attrs
    class = "main",      -- Goes to attrs
    Size = UDim2.new(1, 0, 1, 0)  -- Goes to attrs
})
```

#### `context.expose(exposed: { [string]: any }?)`

Exposes specific methods/values to parent components via template refs. Only exposed members are accessible.

```lua
local Counter = defineComponent({
    setup = function(props, context)
        local count = ref(0)
        local history = ref({})
        
        local function increment()
            count.value = count.value + 1
            table.insert(history.value, count.value)
        end
        
        local function reset()
            count.value = 0
            history.value = {}
        end
        
        -- Only expose specific public API
        context.expose({
            increment = increment,
            reset = reset,
            count = count,  -- Expose reactive ref
            -- history is NOT exposed - stays private
        })
        
        return function()
            return h("TextButton", {
                Text = tostring(count.value),
                onClick = increment
            })
        end
    end
})

-- Parent component accessing exposed API
local Parent = defineComponent({
    setup = function()
        local counterRef = ref(nil)
        
        onMounted(function()
            -- Access exposed API via template ref
            if counterRef.value then
                counterRef.value.increment()
                print("Count:", counterRef.value.count.value)
                counterRef.value.reset()
            end
        end)
        
        return function()
            return h(Counter, {
                ref = counterRef  -- Template ref
            })
        end
    end
})
```

**Benefits:**

- **Encapsulation**: Only expose what's needed
- **Type safety**: Clear contract between parent/child
- **Maintainability**: Easy to see public API at a glance

**Without expose():** If no expose() is called, the template ref gets the entire component instance.

#### `context.emit(eventName: string, ...args)`

Emits an event to parent component.

```lua
setup = function(props, context)
    local handleClick = function()
        context.emit("buttonClicked", "some data")
    end
    
    return function()
        return h("TextButton", { onClick = handleClick })
    end
end

-- Parent component
h(ChildComponent, {
    onButtonClicked = function(data)
        print("Button clicked with:", data)
    end
})
```

#### `context.provide(key: any, value: any)`

Provides a value to descendant components.

```lua
setup = function(props, context)
    context.provide("theme", { color = Color3.fromRGB(255, 0, 0) })
end
```

#### `context.inject(key: any, default: any?): any`

Injects a value provided by an ancestor component.

```lua
setup = function(props, context)
    local theme = context.inject("theme", { color = Color3.fromRGB(0, 0, 0) })
    print(theme.color)
end
```

#### `context.slots: { VNode }`

Access to child content passed to the component.

```lua
setup = function(props, context)
    return function()
        return h("Frame", {}, context.slots) -- Render children
    end
end
```

---

## Rendering API

### `h(type, props?, children?): VNode`

Creates a virtual node (VNode). The hyperscript function for creating UI elements.

```lua
-- Simple element
h("TextLabel", {
    Size = UDim2.fromOffset(200, 50),
    Text = "Hello"
})

-- With children
h("Frame", {
    Size = UDim2.fromOffset(300, 200),
    BackgroundColor3 = Color3.fromRGB(50, 50, 50)
}, {
    h("TextLabel", { Text = "Child 1" }),
    h("TextLabel", { Text = "Child 2" })
})

-- Component
h(MyComponent, { title = "Hello", count = 5 })

-- Functional component
h(function(props)
    return h("TextLabel", { Text = props.message })
end, { message = "Hi!" })
```

**Type Definition:**

```lua
type ElementType = string | ComponentDefinition | (props: table) -> VNode

function h(
    type: ElementType,
    props: { [string]: any }?,
    children: { VNode | string | (() -> VNode) }?
): VNode
```

**Props:**

- Any Roblox Instance property (Size, Position, Text, etc.)
- Event handlers prefixed with `on` (onClick, onActivated, etc.)
- Special props: `key`, `transition`, `__directives`

**Children:**

- Can be VNodes, strings, functions, or nested arrays
- Strings are rendered as TextLabels (or set as Text for text elements)

---

### `hIf(condition: boolean, vnode: VNode): VNode?`

Conditional rendering helper.

```lua
local showLabel = ref(true)

return function()
    return h("Frame", {}, {
        hIf(showLabel.value, h("TextLabel", { Text = "Visible" })),
        h("TextButton", {
            Text = "Toggle",
            onClick = function()
                showLabel.value = not showLabel.value
            end
        })
    })
end
```

---

### `hFor<T>(list: { T }, mapper: (item: T, index: number) -> VNode?): { VNode }`

List rendering helper.

```lua
local items = ref({
    { id = 1, name = "Apple" },
    { id = 2, name = "Banana" },
    { id = 3, name = "Cherry" }
})

return function()
    return h("Frame", {}, 
        hFor(items.value, function(item, index)
            return h("TextLabel", {
                key = item.id, -- Important for efficient updates
                Text = item.name,
                LayoutOrder = index
            })
        end)
    )
end
```

---

### `hForParallel<T>(list: { T }, mapper: (item: T, index: number) -> VNode?, keyFn?: (item: T) -> any): { VNode }`

Parallel list rendering helper for large lists (1000+ items). Uses Parallel Luau for CPU-intensive rendering.

```lua
local largeDataset = ref({})
for i = 1, 5000 do
    table.insert(largeDataset.value, { id = i, name = "Item " .. i })
end

return function()
    return h("ScrollingFrame", {}, 
        hForParallel(
            largeDataset.value, 
            function(item, index)
                return h("TextLabel", {
                    key = item.id,
                    Text = item.name,
                    LayoutOrder = index
                })
            end,
            function(item) return item.id end -- Optional key function
        )
    )
end
```

**Performance Benefits:**

- Automatically uses Parallel Luau for lists with 500+ items
- Splits rendering work across multiple threads
- Reduces frame drops during initial render
- Falls back to regular rendering for small lists (<500 items)

**When to use:**

- Rendering 1000+ list items
- CPU-intensive VNode creation (complex calculations per item)
- Large data grids or tables
- Initial render performance is critical

**Note:** For smaller lists (< 500 items), use regular `hFor` to avoid parallel overhead.

---

### `createApp(rootVNode: VNode, options?): App`

Creates an application instance.

```lua
local app = Rivue.createApp(h(RootComponent), {
    usePool = true -- Enable object pooling for performance
})

-- Mount to a container
app:mount(playerGui)

-- Or mount to player's PlayerGui
app:mountToPlayerGui(player)

-- Unmount
app:unmount()

-- Re-render with new root
app:rerender(h(NewRootComponent))

-- Swap root component
app:swapRoot(h(DifferentComponent))
```

**Type Definition:**

```lua
type AppOptions = {
    usePool: boolean? -- Enable Instance pooling
}

type App = {
    mount: (container: Instance) -> (),
    unmount: () -> (),
    rerender: (newRoot: VNode?) -> (),
    swapRoot: (newRoot: VNode) -> (),
    mountToPlayerGui: (player: Player) -> ()
}

function createApp(rootVNode: VNode, options: AppOptions?): App
```

---

### `Rivue.mount(componentOrVNode, parent, options?)`

Convenience method to create and mount an app in one call.

```lua
Rivue.mount(h(App), playerGui, { usePool = true })
```

---

## Lifecycle Hooks

Lifecycle hooks must be called within a component's `setup` function.

### `onBeforeMount(callback: () -> ())`

Runs right before the component is mounted to the DOM. Called after setup() and before the first render.

```lua
setup = function()
    onBeforeMount(function()
        print("Component is about to mount!")
        -- Good for: Prepare data, validate props, setup external connections
    end)
end
```

**Use Cases:**

- Last-minute data preparation before render
- Prop validation and transformation
- Setting up external resources

---

### `onMounted(callback: () -> ())`

Runs after the component is mounted to the DOM.

```lua
setup = function()
    onMounted(function()
        print("Component mounted!")
        -- Initialize connections, fetch data, etc.
    end)
end
```

---

### `onBeforeUpdate(callback: () -> ())`

Runs right before the component re-renders due to reactive data changes.

```lua
setup = function()
    local count = ref(0)
    
    onBeforeUpdate(function()
        print("Component is about to update! Count:", count.value)
        -- Good for: Save current state, cancel pending operations
    end)
    
    return function()
        return h("TextLabel", {
            Text = tostring(count.value),
            onClick = function()
                count.value = count.value + 1
            end
        })
    end
end
```

**Use Cases:**

- Saving scroll position before re-render
- Canceling in-progress network requests
- Capturing pre-update DOM state

---

### `onUpdated(callback: () -> ())`

Runs after the component updates (re-renders).

```lua
setup = function()
    onUpdated(function()
        print("Component updated!")
    end)
end
```

---

### `onBeforeUnmount(callback: () -> ())`

Runs right before the component is unmounted, before cleanup begins.

```lua
setup = function()
    local data = ref({ important = "state" })
    
    onBeforeUnmount(function()
        print("Component is about to unmount!")
        -- Good for: Save final state, show confirmation dialogs
        saveToDataStore(data.value)
    end)
end
```

**Use Cases:**

- Saving important state before component is destroyed
- Showing "unsaved changes" confirmation
- Final data synchronization

---

### `onUnmounted(callback: () -> ())`

Runs when the component is about to be unmounted.

```lua
setup = function()
    local connection
    
    onMounted(function()
        connection = someEvent:Connect(function() end)
    end)
    
    onUnmounted(function()
        print("Component unmounting!")
        if connection then
            connection:Disconnect()
        end
    end)
end
```

**Lifecycle Order:**

1. `setup()` is called
2. `onBeforeMount()` callbacks run
3. Component renders for the first time
4. `onMounted()` callbacks run
5. **On reactive change:**
   - `onBeforeUpdate()` callbacks run
   - Component re-renders (patch)
   - `onUpdated()` callbacks run
6. **On unmount:**
   - `onBeforeUnmount()` callbacks run
   - `onUnmounted()` callbacks run
   - Component cleanup

---

### `onErrorCaptured(callback: (err: string, instance: ComponentInstance, info: string) -> boolean?)`

Catches errors from child components (error boundary).

```lua
setup = function()
    onErrorCaptured(function(err, instance, info)
        warn("Error caught in child:", err, info)
        
        -- Log to analytics
        logError(err, instance, info)
        
        -- Return true to stop error propagation
        -- Return false or nil to continue propagating up
        return true
    end)
    
    return function()
        return h("Frame", {}, {
            h(ChildComponent) -- Errors here will be caught
        })
    end
end
```

**Parameters:**

- `err`: Error message string
- `instance`: Component instance that threw the error
- `info`: Additional context about where the error occurred

**Return Value:**

- `true`: Stop error propagation (error is handled)
- `false` or `nil`: Continue propagating to parent error boundaries

**Use Cases:**

- Error logging and monitoring
- Graceful degradation (show fallback UI)
- Prevent entire app crash from child component errors
- User-friendly error messages

---

### `onTransition(name: string, callback: (el: Instance) -> ())`

Registers a transition hook for coordinated animations. Allows fine-grained control over element enter/leave transitions.

```lua
setup = function()
    onTransition("before-enter", function(el)
        -- Set initial state before element appears
        el.BackgroundTransparency = 1
        el.Size = UDim2.fromScale(0, 0)
    end)
    
    onTransition("enter", function(el)
        -- Animate element entering
        local tween = TweenService:Create(
            el,
            TweenInfo.new(0.3),
            { BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1) }
        )
        tween:Play()
    end)
    
    onTransition("after-enter", function(el)
        -- Cleanup or trigger next animation
        print("Element entered:", el.Name)
    end)
    
    onTransition("before-leave", function(el)
        -- Prepare for exit animation
    end)
    
    onTransition("leave", function(el)
        -- Animate element leaving
        local tween = TweenService:Create(
            el,
            TweenInfo.new(0.2),
            { BackgroundTransparency = 1 }
        )
        tween:Play()
    end)
    
    onTransition("after-leave", function(el)
        -- Cleanup after element is removed
    end)
end
```

**Hook Names:**

- `before-enter`: Before element is added to DOM
- `enter`: During element enter animation
- `after-enter`: After element enter animation completes
- `before-leave`: Before element leave animation
- `leave`: During element leave animation
- `after-leave`: After element is removed from DOM

**Use Cases:**

- Coordinated list animations (stagger effect)
- Complex multi-stage transitions
- Custom easing and timing control
- Chaining animations across components
- Reusable transition patterns

**Note:** Must be called within `setup()`. Hooks are called automatically by the transition system.

---

## Directives

Directives are special attributes that apply custom behavior to elements.

### Built-in Directives

#### `v-focus`

Automatically focuses an element when mounted.

```lua
h("TextBox", {
    __directives = {
        { name = "focus", value = true }
    },
    PlaceholderText = "Auto-focused"
})
```

#### `v-click-outside`

Triggers a callback when clicking outside an element.

```lua
local showMenu = ref(true)

h("Frame", {
    __directives = {
        {
            name = "click-outside",
            value = function()
                showMenu.value = false
            end
        }
    }
})
```

#### `v-drag`

Makes a GuiObject draggable via mouse or touch input.

```lua
h("Frame", {
    Size = UDim2.fromOffset(300, 200),
    __directives = {
        { name = "drag", value = true }
    }
})
```

**Features:**

- Mouse and touch support
- Smooth dragging with InputChanged tracking
- Maintains relative position during drag

#### `v-fade-in`

Recursively animates all GUI elements from transparent to visible with advanced options.

```lua
h("ScreenGui", {}, {
    h("Frame", {
        __directives = {
            { 
                name = "fade-in", 
                value = { 
                    duration = 1.0,      -- Animation duration (default: 0.5)
                    delay = 0.2,         -- Delay before start (default: 0)
                    waitForLoad = true,  -- Wait for game load (default: false)
                    renderWait = 0.5     -- Component mount wait (default: 0.5)
                } 
            }
        }
    }, {
        h("TextLabel", { Text = "Hello" }),
        h("TextButton", { Text = "Click Me" })
        -- All children fade in together
    })
})
```

**Options:**

- `duration`: Animation duration in seconds
- `delay`: Delay before animation starts
- `waitForLoad`: Wait for `game:IsLoaded()` before animating
- `renderWait`: Time to wait for reactive components to mount

**Supported Transparency Types:**

- `BackgroundTransparency` (GuiObjects)
- `TextTransparency` (TextLabel, TextButton, TextBox)
- `ImageTransparency` (ImageLabel, ImageButton)
- `GroupTransparency` (CanvasGroup - recommended for performance)
- `Transparency` (UIStroke)

**Performance Tip:** Wrap content in `CanvasGroup` for better performance:

```lua
h("CanvasGroup", {
    __directives = {{ name = "fade-in", value = { duration = 0.8 } }}
}, {
    -- Single GroupTransparency tween instead of many individual tweens
    h("Frame", ...),
    h("TextLabel", ...),
})
```

#### `v-show`

Toggles the `Visible` property without unmounting the component. Preserves state and is more efficient than conditional rendering for frequent toggles.

```lua
local isVisible = ref(true)

h("Frame", {
    __directives = {
        { name = "show", value = isVisible }
    }
}, {
    h("TextLabel", { Text = "Toggle me!" })
})

-- Toggle visibility (component stays mounted)
isVisible.value = false  -- Hides (Visible = false)
isVisible.value = true   -- Shows (Visible = true)
```

**Use Cases:**

- Dropdowns and menus that toggle frequently
- Conditional UI that needs to preserve scroll position or input state
- Performance optimization (no unmount/remount overhead)

**Comparison with conditional rendering:**

```lua
-- v-show: Component stays in memory, just hidden
h("Frame", {
    __directives = {{ name = "show", value = isVisible }}
})

-- Conditional rendering: Component is destroyed/recreated
isVisible.value and h("Frame", ...) or nil
```

#### `v-preload`

Preloads assets using `ContentProvider` to prevent pop-in during animations and improve perceived performance.

```lua
-- Preload single asset
h("ImageLabel", {
    Image = "rbxassetid://123456789",
    __directives = {
        { name = "preload", value = "rbxassetid://123456789" }
    }
})

-- Preload multiple assets
h("Frame", {
    __directives = {
        { 
            name = "preload", 
            value = {
                "rbxassetid://123456789",  -- Image
                "rbxassetid://987654321",  -- Another image
                12345678,                  -- Asset ID as number
            }
        }
    }
}, {
    h("ImageLabel", { Image = "rbxassetid://123456789" }),
    h("ImageLabel", { Image = "rbxassetid://987654321" }),
})
```

**Accepted Value Types:**

- `number`: Asset ID (converted to `rbxassetid://` URL)
- `string`: Asset URL or asset ID
- `{number | string}`: Array of asset IDs/URLs

**Use Cases:**

- Preload images before fade-in animations to prevent white flash
- Preload character meshes and textures in character selection screens
- Preload UI icons and badges during loading screens
- Preload sound effects before gameplay starts

**Performance Benefits:**

- Prevents "pop-in" where assets appear after UI is visible
- Smoother fade-in animations (assets already loaded)
- Better user experience during initial load
- Asynchronous loading doesn't block rendering

**Example with fade-in:**

```lua
h("Frame", {
    __directives = {
        { name = "preload", value = { 123456, 789012 } },
        { name = "fade-in", value = { duration = 1.0, waitForLoad = true } }
    }
}, {
    h("ImageLabel", { Image = "rbxassetid://123456" }),
    h("ImageLabel", { Image = "rbxassetid://789012" }),
})
-- Assets preload first, then fade-in animates smoothly
```

---

#### `v-memo`

Memoizes element rendering based on a dependency array. Only re-renders when dependencies change (shallow comparison). Useful for optimizing expensive components.

```lua
local ExpensiveList = defineComponent({
    setup = function(props)
        local items = ref(props.items)
        local selectedId = ref(nil)
        
        return function()
            return h("Frame", {}, 
                Rivue.hFor(items.value, function(item)
                    -- Only re-render when item or selectedId changes
                    return h("TextButton", {
                        Text = item.name,
                        __directives = {
                            { 
                                name = "memo",
                                value = { item, selectedId.value }
                            }
                        },
                        onClick = function()
                            selectedId.value = item.id
                        end
                    })
                end)
            )
        end
    end
})
```

**Value Format:**

- `{ any }`: Array of dependencies to watch
- Only updates element if any dependency changes (shallow comparison)

**Use Cases:**

- Large lists with expensive render logic
- Components with complex computations
- Reduce re-renders of static content
- Optimize child components in frequently updating parents

**Comparison with v-once:**

- `v-memo`: Conditionally skips updates based on deps
- `v-once`: Always skips updates after first render

**Performance Impact:**

```lua
-- Without v-memo: Re-renders on every parent update
h("Frame", { Text = expensiveComputation() })

-- With v-memo: Only re-renders when dep1 or dep2 change
h("Frame", {
    Text = expensiveComputation(),
    __directives = {
        { name = "memo", value = { dep1.value, dep2.value } }
    }
})
```

---

#### `v-once`

Renders element and children only once. Subsequent updates are skipped entirely. Perfect for static content that never changes.

```lua
local StaticHeader = defineComponent({
    setup = function()
        local timestamp = os.time()  -- Captured once
        
        return function()
            return h("TextLabel", {
                Text = "App loaded at: " .. timestamp,
                __directives = {
                    { name = "once", value = true }
                }
            })
        end
    end
})

-- Large static content
h("Frame", {
    __directives = {
        { name = "once", value = true }
    }
}, {
    h("TextLabel", { Text = "Welcome to the app!" }),
    h("TextLabel", { Text = "Version 1.0.0" }),
    h("ImageLabel", { Image = "rbxassetid://logo" }),
    -- All children rendered once and never updated
})
```

**Use Cases:**

- Static headers and footers
- Welcome messages
- Version info
- Logos and branding
- Terms of service text
- Any content that never changes

**Performance Benefits:**

```lua
-- Without v-once: Re-runs expensive computation on every render
local result = ref(1)

h("TextLabel", {
    Text = "Result: " .. expensiveComputation(result.value)
})
-- expensiveComputation called every time result changes

-- With v-once: Computation runs only once
h("TextLabel", {
    Text = "Initial result: " .. expensiveComputation(result.value),
    __directives = {
        { name = "once", value = true }
    }
})
-- expensiveComputation called only on first render
```

**Common Pattern - Static Lists:**

```lua
local categories = { "Home", "Shop", "Profile", "Settings" }

-- Render once, never update
h("Frame", {},
    Rivue.hFor(categories, function(category)
        return h("TextButton", {
            Text = category,
            __directives = {
                { name = "once", value = true }
            }
        })
    end)
)
```

---

### v-model Helpers

#### `vModelText(ref: Ref<string>, options?: { debounce: number? }): { Text: string, onTextChanged: function }`

Two-way binding for TextBox/TextLabel with optional debounce.

```lua
local inputText = ref("")

-- Immediate updates (no debounce)
h("TextBox", Rivue.vModelText(inputText))

-- Debounced updates (waits 150ms after last keystroke)
h("TextBox", Rivue.vModelText(inputText, { debounce = 150 }))

-- Equivalent to:
h("TextBox", {
    Text = inputText.value,
    onTextChanged = function(new)
        inputText.value = new -- or debounced update
    end
})
```

**Parameters:**

- `ref`: Reactive reference to bind
- `options` (optional):
  - `debounce`: Delay in milliseconds before updating ref (default: 0)

**Use cases for debounce:**

- Search inputs (reduce API call frequency)
- Expensive validations or computations
- IME/composition-heavy text input
- Rate-limited operations

#### `vModelProp(ref: Ref<any>, propName: string, eventName?: string)`

Generic two-way binding for any property.

```lua
local volume = ref(0.5)

h("SomeCustomSlider", Rivue.vModelProp(volume, "Volume", "onVolumeChanged"))
```

---

### Custom Directives

Register custom directives:

```lua
Rivue.directives.register("my-directive", {
    mounted = function(element, value)
        print("Directive mounted on", element, "with value", value)
        -- Return cleanup data if needed
        return { someData = true }
    end,
    
    updated = function(element, value, oldCleanup)
        print("Directive updated")
    end,
    
    unmounted = function(element, cleanup)
        print("Directive unmounted, cleanup:", cleanup)
    end
})

-- Usage
h("Frame", {
    __directives = {
        { name = "my-directive", value = "some value" }
    }
})
```

---

## Utilities

### Async Utilities

#### `utils.debounce(fn: function, ms: number): function`

Creates a debounced function that delays execution.

**⚠️ Unit Clarification:** Expects **milliseconds**. Values < 1 are automatically converted from seconds to milliseconds for backward compatibility.

```lua
-- ✅ Recommended: Use milliseconds explicitly
local debouncedSave = Rivue.utils.debounce(function()
    print("Saving...")
end, 500)  -- 500 milliseconds

-- ✅ Also works: Values < 1 auto-convert to milliseconds
local debouncedSave = Rivue.utils.debounce(function()
    print("Saving...")
end, 0.5)  -- Auto-converts to 500 milliseconds

-- Call multiple times, only executes once after 500ms of inactivity
debouncedSave()
debouncedSave()
debouncedSave()

-- Cancellation support
local debounced = Rivue.utils.debounce(function()
    print("This won't run")
end, 1000)

debounced()
debounced:cancel()  -- Cancels pending execution
```

**Returns:** A debounced function with a `cancel()` method.

---

#### `utils.throttle(fn: function, ms: number): function`

Creates a throttled function that executes at most once per interval.

**⚠️ Unit Clarification:** Expects **milliseconds**. Values < 1 are automatically converted from seconds to milliseconds for backward compatibility.

```lua
-- ✅ Recommended: Use milliseconds explicitly
local throttledUpdate = Rivue.utils.throttle(function()
    print("Updating...")
end, 1000)  -- 1000 milliseconds = 1 second

-- ✅ Also works: Values < 1 auto-convert to milliseconds
local throttledUpdate = Rivue.utils.throttle(function()
    print("Updating...")
end, 0.1)  -- Auto-converts to 100 milliseconds

-- Executes immediately on first call, then at most once per second
for i = 1, 100 do
    throttledUpdate()  -- Only executes ~2-3 times for 100 calls
end

-- Cancellation support
local throttled = Rivue.utils.throttle(function()
    print("Throttled")
end, 500)

throttled()
throttled:cancel()  -- Cancels any pending throttled execution
```

**Returns:** A throttled function with a `cancel()` method.

---

#### `utils.nextTick(fn: () -> ())`

Defers execution to the next micro-task.

```lua
Rivue.utils.nextTick(function()
    print("Next tick!")
end)
```

---

#### `utils.nextFrame(fn: () -> ())`

Defers execution to the next Heartbeat frame.

```lua
Rivue.utils.nextFrame(function()
    print("Next frame!")
end)
```

---

#### `utils.useRaf(fn: (deltaTime: number) -> ()): { stop: () -> () }`

Runs a function every RenderStepped frame.

```lua
local raf = Rivue.utils.useRaf(function(dt)
    print("Delta time:", dt)
end)

-- Stop the animation frame loop
raf.stop()
```

---

### Other Utilities

#### `utils.filterForClient(player: Player, text: string): string`

Filters text using TextService (for chat/user input).

```lua
local filtered = Rivue.utils.filterForClient(player, "Hello world!")
```

#### `utils.profiler`

Performance profiler for measuring code execution time. Automatically enabled in Studio, disabled in production.

```lua
-- Basic usage
Rivue.utils.profiler:start("myOperation")
-- ... do work ...
local elapsed = Rivue.utils.profiler:stop("myOperation")
print("Operation took:", elapsed, "seconds")

-- Profiling component renders (automatically tracked by renderer)
-- When enabled, patch operations are automatically profiled:
-- - patch_mount: Time to mount new components
-- - patch_update: Time to update existing components
-- - patch_unmount: Time to unmount components

-- Check if profiler is active
if Rivue.utils.profiler.active then
    print("Profiling enabled")
end

-- Manually enable/disable
Rivue.utils.profiler.active = true -- Enable profiling
Rivue.utils.profiler.active = false -- Disable profiling

-- Profiler methods
Rivue.utils.profiler:mark("checkpoint") -- Mark a point in time
local duration = Rivue.utils.profiler:measure("checkpoint") -- Measure since mark
```

**Type Definition:**

```lua
type Profiler = {
    active: boolean, -- Is profiling enabled
    start: (name: string) -> (),
    stop: (name: string) -> number?,
    mark: (name: string) -> (),
    measure: (name: string) -> number?
}
```

**Automatic Integration:**

The profiler is automatically integrated with:

- **Renderer**: Patch operations (mount/update/unmount)
- **Reactivity**: Effect execution (when manually enabled)
- **h.luau**: VNode creation in hFor/hForParallel

**Note:** Profiling has minimal overhead when disabled and is automatically disabled in production builds.

---

#### `utils.shallowEqual(a: any, b: any): boolean`

Performs shallow equality comparison between two values. Useful for prop comparison and memoization.

```lua
local obj1 = { count = 0, name = "Alice" }
local obj2 = { count = 0, name = "Alice" }
local obj3 = { count = 1, name = "Alice" }
local obj4 = { count = 0, name = "Alice", nested = { value = 10 } }
local obj5 = { count = 0, name = "Alice", nested = { value = 10 } }

print(Rivue.utils.shallowEqual(obj1, obj2)) -- true (same top-level values)
print(Rivue.utils.shallowEqual(obj1, obj3)) -- false (different count)
print(Rivue.utils.shallowEqual(obj4, obj5)) -- false (nested objects are different references)

-- Primitives
print(Rivue.utils.shallowEqual(5, 5)) -- true
print(Rivue.utils.shallowEqual("hello", "hello")) -- true
print(Rivue.utils.shallowEqual(true, false)) -- false

-- Arrays
local arr1 = { 1, 2, 3 }
local arr2 = { 1, 2, 3 }
print(Rivue.utils.shallowEqual(arr1, arr2)) -- true

-- Use in component shouldUpdate optimization
local function shouldComponentUpdate(oldProps, newProps)
    return not Rivue.utils.shallowEqual(oldProps, newProps)
end
```

**Type Definition:**

```lua
function shallowEqual(a: any, b: any): boolean
```

**Comparison Rules:**

1. **Primitives**: Compared by value (`==`)
2. **Tables**: Compared by top-level key-value pairs
3. **Nested objects**: Compared by reference (not deeply compared)
4. **Different types**: Always return false

**Use Cases:**

- Component prop comparison for shouldUpdate optimization
- Memoization cache key comparison
- Preventing unnecessary re-renders
- Detecting changes in reactive state

---

#### `iterArray<T>(array: { T }): () -> (number?, T?)`

**Also available as:** `Rivue.iterArray()`

Iterator for reactive arrays that provides `ipairs`-like syntax while maintaining full reactivity tracking.

**Why it's needed:** Luau's built-in `ipairs()` doesn't work with reactive proxies because it checks for `table[1]` before invoking the `__ipairs` metamethod. Since reactive proxies are empty tables with data stored internally, this check fails.

**Usage:**

```lua
local items = Rivue.reactive({ "apple", "banana", "cherry" })

-- ✅ Using iterArray (ipairs-like syntax)
for i, item in Rivue.iterArray(items) do
    print(i, item)
end

-- ✅ Also works: numeric iteration
for i = 1, #items do
    print(i, items[i])
end

-- ❌ Won't work: ipairs on reactive arrays
for i, item in ipairs(items) do  -- Empty loop!
    print(i, item)
end
```

**Features:**

- Works with both reactive and non-reactive arrays
- Properly triggers `__len` and `__index` metamethods
- Maintains full dependency tracking
- Provides familiar iteration syntax

**See also:** [Iterating Reactive Arrays](RUNTIME_REFERENCE.md#iterating-reactive-arrays) in Runtime Reference for detailed explanation.

---

### Scheduler

Rivue includes a built-in job scheduler for efficient batching and prioritization of reactive updates.

#### `scheduler.queueJob(fn: () -> (), mode?: "micro" | "render" | "heartbeat"): () -> ()`

Queue a job to run at the specified priority level.

**Parameters:**

- `fn: () -> ()` - Function to execute
- `mode?: "micro" | "render" | "heartbeat"` - Execution timing (default: `"micro"`)

**Returns:** A cancellation function that prevents the job from executing.

**Modes:**

1. **`"micro"` (default)** - Runs on next micro-task (via `task.defer`)
   - **Single flush per tick:** All micro jobs are batched and flushed once per tick
   - **Deduplication:** Same function queued multiple times executes only once per flush
   - **Re-queueable:** Can queue the same function again after flush completes
   - Best for reactive updates, watchers, and effects

2. **`"render"` - Runs on next RenderStepped**
   - Best for visual updates, animations
   - Runs before each frame renders

3. **`"heartbeat"` - Runs on next Heartbeat**
   - Best for physics, game logic
   - Runs after physics simulation

**Usage:**

```lua
local scheduler = Rivue.scheduler

-- Queue a micro job (batched, deduplicated)
local updateUI = function()
    print("UI updated")
end

scheduler.queueJob(updateUI, "micro")  -- Queued
scheduler.queueJob(updateUI, "micro")  -- Deduplicated (same function)
scheduler.queueJob(updateUI, "micro")  -- Deduplicated (same function)
-- Result: updateUI executes once on next micro-task

-- After flush completes, can queue again
Rivue.utils.nextTick(function()
    scheduler.queueJob(updateUI, "micro")  -- New batch, will execute
end)

-- Cancellation
local cancel = scheduler.queueJob(function()
    print("This won't run")
end, "micro")

cancel()  -- Prevents execution

-- Render mode for animations
scheduler.queueJob(function()
    -- Update animation frame
end, "render")

-- Heartbeat mode for game logic
scheduler.queueJob(function()
    -- Update game state
end, "heartbeat")
```

**Deduplication Behavior:**

```lua
local count = 0

local increment = function()
    count = count + 1
    print("Count:", count)
end

-- Queue same function 3 times in same tick
scheduler.queueJob(increment, "micro")
scheduler.queueJob(increment, "micro")
scheduler.queueJob(increment, "micro")

-- After flush: prints "Count: 1" (executed once)

-- Queue different functions - all execute
scheduler.queueJob(function() print("A") end, "micro")
scheduler.queueJob(function() print("B") end, "micro")
scheduler.queueJob(function() print("C") end, "micro")
-- After flush: prints "A", "B", "C"
```

**Performance Notes:**

- Micro mode uses a single `task.defer` per tick, regardless of how many jobs are queued
- Deduplication prevents redundant work from multiple reactive triggers
- Batching reduces overhead and improves cache locality

**Use Cases:**

- Reactive system uses micro mode for batched effect updates
- Component lifecycle hooks use micro mode for batched updates
- Custom animations can use render mode for frame-aligned updates
- Game logic can use heartbeat mode for physics-aligned updates

---

## Luau & Roblox Quirks

This section documents Luau-specific behaviors and Roblox API quirks that affect Rivue usage.

### Reactive Proxies and `pairs()`

**Issue:** Luau's `pairs()` doesn't work directly on reactive proxies created with `reactive()` or `shallowReactive()`.

**Why:** Reactive proxies are empty tables with a metatable. Data is stored internally, and `pairs()` only iterates the actual table keys (which are empty).

**Solution:** Use `toRaw()` to get the underlying data before iterating.

```lua
local state = Rivue.reactive({
    name = "Alice",
    age = 30,
    city = "New York"
})

-- ❌ Won't work: pairs() on reactive proxy
for key, value in pairs(state) do
    print(key, value)  -- Empty loop! No output
end

-- ✅ Correct: Use toRaw() before pairs()
local raw = Rivue.toRaw(state)
for key, value in pairs(raw) do
    print(key, value)  -- Works! Prints all key-value pairs
end

-- ✅ Alternative: Access properties directly
print(state.name)   -- "Alice" - works fine
print(state.age)    -- 30 - works fine
state.city = "LA"   -- Works fine, triggers reactivity
```

### Reactive Arrays and `ipairs()`

**Issue:** Luau's `ipairs()` doesn't work on reactive arrays.

**Why:** `ipairs()` checks for `table[1]` before invoking the `__ipairs` metamethod. Reactive proxies are empty tables, so this check fails.

**Solution:** Use `iterArray()` or numeric iteration.

```lua
local items = Rivue.reactive({ "apple", "banana", "cherry" })

-- ❌ Won't work: ipairs() on reactive arrays
for i, item in ipairs(items) do
    print(i, item)  -- Empty loop! No output
end

-- ✅ Correct: Use iterArray()
for i, item in Rivue.iterArray(items) do
    print(i, item)  -- Works! Prints all items with indices
end

-- ✅ Alternative: Numeric iteration
for i = 1, #items do
    print(i, items[i])  -- Works! Prints all items
end

-- ❌ Won't track reactivity: toRaw() + ipairs
local raw = Rivue.toRaw(items)
for i, item in ipairs(raw) do
    print(i, item)  -- Works, but won't trigger reactive updates
end
```

### Operator on Reactive Arrays

**Status:** ✅ Works correctly

```lua
local items = Rivue.reactive({ 1, 2, 3, 4, 5 })

print(#items)  -- 5 (correctly triggers __len metamethod)

items[6] = 6
print(#items)  -- 6 (reactivity tracked)
```

### Property Access on Reactive Objects

**Status:** ✅ Works correctly

```lua
local state = Rivue.reactive({
    nested = { count = 0 }
})

-- ✅ Direct property access works
print(state.nested.count)  -- 0
state.nested.count = 5     -- Triggers reactivity

-- ✅ Dynamic keys work
local key = "nested"
print(state[key].count)    -- 5
```

### Time Units: Milliseconds vs Seconds

**Issue:** Roblox APIs inconsistently use seconds (e.g., `task.wait()`) vs milliseconds (e.g., TweenInfo).

**Rivue Convention:** Rivue prefers **milliseconds** for consistency with web standards (JavaScript, CSS).

**Auto-Conversion:** `debounce()` and `throttle()` auto-convert values < 1 from seconds to milliseconds for backward compatibility.

```lua
-- ✅ Recommended: Use milliseconds explicitly
Rivue.utils.debounce(fn, 500)   -- 500ms
Rivue.utils.throttle(fn, 1000)  -- 1000ms = 1 second

-- ✅ Also works: Auto-converts values < 1
Rivue.utils.debounce(fn, 0.5)   -- Auto-converts to 500ms
Rivue.utils.throttle(fn, 0.1)   -- Auto-converts to 100ms

-- Comparison with Roblox APIs
task.wait(0.5)        -- 0.5 seconds (Roblox convention)
task.delay(1, fn)     -- 1 second (Roblox convention)

TweenInfo.new(0.5)    -- 0.5 seconds (TweenInfo expects seconds)
TweenInfo.new(500)    -- 500 seconds (not milliseconds!)
```

**Recommendation:** Always use milliseconds explicitly in Rivue utilities to avoid confusion.

### Instance Property Reactivity

**Status:** ✅ Works with `vModel` directives

```lua
-- ✅ Correct: Use vModel for two-way binding
local inputText = Rivue.ref("")

h("TextBox", Rivue.vModelText(inputText))

-- User types "hello" → inputText.value becomes "hello"
-- Code sets inputText.value = "world" → TextBox.Text becomes "world"

-- ❌ Won't work: Direct property binding isn't reactive
h("TextBox", {
    Text = inputText.value,  -- Only sets initial value, doesn't update
    [Rivue.Changed("Text")] = function(new)
        inputText.value = new  -- Manual two-way binding (verbose)
    end
})
```

### Table Mutation Detection

**Issue:** Luau doesn't have native Proxy support. Rivue uses metatables to intercept property access.

**Limitation:** Direct table mutation (e.g., `table.insert`, `table.remove`) doesn't trigger reactivity without special handling.

**Solution:** Use array index assignment or Rivue utilities.

```lua
local items = Rivue.reactive({ "a", "b", "c" })

-- ❌ Won't trigger reactivity
table.insert(items, "d")  -- Added, but watchers don't run

-- ✅ Correct: Use index assignment
items[#items + 1] = "d"  -- Triggers reactivity

-- ✅ Also correct: Replace entire array
items.value = { "a", "b", "c", "d" }  -- If using ref

-- ✅ Correct: Use reactive ref methods (if available)
local itemsRef = Rivue.ref({ "a", "b", "c" })
itemsRef.value[#itemsRef.value + 1] = "d"  -- Triggers reactivity
```

**Advanced:** For comprehensive array reactivity, consider wrapping mutations:

```lua
local function pushItem(reactiveArray, item)
    reactiveArray[#reactiveArray + 1] = item
end

local function removeItem(reactiveArray, index)
    table.remove(Rivue.toRaw(reactiveArray), index)
    -- Manually trigger update if needed
    Rivue.triggerRef(reactiveArray)  -- If using refs
end
```

---

## Rivue Configuration

### `Rivue.dev: boolean`

Automatically set to `true` in Roblox Studio, `false` in published games.

```lua
if Rivue.dev then
    print("Running in development mode")
end
```

### `Rivue.debug: boolean`

Controls verbose debug logging across Rivue. Automatically set to `Rivue.dev` by default.

When enabled, Rivue logs detailed information about:

- Scheduler job queuing, flushing, and deduplication
- Reactivity trigger chains and effect runs
- Utility function timing (throttle/debounce execution)
- Performance measurements

```lua
-- Enable debug logging (even in published games)
Rivue.debug = true

-- Disable debug logging (even in Studio)
Rivue.debug = false

-- Check debug status
if Rivue.debug then
    print("Debug logging is enabled")
end
```

**Debug Output Example:**

```txt
[Rivue:DEBUG:Scheduler] Queueing job { mode = "micro" }
[Rivue:DEBUG:Scheduler] Added to micro queue { queueSize = 3 }
[Rivue:DEBUG:Scheduler] Scheduling micro flush
[Rivue:DEBUG:Scheduler] Flushing micro queue { jobCount = 3 }
[Rivue:DEBUG:Scheduler] Micro queue flush complete { executed = 3 }
[Rivue:DEBUG:Performance] FlushMicro took 0.152ms
```

**Performance Impact:** Debug logging has minimal overhead when disabled (single boolean check). When enabled, expect ~5-10% performance impact due to string formatting and print calls.

**Recommendation:** Keep debug logging disabled in production for better performance. Enable selectively for troubleshooting.

### `Rivue.log(level: string, message: string, data: any?)`

Structured logging helper that only outputs when `Rivue.dev = true`.

```lua
-- Only prints in Studio
Rivue.log("info", "Component mounted")
Rivue.log("warn", "Slow render detected", { duration = 50 })
Rivue.log("error", "Failed to load data")
```

**Parameters:**

- `level`: "info", "warn", or "error"
- `message`: Log message
- `data` (optional): Additional context to log

**Output format:** `[Rivue][LEVEL] message`

---

## Remote Communication

The `Remote` API provides client-side wrappers for RemoteEvents with request/response patterns and built-in security validation.

### `Remote.request(actionName: string, payload: any, timeout?: number): (data: any?, error: string?)`

Sends a validated request to the server and waits for a response.

```lua
local data, err = Rivue.Remote.request("getData", { userId = 123 }, 10)

if err then
    warn("Request failed:", err)
    -- Possible error codes:
    -- "invalid_action_name" - action name empty or > 100 chars
    -- "payload_not_serializable" - contains invalid types
    -- "payload_too_large" - exceeds 20KB JSON size limit
    -- "payload_unsafe_type" - contains functions, userdata, etc.
    -- "timeout" - request exceeded timeout duration
else
    print("Received data:", data)
end
```

**Security features:**

- **Action name validation**: Must be 1-100 characters
- **Payload type safety**: Only allows tables, strings, numbers, booleans, nil
- **Size limits**: Maximum 20KB when JSON serialized
- **Nesting depth limit**: Maximum 10 levels to prevent deep recursion
- **Automatic serialization check**: Validates payload can be sent over network

**Server-side handling:**

```lua
-- Server must respond using the Response RemoteEvent
local folder = ReplicatedStorage:WaitForChild("RemoteEvents")
local requestEvent = folder:WaitForChild("Request")
local responseEvent = folder:WaitForChild("Response")

requestEvent.OnServerEvent:Connect(function(player, req)
    if req.action == "getData" then
        local data = { name = "Alice", score = 100 }
        responseEvent:FireClient(player, {
            id = req.id,
            ok = true,
            data = data
        })
    end
end)
```

---

### `Remote.fire(actionName: string, payload: any)`

Fires a one-way event to the server (no response expected).

```lua
Rivue.Remote.fire("playerJumped", { height = 50 })
```

---

### `Remote.on(eventName: string, callback: function): RBXScriptConnection`

Listens for server events.

```lua
local conn = Rivue.Remote.on("serverAnnouncement", function(message)
    print("Server says:", message)
end)

-- Cleanup
conn:Disconnect()
```

---

## Advanced Features

### Keyed Children

Use `key` prop for efficient list rendering and reordering.

```lua
local items = ref({
    { id = 1, text = "First" },
    { id = 2, text = "Second" },
    { id = 3, text = "Third" }
})

return function()
    return h("Frame", {},
        hFor(items.value, function(item)
            return h("TextLabel", {
                key = item.id, -- Critical for efficient updates
                Text = item.text
            })
        end)
    )
end
```

**Without keys:** Rivue re-creates all elements on every change.  
**With keys:** Rivue reuses existing elements, only moving/updating what changed.

---

### Transitions

Add enter/leave animations to elements.

```lua
h("Frame", {
    transition = {
        info = TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        enterGoals = { BackgroundTransparency = 0 },
        leaveGoals = { BackgroundTransparency = 1 }
    }
})
```

---

### Object Pooling

Enable object pooling for better performance with frequently created/destroyed elements.

```lua
local app = Rivue.createApp(rootVNode, { usePool = true })
```

**Benefits:**

- Reduces Instance.new() calls
- Reuses instances instead of destroying them
- Significant performance improvement for dynamic UIs

**Advanced Pool API:**

Rivue exposes the pool module for advanced control:

```lua
-- Access pool module
local Pool = Rivue.pool

-- Configure pool behavior
Pool.configure({
    maxPoolSize = 50,        -- Max instances per class
    maxTotalSize = 500,      -- Max total instances across all classes
    enableMetrics = true,    -- Track usage statistics
    enableDebug = false,     -- Enhanced debug logging
    defaultTTL = 300,        -- Time-to-live in seconds (nil = infinite)
    enableAutoWarmup = false -- Auto-warmup on first acquire
})

-- Manual pool operations
local frame = Pool.acquire("Frame")
-- ... use frame ...
Pool.release(frame)

-- Bulk operations
local frames = Pool.acquireMultiple("Frame", 5)
Pool.releaseMultiple(frames)

-- Pre-populate pool (warmup)
Pool.warmup("TextLabel", 20) -- Create 20 TextLabels in pool

-- Get statistics
local stats = Pool.getStatistics()
print("Total instances:", stats.totalInstances)
print("Hit rate:", stats.hitRate) -- Cache hit rate (0-1)
print("Metrics:", stats.metrics.acquires, stats.metrics.hits, stats.metrics.misses)

-- Health check and cleanup
local isHealthy = Pool.validateHealth() -- Removes destroyed instances

-- Snapshot and restore
local snapshot = Pool.createSnapshot()
-- ... do something ...
Pool.restoreSnapshot(snapshot)

-- Custom reset handlers
Pool.setResetHandler("Frame", function(inst)
    inst.BackgroundColor3 = Color3.new(1, 1, 1)
    inst.BorderSizePixel = 0
end)

-- Event hooks
Pool.setEventHook("onAcquire", function(inst, fromPool)
    print("Acquired:", inst.ClassName, "from pool:", fromPool)
end)

Pool.setEventHook("onRelease", function(inst, pooled)
    print("Released:", inst.ClassName, "pooled:", pooled)
end)

Pool.setEventHook("onEvict", function(inst, reason)
    print("Evicted:", inst.ClassName, "reason:", reason)
end)

-- Clear pool (all or specific class)
Pool.clear() -- Clear all
Pool.clear("Frame") -- Clear only Frames
```

**Pool Statistics from App:**

```lua
local app = Rivue.createApp(rootVNode, { usePool = true })
app:mount(playerGui)

-- Get pool stats through app API
local stats = app:getPoolStatistics()
if stats then
    print("Pool hit rate:", stats.hitRate)
    print("Total instances:", stats.totalInstances)
end
```

**Type Definitions:**

```lua
type PoolConfig = {
    maxPoolSize: number?,
    maxTotalSize: number?,
    enableMetrics: boolean?,
    enableDebug: boolean?,
    defaultTTL: number?,
    enableAutoWarmup: boolean?
}

type PoolMetrics = {
    acquires: number,
    releases: number,
    creates: number,
    hits: number,
    misses: number,
    destroyed: number,
    evictions: number
}

type PoolStatistics = {
    totalInstances: number,
    poolsByClass: { [string]: number },
    metrics: PoolMetrics,
    hitRate: number
}
```

---

### Teleport (Portal)

Renders content in a different location in the Roblox instance tree, useful for modals, tooltips, and overlays.

```lua
-- Basic usage: Teleport to a specific container
h(Rivue.Teleport, {
    to = playerGui:WaitForChild("ModalContainer")
}, {
    h("Frame", {
        Size = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    }, {
        h("TextLabel", { Text = "I'm in a different container!" })
    })
})

-- Dynamic target using function
local modalContainer = ref(nil)

h(Rivue.Teleport, {
    to = function()
        return modalContainer.value or playerGui
    end
}, {
    h("TextLabel", { Text = "Dynamic teleport target" })
})

-- Conditional teleport with disabled prop
local usePortal = ref(true)

h(Rivue.Teleport, {
    to = playerGui.Overlays,
    disabled = not usePortal.value  -- When true, renders in normal location
}, {
    h("TextLabel", { Text = "Maybe teleported" })
})
```

**Props:**

- `to: Instance | () -> Instance` - Target container (can be dynamic function)
- `disabled: boolean?` - When true, renders normally without teleporting

**Use Cases:**

- **Modals & Dialogs**: Render above all other content
- **Tooltips**: Position tooltips in a dedicated overlay layer
- **Notifications**: Toast notifications in a fixed container
- **Context Menus**: Dropdowns that escape parent scroll containers
- **Fullscreen Overlays**: Loading screens, confirmations

#### Example: Modal System

```lua
local Modal = defineComponent({
    setup = function(props, context)
        local isOpen = ref(props.isOpen or false)
        
        return function()
            if not isOpen.value then
                return nil
            end
            
            return h(Rivue.Teleport, {
                to = playerGui:WaitForChild("Modals")
            }, {
                h("Frame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                    BackgroundTransparency = 0.5,
                    __directives = {
                        { name = "fade-in", value = { duration = 0.2 } }
                    }
                }, {
                    h("Frame", {
                        Size = UDim2.fromScale(0.4, 0.3),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.fromScale(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    }, context.slots)
                })
            })
        end
    end
})

-- Usage
h(Modal, { isOpen = showModal.value }, {
    h("TextLabel", { Text = "Modal content" }),
    h("TextButton", { 
        Text = "Close",
        onClick = function() showModal.value = false end
    })
})
```

**Performance Tip:** Teleport children maintain their reactivity and lifecycle. Use `v-show` instead of conditional rendering for frequently toggled teleported content.

---

### Suspense

Handles asynchronous component rendering with loading and error states. Suspense waits for async children to resolve before showing content, displaying a fallback UI during loading.

```lua
-- Basic usage with async component
local AsyncData = defineComponent({
    setup = function()
        local data = ref(nil)
        
        -- Simulate async data fetch
        task.spawn(function()
            task.wait(2)
            data.value = "Loaded data!"
        end)
        
        return function()
            if not data.value then
                -- Signal to Suspense we're still loading
                return nil
            end
            return h("TextLabel", { Text = data.value })
        end
    end
})

h(Rivue.Suspense, {
    fallback = h("TextLabel", { Text = "Loading..." }),
    timeout = 5000  -- Show error after 5 seconds
}, {
    h(AsyncData)
})
```

**Props:**

- `fallback: VNode` - Loading UI to show while waiting
- `timeout: number?` - Max wait time in ms (default: 5000). Shows error state if exceeded.

**Use Cases:**

- **Data Fetching**: Wait for API responses before rendering
- **Lazy Loading**: Show loading state while components load
- **Image Loading**: Wait for texture/image assets
- **Multi-Step Loading**: Coordinate multiple async dependencies

**Using with defineAsyncComponent:**

```lua
local HeavyComponent = Rivue.defineAsyncComponent(function()
    -- Simulate loading a large module
    task.wait(1)
    return defineComponent({
        setup = function()
            return function()
                return h("TextLabel", { Text = "Heavy component loaded!" })
            end
        end
    })
end, {
    loadingComponent = h("TextLabel", { Text = "Loading component..." }),
    errorComponent = h("TextLabel", { Text = "Failed to load" }),
    delay = 200,  -- Delay before showing loading (avoid flash)
    timeout = 3000
})

-- Use in Suspense
h(Rivue.Suspense, {
    fallback = h("TextLabel", { Text = "Preparing UI..." })
}, {
    h(HeavyComponent)
})
```

**Error Handling:**

```lua
h(Rivue.Suspense, {
    fallback = h("TextLabel", { Text = "Loading..." }),
    timeout = 3000,
    onError = function(err)
        warn("Suspense timeout or error:", err)
    end
}, {
    h(AsyncComponent)
})
```

---

### KeepAlive

Caches component instances to preserve state when components are toggled or switched. Uses LRU (Least Recently Used) cache strategy.

```lua
local currentTab = ref("tab1")

local Tab1 = defineComponent({
    setup = function()
        local count = ref(0)
        return function()
            return h("TextButton", {
                Text = "Tab 1 - Count: " .. count.value,
                onClick = function() count.value = count.value + 1 end
            })
        end
    end
})

local Tab2 = defineComponent({
    setup = function()
        local text = ref("")
        return function()
            return h("TextBox", Rivue.vModelText(text))
        end
    end
})

-- Keep component state alive when switching tabs
h(Rivue.KeepAlive, {
    max = 10,  -- Cache up to 10 components
    include = { "Tab1", "Tab2" }  -- Only cache these
}, {
    currentTab.value == "tab1" and h(Tab1) or h(Tab2)
})
```

**Props:**

- `include: string[]?` - Component names to cache (whitelist)
- `exclude: string[]?` - Component names to never cache (blacklist)
- `max: number?` - Maximum cached instances (default: 10)

**Use Cases:**

- **Tab Navigation**: Preserve form state when switching tabs
- **Route Caching**: Keep route components alive for instant back navigation
- **Performance**: Avoid re-creating expensive components
- **User Experience**: Maintain scroll position, input state

**Component Naming for KeepAlive:**

```lua
local MyComponent = defineComponent({
    __name = "MyComponent",  -- Required for include/exclude
    setup = function()
        -- ...
    end
})
```

#### Example: Tab System with State Preservation

```lua
local TabManager = defineComponent({
    setup = function()
        local activeTab = ref("home")
        
        local Home = defineComponent({ __name = "Home", setup = ... })
        local Profile = defineComponent({ __name = "Profile", setup = ... })
        local Settings = defineComponent({ __name = "Settings", setup = ... })
        
        return function()
            return h("Frame", {}, {
                -- Tab buttons
                h("Frame", {}, {
                    h("TextButton", {
                        Text = "Home",
                        onClick = function() activeTab.value = "home" end
                    }),
                    h("TextButton", {
                        Text = "Profile",
                        onClick = function() activeTab.value = "profile" end
                    }),
                    h("TextButton", {
                        Text = "Settings",
                        onClick = function() activeTab.value = "settings" end
                    })
                }),
                
                -- Cached tab content
                h(Rivue.KeepAlive, {
                    max = 3,
                    include = { "Home", "Profile", "Settings" }
                }, {
                    activeTab.value == "home" and h(Home)
                    or activeTab.value == "profile" and h(Profile)
                    or h(Settings)
                })
            })
        end
    end
})
```

**Cache Eviction:**

When `max` is exceeded, the least recently activated component is removed from cache:

```lua
h(Rivue.KeepAlive, { max = 2 }, {
    -- Only the 2 most recently active components are cached
    -- Older components are unmounted and state is lost
})
```

---

### defineAsyncComponent

Creates a component that loads asynchronously with loading and error states.

```lua
local AsyncComponent = Rivue.defineAsyncComponent(function()
    -- Async loader function
    task.wait(2)  -- Simulate network delay
    return MyHeavyComponent
end, {
    loadingComponent = h("TextLabel", { Text = "Loading..." }),
    errorComponent = h("TextLabel", { Text = "Failed to load" }),
    delay = 200,  -- Delay before showing loading (ms)
    timeout = 5000  -- Timeout for loading (ms)
})

-- Use like a normal component
h(AsyncComponent, { someProp = "value" })
```

**Parameters:**

- `loader: () -> ComponentDefinition` - Function that returns a component
- `options: table?` - Configuration object:
  - `loadingComponent: VNode?` - Component to show while loading
  - `errorComponent: VNode?` - Component to show on error/timeout
  - `delay: number?` - Delay in ms before showing loading component (default: 200)
  - `timeout: number?` - Timeout in ms (default: 5000)

**Use Cases:**

- **Code Splitting**: Load heavy components only when needed
- **Lazy Routes**: Load route components on demand
- **Conditional Features**: Load feature components based on user actions
- **Network Resources**: Components that fetch remote data

#### Example: Lazy-Loded Settings Panel

```lua
local SettingsPanel = Rivue.defineAsyncComponent(function()
    -- Load heavy settings UI module
    local SettingsModule = require(ReplicatedStorage.HeavyModules.Settings)
    return SettingsModule.Component
end, {
    loadingComponent = h("Frame", {}, {
        h("TextLabel", { Text = "Loading settings..." })
    }),
    errorComponent = h("Frame", {}, {
        h("TextLabel", { Text = "Failed to load settings" }),
        h("TextButton", { 
            Text = "Retry",
            onClick = function() 
                -- Retry logic
            end
        })
    }),
    delay = 300,
    timeout = 10000
})

-- Only loads when user opens settings
local showSettings = ref(false)

h("Frame", {}, {
    h("TextButton", {
        Text = "Open Settings",
        onClick = function() showSettings.value = true end
    }),
    showSettings.value and h(SettingsPanel) or nil
})
```

---

### Composition API Helpers

#### `useAttrs(): { [string]: any }`

Returns non-declared props (fallthrough attributes). Must be called during component `setup()`.

```lua
local MyComponent = defineComponent({
    props = {
        title = { type = "string" }
    },
    setup = function(props, context)
        local attrs = Rivue.useAttrs()
        
        -- attrs contains all props not declared in props schema
        -- e.g., { class = "...", onClick = ..., customProp = ... }
        
        return function()
            return h("TextButton", {
                Text = props.title,
                -- Spread attrs to child element
                Name = attrs.Name,
                onClick = attrs.onClick
            })
        end
    end
})

-- Usage: onClick and Name are passed as attrs
h(MyComponent, {
    title = "Click Me",
    onClick = function() print("clicked") end,
    Name = "CustomButton"
})
```

#### `useSlots(): { VNode }`

Returns child content slots. Must be called during component `setup()`.

```lua
local Card = defineComponent({
    setup = function()
        local slots = Rivue.useSlots()
        
        return function()
            return h("Frame", {}, {
                h("TextLabel", { Text = "Card Header" }),
                -- Render slot content
                slots[1],  -- Default slot
                slots.footer  -- Named slot
            })
        end
    end
})

-- Usage
h(Card, {}, {
    h("TextLabel", { Text = "Card body content" }),  -- Default slot
    footer = h("TextButton", { Text = "OK" })  -- Named slot
})
```

#### `defineModel(options?: { name: string?, event: string? }): (props, context) -> ComputedRef`

Creates a computed ref for two-way binding (v-model). Returns a factory function.

```lua
local CustomInput = defineComponent({
    props = {
        modelValue = { type = "string", default = "" }
    },
    setup = function(props, context)
        -- Create v-model binding
        local model = Rivue.defineModel()(props, context)
        
        return function()
            return h("TextBox", {
                Text = model.value,
                onTextChanged = function(new)
                    model.value = new  -- Emits "update:modelValue"
                end
            })
        end
    end
})

-- Usage: two-way binding
local text = ref("")
h(CustomInput, Rivue.vModelText(text))
```

**With Custom Model Name:**

```lua
local RangeSlider = defineComponent({
    props = {
        min = { type = "number", default = 0 },
        max = { type = "number", default = 100 }
    },
    setup = function(props, context)
        local minModel = Rivue.defineModel({ 
            name = "min",
            event = "update:min"
        })(props, context)
        
        local maxModel = Rivue.defineModel({ 
            name = "max",
            event = "update:max"
        })(props, context)
        
        return function()
            return h("Frame", {}, {
                h("TextBox", {
                    Text = tostring(minModel.value),
                    onTextChanged = function(new)
                        minModel.value = tonumber(new) or 0
                    end
                }),
                h("TextBox", {
                    Text = tostring(maxModel.value),
                    onTextChanged = function(new)
                        maxModel.value = tonumber(new) or 100
                    end
                })
            })
        end
    end
})
```

#### `useTheme(): any?`

Retrieves theme from ancestor component's `provide()`. Walks component tree upward.

```lua
-- Parent provides theme
local App = defineComponent({
    setup = function(props, context)
        context.provide("theme", {
            primaryColor = Color3.fromRGB(66, 135, 245),
            textColor = Color3.fromRGB(255, 255, 255)
        })
        
        return function()
            return h(ChildComponent)
        end
    end
})

-- Child uses theme
local ChildComponent = defineComponent({
    setup = function()
        local theme = Rivue.useTheme()
        
        return function()
            return h("TextButton", {
                BackgroundColor3 = theme.primaryColor,
                TextColor3 = theme.textColor,
                Text = "Themed Button"
            })
        end
    end
})
```

#### `useStyles(factory: (theme: any) -> table): ComputedRef<table>`

Creates computed styles that react to theme changes.

```lua
local MyComponent = defineComponent({
    setup = function()
        local theme = Rivue.useTheme()
        
        local styles = Rivue.useStyles(function(t)
            return {
                button = {
                    BackgroundColor3 = t.primaryColor,
                    TextColor3 = t.textColor,
                    Size = UDim2.fromScale(0.2, 0.1)
                },
                text = {
                    TextColor3 = t.textColor,
                    Font = t.font
                }
            }
        end)
        
        return function()
            return h("Frame", {}, {
                h("TextButton", styles.value.button, {
                    h("TextLabel", styles.value.text)
                })
            })
        end
    end
})
```

---

### Scheduler API

Rivue exposes a job scheduler for advanced control over update timing.

```lua
local scheduler = Rivue.scheduler

-- Queue a job with specific timing mode
scheduler.queueJob(function()
    print("Job executed")
end, {
    mode = "render" -- "micro", "render", or "heartbeat"
})

-- Auto-cleanup wrapper (tracks jobs in component context)
Rivue.queueJob(function()
    -- This job is automatically cancelled when component unmounts
    updateState()
end, { mode = "render" })
```

**Scheduler Modes:**

- `"micro"`: Executes on next micro-task (immediate, same frame)
- `"render"`: Executes on next RenderStepped (before rendering)
- `"heartbeat"`: Executes on next Heartbeat (after physics)

**Type Definition:**

```lua
type JobOptions = {
    mode: "micro" | "render" | "heartbeat"?,
    id: any? -- Optional deduplication ID
}

type JobHandle = {
    cancel: () -> ()
}

function queueJob(fn: () -> (), opts: JobOptions?): JobHandle
```

**Use Cases:**

- **Batch Updates**: Group multiple state changes into single render
- **Deferred Work**: Delay non-critical work to next frame
- **Update Timing**: Control when effects run relative to rendering
- **Performance Optimization**: Spread expensive work across frames

#### Example: Batched State Updates

```lua
local count = ref(0)
local name = ref("Alice")
local age = ref(25)

-- Without scheduler: 3 separate renders
count.value = 10
name.value = "Bob"
age.value = 30

-- With scheduler: 1 batched render
Rivue.queueJob(function()
    count.value = 10
    name.value = "Bob"
    age.value = 30
end, { mode = "render" })
```

#### Auto-Cleanup

When `Rivue.queueJob()` is called during component setup, the job is automatically tracked and cancelled on component unmount:

```lua
setup = function()
    -- This job is auto-cancelled on unmount
    Rivue.queueJob(function()
        -- Recurring work
        Rivue.queueJob(doWork, { mode = "heartbeat" })
    end)
    
    -- Manual cleanup not needed!
end
```

---

### Roblox Integration Utilities

#### `attributeRef(instance: Instance, attributeName: string, defaultValue?: T, options?: { throttle: number? }): Ref<T>`

Creates a reactive reference that syncs bidirectionally with an Instance attribute. Changes to the ref update the attribute, and attribute changes update the ref.

```lua
local character = workspace:WaitForChild("Character")

-- Basic usage
local health = Rivue.attributeRef(character, "Health", 100)

watch(health, function(newHealth)
    print("Health changed:", newHealth)
end)

health.value = 50 -- Updates attribute
-- Attribute changes also update health.value

-- With throttling for high-frequency attributes
local position = Rivue.attributeRef(character, "Position", Vector3.new(0, 0, 0), {
    throttle = 100 -- Throttle updates to max once per 100ms
})

-- Useful for rapidly changing attributes like position, velocity, etc.
RunService.Heartbeat:Connect(function()
    character:SetAttribute("Position", character.PrimaryPart.Position)
    -- position.value updates at most every 100ms
end)
```

**Type Definition:**

```lua
type AttributeRefOptions = {
    throttle: number? -- Throttle delay in milliseconds
}

function attributeRef<T>(
    instance: Instance,
    attributeName: string,
    defaultValue: T?,
    options: AttributeRefOptions?
): Ref<T>
```

**Features:**

- **Bidirectional Sync**: Ref ↔ Attribute automatically synchronized
- **Auto-Cleanup**: Connection is automatically disconnected on component unmount
- **Circular Update Prevention**: Prevents infinite update loops
- **Throttling**: Optional throttling for high-frequency attribute changes
- **Type-Safe**: Preserves TypeScript-like type safety

**Use Cases:**

- **Character Stats**: Health, stamina, mana synced with attributes
- **Configuration**: Sync UI controls with object attributes
- **Real-time Data**: Position, velocity, or other frequently updated values
- **Persistence**: Attributes that persist across server/client

**Manual Cleanup (if not in component context):**

```lua
local ref = Rivue.attributeRef(instance, "Value", 0)

-- Manually cleanup when done
ref._cleanup()
```

#### `useTag(tagName: string, onAdded: (instance: Instance) -> (() -> ())?)`

Registers callbacks for CollectionService tagged instances with automatic cleanup.

```lua
Rivue.useTag("Enemy", function(enemy)
    print("Enemy spawned:", enemy.Name)
    
    -- Return cleanup function (optional)
    return function()
        print("Enemy despawned:", enemy.Name)
    end
end)
```

#### `onRenderStepped(callback: (deltaTime: number) -> ())`

Registers a RunService.RenderStepped callback with auto-disconnect on unmount.

```lua
Rivue.onRenderStepped(function(dt)
    -- Update camera or UI every frame (before rendering)
end)
```

#### `onHeartbeat(callback: (deltaTime: number) -> ())`

Registers a RunService.Heartbeat callback with auto-disconnect on unmount.

```lua
Rivue.onHeartbeat(function(dt)
    -- Update physics or game logic every frame (after physics)
end)
```

#### `onStepped(callback: (time: number, deltaTime: number) -> ())`

Registers a RunService.Stepped callback with auto-disconnect on unmount.

```lua
Rivue.onStepped(function(time, dt)
    -- Physics step callback
end)
```

**Note:** All Roblox utilities must be called during component `setup()` for proper auto-cleanup.

---

### Error Boundaries & Suspense

Handle component errors gracefully.

```lua
local ErrorBoundary = defineComponent({
    setup = function(props, context)
        return function()
            return h("Frame", {
                fallback = h("TextLabel", { Text = "Error occurred!" })
            }, context.slots)
        end
    end
})
```

---

### Async Components

```lua
local AsyncComponent = defineComponent({
    setup = function()
        return function()
            return {
                __async = true,
                promise = function()
                    task.wait(2)
                    return h("TextLabel", { Text = "Loaded!" })
                end
            }
        end
    end
})

-- With fallback
h(AsyncComponent, {
    fallback = h("TextLabel", { Text = "Loading..." })
})
```

---

## Performance Tips

1. **Use `usePool: true`** in createApp for dynamic UIs
2. **Add `key` props** to list items for efficient updates
3. **Use `shallowReactive`** for large objects when deep tracking isn't needed
4. **Use `markRaw`** for non-reactive data (Instances, large datasets)
5. **Debounce/throttle** frequent updates (scroll, resize, input)
6. **Use `computed`** instead of recalculating in render
7. **Clean up in `onUnmounted`** (connections, effects, watchers)

---

## Type Definitions Summary

```lua
-- Reactivity
type Ref<T> = { value: T, _is_ref: true }
type ComputedRef<T> = { value: T, get: () -> T }
type Effect = { run: () -> (), stop: () -> (), active: boolean }
type WatchStopHandle = () -> ()

-- VNode
type VNode = {
    type: string | table | function,
    props: { [string]: any }?,
    children: { VNode | string }?,
    key: any?,
    el: Instance?
}

-- Component
type ComponentDefinition = {
    setup: ((props: table, ctx: ComponentContext) -> (() -> VNode))?,
    render: ((props: table) -> VNode)?,
    props: PropSchema?,
    __is_component: true,
    __name: string?
}

type ComponentContext = {
    emit: (eventName: string, ...any) -> (),
    provide: (key: any, value: any) -> (),
    inject: (key: any, default: any?) -> any,
    slots: { VNode },
    onUnmounted: (fn: () -> ()) -> ()
}

-- App
type App = {
    mount: (container: Instance) -> (),
    unmount: () -> (),
    rerender: (newRoot: VNode?) -> (),
    swapRoot: (newRoot: VNode) -> (),
    mountToPlayerGui: (player: Player) -> ()
}
```

---

## Examples

See the `App.luau` file for a comprehensive example demonstrating:

- Component definition
- Reactive state management
- Event handling
- List rendering with keys
- Form inputs
- Lifecycle hooks

---

## License & Credits

This Rivue is inspired by Vue.js 3's Composition API and adapted for Roblox/Luau.
