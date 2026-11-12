<script setup lang="ts">
import { computed, nextTick, reactive, ref } from "vue"
import { useData } from "vitepress"

type Item = { name: string; price: number }
type Icon =
	| "workspace" | "camera" | "terrain" | "part" | "spawn" | "players" | "player" | "playergui"
	| "gui" | "frame" | "layout" | "label" | "button" | "storage" | "module"
type Node = { id: string; name: string; icon: Icon; parent?: string; component?: { id: string; label: string } }
type Section = { title: string; rows: Record<string, string> }
type Steps = Partial<Record<"shop" | "itemRow", string[]>>

const { theme } = useData()
const landing = theme.value.landing

const ITEMS: Item[] = [
	{ name: "Sword", price: 20 },
	{ name: "Shield", price: 30 },
	{ name: "Potion", price: 10 },
]

const coins = ref(30)
const owned = reactive<Record<string, boolean>>({})
const selected = ref("coins")
const pane = ref<"explorer" | "properties">("explorer")

function pick(id: string) {
	selected.value = id
	if (window.matchMedia("(max-width: 520px)").matches) pane.value = "properties"
}
const file = ref<"shop" | "itemRow">("shop")
const ran = reactive({ shop: false, itemRow: false })
const flashing = reactive(new Set<string>())
const written = reactive(new Set<string>())
const code = ref<HTMLElement>()

const nodes: Node[] = [
	{ id: "workspace", name: "Workspace", icon: "workspace" },
	{ id: "camera", name: "Camera", icon: "camera", parent: "workspace" },
	{ id: "terrain", name: "Terrain", icon: "terrain", parent: "workspace" },
	{ id: "baseplate", name: "Baseplate", icon: "part", parent: "workspace" },
	{ id: "spawn", name: "SpawnLocation", icon: "spawn", parent: "workspace" },
	{ id: "players", name: "Players", icon: "players" },
	{ id: "player", name: "Player1", icon: "player", parent: "players" },
	{ id: "playergui", name: "PlayerGui", icon: "playergui", parent: "player" },
	{ id: "approot", name: "AppRoot", icon: "gui", parent: "playergui" },
	{ id: "frame", name: "Shop", icon: "frame", parent: "approot", component: { id: "shop", label: "<Shop>" } },
	{ id: "layout", name: "UIListLayout", icon: "layout", parent: "frame" },
	{ id: "coins", name: "Coins", icon: "label", parent: "frame" },
	{ id: "earn", name: "Earn", icon: "button", parent: "frame" },
	...ITEMS.map((item) => ({
		id: `btn-${item.name}`,
		name: item.name,
		icon: "button" as const,
		parent: "frame",
		component: { id: `row-${item.name}`, label: "<ItemRow>" },
	})),
	{ id: "replicated", name: "ReplicatedStorage", icon: "storage" },
	{ id: "rivueui", name: "RivueUI", icon: "module", parent: "replicated" },
]

const byId = new Map(nodes.map((node) => [node.id, node]))
const hasChildren = new Set(nodes.flatMap((node) => (node.parent ? [node.parent] : [])))
const collapsed = reactive(new Set(["workspace", "replicated"]))
const filter = ref("")

function depth(node: Node): number {
	return node.parent ? depth(byId.get(node.parent)!) + 1 : 0
}

function ancestors(node: Node): Node[] {
	const parent = node.parent ? byId.get(node.parent) : undefined
	return parent ? [parent, ...ancestors(parent)] : []
}

const visible = computed(() => {
	const query = filter.value.trim().toLowerCase()
	if (query) {
		const matches = nodes.filter((node) => `${node.name} ${node.component?.label ?? ""}`.toLowerCase().includes(query))
		const keep = new Set(matches.flatMap((node) => [node, ...ancestors(node)]))
		return nodes.filter((node) => keep.has(node))
	}
	return nodes.filter((node) => !ancestors(node).some((parent) => collapsed.has(parent.id)))
})

function toggle(id: string) {
	if (collapsed.has(id)) collapsed.delete(id)
	else collapsed.add(id)
}

const VIEW = { width: 640, height: 360, horizon: 128, focal: 230 }

function project(x: number, y: number, z: number) {
	return `${(VIEW.width / 2 + (VIEW.focal * x) / z).toFixed(1)},${(VIEW.horizon + (VIEW.focal * (1 - y)) / z).toFixed(1)}`
}

const polygon = (points: [number, number, number][]) => points.map(([x, y, z]) => project(x, y, z)).join(" ")

