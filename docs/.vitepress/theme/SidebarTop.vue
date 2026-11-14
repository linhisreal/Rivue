<script setup lang="ts">
import { withBase } from "vitepress"

function openSearch() {
	document.querySelector<HTMLButtonElement>(".VPNavBarSearch .DocSearch-Button")?.click()
}
</script>

<template>
	<div class="fd-sidebar-top">
		<a class="fd-brand" :href="withBase('/')">
			<img :src="withBase('/icon-192.png')" alt="" width="24" height="24" />
			<span>Rivue</span>
		</a>
		<button type="button" class="fd-search" @click="openSearch">
			<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>
			<span>Search</span>
			<kbd>Ctrl K</kbd>
		</button>
	</div>
</template>
