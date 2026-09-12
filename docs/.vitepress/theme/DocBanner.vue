<!-- Copyright (c) 2025-2026 linhisreal (ThisisLinh) -->
<!-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE. -->

<script setup lang="ts">
import { computed } from "vue"
import { withBase } from "vitepress"
import { useTheme } from "./types"

const { theme } = useTheme()
const version = computed(() => theme.value.version)
const stage = computed(() => (version.value.includes("-rc") ? "a release candidate" : version.value.includes("-") ? "a pre-release" : ""))
</script>

<template>
	<aside v-if="stage" class="fd-banner" aria-label="Release status">
		RivueUI {{ version }} is {{ stage }}, so APIs can still change before the stable release.
		<a :href="withBase('/INSTALLATION')">Install it</a>
	</aside>
</template>
