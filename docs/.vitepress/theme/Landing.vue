<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from "vue"
import LandingDemo from "./LandingDemo.vue"
import FeatureArt from "./FeatureArt.vue"
import { useData, withBase } from "vitepress"
import uiIcon from "../../assets/packages/rivue-ui.webp"
import remoteIcon from "../../assets/packages/rivue-remote.webp"
import routerIcon from "../../assets/packages/rivue-router.webp"
import devtoolsIcon from "../../assets/packages/rivue-devtools.webp"
import devtoolsShot from "../../assets/diagrams/devtools-window.webp"

const { theme } = useData()
const landing = theme.value.landing
const icons: Record<string, string> = {
	RivueUI: uiIcon,
	RivueRemote: remoteIcon,
	RivueRouter: routerIcon,
	RivueDevTools: devtoolsIcon,
}

const compare = ref(0)

const version: string = theme.value.version
const stage = version.includes("-rc") ? "Release candidate" : version.includes("-") ? "Pre-release" : "Stable"
const RELEASES = "https://github.com/linhisreal/Rivue/releases/latest"
const installs = [
	{
		name: "Wally",
		file: "wally.toml",
		code: `[dependencies]\nRivueUI = "linhisreal/rivue-ui@${version}"`,
		next: "Then run wally install.",
	},
	{ name: "pesde", file: "Terminal", code: "pesde add linhisreal/rivue_ui", next: "Installs into your pesde project." },
	{
		name: "Rojo",
		file: "Terminal",
		code: "git submodule add https://github.com/linhisreal/Rivue vendor/Rivue",
		next: "Then map vendor/Rivue/packages/rivue-ui in default.project.json.",
	},
	{
		name: "Studio",
		file: "",
		code: "",
		next: "Drag RivueUI.rbxm into ReplicatedStorage. The release also has RivueRemote, RivueRouter and the DevTools plugin.",
	},
]
const install = ref(0)

const features = [
	{
		title: "Reactivity",
		text: "ref, reactive, computed and watch, named and used as in Vue 3.",
		link: "/guide/02-state",
		chapter: "State",
		art: "reactivity",
	},
	{
		title: "Components",
		text: "setup and render, props, emits, slots, provide/inject and every lifecycle hook.",
		link: "/guide/04-components",
		chapter: "Components",
		art: "components",
	},
	{
		title: "Styling and layout",
		text: "Style classes with hover and device variants, plus layout, padding and corner props.",
		link: "/guide/06-styling-and-layout",
		chapter: "Styling and layout",
		art: "styling",
	},
	{
		title: "Animation",
		text: "Transition, TransitionGroup, tweens and springs, with fade, slide and pop presets.",
		link: "/guide/07-effects-and-animation",
		chapter: "Effects and animation",
		art: "animation",
	},
	{
		title: "Long lists",
		text: "Keyed diffing, VirtualList for thousands of rows, and bindings for values that change every frame.",
		link: "/guide/09-performance-and-debugging",
		chapter: "Performance and debugging",
		art: "lists",
	},
	{
		title: "Typed",
		text: "Strict Luau throughout, with exported types and support for both type solvers.",
		link: "/API",
		chapter: "API reference",
		art: "typed",
	},
]
const codeShown = ref(new Set<number>())
const codeToggled = ref(new Set<number>())

function toggleCode(index: number) {
	codeToggled.value.add(index)
	if (!codeShown.value.delete(index)) codeShown.value.add(index)
}

function sceneAnimations(cell: HTMLElement) {
	const art = cell.querySelector<HTMLElement>(".rv-art")
	return (art?.getAnimations({ subtree: true }) ?? []).filter((anim) => anim instanceof CSSAnimation)
}

const playing = ref(new Set<number>())

async function playScene(index: number, cell: HTMLElement) {
	playing.value.add(index)
	await nextTick()
	for (const anim of sceneAnimations(cell)) anim.effect?.updateTiming({ iterations: Infinity })
}

function settleScene(index: number, cell: HTMLElement) {
	const anims = sceneAnimations(cell)
	for (const anim of anims) {
		const done = anim.effect?.getComputedTiming().currentIteration ?? 0
		anim.effect?.updateTiming({ iterations: done + 1 })
	}
	Promise.all(anims.map((anim) => anim.finished)).then(
		() => {
			if (!cell.matches(":hover, :focus-within")) playing.value.delete(index)
		},
		() => {},
	)
}

