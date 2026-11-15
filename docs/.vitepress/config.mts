import fs from "node:fs"
import path from "node:path"
import { createHighlighter } from "shiki"
import { defineConfig } from "vitepress"
import { withMermaid } from "vitepress-plugin-mermaid"
import { transformerMetaWordHighlight } from "@shikijs/transformers"
import { exampleMarkdown, loadExamples } from "./examples.mts"

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
			} else if (/[\\/]examples[\\/]components[\\/]\w+\.luau$/.test(target)) {
				tokens[idx].attrSet("href", `/examples/${path.basename(target, ".luau").toLowerCase()}`)
			} else if (!target.startsWith(DOCS + path.sep)) {
				const repoPath = path.relative(path.resolve(DOCS, ".."), target).split(path.sep).join("/")
				const kind = path.extname(target) ? "blob" : "tree"
				tokens[idx].attrSet("href", `${REPO}/${kind}/main/${repoPath}${hash ? `#${hash}` : ""}`)
			}
		}
		return render(tokens, idx, options, env, self)
	}
}

// Vue's template compiler drops whitespace with a newline between two tags, which glued "**Core**" to the next link.
function softBreaks(md: any) {
	md.renderer.rules.softbreak = () => " "
}

// GitHub reads only a fence's first word, so "lua [title] tab /word/ {3,5}" still renders as plain Lua there.
function codeBlocks(md: any) {
	md.core.ruler.push("code_tabs", (state: any) => {
		const tokens = state.tokens
		for (let i = 0; i < tokens.length; i++) {
			if (!isTab(tokens[i])) continue
			let end = i
			while (isTab(tokens[end + 1])) end++
			const labels = tokens.slice(i, end + 1).map((token: any, n: number) => {
				token.meta = { ...token.meta, tab: n }
				return titleOf(token.info) ?? token.info.split(/\s/)[0]
			})
			const buttons = labels
				.map(
					(label: string, n: number) =>
						`<button type="button" role="tab" aria-selected="${n === 0}" data-lang="${langOf(tokens[i + n].info)}">${md.utils.escapeHtml(label)}</button>`,
				)
				.join("")
			const open = new state.Token("html_block", "", 0)
			open.content = `<div class="fd-tabs"><div class="fd-tab-list" role="tablist">${buttons}</div>\n`
			const close = new state.Token("html_block", "", 0)
			close.content = "</div>\n"
			tokens.splice(end + 1, 0, close)
			tokens.splice(i, 0, open)
			i = end + 2
		}
	})

	const fence = md.renderer.rules.fence
	md.renderer.rules.fence = (tokens: any, idx: number, options: any, env: any, self: any) => {
		const token = tokens[idx]
		let title = titleOf(token.info)
		token.info = token.info.replace(/\s\[[^\]]+\]/, "").replace(/\stab(?=\s|$)/, "")
		const pathComment = /^-- ([\w./-]+\.luau)\s*\n/.exec(token.content)
		if (!title && token.info.startsWith("lua") && pathComment) {
			title = pathComment[1]
			token.content = token.content.slice(pathComment[0].length)
		}
		const html = fence(tokens, idx, options, env, self)
		const tab = token.meta?.tab
		if (tab !== undefined) return html.replace(/^<div class="([^"]*)"/, `<div class="$1 fd-tab-panel${tab === 0 ? " active" : ""}" role="tabpanel"`)
		if (!title) return html
		const head = `<div class="fd-code-head"><span class="fd-code-icon" data-lang="${langOf(token.info)}"></span>${md.utils.escapeHtml(title)}</div>`
		return html.replace(/^<div class="([^"]*)">/, `<div class="$1 fd-titled">${head}`)
	}
}

const titleOf = (info: string) => /\s\[([^\]]+)\]/.exec(info)?.[1]
const langOf = (info: string) => info.trim().split(/\s/)[0] || "text"
const isTab = (token: any) => token?.type === "fence" && /\stab(\s|$)/.test(token.info)

function pageActions(md: any) {
	md.core.ruler.push("page_actions", (state: any) => {
		const tokens = state.tokens
		const close = tokens.findIndex((t: any) => t.type === "heading_close" && t.tag === "h1")
		if (close === -1) return
		const html = new state.Token("html_block", "", 0)
		html.content = "<PageActions />\n"
		tokens.splice(close + 1, 0, html)
	})
}

