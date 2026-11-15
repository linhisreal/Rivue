<script setup lang="ts">
import { computed, ref } from "vue"
import { useData, withBase } from "vitepress"
import { openSearch, setSidebarCollapsed, sidebarCollapsed, useDismiss } from "./composables"

const sections = [
	{
		title: "Guide",
		text: "Learn Rivue step by step",
		link: "/guide/01-introduction",
		icon: "M4 19.5V5a2 2 0 0 1 2-2h14v16H6a2 2 0 0 0-2 2.5zM8 7h8",
	},
	{
		title: "Examples",
		text: "Components you can copy, each one tested",
		link: "/examples/counter",
		icon: "M4 5h16v14H4zM4 9h16M9 9v10",
	},
	{
		title: "API reference",
		text: "Every function, component and package",
		link: "/API",
		icon: "M8 3H7a2 2 0 0 0-2 2v5a2 2 0 0 1-2 2 2 2 0 0 1 2 2v5a2 2 0 0 0 2 2h1M16 3h1a2 2 0 0 1 2 2v5a2 2 0 0 0 2 2 2 2 0 0 0-2 2v5a2 2 0 0 1-2 2h-1",
	},
]

const { page } = useData()
const current = computed(() => {
	const at = page.value.relativePath
	if (/^(api\/|API\.md)/.test(at)) return sections[2]
	if (at.startsWith("examples/")) return sections[1]
	return sections[0]
})
const open = ref(false)
const menu = ref<HTMLElement>()
useDismiss(menu, open)
</script>

<template>
	<div class="fd-sidebar-top">
		<div class="fd-brand-row">
			<a class="fd-brand" :href="withBase('/')">
				<img :src="withBase('/icon-192.png')" alt="" width="22" height="22" />
				<span>Rivue</span>
			</a>
			<button
				type="button"
				class="fd-icon-button"
				:aria-label="sidebarCollapsed ? 'Keep sidebar open' : 'Hide sidebar'"
				@click="setSidebarCollapsed(!sidebarCollapsed)"
			>
				<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="16" rx="2" /><path d="M9 4v16" /></svg>
			</button>
		</div>
		<button type="button" class="fd-search" @click="openSearch">
			<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>
			<span>Search</span>
			<span class="fd-keys"><kbd>Ctrl</kbd><kbd>K</kbd></span>
		</button>
		<div ref="menu" class="fd-switcher">
			<button type="button" class="fd-switcher-button" :aria-expanded="open" aria-controls="fd-switcher-list" @click="open = !open">
				<svg class="fd-switcher-icon" viewBox="0 0 24 24" aria-hidden="true"><path :d="current.icon" /></svg>
				<span>{{ current.title }}</span>
				<svg class="fd-switcher-caret" viewBox="0 0 24 24" aria-hidden="true"><path d="m7 15 5 5 5-5M7 9l5-5 5 5" /></svg>
			</button>
			<div v-show="open" id="fd-switcher-list" class="fd-switcher-list">
				<a
					v-for="section in sections"
					:key="section.title"
					:href="withBase(section.link)"
					:aria-current="section === current ? 'page' : undefined"
					@click="open = false"
				>
					<svg class="fd-switcher-icon" viewBox="0 0 24 24" aria-hidden="true"><path :d="section.icon" /></svg>
					<span>
						<b>{{ section.title }}</b>
						<small>{{ section.text }}</small>
					</span>
				</a>
			</div>
		</div>
	</div>
</template>
