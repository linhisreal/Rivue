<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from "vue"
import { withBase } from "vitepress"
import LandingDemo from "./LandingDemo.vue"
import FeatureArt from "./FeatureArt.vue"
import { ICONS } from "./icons"
import { readStorage, writeStorage } from "./storage"
import { useTheme, type Landing, type Scene } from "./types"
import uiIcon from "../../assets/packages/rivue-ui.webp"
import remoteIcon from "../../assets/packages/rivue-remote.webp"
import routerIcon from "../../assets/packages/rivue-router.webp"
import devtoolsIcon from "../../assets/packages/rivue-devtools.webp"
import devtoolsShot from "../../assets/diagrams/devtools-window.webp"

const { theme } = useTheme()
const landing = theme.value.landing
const icons: Record<string, string> = {
	RivueUI: uiIcon,
	RivueRemote: remoteIcon,
	RivueRouter: routerIcon,
	RivueDevTools: devtoolsIcon,
}

const compare = ref(0)

const { version, repo } = theme.value
const releases = `${repo.url}/releases/latest`

type Install = { name: string; line?: { code: string; where: string; icon: "file" | "terminal" } }

const installs: Install[] = [
	{ name: "Wally", line: { code: `RivueUI = "linhisreal/rivue-ui@${version}"`, where: "wally.toml", icon: "file" } },
	{ name: "pesde", line: { code: "pesde add linhisreal/rivue_ui", where: "Terminal", icon: "terminal" } },
	{ name: "Rojo", line: { code: `git submodule add ${repo.url} vendor/Rivue`, where: "Terminal", icon: "terminal" } },
	{ name: "Studio" },
]
const INSTALL_KEY = "rivue-install-tab"
const install = ref(0)
const installLine = computed(() => installs[install.value].line)
watch(install, (i) => writeStorage(INSTALL_KEY, installs[i].name))

type Feature = { title: string; text: string; link: string; art: Scene }

const features: Feature[] = [
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
		text: "Style classes with hover and device variants, plus layout, padding and corner props.",
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

type CommandEvent = Event & { command: string; source: HTMLElement | null }

function onCommand(event: Event) {
	const { command, source, target } = event as CommandEvent
	if (command === "--copy" && source && target instanceof HTMLElement) copy(source, target)
}

function onClick(event: MouseEvent) {
	const button = (event.target as Element | null)?.closest<HTMLElement>('button[command="--copy"]')
	const target = button && document.getElementById(button.getAttribute("commandfor") ?? "")
	if (button && target) copy(button, target)
}

const native = typeof window !== "undefined" && "CommandEvent" in window

const LOOKUP_SHOWN = 10
const query = ref("")
const expanded = ref(false)
const lookupList = ref<HTMLElement>()
const GROUPS = [
	{ key: "learn", label: "Learn", icon: ICONS.guide },
	{ key: "api", label: "API", icon: ICONS.api },
	{ key: "example", label: "Example", icon: ICONS.example },
] as const

const lookup: Landing["lookup"] = landing.lookup

const matches = computed(() => {
	const words = query.value.toLowerCase().split(/\s+/).filter(Boolean)
	if (!words.length) return lookup
	return lookup.filter((item) => {
		const text = [item.task, ...[...item.learn, ...item.api, ...item.example].map((link) => link.text)].join(" ").toLowerCase()
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
	const saved = installs.findIndex((option) => option.name === readStorage(INSTALL_KEY))
	if (saved > 0) install.value = saved
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
			<h1>
				The <span class="rv-accent">Vue-style</span> framework for
				<span class="rv-selected">
					Roblox UI
					<span class="rv-selection" aria-hidden="true">
						<span class="rv-marquee-x"><span class="rv-marquee"></span></span>
						<span class="rv-cursor-x">
							<span class="rv-cursor-y">
								<svg class="rv-cursor" viewBox="0 0 16 20"><path d="M1 1v15l4-4 3 7 3-1-3-7h6z" /></svg>
							</span>
						</span>
						<i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i>
						<b>TextLabel</b>
					</span>
				</span>
			</h1>
			<p class="rv-lead">{{ landing.lead }}</p>
			<div class="rv-actions">
				<a class="rv-btn rv-btn-brand" :href="withBase('/introduction')">
					Get started
					<svg viewBox="0 0 24 24" aria-hidden="true"><path :d="ICONS.arrow" /></svg>
				</a>
				<a class="rv-btn" :href="withBase('/examples/counter')">Browse examples</a>
			</div>

			<div class="rv-install">
				<div class="rv-install-bar">
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
					</div>
					<a class="rv-install-guide" :href="withBase('/INSTALLATION')">
						Install guide
						<svg viewBox="0 0 24 24" aria-hidden="true"><path :d="ICONS.arrow" /></svg>
					</a>
				</div>
				<div :key="install" class="rv-install-line">
					<template v-if="installLine">
						<code id="rv-install-text" tabindex="0" aria-label="Install line">{{ installLine.code }}</code>
						<span class="rv-install-where" :title="`Paste into ${installLine.where}`">
							<svg v-if="installLine.icon === 'file'" viewBox="0 0 24 24" aria-hidden="true"><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8zM14 3v5h5M9 13h6M9 17h4" /></svg>
							<svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m5 8 4 4-4 4M12 17h7" /></svg>
							<span class="rv-visually-hidden">Paste into {{ installLine.where }}</span>
						</span>
						<span class="rv-copy">
							<button type="button" command="--copy" commandfor="rv-install-text" aria-label="Copy the install line">
								<svg class="rv-icon-copy" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 9h10v11H9zM5 15V4h10" /></svg>
								<svg class="rv-icon-check" viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 5 5 9-10" /></svg>
							</button>
							<span class="rv-tip" role="status"></span>
						</span>
					</template>
					<p v-else class="rv-install-studio">
						<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M5 20h14" /></svg>
						<span><a :href="releases">Download RivueUI.rbxm</a> and drag it into ReplicatedStorage</span>
					</p>
				</div>
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
						<button
							type="button"
							class="rv-spec-chip"
							:aria-pressed="codeShown.has(i)"
							:aria-controls="`rv-code-${feature.art}`"
							:aria-label="`Show the code for ${feature.title}`"
							@click="toggleCode(i)"
						>
							<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m8 7-5 5 5 5M16 7l5 5-5 5" /></svg>
						</button>
					</div>
					<div class="rv-spec-text">
						<a class="rv-spec-title" :href="withBase(feature.link)">
							{{ feature.title }}
							<svg viewBox="0 0 24 24" aria-hidden="true"><path :d="ICONS.arrow" /></svg>
						</a>
						<p>{{ feature.text }}</p>
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
						<div class="rv-tile-name">
							<h3>{{ pkg.name }}</h3>
							<span class="rv-tile-version">{{ pkg.version || "Studio plugin" }}</span>
						</div>
						<svg class="rv-tile-go" viewBox="0 0 24 24" aria-hidden="true"><path :d="ICONS.arrow" /></svg>
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
