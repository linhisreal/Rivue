# Rivue for Vue Developers

Rivue implements Vue 3's runtime (reactivity, components, the virtual DOM) in Luau. There's no
template compiler, so you write what Vue templates compile to: render functions with `h()`.
Everything else maps closely.

## Templates to render functions

| Vue template | Rivue |
|--------------|-------|
| `<div class="card">` | `h("Frame", { class = "card" })` (classes from `app:styles()` or the `styles` option) |
| `:class="{ active: isActive }"` / `:class="[a, b]"` | `class = { active = isActive }` / `class = { a, b }` |
| `<style scoped>` | the component's `styles = { ... }` option |
| `display: flex; gap: 8px` | `layout = { direction = "horizontal", gap = 8 }`, `flex = "fill"` on children |
| `:size="size"` | `Size = size` |
| `@click="onClick"` | `onClick = onClick` |
| `@update:modelValue` | `["onUpdate:modelValue"] = fn` |
| `v-if="open"` | `Rivue.hIf(open.value, h(...))` or `if open.value then h(...) else nil` |
| `v-else` | `if a then h(A) else h(B)` |
| `v-show="open"` | `vShow = open.value` |
| `v-for="item in items" :key="item.id"` | `Rivue.hFor(items.value, function(item) return h(..., { key = item.id }) end)` |
| `v-model="name"` | `model = name` (TextBox, or a component using `defineModel`), or `model = "name"` in `render(ctx)` |
| `v-focus` / custom `v-x` | `vFocus = true` / `vX = value` |
| `v-memo="[a, b]"` | `memo = { a, b }` |
| `v-once` | `memo = {}` (empty deps never change) |
| `ref="input"` | `ref = "input"` + `Rivue.useTemplateRef("input")` |
| `<slot name="header" :title="t" />` | `ctx.renderSlot("header", { title = t })` |
| `<template #header="{ title }">` | `header = function(scope) ... end` in the children table |
| `<Teleport to="body">` | `h(Rivue.Teleport, { to = screenGui }, ...)` |
| `<Transition name="fade">` | `h(Rivue.Transition, { tweenInfo = ..., from = { BackgroundTransparency = 1 } }, ...)` |
| `<KeepAlive>` / `<Suspense>` | `Rivue.KeepAlive` / `Rivue.Suspense` |
| `{{ count }}` | `Text = tostring(ctx.count)` in `render(ctx)`, or `` Text = `{count.value}` `` in setup's render function |
| `components: { ItemRow }` | `components = { ItemRow = ItemRow }`, then `h("ItemRow", ...)` |
| `items.push(x)` / `items.splice(i, 1)` | `Rivue.array.push(items, x)` / `Rivue.array.splice(items, i, 1)` |

## script setup to defineComponent

```vue
<script setup>
const props = defineProps({ start: { type: Number, default: 0 } })
const emit = defineEmits(["change"])
const count = ref(props.start)
const doubled = computed(() => count.value * 2)
onMounted(() => console.log("mounted"))
</script>
```

```lua
local Counter = Rivue.defineComponent({
	name = "Counter",
	props = { start = { type = "number", default = 0 } },
	emits = { "change" },
	setup = function(props, ctx)
		local count = Rivue.ref(props.start)
		local doubled = Rivue.computed(function()
			return count.value * 2
		end)
		Rivue.onMounted(function()
			print("mounted")
		end)

		return function()
			return h("TextButton", {
				Text = `{count.value} ({doubled.value})`,
				onClick = function()
					count.value += 1
					ctx.emit("change", count.value)
				end,
			})
		end
	end,
})
```

Or the short form, with just a setup function:
`Rivue.defineComponent(function(props, ctx) ... end, { name = "Counter" })`.

`setup()` can also return its state, like the Options API's `setup` + `render` pair or what
`<script setup>` exposes to a template. Refs are unwrapped in `render(ctx)`, as in templates:

