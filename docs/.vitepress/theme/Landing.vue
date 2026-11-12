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

const installs = [
	{ name: "Wally", line: `RivueUI = "linhisreal/rivue-ui@${theme.value.version}"` },
	{ name: "pesde", line: "pesde add linhisreal/rivue_ui" },
	{ name: "Rojo", line: "git submodule add https://github.com/linhisreal/Rivue vendor/Rivue" },
]
const install = ref(0)

const features = [
	{
		title: "Reactivity",
		text: "ref, reactive, computed and watch, named and used as in Vue 3.",
		link: "/guide/02-state",
		art: "reactivity",
	},
	{
		title: "Components",
		text: "setup and render, props, emits, slots, provide/inject and every lifecycle hook.",
		link: "/guide/04-components",
		art: "components",
	},
	{
		title: "Styling and layout",
		text: "Style classes with hover and device variants, plus layout, flex, padding and corner props.",
		link: "/guide/06-styling-and-layout",
		art: "styling",
	},
	{
		title: "Animation",
		text: "Transition, TransitionGroup, tweens and springs, with fade, slide and pop presets.",
		link: "/guide/07-effects-and-animation",
		art: "animation",
	},
	{
		title: "Long lists",
		text: "Keyed diffing, VirtualList for thousands of rows, and bindings for values that change every frame.",
		link: "/guide/09-performance-and-debugging",
		art: "lists",
	},
	{
		title: "Typed",
		text: "Strict Luau throughout, with exported types and support for both type solvers.",
		link: "/API",
		art: "typed",
	},
]

function sceneAnimations(el: HTMLElement) {
	return el.getAnimations({ subtree: true }).filter((anim) => anim instanceof CSSAnimation)
}

function playScene(event: Event) {
	const el = event.currentTarget as HTMLElement
	for (const anim of sceneAnimations(el)) anim.effect?.updateTiming({ iterations: Infinity })
	el.classList.add("is-playing")
}

function settleScene(event: Event) {
	const el = event.currentTarget as HTMLElement
	const anims = sceneAnimations(el)
	for (const anim of anims) {
		const done = anim.effect?.getComputedTiming().currentIteration ?? 0
		anim.effect?.updateTiming({ iterations: done + 1 })
	}
	Promise.all(anims.map((anim) => anim.finished)).then(
		() => {
			if (!el.matches(":hover, :focus-visible")) el.classList.remove("is-playing")
		},
		() => {},
	)
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
	<div class="rv">
		<section class="rv-hero">
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
				Write your UI as Luau components. When state changes, Rivue <span class="rv-nowrap">re-renders</span> only the
				components that read it and writes just the properties that changed.
			</p>
			<div class="rv-actions">
				<a class="rv-btn rv-btn-brand" :href="withBase('/introduction')">
					Get started
					<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
				</a>
			</div>
			<div class="rv-install-block">
				<div class="rv-install-tabs" role="group" aria-label="Install with">
					<button
						v-for="(option, i) in installs"
						:key="option.name"
						type="button"
						:aria-pressed="install === i"
						@click="install = i"
					>
						{{ option.name }}
					</button>
					<a :href="withBase('/INSTALLATION')">More options</a>
				</div>
				<div class="rv-install">
					<code id="rv-install-text" :key="install">{{ installs[install].line }}</code>
					<span class="rv-copy">
						<button type="button" command="--copy" commandfor="rv-install-text" aria-label="Copy the install line">
							<svg class="rv-icon-copy" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 9h10v11H9zM5 15V4h10" /></svg>
							<svg class="rv-icon-check" viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 5 5 9-10" /></svg>
						</button>
						<span class="rv-tip" role="status"></span>
					</span>
				</div>
			</div>
		</section>

		<LandingDemo />

		<section class="rv-section">
			<h2>What RivueUI covers</h2>
			<ul class="rv-features">
				<li v-for="feature in features" :key="feature.title">
					<a
						class="rv-feature"
						:href="withBase(feature.link)"
						@pointerenter="playScene"
						@pointerleave="settleScene"
						@focus="playScene"
						@blur="settleScene"
					>
						<FeatureArt :kind="feature.art" />
						<strong>{{ feature.title }}</strong>
						<span>{{ feature.text }}</span>
					</a>
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
	</div>
</template>
