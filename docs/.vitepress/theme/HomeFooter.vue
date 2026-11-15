<script setup lang="ts">
import { useData, withBase } from "vitepress"

const REPO = "https://github.com/linhisreal/Rivue"
const { frontmatter, theme } = useData()

const steps = [
	{ title: "Install RivueUI", text: "With Wally, pesde, Rojo or the Studio model." },
	{ title: "Write Hud.client.luau", text: "A Counter component with one ref." },
	{ title: "Press Play", text: "Click the button and the text counts up." },
]

const columns = [
	{
		title: "Docs",
		links: [
			{ text: "Installation", href: withBase("/INSTALLATION") },
			{ text: "Guide", href: withBase("/guide/01-introduction") },
			{ text: "API reference", href: withBase("/API") },
			{ text: "Coming from Vue", href: withBase("/VUE") },
		],
	},
	{
		title: "Packages",
		links: [
			{ text: "RivueUI", href: withBase("/guide/01-introduction") },
			{ text: "RivueRemote", href: withBase("/api/remote") },
			{ text: "RivueRouter", href: withBase("/api/router") },
			{ text: "RivueDevTools", href: withBase("/DEVTOOLS") },
		],
	},
	{
		title: "Project",
		links: [
			{ text: "GitHub", href: REPO },
			{ text: "Releases", href: `${REPO}/releases` },
			{ text: "Examples", href: `${REPO}/tree/main/examples` },
			{ text: "License", href: `${REPO}/blob/main/LICENSE.md` },
		],
	},
]
</script>

<template>
	<section v-if="frontmatter.layout === 'home'" class="rv-cta" aria-labelledby="rv-cta-title">
		<div class="rv-cta-inner">
			<div class="rv-cta-copy">
				<h2 id="rv-cta-title">Build your first screen</h2>
				<p>Chapter 1 walks you through all three steps, from an empty place to a component that updates itself.</p>
				<div class="rv-cta-actions">
					<a class="rv-btn rv-btn-brand" :href="withBase('/guide/01-introduction')">Get started</a>
					<a class="rv-cta-link" :href="withBase('/INSTALLATION')">Installation</a>
				</div>
			</div>
			<ol class="rv-cta-steps">
				<li v-for="step in steps" :key="step.title">
					<strong>{{ step.title }}</strong>
					<span>{{ step.text }}</span>
				</li>
			</ol>
		</div>
	</section>
	<footer v-if="frontmatter.layout === 'home'" class="rv-footer">
		<div class="rv-footer-inner">
			<div class="rv-footer-brand">
				<a :href="withBase('/')"><img :src="withBase('/icon-192.png')" alt="" width="24" height="24" />Rivue</a>
				<p>Vue 3's component model for Roblox UI, in Luau.</p>
			</div>
			<nav v-for="column in columns" :key="column.title" :aria-label="column.title">
				<h2>{{ column.title }}</h2>
				<a v-for="link in column.links" :key="link.text" :href="link.href">{{ link.text }}</a>
			</nav>
		</div>
		<p class="rv-footer-legal">{{ theme.footer.message }} {{ theme.footer.copyright }}</p>
	</footer>
</template>