function enterFeature(index: number, event: Event) {
	playScene(index, event.currentTarget as HTMLElement)
}

function leaveFeature(index: number, event: Event) {
	settleScene(index, event.currentTarget as HTMLElement)
}

let lastMessage = ""
const timers = new WeakMap<Element, ReturnType<typeof setTimeout>>()

function report(button: HTMLElement, ok: boolean) {
	const tip = button.nextElementSibling as HTMLElement
	clearTimeout(timers.get(button))
	button.removeAttribute("data-copied")
	button.removeAttribute("data-failed")
	let message = ok ? "Copied" : "Copy failed"
	if (message === lastMessage) message += " "
	lastMessage = message
	tip.textContent = ""
	void button.offsetWidth
	button.setAttribute(ok ? "data-copied" : "data-failed", "")
	requestAnimationFrame(() => (tip.textContent = message))
	timers.set(
		button,
		setTimeout(() => {
			button.removeAttribute("data-copied")
			button.removeAttribute("data-failed")
			tip.textContent = ""
		}, 2000),
	)
}

async function copy(button: HTMLElement, target: HTMLElement) {
	const text = target.innerText.trim()
	if (!text) return
	try {
		await navigator.clipboard.writeText(text)
		report(button, true)
	} catch {
		report(button, false)
	}
}

function onCommand(event: any) {
	if (event.command === "--copy") copy(event.source, event.target)
}

function onClick(event: MouseEvent) {
	const button = (event.target as HTMLElement).closest<HTMLElement>('button[command="--copy"]')
	const target = button && document.getElementById(button.getAttribute("commandfor") ?? "")
	if (button && target) copy(button, target)
}

const native = typeof window !== "undefined" && "CommandEvent" in window

const LOOKUP_SHOWN = 10
const query = ref("")
const expanded = ref(false)
const lookupList = ref<HTMLElement>()
const GROUPS = [
	{ key: "learn", label: "Learn", icon: "M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2zM4 19V5M8 7h7" },
	{ key: "api", label: "API", icon: "M8 4H7a2 2 0 0 0-2 2v4l-2 2 2 2v4a2 2 0 0 0 2 2h1M16 4h1a2 2 0 0 1 2 2v4l2 2-2 2v4a2 2 0 0 1-2 2h-1" },
	{ key: "example", label: "Example", icon: "M7 4v16l13-8z" },
] as const

type LookupLink = { text: string; href: string }
type LookupItem = { task: string; learn: LookupLink[]; api: LookupLink[]; example: LookupLink[] }
const lookup: LookupItem[] = landing.lookup

const matches = computed(() => {
	const words = query.value.toLowerCase().split(/\s+/).filter(Boolean)
	if (!words.length) return lookup
	return lookup.filter((item) => {
		const text = [item.task, ...item.learn, ...item.api, ...item.example].map((part) => (typeof part === "string" ? part : part.text)).join(" ").toLowerCase()
		return words.every((word) => text.includes(word))
	})
})
const shown = computed(() => (query.value || expanded.value ? matches.value : matches.value.slice(0, LOOKUP_SHOWN)))
const linkHref = (href: string) => (href.startsWith("http") ? href : withBase(href))

async function showAll() {
	expanded.value = true
	await nextTick()
	lookupList.value?.children[LOOKUP_SHOWN]?.querySelector("a")?.focus()
}

onMounted(() => {
	if (native) document.addEventListener("command", onCommand, true)
	else document.addEventListener("click", onClick)
})
onUnmounted(() => {
	if (native) document.removeEventListener("command", onCommand, true)
	else document.removeEventListener("click", onClick)
})
</script>

