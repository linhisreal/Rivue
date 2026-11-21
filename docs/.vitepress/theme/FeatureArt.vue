<script setup lang="ts">
defineProps<{ kind: string }>()
</script>

<template>
	<div :class="['rv-art', `rv-art-${kind}`]" aria-hidden="true">
		<template v-if="kind === 'reactivity'">
			<span class="rv-deps">
				<span class="rv-o rv-deps-root">
					<em class="rv-lbl">ref</em>
					<code>coins</code>
					<b class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></b>
				</span>
				<svg class="rv-deps-links" viewBox="0 0 240 40" preserveAspectRatio="none">
					<path d="M120 0V16H40V40" />
					<path class="rv-deps-hot" d="M120 0V40" />
					<path d="M120 16H200V40" />
				</svg>
				<span class="rv-deps-kids">
					<span class="rv-o rv-deps-kid">Title</span>
					<span class="rv-o rv-deps-kid rv-deps-reader">
						<em class="rv-lbl">re-renders</em>
						Coins: <span class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></span>
					</span>
					<span class="rv-o rv-deps-kid">Shop</span>
				</span>
			</span>
		</template>

		<template v-else-if="kind === 'components'">
			<span class="rv-cards">
				<span class="rv-o rv-sheet">
					<i class="rv-swatch rv-swatch-a"></i>
					<span>Sword</span>
					<b>20</b>
				</span>
				<span class="rv-o rv-sheet">
					<i class="rv-swatch rv-swatch-b"></i>
					<span>Shield</span>
					<b>30</b>
				</span>
				<span class="rv-o rv-sheet">
					<em class="rv-lbl">&lt;ItemRow&gt;</em>
					<i class="rv-swatch rv-swatch-c"></i>
					<span>Potion</span>
					<b>10</b>
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
				<span class="rv-o rv-pane">
					<em class="rv-lbl">
						<span class="rv-tick"><span>fade</span><span>slide</span><span>pop</span><span>fade</span></span>
					</em>
					<b>Panel</b>
					<i class="rv-sk"></i>
					<i class="rv-sk"></i>
					<span class="rv-pane-btn">OK</span>
				</span>
			</span>
		</template>

		<template v-else-if="kind === 'lists'">
			<span class="rv-list">
				<span class="rv-list-all"><i v-for="n in 16" :key="n"></i></span>
				<span class="rv-list-live"><i v-for="n in 16" :key="n"><b class="rv-sk"></b><small>{{ n * 25 }}</small></i></span>
				<span class="rv-list-window"><em class="rv-lbl">4 of 16 created</em></span>
			</span>
		</template>

		<template v-else-if="kind === 'typed'">
			<span class="rv-o rv-editor">
				<code class="rv-code-line"><i>1</i><span><span class="rv-tok-kw">local</span> hp: <span class="rv-tok-type">Ref</span>&lt;<span class="rv-tok-type">number</span>&gt; = ref(100)</span></code>
				<code class="rv-code-line"><i>2</i><span>hp.value = <span class="rv-tick rv-bad"><span>100</span><span>"full"</span><span>100</span></span></span></code>
				<span class="rv-error">Type 'string' could not be converted into 'number'</span>
			</span>
		</template>
	</div>
</template>
