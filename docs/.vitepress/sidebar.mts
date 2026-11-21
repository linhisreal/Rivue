// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import type { DefaultTheme } from "vitepress"
import type { Example } from "./examples.mts"

type Page = [title: string, file: string]

const GUIDE: Page[] = [
	["Introduction", "01-introduction"],
	["State", "02-state"],
	["Describing UI", "03-describing-ui"],
	["Components", "04-components"],
	["Forms and input", "05-forms-and-input"],
	["Styling and layout", "06-styling-and-layout"],
	["Effects and animation", "07-effects-and-animation"],
	["Sharing state and the server", "08-state-and-server"],
	["Performance and debugging", "09-performance-and-debugging"],
	["Organising a project", "10-organising-a-project"],
	["Style rules", "11-style-rules"],
]

const ADVANCED: Page[] = [
	["Writing composables", "12-writing-composables"],
	["Component patterns", "13-advanced-components"],
	["Organising state", "14-state-architecture"],
	["Performance in depth", "15-performance-in-depth"],
	["Testing UI", "16-testing-ui"],
	["Screens and navigation", "17-screens-and-navigation"],
]

const API: [group: string, pages: Page[]][] = [
	[
		"Reactivity",
		[
			["Core", "reactivity-core"],
			["Utilities", "reactivity-utilities"],
			["Array helpers", "array"],
			["Advanced", "reactivity-advanced"],
		],
	],
	[
		"Components and rendering",
		[
			["Render function", "render-function"],
			["Components", "component"],
			["Lifecycle hooks", "lifecycle"],
			["Built-in components", "builtins"],
			["Directives", "directives"],
		],
	],
	[
		"Application",
		[
			["Application", "application"],
			["Scheduler", "scheduler"],
		],
	],
	[
		"Roblox",
		[
			["Roblox composables", "roblox"],
			["RivueRemote", "remote"],
			["RivueRouter", "router"],
			["Instance pool", "pool"],
		],
	],
	["Utilities", [["Utilities and debugging", "utilities"]]],
]

const LEARN: [folder: string, pages: Page[]][] = [
	["Basics", GUIDE.slice(0, 5)],
	["Styling and motion", GUIDE.slice(5, 7)],
	["Building a game", GUIDE.slice(7)],
]
const PATTERNS: [folder: string, pages: Page[]][] = [
	["Patterns", ADVANCED.slice(0, 3)],
	["Scaling up", ADVANCED.slice(3)],
]

export type Chapter = { file: string; title: string; number: number; folder: string }

export const CHAPTERS: Chapter[] = [...LEARN, ...PATTERNS].flatMap(([folder, pages]) =>
	pages.map(([title, file]) => ({ file, title, folder, number: Number(file.slice(0, 2)) })),
)

const links = (dir: string, pages: Page[]) => pages.map(([text, file]) => ({ text, link: `/${dir}/${file}` }))
const folder = (text: string, items: DefaultTheme.SidebarItem[]) => ({ text, collapsed: true, items })

const guideSidebar: DefaultTheme.SidebarItem[] = [
	{
		text: "Getting started",
		items: [
			{ text: "Introduction", link: "/introduction" },
			{ text: "Installation", link: "/INSTALLATION" },
			{ text: "Coming from Vue", link: "/VUE" },
			{ text: "Coming from React-lua or Fusion", link: "/COMING-FROM-REACT" },
		],
	},
	{
		text: "Learn",
		link: "/GUIDE",
		items: LEARN.map(([text, pages]) => folder(text, links("guide", pages))),
	},
	{
		text: "Advanced",
		items: PATTERNS.map(([text, pages]) => folder(text, links("guide", pages))),
	},
	{
		text: "Tools",
		items: [
			{ text: "DevTools", link: "/DEVTOOLS" },
			{ text: "Architecture", link: "/ARCHITECTURE" },
			{ text: "Releasing", link: "/RELEASING" },
		],
	},
]

const apiSidebar: DefaultTheme.SidebarItem[] = [
	{ items: [{ text: "Overview", link: "/API" }] },
	{ text: "Reference", items: API.map(([group, pages]) => folder(group, links("api", pages))) },
]

export function sidebar(examples: Example[]): DefaultTheme.Sidebar {
	const examplesSidebar = [{ text: "Examples", items: examples.map((e) => ({ text: e.name, link: `/examples/${e.slug}` })) }]
	return { "/api/": apiSidebar, "/API": apiSidebar, "/examples/": examplesSidebar, "/": guideSidebar }
}