<template>
	<main class="rv">
		<section class="rv-hero">
			<div class="rv-hero-copy">
				<a class="rv-hero-tag" :href="withBase('/INSTALLATION')">
					<code>v{{ version }}</code>
					{{ stage }}
					<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
				</a>
				<h1>
					The <span class="rv-accent">Vue-style</span> framework for
					<span class="rv-selected">
						Roblox UI
						<span class="rv-selection" aria-hidden="true">
							<i></i><i></i><i></i><i></i>
							<b>TextLabel</b>
						</span>
					</span>
				</h1>
				<p class="rv-lead">
					Build Roblox UI with Vue 3's components, refs and computed values. Change state and Rivue writes
					only the properties that changed.
				</p>
				<div class="rv-actions">
					<a class="rv-btn rv-btn-brand" :href="withBase('/introduction')">
						Get started
						<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
					</a>
					<a class="rv-btn" :href="withBase('/examples/counter')">Browse examples</a>
				</div>
				<ul class="rv-proof">
					<li>Strict Luau types</li>
					<li>Vue 3 API names</li>
					<li>DevTools plugin for Studio</li>
				</ul>
			</div>

			<div class="rv-get">
				<p class="rv-get-title">Install RivueUI</p>
				<div class="rv-get-tabs" role="group" aria-label="Install with">
					<button
						v-for="(option, i) in installs"
						:key="option.name"
						type="button"
						:aria-pressed="install === i"
						@click="install = i"
					>
						{{ option.name }}
					</button>
				</div>
				<div :key="install" class="rv-get-body">
					<template v-if="installs[install].code">
						<p class="rv-get-file">{{ installs[install].file }}</p>
						<div class="rv-get-code">
							<pre><code id="rv-install-text" tabindex="0" aria-label="Install code">{{ installs[install].code }}</code></pre>
							<span class="rv-copy">
								<button type="button" command="--copy" commandfor="rv-install-text" aria-label="Copy the install code">
									<svg class="rv-icon-copy" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 9h10v11H9zM5 15V4h10" /></svg>
									<svg class="rv-icon-check" viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 5 5 9-10" /></svg>
								</button>
								<span class="rv-tip" role="status"></span>
							</span>
						</div>
					</template>
					<a v-else class="rv-btn rv-get-download" :href="RELEASES">
						<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M5 20h14" /></svg>
						Download RivueUI.rbxm
					</a>
					<p class="rv-get-next">{{ installs[install].next }}</p>
				</div>
				<a class="rv-get-more" :href="withBase('/INSTALLATION')">All install options</a>
			</div>
		</section>

		<LandingDemo />

		<section class="rv-section">
			<h2>What RivueUI covers</h2>
			<ul class="rv-spec">
				<li
					v-for="(feature, i) in features"
					:key="feature.title"
					:class="[
						'rv-spec-cell',
						{
							'is-code': codeShown.has(i),
							'was-code': codeToggled.has(i) && !codeShown.has(i),
							'is-playing': playing.has(i),
						},
					]"
					@pointerenter="enterFeature(i, $event)"
					@pointerleave="leaveFeature(i, $event)"
					@focusin="enterFeature(i, $event)"
					@focusout="leaveFeature(i, $event)"
				>
					<div class="rv-spec-stage">
						<FeatureArt :kind="feature.art" :inert="codeShown.has(i)" />
						<div :id="`rv-code-${feature.art}`" class="rv-spec-code" :inert="!codeShown.has(i)">
							<div class="rv-spec-file">
								<span class="rv-spec-file-icon" aria-hidden="true"></span>{{ landing.featureCode[feature.art].file }}
							</div>
							<div class="rv-spec-src" v-html="landing.featureCode[feature.art].html"></div>
						</div>
						<span class="rv-spec-scan" aria-hidden="true"></span>
					</div>
					<div class="rv-spec-text">
						<button
							type="button"
							class="rv-spec-chip"
							:aria-pressed="codeShown.has(i)"
							:aria-controls="`rv-code-${feature.art}`"
							@click="toggleCode(i)"
						>
							<span class="rv-spec-dot" aria-hidden="true"></span>
							<span class="rv-visually-hidden">Show the code for </span>{{ feature.title }}
						</button>
						<p>{{ feature.text }}</p>
						<a :href="withBase(feature.link)">
							{{ feature.chapter }}
							<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
						</a>
					</div>
				</li>
			</ul>
		</section>

		<section class="rv-section">
			<h2>Compared with Vue, React-lua and Fusion</h2>
			<p class="rv-sub">
				The same counter in all four.
				<a :href="withBase('/COMING-FROM-REACT')">Coming from React-lua or Fusion</a> and
				<a :href="withBase('/VUE')">the Vue cheat sheet</a> explain what differs.
			</p>
			<div class="rv-window rv-compare">
				<div class="rv-compare-tabs" role="group" aria-label="Framework">
					<button
						v-for="(option, i) in landing.compare"
						:key="option.name"
						type="button"
						:aria-pressed="compare === i"
						@click="compare = i"
					>
						{{ option.name }}
					</button>
				</div>
				<div :key="compare" class="rv-code" v-html="landing.compare[compare].html"></div>
			</div>
		</section>

		<section class="rv-section">
			<h2>Packages</h2>
			<p class="rv-sub">RivueUI is the framework. The others are optional and versioned on their own.</p>
			<div class="rv-bento">
				<a
					v-for="pkg in landing.packages"
					:key="pkg.name"
					:class="['rv-tile', `rv-tile-${pkg.name.toLowerCase()}`]"
					:href="withBase(pkg.link)"
				>
					<div class="rv-tile-head">
						<img :src="icons[pkg.name]" alt="" width="36" height="36" />
						<span class="rv-tile-name">
							<h3>{{ pkg.name }}</h3>
							<span class="rv-tile-version">{{ pkg.version || "Studio plugin" }}</span>
						</span>
						<svg class="rv-tile-go" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
					</div>
					<p>{{ pkg.text }}</p>
					<div v-if="pkg.name === 'RivueUI'" class="rv-pkg-foot" aria-hidden="true">
						<code><span class="rv-tok-ns">Rivue</span>.<span class="rv-tok-fn">createApp</span>(App):<span class="rv-tok-fn">mount</span>(gui)</code>
					</div>
					<div v-else-if="pkg.name === 'RivueRemote'" class="rv-pkg-foot rv-pkg-router" aria-hidden="true">
						<span>client</span>
						<svg viewBox="0 0 24 24"><path d="M4 12h15M14 7l5 5-5 5" /></svg>
						<span class="rv-pkg-current">shop:buy</span>
						<svg viewBox="0 0 24 24"><path d="M4 12h15M14 7l5 5-5 5" /></svg>
						<span>server</span>
					</div>
					<div v-else-if="pkg.name === 'RivueRouter'" class="rv-pkg-foot rv-pkg-router" aria-hidden="true">
						<span>lobby</span>
						<svg viewBox="0 0 24 24"><path d="m9 6 6 6-6 6" /></svg>
						<span class="rv-pkg-current">shop</span>
						<svg viewBox="0 0 24 24"><path d="m9 6 6 6-6 6" /></svg>
						<span class="rv-pkg-next">inventory</span>
					</div>
					<span v-if="pkg.name === 'RivueDevTools'" class="rv-tile-shot">
						<img
							:src="devtoolsShot"
							alt="The RivueDevTools Components tab: the component tree with render counts and the selected component's details"
							loading="lazy"
							width="4080"
							height="2580"
						/>
					</span>
				</a>
			</div>
		</section>

		<section class="rv-section">
			<h2>I want to…</h2>
			<p class="rv-sub">Find the guide chapter, the API entry and a working example for a task.</p>
			<div class="rv-lookup">
				<label class="rv-lookup-search">
					<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>
					<span class="rv-visually-hidden">Filter tasks</span>
					<input v-model="query" type="search" :placeholder="`Filter ${lookup.length} tasks`" spellcheck="false" />
					<span class="rv-lookup-count" aria-live="polite">{{ query ? `${matches.length} of ${lookup.length}` : "" }}</span>
				</label>
				<ul ref="lookupList" class="rv-lookup-list">
					<li v-for="item in shown" :key="item.task">
						<span class="rv-lookup-task">{{ item.task }}</span>
						<span class="rv-lookup-links">
							<template v-for="group in GROUPS" :key="group.key">
								<span v-if="item[group.key].length" class="rv-lookup-group" :title="group.label">
									<svg viewBox="0 0 24 24" aria-hidden="true"><path :d="group.icon" /></svg>
									<span>
										<span class="rv-visually-hidden">{{ group.label }}: </span>
										<template v-for="(link, i) in item[group.key]" :key="link.href">
											<template v-if="i">, </template>
											<a :href="linkHref(link.href)">{{ link.text }}</a>
										</template>
									</span>
								</span>
							</template>
						</span>
					</li>
				</ul>
				<p v-if="!matches.length" class="rv-lookup-empty">
					Nothing matches “{{ query }}”. Try the <a :href="withBase('/API')">API reference</a> or search with Ctrl K.
				</p>
				<button v-if="!query && !expanded && lookup.length > LOOKUP_SHOWN" type="button" class="rv-lookup-more" @click="showAll">
					Show all {{ lookup.length }}
				</button>
			</div>
		</section>
	</main>
</template>
