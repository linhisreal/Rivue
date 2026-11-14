import fs from "node:fs"
import path from "node:path"
import { createHighlighter } from "shiki"
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
const version = (pkg: string) =>
	/^version = "([^"]+)"/m.exec(fs.readFileSync(path.resolve(DOCS, `../packages/${pkg}/wally.toml`), "utf8"))?.[1] ?? ""

const COUNTER = `local Rivue = require(game.ReplicatedStorage.RivueUI)
local h = Rivue.h

local Counter = Rivue.defineComponent({
	name = "Counter",
	setup = function()
		local count = Rivue.ref(0)
		return {
			count = count,
			increment = function()
				count.value += 1
			end,
		}
	end,
	render = function(ctx)
		return h("TextButton", {
			Text = \`Clicked {ctx.count} times\`,
			onClick = ctx.increment,
		})
	end,
})

Rivue.createApp(Counter):mountToPlayerGui(game.Players.LocalPlayer)`

const VUE = `<script setup>
import { ref, computed } from "vue"

const coins = ref(0)
const label = computed(() => \`\${coins.value} coins\`)
</script>

<template>
  <button @click="coins += 10">{{ label }}</button>
</template>`

const RIVUE = `setup = function()
	local coins = Rivue.ref(0)
	local label = Rivue.computed(function()
		return \`{coins.value} coins\`
	end)
	return { coins = coins, label = label }
end,
render = function(ctx)
	return h("TextButton", {
		Text = ctx.label,
		onClick = function()
			ctx.coins += 10
		end,
	})
end,`

const highlighter = await createHighlighter({ themes: ["github-light", "github-dark"], langs: ["luau", "vue"] })
const highlight = (code: string, lang: string) =>
	highlighter.codeToHtml(code, { lang, themes: { light: "github-light", dark: "github-dark" } })

const landing = {
	version: version("rivue-ui"),
	counter: highlight(COUNTER, "luau"),
	vue: highlight(VUE, "vue"),
	rivue: highlight(RIVUE, "luau"),
	packages: [
		{ name: "RivueUI", version: version("rivue-ui"), text: "Components, reactivity, styling and the built-ins.", link: "/guide/01-introduction" },
		{ name: "RivueRemote", version: version("rivue-remote"), text: "Checked client/server calls, events and replicated state.", link: "/api/remote" },
		{ name: "RivueRouter", version: version("rivue-router"), text: "Screens with history, guards and nested routes.", link: "/api/router" },
		{ name: "RivueDevTools", version: "", text: "A Studio plugin for props, state, renders and network.", link: "/DEVTOOLS" },
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
				pageData.frontmatter = { ...pageData.frontmatter, layout: "home" }
			}
		},
		markdown: { config: githubLinks, anchor: { slugify: githubSlug } },
		themeConfig: {
			logo: { src: "/icon-192.png", alt: "Rivue" },
			landing,
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
