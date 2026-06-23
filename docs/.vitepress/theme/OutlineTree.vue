<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from "vue"
import { useData, useRoute } from "vitepress"

type Heading = { id: string; text: string; depth: number; kind?: string; group?: string }
type Point = { x: number; top: number; bottom: number }

const INDENT = 12
const GROUPS: Record<string, string> = { function: "Functions", component: "Components", type: "Types", property: "Properties", directive: "Directives" }
const INSET = 6
const PAD = 4

const route = useRoute()
const { frontmatter } = useData()
const headings = ref<Heading[]>([])
const points = ref<Point[]>([])
const active = ref<number[]>([])
const list = ref<HTMLElement>()
const line = ref<SVGPathElement>()
const starts = ref<number[]>([])
const ends = ref<number[]>([])
const down = ref(true)
let lastY = 0

const path = computed(() =>
	points.value
		.map((p, i) => {
			const x = p.x + 0.5
			const prev = points.value[i - 1]
			if (!prev) return `M${x} ${p.top + INSET} L${x} ${p.bottom - INSET}`
			const from = prev.bottom - INSET
			const to = p.top + INSET
			const mid = (from + to) / 2
			return `C${prev.x + 0.5} ${mid} ${x} ${mid} ${x} ${to} L${x} ${p.bottom - INSET}`
		})
		.join(" "),
)

const height = computed(() => points.value.at(-1)?.bottom ?? 0)
const width = computed(() => Math.max(1, ...points.value.map((p) => p.x + PAD)))

const thumb = computed(() => {
	const first = points.value[active.value[0]]
	const last = points.value[active.value.at(-1) ?? -1]
	if (!first || !last) return null
	const distance = down.value ? ends.value[active.value.at(-1) ?? 0] : starts.value[active.value[0]]
	return { top: first.top + INSET, bottom: last.bottom - INSET, distance: distance ?? 0 }
})

const all = ref<Heading[]>([])
const kindFilter = ref<string>()
const kinds = computed(() => {
	const counts = new Map<string, number>()
	for (const h of all.value) if (h.kind) counts.set(h.kind, (counts.get(h.kind) ?? 0) + 1)
	return counts.size > 1 ? [...counts] : []
})

function applyFilter() {
	const list = kindFilter.value ? all.value.filter((h) => h.kind === kindFilter.value) : all.value
	// group labels only when a page mixes kinds and keeps each kind in one block
	const runs = list.filter((h, i) => h.kind && h.kind !== list[i - 1]?.kind).map((h) => h.kind)
	const grouped = runs.length > 1 && new Set(runs).size === runs.length
	headings.value = list.map((h, i) => ({
		...h,
		group: grouped && h.kind && h.kind !== list[i - 1]?.kind ? GROUPS[h.kind] : undefined,
	}))
}

async function filterBy(kind: string) {
	kindFilter.value = kindFilter.value === kind ? undefined : kind
	applyFilter()
	await nextTick()
	await remeasure()
	track()
}

function collect() {
	const deepest = typeof frontmatter.value.outline === "number" ? frontmatter.value.outline : 4
	const levels = ["h2", "h3", "h4"].slice(0, Math.max(1, deepest - 1)).join(", ")
	const found = [...document.querySelectorAll<HTMLElement>(`.vp-doc :is(${levels})[id]`)]
	all.value = found.map((el) => ({
		id: el.id,
		text: (el.textContent ?? "").replace(/​/g, "").trim(),
		depth: Number(el.tagName[1]) - 2,
		kind: el.dataset.kind,
	}))
	kindFilter.value = undefined
	applyFilter()
}

function measure() {
	const items = list.value?.querySelectorAll<HTMLElement>("li")
	if (!items) return
	points.value = [...items].map((item, i) => ({
		x: headings.value[i].depth * INDENT + PAD,
		top: item.offsetTop,
		bottom: item.offsetTop + item.offsetHeight,
	}))
}