function shade(hex: string, amount: number) {
	const channels = [1, 3, 5].map((at) => Math.min(255, Math.round(parseInt(hex.slice(at, at + 2), 16) * amount)))
	return `rgb(${channels.join(",")})`
}

type Shape = { points: string; fill: string; opacity?: number }

// one side, the front and the top; the camera sits above everything and looks down +z
function box(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: string): Shape[] {
	const shapes: Shape[] = []
	const side = (x0 + x1) / 2 > 0 ? x0 : x1
	shapes.push({ points: polygon([[side, y0, z0], [side, y0, z1], [side, y1, z1], [side, y1, z0]]), fill: shade(color, 0.7) })
	shapes.push({ points: polygon([[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0]]), fill: shade(color, 0.86) })
	shapes.push({ points: polygon([[x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]]), fill: shade(color, 1.06) })
	return shapes
}

// the sun sits behind the camera on the left, so shadows fall back and to the right
function shadow(x0: number, x1: number, z0: number, z1: number, height: number): Shape {
	const dx = height * 0.7
	const dz = height * 0.9
	return {
		points: polygon([[x0, 0, z0], [x1, 0, z0], [x1 + dx, 0, z0 + dz], [x1 + dx, 0, z1 + dz], [x0 + dx, 0, z1 + dz], [x0, 0, z1]]),
		fill: "#000",
		opacity: 0.18,
	}
}

function disc(cx: number, y: number, cz: number, radius: number, fill: string): Shape {
	const points = Array.from({ length: 28 }, (_, i): [number, number, number] => {
		const angle = (i / 28) * Math.PI * 2
		return [cx + Math.cos(angle) * radius, y, cz + Math.sin(angle) * radius]
	})
	return { points: polygon(points), fill }
}

const TILE = 0.6
const CELL = TILE / 4
const NEAR = 0.9
const range = (from: number, to: number, step: number) => Array.from({ length: Math.floor((to - from) / step) + 1 }, (_, i) => from + i * step)

const floorTiles = range(0, 30, TILE).flatMap((z0) =>
	range(-Math.ceil((1.5 * (z0 + TILE)) / TILE), Math.ceil((1.5 * (z0 + TILE)) / TILE), 1)
		.filter((col) => (col + Math.round(z0 / TILE)) % 2 === 0)
		.map((col) => {
			const x0 = col * TILE
			const near = Math.max(z0, NEAR)
			return polygon([[x0, 0, near], [x0 + TILE, 0, near], [x0 + TILE, 0, z0 + TILE], [x0, 0, z0 + TILE]])
		}),
)

const floorCells = [
	...range(-18, 18, CELL).map((x) => ({ a: project(x, 0, NEAR), b: project(x, 0, 12) })),
	...range(NEAR - (NEAR % CELL) + CELL, 12, CELL).map((z) => ({ a: project(-18, 0, z), b: project(18, 0, z) })),
]

const floorEdges = [
	...range(-60, 60, TILE).map((x) => ({ a: project(x, 0, NEAR), b: project(x, 0, 60) })),
	...range(TILE * 2, 60, TILE).map((z) => ({ a: project(-60, 0, z), b: project(60, 0, z) })),
]

const SPAWN_COLOR = "#c8c8ca"
const SPAWN = { x0: -3.05, x1: -1.85, z0: 2.5, z1: 3.7, top: 0.1 }

function spawnDecal(cx: number, y: number, cz: number, radius: number): Shape[] {
	const at = (r: number, degrees: number): [number, number, number] => {
		const angle = (degrees * Math.PI) / 180
		return [cx + Math.cos(angle) * r * radius, y, cz + Math.sin(angle) * r * radius]
	}
	const spikes = Array.from({ length: 8 }, (_, k) => {
		const a = k * 45
		return {
			points: polygon([at(0.48, a - 20), at(0.66, a - 4), at(0.84, a + 14), at(1, a + 34), at(0.8, a + 24), at(0.64, a + 20), at(0.48, a + 22)]),
			fill: "#1d1d1f",
		}
	})
	return [...spikes, disc(cx, y, cz, 0.54 * radius, "#1d1d1f"), disc(cx, y + 0.0005, cz, 0.4 * radius, SPAWN_COLOR)]
}

