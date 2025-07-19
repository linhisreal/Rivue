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
		markdown: { config: githubLinks, anchor: { slugify: githubSlug } },
		themeConfig: {
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
