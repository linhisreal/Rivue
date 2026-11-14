import path from "node:path"
import { defineConfig } from "vitepress"
import { withMermaid } from "vitepress-plugin-mermaid"

const REPO = "https://github.com/linhisreal/Rivue"
const DOCS = path.resolve(__dirname, "..")

function githubLinks(md: any) {
	const render = md.renderer.rules.link_open ?? ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options))
	md.renderer.rules.link_open = (tokens, idx, options, env, self) => {
		const href: string = tokens[idx].attrGet("href") ?? ""
		if (env?.relativePath && !/^[a-z]+:|^#|^\//i.test(href)) {
			const [file, hash] = href.split("#")
			const target = path.resolve(DOCS, path.dirname(env.relativePath), file)
			if (target === path.join(DOCS, "README.md")) {
				const up = path.relative(path.dirname(path.resolve(DOCS, env.relativePath)), DOCS)
				tokens[idx].attrSet("href", `${up ? up + "/" : "./"}index.md${hash ? `#${hash}` : ""}`)
			} else if (!target.startsWith(DOCS + path.sep)) {
				const repoPath = path.relative(path.resolve(DOCS, ".."), target).split(path.sep).join("/")
				const kind = path.extname(target) ? "blob" : "tree"
				tokens[idx].attrSet("href", `${REPO}/${kind}/main/${repoPath}${hash ? `#${hash}` : ""}`)
			}
		}
		return render(tokens, idx, options, env, self)
	}
}

function githubSlug(text: string): string {
	return text
		.trim()
		.toLowerCase()
		.replace(/<[^>]*>/g, "")
		.replace(/[^\p{L}\p{N}\s_-]/gu, "")
		.replace(/\s/g, "-")
}

const guide = [
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
const advanced = [
	["Writing composables", "12-writing-composables"],
	["Component patterns", "13-advanced-components"],
	["Organising state", "14-state-architecture"],
	["Performance in depth", "15-performance-in-depth"],
	["Testing UI", "16-testing-ui"],
	["Screens and navigation", "17-screens-and-navigation"],
]
const icon = (d: string) =>
	`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`

const home = {
	layout: "home",
	hero: {
		name: "Rivue",
		text: "Vue components for Roblox UI",
		tagline: "Write UI as components in Luau. When state changes, Rivue updates the Instances that use it.",
		image: { src: "/icon-512.png", alt: "Rivue" },
		actions: [
			{ theme: "brand", text: "Get started", link: "/guide/01-introduction" },
			{ theme: "alt", text: "API reference", link: "/API" },
			{ theme: "alt", text: "Coming from Vue", link: "/VUE" },
		],
	},
	features: [
		{
			icon: icon('<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>'),
			title: "Reactivity",
			details: "ref, reactive, computed and watch. Only components that read a changed value re-render.",
			link: "/guide/02-state",
		},
		{
			icon: icon('<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>'),
			title: "Components",
			details: "setup and render, props, emits, slots, provide/inject and every lifecycle hook.",
			link: "/guide/04-components",
		},
		{
			icon: icon('<path d="M12 3a9 9 0 1 0 9 9c0-1.7-1.3-3-3-3h-2a2 2 0 0 1-2-2V5a2 2 0 0 0-2-2z"/><circle cx="7.5" cy="11.5" r="1"/><circle cx="9.5" cy="7.5" r="1"/>'),
			title: "Styling and layout",
			details: "Style classes with hover and device variants, plus layout, flex, padding and corner props.",
			link: "/guide/06-styling-and-layout",
		},
		{
			icon: icon('<path d="M5 3v18"/><path d="M5 12c4-6 10 6 14 0"/><path d="M19 3v18"/>'),
			title: "Animation",
			details: "Transition, TransitionGroup, tweens and springs, with fade, slide and pop presets.",
			link: "/guide/07-effects-and-animation",
		},
		{
			icon: icon('<path d="M4 12h6"/><path d="M14 12h6"/><circle cx="12" cy="12" r="2"/><path d="M12 4v4"/><path d="M12 16v4"/>'),
			title: "Remote and Router",
			details: "Checked client/server calls and replicated state, and screens with history and guards.",
			link: "/api/remote",
		},
		{
			icon: icon('<path d="M4 5h16v11H4z"/><path d="M8 20h8"/><path d="M12 16v4"/><path d="m8 9 2 2-2 2"/><path d="M13 13h3"/>'),
			title: "DevTools",
			details: "A Studio plugin that shows each component's props, state, renders and network traffic.",
			link: "/DEVTOOLS",
		},
	],
}

const api = [
	["Reactivity: core", "reactivity-core"],
	["Reactivity: utilities", "reactivity-utilities"],
	["Reactivity: advanced", "reactivity-advanced"],
	["Array helpers", "array"],
	["Components", "component"],
	["Render function", "render-function"],
	["Application", "application"],
	["Lifecycle hooks", "lifecycle"],
	["Built-in components", "builtins"],
	["Directives", "directives"],
	["Scheduler", "scheduler"],
	["Roblox composables", "roblox"],
	["RivueRemote", "remote"],
	["RivueRouter", "router"],
	["Instance pool", "pool"],
	["Utilities and debugging", "utilities"],
]

export default withMermaid(
	defineConfig({
		title: "Rivue",
		description: "Vue 3's component model for Roblox UI, in Luau",
		base: "/Rivue/",
		cleanUrls: true,
		rewrites: { "README.md": "index.md" },
		srcExclude: ["assets/README.md"],
		lastUpdated: true,
		head: [
			["link", { rel: "icon", href: "/Rivue/favicon.ico", sizes: "any" }],
			["link", { rel: "icon", type: "image/png", sizes: "32x32", href: "/Rivue/favicon-32.png" }],
			["link", { rel: "apple-touch-icon", href: "/Rivue/apple-touch-icon.png" }],
			["meta", { name: "theme-color", content: "#1f6feb" }],
		],
		vite: { publicDir: path.resolve(DOCS, "assets/web") },
		transformPageData(pageData) {
			if (pageData.relativePath === "index.md") {
				pageData.frontmatter = { ...pageData.frontmatter, ...home }
			}
		},
		markdown: { config: githubLinks, anchor: { slugify: githubSlug } },
		themeConfig: {
			logo: { src: "/icon-192.png", alt: "Rivue" },
			outline: { level: [2, 3] },
			footer: {
				message: "Released under the Rivue License, based on PolyForm Noncommercial 1.0.0.",
				copyright: "Copyright © 2025-2026 linhisreal",
			},
			nav: [
				{ text: "Guide", link: "/GUIDE" },
				{ text: "API", link: "/API" },
				{ text: "Examples", link: `${REPO}/tree/main/examples` },
			],
			sidebar: [
				{ text: "Guide", items: guide.map(([text, file]) => ({ text, link: `/guide/${file}` })) },
				{ text: "Advanced", items: advanced.map(([text, file]) => ({ text, link: `/guide/${file}` })) },
				{ text: "API reference", collapsed: true, items: api.map(([text, file]) => ({ text, link: `/api/${file}` })) },
				{
					text: "More",
					items: [
						{ text: "Coming from Vue", link: "/VUE" },
						{ text: "Coming from React-lua or Fusion", link: "/COMING-FROM-REACT" },
						{ text: "DevTools", link: "/DEVTOOLS" },
						{ text: "Architecture", link: "/ARCHITECTURE" },
						{ text: "Releasing", link: "/RELEASING" },
					],
				},
			],
			socialLinks: [{ icon: "github", link: REPO }],
			search: { provider: "local" },
			editLink: { pattern: `${REPO}/edit/main/docs/:path` },
		},
	}),
)
