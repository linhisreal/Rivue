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

const routeNames = computed(() => pages.value.map((page) => page.link.split("/").pop()!.toLowerCase()))

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

onMounted(() => {
	const base = site.value.base
	const path = decodeURIComponent(location.pathname)
	missing.value = (path.startsWith(base) ? path.slice(base.length) : path).replace(/\.html$|\/$/g, "") || "index"
})
</script>

<template>
	<div class="fd-404">
		<p class="fd-404-code">404</p>
		<h1>This screen isn't in the router</h1>
		<div class="fd-404-output" role="img" :aria-label="`No page at ${missing}`">
			<div class="fd-404-bar"><b>Output</b></div>
			<p class="fd-404-input">router.push("{{ missing }}")</p>
			<p class="fd-404-error">
				[RivueRouter] No route named '{{ missing }}'. Routes: {{ routeNames.slice(0, 6).join(", ") }}, …
			</p>
		</div>
		<template v-if="suggestions.length">
			<h2>Did you mean</h2>
			<div class="fd-404-pages">
				<a v-for="page in suggestions" :key="page.link" :href="withBase(page.link)">
					<span>{{ page.text }}</span>
					<small>{{ page.link }}</small>
				</a>
			</div>
		</template>
		<div class="fd-404-actions">
			<a class="fd-404-button fd-404-primary" :href="withBase('/')">Docs home</a>
			<button type="button" class="fd-404-button" @click="openSearch">Search the docs</button>
		</div>
	</div>
</template>
