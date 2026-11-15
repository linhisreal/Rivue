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
const file = ref<"shop" | "itemRow">("shop")
const ran = reactive({ shop: false, itemRow: false })
const flashing = reactive(new Set<string>())
const written = reactive(new Set<string>())
const code = ref<HTMLElement>()

// The Baseplate template's tree at play time, with the Instances Rivue made under PlayerGui.
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

// A tiny pinhole camera 1 stud-unit above the baseplate, so the floor, spawn pad and part share one perspective.
const VIEW = { width: 640, height: 360, horizon: 150, focal: 210 }

function project(x: number, y: number, z: number) {
	return `${(VIEW.width / 2 + (VIEW.focal * x) / z).toFixed(1)},${(VIEW.horizon + (VIEW.focal * (1 - y)) / z).toFixed(1)}`
}

const polygon = (points: [number, number, number][]) => points.map(([x, y, z]) => project(x, y, z)).join(" ")

const floorLines = [
	...Array.from({ length: 41 }, (_, i) => (i - 20) * 0.5).map((x) => ({ a: project(x, 0, 0.9), b: project(x, 0, 60) })),
	...Array.from({ length: 30 }, (_, i) => 1 + i * 0.5).map((z) => ({ a: project(-40, 0, z), b: project(40, 0, z) })),
]

const spawnTop = polygon([[-2.6, 0.08, 2.2], [-1.3, 0.08, 2.2], [-1.3, 0.08, 3.5], [-2.6, 0.08, 3.5]])
const spawnFront = polygon([[-2.6, 0, 2.2], [-1.3, 0, 2.2], [-1.3, 0.08, 2.2], [-2.6, 0.08, 2.2]])
const spawnMark = polygon([[-2.15, 0.081, 2.55], [-1.75, 0.081, 2.55], [-1.75, 0.081, 3.15], [-2.15, 0.081, 3.15]])
const blockTop = polygon([[1.4, 0.7, 2.6], [2.2, 0.7, 2.6], [2.2, 0.7, 3.4], [1.4, 0.7, 3.4]])
const blockFront = polygon([[1.4, 0, 2.6], [2.2, 0, 2.6], [2.2, 0.7, 2.6], [1.4, 0.7, 2.6]])
const blockSide = polygon([[1.4, 0, 2.6], [1.4, 0, 3.4], [1.4, 0.7, 3.4], [1.4, 0.7, 2.6]])

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

// Works out what Rivue would touch: Shop re-renders, and a row only when one of its props changed.
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
		<div class="rv-studio-window">
			<div class="rv-panel rv-explorer">
				<div class="rv-panel-bar">Explorer</div>
				<label class="rv-filter">
					<span class="rv-visually-hidden">Filter the Explorer</span>
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
							<button type="button" class="rv-node-main" @click="selected = node.id">
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
								<stop offset="0" stop-color="#4f8fd8" />
								<stop offset="1" stop-color="#bcdaf3" />
							</linearGradient>
							<linearGradient id="rv-haze" x1="0" y1="0" x2="0" y2="1">
								<stop offset="0" stop-color="#bcdaf3" stop-opacity="0" />
								<stop offset="0.45" stop-color="#c9dff0" stop-opacity="0.95" />
								<stop offset="1" stop-color="#c9dff0" stop-opacity="0" />
							</linearGradient>
						</defs>
						<rect :width="VIEW.width" :height="VIEW.horizon" fill="url(#rv-sky)" />
						<rect :y="VIEW.horizon" :width="VIEW.width" :height="VIEW.height - VIEW.horizon" fill="#6b6e73" />
						<g class="rv-scene-grid">
							<line v-for="(line, i) in floorLines" :key="i" :x1="line.a.split(',')[0]" :y1="line.a.split(',')[1]" :x2="line.b.split(',')[0]" :y2="line.b.split(',')[1]" />
						</g>
						<rect :y="VIEW.horizon - 26" :width="VIEW.width" height="70" fill="url(#rv-haze)" />
						<polygon :points="spawnFront" fill="#3f4246" />
						<polygon :points="spawnTop" fill="#8b8e93" />
						<polygon :points="spawnMark" fill="#5f6266" />
						<polygon :points="blockSide" fill="#7c7b80" />
						<polygon :points="blockFront" fill="#8f8e93" />
						<polygon :points="blockTop" fill="#b4b3b7" />
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
					Buy something or add coins. Explorer marks what re-rendered in blue, Properties shows what was written in green.
				</p>
			</div>

			<div class="rv-panel rv-properties">
				<div class="rv-panel-bar">Properties</div>
				<div v-for="section in sections" :key="section.title" class="rv-prop-section">
					<p class="rv-prop-title">
						<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 9 5 5 5-5" /></svg>{{ section.title }}
					</p>
					<dl>
						<template v-for="(value, key) in section.rows" :key="key">
							<dt>{{ key }}</dt>
							<dd :class="{ flash: written.has(`${section.title}.${key}`) }">{{ value }}</dd>
						</template>
					</dl>
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
