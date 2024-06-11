# Architecture

How Rivue works inside, for people changing the runtime. For the public API, see [API.md](API.md).

## Modules

```
Rivue.luau            entry point, requires runtime/main
runtime/
  main.luau           assembles the public API, wraps watch/effect for auto-cleanup
  types.luau          shared exported types
  reactivity.luau     proxies, refs, computed, effects, watch, effect scopes
  scheduler.luau      micro queue, frame queues, component update queue
  h.luau              vnode creation, slots splitting, hFor/hIf, Fragment
  component.luau      component instances, props/attrs, emits, hooks, provide/inject
  renderer.luau       mount/patch/unmount, events, props, transitions, KeepAlive, Teleport, createApp
  builtins.luau       Suspense, KeepAlive, Transition, TransitionGroup, VirtualList, async components
  directives.luau     directive registry and built-in directives, v-model helpers
  composables.luau    useAttrs, useSlots, defineModel, useTheme, useStyles
  roblox.luau         attributeRef, useTag, RunService hooks, viewport/input/selection/tween/spring
  pool.luau           Instance pool
  remote.luau         RemoteEvent request/response with rate limiting
  utils.luau          debounce, throttle, misc
  debug.luau          logging, inspect, invariants
```

Dependencies only point downward: `types` and `debug` have no runtime dependencies, `reactivity`
needs `scheduler`, `component` needs `reactivity`, `h` needs `component` (for ref owners), and
`renderer` needs everything below it. `builtins` reaches renderer internals only through fields
the renderer sets on component instances (`_keepAliveRenderer`).

## Reactivity

- **Proxies.** `reactive(t)` returns an empty table whose metatable forwards to the raw table:
  - `__index` tracks the read,
  - `__newindex` triggers on change,
  - `__iter` and `__len` track structural changes.

  Raw tables, proxies and markers are kept in weak-keyed maps, so proxies are cached per table
  and garbage collected with it.
- **Dependencies.** `track(target, key)` adds the running effect to `depMap[target][key]`.
  `trigger(target, key)` runs or schedules every effect in that set. Adding or removing a key
  also triggers `ITERATE_KEY`, and array length changes trigger `LENGTH_KEY`.
- **Effects.** An effect re-collects its dependencies on every run (old deps are cleared first).
  With a scheduler, `trigger` calls `scheduler(run)` instead of running. Without one, the effect
  is deduplicated on the micro queue. `effect.job` is the queued entry point and skips stopped
  effects.
- **Computed** values are lazy. A trigger only marks them dirty and notifies their own
  dependents.
- **Watch** wraps an effect whose scheduler refreshes the value, then queues the callback by
  flush mode (`"pre"` on the micro queue, `"post"` on Heartbeat, `"sync"` inline). Pausing
  records that something changed and replays it once on resume.
- **Scopes.** `effectScope` collects effects created while it runs. Each component's setup runs
  in a detached scope that's stopped on unmount.

## Scheduler

- **Micro queue**: `queueJob(fn)` / `queueEffect(fn)` are deduplicated by function and flushed on
  `task.defer`. Jobs queued during a flush run in a follow-up flush.
- **Frame queues**: `"render"` (RenderStepped) and `"heartbeat"`, one connection per mode, only
  connected while something is queued.
- **Component updates**: `queueUpdate({ id, run })` is deduplicated by job and sorted by
  component uid before flushing, so parents (created first) render before children. A child that
  is already queued when its parent passes it new props still renders only once, after the
  parent. A loop guard stops runaway recursive updates.
- `nextTick` defers after all of the above.

## Rendering

### Vnodes

`h()` returns:

```lua
{ type, props, children, slots?, key, _uid, _owner? }
```

The renderer adds fields while the vnode is mounted:

| Field | Holds |
|-------|-------|
| `el` | The Instance |
| `_instance` | The component instance |
| `_conns` | Event connections |
| `_dirs` | Directive state |
| `_touched` | Props written, so the pool can reset them |
| `_sugar` | Generated UICorner and similar children |
| `_tween` | The running enter tween |
| `_fnTree` | A function component's output |
| `_teleportTarget` | Where a Teleport rendered |
| `_keepAlive`, `_kept` | KeepAlive bookkeeping |
| `_transition` | The transition config |

