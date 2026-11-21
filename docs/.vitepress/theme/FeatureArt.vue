<script setup lang="ts">
defineProps<{ kind: string }>()

const FIELD = 120
const TARGET = 52
const path = "M16 118 C 70 116, 120 40, 236 22"
const along = [0.06, 0.24, 0.44, 0.66, 0.9]
</script>

<template>
	<div :class="['rv-art', `rv-art-${kind}`]" aria-hidden="true">
		<template v-if="kind === 'reactivity'">
			<span class="rv-field-wrap">
				<span class="rv-field-head">
					<code>coins = <b class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></b></code>
				</span>
				<span class="rv-field">
					<i v-for="n in FIELD" :key="n" :class="{ 'rv-field-hit': n === TARGET }"></i>
				</span>
				<em class="rv-field-count">1 / {{ FIELD }} written</em>
			</span>
		</template>

		<template v-else-if="kind === 'components'">
			<span class="rv-mould">
				<svg class="rv-mould-links" viewBox="0 0 264 132">
					<path d="M98 66 C 124 66, 124 22, 150 22" />
					<path d="M98 66 H 150" />
					<path d="M98 66 C 124 66, 124 110, 150 110" />
				</svg>
				<span class="rv-mould-print">
					<em class="rv-lbl rv-lbl-left">ItemRow</em>
					<i class="rv-mould-slot"></i>
					<i class="rv-sk"></i>
					<i class="rv-sk"></i>
				</span>
				<span class="rv-copy-row"><i class="rv-swatch rv-swatch-a"></i>Sword<b>20</b></span>
				<span class="rv-copy-row"><i class="rv-swatch rv-swatch-b"></i>Shield<b>30</b></span>
				<span class="rv-copy-row"><i class="rv-swatch rv-swatch-c"></i>Potion<b>10</b></span>
			</span>
		</template>

		<template v-else-if="kind === 'styling'">
			<span class="rv-spec-box">
				<span class="rv-spec-frame">
					<span class="rv-spec-inner"><i class="rv-sk"></i><i class="rv-sk"></i></span>
					<span class="rv-spec-pad rv-spec-pad-top"><em><span class="rv-tick"><span>8</span><span>16</span><span>8</span></span></em></span>
					<span class="rv-spec-pad rv-spec-pad-left"><em><span class="rv-tick"><span>8</span><span>16</span><span>8</span></span></em></span>
					<span class="rv-spec-radius"><em>r 8</em></span>
				</span>
				<span class="rv-spec-width"><em>200</em></span>
			</span>
		</template>

		<template v-else-if="kind === 'animation'">
			<span class="rv-onion">
				<svg class="rv-onion-path" viewBox="0 0 252 136"><path :d="path" /></svg>
				<span
					v-for="(t, i) in along"
					:key="i"
					class="rv-onion-frame"
					:style="{ offsetPath: `path('${path}')`, offsetDistance: `${t * 100}%`, '--i': i }"
				>
					<i class="rv-sk"></i>
				</span>
				<span class="rv-ease">
					<svg viewBox="0 0 96 40"><path d="M2 38 C 30 38, 40 2, 94 2" /></svg>
					<i></i>
					<em>ease out</em>
				</span>
			</span>
		</template>

		<template v-else-if="kind === 'lists'">
			<span class="rv-tilt">
				<span class="rv-plane">
					<span class="rv-list-all"><i v-for="n in 34" :key="n"></i></span>
					<span class="rv-list-live"><i v-for="n in 34" :key="n"><b class="rv-sk"></b></i></span>
					<span class="rv-list-window"></span>
				</span>
				<em class="rv-tilt-count">4 of 10,000 created</em>
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
