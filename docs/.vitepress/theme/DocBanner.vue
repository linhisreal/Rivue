<script setup lang="ts">
import { useData, withBase } from "vitepress"

const { theme } = useData()
const version: string = theme.value.version
const stage = version.includes("-rc") ? "a release candidate" : version.includes("-") ? "a pre-release" : ""
</script>

<template>
	<p v-if="stage" class="fd-banner">
		RivueUI {{ version }} is {{ stage }}, so APIs can still change before the stable release.
		<a :href="withBase('/INSTALLATION')">Install it</a>
	</p>
</template>