const sceneShapes: Shape[] = [
	shadow(SPAWN.x0, SPAWN.x1, SPAWN.z0, SPAWN.z1, SPAWN.top),
	...box(SPAWN.x0, SPAWN.x1, 0, SPAWN.top, SPAWN.z0, SPAWN.z1, SPAWN_COLOR),
	...spawnDecal((SPAWN.x0 + SPAWN.x1) / 2, SPAWN.top + 0.001, (SPAWN.z0 + SPAWN.z1) / 2, 0.46),
]

function rowState(item: Item) {
	const isOwned = owned[item.name] === true
	const disabled = isOwned || coins.value < item.price
	return {
		text: isOwned ? `${item.name} · Owned` : `${item.name} · ${item.price}`,
		transparency: disabled ? "0.5" : "0",
		interactable: disabled ? "false" : "true",
		disabled,
	}
}

const data = (className: string, name: string, parent: string): Section => ({
	title: "Data",
	rows: { ClassName: className, Name: name, Parent: parent },
})

const sections = computed<Section[]>(() => {
	const id = selected.value
	if (id === "workspace") return [{ title: "Data", rows: { ClassName: "Workspace", Name: "Workspace", Parent: "game" } }]
	if (id === "camera") return [{ title: "Data", rows: { ClassName: "Camera", Name: "Camera", Parent: "Workspace" } }, { title: "Camera", rows: { CameraType: "Custom", FieldOfView: "70" } }]
	if (id === "terrain") return [{ title: "Data", rows: { ClassName: "Terrain", Name: "Terrain", Parent: "Workspace" } }]
	if (id === "baseplate") return [{ title: "Data", rows: { ClassName: "Part", Name: "Baseplate", Parent: "Workspace" } }, { title: "Behavior", rows: { Anchored: "true", Locked: "true" } }]
	if (id === "spawn") return [{ title: "Data", rows: { ClassName: "SpawnLocation", Name: "SpawnLocation", Parent: "Workspace" } }, { title: "Behavior", rows: { Anchored: "true" } }]
	if (id === "players") return [{ title: "Data", rows: { ClassName: "Players", Name: "Players", Parent: "game" } }]
	if (id === "player") return [{ title: "Data", rows: { ClassName: "Player", Name: "Player1", Parent: "Players" } }]
	if (id === "replicated") return [{ title: "Data", rows: { ClassName: "ReplicatedStorage", Name: "ReplicatedStorage", Parent: "game" } }]
	if (id === "rivueui") return [{ title: "Data", rows: { ClassName: "ModuleScript", Name: "RivueUI", Parent: "ReplicatedStorage" } }]
	if (id === "playergui") return [{ title: "Data", rows: { ClassName: "PlayerGui", Name: "PlayerGui", Parent: "Player1" } }]
	if (id === "approot") return [{ title: "Data", rows: { ClassName: "ScreenGui", Name: "AppRoot", Parent: "PlayerGui" } }]
	if (id === "frame")
		return [data("Frame", "Shop", "AppRoot"), { title: "Shop state", rows: { coins: String(coins.value), owned: Object.keys(owned).join(", ") || "none" } }]
	if (id === "layout") return [data("UIListLayout", "UIListLayout", "Shop"), { title: "Layout", rows: { Padding: "0, 8", SortOrder: "LayoutOrder" } }]
	if (id === "coins") return [data("TextLabel", "Coins", "Shop"), { title: "Text", rows: { Text: `${coins.value} coins`, TextSize: "18" } }]
	if (id === "earn") return [data("TextButton", "Earn", "Shop"), { title: "Text", rows: { Text: "+10 coins" } }, { title: "Behavior", rows: { Interactable: "true" } }]
	const item = ITEMS.find((i) => id === `btn-${i.name}`)
	if (!item) return []
	const state = rowState(item)
	return [
		data("TextButton", item.name, "Shop"),
		{ title: "Appearance", rows: { BackgroundTransparency: state.transparency } },
		{ title: "Text", rows: { Text: state.text } },
		{ title: "Behavior", rows: { Interactable: state.interactable } },
		{
			title: "ItemRow props",
			rows: { name: `"${item.name}"`, price: String(item.price), owned: String(owned[item.name] === true), affordable: String(coins.value >= item.price) },
		},
	]
})

function flatten(list: Section[]) {
	return Object.fromEntries(list.flatMap((section) => Object.entries(section.rows).map(([key, value]) => [`${section.title}.${key}`, value])))
}

function flashFor(set: Set<string>, ids: string[]) {
	set.clear()
	requestAnimationFrame(() => {
		ids.forEach((id) => set.add(id))
		setTimeout(() => set.clear(), 1200)
	})
}

