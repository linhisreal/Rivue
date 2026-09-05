<script setup lang="ts">
import { computed } from "vue"
import { useTheme } from "./types"

const { theme } = useTheme()
const repo = computed(() => theme.value.repo)
</script>

<template>
	<a class="fd-repo" :href="repo.url" :aria-label="`${repo.name} on GitHub`">
		<svg class="fd-repo-logo" viewBox="0 0 24 24" aria-hidden="true">
			<path
				d="M12 2a10 10 0 0 0-3.16 19.49c.5.09.68-.22.68-.48v-1.7c-2.78.6-3.37-1.34-3.37-1.34-.45-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.9 1.52 2.34 1.08 2.91.83.09-.65.35-1.08.63-1.33-2.22-.25-4.55-1.11-4.55-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.64 0 0 .84-.27 2.75 1.02a9.5 9.5 0 0 1 5 0c1.91-1.29 2.75-1.02 2.75-1.02.55 1.37.2 2.39.1 2.64.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.68-4.57 4.93.36.31.68.92.68 1.85v2.74c0 .27.18.58.69.48A10 10 0 0 0 12 2z"
			/>
		</svg>
		<span class="fd-repo-text">
			<span class="fd-repo-name">{{ repo.name }}</span>
			<span v-if="repo.tag || repo.stars !== undefined" class="fd-repo-meta">
				<span v-if="repo.tag">
					<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12V4h8l10 10-8 8zM7.5 7.5h.01" /></svg>{{ repo.tag }}
				</span>
				<span v-if="repo.stars !== undefined" :aria-label="`${repo.stars} stars`">
					<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.2l1-6.2L3 9.6l6.2-.9z" /></svg>{{ repo.stars }}
				</span>
				<span v-if="repo.forks !== undefined" :aria-label="`${repo.forks} forks`">
					<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="6" cy="5" r="2" /><circle cx="18" cy="5" r="2" /><circle cx="12" cy="19" r="2" /><path d="M6 7v2a3 3 0 0 0 3 3h6a3 3 0 0 0 3-3V7M12 12v5" /></svg>{{ repo.forks }}
				</span>
			</span>
		</span>
	</a>
</template>
