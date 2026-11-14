<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from "vue"
import { useRoute } from "vitepress"

type Heading = { id: string; text: string; depth: number }
type Point = { x: number; top: number; bottom: number }

const INDENT = 12
const INSET = 6

const route = useRoute()
const headings = ref<Heading[]>([])
const points = ref<Point[]>([])
const active = ref<number[]>([])
const list = ref<HTMLElement>()

const path = computed(() =>
	points.value
		.flatMap((p, i) => [`${i === 0 ? "M" : "L"}${p.x + 0.5} ${p.top + INSET}`, `L${p.x + 0.5} ${p.bottom - INSET}`])
		.join(" "),
)

const height = computed(() => points.value.at(-1)?.bottom ?? 0)
const width = computed(() => Math.max(1, ...points.value.map((p) => p.x + 1)))

const thumb = computed(() => {
	const first = points.value[active.value[0]]
	const last = points.value[active.value.at(-1) ?? -1]
	if (!first || !last) return null
	return { top: first.top + INSET, bottom: last.bottom - INSET, x: last.x }
})

function collect() {
	const found = [...document.querySelectorAll<HTMLElement>(".vp-doc :is(h2, h3, h4)[id]")]
	headings.value = found.map((el) => ({
		id: el.id,
		text: (el.textContent ?? "").replace(/​/g, "").trim(),
		depth: Number(el.tagName[1]) - 2,
	}))
}

function measure() {
	const items = list.value?.querySelectorAll<HTMLElement>("li")
	if (!items) return
	points.value = [...items].map((item, i) => ({
		x: headings.value[i].depth * INDENT,
		top: item.offsetTop,
		bottom: item.offsetTop + item.offsetHeight,
	}))
}

function track() {
	const els = headings.value.map((h) => document.getElementById(h.id))
	const viewTop = 80
	const viewBottom = window.innerHeight
	const visible: number[] = []
	let lastAbove = -1
	els.forEach((el, i) => {
		if (!el) return
		const top = el.getBoundingClientRect().top
		const next = els[i + 1]
		const end = next ? next.getBoundingClientRect().top : document.documentElement.scrollHeight
		if (top <= viewTop) lastAbove = i
		if (end > viewTop && top < viewBottom) visible.push(i)
	})
	active.value = visible.length > 0 ? visible : lastAbove >= 0 ? [lastAbove] : []
}

let frame = 0
function onScroll() {
	cancelAnimationFrame(frame)
	frame = requestAnimationFrame(track)
}

async function refresh() {
	await nextTick()
	collect()
	await nextTick()
	measure()
	track()
}

watch(() => route.path, refresh)

onMounted(() => {
	refresh()
	window.addEventListener("scroll", onScroll, { passive: true })
	window.addEventListener("resize", refresh)
})
onUnmounted(() => {
	window.removeEventListener("scroll", onScroll)
	window.removeEventListener("resize", refresh)
	cancelAnimationFrame(frame)
})
</script>

<template>
	<nav v-if="headings.length > 0" class="fd-toc" aria-labelledby="fd-toc-title">
		<p id="fd-toc-title" class="fd-toc-title">
			<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 6h18M3 12h12M3 18h16" /></svg>
			On this page
		</p>
		<div class="fd-toc-body">
			<svg class="fd-toc-line" :width="width" :height="height" aria-hidden="true">
				<path :d="path" />
			</svg>
			<div
				v-if="thumb"
				class="fd-toc-thumb"
				:style="{ clipPath: `inset(${thumb.top}px 0 ${height - thumb.bottom}px 0)` }"
				aria-hidden="true"
			>
				<svg :width="width" :height="height"><path :d="path" /></svg>
			</div>
			<span
				v-if="thumb"
				class="fd-toc-dot"
				:style="{ transform: `translate(${thumb.x - 1.5}px, ${thumb.bottom - 2}px)` }"
				aria-hidden="true"
			></span>
			<ul ref="list">
				<li v-for="(h, i) in headings" :key="h.id" :style="{ paddingLeft: `${h.depth * INDENT + 14}px` }">
					<a :href="`#${h.id}`" :class="{ active: active.includes(i) }" :aria-current="active[0] === i ? 'location' : undefined">
						{{ h.text }}
					</a>
				</li>
			</ul>
		</div>
	</nav>
</template>