async function run(steps: Steps) {
	ran.shop = Boolean(steps.shop?.length) && file.value !== "shop"
	ran.itemRow = Boolean(steps.itemRow?.length) && file.value !== "itemRow"
	await nextTick()
	;(steps[file.value] ?? []).forEach((step, i) =>
		code.value?.querySelectorAll<HTMLElement>(`[data-step="${step}"]`).forEach((line) => {
			line.style.animationDelay = `${i * 0.25}s`
			line.classList.remove("rv-run")
			void line.offsetWidth
			line.classList.add("rv-run")
		}),
	)
}

function change(update: () => void, steps: Steps) {
	const rowsBefore = ITEMS.map(rowState)
	const shownBefore = flatten(sections.value)
	update()
	const shownAfter = flatten(sections.value)
	const touched = ["shop", "coins"]
	ITEMS.forEach((item, i) => {
		const after = rowState(item)
		if (after.text !== rowsBefore[i].text || after.disabled !== rowsBefore[i].disabled) touched.push(`row-${item.name}`, `btn-${item.name}`)
	})
	flashFor(flashing, touched)
	flashFor(
		written,
		Object.keys(shownAfter).filter((key) => shownAfter[key] !== shownBefore[key]),
	)
	run(steps)
}

function earn() {
	selected.value = "coins"
	change(() => (coins.value += 10), { shop: ["earn", "coins", "props"] })
}

function buy(item: Item) {
	if (rowState(item).disabled) return
	selected.value = `btn-${item.name}`
	change(
		() => {
			coins.value -= item.price
			owned[item.name] = true
		},
		{ itemRow: ["emit", "text", "disabled"], shop: ["call", "spend", "own", "coins", "props"] },
	)
}

function show(name: "shop" | "itemRow") {
	file.value = name
	ran[name] = false
}
</script>

