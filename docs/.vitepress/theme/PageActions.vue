<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from "vue"
import { useData } from "vitepress"

const REPO = "https://github.com/linhisreal/Rivue"
const { frontmatter } = useData()
const status = ref("")
const open = ref(false)
const menu = ref<HTMLElement>()

const links = computed(() => {
	const file = `docs/${frontmatter.value.source}`
	return [
		{ text: "View on GitHub", href: `${REPO}/blob/main/${file}` },
		{ text: "Edit on GitHub", href: `${REPO}/edit/main/${file}` },
	]
})

let timer: ReturnType<typeof setTimeout> | undefined

function decode(base64: string): string {
	return new TextDecoder().decode(Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)))
}

async function copy() {
	clearTimeout(timer)
	try {
		await navigator.clipboard.writeText(decode(frontmatter.value.markdown ?? ""))
		status.value = "Copied"
	} catch {
		status.value = "Copy failed"
	}
	timer = setTimeout(() => (status.value = ""), 2000)
}

function onDocumentClick(event: MouseEvent) {
	if (menu.value && !menu.value.contains(event.target as Node)) open.value = false
}

function onKeydown(event: KeyboardEvent) {
	if (event.key === "Escape") open.value = false
}

onMounted(() => {
	document.addEventListener("click", onDocumentClick)
	document.addEventListener("keydown", onKeydown)
})
onUnmounted(() => {
	document.removeEventListener("click", onDocumentClick)
	document.removeEventListener("keydown", onKeydown)
})
</script>

<template>
	<div class="fd-actions">
		<button type="button" class="fd-action" @click="copy">
			<svg viewBox="0 0 24 24" aria-hidden="true">
				<rect x="8" y="8" width="12" height="12" rx="2" />
				<path d="M4 16V6a2 2 0 0 1 2-2h10" />
			</svg>
			{{ status === "Copied" ? "Copied" : "Copy Markdown" }}
		</button>
		<span class="fd-visually-hidden" role="status">{{ status }}</span>
		<div ref="menu" class="fd-menu">
			<button type="button" class="fd-action" :aria-expanded="open" aria-haspopup="menu" @click="open = !open">
				Open
				<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>
			</button>
			<div v-if="open" class="fd-menu-list" role="menu">
				<a v-for="link in links" :key="link.text" role="menuitem" :href="link.href" target="_blank" rel="noreferrer">
					{{ link.text }}
				</a>
			</div>
		</div>
	</div>
</template>
