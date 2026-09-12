<!-- Copyright (c) 2025-2026 linhisreal (ThisisLinh) -->
<!-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE. -->

<script setup lang="ts">
import { computed, ref } from "vue"
import { useDismiss, useFlash } from "./composables"
import { useTheme } from "./types"

const { frontmatter, theme } = useTheme()
const { message: status, flash } = useFlash()
const open = ref(false)
const menu = ref<HTMLElement>()

const links = computed(() => {
	const file = frontmatter.value.githubPath
	const repo = theme.value.repo.url
	return [
		{ text: "View on GitHub", href: `${repo}/blob/main/${file}` },
		{ text: "Edit on GitHub", href: `${repo}/edit/main/${file}` },
	]
})

function decode(base64: string): string {
	return new TextDecoder().decode(Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)))
}

async function copy() {
	try {
		await navigator.clipboard.writeText(decode(frontmatter.value.markdown ?? ""))
		flash("Copied")
	} catch {
		flash("Copy failed")
	}
}

useDismiss(menu, open)
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
			<button type="button" class="fd-action" :aria-expanded="open" aria-controls="fd-open-list" @click="open = !open">
				Open
				<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>
			</button>
			<div v-show="open" id="fd-open-list" class="fd-menu-list">
				<a v-for="link in links" :key="link.text" :href="link.href" target="_blank" rel="noreferrer">
					{{ link.text }}
				</a>
			</div>
		</div>
	</div>
</template>
