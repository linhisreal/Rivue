<script setup lang="ts">
import { useData } from "vitepress"

const { isDark } = useData()
</script>

<template>
	<div class="fd-sidebar-bottom">
		<div class="fd-card">
			<a class="fd-icon-link" href="https://github.com/linhisreal/Rivue" aria-label="GitHub">
				<svg viewBox="0 0 24 24" aria-hidden="true">
					<path
						d="M12 2a10 10 0 0 0-3.16 19.49c.5.09.68-.22.68-.48v-1.7c-2.78.6-3.37-1.34-3.37-1.34-.45-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.9 1.52 2.34 1.08 2.91.83.09-.65.35-1.08.63-1.33-2.22-.25-4.55-1.11-4.55-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.64 0 0 .84-.27 2.75 1.02a9.5 9.5 0 0 1 5 0c1.91-1.29 2.75-1.02 2.75-1.02.55 1.37.2 2.39.1 2.64.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.68-4.57 4.93.36.31.68.92.68 1.85v2.74c0 .27.18.58.69.48A10 10 0 0 0 12 2z"
					/>
				</svg>
			</a>
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
