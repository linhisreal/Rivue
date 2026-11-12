<script setup lang="ts">
import { openSearch } from "./composables"

// VitePress keeps the sidebar's open state private; its own "Menu" button in the local nav is the way in
function openSidebar() {
	document.querySelector<HTMLButtonElement>(".VPLocalNav .menu")?.click()
}
</script>

<template>
	<div class="fd-nav-mobile">
		<button type="button" class="fd-nav-button" aria-label="Search" @click="openSearch">
			<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>
		</button>
		<button type="button" class="fd-nav-button" aria-label="Open menu" @click="openSidebar">
			<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>
		</button>
	</div>
</template>