```lua
local Counter = Rivue.defineComponent({
	name = "Counter",
	props = { start = { type = "number", default = 0 } },
	emits = { "change" },
	setup = function(props, ctx)
		local count = Rivue.ref(props.start)
		return {
			count = count,
			doubled = Rivue.computed(function()
				return count.value * 2
			end),
			increment = function()
				count.value += 1
				ctx.emit("change", count.value)
			end,
		}
	end,
	render = function(ctx)
		return h("TextButton", { Text = `{ctx.count} ({ctx.doubled})`, onClick = ctx.increment })
	end,
})
```

## Same names, same behaviour

| Area | APIs |
|------|------|
| Reactivity | `ref`, `shallowRef`, `reactive`, `shallowReactive`, `readonly`, `shallowReadonly`, `computed` (getter and get/set), `customRef`, `triggerRef`, `toRef`, `toRefs`, `toValue`, `unref`, `toRaw`, `markRaw`, `isRef`, `isReactive`, `isReadonly`, `isProxy`, `isShallow` |
| Watching | `watch` (`immediate`, `deep` incl. a depth number, `flush`, `once`, multiple sources, pause/resume handle), `watchEffect`, `watchPostEffect`, `watchSyncEffect`, `onWatcherCleanup` |
| Scopes | `effectScope`, `getCurrentScope`, `onScopeDispose` |
| Lifecycle | `onBeforeMount`, `onMounted`, `onBeforeUpdate`, `onUpdated`, `onBeforeUnmount`, `onUnmounted`, `onActivated`, `onDeactivated`, `onErrorCaptured`, `onRenderTracked`, `onRenderTriggered` |
| Components | `defineComponent`, `defineAsyncComponent`, `defineModel`, `useAttrs`, `useSlots`, `useTemplateRef`, `useId`, `getCurrentInstance`, `provide`, `inject`, `hasInjectionContext`, `resolveComponent` |
| Render | `h`, `Fragment`, `mergeProps`, `cloneVNode`, `isVNode`, `nextTick` |
| App | `createApp`, `app.mount/unmount/provide/component/directive/use/onUnmount/runWithContext`, `app.config.errorHandler/warnHandler/globalProperties` |
| Built-ins | `Transition`, `TransitionGroup`, `KeepAlive`, `Teleport` (with `to`, `disabled` and `defer`), `Suspense` |

## Differences to know

- **`.value` and proxies.** Same as Vue, but Luau has no `__pairs`/`__ipairs`. Iterate reactive
  tables with `for k, v in state do` or a numeric loop. `table.insert`/`table.remove` bypass the
  proxy, so use [`Rivue.array`](api/array.md) (`push`, `splice`, `removeWhere`, `sort`, ...) in
  place of JavaScript's array methods.
- **No templates, no compiler.** That means no compile-time props destructuring, no `<style>`,
  and no SFCs (one ModuleScript per component instead, see the [Style Guide](STYLE_GUIDE.md)).
  The `defineProps` and `defineEmits` macros are the `props` and `emits` options.
  Every render re-creates its vnodes. Rivue's diff is shallow on props, and `memo` and keys do
  what the compiler's static hoisting does in Vue.
- **Instances, not DOM.** Element types are Roblox ClassNames. Props are Instance properties and
  events. Styling is properties, grouped into `class` styles, plus modifier props like `cornerRadius`,
  `padding` and `layout`. There's no CSS cascade: a class only styles the element it's on.
- **Transitions are tweens.** `from` replaces Vue's `*-enter-from`/`*-leave-to` classes, and
  TweenService does the animation.
- **Event names** follow Roblox: `onClick` maps to `Activated`, and `onX` connects event `X` or
  the changed signal of property `X`.
- **No SSR or hydration.** Rivue runs on the client.
- **Roblox extras** with no Vue equivalent:
  - `VirtualList`,
  - `useTween`/`useSpring`,
  - `useViewportSize`, `useInputType`, `useSafeArea`, `useSelection`,
  - `attributeRef`, `useTag`,
  - `Rivue.Remote`,
  - the Instance pool.
