<script setup lang="ts">
import { onMounted, onUnmounted } from "vue"
import { openSearch, restoreSidebar, setSidebarCollapsed, sidebarCollapsed } from "./composables"

const root = () => document.documentElement

function peek() {
	root().classList.add("fd-peek")
}

function onMove(event: MouseEvent) {
	if (!root().classList.contains("fd-peek")) return
	const right = document.querySelector(".VPSidebar")?.getBoundingClientRect().right ?? 0
	if (event.clientX > right + 24) root().classList.remove("fd-peek")
}

onMounted(() => {
	restoreSidebar()
	document.addEventListener("mousemove", onMove, { passive: true })
})
onUnmounted(() => document.removeEventListener("mousemove", onMove))
</script>

<template>
	<template v-if="sidebarCollapsed">
		<div class="fd-sidebar-zone" aria-hidden="true" @mouseenter="peek"></div>
		<div class="fd-sidebar-open">
			<button type="button" class="fd-icon-button" aria-label="Show sidebar" @click="setSidebarCollapsed(false)">
				<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="16" rx="2" /><path d="M9 4v16" /></svg>
			</button>
			<button type="button" class="fd-icon-button" aria-label="Search" @click="openSearch">
				<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>
			</button>
		</div>
	</template>
</template>
