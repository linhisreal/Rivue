<!-- Copyright (c) 2025-2026 linhisreal (ThisisLinh) -->
<!-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE. -->

<script setup lang="ts">
import { computed } from "vue"
import { BANNER_SIZE, bannerImage } from "./blog"

const props = defineProps<{ file?: string; sizes: string }>()

const light = computed(() => bannerImage(props.file))
const dark = computed(() => bannerImage(props.file, true))
</script>

<template>
	<template v-if="light">
		<img
			:class="{ 'fd-only-light': dark }"
			:src="light.src"
			:srcset="light.srcset"
			:sizes="sizes"
			:width="BANNER_SIZE.width"
			:height="BANNER_SIZE.height"
			loading="lazy"
			decoding="async"
			alt=""
		/>
		<img
			v-if="dark"
			class="fd-only-dark"
			:src="dark.src"
			:srcset="dark.srcset"
			:sizes="sizes"
			:width="BANNER_SIZE.width"
			:height="BANNER_SIZE.height"
			loading="lazy"
			decoding="async"
			alt=""
		/>
	</template>
</template>
