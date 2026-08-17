<script setup lang="ts">
defineProps<{ kind: string }>()
</script>

<template>
	<div :class="['rv-art', `rv-art-${kind}`]" aria-hidden="true">
		<template v-if="kind === 'reactivity'">
			<span class="rv-art-state">
				<code>coins</code>
				<b class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></b>
			</span>
			<span class="rv-art-wire"><i></i></span>
			<span class="rv-art-gui">
				<span class="rv-art-text rv-art-reads">Coins: <span class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></span></span>
				<span class="rv-art-text rv-art-idle">Shop</span>
			</span>
		</template>

		<template v-else-if="kind === 'components'">
			<span class="rv-art-frame">
				<span class="rv-art-frame-title">Shop</span>
				<span class="rv-art-row"><i class="rv-swatch-a"></i>Sword<b>20</b></span>
				<span class="rv-art-row"><i class="rv-swatch-b"></i>Shield<b>30</b></span>
				<span class="rv-art-row"><i class="rv-swatch-c"></i>Potion<b>10</b></span>
				<span class="rv-art-stamp"><code>ItemRow</code></span>
			</span>
			<span class="rv-art-prop">
				<span>name</span>
				<code><span class="rv-tick"><span>"Sword"</span><span>"Shield"</span><span>"Potion"</span><span>"Sword"</span></span></code>
			</span>
		</template>

		<template v-else-if="kind === 'styling'">
			<span class="rv-art-boxes"><i></i><i></i><i></i><em>8</em></span>
			<span class="rv-art-prop">
				<span>layout</span>
				<code><span class="rv-tick"><span>"horizontal"</span><span>"vertical"</span><span>"horizontal"</span></span></code>
			</span>
		</template>

		<template v-else-if="kind === 'animation'">
			<span class="rv-art-slot">
				<span class="rv-art-panel">
					<b>Panel</b>
					<i></i>
					<i></i>
					<span class="rv-art-panel-btn">OK</span>
				</span>
			</span>
			<span class="rv-art-prop">
				<span>preset</span>
				<code><span class="rv-tick"><span>"fade"</span><span>"slide"</span><span>"pop"</span><span>"fade"</span></span></code>
			</span>
		</template>

		<template v-else-if="kind === 'lists'">
			<span class="rv-art-list">
				<span class="rv-art-list-all"><i v-for="n in 16" :key="n"></i></span>
				<span class="rv-art-list-live"><i v-for="n in 16" :key="n"></i></span>
			</span>
			<span class="rv-art-prop">
				<span>rows created</span>
				<code>4 of 16</code>
			</span>
		</template>

		<template v-else-if="kind === 'typed'">
			<span class="rv-art-editor">
				<code class="rv-art-line"><i>1</i><span><span class="rv-tok-kw">local</span> hp: <span class="rv-tok-type">Ref</span>&lt;<span class="rv-tok-type">number</span>&gt; = ref(100)</span></code>
				<code class="rv-art-line"><i>2</i><span>hp.value = <span class="rv-tick rv-art-value"><span>100</span><span>"full"</span><span>100</span></span></span></code>
				<span class="rv-art-error">Type 'string' could not be converted into 'number'</span>
			</span>
		</template>
	</div>
</template>
