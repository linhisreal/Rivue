<script setup lang="ts">
import { computed, onMounted, ref } from "vue"
import { useData, withBase } from "vitepress"
import { openSearch } from "./composables"

type Page = { text: string; link: string }

const { theme, site } = useData()
const missing = ref("")

const pages = computed(() => {
	const found: Page[] = []
	const walk = (items: any[]) => {
		for (const item of items ?? []) {
			if (item.link) found.push({ text: item.text, link: item.link })
			walk(item.items)
		}
	}
	for (const list of Object.values(theme.value.sidebar ?? {})) walk(list as any[])
	return [...new Map(found.map((page) => [page.link, page])).values()]
})

function distance(a: string, b: string) {
	const row = Array.from({ length: b.length + 1 }, (_, i) => i)
	for (let i = 1; i <= a.length; i++) {
		let previous = row[0]
		row[0] = i
		for (let j = 1; j <= b.length; j++) {
			const current = row[j]
			row[j] = Math.min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1))
			previous = current
		}
	}
	return row[b.length]
}

const suggestions = computed(() => {
	const wanted = missing.value.split("/").pop()!.toLowerCase()
	if (!wanted) return pages.value.slice(0, 3)
	return pages.value
		.map((page) => {
			const slug = page.link.split("/").pop()!.toLowerCase()
			const words = `${slug} ${page.text}`.toLowerCase()
			const shared = wanted.split(/[-_/\s]+/).filter((word) => word.length > 2 && words.includes(word)).length
			return { page, score: distance(wanted, slug) / Math.max(wanted.length, slug.length) - shared }
		})
		.sort((a, b) => a.score - b.score)
		.slice(0, 3)
		.map(({ page }) => page)
})

const KINDS = [
	{ prefix: "/guide/", label: "Guide", icon: "M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2zM4 19V5M8 7h7" },
	{ prefix: "/api/", label: "API", icon: "M8 4H7a2 2 0 0 0-2 2v4l-2 2 2 2v4a2 2 0 0 0 2 2h1M16 4h1a2 2 0 0 1 2 2v4l2 2-2 2v4a2 2 0 0 1-2 2h-1" },
	{ prefix: "/examples/", label: "Example", icon: "M7 4v16l13-8z" },
]
const DOC = { label: "Docs", icon: "M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9zM14 3v6h6" }
const kindOf = (link: string) => KINDS.find((kind) => link.startsWith(kind.prefix)) ?? DOC

onMounted(() => {
	const base = site.value.base
	const path = decodeURIComponent(location.pathname)
	missing.value = (path.startsWith(base) ? path.slice(base.length) : path).replace(/\.html$|\/$/g, "") || "index"
})
</script>

<template>
	<div class="fd-404">
		<div class="fd-404-mark" role="img" aria-label="404">
			<span>4</span>
			<span class="fd-404-zero" aria-hidden="true">
				<svg viewBox="0 0 100 100">
					<rect class="fd-404-tile" x="16" y="16" width="68" height="68" rx="18" transform="rotate(-15 50 50)" />
					<path class="fd-404-v" d="M37 40 50 61 63 40" />
				</svg>
				<b>nil</b>
			</span>
			<span>4</span>
		</div>
		<h1>There's no page here</h1>
		<p class="fd-404-lead">
			Nothing lives at <code>/{{ missing }}</code>. The page may have moved, or the link has a typo.
		</p>
		<template v-if="suggestions.length">
			<h2>Did you mean</h2>
			<ul class="fd-404-pages">
				<li v-for="page in suggestions" :key="page.link">
					<a :href="withBase(page.link)">
						<svg class="fd-404-kind" viewBox="0 0 24 24" aria-hidden="true"><path :d="kindOf(page.link).icon" /></svg>
						<span class="fd-404-title">{{ page.text }}</span>
						<span class="fd-404-section">{{ kindOf(page.link).label }}</span>
						<svg class="fd-404-arrow" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
					</a>
				</li>
			</ul>
		</template>
		<div class="fd-404-actions">
			<a class="fd-404-button fd-404-primary" :href="withBase('/')">Docs home</a>
			<button type="button" class="fd-404-button" @click="openSearch">Search the docs</button>
		</div>
	</div>
</template>
