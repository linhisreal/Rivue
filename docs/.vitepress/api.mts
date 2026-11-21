// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import fs from "node:fs"
import path from "node:path"
import { htmlToken, REPO, ROOT, slug } from "./site.mts"

type Location = { file: string; line: number }

function sourceIndex() {
	const index = new Map<string, Map<string, Location>>()
	const definition = /^\s*(?:local\s+)?function\s+(?:[\w.]+[.:])?(\w+)\s*[(<]|^\s*(?:[\w.]+\.)?(\w+)\s*=\s*function\s*\(/
	for (const pkg of fs.readdirSync(path.join(ROOT, "packages"))) {
		const names = new Map<string, Location>()
		const walk = (dir: string) => {
			for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
				const full = path.join(dir, entry.name)
				if (entry.isDirectory()) walk(full)
				else if (entry.name.endsWith(".luau")) {
					fs.readFileSync(full, "utf8")
						.split("\n")
						.forEach((text, i) => {
							const match = definition.exec(text)
							const name = match?.[1] ?? match?.[2]
							if (name && !names.has(name)) names.set(name, { file: path.relative(ROOT, full).split(path.sep).join("/"), line: i + 1 })
						})
				}
			}
		}
		const src = path.join(ROOT, "packages", pkg, "src")
		if (fs.existsSync(src)) walk(src)
		index.set(pkg, names)
	}
	return index
}

const PAGE_PACKAGE: Record<string, string> = { "api/remote.md": "rivue-remote", "api/router.md": "rivue-router" }

const PARAM_HEADERS = new Set(["Parameter", "Prop", "Event", "Slot", "Field", "Option"])

function cellsOf(tokens: any[], start: number, end: number) {
	const rows: string[][] = []
	let row: string[] | undefined
	for (let i = start; i < end; i++) {
		const t = tokens[i]
		if (t.type === "tr_open") row = []
		else if (t.type === "inline" && row) row.push(t.content)
		else if (t.type === "tr_close" && row) rows.push(row), (row = undefined)
	}
	return rows
}

type TypeTarget = { file: string; anchor: string }

function typeIndex() {
	const index = new Map<string, TypeTarget>()
	const dir = path.join(ROOT, "docs", "api")
	const fromSignatures: [string, TypeTarget][] = []
	for (const name of fs.readdirSync(dir).filter((f) => f.endsWith(".md"))) {
		const file = `api/${name}`
		const blocks = fs.readFileSync(path.join(dir, name), "utf8").split(/^## /m).slice(1)
		for (const block of blocks) {
			const heading = block.split("\n")[0]
			const anchor = slug(heading)
			const bare = heading.replace(/^type\s+/, "").trim()
			if (/^[A-Z]\w*$/.test(bare)) index.set(bare, { file, anchor })
			for (const sig of block.matchAll(/```lua signature\n([\s\S]*?)```/g))
				for (const def of sig[1].matchAll(/^\s*(?:export\s+)?type\s+(\w+)/gm)) fromSignatures.push([def[1], { file, anchor }])
		}
	}
	for (const [name, target] of fromSignatures) if (!index.has(name)) index.set(name, target)
	for (const [name, file, anchor] of DOCUMENTED_ELSEWHERE) if (!index.has(name)) index.set(name, { file, anchor })
	return index
}

const DOCUMENTED_ELSEWHERE: [string, string, string][] = [
	["VNode", "api/render-function.md", "h"],
	["Props", "api/render-function.md", "element-props"],
	["ComponentDef", "api/component.md", "definecomponent"],
	["ComponentOptions", "api/component.md", "definecomponent"],
	["RenderContext", "api/component.md", "render"],
	["ComponentInstance", "api/component.md", "getcurrentinstance"],
	["MaybeRefOrGetter", "api/reactivity-utilities.md", "tovalue"],
	["EffectOptions", "api/reactivity-advanced.md", "effect"],
	["EffectScope", "api/reactivity-advanced.md", "effectscope"],
	["TransitionProps", "api/builtins.md", "transition"],
	["TransitionGroupProps", "api/builtins.md", "transitiongroup"],
	["KeepAliveProps", "api/builtins.md", "keepalive"],
	["TeleportProps", "api/builtins.md", "teleport"],
	["SuspenseProps", "api/builtins.md", "suspense"],
	["VirtualListProps", "api/builtins.md", "virtuallist"],
	["ViewportModelProps", "api/builtins.md", "viewportmodel"],
	["ErrorBoundaryProps", "api/builtins.md", "errorboundary"],
	["DialogProps", "api/builtins.md", "dialog"],
	["RowProps", "api/builtins.md", "row-column-and-spacer"],
	["PoolConfig", "api/pool.md", "poolconfigure"],
	["RouteLocation", "api/router.md", "routerpush-and-routerreplace"],
	["RouterOptions", "api/router.md", "routercreaterouter"],
	["Router", "api/router.md", "routercreaterouter"],
	["RouterViewProps", "api/router.md", "routerrouterview"],
	["RouterLinkProps", "api/router.md", "routerrouterlink"],
	["NavigationFailure", "api/router.md", "navigation-failures"],
	["HandleOptions", "api/remote.md", "remotehandle"],
	["RequestOptions", "api/remote.md", "remoteuserequest"],
	["RemoteConfig", "api/remote.md", "remoteconfigure"],
	["AsyncState", "api/component.md", "useasync"],
	["App", "api/application.md", "createapp"],
]

const ROBLOX = "https://create.roblox.com/docs/reference/engine"
const ROBLOX_DATATYPES = new Set(["TweenInfo", "UDim", "UDim2", "Vector2", "Vector3", "CFrame", "Color3", "ColorSequence", "NumberSequence", "Rect", "BrickColor"])
const ROBLOX_CLASSES = new Set(["Instance", "Player", "TextBox", "TextLabel", "TextButton", "GuiObject", "Frame", "ScrollingFrame", "BasePart", "Model", "InputObject", "ScreenGui", "CanvasGroup", "ImageLabel", "ImageButton", "Folder", "Sound", "RemoteEvent", "UnreliableRemoteEvent"])

function robloxLink(name: string, enumPrefix: boolean) {
	if (enumPrefix) return `${ROBLOX}/enums/${name}`
	if (ROBLOX_DATATYPES.has(name)) return `${ROBLOX}/datatypes/${name}`
	if (ROBLOX_CLASSES.has(name)) return `${ROBLOX}/classes/${name}`
	return undefined
}

let types: Map<string, TypeTarget> | undefined

function linkTypes(html: string, page: string) {
	types ??= typeIndex()
	let inLink = 0
	return html
		.split(/(<[^>]+>)/)
		.map((part) => {
			if (part.startsWith("<")) {
				if (/^<a[\s>]/.test(part)) inLink++
				else if (part === "</a>") inLink--
				return part
			}
			if (inLink > 0) return part
			return part.replace(/(Enum\.)?\b([A-Z][A-Za-z0-9]+)\b/g, (whole, prefix, name) => {
				const external = robloxLink(name, Boolean(prefix))
				if (external) return `${prefix ?? ""}<a class="fd-type-link" href="${external}" target="_blank" rel="noreferrer">${name}</a>`
				const target = types!.get(name)
				if (!target) return whole
				const href = target.file === page ? `#${target.anchor}` : `${path.basename(target.file, ".md")}#${target.anchor}`
				return `<a class="fd-type-link" href="${href}">${name}</a>`
			})
		})
		.join("")
}

function paramList(md: any, env: any, header: string[], rows: string[][]) {
	const page: string = env?.relativePath ?? ""
	const inline = (text: string) => md.renderInline(text, env)
	const seen = new Set(rows.map(([name]) => name.replace(/`/g, "")))
	const filled: string[][] = []
	for (const row of rows) {
		const parent = /^(\w+)\./.exec(row[0].replace(/`/g, ""))?.[1]
		if (parent && !seen.has(parent)) {
			seen.add(parent)
			filled.push([`\`${parent}\``, "", "", ""])
		}
		filled.push(row)
	}
	const out = filled.map(([name, type, def, description]) => {
		const bare = name.replace(/`/g, "")
		const child = /^[\w]+\./.test(bare)
		const shown = child ? bare.replace(/^[\w]+\./, ".") : bare
		return `<div class="fd-param${child ? " fd-param-child" : ""}" role="listitem">
<div class="fd-param-head"><code class="fd-param-name">${md.utils.escapeHtml(shown)}</code><span class="fd-param-type">${type ? linkTypes(inline(type), page) : ""}</span>${def ? `<span class="fd-param-default">= ${inline(def)}</span>` : ""}</div>
${description ? `<div class="fd-param-desc">${inline(description)}</div>` : ""}
</div>`
	})
	return `<div class="fd-params" role="list" aria-label="${md.utils.escapeHtml(header[0])}s">
<div class="fd-params-label">${md.utils.escapeHtml(header[0] === "Parameter" ? "Parameters" : `${header[0]}s`)}</div>
${out.join("\n")}
</div>\n`
}

function kindOf(signature: string) {
	const first = signature.trimStart().split("\n")[0]
	if (/^(export\s+)?type\s/.test(first)) return "type"
	if (/^h\(/.test(first)) return "component"
	if (/^v[A-Z]\w*:/.test(first)) return "directive"
	if (/^function\b/.test(first) || /^[\w.:]+\(/.test(first) || /^\w+:\s*\(/.test(first)) return "function"
	if (/^[\w.]+:/.test(first)) return "property"
	return "function"
}

function pageEntries(file: string) {
	const text = fs.readFileSync(path.join(ROOT, "docs", file), "utf8")
	const entries: { title: string; anchor: string; summary: string }[] = []
	const blocks = text.split(/^## /m).slice(1)
	for (const block of blocks) {
		const [heading, ...rest] = block.split("\n")
		const title = heading.replace(/\\</g, "<").replace(/\\>/g, ">").trim()
		const para = rest.join("\n").trim().split(/\n\s*\n/)[0] ?? ""
		const summary = para.startsWith("```") || para.startsWith("|") || para.startsWith(">") ? "" : (/^[\s\S]*?[.:](?=\s|$)/.exec(para.replace(/\n/g, " "))?.[0] ?? para)
		const plain = summary.replace(/\[([^\]]+)\]\([^)]*\)/g, "$1").replace(/:$/, ".")
		entries.push({ title, anchor: slug(heading), summary: plain })
	}
	return entries
}

function apiIndexCard(md: any, env: any, label: string, file: string) {
	const href = file.replace(/\.md$/, "")
	const items = pageEntries(file)
		.map(
			(e) =>
				`<li><a href="${href}#${e.anchor}"><code>${md.utils.escapeHtml(e.title)}</code></a><span>${md.renderInline(e.summary, env)}</span></li>`,
		)
		.join("")
	return `<section class="fd-api-card"><a class="fd-api-card-title" href="${href}">${md.utils.escapeHtml(label)}</a><ul>${items}</ul></section>\n`
}

function labelsHtml(md: any, labels: string) {
	const items = labels.split(" · ").map((label) => `<span class="fd-label">${md.utils.escapeHtml(label)}</span>`)
	return `<div class="fd-labels">${items.join("")}</div>\n`
}

function returnsHtml(md: any, env: any, text: string) {
	const value = linkTypes(md.renderInline(text, env), env.relativePath)
	return `<div class="fd-returns"><span class="fd-returns-label">Returns</span><span>${value}</span></div>\n`
}

function renderApiIndex(md: any, state: any) {
	const tokens = state.tokens
	for (let i = 0; i < tokens.length; i++) {
		if (tokens[i].type !== "paragraph_open") continue
		const head = /^\*\*\[([^\]]+)\]\((api\/[\w-]+\.md)\)\*\*/.exec(tokens[i + 1]?.content ?? "")
		if (head) tokens.splice(i, 3, htmlToken(state, apiIndexCard(md, state.env, head[1], head[2])))
	}
}

function renderApiPage(md: any, state: any, sources: Map<string, Location> | undefined) {
	const tokens = state.tokens
	let heading: any
	let entry: string | undefined
	for (let i = 0; i < tokens.length; i++) {
		const t = tokens[i]
		if (t.type === "heading_open" && t.tag === "h2") {
			heading = t
			entry = /([A-Za-z_]\w*)\s*\(\)/.exec(tokens[i + 1].content.replace(/\s*\/.*$/, ""))?.[1]
			const labels = tokens[i + 3]?.type === "paragraph_open" ? /^_([^_]+)_$/.exec(tokens[i + 4]?.content ?? "")?.[1] : undefined
			if (labels) tokens.splice(i + 3, 3, htmlToken(state, labelsHtml(md, labels)))
		} else if (t.type === "fence" && /^lua\s+signature\b/.test(t.info)) {
			if (heading && !heading.attrGet("data-kind")) heading.attrSet("data-kind", kindOf(t.content))
			t.info = "lua"
			t.meta = { ...t.meta, signature: true }
			const at = entry ? sources?.get(entry) : undefined
			if (at) t.meta.source = `${REPO}/blob/main/${at.file}#L${at.line}`
			entry = undefined
		} else if (t.type === "table_open") {
			const close = tokens.findIndex((x: any, j: number) => j > i && x.type === "table_close")
			const [header, ...rows] = cellsOf(tokens, i, close)
			if (header && PARAM_HEADERS.has(header[0])) tokens.splice(i, close - i + 1, htmlToken(state, paramList(md, state.env, header, rows)))
		} else if (t.type === "paragraph_open" && /^\*\*Returns\*\*/.test(tokens[i + 1]?.content ?? "")) {
			const text = tokens[i + 1].content.replace(/^\*\*Returns\*\*\s*/, "")
			tokens.splice(i, 3, htmlToken(state, returnsHtml(md, state.env, text)))
		}
	}
}

export function apiEntries(md: any) {
	const sources = sourceIndex()
	md.core.ruler.push("api_entries", (state: any) => {
		const page: string = state.env?.relativePath ?? ""
		if (page === "API.md") renderApiIndex(md, state)
		else if (page.startsWith("api/")) renderApiPage(md, state, sources.get(PAGE_PACKAGE[page] ?? "rivue-ui"))
	})
}