function githubSlug(text: string): string {
	return text
		.trim()
		.toLowerCase()
		.replace(/<[^>]*>/g, "")
		.replace(/[^\p{L}\p{N}\s_-]/gu, "")
		.replace(/\s/g, "-")
}

const SITE = "https://linhisreal.github.io/Rivue/"

function pageTitle(markdown: string, fallback: string) {
	return /^# (.+)$/m.exec(markdown)?.[1] ?? /<h1[^>]*>([^<]+)<\/h1>/.exec(markdown)?.[1] ?? fallback
}

function writeLlmsFiles(pages: string[], outDir: string) {
	const sources = pages.sort().map((page) => {
		const example = examples.find((e) => page === `examples/${e.slug}.md`)
		const markdown = example ? exampleMarkdown(example) : fs.readFileSync(path.resolve(DOCS, page), "utf8")
		const url = SITE + (page === "README.md" ? "" : page.replace(/\.md$/, ""))
		return { page, url, markdown, title: pageTitle(markdown, page) }
	})
	const index = sources.map(({ url, title }) => `- [${title}](${url})`).join("\n")
	fs.writeFileSync(
		path.join(outDir, "llms.txt"),
		`# Rivue\n\n> Vue 3's component model for Roblox UI, in Luau.\n\n## Docs\n\n${index}\n`,
	)
	const full = sources.map(({ url, markdown }) => `<!-- ${url} -->\n\n${markdown}`).join("\n\n---\n\n")
	fs.writeFileSync(path.join(outDir, "llms-full.txt"), full)
}

// The docs workflow passes its GITHUB_TOKEN; without it (or offline) the repo card just shows the name.
async function repoStats() {
	const headers: Record<string, string> = { "User-Agent": "rivue-docs" }
	if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`
	const get = (url: string) => fetch(`https://api.github.com/repos/linhisreal/Rivue${url}`, { headers, signal: AbortSignal.timeout(5000) })
	try {
		const [repo, releases] = await Promise.all([get(""), get("/releases?per_page=1")])
		if (!repo.ok) return {}
		const data = await repo.json()
		const latest = releases.ok ? (await releases.json())[0] : undefined
		return { stars: data.stargazers_count as number, forks: data.forks_count as number, tag: latest?.tag_name as string | undefined }
	} catch {
		return {}
	}
}

const PAGE_CLASSES: Record<string, string> = { "INSTALLATION.md": "fd-steps" }

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
const version = (pkg: string) =>
	/^version = "([^"]+)"/m.exec(fs.readFileSync(path.resolve(DOCS, `../packages/${pkg}/wally.toml`), "utf8"))?.[1] ?? ""

const SHOP = `local ITEMS = {
	{ name = "Sword", price = 20 },
	{ name = "Shield", price = 30 },
	{ name = "Potion", price = 10 },
}

local Shop = Rivue.defineComponent({
	name = "Shop",
	setup = function()
		local coins = Rivue.ref(30)
		local owned = Rivue.reactive({})
		return {
			coins = coins,
			owned = owned,
			buy = function(item)
				coins.value -= item.price
				owned[item.name] = true
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { Name = "Shop", class = "shop" }, {
			h("UIListLayout"),
			h("TextLabel", { Name = "Coins", Text = \`{ctx.coins} coins\` }),
			h("TextButton", {
				Name = "Earn",
				Text = "+10 coins",
				onClick = function()
					ctx.coins += 10
				end,
			}),
			Rivue.hFor(ITEMS, function(item)
				return h(ItemRow, {
					key = item.name,
					name = item.name,
					price = item.price,
					owned = ctx.owned[item.name] == true,
					affordable = ctx.coins >= item.price,
					onBuy = function()
						ctx.buy(item)
					end,
				})
			end),
		})
	end,
})`

const ITEM_ROW = `local ItemRow = Rivue.defineComponent({
	name = "ItemRow",
	props = {
		name = { type = "string" },
		price = { type = "number" },
		owned = { type = "boolean", default = false },
		affordable = { type = "boolean", default = true },
	},
	emits = { "buy" },
	render = function(ctx)
		return h("TextButton", {
			Name = ctx.name,
			class = "row",
			Text = if ctx.owned then \`{ctx.name} · Owned\` else \`{ctx.name} · {ctx.price}\`,
			disabled = ctx.owned or not ctx.affordable,
			onClick = function()
				ctx.emit("buy")
			end,
		})
	end,
})`

