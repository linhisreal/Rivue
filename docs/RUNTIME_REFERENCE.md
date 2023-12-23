# Runtime Modules Reference

Complete Luau syntax reference for all Rivue runtime modules.

## Table of Contents

- [reactivity.luau](#reactivityluau)
- [h.luau](#hluau)
- [component.luau](#componentluau)
- [renderer.luau](#rendererluau)
- [directives.luau](#directivesluau)
- [scheduler.luau](#schedulerluau)
- [pool.luau](#poolluau)
- [utils.luau](#utilsluau)
- [remote.luau](#remoteluau)
- [main.luau](#mainluau)

---

## reactivity.luau

Reactive state management system with dependency tracking.

### Module Exports

```lua
return {
	-- Core Reactivity
	reactive: (target: table) -> table,
	readonly: (target: table) -> table,
	
	-- Shallow Variants
	shallowReactive: (target: table) -> table,
	shallowReadonly: (target: table) -> table,
	
	-- Refs
	ref: <T>(initial: T) -> Ref<T>,
	shallowRef: <T>(initial: T) -> Ref<T>,
	triggerRef: (r: Ref<any>) -> (),
	customRef: <T>(factory: RefFactory<T>) -> Ref<T>,
	
	-- Type Checking
	isRef: (value: any) -> boolean,
	isReactive: (value: any) -> boolean,
	isReadonly: (value: any) -> boolean,
	isProxy: (value: any) -> boolean,
	
	-- Conversion Utilities
	unref: <T>(value: T | Ref<T>) -> T,
	toRef: (obj: table, key: string) -> Ref<any>,
	toRefs: (obj: table) -> { [string]: Ref<any> },
	toValue: <T>(value: T | Ref<T> | (() -> T)) -> T,
	toRaw: (obj: table) -> table,
	markRaw: (obj: table) -> table,
	
	-- Computed
	computed: <T>(getter: () -> T) -> ComputedRef<T>,
	
	-- Watchers
	watch: (source: WatchSource, cb: WatchCallback, opts: WatchOptions?) -> WatchStopHandle,
	watchEffect: (fn: () -> (), opts: WatchOptions?) -> WatchStopHandle,
	
	-- Effects
	effect: (fn: () -> (), opts: EffectOptions?) -> Effect,
	
	-- Effect Scopes
	effectScope: (detached: boolean?) -> EffectScope,
	getCurrentScope: () -> EffectScope?,
	onScopeDispose: (fn: () -> (), failSilently: boolean?) -> ()
}
```
### Type Definitions

```lua
-- Ref type
type Ref<T> = {
    value: T,
    _is_ref: true
}

-- Computed ref type
type ComputedRef<T> = {
    value: T, -- Read-only
    get: () -> T
}

-- Effect type
type Effect = {
    fn: () -> (),
    scheduler: ((fn: () -> ()) -> ())?,
    deps: { any },
    active: boolean,
    run: (...any) -> any,
    stop: (self: Effect) -> ()
}

type EffectOptions = {
    lazy: boolean?,
    scheduler: ((fn: () -> ()) -> ())?
}

-- Watch types
type WatchSource = (() -> any) | Ref<any>

type WatchCallback = (
    newValue: any,
    oldValue: any,
    onCleanup: (fn: () -> ()) -> ()
) -> ()

type WatchOptions = {
    immediate: boolean?,
    deep: boolean?
}

type WatchStopHandle = () -> ()
```

### Function Signatures

#### `ref<T>(initial: T): Ref<T>`

```lua
function ref(initial: any): Ref<any>
```

Creates a mutable ref object with `.value` property.

**Example:**
```lua
local count = ref(0)
count.value = 10
```

---

#### `reactive(target: table): table`

```lua
function reactive(target: table): table
```

Creates a deeply reactive proxy. All nested objects become reactive automatically.

**Implementation notes:**
- Uses weak-key `depMap` for tracking
- Creates `__index`, `__newindex`, `__pairs` metamethods
- Caches proxies to avoid duplicate wrapping
- Respects `markRaw` objects

**Example:**
```lua
local state = reactive({ count: 0, nested: { value: 5 } })
state.count = 10 -- Triggers updates
state.nested.value = 20 -- Also triggers (deep)
```

---

#### `shallowReactive(target: table): table`

```lua
function shallowReactive(target: table): table
```

Creates a shallow reactive proxy. Only top-level properties are reactive.

**Example:**
```lua
local state = shallowReactive({ count: 0, obj: { x: 1 } })
state.count = 5 -- Reactive
state.obj.x = 2 -- NOT reactive
state.obj = {} -- Reactive (replacing whole object)
```

---

#### `computed<T>(getter: () -> T): ComputedRef<T>`

```lua
function computed(getter: () -> any): ComputedRef<any>
```

Creates a computed value that caches results and only re-computes when dependencies change.

**Implementation:**
- Uses `dirty` flag for cache invalidation
- Lazy evaluation via `lazy: true` effect
- Tracks dependencies via activeEffect

**Example:**
```lua
local count = ref(5)
local doubled = computed(function()
    return count.value * 2
end)
print(doubled.value) -- 10 (computed once)
print(doubled.value) -- 10 (cached)
count.value = 10
print(doubled.value) -- 20 (re-computed)
```

---

#### `watch(source, callback, options?): () -> ()`

```lua
function watch(
    source: (() -> any) | Ref<any>,
    cb: (newValue: any, oldValue: any, onCleanup: (fn: () -> ()) -> ()) -> (),
    opts: { immediate: boolean?, deep: boolean? }?
): () -> ()
```

Watches a reactive source and runs callback on changes.

**Parameters:**
- `source`: Function that returns a value, or a Ref
- `cb`: Callback receiving (newVal, oldVal, onCleanup)
- `opts.immediate`: Run callback immediately
- `opts.deep`: Deep traverse the result to track nested properties

**Returns:** Stop function to cancel watching

**Example:**
```lua
local count = ref(0)
local stop = watch(
    function() return count.value end,
    function(newVal, oldVal, onCleanup)
        print("Changed from", oldVal, "to", newVal)
        
        onCleanup(function()
            -- Cleanup before next run
        end)
    end,
    { immediate = true }
)

-- Stop watching
stop()
```

---

#### `effect(fn, options?): Effect`

```lua
function effect(
    fn: () -> (),
    opts: { lazy: boolean?, scheduler: ((fn: () -> ()) -> ())? }?
): Effect
```

Creates an effect that automatically tracks dependencies and re-runs.

**Example:**
```lua
local count = ref(0)
local eff = effect(function()
    print("Count is:", count.value)
end)

count.value = 5 -- Re-runs effect
eff:stop() -- Stop effect
```

---

#### `toRef(object: table, key: string): Ref<any>`

```lua
function toRef(obj: table, key: string): Ref<any>
```

Creates a ref linked to a property of a reactive object.

**Example:**
```lua
local state = reactive({ count: 0 })
local countRef = toRef(state, "count")
countRef.value = 10
print(state.count) -- 10
```

---

#### `toRefs(object: table): { [string]: Ref<any> }`

```lua
function toRefs(obj: table): { [string]: Ref<any> }
```

Converts all properties of an object to refs.

**Example:**
```lua
local state = reactive({ a: 1, b: 2 })
local refs = toRefs(state)
refs.a.value = 10
```

---

#### `isRef(value: any): boolean`

```lua
function isRef(r: any): boolean
```

Checks if a value is a ref.

---

#### `unref<T>(value: T | Ref<T>): T`

```lua
function unref(r: any): any
```

Returns the inner value if ref, otherwise returns value as-is.

---

#### `markRaw(object: table): table`

```lua
function markRaw(obj: table): table
```

Marks an object to prevent it from becoming reactive.

---

#### `toRaw(proxy: table): table`

```lua
function toRaw(obj: table): table
```

Returns the raw object (passthrough in current implementation).

---

### Iterating Reactive Arrays

**Important:** Use numeric iteration instead of `ipairs()` for reactive arrays.

#### Why `ipairs()` Doesn't Work

Luau's `ipairs()` performs a preliminary check for `table[1]` existence **before** invoking the `__ipairs` metamethod. Since reactive proxies are empty tables with all data stored in a separate internal table (accessed via `__index`), this check fails and iteration terminates immediately.

**Technical explanation:** The proxy table structure separates the proxy (empty `{}`) from the actual data (stored in `tbl`). While `proxy[1]` triggers `__index` to return `tbl[1]`, the raw `table[1]` check in `ipairs()` sees the empty proxy table and returns before `__ipairs` can be called.

#### ✅ Correct Pattern: Numeric Iteration

```lua
local items = reactive({ "apple", "banana", "cherry" })

-- ✅ CORRECT: Use numeric iteration
for i = 1, #items do
    print(i, items[i])
end
```

**Why this works:**
- `#items` triggers the `__len` metamethod → tracks dependency on array length
- `items[i]` triggers the `__index` metamethod → tracks dependency on each element
- Full reactivity tracking maintained
- Standard Lua pattern (not Rivue-specific)

#### ❌ Incorrect Pattern: Using `ipairs()`

```lua
local items = reactive({ "apple", "banana", "cherry" })

-- ❌ WRONG: Will not iterate (empty loop)
for i, v in ipairs(items) do
    print(i, v)  -- Never executes!
end
```

**Why this fails:** `ipairs()` checks if `table[1]` exists in the raw proxy table before calling `__ipairs`. Since the proxy is empty, iteration stops immediately.

#### Alternative: Rivue Helper

For `ipairs`-like syntax, use `Rivue.iterArray()`:

```lua
local items = reactive({ "apple", "banana", "cherry" })

-- Alternative: Rivue helper with ipairs-like syntax
for i, v in Rivue.iterArray(items) do
    print(i, v)
end
```

**Benefits:**
- Familiar `ipairs`-like syntax
- Full reactivity tracking via `__len` and `__index`
- Works with both reactive and non-reactive arrays

#### Comparison with Vue 3

This pattern aligns with Vue 3's Proxy-based reactivity:
- Vue 3 uses JavaScript Proxies, which have similar iteration considerations
- Modern reactive Rivues accept that proxies require different iteration patterns
- The numeric iteration pattern is the industry-standard approach for proxy-based reactivity

#### Performance Notes

**Numeric iteration is actually optimal:**
- Single `__len` call to get array length
- Individual `__index` calls for each element (same as `ipairs`)
- No overhead compared to native iteration
- Enables precise dependency tracking per element

---

#### `shallowRef<T>(initial: T): Ref<T>`

```lua
function shallowRef(initial: any): Ref<any>
```

Creates a ref that tracks its own `.value` replacement but does not make the value itself reactive.

**Implementation details:**
- Creates a regular ref with `shallowRefMarker[ref] = true`
- `.value` assignment triggers reactivity
- Nested object properties do **not** trigger reactivity
- Ideal for large objects, arrays, or external data structures

**Example:**
```lua
local bigArray = shallowRef({ item1 = {}, item2 = {}, ... }) -- 1000+ items

-- Triggers reactivity
bigArray.value = newArray

-- Does NOT trigger reactivity automatically
bigArray.value[1].property = "changed"

-- Manual trigger needed
triggerRef(bigArray)
```

**Use cases:**
- Large datasets (1000+ items)
- Integration with external APIs
- Performance-critical reactive containers
- Manual update control

---

#### `isReactive(value: any): boolean`

```lua
function isReactive(value: any): boolean
```

Checks if a value is a reactive proxy created by `reactive()` or `shallowReactive()`.

**Implementation:**
```lua
return reactiveMarker[value] ~= nil
```

**Performance:** O(1) weak-table lookup

**Returns:**
- `true`: Value is a reactive proxy
- `false`: Value is not reactive (plain table, ref, readonly proxy, marked raw, etc.)

**Example:**
```lua
local obj = reactive({ count: 0 })
print(isReactive(obj)) -- true
print(isReactive({ x: 1 })) -- false
print(isReactive(readonly(obj))) -- false (readonly, not reactive)
```

**Use cases:**
- Type guards in utility functions
- Conditional logic based on reactivity
- Debugging reactive state
- Library/Rivue code that needs to handle mixed types

---

#### `isReadonly(value: any): boolean`

```lua
function isReadonly(value: any): boolean
```

Checks if a value is a readonly proxy created by `readonly()`.

**Implementation:**
```lua
return readonlyMarker[value] == true
```

**Performance:** O(1) weak-table lookup

**Returns:**
- `true`: Value is a readonly proxy
- `false`: Value is not readonly

**Example:**
```lua
local source = reactive({ count: 0 })
local ro = readonly(source)

print(isReadonly(ro)) -- true
print(isReadonly(source)) -- false
print(isReadonly({ x: 1 })) -- false
```

**Use cases:**
- Enforcing mutation restrictions
- Validating prop types
- Configuration immutability checks
- Component boundary validation

---

#### `isProxy(value: any): boolean`

```lua
function isProxy(value: any): boolean
```

Checks if a value is **any** kind of reactive proxy (reactive or readonly).

**Implementation:**
```lua
return isReactive(value) or isReadonly(value)
```

**Returns:**
- `true`: Value is either reactive or readonly
- `false`: Value is a plain object, ref, or marked raw

**Example:**
```lua
local reactiveObj = reactive({ a: 1 })
local readonlyObj = readonly({ b: 2 })
local plainObj = { c: 3 }

print(isProxy(reactiveObj)) -- true
print(isProxy(readonlyObj)) -- true
print(isProxy(plainObj)) -- false
```

**Use cases:**
- Optimization: skip processing for non-proxies
- Type checking: "is this managed by reactivity system?"
- Deep cloning: avoid recursive proxy wrapping
- Serialization: detect proxies before JSON encoding

**Optimization pattern:**
```lua
function deepClone(obj)
    if isProxy(obj) then
        -- Use toRaw to get original before cloning
        obj = toRaw(obj)
    end
    
    -- ... normal clone logic
end
```

---

#### `markRaw<T>(object: table): T`

```lua
function markRaw(obj: table): table
```

Marks an object to **permanently** prevent it from becoming reactive. Returns the same object.

**Implementation:**
```lua
-- Validation
if typeof(obj) ~= "table" then
    error("markRaw expects a table")
end

-- Mark
rawMarker[obj] = true
return obj
```

**Memory safety:** `rawMarker` is a weak-key table: `{ __mode = "k" }`

**Behavior:**
- Stores `rawMarker[obj] = true` in a weak-key metatable
- `reactive()` / `shallowReactive()` / `readonly()` all check `rawMarker` and return the object unchanged
- Marking is **permanent** for the object's lifetime
- GC-safe: marker entry is removed when object is collected

**Example:**
```lua
local instance = workspace.Part
markRaw(instance) -- Permanently prevent reactivity

local state = reactive({
    myPart = instance -- Stored as-is, not wrapped
})

print(isReactive(state.myPart)) -- false
state.myPart.Position = Vector3.new(0, 10, 0) -- Direct access, no reactivity
```

**Roblox-specific use cases:**
- **Instances:** Prevent Roblox Instances from being proxied
- **Large datasets:** Mark static lookup tables (10,000+ items)
- **CollectionService:** Store tagged parts without reactivity overhead
- **Third-party objects:** Objects from plugins or external modules

**Performance impact:**
```lua
-- Without markRaw: Creates 10,000 reactive proxies
local items = reactive({})
for i = 1, 10000 do
    items[i] = { id = i, data = "..." } -- Each item becomes reactive
end

-- With markRaw: Stores 10,000 plain objects
local items = reactive({})
for i = 1, 10000 do
    items[i] = markRaw({ id = i, data = "..." }) -- No proxy overhead
end
```

**Memory savings:** Avoids metatable and dependency tracking overhead per object.

---

#### `toRaw<T>(proxy: table): T`

```lua
function toRaw(obj: any): any
```

Returns the original object from a reactive/readonly proxy. If not a proxy, returns the value unchanged.

**Implementation:**
```lua
local raw = reactiveMarker[obj]
return if raw then raw else obj
```

**Memory safety:** `reactiveMarker` is a weak-key table: `{ __mode = "k" }`

**Storage mechanism:**
```lua
-- When creating a reactive proxy:
function reactive(tbl)
    local proxy = setmetatable({}, proxyMetatable)
    reactiveMarker[proxy] = tbl -- Store original
    return proxy
end

-- When retrieving original:
function toRaw(proxy)
    local original = reactiveMarker[proxy]
    return original ~= nil and original or proxy
end
```

**Use cases:**
1. **DataStore serialization:** Proxies aren't serializable
```lua
local state = reactive({ coins = 100, level = 5 })
local dataToSave = toRaw(state) -- Get plain table
DataStoreService:SetAsync("player_123", dataToSave)
```

2. **Identity comparison:** `==` compares by reference
```lua
local original = { x = 1 }
local proxied = reactive(original)

print(proxied == original) -- false (different tables)
print(toRaw(proxied) == original) -- true
```

3. **Bulk updates bypassing reactivity:**
```lua
local items = reactive({ item1, item2, item3 })
local raw = toRaw(items)

-- Update 1000 items without triggering reactivity each time
for i = 1, 1000 do
    raw[i] = newValue
end

-- Manually trigger once
trigger(items, "length") -- Or use triggerRef if it's a shallowRef
```

4. **External API integration:**
```lua
-- Some APIs expect plain objects
local data = reactive({ config = { ... } })
externalLibrary.process(toRaw(data.config)) -- Pass plain object
```

**Performance:** O(1) table lookup

---

#### `triggerRef(ref: Ref<any>)`

```lua
function triggerRef(r: Ref<any>): ()
```

Manually triggers reactivity for a `shallowRef` without changing its value.

**Implementation:**
```lua
if r and r._is_ref then
    trigger(r, "value")
end
```

**Use cases:**
1. **Batch mutations on large objects:**
```lua
local bigData = shallowRef({ items = {} })

-- Add 1000 items without triggering each time
for i = 1, 1000 do
    table.insert(bigData.value.items, newItem)
end

-- Trigger once after all changes
triggerRef(bigData)
```

2. **External state synchronization:**
```lua
local instances = shallowRef({})

-- CollectionService updates external state
CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(part)
    table.insert(instances.value, part)
    triggerRef(instances) -- Notify watchers
end)
```

3. **Manual cache invalidation:**
```lua
local cache = shallowRef({ data = loadExpensiveData() })

-- Invalidate cache without replacing object
function refreshCache()
    cache.value.data = loadExpensiveData()
    triggerRef(cache) -- Trigger update
end
```

**Performance:** Same as any reactive trigger (notifies dependent effects)

**Comparison:**
```lua
-- Regular ref: Automatic trigger
local count = ref(0)
count.value = count.value + 1 -- Auto-triggers

-- ShallowRef: Manual trigger
local obj = shallowRef({ count = 0 })
obj.value.count = obj.value.count + 1 -- No auto-trigger
triggerRef(obj) -- Manual trigger required
```

---

#### `customRef<T>(factory: RefFactory<T>): Ref<T>`

```lua
function customRef<T>(factory: (track: () -> (), trigger: () -> ()) -> RefAccessors<T>): Ref<T>
```

Creates a custom ref with full control over dependency tracking and triggering.

**Type definitions:**
```lua
type RefFactory<T> = (
    track: () -> (), -- Call to track dependency
    trigger: () -> () -- Call to trigger updates
) -> RefAccessors<T>

type RefAccessors<T> = {
    get: () -> T, -- Called when .value is read
    set: (newValue: T) -> () -- Called when .value is assigned
}
```

**Implementation details:**
```lua
function customRef(factory)
    local ref = { _is_ref = true }
    local deps = {}
    
    -- Factory-controlled track/trigger
    local accessors = factory(
        function() -- track
            if activeEffect then
                table.insert(deps, activeEffect)
            end
        end,
        function() -- trigger
            for _, effect in deps do
                queueJob(effect.run)
            end
        end
    )
    
    -- Metatable intercepts .value access
    setmetatable(ref, {
        __index = function(_, key)
            if key == "value" then
                return accessors.get() -- Factory controls read
            end
        end,
        __newindex = function(_, key, val)
            if key == "value" then
                accessors.set(val) -- Factory controls write
            end
        end
    })
    
    return ref
end
```

**Factory pattern examples:**

**1. Debounced ref:**
```lua
function debouncedRef(value, delay)
    local timer = nil
    local actualValue = value
    
    return customRef(function(track, trigger)
        return {
            get = function()
                track() -- Track dependency
                return actualValue
            end,
            set = function(newValue)
                actualValue = newValue
                
                -- Debounce trigger
                if timer then
                    task.cancel(timer)
                end
                timer = task.delay(delay, function()
                    trigger() -- Notify watchers after delay
                end)
            end
        }
    end)
end

-- Usage
local search = debouncedRef("", 0.3)
search.value = "a" -- No immediate trigger
search.value = "ab" -- Cancels previous
search.value = "abc" -- Triggers after 300ms
```

**2. Validation ref:**
```lua
function validatedRef(initial, validator)
    local value = initial
    
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
                    warn("Validation failed:", newValue)
                end
            end
        }
    end)
end

-- Usage
local age = validatedRef(0, function(val)
    return val >= 0 and val <= 120
end)
age.value = 150 -- Warns, not updated
age.value = 25 -- Valid, triggers
```

**3. DataStore-synced ref:**
```lua
function datastoreRef(key, defaultValue)
    local value = DataStoreService:GetAsync(key) or defaultValue
    
    return customRef(function(track, trigger)
        return {
            get = function()
                track()
                return value
            end,
            set = function(newValue)
                value = newValue
                trigger()
                
                -- Async save to DataStore
                task.spawn(function()
                    DataStoreService:SetAsync(key, value)
                end)
            end
        }
    end)
end
```

**Use cases:**
- **Debouncing/throttling:** Rate-limit reactive updates
- **Validation:** Enforce constraints before updating
- **Lazy evaluation:** Defer expensive computations
- **External sync:** Auto-save to DataStore, sync with remote state
- **Custom computed logic:** Transform values on read/write
- **Undo/redo:** Track history on every set

**Performance:** Same as regular refs, with additional factory overhead.

---

#### `effectScope(detached?: boolean): EffectScope`

```lua
function effectScope(detached: boolean?): EffectScope
```

Creates a scope for managing effects and nested scopes, enabling batch cleanup.

**Type definition:**
```lua
type EffectScope = {
    effects: { Effect }, -- Registered effects
    scopes: { EffectScope }, -- Child scopes
    parent: EffectScope?, -- Parent scope (if not detached)
    active: boolean, -- Is scope active?
    
    run: <T>(self: EffectScope, fn: () -> T) -> T, -- Execute function in scope context
    stop: (self: EffectScope) -> () -- Stop all effects and child scopes
}
```

**Implementation:**
```lua
local activeScope: EffectScope? = nil

function effectScope(detached: boolean?): EffectScope
    local scope: EffectScope = {
        effects = {},
        scopes = {},
        parent = if detached then nil else activeScope,
        active = true
    }
    
    -- Register with parent scope
    if scope.parent then
        table.insert(scope.parent.scopes, scope)
    end
    
    function scope:run(fn)
        local prevScope = activeScope
        activeScope = self
        local success, result = pcall(fn)
        activeScope = prevScope
        
        if not success then
            error(result)
        end
        return result
    end
    
    function scope:stop()
        if not self.active then
            return
        end
        
        -- Stop all child scopes recursively
        for _, childScope in self.scopes do
            childScope:stop()
        end
        
        -- Stop all effects
        for _, effect in self.effects do
            if effect.active then
                effect:stop()
            end
        end
        
        self.active = false
    end
    
    return scope
end
```

**Automatic effect registration:**
```lua
function createEffect(fn, opts)
    local effect = {
        fn = fn,
        active = true,
        -- ... other effect properties
    }
    
    -- Auto-register with active scope
    if activeScope then
        table.insert(activeScope.effects, effect)
    end
    
    return effect
end
```

**Lifecycle flow:**
1. **Creation:** `effectScope()` creates a new scope
2. **Activation:** `scope:run(fn)` sets `activeScope = scope`
3. **Effect registration:** Effects created inside `run()` are auto-added to `scope.effects`
4. **Cleanup:** `scope:stop()` recursively stops all effects and child scopes
5. **Deactivation:** `scope.active = false`

**Hierarchy example:**
```lua
local parentScope = effectScope()

parentScope:run(function()
    effect(function() print("Parent effect") end)
    
    local childScope = effectScope()
    childScope:run(function()
        effect(function() print("Child effect") end)
    end)
end)

-- Stops both parent and child effects
parentScope:stop()
```

**Detached scopes:**
```lua
local detachedScope = effectScope(true) -- Not attached to active scope

detachedScope:run(function()
    effect(function() print("Independent effect") end)
end)

-- Must be stopped manually (not affected by parent scopes)
detachedScope:stop()
```

**Use cases:**
- **Plugin systems:** Start/stop entire plugin with one call
- **Feature flags:** Enable/disable features with batch cleanup
- **Dynamic modules:** Load/unload modules with automatic resource cleanup
- **Testing:** Isolate test effects from global state
- **Service managers:** Lifecycle management for service groups

**Roblox example - Service manager:**
```lua
local serviceScope = effectScope()

function startServices()
    serviceScope:run(function()
        -- All effects auto-registered to serviceScope
        effect(function()
            -- Monitor player count
            print("Players:", #Players:GetPlayers())
        end)
        
        effect(function()
            -- Update leaderboard
            updateLeaderboard()
        end)
        
        effect(function()
            -- Sync game state
            syncGameState()
        end)
    end)
end

function stopServices()
    serviceScope:stop() -- Stops all 3 effects at once
end
```

**Memory management:** Scopes are GC'd when no references remain and they're stopped.

---

#### `getCurrentScope(): EffectScope?`

```lua
function getCurrentScope(): EffectScope?
```

Returns the currently active effect scope, or `nil` if not inside a scope.

**Implementation:**
```lua
local activeScope: EffectScope? = nil

function getCurrentScope(): EffectScope?
    return activeScope
end
```

**Returns:**
- `EffectScope`: Currently active scope
- `nil`: No active scope (not inside `scope:run()`)

**Use cases:**
1. **Conditional registration:**
```lua
function watchIfScoped(source, callback)
    if getCurrentScope() then
        -- Inside a scope, register with it
        return watch(source, callback)
    else
        -- No scope, create standalone watcher
        return watch(source, callback)
    end
end
```

2. **Scope-aware utilities:**
```lua
function createManagedConnection(signal, handler)
    local conn = signal:Connect(handler)
    
    -- Auto-cleanup if inside a scope
    local scope = getCurrentScope()
    if scope then
        onScopeDispose(function()
            conn:Disconnect()
        end)
    end
    
    return conn
end
```

3. **Debugging:**
```lua
function logScopeContext(message)
    local scope = getCurrentScope()
    if scope then
        print("[Scope]", message, "Effects:", #scope.effects)
    else
        print("[No Scope]", message)
    end
end
```

**Performance:** O(1) - returns a module-level variable

---

#### `onScopeDispose(fn: () -> (), failSilently?: boolean)`

```lua
function onScopeDispose(fn: () -> (), failSilently: boolean?): ()
```

Registers a cleanup callback to run when the current scope stops.

**Implementation:**
```lua
function onScopeDispose(fn: () -> (), failSilently: boolean?): ()
    local scope = getCurrentScope()
    
    if not scope then
        if failSilently then
            return
        end
        error("onScopeDispose called outside of an active scope")
    end
    
    -- Create a cleanup effect
    local cleanupEffect = {
        fn = fn,
        active = true,
        stop = function(self)
            if self.active then
                self.fn()
                self.active = false
            end
        end
    }
    
    table.insert(scope.effects, cleanupEffect)
end
```

**Parameters:**
- `fn`: Cleanup function to execute when scope stops
- `failSilently`: If `true`, silently returns if no active scope (useful for libraries)

**Execution order:**
- Cleanup callbacks execute in **registration order** when `scope:stop()` is called
- All callbacks run before the scope is marked inactive

**Example:**
```lua
local scope = effectScope()

scope:run(function()
    local part = Instance.new("Part")
    part.Parent = workspace
    
    -- Register cleanup
    onScopeDispose(function()
        part:Destroy()
        print("Part destroyed")
    end)
    
    local conn = RunService.Heartbeat:Connect(function()
        part.CFrame = part.CFrame * CFrame.Angles(0, 0.01, 0)
    end)
    
    onScopeDispose(function()
        conn:Disconnect()
        print("Connection disconnected")
    end)
end)

-- Later: cleanup everything
scope:stop()
-- Output:
-- Part destroyed
-- Connection disconnected
```

**Use cases:**
- **Resource cleanup:** Destroy Instances, disconnect connections
- **State restoration:** Reset global state before scope exit
- **Logging/metrics:** Record scope lifetime
- **Async cancellation:** Cancel ongoing promises/requests

**Multiple callbacks:**
```lua
scope:run(function()
    onScopeDispose(function() print("First cleanup") end)
    onScopeDispose(function() print("Second cleanup") end)
    onScopeDispose(function() print("Third cleanup") end)
end)

scope:stop()
-- Output (in order):
-- First cleanup
-- Second cleanup
-- Third cleanup
```

**Fail silently for libraries:**
```lua
-- Library code that may or may not be in a scope
function createReactiveResource()
    local resource = {}
    
    -- Cleanup only if inside a scope
    onScopeDispose(function()
        resource:cleanup()
    end, true) -- Won't error if no scope
    
    return resource
end
```

**Comparison with component lifecycle:**
- **`onScopeDispose`:** Generic scope cleanup (any scope)
- **`onUnmounted`:** Component-specific cleanup (component scope only)
- **`onMounted`:** Component-specific initialization (no scope equivalent)

**Performance:** O(1) - inserts callback into scope's effects array

---

### Advanced Patterns and Implementation Details

#### Marker System Architecture

The reactivity system uses **four** weak-key marker tables for type tracking:

```lua
local reactiveMarker = setmetatable({}, { __mode = "k" })
local readonlyMarker = setmetatable({}, { __mode = "k" })
local rawMarker = setmetatable({}, { __mode = "k" })
local shallowRefMarker = setmetatable({}, { __mode = "k" })
```

**Memory management:**
- Weak-key tables (`{ __mode = "k" }`) allow garbage collection of marked objects
- Entries are automatically removed when the key (proxy or object) is collected
- Prevents memory leaks from abandoned reactive state

**Marker usage:**
1. **`reactiveMarker[proxy] = originalTable`**
   - Stores reference to original table
   - Used by `toRaw()` to retrieve original
   - Used by `isReactive()` to check reactivity

2. **`readonlyMarker[proxy] = true`**
   - Marks readonly proxies
   - Used by `isReadonly()` to check readonly status

3. **`rawMarker[obj] = true`**
   - Permanently prevents object from becoming reactive
   - Checked by `reactive()`, `shallowReactive()`, `readonly()`
   - Used by `markRaw()` to mark objects

4. **`shallowRefMarker[ref] = true`**
   - Marks refs created by `shallowRef()`
   - Used internally to prevent deep reactivity on `.value`

**Lifecycle:**
```lua
-- Creation
local obj = { x = 1 }
local proxy = reactive(obj)
-- reactiveMarker[proxy] = obj

-- Usage
local original = toRaw(proxy) -- Retrieves obj from reactiveMarker
local isRx = isReactive(proxy) -- Checks reactiveMarker[proxy] ~= nil

-- Garbage collection
proxy = nil
obj = nil
-- GC collects both, reactiveMarker entry is automatically removed
```

---

#### Effect Scope Lifecycle and Cascade Cleanup

**Scope creation hierarchy:**
```lua
local rootScope = effectScope() -- Parent

rootScope:run(function()
    effect(function() print("Root effect") end)
    
    local childScope = effectScope() -- Child of rootScope
    childScope:run(function()
        effect(function() print("Child effect") end)
        
        local grandchildScope = effectScope() -- Child of childScope
        grandchildScope:run(function()
            effect(function() print("Grandchild effect") end)
        end)
    end)
end)
```

**Cascade stop algorithm:**
```lua
function EffectScope:stop()
    if not self.active then
        return -- Already stopped
    end
    
    -- 1. Stop all child scopes recursively (depth-first)
    for _, childScope in self.scopes do
        childScope:stop()
    end
    
    -- 2. Stop all effects in this scope
    for _, effect in self.effects do
        if effect.active then
            effect:stop()
        end
    end
    
    -- 3. Mark scope inactive
    self.active = false
end
```

**Execution order:**
```
rootScope:stop()
  ├─ childScope:stop()
  │   ├─ grandchildScope:stop()
  │   │   └─ Stop grandchild effects
  │   └─ Stop child effects
  └─ Stop root effects
```

**Effect registration:**
```lua
local activeScope: EffectScope? = nil

function createEffect(fn, opts)
    local effect = {
        fn = fn,
        active = true,
        -- ...
    }
    
    -- Auto-register with active scope
    if activeScope then
        table.insert(activeScope.effects, effect)
    end
    
    return effect
end
```

**Detached scope behavior:**
```lua
local detached = effectScope(true) -- detached = true

detached:run(function()
    -- Not attached to parent scope
    -- Must be manually stopped
end)
```

---

#### customRef Factory Pattern and Internals

**Factory contract:**
```lua
type RefFactory<T> = (track: () -> (), trigger: () -> ()) -> {
    get: () -> T,
    set: (newValue: T) -> ()
}
```

**Implementation:**
```lua
function customRef(factory)
    local ref = { _is_ref = true }
    local deps = {}
    
    local accessors = factory(
        function() -- track
            if activeEffect then
                table.insert(deps, activeEffect)
            end
        end,
        function() -- trigger
            for _, effect in deps do
                queueJob(effect.run)
            end
        end
    )
    
    setmetatable(ref, {
        __index = function(_, key)
            if key == "value" then
                return accessors.get()
            end
        end,
        __newindex = function(_, key, val)
            if key == "value" then
                accessors.set(val)
            end
        end
    })
    
    return ref
end
```

**Dependency tracking flow:**
```
1. Component reads ref.value
2. __index triggers accessors.get()
3. get() calls track()
4. track() adds activeEffect to deps
5. Later: ref.value = newValue
6. __newindex triggers accessors.set()
7. set() calls trigger()
8. trigger() schedules all deps to re-run
```

**Advanced factory - Readonly computed:**
```lua
function readonlyComputedRef(getter)
    return customRef(function(track, trigger)
        local value = nil
        local dirty = true
        
        return {
            get = function()
                track()
                if dirty then
                    value = getter()
                    dirty = false
                end
                return value
            end,
            set = function()
                error("Cannot assign to readonly computed ref")
            end
        }
    end)
end
```

---

#### toRaw/markRaw Identity Management

**Storage mechanism:**
```lua
-- When creating a reactive proxy
function reactive(tbl)
    -- Check if already marked raw
    if rawMarker[tbl] then
        return tbl -- Return as-is
    end
    
    local proxy = setmetatable({}, {
        __index = function(_, key)
            track(tbl, key)
            return tbl[key]
        end,
        __newindex = function(_, key, value)
            tbl[key] = value
            trigger(tbl, key)
        end
    })
    
    -- Store original for toRaw
    reactiveMarker[proxy] = tbl
    
    return proxy
end
```

**toRaw retrieval:**
```lua
function toRaw(obj)
    local original = reactiveMarker[obj]
    return original ~= nil and original or obj
end
```

**markRaw bypass:**
```lua
function markRaw(obj)
    if typeof(obj) ~= "table" then
        error("markRaw expects a table")
    end
    
    rawMarker[obj] = true
    return obj
end

-- Usage
local instance = workspace.Part
markRaw(instance)

local state = reactive({
    myPart = instance -- Not wrapped, stored as-is
})
```

**Identity comparison:**
```lua
local original = { x = 1 }
local proxy = reactive(original)

print(proxy == original) -- false (different references)
print(toRaw(proxy) == original) -- true (same reference)
```

---

#### Type Checking Implementation

**isReactive:**
```lua
function isReactive(value: any): boolean
    return reactiveMarker[value] ~= nil
end
```

**isReadonly:**
```lua
function isReadonly(value: any): boolean
    return readonlyMarker[value] == true
end
```

**isProxy:**
```lua
function isProxy(value: any): boolean
    return isReactive(value) or isReadonly(value)
end
```

**Performance:** All type checks are O(1) weak-table lookups.

---

#### Component Lifecycle Integration

**Automatic scope creation for components:**
```lua
function createComponentInstance(vnode, parent)
    local instance = {
        -- ... component properties
    }
    
    -- Create component scope
    local componentScope = effectScope()
    instance._scope = componentScope
    
    -- Run setup inside scope
    componentScope:run(function()
        instance:setupComponent()
    end)
    
    return instance
end
```

**Cleanup on unmount:**
```lua
function instance:runUnmounted()
    -- Stop component scope (cleans up all effects, watchers, etc.)
    if self._scope then
        self._scope:stop()
    end
    
    -- Run unmounted callbacks
    for _, cb in self.unmountedCbs do
        cb()
    end
end
```

**Integration with main.luau wrappers:**
```lua
-- Rivue.watch wrapper
function Rivue.watch(source, callback, options)
    local currentInstance = getCurrentInstance()
    
    local stopHandle = watch(source, callback, options)
    
    -- Auto-cleanup when component unmounts
    if currentInstance then
        table.insert(currentInstance._effects, { stop = stopHandle })
    end
    
    return stopHandle
end
```

---

#### Memory Management Considerations

**Weak-key tables and GC:**
```lua
-- Weak-key tables allow GC to collect marked objects
local marker = setmetatable({}, { __mode = "k" })

local obj = { x = 1 }
marker[obj] = "metadata"

obj = nil -- GC can collect obj
-- marker[obj] entry is automatically removed
```

**Large dataset handling:**
```lua
-- BAD: Deep reactivity on 10,000 items (slow)
local items = reactive({})
for i = 1, 10000 do
    items[i] = { id = i, data = "..." } -- Each item becomes reactive
end

-- GOOD: Shallow reactivity (fast)
local items = reactive({})
for i = 1, 10000 do
    items[i] = markRaw({ id = i, data = "..." }) -- Plain objects
end

-- BETTER: ShallowRef with manual trigger
local items = shallowRef({})
for i = 1, 10000 do
    table.insert(items.value, { id = i, data = "..." })
end
triggerRef(items) -- Single update after bulk insert
```

**Roblox Instance lifecycle:**
```lua
-- BAD: Reactive Instances cause memory leaks
local state = reactive({
    parts = {} -- Don't store Instances reactively
})

for _, part in workspace:GetDescendants() do
    table.insert(state.parts, part) -- Creates proxy for each Instance
end

-- GOOD: MarkRaw prevents proxy creation
local state = reactive({
    parts = {}
})

for _, part in workspace:GetDescendants() do
    table.insert(state.parts, markRaw(part)) -- Stores Instance as-is
end
```

**CollectionService integration:**
```lua
function useTaggedInstances(tag)
    local instances = shallowRef({})
    
    -- Store instances as markRaw
    local function refresh()
        instances.value = {}
        for _, inst in CollectionService:GetTagged(tag) do
            table.insert(instances.value, markRaw(inst))
        end
        triggerRef(instances)
    end
    
    refresh()
    
    local added = CollectionService:GetInstanceAddedSignal(tag):Connect(refresh)
    local removed = CollectionService:GetInstanceRemovedSignal(tag):Connect(refresh)
    
    onScopeDispose(function()
        added:Disconnect()
        removed:Disconnect()
    end)
    
    return instances
end
```

---

#### Performance Implications

**Shallow vs Deep reactivity:**
```lua
-- Deep reactivity (default)
local deep = reactive({ nested: { value: 1 } })
deep.nested.value = 2 -- Triggers update (nested object is also reactive)

-- Shallow reactivity
local shallow = shallowReactive({ nested: { value: 1 } })
shallow.nested.value = 2 -- No trigger (nested object is not reactive)
shallow.nested = { value: 2 } -- Triggers update (top-level change)
```

**Effect scope overhead:**
- **Per scope:** ~200 bytes (table + fields)
- **Per effect:** ~100-200 bytes (effect table + function closure)
- **Hierarchy:** Negligible (parent/child references)

**Batch cleanup benefits:**
```lua
-- Without scopes: Manual cleanup (error-prone)
local effects = {}
table.insert(effects, effect(fn1))
table.insert(effects, effect(fn2))
table.insert(effects, effect(fn3))
-- Must manually stop each

-- With scopes: Automatic batch cleanup
local scope = effectScope()
scope:run(function()
    effect(fn1)
    effect(fn2)
    effect(fn3)
end)
scope:stop() -- One call stops all
```

**Marker lookup performance:**
- All type checks: O(1) table lookup
- Weak-key overhead: Minimal (same as regular tables)
- GC impact: Automatic cleanup reduces manual memory management

**Recommended optimization patterns:**
1. Use `shallowRef` for large arrays/tables
2. Batch updates with `triggerRef`
3. Mark Roblox Instances with `markRaw`
4. Use `effectScope` for plugin-like features
5. Prefer `toRaw` for DataStore serialization

---

### Internal Implementation Details

#### Dependency Tracking

```lua
local depMap = setmetatable({}, { __mode = "k" }) -- Weak-key map
local effectStack = {}
local activeEffect = nil
```

- **depMap**: Maps `target -> key -> Set<Effect>`
- **effectStack**: Stack of currently running effects
- **activeEffect**: Currently executing effect

#### `track(target, key)`

Registers the active effect as dependent on `target[key]`.

```lua
function track(target: table, key: string): ()
```

#### `trigger(target, key)`

Notifies all effects that depend on `target[key]`.

```lua
function trigger(target: table, key: string): ()
```

---

## h.luau

Hyperscript function and helpers for creating VNodes.

### Module Exports

```lua
return {
    h: (type_: string | table | function, props: table?, children: any?) -> VNode,
    hIf: (cond: boolean, vnode: VNode?) -> VNode?,
    hFor: <T>(list: { T }, mapper: (item: T, index: number) -> VNode?) -> { VNode }
}
```

### Type Definitions

```lua
type VNode = {
    type: string | table | function,
    props: { [string]: any }?,
    children: { VNode | string | function },
    key: any?,
    _uid: {}
}
```

### Function Signatures

#### `h(type, props?, children?): VNode`

```lua
function h(
    type_: string | table | ((props: table) -> VNode),
    props: { [string]: any }?,
    children: string | number | table | function | { any }?
): VNode
```

Creates a virtual node.

**Parameters:**
- `type_`: Element class name, component definition, or functional component
- `props`: Properties/attributes for the element
- `children`: Child nodes (VNodes, strings, numbers, functions, or arrays)

**Returns:** VNode table

**Example:**
```lua
-- Element
h("Frame", {
    Size = UDim2.fromOffset(100, 100),
    BackgroundColor3 = Color3.fromRGB(255, 0, 0)
})

-- With children
h("Frame", { Size = UDim2.fromOffset(200, 200) }, {
    h("TextLabel", { Text = "Child 1" }),
    h("TextLabel", { Text = "Child 2" })
})

-- String child (auto-converted to TextLabel or set as Text)
h("Frame", {}, "Hello")

-- Number child
h("TextLabel", {}, 42) -- Converted to "42"

-- Function child (evaluated during render)
h("Frame", {}, function()
    return h("TextLabel", { Text = "Dynamic" })
end)

-- Component
h(MyComponent, { title = "Hello" })

-- Functional component
h(function(props)
    return h("TextLabel", { Text = props.message })
end, { message = "Hi" })
```

---

#### `hIf(condition: boolean, vnode: VNode?): VNode?`

```lua
function hIf(cond: boolean, vnode: VNode?): VNode?
```

Conditional rendering. Returns vnode if condition is true, nil otherwise.

**Example:**
```lua
hIf(showLabel, h("TextLabel", { Text = "Visible when true" }))
```

---

#### `hFor<T>(list: { T }, mapper: (item: T, index: number) -> VNode?): { VNode }`

```lua
function hFor<T>(
    list: { T },
    mapper: (item: T, index: number) -> VNode?
): { VNode }
```

List rendering. Maps each item to a VNode.

**Example:**
```lua
local items = { "Apple", "Banana", "Cherry" }

hFor(items, function(item, index)
    return h("TextLabel", {
        key = index,
        Text = item,
        LayoutOrder = index
    })
end)
```

---

### Internal Implementation

#### `normalizeChildren(children: any): { VNode | string | function }`

```lua
function nomalizeChildren(children: any): { any }
```

Normalizes children to an array format:
- `nil` → `{}`
- `string` or `number` → `{ tostring(children) }`
- `table` → `children`
- `function` → `{ children }`
- Other → `{ tostring(children) }`

---

## component.luau

Component instance lifecycle and management.

### Module Exports

```lua
return {
    createComponentInstance: (vnode: VNode, parent: ComponentInstance?) -> (ComponentInstance, ComponentContext),
    onBeforeMount: (fn: () -> ()) -> (),
    onMounted: (fn: () -> ()) -> (),
    onBeforeUpdate: (fn: () -> ()) -> (),
    onUpdated: (fn: () -> ()) -> (),
    onBeforeUnmount: (fn: () -> ()) -> (),
    onUnmounted: (fn: () -> ()) -> (),
    setCurrentInstance: (instance: ComponentInstance?) -> (),
    getCurrentInstance: () -> ComponentInstance?
}
```

### Type Definitions

```lua
type ComponentInstance = {
    vnode: VNode,
    type: ComponentDefinition,
    props: { [string]: any },
    attrs: { [string]: any },  -- Non-declared props
    exposed: { [string]: any }?,  -- Public API exposed via ctx.expose()
    parent: ComponentInstance?,
    provides: { [any]: any },
    isMounted: boolean,
    subTree: VNode?,
    el: Instance?,
    cleanupCbs: { () -> () },
    beforeMountCbs: { () -> () },
    mountedCbs: { () -> () },
    beforeUpdateCbs: { () -> () },
    updatedCbs: { () -> () },
    beforeUnmountCbs: { () -> () },
    unmountedCbs: { () -> () },
    slots: { VNode },
    pendingJobs: { any },
    render: (() -> VNode)?,
    setupState: any,
    
    setupComponent: (self: ComponentInstance) -> (),
    runBeforeMount: (self: ComponentInstance) -> (),
    runMounted: (self: ComponentInstance) -> (),
    runBeforeUpdate: (self: ComponentInstance) -> (),
    runUpdated: (self: ComponentInstance) -> (),
    runBeforeUnmount: (self: ComponentInstance) -> (),
    runUnmounted: (self: ComponentInstance) -> ()
}

type ComponentContext = {
    emit: (eventName: string, ...any) -> (),
    provide: (key: any, value: any) -> (),
    inject: (key: any, default: any?) -> any,
    attrs: { [string]: any },  -- Non-declared props
    expose: (exposed: { [string]: any }?) -> (),  -- Expose public API
    slots: { VNode },
    onUnmounted: (fn: () -> ()) -> ()
}

type PropSpec = {
    type: "string" | "number" | "boolean" | "table" | "function",
    required: boolean?,
    default: any?,  -- Default value (primitive or factory function)
    validator: ((value: any) -> boolean)?  -- Custom validation function
}

type PropSchema = { [string]: PropSpec }

type ComponentDefinition = {
    __is_component: true,
    setup: ((props: table, ctx: ComponentContext) -> (() -> VNode))?,
    render: ((props: table) -> VNode)?,
    props: PropSchema?,
    inheritAttrs: boolean?,  -- Whether to auto-apply attrs to root element
    __name: string?
}
```

### Function Signatures

#### `createComponentInstance(vnode: VNode, parent?: ComponentInstance): (ComponentInstance, ComponentContext)`

```lua
function createComponentInstance(
    vnode: VNode,
    parent: ComponentInstance?
): (ComponentInstance, ComponentContext)
```

Creates a component instance with lifecycle management.

**Returns:** `(instance, context)` tuple

**Instance Methods:**
- `setupComponent()`: Runs setup and initializes render function
- `runBeforeMount()`: Executes all beforeMount callbacks
- `runMounted()`: Executes all mounted callbacks
- `runBeforeUpdate()`: Executes all beforeUpdate callbacks
- `runUpdated()`: Executes all updated callbacks
- `runBeforeUnmount()`: Executes all beforeUnmount callbacks
- `runUnmounted()`: Executes all unmounted and cleanup callbacks

**Props and Attrs:**
- Props are validated and defaults applied during instance creation
- Non-declared props are separated into `attrs` for pass-through scenarios
- Access via `ctx.attrs` in setup function

**Attrs Example:**
```lua
-- Component definition with props schema
local MyComponent = {
    props = {
        title = { type = "string" },  -- Declared prop
        count = { type = "number" }   -- Declared prop
    },
    setup = function(props, ctx)
        -- props.title and props.count are declared props
        -- ctx.attrs contains any additional props passed by parent
        
        print(ctx.attrs.onClick)  -- Access non-declared prop
        print(ctx.attrs.customData)  -- Access non-declared prop
        
        return function()
            -- Can pass attrs to child elements
            return h("Frame", ctx.attrs)
        end
    end
}

-- Parent passes both declared and non-declared props:
-- h(MyComponent, {
--     title = "Hello",      -- Declared prop → goes to props.title
--     count = 5,            -- Declared prop → goes to props.count
--     onClick = handler,    -- Non-declared → goes to ctx.attrs.onClick
--     customData = "test"   -- Non-declared → goes to ctx.attrs.customData
-- })
```

**Attrs Use Cases:**
- Pass-through props to child elements
- Event handlers on component root
- Custom attributes for styling/behavior
- Flexible component APIs without strict prop schemas

**Inherit Attrs:**

By default, attrs are NOT automatically applied to the component's root element. To enable automatic application, set `inheritAttrs = true` in the component definition:

```lua
local MyComponent = {
    props = {
        title = { type = "string" }
    },
    inheritAttrs = true,  -- Auto-apply attrs to root element
    
    setup = function(props, ctx)
        return function()
            -- Attrs automatically merged into root Frame props
            return h("Frame", {
                Size = UDim2.fromOffset(200, 100)
                -- ctx.attrs will be automatically merged here
            })
        end
    end
}

-- Parent usage:
-- h(MyComponent, {
--     title = "Hello",           -- Declared prop
--     BackgroundColor3 = Color3.new(1, 0, 0),  -- Auto-applied to root Frame
--     onClick = handler           -- Auto-applied to root Frame
-- })
```

**When to use `inheritAttrs`:**
- Component is a thin wrapper around a single element
- You want attrs to automatically apply to the root
- Simplifies pass-through scenarios

**When NOT to use `inheritAttrs`:**
- Component has complex internal structure
- You want manual control over attr placement
- Attrs should go to a specific child, not root

---

#### Lifecycle Hook Registration

Must be called within a component's `setup` function.

##### `onBeforeMount(fn: () -> ())`

```lua
function onBeforeMount(fn: () -> ()): ()
```

Registers a callback to run **before** component is mounted (before first render).

**Use cases:**
- Prepare data before rendering
- Validate props
- Setup external connections
- Load initial state

**Example:**
```lua
setup = function()
    onBeforeMount(function()
        print("About to mount - preparing data...")
    end)
end
```

**Execution order:** `setup()` → `onBeforeMount` → first render → `onMounted`

---

##### `onMounted(fn: () -> ())`

```lua
function onMounted(fn: () -> ()): ()
```

Registers a callback to run after component is mounted (after first render).

**Use cases:**
- Access DOM elements (Instance tree is ready)
- Start animations
- Fetch data
- Setup event listeners

**Example:**
```lua
setup = function()
    onMounted(function()
        print("Mounted! DOM is ready.")
    end)
end
```

---

##### `onBeforeUpdate(fn: () -> ())`

```lua
function onBeforeUpdate(fn: () -> ()): ()
```

Registers a callback to run **before** component re-renders due to reactive changes.

**Use cases:**
- Save current state before update
- Cancel pending operations
- Prepare for next render
- Debugging state transitions

**Example:**
```lua
setup = function()
    local previousValue = ref(nil)
    
    onBeforeUpdate(function()
        previousValue.value = count.value
        print("About to update - current:", count.value)
    end)
end
```

**Execution order:** reactive change → `onBeforeUpdate` → re-render → `onUpdated`

---

##### `onUpdated(fn: () -> ())`

```lua
function onUpdated(fn: () -> ()): ()
```

Registers a callback to run after component updates (after re-render).

**Use cases:**
- React to DOM changes
- Restart animations
- Update third-party libraries
- Sync with external state

**Example:**
```lua
setup = function()
    onUpdated(function()
        print("Updated! New DOM state applied.")
    end)
end
```

---

##### `onBeforeUnmount(fn: () -> ())`

```lua
function onBeforeUnmount(fn: () -> ()): ()
```

Registers a callback to run **before** component unmounts.

**Use cases:**
- Save final state
- Show confirmation dialogs
- Complete pending operations
- Graceful shutdown preparation

**Example:**
```lua
setup = function()
    onBeforeUnmount(function()
        print("About to unmount - saving state...")
        saveStateToDataStore()
    end)
end
```

**Execution order:** unmount triggered → `onBeforeUnmount` → `onUnmounted` → cleanup

---

##### `onUnmounted(fn: () -> ())`

```lua
function onUnmounted(fn: () -> ()): ()
```

Registers a callback to run after component unmounts.

**Use cases:**
- Final cleanup
- Stop timers/connections
- Remove event listeners
- Free resources

**Example:**
```lua
setup = function()
    local connection
    
    onMounted(function()
        connection = workspace.DescendantAdded:Connect(function() end)
    end)
    
    onUnmounted(function()
        print("Unmounted! Cleaning up...")
        if connection then
            connection:Disconnect()
        end
    end)
end
```

---

**Lifecycle Hook Execution Order:**

```
Component Creation:
  1. setup() called
  2. Lifecycle hooks registered (onBeforeMount, onMounted, etc.)
  3. onBeforeMount() → all beforeMount callbacks execute
  4. First render (vnode tree created)
  5. onMounted() → all mounted callbacks execute

Reactive Updates:
  1. Reactive dependency changes
  2. onBeforeUpdate() → all beforeUpdate callbacks execute
  3. Re-render (vnode tree patched)
  4. onUpdated() → all updated callbacks execute

Component Destruction:
  1. Unmount triggered
  2. onBeforeUnmount() → all beforeUnmount callbacks execute
  3. onUnmounted() → all unmounted callbacks execute
  4. Cleanup (effects stopped, connections disconnected)
```

---

#### Component Context Methods

##### `context.emit(eventName: string, ...args)`

```lua
context.emit(eventName: string, ...any): ()
```

Emits an event to parent. Calls `props["on" .. EventName]` handler if it exists.

**Example:**
```lua
context.emit("click", "data1", "data2")
-- Parent's onClick handler receives: "data1", "data2"
```

---

##### `context.expose(api: { [string]: any })`

```lua
context.expose(api: { [string]: any }): ()
```

Exposes a public API from this component that can be accessed via template refs.

**Use cases:**
- Expose methods for parent to call
- Provide controlled access to internal state
- Create imperative handles

**Example:**
```lua
-- Child component
setup = function(props, ctx)
    local count = ref(0)
    local increment = function()
        count.value = count.value + 1
    end
    
    -- Expose public API
    ctx.expose({
        increment = increment,
        getCount = function() return count.value end
    })
    
    return function()
        return h("TextButton", {
            Text = tostring(count.value)
        })
    end
end

-- Parent component can access via ref:
-- local childRef = ref()
-- childRef.value.increment()  -- Call exposed method
-- local count = childRef.value.getCount()  -- Call exposed getter
```

**Notes:**
- Without `ctx.expose()`, the component instance itself is accessible via ref
- With `ctx.expose()`, only the exposed API is accessible
- Useful for encapsulation and creating clean public interfaces

---

##### `context.provide(key: any, value: any)`

```lua
context.provide(key: any, value: any): ()
```

Provides a value to descendant components.

---

##### `context.inject(key: any, default?: any): any`

```lua
context.inject(key: any, default: any?): any
```

Injects a value from an ancestor. Returns `default` if not found.

---

### Prop Validation

Props are validated against the schema during component instance creation. In Studio mode, validation errors are logged as warnings.

```lua
function validateProps(schema: PropSchema?, props: table): (boolean, string?)
```

**Returns:** `(isValid, errorMessage)`

**PropSpec Type:**
```lua
type PropSpec = {
    type: string,       -- Type name: "string", "number", "boolean", "table", etc.
    required: boolean?, -- Is prop required?
    default: any?,      -- Default value (can be literal or function)
    validator: ((value: any) -> boolean)?  -- Custom validation function
}
```

**Basic Validation Example:**
```lua
props = {
    title = { 
        type = "string", 
        required = true 
    },
    count = { 
        type = "number", 
        required = false,
        default = 0  -- Literal default value
    }
}
```

**Default Value Functions:**
```lua
props = {
    items = {
        type = "table",
        default = function()
            return {}  -- New table for each instance
        end
    },
    config = {
        type = "table",
        default = function(props)
            -- Default can access other props
            return { 
                name = props.name or "Default",
                enabled = true 
            }
        end
    }
}
```

**Custom Validators:**
```lua
props = {
    count = {
        type = "number",
        validator = function(value)
            return value >= 0 and value <= 100
        end
    },
    status = {
        type = "string",
        validator = function(value)
            local allowed = { "active", "pending", "completed" }
            return table.find(allowed, value) ~= nil
        end
    }
}
```

**Validation Behavior:**
- Type checking: Validates `typeof(value) == spec.type`
- Required checking: Logs warning if required prop is nil
- Default application: Applied if prop is nil (defaults run before validation)
- Custom validation: Runs after type and required checks
- Errors logged as warnings in Studio (does not throw errors)

---

## renderer.luau

Core rendering engine with virtual DOM diffing and patching, featuring optimized event handling and connection cleanup.

### Performance Optimizations

**Event/Signal Caching:**
- Event names are cached per ClassName to reduce reflection overhead
- Successful `connectEvent()` resolutions are stored in `eventSignalCache`
- Cache structure: `{ [className]: { [eventPropName]: signalName? } }`
- Avoids repeated `pcall` for signal lookups on same element types

**Connection State Transfer (Critical Fix):**
- During vnode patching, `_conns` and `_dirs` tables are transferred from old vnode to new vnode
- **Why this matters:** Prevents event handler memory leaks during re-renders
- **Before fix:** New vnodes created empty `_conns` tables, making disconnect logic unable to find old handlers
- **After fix:** Old connections are found and properly disconnected before new handlers are bound
- This prevents handlers from accumulating (single clicks firing multiple times)

**Connection Cleanup:**
- `clearVNodeConns()` safely checks `conn.Connected` before disconnecting
- Explicitly nils all connection references to prevent memory leaks
- Handles edge cases where connections may already be disconnected

### Module Exports

```lua
return {
    createApp: (rootVNode: VNode, opts: AppOptions?) -> App,
    patch: (oldVNode: VNode?, newVNode: VNode?, container: Instance, poolOpt: PoolOptions?) -> (),
    unmountVNode: (vnode: VNode?, poolOpt: PoolOptions?) -> ()
}
```

### Type Definitions

```lua
type AppOptions = {
    usePool: boolean?
}

type PoolOptions = {
    usePool: boolean?
}

type App = {
    mount: (self: App, container: Instance) -> any,
    unmount: (self: App) -> (),
    rerender: (self: App, newRoot: VNode?) -> any,
    swapRoot: (self: App, newRoot: VNode) -> any,
    mountToPlayerGui: (self: App, player: Player) -> ()
}
```

### Function Signatures

#### `createApp(rootVNode: VNode, options?: AppOptions): App`

```lua
function createApp(
    rootVNode: VNode,
    opts: { usePool: boolean? }?
): App
```

Creates an application instance.

**Options:**
- `usePool`: Enable Instance pooling for better performance

**Returns:** App instance with mount/unmount methods

---

#### `patch(oldVNode?, newVNode?, container, poolOpt?)`

```lua
function patch(
    oldVNode: VNode?,
    newVNode: VNode?,
    container: Instance,
    poolOpt: { usePool: boolean? }?
): ()
```

Core patching algorithm. Diffs old and new VNodes and updates the DOM.

**Cases:**
1. `newVNode == nil`: Unmount oldVNode
2. `oldVNode == nil`: Mount newVNode
3. Different types: Unmount old, mount new
4. Same type: Update props and patch children

**Element Patching (same type):**
When patching elements of the same type, the renderer:
1. Transfers `el` reference from old to new vnode
2. **Transfers `_conns` and `_dirs` from old to new vnode** (prevents memory leaks)
3. Patches props via `patchProps()`
4. Patches children via `patchKeyedChildren()`

**Why connection state transfer is critical:**
```lua
-- During element update:
newVNode.el = oldVNode.el
newVNode._conns = oldVNode._conns or {}  -- ✅ Transfer connections
newVNode._dirs = oldVNode._dirs or {}     -- ✅ Transfer directives
```

Without this transfer:
- `setProp` would create a new empty `_conns` table
- Disconnect logic couldn't find old handlers (they're in the old vnode's `_conns`)
- Old handlers accumulate, causing single clicks to fire multiple handlers

With this transfer:
- Old handlers are found in the transferred `_conns` table
- `setProp` properly disconnects them before binding new ones
- No handler accumulation, proper 1:1 click-to-handler ratio

**Special handling:**
- Components: Call setup, render, lifecycle hooks
- Functional components: Call function with props
- Teleport: Render children in different container
- Async components: Handle promise-based rendering
- TextBox: Preserve focus and cursor position

---

#### `unmountVNode(vnode?, poolOpt?)`

```lua
function unmountVNode(
    vnode: VNode?,
    poolOpt: { usePool: boolean? }?
): ()
```

Unmounts a VNode and cleans up:
- Disconnects event connections
- Runs unmounted directive hooks
- Destroys or pools Instance
- Recursively unmounts children

---

### Event Handling

#### Event Aliases

```lua
local eventAlias = {
    onClick = { "Activated", "MouseButton1Click" },
    onActivated = { "Activated" },
    onMouseButton1Click = { "MouseButton1Click" },
    onTouched = { "Touched" }
}
```

#### `connectEvent(inst: Instance, propName: string, handler: function): RBXScriptConnection?`

Connects an event handler to an Instance.

**Patterns:**
- Checks aliases first
- Strips `on` prefix and tries variations
- Tries GetPropertyChangedSignal for property changes
- Special handling for `onTextChanged`

---

### Prop Setting

#### `setProp(inst: Instance, key: string, value: any, vnode: VNode)`

Sets a property on an Instance:

1. Handles `__directives` specially
2. Event handlers (`on*`): Creates/replaces connections
3. Direct property assignment if property exists
4. Case variations (e.g., `text` → `Text`)
5. Warns about unknown properties in Studio

**Special cases:**
- `onTextChanged`: Uses GetPropertyChangedSignal("Text")
- Connection cleanup: Disconnects old connections before creating new ones

---

### Children Patching

#### `patchKeyedChildren(oldChildren, newChildren, parent, poolOpt)`

Efficiently patches children using keys:

1. Build map of old children by key
2. For each new child with key:
   - Reuse old child if key matches
   - Search DOM for matching key
   - Create new child if not found
3. Update LayoutOrder if UIListLayout/UIGridLayout present
4. Unmount remaining old children

**Without keys:** Simple index-based patching  
**With keys:** Optimal reordering and minimal DOM changes

---

### Transitions

#### `runTransition(inst: Instance, transition, phase: "enter" | "leave")`

Runs a TweenService animation:

```lua
type Transition = {
    info: TweenInfo | tweenInfo: TweenInfo,
    enterGoals: { [string]: any } | goals: { [string]: any },
    leaveGoals: { [string]: any }?
}
```

**Example:**
```lua
h("Frame", {
    transition = {
        info = TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        enterGoals = { BackgroundTransparency = 0 },
        leaveGoals = { BackgroundTransparency = 1 }
    }
})
```

---

### TextBox Preservation

#### `withPreservedTextState(el: Instance, fn: () -> any): any`

Preserves TextBox state during updates:
- Saves Text, SelectionStart, focus state
- Runs update function
- Restores state afterward

Prevents cursor jumping and text loss during reactive updates.

---

## directives.luau

Directive system for custom element behaviors.

### Module Exports

```lua
return {
    register: (name: string, hooks: DirectiveHooks) -> (),
    get: (name: string) -> DirectiveHooks?,
    vModelText: (r: Ref<string>) -> { Text: string, onTextChanged: function },
    vModelProp: (r: Ref<any>, propName: string, eventName: string?) -> table
}
```

### Type Definitions

```lua
type DirectiveHooks = {
    mounted: ((el: Instance, value: any) -> any)?,
    updated: ((el: Instance, value: any, cleanup: any) -> any)?,
    unmounted: ((el: Instance, cleanup: any) -> ())?
}
```

### Function Signatures

#### `register(name: string, hooks: DirectiveHooks)`

```lua
function directives.register(name: string, hooks: DirectiveHooks): ()
```

Registers a custom directive.

**Hooks:**
- `mounted(element, value)`: Called when element is mounted. Return cleanup data.
- `updated(element, value, cleanup)`: Called when directive value changes.
- `unmounted(element, cleanup)`: Called before element unmounts.

**Example:**
```lua
directives.register("rainbow", {
    mounted = function(el, speed)
        local hue = 0
        local conn = RunService.Heartbeat:Connect(function(dt)
            hue = (hue + dt * (speed or 1)) % 1
            el.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        end)
        return conn -- Return for cleanup
    end,
    
    unmounted = function(el, conn)
        if conn then
            conn:Disconnect()
        end
    end
})

-- Usage
h("Frame", {
    __directives = {
        { name = "rainbow", value = 0.5 }
    }
})
```

---

#### `get(name: string): DirectiveHooks?`

```lua
function directives.get(name: string): DirectiveHooks?
```

Gets a registered directive's hooks.

---

### Built-in Directives

#### `focus`

Auto-focuses an element when mounted.

```lua
h("TextBox", {
    __directives = {
        { name = "focus", value = true }
    }
})
```

---

#### `click-outside`

Calls a function when clicking outside the element.

```lua
h("Frame", {
    __directives = {
        {
            name = "click-outside",
            value = function()
                print("Clicked outside!")
            end
        }
    }
})
```

**Implementation:** Uses UserInputService.InputBegan and mouse target tracking.

---

#### `show`

Toggles element visibility without unmounting (like Vue's v-show).

```lua
local visible = ref(true)

h("Frame", {
    __directives = {
        { name = "show", value = visible.value }
    }
})
```

**Benefits:**
- Preserves component state (not destroyed/recreated)
- Faster toggling than conditional rendering
- Good for frequently toggled elements

---

#### `drag`

Makes a GuiObject draggable via mouse or touch.

```lua
h("Frame", {
    __directives = {
        { name = "drag", value = true }
    }
})
```

**Features:**
- Mouse and touch support
- Preserves relative position during drag
- No boundary constraints (can be added via options in future)

---

#### `fade-in`

Recursively animates all GUI elements from transparent to visible.

```lua
h("Frame", {
    __directives = {
        { 
            name = "fade-in", 
            value = { 
                duration = 1.0,      -- Animation duration in seconds
                delay = 0.5,         -- Delay before animation starts
                waitForLoad = true,  -- Wait for game:IsLoaded()
                renderWait = 0.5     -- Wait time for children to render
            } 
        }
    }
})
```

**Options:**
- `duration` (number, default: 0.5): Tween duration in seconds
- `delay` (number, default: 0): Delay before animation starts
- `waitForLoad` (boolean, default: false): Wait for game to load before starting
- `renderWait` (number, default: 0.5): Wait time for reactive components to mount

**Supported Properties:**
- `BackgroundTransparency` (all GuiObjects)
- `TextTransparency` (TextLabel, TextButton, TextBox)
- `ImageTransparency` (ImageLabel, ImageButton)
- `GroupTransparency` (CanvasGroup - for better performance)
- `Transparency` (UIStroke - modern UI elements)

**Features:**
- Recursive: Animates all descendants automatically
- Memory efficient: Tweens are destroyed after completion
- Modern UI support: Handles UIStroke, CanvasGroup
- Configurable timing: Adjust for different component complexities

**Performance Tips:**
- Wrap content in CanvasGroup for single-property animation (faster)
- Increase `renderWait` for complex component trees
- Use shorter `duration` for snappier feel

**Example with CanvasGroup:**
```lua
h("CanvasGroup", {
    __directives = {
        { name = "fade-in", value = { duration = 0.8 } }
    }
}, {
    -- All children will benefit from single GroupTransparency tween
    h("Frame", ...),
    h("TextLabel", ...),
})
```

---

### v-model Helpers

#### `vModelText(ref: Ref<string>): { Text: string, onTextChanged: function }`

```lua
function directives.vModelText(r: Ref<string>): {
    Text: string,
    onTextChanged: (new: string) -> ()
}
```

Two-way binding for text inputs.

**Example:**
```lua
local text = ref("Hello")
h("TextBox", vModelText(text))

-- Equivalent to:
h("TextBox", {
    Text = text.value,
    onTextChanged = function(new)
        text.value = new
    end
})
```

---

#### `vModelProp(ref: Ref<any>, propName: string, eventName?: string): table`

```lua
function directives.vModelProp(
    r: Ref<any>,
    propName: string,
    eventName: string?
): table
```

Generic two-way binding.

**Example:**
```lua
local volume = ref(0.5)
h("CustomSlider", vModelProp(volume, "Volume", "onVolumeChanged"))

-- Equivalent to:
h("CustomSlider", {
    Volume = volume.value,
    onVolumeChanged = function(new)
        volume.value = new
    end
})
```

**Event name default:** `"on" .. capitalize(propName)`

---

## scheduler.luau

Job scheduling system for deferred execution.

### Module Exports

```lua
return {
    queueJob: (fn: () -> (), opts: QueueOptions?) -> JobHandle
}
```

### Type Definitions

```lua
type QueueOptions = {
    mode: "micro" | "render" | "heartbeat"?
}

type JobHandle = {
    cancel: () -> ()
}
```

### Function Signatures

#### `queueJob(fn: () -> (), options?): JobHandle`

```lua
function scheduler.queueJob(
    fn: () -> (),
    opts: { mode: "micro" | "render" | "heartbeat"? }?
): { cancel: () -> () }
```

Queues a job for execution.

**Modes:**
- `"micro"` (default): Deferred execution via task.defer with deduplication
- `"render"`: Next RenderStepped frame
- `"heartbeat"`: Next Heartbeat frame

**Returns:** Handle with `cancel()` method

**Example:**
```lua
local job = scheduler.queueJob(function()
    print("Executed!")
end, { mode = "render" })

-- Cancel if needed
job.cancel()
```

**Micro-queue behavior:**
- Deduplicates: Same function queued multiple times runs once
- Batches: All micro jobs flush together
- Non-blocking: Uses task.defer

---

### Internal Implementation

```lua
local microQueue = {} -- Pending jobs
local microQueued = {} -- Deduplication map

function flushMicro()
    -- Runs all queued jobs in batch
end
```

Jobs are automatically flushed via `task.defer(flushMicro)`.

---

## pool.luau

Instance pooling system for performance optimization.

### Module Exports

```lua
return {
    acquire: (className: string) -> Instance,
    release: (inst: Instance) -> (),
    clear: () -> (),
    store: { [string]: { Instance } } -- Internal pool storage
}
```

### Function Signatures

#### `acquire(className: string): Instance`

```lua
function Pool.acquire(className: string): Instance
```

Gets an Instance from the pool or creates a new one.

**Example:**
```lua
local frame = Pool.acquire("Frame")
-- Use frame...
```

**Fallback:** If Instance.new fails, returns a Frame.

---

#### `release(inst: Instance)`

```lua
function Pool.release(inst: Instance): ()
```

Returns an Instance to the pool after resetting it.

**Reset operations:**
- Sets `Parent = nil`
- Clears `Text` for text elements
- Clears `Image` for image elements
- Resets `LayoutOrder` to 0
- Renames to `"Pooled" .. className`
- Removes `__vkey` and `__v_is_textbox` attributes

**Example:**
```lua
Pool.release(frame)
```

---

#### `clear()`

```lua
function Pool.clear(): ()
```

Destroys all pooled Instances and empties the pool.

**Example:**
```lua
Pool.clear() -- Destroys all pooled objects
```

---

### Usage with Rivue

When `usePool: true` is enabled in createApp:
- `patch` calls `Pool.acquire` instead of `Instance.new`
- `unmountVNode` calls `Pool.release` instead of `:Destroy()`
- ScreenGuis are never pooled (always destroyed)

---

## utils.luau

Utility functions for common tasks.

### Module Exports

```lua
return {
    debounce: (fn: function, ms: number) -> function,
    throttle: (fn: function, ms: number) -> function,
    nextTick: (fn: () -> ()) -> (),
    nextFrame: (fn: () -> ()) -> (),
    useRaf: (fn: (dt: number) -> ()) -> { stop: () -> () },
    filterForClient: (player: Player, str: string) -> string,
    profiler: {
        active: boolean,
        records: { [string]: number },
        start: (name: string) -> (),
        stop: (name: string) -> number?
    }
}
```

### Function Signatures

#### `debounce(fn: function, ms: number): function`

```lua
function utils.debounce(fn: (...any) -> (), ms: number): (...any) -> { cancel: () -> () }
```

Creates a debounced function that delays execution until `ms` milliseconds of inactivity.

**Returns:** Debounced function that returns `{ cancel: () -> () }`

**Example:**
```lua
local debouncedSave = utils.debounce(function(data)
    print("Saving:", data)
end, 500)

debouncedSave("data1")
debouncedSave("data2") -- Cancels previous
debouncedSave("data3") -- Only this executes (after 500ms)
```

---

#### `throttle(fn: function, ms: number): function`

```lua
function utils.throttle(fn: (...any) -> (), ms: number): (...any) -> ()
```

Creates a throttled function that executes at most once per `ms` milliseconds.

**Example:**
```lua
local throttledUpdate = utils.throttle(function()
    print("Update")
end, 1000)

for i = 1, 100 do
    throttledUpdate() -- Executes ~once per second
end
```

---

#### `nextTick(fn: () -> ())`

```lua
function utils.nextTick(fn: () -> ()): ()
```

Defers function to next micro-task via `task.defer`.

---

#### `nextFrame(fn: () -> ())`

```lua
function utils.nextFrame(fn: () -> ()): ()
```

Defers function to next Heartbeat frame.

---

#### `useRaf(fn: (deltaTime: number) -> ()): { stop: () -> () }`

```lua
function utils.useRaf(fn: (dt: number) -> ()): { stop: () -> () }
```

Runs a function every RenderStepped frame.

**Example:**
```lua
local raf = utils.useRaf(function(dt)
    rotation = rotation + dt * 45
    part.Rotation = Vector3.new(0, rotation, 0)
end)

-- Stop
raf.stop()
```

---

#### `filterForClient(player: Player, text: string): string`

```lua
function utils.filterForClient(player: Player, str: string): string
```

Filters text using TextService for chat/display.

**Returns:** Filtered text, or original on error

---

#### Profiler

Simple performance profiler.

```lua
utils.profiler.start("operation")
-- ... do work ...
local elapsed = utils.profiler.stop("operation")
print("Took", elapsed, "seconds")
```

**Methods:**
- `start(name: string)`: Start timing
- `stop(name: string): number?`: Stop and return elapsed time

---

#### `iterArray<T>(array: { T }): () -> (number?, T?)`

```lua
function utils.iterArray<T>(array: { T }): () -> (number?, T?)
```

Iterator for reactive arrays with `ipairs`-like syntax.

**Benefits:**
- Works with both reactive and non-reactive arrays
- Properly triggers `__len` and `__index` metamethods
- Familiar syntax for developers expecting `ipairs()` behavior
- Full reactivity tracking maintained

**Example:**
```lua
local items = reactive({ "apple", "banana", "cherry" })

-- Use with Rivue.utils.iterArray or directly if imported
for i, item in utils.iterArray(items) do
    print(i, item)  -- 1 apple, 2 banana, 3 cherry
end

-- Also works with non-reactive arrays
for i, item in utils.iterArray({ "a", "b", "c" }) do
    print(i, item)
end
```

**Note:** While `for i = 1, #array` is more concise, `iterArray()` provides `ipairs`-like ergonomics for developers who prefer that style.

---

## remote.luau

Client-side remote communication wrapper.

### Module Exports

```lua
return {
    request: (actionName: string, payload: any, timeout: number?) -> (any?, string?),
    fire: (actionName: string, payload: any) -> (),
    on: (name: string, fn: function) -> RBXScriptConnection
}
```

### Function Signatures

#### `request(actionName: string, payload: any, timeout?: number): (data?, error?)`

```lua
function Remote.request(
    actionName: string,
    payload: any,
    timeout: number?
): (any?, string?)
```

Sends a validated request to server and waits for response.

**Parameters:**
- `actionName`: Action identifier (validated: 1-100 chars)
- `payload`: Data to send (validated for safety and size)
- `timeout`: Timeout in seconds (default: 10)

**Returns:** `(data, error)` tuple
- Success: `(data, nil)`
- Failure: `(nil, errorCode)`

**Error codes:**
- `"invalid_action_name"`: Action name empty or exceeds 100 characters
- `"payload_not_serializable"`: Payload cannot be JSON encoded
- `"payload_too_large"`: Payload exceeds 20KB when serialized
- `"payload_unsafe_type"`: Payload contains functions, userdata, or other unsafe types
- `"timeout"`: Request exceeded timeout duration

**Validation details:**
- **Action name**: Must be a non-empty string ≤100 characters
- **Payload size**: Max 20,000 bytes (20KB) when JSON serialized
- **Payload types**: Only allows `string`, `number`, `boolean`, `nil`, and `table`
- **Nesting depth**: Max 10 levels to prevent deep recursion attacks
- **Safety check**: Uses `HttpService:JSONEncode()` to verify serializability

**Example:**
```lua
local data, err = Remote.request("getPlayerData", { userId = 123 }, 5)

if err == "payload_too_large" then
    warn("Request payload exceeds size limit")
elseif err == "timeout" then
    warn("Server did not respond in time")
elseif err then
    warn("Request failed:", err)
else
    print("Got data:", data)
end
```

**Server implementation:**
```lua
local requestEvent = ReplicatedStorage.RemoteEvents.Request
local responseEvent = ReplicatedStorage.RemoteEvents.Response

requestEvent.OnServerEvent:Connect(function(player, req)
    if req.action == "getPlayerData" then
        local data = { name = "Player", score = 100 }
        responseEvent:FireClient(player, {
            id = req.id,
            ok = true,
            data = data
        })
    end
end)
```

---

#### `fire(actionName: string, payload: any)`

```lua
function Remote.fire(actionName: string, payload: any): ()
```

Fires a one-way event to server (no response).

**Example:**
```lua
Remote.fire("logAction", { action = "jump", timestamp = os.time() })
```

---

#### `on(eventName: string, callback: function): RBXScriptConnection`

```lua
function Remote.on(
    name: string,
    fn: (...any) -> ()
): RBXScriptConnection
```

Listens for events from server.

**Example:**
```lua
local conn = Remote.on("serverNotification", function(message)
    print("Server says:", message)
end)

-- Cleanup
conn:Disconnect()
```

---

### Internal Structure

Creates/finds RemoteEvents in `ReplicatedStorage.RemoteEvents`:
- `Request`: Client → Server requests
- `Response`: Server → Client responses
- Custom named events for `Remote.on()`

Request/response uses GUID-based matching for async request correlation.

---

## main.luau

Main entry point that assembles the public API.

### Module Structure

```lua
-- Import all runtime modules
local reactivity = require(runtime:WaitForChild("reactivity"))
local hModule = require(runtime:WaitForChild("h"))
local renderer = require(runtime:WaitForChild("renderer"))
local componentAPI = require(runtime:WaitForChild("component"))
local utils = require(runtime:WaitForChild("utils"))
local directives = require(runtime:WaitForChild("directives"))
local remote = require(runtime:WaitForChild("remote"))

-- Assemble public API
local Rivue = {}

-- Detect dev mode
Rivue.dev = RunService:IsStudio()

-- Export all APIs...

return Rivue
```

### Complete API Export

```lua
return {
    dev: boolean,
    
    -- Reactivity
    ref: <T>(initial: T) -> Ref<T>,
    reactive: (target: table) -> table,
    shallowReactive: (target: table) -> table,
    computed: <T>(getter: () -> T) -> ComputedRef<T>,
    watch: (source, cb, opts?) -> () -> (),
    effect: (fn, opts?) -> Effect,
    toRef: (obj: table, key: string) -> Ref<any>,
    toRefs: (obj: table) -> { [string]: Ref<any> },
    markRaw: (obj: table) -> table,
    toRaw: (obj: table) -> table,
    unref: <T>(value: T | Ref<T>) -> T,
    isRef: (value: any) -> boolean,
    
    -- Rendering
    h: (type, props?, children?) -> VNode,
    hIf: (cond: boolean, vnode?) -> VNode?,
    hFor: <T>(list: { T }, mapper: (T, number) -> VNode?) -> { VNode },
    
    -- Components
    defineComponent: (opts: ComponentOptions) -> ComponentDefinition,
    onMounted: (fn: () -> ()) -> (),
    onUpdated: (fn: () -> ()) -> (),
    onUnmounted: (fn: () -> ()) -> (),
    
    -- App
    createApp: (vnode: VNode, opts?) -> App,
    mount: (componentOrVNode, parent, opts?) -> App,
    
    -- Directives
    vModelText: (ref: Ref<string>) -> table,
    vModelProp: (ref: Ref<any>, propName: string, eventName?: string) -> table,
    
    -- Utilities
    utils: Utils,
    directives: Directives,
    Remote: Remote
}
```

---

## Rivue.luau

Entry point that locates and requires the runtime.

### Logic Flow

```lua
local runtimeFolder = script:FindFirstChild("runtime")

if runtimeFolder then
    -- Runtime is a child of this script
    return require(runtimeFolder:WaitForChild("main"))
else
    -- Fallback: Look in ReplicatedStorage
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local runtimeModule = ReplicatedStorage:FindFirstChild("Rivue")
    
    if runtimeModule and runtimeModule:FindFirstChild("main") then
        return require(runtimeModule:WaitForChild("main"))
    end
    
    error("Rivue runtime not found. Place 'runtime' folder as child of this ModuleScript or place runtime in ReplicatedStorage.")
end
```

**Expected structure:**
```
Rivue (ModuleScript)
└── runtime (Folder)
    ├── main (ModuleScript)
    ├── reactivity (ModuleScript)
    ├── h (ModuleScript)
    └── ... other runtime modules
```

---

## Type Reference Summary

```lua
-- Core types
type Ref<T> = { value: T, _is_ref: true }
type ComputedRef<T> = { value: T, get: () -> T }
type Effect = { run: () -> (), stop: () -> (), active: boolean }

type VNode = {
    type: string | table | function,
    props: { [string]: any }?,
    children: { VNode | string }?,
    key: any?,
    el: Instance?
}

type ComponentDefinition = {
    __is_component: true,
    setup: ((props, ctx) -> (() -> VNode))?,
    render: ((props) -> VNode)?,
    props: PropSchema?,
    __name: string?
}

type App = {
    mount: (container: Instance) -> any,
    unmount: () -> (),
    rerender: (newRoot?: VNode) -> any,
    swapRoot: (newRoot: VNode) -> any,
    mountToPlayerGui: (player: Player) -> ()
}

type DirectiveHooks = {
    mounted: ((el: Instance, value: any) -> any)?,
    updated: ((el: Instance, value: any, cleanup: any) -> any)?,
    unmounted: ((el: Instance, cleanup: any) -> ())?
}
```

---

## Performance Considerations

### Reactivity System
- Uses weak-key maps to prevent memory leaks
- Dependency tracking is automatic and optimized
- Effects are batched via scheduler

### Renderer
- Virtual DOM diffing minimizes DOM operations
- Keyed children enable efficient list updates
- Object pooling reduces GC pressure
- TextBox state preservation prevents focus loss

### Scheduler
- Micro-tasks are deduplicated
- Batched execution reduces overhead
- Multiple scheduling modes for different use cases

### Pool
- Reuses Instances instead of creating/destroying
- Automatic cleanup of pooled objects
- Significant performance gain for dynamic UIs

---

## Best Practices

1. **Always use keys for lists** to enable efficient updates
2. **Enable pooling** for dynamic UIs with `usePool: true`
3. **Clean up effects** in onUnmounted hooks
4. **Use shallow reactive** for large objects when deep tracking isn't needed
5. **Mark raw** third-party objects that shouldn't be reactive
6. **Debounce/throttle** frequent updates (input, scroll, resize)
7. **Use computed** for derived state instead of recalculating in render
8. **Profile with utils.profiler** to identify bottlenecks

---

## Migration Guide

### From raw Roblox UI code

**Before:**
```lua
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(200, 200)
frame.Parent = screenGui

local button = Instance.new("TextButton")
button.Text = "Click"
button.Parent = frame

button.Activated:Connect(function()
    frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
end)
```

**After:**
```lua
local showRed = ref(false)

local App = defineComponent({
    setup = function()
        return function()
            return h("Frame", {
                Size = UDim2.fromOffset(200, 200),
                BackgroundColor3 = showRed.value and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 255, 255)
            }, {
                h("TextButton", {
                    Text = "Click",
                    onClick = function()
                        showRed.value = true
                    end
                })
            })
        end
    end
})

Rivue.mount(h(App), screenGui)
```

---

This completes the runtime reference documentation for the Rivue!