When an element is patched, its state moves from the old vnode to the new one.

### patch(old, new, container)

1. `new == nil` → unmount `old`.
2. A string type registered with `app:component()` is swapped for the component.
3. `old == nil` → mount. The order of checks is Fragment, Teleport, then a KeepAlive child to
   re-activate, then a component, a function component, and finally an element.
4. If the type or key differs → unmount `old` and mount `new`.
5. Otherwise, update in place:
   - **Fragment**: patch the children as a list.
   - **Teleport**: patch in the target, or remount if the target changed.
   - **Component**: update props and slots. Its own render effect re-renders it, unless
     `memo` deps match.
   - **Function component**: diff its output.
   - **Element**: `patchElement`.

The outermost `patch` call sets a flag and flushes the **post queue** when it returns. Mounting
an element sets props, mounts the children into the still-detached Instance, and only then sets
`Parent`. Work that needs the tree in the DataModel is queued and runs after the whole patch,
children before parents:
- `onMounted`,
- directive `mounted`,
- component template refs,
- `onActivated`,
- enter tweens.

### Elements

- `setProp` handles each prop:
  - `__directives`,
  - `on*` keys: aliases, then the event, then the property changed signal (which passes the new
    value). The lookup is cached per ClassName and prop.
  - modifier props on GuiObjects,
  - Instance properties: exact name, then PascalCase, cached per ClassName,
  - unknown props, which trigger a Studio warning.
- `patchElement`:
  - skips everything when `memo` deps match,
  - re-points template refs if `ref` changed,
  - diffs props shallowly (removed props are reset with `Pool.restoreDefaults`),
  - patches children unless the children table is the same.
  - On TextBoxes the patch keeps what the player typed unless the new props change `Text`.
- `patchKeyedChildren`:
  - matches keyed children by key, falling back to a `__vkey` attribute lookup,
  - patches unkeyed children by index,
  - unmounts what's left over,
  - keeps `LayoutOrder` in step with the list order when the parent has a UIListLayout or
    UIGridLayout.

### Unmounting

`unmountVNode(vnode, poolOpt, doRemove)`:

- **Components**: stop the render effect, run unmount hooks and cleanups, then unmount the
  subtree. A child cached by a live KeepAlive is *deactivated* instead: its root Instances are
  detached and `onDeactivated` runs.
- **Elements**:
  - Connections and directives are cleared first.
  - Without the pool, children are unmounted with `doRemove = false`: their hooks run, but
    their Instances go with the root's `Destroy()`.
  - With the pool, each Instance is released individually.
  - An element with a leave transition keeps its Instance until the tween completes. Nothing
    waits for it.

### Components

`mountComponent`:

1. Creates the instance.
2. Runs `setup()` in its scope, with the current instance set.
3. Creates a lazy render effect, with these steps:
   - the render function runs with `currentRenderingInstance` set, so string refs know their
     owner,
   - array results are wrapped in a Fragment,
   - fallthrough attrs and the Transition config are applied to the root,
   - then the result is patched into `inst.container`.
4. Uses the effect's scheduler, which queues an update job keyed by the instance uid.

While a component is deactivated, update jobs only mark it dirty, and it re-renders on
activation.

Props and attrs are `shallowReactive` tables. `updateComponentProps` writes through them, so only
effects that read a changed prop re-run. Slots aren't reactive. `updateComponentSlots` reports
whether there was slot content, and the renderer then queues a re-render.

## Tests

Test suites live in `tests/*.test.luau`. Each one returns a function, or a table with
`runAllTests`.

- **Studio**: `src/client/TestRunner.client.luau` runs every suite.
- **Offline**: `scripts/test-offline.sh` bundles each suite with `tests/offline/prelude.luau` and
  runs it with the Luau CLI. The prelude provides:
  - stub Instances (userdata with property signals),
  - virtual time, where `task.wait` and frame signals advance a fake clock,
  - TweenService, GuiService, Players and CollectionService.

  Only the parts of the engine the runtime uses are stubbed. Extend the prelude when a test needs
  more.

When fixing a bug, add a test that fails without the fix.