function lengthAt(el: SVGPathElement, y: number) {
	let low = 0
	let high = el.getTotalLength()
	for (let i = 0; i < 24; i++) {
		const mid = (low + high) / 2
		if (el.getPointAtLength(mid).y < y) low = mid
		else high = mid
	}
	return high
}

function measureDistances() {
	const el = line.value
	starts.value = el ? points.value.map((p) => lengthAt(el, p.top + INSET)) : []
	ends.value = el ? points.value.map((p) => lengthAt(el, p.bottom - INSET)) : []
}

function track() {
	const readingLine = window.innerHeight * 0.3
	const atBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2
	let current = 0
	headings.value.forEach((h, i) => {
		const el = document.getElementById(h.id)
		if (el && el.getBoundingClientRect().top <= readingLine) current = i
	})
	if (atBottom) current = headings.value.length - 1
	active.value = headings.value.length > 0 ? [current] : []
}

let frame = 0
function onScroll() {
	if (window.scrollY !== lastY) down.value = window.scrollY > lastY
	lastY = window.scrollY
	cancelAnimationFrame(frame)
	frame = requestAnimationFrame(track)
}

async function remeasure() {
	measure()
	await nextTick()
	measureDistances()
}

function resetDirection() {
	down.value = true
	lastY = window.scrollY
}

async function refresh() {
	resetDirection()
	await nextTick()
	collect()
	await nextTick()
	await remeasure()
	resetDirection()
	track()
}

// item heights change when Geist arrives or a long heading wraps, and stale distances put the dot at the wrong end
const resize = typeof ResizeObserver === "undefined" ? undefined : new ResizeObserver(() => remeasure())
watch(list, (el, old) => {
	if (old) resize?.unobserve(old)
	if (el) resize?.observe(el)
})

watch(() => route.path, refresh)

onMounted(() => {
	refresh()
	document.fonts.ready.then(remeasure)
	window.addEventListener("scroll", onScroll, { passive: true })
	window.addEventListener("resize", refresh)
})
onUnmounted(() => {
	window.removeEventListener("scroll", onScroll)
	window.removeEventListener("resize", refresh)
	resize?.disconnect()
	cancelAnimationFrame(frame)
})
</script>

<template>
	<nav v-if="headings.length > 0" class="fd-toc" aria-labelledby="fd-toc-title">
		<p id="fd-toc-title" class="fd-toc-title">
			<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 6h18M3 12h12M3 18h16" /></svg>
			On this page
		</p>
		<div v-if="kinds.length" class="fd-toc-kinds" role="group" aria-label="Show only">
			<button
				v-for="[kind, count] in kinds"
				:key="kind"
				type="button"
				:aria-pressed="kindFilter === kind"
				:title="`Show only ${GROUPS[kind].toLowerCase()}`"
				@click="filterBy(kind)"
			>
				<span class="fd-kind-icon" :data-kind="kind" aria-hidden="true"></span>{{ GROUPS[kind] }}
				<span class="fd-toc-count">{{ count }}</span>
			</button>
		</div>
		<div class="fd-toc-body">
			<svg class="fd-toc-line" :width="width" :height="height" aria-hidden="true">
				<path ref="line" :d="path" />
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
				:style="{ offsetPath: `path('${path}')`, offsetDistance: `${thumb.distance}px` }"
				aria-hidden="true"
			></span>
			<ul ref="list">
				<li v-for="(h, i) in headings" :key="h.id" :style="{ paddingLeft: `${h.depth * INDENT + PAD + 14}px` }">
					<span v-if="h.group" class="fd-toc-group">{{ h.group }}</span>
					<a :href="`#${h.id}`" :class="{ active: active.includes(i) }" :aria-current="active[0] === i ? 'location' : undefined">
						<span v-if="h.kind" class="fd-kind-icon" :data-kind="h.kind" aria-hidden="true"></span>{{ h.text }}
					</a>
				</li>
			</ul>
		</div>
	</nav>
</template>
