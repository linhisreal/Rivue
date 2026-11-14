<script setup lang="ts">
import { onMounted, onUnmounted, ref } from "vue"
import { useData, withBase } from "vitepress"
import uiIcon from "../../assets/packages/rivue-ui.webp"
import remoteIcon from "../../assets/packages/rivue-remote.webp"
import routerIcon from "../../assets/packages/rivue-router.webp"
import devtoolsIcon from "../../assets/packages/rivue-devtools.webp"

const { theme } = useData()
const landing = theme.value.landing
const icons: Record<string, string> = {
	RivueUI: uiIcon,
	RivueRemote: remoteIcon,
	RivueRouter: routerIcon,
	RivueDevTools: devtoolsIcon,
}

const clicks = ref(0)

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
			<h1>The <span class="rv-accent">Vue-style</span> framework for Roblox UI</h1>
			<p class="rv-lead">
				Write UI as components in Luau. When state changes, Rivue re-renders the components that use it and
				updates their Instances.
			</p>
			<div class="rv-actions">
				<a class="rv-btn rv-btn-brand" :href="withBase('/guide/01-introduction')">Get started</a>
				<a class="rv-btn" :href="withBase('/API')">API reference</a>
				<a class="rv-btn" :href="withBase('/VUE')">Coming from Vue</a>
			</div>
			<div class="rv-install">
				<code id="rv-install-text">RivueUI = "linhisreal/rivue-ui@{{ landing.version }}"</code>
				<span class="rv-copy">
					<button type="button" command="--copy" commandfor="rv-install-text" aria-label="Copy the Wally dependency line">
						<svg class="rv-icon-copy" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 9h10v11H9zM5 15V4h10" /></svg>
						<svg class="rv-icon-check" viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 5 5 9-10" /></svg>
					</button>
					<span class="rv-tip" role="status"></span>
				</span>
			</div>
		</section>

		<section class="rv-showcase" aria-label="Example">
			<div class="rv-window">
				<div class="rv-window-bar"><b>Counter.luau</b></div>
				<div class="rv-code" v-html="landing.counter"></div>
			</div>
			<div class="rv-result">
				<p class="rv-eyebrow">Result</p>
				<button type="button" class="rv-roblox-button" @click="clicks++">Clicked {{ clicks }} times</button>
				<p class="rv-note">Press it. Only the button's Text is written when the count changes.</p>
			</div>
		</section>

		<section class="rv-section">
			<h2>Everything a game UI needs</h2>
			<div class="rv-grid">
				<a v-for="feature in features" :key="feature.title" class="rv-card-link" :href="withBase(feature.link)">
					<article class="rv-card">
						<svg viewBox="0 0 24 24" aria-hidden="true"><path :d="feature.icon" /></svg>
						<h3>{{ feature.title }}</h3>
						<p>{{ feature.text }}</p>
					</article>
				</a>
			</div>
		</section>

		<section class="rv-section">
			<h2>Familiar if you know Vue</h2>
			<p class="rv-sub">
				The same ideas, in Luau. <a :href="withBase('/VUE')">The cheat sheet</a> lists where Rivue differs.
			</p>
			<div class="rv-compare">
				<div class="rv-window">
					<div class="rv-window-bar"><b>Vue</b></div>
					<div class="rv-code" v-html="landing.vue"></div>
				</div>
				<div class="rv-window">
					<div class="rv-window-bar"><b>Rivue</b></div>
					<div class="rv-code" v-html="landing.rivue"></div>
				</div>
			</div>
		</section>

		<section class="rv-section">
			<h2>Packages</h2>
			<p class="rv-sub">RivueUI is the framework. The others are optional and versioned on their own.</p>
			<div class="rv-grid rv-grid-4">
				<a v-for="pkg in landing.packages" :key="pkg.name" class="rv-card-link" :href="withBase(pkg.link)">
					<article class="rv-card rv-package">
						<img :src="icons[pkg.name]" alt="" width="44" height="44" />
						<h3>
							{{ pkg.name }} <small v-if="pkg.version">{{ pkg.version }}</small>
						</h3>
						<p>{{ pkg.text }}</p>
					</article>
				</a>
			</div>
		</section>

		<section class="rv-section rv-lookup-title">
			<h2>I want to…</h2>
			<p class="rv-sub">Find the guide chapter, the API entry and a working example for a task.</p>
		</section>
	</div>
</template>
