<script setup lang="ts">
defineProps<{ kind: string }>()
</script>

<template>
	<div :class="['rv-art', `rv-art-${kind}`]" aria-hidden="true">
		<template v-if="kind === 'reactivity'">
			<span class="rv-tree">
				<span class="rv-o rv-tree-root">
					<em class="rv-lbl">coins <span class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></span></em>
					<i class="rv-sk"></i>
				</span>
				<svg class="rv-tree-links" viewBox="0 0 240 40" preserveAspectRatio="none">
					<path d="M120 0V16H40V40" />
					<path class="rv-tree-hot" d="M120 0V40" />
					<path d="M120 16H200V40" />
				</svg>
				<span class="rv-tree-kids">
					<span class="rv-o"><i class="rv-sk"></i></span>
					<span class="rv-o rv-tree-reader"><em class="rv-lbl">re-renders</em><i class="rv-sk"></i></span>
					<span class="rv-o"><i class="rv-sk"></i></span>
				</span>
			</span>
		</template>

		<template v-else-if="kind === 'components'">
			<span class="rv-cards">
				<span v-for="n in 3" :key="n" class="rv-o rv-sheet">
					<em v-if="n === 3" class="rv-lbl">ItemRow</em>
					<i class="rv-dots"></i>
					<span class="rv-sheet-lines"><i class="rv-sk"></i><i class="rv-sk"></i></span>
				</span>
			</span>
		</template>

		<template v-else-if="kind === 'styling'">
			<span class="rv-o rv-frame">
				<em class="rv-lbl rv-lbl-left">padding 8</em>
				<em class="rv-lbl">
					<span class="rv-tick"><span>horizontal</span><span>vertical</span><span>horizontal</span></span>
				</em>
				<span class="rv-boxes"><i></i><i></i><i></i></span>
			</span>
		</template>

		<template v-else-if="kind === 'animation'">
			<span class="rv-motion">
				<span class="rv-o rv-ghost"></span>
				<span class="rv-o rv-ghost"></span>
				<span class="rv-o rv-panel">
					<em class="rv-lbl">
						<span class="rv-tick"><span>fade</span><span>slide</span><span>pop</span><span>fade</span></span>
					</em>
					<i class="rv-sk"></i>
					<i class="rv-sk"></i>
					<i class="rv-sk rv-sk-blue"></i>
				</span>
			</span>
		</template>

		<template v-else-if="kind === 'lists'">
			<span class="rv-list">
				<span class="rv-list-all"><i v-for="n in 16" :key="n"></i></span>
				<span class="rv-list-live"><i v-for="n in 16" :key="n"><b class="rv-sk"></b></i></span>
				<span class="rv-list-window"><em class="rv-lbl">4 / 16</em></span>
			</span>
		</template>

		<template v-else-if="kind === 'typed'">
			<span class="rv-o rv-editor">
				<span class="rv-code-line"><i class="rv-sk" style="width: 52%"></i></span>
				<span class="rv-code-line">
					<i class="rv-sk" style="width: 28%"></i>
					<code class="rv-tick rv-bad"><span>100</span><span>"full"</span><span>100</span></code>
				</span>
				<span class="rv-code-line"><i class="rv-sk" style="width: 40%"></i></span>
				<em class="rv-lbl rv-lbl-error">string ≠ number</em>
			</span>
		</template>
	</div>
</template>
