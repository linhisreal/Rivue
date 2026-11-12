<script setup lang="ts">
import { useData } from "vitepress"
import RepoLink from "./RepoLink.vue"

const { isDark } = useData()
</script>

<template>
	<div class="fd-sidebar-bottom">
		<div class="fd-card">
			<RepoLink />
			<div class="fd-theme" role="group" aria-label="Theme">
				<button type="button" :aria-pressed="!isDark" aria-label="Light" @click="isDark = false">
					<svg viewBox="0 0 24 24" aria-hidden="true">
						<circle cx="12" cy="12" r="4" />
						<path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
					</svg>
				</button>
				<button type="button" :aria-pressed="isDark" aria-label="Dark" @click="isDark = true">
					<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z" /></svg>
				</button>
			</div>
		</div>
	</div>
</template>
