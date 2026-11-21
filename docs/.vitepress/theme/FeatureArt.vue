<script setup lang="ts">
defineProps<{ kind: string }>()
</script>

<template>
	<div :class="['rv-art', `rv-art-${kind}`]" aria-hidden="true">
		<template v-if="kind === 'reactivity'">
			<span class="rv-art-tag">1 of 2 re-renders</span>
			<span class="rv-art-tree">
				<span class="rv-art-node rv-art-src">
					<code>coins</code>
					<b class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></b>
				</span>
				<svg class="rv-art-links" viewBox="0 0 200 44" preserveAspectRatio="none">
					<path class="rv-art-link-on" d="M100 0V14H44V44" />
					<path d="M100 14H156V44" />
				</svg>
				<span class="rv-art-kids">
					<span class="rv-art-node rv-art-reads">Coins: <span class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></span></span>
					<span class="rv-art-node rv-art-idle">Shop</span>
				</span>
			</span>
		</template>

		<template v-else-if="kind === 'components'">
			<span class="rv-art-tag">ItemRow × 3</span>
			<span class="rv-art-stack">
				<span class="rv-art-sheet">
					<span class="rv-art-sheet-title">Shop</span>
					<span class="rv-art-bar"><i></i></span>
					<span class="rv-art-bar"><i></i></span>
					<span class="rv-art-bar"><i></i></span>
					<span class="rv-art-stamp"></span>
				</span>
				<span class="rv-art-sheet rv-art-front">
					<code>ItemRow</code>
					<span class="rv-art-item">
						<i></i>
						<span class="rv-tick"><span>Sword</span><span>Shield</span><span>Potion</span><span>Sword</span></span>
					</span>
				</span>
			</span>
		</template>

		<template v-else-if="kind === 'styling'">
			<span class="rv-art-tag">
				<span class="rv-tick"><span>Horizontal</span><span>Vertical</span><span>Horizontal</span></span>
			</span>
			<span class="rv-art-boxes"><i></i><i></i><i></i><em>8</em></span>
		</template>

		<template v-else-if="kind === 'animation'">
			<span class="rv-art-tag">
				<span class="rv-tick"><span>Fade</span><span>Slide</span><span>Pop</span><span>Fade</span></span>
			</span>
			<span class="rv-art-slot">
				<span class="rv-art-ghost"></span>
				<span class="rv-art-ghost"></span>
				<span class="rv-art-panel">
					<b>Panel</b>
					<i></i>
					<i></i>
					<span class="rv-art-panel-btn">OK</span>
				</span>
			</span>
		</template>

		<template v-else-if="kind === 'lists'">
			<span class="rv-art-tag">4 of 16 rows created</span>
			<span class="rv-art-list">
				<span class="rv-art-list-all"><i v-for="n in 16" :key="n"></i></span>
				<span class="rv-art-list-live"><i v-for="n in 16" :key="n"></i></span>
			</span>
		</template>

		<template v-else-if="kind === 'typed'">
			<span class="rv-art-tag">Strict</span>
			<span class="rv-art-editor">
				<code class="rv-art-line"><i>1</i><span><span class="rv-tok-kw">local</span> hp: <span class="rv-tok-type">Ref</span>&lt;<span class="rv-tok-type">number</span>&gt; = ref(100)</span></code>
				<code class="rv-art-line"><i>2</i><span>hp.value = <span class="rv-tick rv-art-value"><span>100</span><span>"full"</span><span>100</span></span></span></code>
				<span class="rv-art-error">Type 'string' could not be converted into 'number'</span>
			</span>
		</template>
	</div>
</template>
