[Docs](README.md) › **API reference**

# API Reference

Everything on the module returned by `require(game.ReplicatedStorage.Rivue)`. Each entry has its
type, details and an example. New to Rivue? Start with the [Guide](GUIDE.md). Coming from Vue?
See [Rivue for Vue developers](VUE.md). For conventions, see [Style rules](guide/11-style-rules.md).

## Reactivity

**[Core](api/reactivity-core.md)**
[ref()](api/reactivity-core.md#ref) ·
[computed()](api/reactivity-core.md#computed) ·
[reactive()](api/reactivity-core.md#reactive) ·
[readonly()](api/reactivity-core.md#readonly) ·
[watchEffect()](api/reactivity-core.md#watcheffect) ·
[watchPostEffect()](api/reactivity-core.md#watchposteffect) ·
[watchSyncEffect()](api/reactivity-core.md#watchsynceffect) ·
[watch()](api/reactivity-core.md#watch) ·
[onWatcherCleanup()](api/reactivity-core.md#onwatchercleanup)

**[Utilities](api/reactivity-utilities.md)**
[isRef()](api/reactivity-utilities.md#isref) ·
[unref()](api/reactivity-utilities.md#unref) ·
[toRef()](api/reactivity-utilities.md#toref) ·
[toValue()](api/reactivity-utilities.md#tovalue) ·
[toRefs()](api/reactivity-utilities.md#torefs) ·
[proxyRefs()](api/reactivity-utilities.md#proxyrefs) ·
[isProxy()](api/reactivity-utilities.md#isproxy) ·
[isReactive()](api/reactivity-utilities.md#isreactive) ·
[isReadonly()](api/reactivity-utilities.md#isreadonly)

**[Array Helpers](api/array.md)**
[push()](api/array.md#arraypush) ·
[insert()](api/array.md#arrayinsert) ·
[remove()](api/array.md#arrayremove) ·
[removeValue()](api/array.md#arrayremovevalue) ·
[removeWhere()](api/array.md#arrayremovewhere) ·
[splice()](api/array.md#arraysplice) ·
[move()](api/array.md#arraymove) ·
[sort()](api/array.md#arraysort) ·
[clear()](api/array.md#arrayclear) ·
[indexOf()](api/array.md#arrayindexof) ·
[find()](api/array.md#arrayfind) ·
[filter() / map() / count()](api/array.md#arrayfilter--arraymap--arraycount)

**[Advanced](api/reactivity-advanced.md)**
[shallowRef()](api/reactivity-advanced.md#shallowref) ·
[triggerRef()](api/reactivity-advanced.md#triggerref) ·
[customRef()](api/reactivity-advanced.md#customref) ·
[shallowReactive()](api/reactivity-advanced.md#shallowreactive) ·
[shallowReadonly()](api/reactivity-advanced.md#shallowreadonly) ·
[isShallow()](api/reactivity-advanced.md#isshallow) ·
[toRaw()](api/reactivity-advanced.md#toraw) ·
[markRaw()](api/reactivity-advanced.md#markraw) ·
[effect()](api/reactivity-advanced.md#effect) ·
[effectScope()](api/reactivity-advanced.md#effectscope) ·
[getCurrentScope()](api/reactivity-advanced.md#getcurrentscope) ·
[onScopeDispose()](api/reactivity-advanced.md#onscopedispose)

## Components and Rendering

**[Render Function](api/render-function.md)**
[h()](api/render-function.md#h) ·
[Element props](api/render-function.md#element-props) ·
[Fragment](api/render-function.md#fragment) ·
[hIf()](api/render-function.md#hif) ·
[hFor()](api/render-function.md#hfor) ·
[mergeProps()](api/render-function.md#mergeprops) ·
[cloneVNode()](api/render-function.md#clonevnode) ·
[isVNode()](api/render-function.md#isvnode) ·
[resolveComponent()](api/render-function.md#resolvecomponent) ·
[Function components](api/render-function.md#function-components)

**[Components](api/component.md)**
[defineComponent()](api/component.md#definecomponent) ·
[props](api/component.md#props) ·
[emits](api/component.md#emits) ·
[setup()](api/component.md#setup) ·
[render()](api/component.md#render) ·
[components](api/component.md#components) ·
[styles](api/component.md#styles) ·
[Setup context](api/component.md#setup-context) ·
[Slots](api/component.md#slots) ·
[provide()](api/component.md#provide) ·
[inject()](api/component.md#inject) ·
[hasInjectionContext()](api/component.md#hasinjectioncontext) ·
[useTemplateRef()](api/component.md#usetemplateref) ·
[useAttrs()](api/component.md#useattrs) ·
[useSlots()](api/component.md#useslots) ·
[defineModel()](api/component.md#definemodel) ·
[useModel()](api/component.md#usemodel) ·
[useId()](api/component.md#useid) ·
[getCurrentInstance()](api/component.md#getcurrentinstance) ·
[defineAsyncComponent()](api/component.md#defineasynccomponent)

**[Lifecycle Hooks](api/lifecycle.md)**
[onMounted()](api/lifecycle.md#onmounted) ·
[onUpdated()](api/lifecycle.md#onupdated) ·
[onUnmounted()](api/lifecycle.md#onunmounted) ·
[onBeforeMount()](api/lifecycle.md#onbeforemount) ·
[onBeforeUpdate()](api/lifecycle.md#onbeforeupdate) ·
[onBeforeUnmount()](api/lifecycle.md#onbeforeunmount) ·
[onErrorCaptured()](api/lifecycle.md#onerrorcaptured) ·
[onActivated()](api/lifecycle.md#onactivated) ·
[onDeactivated()](api/lifecycle.md#ondeactivated) ·
[onRenderTracked()](api/lifecycle.md#onrendertracked) ·
[onRenderTriggered()](api/lifecycle.md#onrendertriggered) ·
[onTransition()](api/lifecycle.md#ontransition)

**[Built-in Components](api/builtins.md)**
[Transition](api/builtins.md#transition) ·
[TransitionGroup](api/builtins.md#transitiongroup) ·
[KeepAlive](api/builtins.md#keepalive) ·
[Teleport](api/builtins.md#teleport) ·
[Suspense](api/builtins.md#suspense) ·
[VirtualList](api/builtins.md#virtuallist)

**[Directives](api/directives.md)**
[vShow](api/directives.md#vshow) ·
[vFocus](api/directives.md#vfocus) ·
[vSelect](api/directives.md#vselect) ·
[vClickOutside](api/directives.md#vclickoutside) ·
[vDrag](api/directives.md#vdrag) ·
[vPreload](api/directives.md#vpreload) ·
[vFadeIn](api/directives.md#vfadein) ·
[Custom directives](api/directives.md#custom-directives) ·
[vModelText()](api/directives.md#vmodeltext) ·
[vModelProp()](api/directives.md#vmodelprop)

## Application

**[Application](api/application.md)**
[createApp()](api/application.md#createapp) ·
[mount()](api/application.md#mount) ·
[app:mount()](api/application.md#appmount) ·
[app:mountToPlayerGui()](api/application.md#appmounttoplayergui) ·
[app:unmount()](api/application.md#appunmount) ·
[app:onUnmount()](api/application.md#apponunmount) ·
[app:component()](api/application.md#appcomponent) ·
[app:styles()](api/application.md#appstyles) ·
[app:directive()](api/application.md#appdirective) ·
[app:use()](api/application.md#appuse) ·
[app:provide()](api/application.md#appprovide) ·
[app:runWithContext()](api/application.md#apprunwithcontext) ·
[app:printTree()](api/application.md#appprinttree) ·
[app.config](api/application.md#appconfigerrorhandler) ·
[Pooling options](api/application.md#pooling-options)

**[Scheduler](api/scheduler.md)**
[nextTick()](api/scheduler.md#nexttick) ·
[queueJob()](api/scheduler.md#queuejob) ·
[Update timing](api/scheduler.md#update-timing)

## Roblox

**[Roblox Composables](api/roblox.md)**
[useViewportSize()](api/roblox.md#useviewportsize) ·
[useInputType()](api/roblox.md#useinputtype) ·
[useSafeArea()](api/roblox.md#usesafearea) ·
[useSelection()](api/roblox.md#useselection) ·
[useTween()](api/roblox.md#usetween) ·
[useSpring()](api/roblox.md#usespring) ·
[attributeRef()](api/roblox.md#attributeref) ·
[useTag()](api/roblox.md#usetag) ·
[onRenderStepped() / onHeartbeat() / onStepped()](api/roblox.md#onrenderstepped--onheartbeat--onstepped) ·
[useTheme()](api/roblox.md#usetheme) ·
[useStyles()](api/roblox.md#usestyles)

**[RivueRemote](api/remote.md)** (separate package)
[setupServer()](api/remote.md#remotesetupserver) ·
[handle()](api/remote.md#remotehandle) ·
[request()](api/remote.md#remoterequest) ·
[fire()](api/remote.md#remotefire) ·
[on()](api/remote.md#remoteon) ·
[Payloads and errors](api/remote.md#payloads-and-errors)

**[Instance Pool](api/pool.md)**
[configure()](api/pool.md#poolconfigure) ·
[warmup()](api/pool.md#poolwarmup) ·
[acquire()](api/pool.md#poolacquire--poolacquiremultiple) ·
[release()](api/pool.md#poolrelease--poolreleasemultiple) ·
[clear()](api/pool.md#poolclear) ·
[getStatistics()](api/pool.md#poolgetstatistics) ·
[validateHealth()](api/pool.md#poolvalidatehealth) ·
[setResetHandler()](api/pool.md#poolsetresethandler) ·
[setEventHook()](api/pool.md#poolseteventhook) ·
[snapshots](api/pool.md#poolcreatesnapshot--poolrestoresnapshot)

## Utilities

**[Utilities and Debugging](api/utilities.md)**
[Rivue.dev](api/utilities.md#rivuedev) ·
[printTree()](api/utilities.md#printtree) ·
[debug.enabled](api/utilities.md#debugenabled) ·
[inspect()](api/utilities.md#inspect) ·
[prettyPrint()](api/utilities.md#prettyprint) ·
[assertInvariant()](api/utilities.md#assertinvariant) ·
[debug.measure()](api/utilities.md#debugmeasure) ·
[debug.log()](api/utilities.md#debuglog) ·
[debug.formatError()](api/utilities.md#debugformaterror) ·
[utils.debounce()](api/utilities.md#utilsdebounce) ·
[utils.throttle()](api/utilities.md#utilsthrottle) ·
[utils.nextFrame()](api/utilities.md#utilsnextframe) ·
[utils.useRaf()](api/utilities.md#utilsuseraf) ·
[utils.filterForClient()](api/utilities.md#utilsfilterforclient) ·
[utils.shallowEqual()](api/utilities.md#utilsshallowequal) ·
[utils.profiler](api/utilities.md#utilsprofiler) ·
[iterArray()](api/utilities.md#iterarray) ·
[testing.trigger()](api/utilities.md#testingtrigger) ·
[Types](api/utilities.md#types)
