<script setup lang="ts">
import { onMounted, onUnmounted, ref } from "vue"
import LandingDemo from "./LandingDemo.vue"
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
		text: "ref, reactive, computed and watch. Only components that read a changed value re-render.",
		link: "/guide/02-state",
		icon: "M13 2 4 14h7l-1 8 9-12h-7z",
	},
	{
		title: "Components",
		text: "setup and render, props, emits, slots, provide/inject and every lifecycle hook.",
		link: "/guide/04-components",
		icon: "M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z",
	},
	{
		title: "Styling and layout",
		text: "Style classes with hover and device variants, plus layout, flex, padding and corner props.",
		link: "/guide/06-styling-and-layout",
		icon: "M4 6h16M4 12h10M4 18h13",
	},
	{
		title: "Animation",
		text: "Transition, TransitionGroup, tweens and springs, with fade, slide and pop presets.",
		link: "/guide/07-effects-and-animation",
		icon: "M3 17c4 0 4-10 9-10s5 10 9 10",
	},
	{
		title: "Long lists",
		text: "Keyed diffing, VirtualList for thousands of rows, and bindings for values that change every frame.",
		link: "/guide/09-performance-and-debugging",
		icon: "M4 5h16M4 10h16M4 15h16M4 20h16",
	},
	{
		title: "Typed",
		text: "Strict Luau throughout, with exported types and support for both type solvers.",
		link: "/API",
		icon: "m8 8-4 4 4 4M16 8l4 4-4 4M13 5l-2 14",
	},
]

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

const LOOKUP_SHOWN = 6

// The "I want to…" table comes from the README; on the site it starts short with a button for the rest.
function shortenLookup() {
	const table = document.querySelector<HTMLTableElement>(".VPHome .vp-doc table:not(:first-of-type)")
	const rows = table?.tBodies[0]?.rows.length ?? 0
	if (!table || rows <= LOOKUP_SHOWN || table.nextElementSibling?.classList.contains("rv-more")) return
	table.classList.add("rv-short")
	const more = document.createElement("button")
	more.type = "button"
	more.className = "rv-more"
	more.textContent = `Show all ${rows}`
	more.addEventListener("click", () => {
		table.classList.remove("rv-short")
		more.remove()
	})
	table.after(more)
}

onMounted(() => {
	shortenLookup()
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
				Write UI as components in Luau. When state changes, Rivue re-renders the components that use it and
				updates their Instances.
			</p>
			<div class="rv-actions">
				<a class="rv-btn rv-btn-brand" :href="withBase('/guide/01-introduction')">
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
					<code id="rv-install-text">{{ installs[install].line }}</code>
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
					<svg viewBox="0 0 24 24" aria-hidden="true"><path :d="feature.icon" /></svg>
					<div>
						<a :href="withBase(feature.link)">{{ feature.title }}</a>
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
						<h3>
							{{ pkg.name }} <small v-if="pkg.version">{{ pkg.version }}</small>
						</h3>
					</div>
					<p>{{ pkg.text }}</p>
					<code v-if="pkg.example">{{ pkg.example }}</code>
					<img
						v-if="pkg.name === 'RivueDevTools'"
						class="rv-tile-shot"
						:src="devtoolsShot"
						alt="The RivueDevTools window in Studio, showing a component tree and the selected component's state"
						loading="lazy"
					/>
				</a>
			</div>
		</section>

		<section class="rv-section rv-lookup-title">
			<h2>I want to…</h2>
			<p class="rv-sub">Find the guide chapter, the API entry and a working example for a task.</p>
		</section>
	</div>
</template>
