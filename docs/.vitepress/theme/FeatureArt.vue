<script setup lang="ts">
import type { Scene } from "./types"

defineProps<{ kind: Scene }>()

const COLS = 15
const ROWS = 8
const DIGITS = [3, 4, 5] as const
const GLYPHS: Record<(typeof DIGITS)[number], string[]> = {
	3: ["01110", "10001", "00001", "00110", "00001", "10001", "01110"],
	4: ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	5: ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
}
const pixels = Array.from({ length: COLS * ROWS }, (_, i) =>
	DIGITS.map((digit) => GLYPHS[digit][Math.floor(i / COLS)]?.[(i % COLS) - 5] ?? "0").join(""),
)
const writes = DIGITS.map((_, step) => pixels.filter((p) => p[step] !== p[(step + 1) % DIGITS.length]).length)
const copies = [
	{ name: "Sword", price: 20, swatch: "a", link: "M98 66 C 124 66, 124 22, 150 22" },
	{ name: "Shield", price: 30, swatch: "b", link: "M98 66 H 150" },
	{ name: "Potion", price: 10, swatch: "c", link: "M98 66 C 124 66, 124 110, 150 110" },
]
const path = "M30 112 C 80 110, 120 44, 222 26"
const along = [0, 0.416, 0.751, 1]
</script>

<template>
	<div :class="['rv-art', `rv-art-${kind}`]" aria-hidden="true">
		<template v-if="kind === 'reactivity'">
			<span class="rv-field-wrap">
				<span class="rv-field-head">
					<code>coins = <b class="rv-tick"><span>3</span><span>4</span><span>5</span><span>3</span></b></code>
				</span>
				<span class="rv-field">
					<i
						v-for="(pattern, i) in pixels"
						:key="i"
						:class="{ 'is-on': pattern[0] === '1', [`rv-px-${pattern}`]: pattern !== '000' && pattern !== '111' }"
					></i>
				</span>
				<em class="rv-field-count"
					><b class="rv-tick"><span>{{ writes[2] }}</span><span>{{ writes[0] }}</span><span>{{ writes[1] }}</span><span>{{ writes[2] }}</span></b>
					/ {{ pixels.length }} written</em
				>
			</span>
		</template>

		<template v-else-if="kind === 'components'">
			<span class="rv-mould">
				<svg class="rv-mould-links" viewBox="0 0 264 132">
					<path v-for="(c, i) in copies" :key="i" :d="c.link" :style="{ '--n': i }" />
				</svg>
				<span class="rv-mould-print">
					<em class="rv-lbl rv-lbl-left">ItemRow</em>
					<i class="rv-mould-slot"></i>
					<i class="rv-sk"></i>
					<i class="rv-sk"></i>
				</span>
				<span
					v-for="(c, i) in copies"
					:key="c.name"
					class="rv-copy-row"
					:style="{ top: `${7 + i * 44}px`, '--n': i }"
				><i :class="['rv-swatch', `rv-swatch-${c.swatch}`]"></i>{{ c.name }}<b>{{ c.price }}</b></span>
				<i
					v-for="(c, i) in copies"
					:key="`p${i}`"
					class="rv-mould-pulse"
					:style="{ offsetPath: `path('${c.link}')`, '--n': i }"
				></i>
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
				<svg class="rv-onion-path" viewBox="0 0 252 136">
					<path :d="path" />
					<path class="rv-onion-trail" :d="path" pathLength="1" />
				</svg>
				<span
					v-for="(t, i) in along"
					:key="i"
					:class="['rv-onion-frame', { 'is-end': i === along.length - 1 }]"
					:style="{ offsetPath: `path('${path}')`, offsetDistance: `${t * 100}%`, '--i': i }"
				>
					<i class="rv-sk"></i>
				</span>
				<span class="rv-onion-frame rv-onion-live" :style="{ offsetPath: `path('${path}')` }"><i class="rv-sk"></i></span>
				<span class="rv-ease">
					<svg viewBox="0 0 96 40"><path d="M2 38 C 29.6 20, 52.6 2, 94 2" /></svg>
					<i><b></b></i>
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