const VUE_COUNTER = `<script setup>
import { ref } from "vue"

const count = ref(0)
</script>

<template>
  <button @click="count++">Clicked {{ count }} times</button>
</template>`

// The React-lua, Fusion and Rivue counters come from the comparison page so the two can't drift apart.
function counters() {
	const page = fs.readFileSync(path.resolve(DOCS, "COMING-FROM-REACT.md"), "utf8")
	const section = page.slice(page.indexOf("## The same counter in each"), page.indexOf("## API map"))
	const [react, fusion, rivue] = [...section.matchAll(/```lua\n([\s\S]*?)```/g)].map((m) => m[1].trimEnd())
	return { react, fusion, rivue }
}

const highlighter = await createHighlighter({ themes: ["github-light", "github-dark"], langs: ["luau", "vue"] })
const highlight = (code: string, lang: string, steps: Record<string, string> = {}) => {
	const lines = code.split("\n")
	const stepAt = new Map(Object.entries(steps).map(([text, step]) => [lines.findIndex((l) => l.includes(text)) + 1, step]))
	return highlighter.codeToHtml(code, {
		lang,
		themes: { light: "github-light", dark: "github-dark" },
		transformers: [
			{
				line(node, line) {
					const step = stepAt.get(line)
					if (step) node.properties["data-step"] = step
				},
			},
		],
	})
}

const { react, fusion, rivue } = counters()

const landing = {
	shop: highlight(SHOP, "luau", {
		"coins.value -= item.price": "spend",
		"owned[item.name] = true": "own",
		"ctx.coins += 10": "earn",
		"Text = `{ctx.coins} coins`": "coins",
		"owned = ctx.owned": "props",
		"affordable = ctx.coins": "props",
		"ctx.buy(item)": "call",
	}),
	itemRow: highlight(ITEM_ROW, "luau", {
		'ctx.emit("buy")': "emit",
		"Text = if ctx.owned": "text",
		"disabled = ctx.owned": "disabled",
	}),
	compare: [
		{ name: "Vue", lang: "vue", html: highlight(VUE_COUNTER, "vue") },
		{ name: "Rivue", lang: "luau", html: highlight(rivue, "luau") },
		{ name: "React-lua", lang: "luau", html: highlight(react, "luau") },
		{ name: "Fusion", lang: "luau", html: highlight(fusion, "luau") },
	],
	packages: [
		{ name: "RivueUI", version: version("rivue-ui"), text: "Components, reactivity, styling and the built-ins.", link: "/guide/01-introduction" },
		{ name: "RivueRemote", version: version("rivue-remote"), text: "Checked client/server calls, events and replicated state.", link: "/api/remote", example: 'Remote.request("shop:buy", { id = "sword" })' },
		{ name: "RivueRouter", version: version("rivue-router"), text: "Screens with history, guards and nested routes.", link: "/api/router", example: 'router.push("shop")' },
		{ name: "RivueDevTools", version: "", text: "A Studio plugin for props, state, renders and network.", link: "/DEVTOOLS" },
	],
}

