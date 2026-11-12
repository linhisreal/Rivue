<script setup lang="ts">
defineProps<{ kind: string }>()
</script>

<template>
	<div :class="['rv-art', `rv-art-${kind}`]" aria-hidden="true">
		<template v-if="kind === 'reactivity'">
			<span class="rv-art-chip rv-art-source"><code>count</code><span class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></span></span>
			<svg class="rv-art-wire" viewBox="0 0 40 40"><path d="M2 20h30M26 14l6 6-6 6" /></svg>
			<span class="rv-art-ui">
				<span class="rv-art-label rv-art-reads">Coins: <span class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></span></span>
				<span class="rv-art-label rv-art-idle">Shop</span>
			</span>
		</template>

		<template v-else-if="kind === 'components'">
			<span class="rv-art-frame">
				<span class="rv-art-frame-title">Shop</span>
				<span class="rv-art-row">Sword<b>20</b></span>
				<span class="rv-art-row">Shield<b>30</b></span>
				<span class="rv-art-row">Potion<b>10</b></span>
				<span class="rv-art-stamp"><code>&lt;ItemRow&gt;</code></span>
			</span>
			<code class="rv-art-caption">name = <span class="rv-tick"><span>"Sword"</span><span>"Shield"</span><span>"Potion"</span><span>"Sword"</span></span></code>
		</template>

		<template v-else-if="kind === 'styling'">
			<span class="rv-art-boxes"><i></i><i></i><i></i></span>
			<code class="rv-art-caption">layout = <span class="rv-tick"><span>"row"</span><span>"column"</span><span>"row"</span></span></code>
		</template>

		<template v-else-if="kind === 'animation'">
			<span class="rv-art-panel">Panel</span>
			<code class="rv-art-caption">preset = <span class="rv-tick"><span>"fade"</span><span>"slide"</span><span>"pop"</span><span>"fade"</span></span></code>
		</template>

		<template v-else-if="kind === 'lists'">
			<span class="rv-art-list">
				<span class="rv-art-list-all"><i v-for="n in 16" :key="n"></i></span>
				<span class="rv-art-list-live"><i v-for="n in 16" :key="n"></i></span>
			</span>
			<code class="rv-art-caption">4 of 16 rows created</code>
		</template>

		<template v-else-if="kind === 'typed'">
			<code class="rv-art-code">count.value = <span class="rv-tick rv-art-value"><span>5</span><span>"5"</span><span>5</span></span></code>
			<span class="rv-art-error">Type 'string' could not be converted into 'number'</span>
		</template>
	</div>
</template>
