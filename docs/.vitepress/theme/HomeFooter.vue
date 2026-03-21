<script setup lang="ts">
import { useData, withBase } from "vitepress"

const REPO = "https://github.com/linhisreal/Rivue"
const { frontmatter, theme } = useData()

const rings = [
	{ at: 66, size: 380, radius: 84 },
	{ at: 26, size: 460, radius: 104 },
	{ at: -14, size: 540, radius: 124 },
	{ at: -54, size: 620, radius: 144 },
]

const columns = [
	{
		title: "Docs",
		links: [
			{ text: "Installation", href: withBase("/INSTALLATION") },
			{ text: "Guide", href: withBase("/GUIDE") },
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
				<p>Install RivueUI, then follow Chapter 1 to put a component on screen and watch it update.</p>
				<div class="rv-cta-actions">
					<a class="rv-btn rv-btn-brand" :href="withBase('/introduction')">Get started</a>
					<a class="rv-cta-link" :href="withBase('/INSTALLATION')">Installation</a>
				</div>
			</div>
			<svg class="rv-cta-art" viewBox="0 0 512 512" aria-hidden="true">
				<g transform="rotate(-15 256 256)">
					<rect v-for="(ring, i) in rings" :key="i" :class="`rv-cta-ring rv-cta-ring-${i}`" :x="ring.at" :y="ring.at" :width="ring.size" :height="ring.size" :rx="ring.radius" />
				</g>
				<path class="rv-cta-v-edge" d="M150 165 256 350 362 165" />
				<path class="rv-cta-v-fill" d="M150 165 256 350 362 165" />
				<path class="rv-cta-v-edge rv-cta-mint" d="M222 168 256 226 290 168" />
				<path class="rv-cta-v-fill rv-cta-mint" d="M222 168 256 226 290 168" />
			</svg>
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