const api: [string, [string, string][]][] = [
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

const chapter = ([text, file]: string[]) => ({ text, link: `/guide/${file}` })
const folder = (text: string, pages: string[][]) => ({ text, collapsed: true, items: pages.map(chapter) })

const guideSidebar = [
	{
		text: "Getting started",
		items: [
			chapter(guide[0]),
			{ text: "Installation", link: "/INSTALLATION" },
			{ text: "Coming from Vue", link: "/VUE" },
			{ text: "Coming from React-lua or Fusion", link: "/COMING-FROM-REACT" },
		],
	},
	{
		text: "Learn",
		items: [
			folder("Basics", guide.slice(1, 5)),
			folder("Styling and motion", guide.slice(5, 7)),
			folder("Building a game", guide.slice(7)),
		],
	},
	{ text: "Advanced", items: [folder("Patterns", advanced.slice(0, 3)), folder("Scaling up", advanced.slice(3))] },
	{
		text: "Tools",
		items: [
			{ text: "DevTools", link: "/DEVTOOLS" },
			{ text: "Architecture", link: "/ARCHITECTURE" },
			{ text: "Releasing", link: "/RELEASING" },
		],
	},
]

const examples = loadExamples()
const examplesSidebar = [
	{ text: "Examples", items: examples.map((example) => ({ text: example.name, link: `/examples/${example.slug}` })) },
]

const apiSidebar = [
	{ items: [{ text: "Overview", link: "/API" }] },
	{
		text: "Reference",
		items: api.map(([text, pages]) => ({
			text,
			collapsed: true,
			items: pages.map(([page, file]) => ({ text: page, link: `/api/${file}` })),
		})),
	},
]

export default withMermaid(
	defineConfig({
		title: "Rivue",
		description: "Vue 3's component model for Roblox UI, in Luau",
		base: "/Rivue/",
		cleanUrls: true,
		appearance: "dark",
		scrollOffset: { selector: ".VPLocalNav", padding: 24 },
		rewrites: { "README.md": "index.md" },
		srcExclude: ["assets/README.md", "superpowers/**"],
		head: [
			["link", { rel: "icon", href: "/Rivue/favicon.ico", sizes: "any" }],
			["link", { rel: "icon", type: "image/png", sizes: "32x32", href: "/Rivue/favicon-32.png" }],
			["link", { rel: "apple-touch-icon", href: "/Rivue/apple-touch-icon.png" }],
			["meta", { name: "theme-color", content: "#1f6feb" }],
			["link", { rel: "preconnect", href: "https://fonts.googleapis.com" }],
			["link", { rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: "" }],
			[
				"link",
				{
					rel: "stylesheet",
					href: "https://fonts.googleapis.com/css2?family=Geist:wght@400..700&family=Geist+Mono:wght@400..600&display=swap",
				},
			],
		],
		vite: { publicDir: path.resolve(DOCS, "assets/web") },
		buildEnd(site) {
			writeLlmsFiles(site.pages, site.outDir)
		},
		transformPageData(pageData) {
			if (pageData.relativePath === "index.md") {
				pageData.frontmatter = { ...pageData.frontmatter, layout: "home" }
				return
			}
			const example = examples.find((e) => e.slug === pageData.params?.example)
			if (example) {
				pageData.frontmatter = {
					...pageData.frontmatter,
					githubPath: example.file,
					markdown: Buffer.from(exampleMarkdown(example)).toString("base64"),
				}
				return
			}
			const source = pageData.filePath === "index.md" ? "README.md" : pageData.filePath
			pageData.frontmatter = {
				...pageData.frontmatter,
				githubPath: `docs/${source}`,
				pageClass: PAGE_CLASSES[pageData.relativePath] ?? (pageData.relativePath.startsWith("api/") ? "fd-api" : undefined),
				markdown: fs.readFileSync(path.resolve(DOCS, source)).toString("base64"),
			}
		},
		markdown: {
			codeTransformers: [transformerMetaWordHighlight()],
			config(md) {
				githubLinks(md)
				softBreaks(md)
				codeBlocks(md)
				pageActions(md)
			},
			anchor: { slugify: githubSlug },
		},
		mermaid: {
			fontFamily: "Geist, ui-sans-serif, system-ui, sans-serif",
			flowchart: { curve: "basis", padding: 12, nodeSpacing: 32, rankSpacing: 36 },
			sequence: { mirrorActors: false },
		},
		themeConfig: {
			logo: { src: "/icon-192.png", alt: "Rivue" },
			version: version("rivue-ui"),
			repo: { name: "linhisreal/Rivue", url: REPO, ...(await repoStats()) },
			landing,
			outline: { level: [2, 3] },
			footer: {
				message: "Released under the Rivue License, based on PolyForm Noncommercial 1.0.0.",
				copyright: "Copyright © 2025-2026 linhisreal",
			},
			nav: [
				{ text: "Guide", link: "/GUIDE" },
				{ text: "API", link: "/API" },
				{ text: "Examples", link: `/examples/${examples[0].slug}` },
			],
			sidebar: { "/api/": apiSidebar, "/API": apiSidebar, "/examples/": examplesSidebar, "/": guideSidebar },
			socialLinks: [{ icon: "github", link: REPO }],
			search: { provider: "local" },

		},
	}),
)