<template>
	<section class="rv-studio" aria-label="Try it">
		<div class="rv-studio-window" :data-pane="pane">
			<div class="rv-pane-tabs" role="tablist" aria-label="Studio panels">
				<button type="button" role="tab" :aria-selected="pane === 'explorer'" @click="pane = 'explorer'">Explorer</button>
				<button type="button" role="tab" :aria-selected="pane === 'properties'" @click="pane = 'properties'">
					Properties <span class="rv-pane-target">{{ byId.get(selected)?.name }}</span>
				</button>
			</div>
			<div class="rv-panel rv-explorer">
				<div class="rv-panel-bar">Explorer</div>
				<label class="rv-filter">
					<span class="rv-visually-hidden">Filter the Explorer</span>
					<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>
					<input v-model="filter" type="search" placeholder="Filter workspace" spellcheck="false" />
				</label>
				<ul class="rv-tree" role="tree" aria-label="Explorer">
					<li v-for="node in visible" :key="node.id" role="treeitem" :aria-selected="selected === node.id" :aria-expanded="hasChildren.has(node.id) ? !collapsed.has(node.id) || Boolean(filter) : undefined">
						<div
							:class="['rv-node', { selected: selected === node.id, flash: flashing.has(node.id) }]"
							:style="{ paddingLeft: `${4 + depth(node) * 16}px` }"
						>
							<button
								v-if="hasChildren.has(node.id)"
								type="button"
								:class="['rv-caret', { open: !collapsed.has(node.id) || filter }]"
								:aria-label="collapsed.has(node.id) ? `Expand ${node.name}` : `Collapse ${node.name}`"
								@click="toggle(node.id)"
							>
								<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M3 2l4 3-4 3z" /></svg>
							</button>
							<span v-else class="rv-caret" aria-hidden="true"></span>
							<button type="button" class="rv-node-main" @click="pick(node.id)">
								<span :class="['rv-icon', `rv-icon-${node.icon}`]" aria-hidden="true"></span>
								<span class="rv-node-name">{{ node.name }}</span>
								<span v-if="node.component" :class="['rv-node-tag', { flash: flashing.has(node.component.id) }]">
									{{ node.component.label }}
								</span>
							</button>
						</div>
					</li>
				</ul>
			</div>

			<div class="rv-panel rv-stage">
				<div class="rv-panel-bar">Game view</div>
				<div class="rv-world">
					<svg class="rv-scene" :viewBox="`0 0 ${VIEW.width} ${VIEW.height}`" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
						<defs>
							<linearGradient id="rv-sky" x1="0" y1="0" x2="0" y2="1">
								<stop offset="0" stop-color="#5d8fc9" />
								<stop offset="1" stop-color="#c3d6e6" />
							</linearGradient>
							<linearGradient id="rv-haze" x1="0" y1="0" x2="0" y2="1">
								<stop offset="0" stop-color="#c3d6e6" stop-opacity="0" />
								<stop offset="0.25" stop-color="#c3d6e6" stop-opacity="0.9" />
								<stop offset="1" stop-color="#c3d6e6" stop-opacity="0" />
							</linearGradient>
							<radialGradient id="rv-vignette" cx="0.5" cy="0.45" r="0.75">
								<stop offset="0.55" stop-color="#000" stop-opacity="0" />
								<stop offset="1" stop-color="#000" stop-opacity="0.35" />
							</radialGradient>
						</defs>
						<rect :width="VIEW.width" :height="VIEW.horizon" fill="url(#rv-sky)" />
						<rect :y="VIEW.horizon" :width="VIEW.width" :height="VIEW.height - VIEW.horizon" fill="#8b8e94" />
						<g fill="#6e7177">
							<polygon v-for="(points, i) in floorTiles" :key="i" :points="points" />
						</g>
						<g class="rv-scene-cells">
							<line
								v-for="(line, i) in floorCells"
								:key="i"
								:x1="line.a.split(',')[0]"
								:y1="line.a.split(',')[1]"
								:x2="line.b.split(',')[0]"
								:y2="line.b.split(',')[1]"
							/>
						</g>
						<g class="rv-scene-edges">
							<line
								v-for="(line, i) in floorEdges"
								:key="i"
								:x1="line.a.split(',')[0]"
								:y1="line.a.split(',')[1]"
								:x2="line.b.split(',')[0]"
								:y2="line.b.split(',')[1]"
							/>
						</g>
						<rect :y="VIEW.horizon - 30" :width="VIEW.width" height="120" fill="url(#rv-haze)" />
						<polygon v-for="(shape, i) in sceneShapes" :key="`s${i}`" :points="shape.points" :fill="shape.fill" :fill-opacity="shape.opacity" />
						<rect :width="VIEW.width" :height="VIEW.height" fill="url(#rv-vignette)" />
					</svg>
					<div class="rv-shop-ui">
						<p :class="['rv-shop-coins', { flash: flashing.has('coins') }]" @click="selected = 'coins'">
							{{ coins }} coins
						</p>
						<button type="button" class="rv-shop-earn" @click="earn">+10 coins</button>
						<button
							v-for="item in ITEMS"
							:key="item.name"
							type="button"
							:class="['rv-shop-row', { flash: flashing.has(`btn-${item.name}`) }]"
							:disabled="rowState(item).disabled"
							@click="buy(item)"
						>
							{{ rowState(item).text }}
						</button>
					</div>
				</div>
				<p class="rv-note">
					Buy something or add coins. Components that <span class="rv-nowrap">re-render</span> turn blue in the Explorer, and the properties Rivue writes turn green.
				</p>
			</div>

			<div class="rv-panel rv-properties">
				<div class="rv-panel-bar">Properties</div>
				<div class="rv-props-scroll" tabindex="0" aria-label="Properties">
					<div v-for="section in sections" :key="section.title" class="rv-prop-section">
						<p class="rv-prop-title">
							<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 9 5 5 5-5" /></svg>{{ section.title }}
						</p>
						<dl>
							<template v-for="(value, key) in section.rows" :key="key">
								<dt :title="String(key)">{{ key }}</dt>
								<dd :class="{ flash: written.has(`${section.title}.${key}`) }">{{ value }}</dd>
							</template>
						</dl>
					</div>
				</div>
			</div>
		</div>

		<div class="rv-window rv-studio-code">
			<div class="rv-file-tabs" role="group" aria-label="File">
				<button type="button" :aria-pressed="file === 'shop'" @click="show('shop')">
					Shop.luau<span v-if="ran.shop" class="rv-ran" aria-label="ran"></span>
				</button>
				<button type="button" :aria-pressed="file === 'itemRow'" @click="show('itemRow')">
					ItemRow.luau<span v-if="ran.itemRow" class="rv-ran" aria-label="ran"></span>
				</button>
			</div>
			<div :key="file" ref="code" class="rv-code" v-html="file === 'shop' ? landing.shop : landing.itemRow"></div>
		</div>
	</section>
</template>
