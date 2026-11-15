// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import fs from "node:fs"
import path from "node:path"
import { apiEntries } from "./api.mts"
import { DOCS, htmlToken, REPO, ROOT } from "./site.mts"

const EXAMPLE_FILE = /[\\/]examples[\\/]components[\\/]\w+\.luau$/

export function markdownPlugins(md: any) {
	githubLinks(md)
	softBreaks(md)
	codeBlocks(md)
	pageActions(md)
	dropPagerLine(md)
	relatedLinks(md)
	themedImages(md)
	apiEntries(md)
}

export function siteLink(target: string, hash = "") {
	if (EXAMPLE_FILE.test(target)) return `/examples/${path.basename(target, ".luau").toLowerCase()}`
	if (target.startsWith(DOCS + path.sep)) return undefined
	const kind = path.extname(target) ? "blob" : "tree"
	return `${REPO}/${kind}/main/${path.relative(ROOT, target).split(path.sep).join("/")}${hash ? `#${hash}` : ""}`
}

function githubLinks(md: any) {
	const render = md.renderer.rules.link_open ?? ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options))
	md.renderer.rules.link_open = (tokens, idx, options, env, self) => {
		const href: string = tokens[idx].attrGet("href") ?? ""
		if (env?.relativePath && !/^[a-z]+:|^#|^\//i.test(href)) {
			const [file, hash] = href.split("#")
			const target = path.resolve(DOCS, path.dirname(env.relativePath), file)
			const link = target === path.join(DOCS, "README.md") ? introductionLink(env.relativePath, hash) : siteLink(target, hash)
			if (link) tokens[idx].attrSet("href", link)
		}
		return render(tokens, idx, options, env, self)
	}
}

function introductionLink(page: string, hash?: string) {
	const up = path.posix.relative(path.posix.dirname(page), ".")
	return `${up ? up + "/" : "./"}introduction.md${hash ? `#${hash}` : ""}`
}

// the Vue template compiler drops whitespace with a newline between two tags, which glued "**Core**" to the next link
function softBreaks(md: any) {
	md.renderer.rules.softbreak = () => " "
}

const titleOf = (info: string) => /\s\[([^\]]+)\]/.exec(info)?.[1]
const langOf = (info: string) => info.trim().split(/\s/)[0] || "text"
const isTab = (token: any) => token?.type === "fence" && /\stab(\s|$)/.test(token.info)

// GitHub only reads a fence's first word, so "lua [title] tab /word/" still renders as plain Lua there
function codeBlocks(md: any) {
	md.core.ruler.push("code_tabs", (state: any) => {
		const tokens = state.tokens
		for (let i = 0; i < tokens.length; i++) {
			if (!isTab(tokens[i])) continue
			let end = i
			while (isTab(tokens[end + 1])) end++
			const group = tokens.slice(i, end + 1)
			const buttons = group
				.map((token: any, n: number) => {
					token.meta = { ...token.meta, tab: n }
					const label = titleOf(token.info) ?? langOf(token.info)
					return `<button type="button" role="tab" aria-selected="${n === 0}" data-lang="${langOf(token.info)}">${md.utils.escapeHtml(label)}</button>`
				})
				.join("")
			tokens.splice(end + 1, 0, htmlToken(state, "</div>\n"))
			tokens.splice(i, 0, htmlToken(state, `<div class="fd-tabs"><div class="fd-tab-list" role="tablist">${buttons}</div>\n`))
			i = end + 2
		}
	})

	const fence = md.renderer.rules.fence
	md.renderer.rules.fence = (tokens: any, idx: number, options: any, env: any, self: any) => {
		const token = tokens[idx]
		if (langOf(token.info) === "tree") return fileTree(md, token.content)
		let title = titleOf(token.info)
		token.info = token.info.replace(/\s\[[^\]]+\]/, "").replace(/\stab(?=\s|$)/, "")
		const pathComment = /^-- ([\w./-]+\.luau)\s*\n/.exec(token.content)
		if (!title && token.info.startsWith("lua") && pathComment) {
			title = pathComment[1]
			token.content = token.content.slice(pathComment[0].length)
		}
		const html = fence(tokens, idx, options, env, self)
		const decorate = (className: string, inside = "", attrs = "") =>
			html.replace(/^<div class="([^"]*)">/, `<div class="$1 ${className}"${attrs}>${inside}`)
		const tab = token.meta?.tab
		if (tab !== undefined) return decorate(`fd-tab-panel${tab === 0 ? " active" : ""}`, "", ' role="tabpanel"')
		if (token.meta?.signature) {
			const source = token.meta.source ? `<a class="fd-source" href="${token.meta.source}" target="_blank" rel="noreferrer">Source</a>` : ""
			return decorate("fd-signature", source)
		}
		if (!title) return html
		const icon = `<span class="fd-code-icon" data-lang="${langOf(token.info)}"></span>`
		return decorate("fd-titled", `<div class="fd-code-head">${icon}${md.utils.escapeHtml(title)}</div>`)
	}
}

type TreeNode = { name: string; note: string; folder: boolean; children: TreeNode[] }

// ```tree: two spaces per level, a trailing "/" marks a folder, two or more spaces start a note
function parseTree(content: string) {
	const root: TreeNode[] = []
	const stack: { depth: number; children: TreeNode[] }[] = [{ depth: -1, children: root }]
	for (const raw of content.split("\n")) {
		if (!raw.trim()) continue
		const depth = Math.floor((raw.length - raw.trimStart().length) / 2)
		const [, name, note = ""] = /^(\S+(?: \S+)*?)(?:\s{2,}(.*))?$/.exec(raw.trim()) ?? [, raw.trim()]
		const node = { name: name.replace(/\/$/, ""), note, folder: name.endsWith("/"), children: [] }
		while (stack.at(-1)!.depth >= depth) stack.pop()
		stack.at(-1)!.children.push(node)
		stack.push({ depth, children: node.children })
	}
	return root
}

function fileTree(md: any, content: string) {
	const escape = md.utils.escapeHtml
	const icon = (node: TreeNode) => {
		if (node.folder) return `<span class="fd-file-icon fd-folder" aria-hidden="true"></span>`
		const ext = node.name.split(".").pop()
		return `<span class="fd-file-icon" data-lang="${escape(ext === "luau" ? "lua" : ext)}" aria-hidden="true"></span>`
	}
	const item = (node: TreeNode): string => {
		const note = node.note ? `<span class="fd-file-note">${escape(node.note)}</span>` : ""
		const row = `<span class="fd-file-row">${icon(node)}<span class="fd-file-name">${escape(node.name)}</span>${note}</span>`
		return `<li>${row}${node.children.length ? list(node.children) : ""}</li>`
	}
	const list = (nodes: TreeNode[]): string => `<ul>${nodes.map(item).join("")}</ul>`
	return `<div class="fd-files">${list(parseTree(content))}</div>\n`
}

function pageActions(md: any) {
	md.core.ruler.push("page_actions", (state: any) => {
		const tokens = state.tokens
		const close = tokens.findIndex((t: any) => t.type === "heading_close" && t.tag === "h1")
		if (close !== -1) tokens.splice(close + 1, 0, htmlToken(state, "<PageActions />\n"))
	})
}

// the "← prev · contents · next →" line is for reading on GitHub; the site has its own prev/next footer
function dropPagerLine(md: any) {
	md.core.ruler.push("drop_pager_line", (state: any) => {
		const tokens = state.tokens
		const inline = tokens[tokens.length - 2]
		if (tokens[tokens.length - 1]?.type !== "paragraph_close" || inline?.type !== "inline") return
		if (/^\[(← |Guide contents\]|API reference\])/.test(inline.content) && /[←→]\]/.test(inline.content)) tokens.splice(-3, 3)
	})
}

const RELATED_LABEL = /\*\*(Try it|Reference):\*\*/g

function relatedRow(md: any, env: any, label: string, source: string) {
	const items = source
		.replace(/\\\n/g, " ")
		.split(/\s+·\s+/)
		.map((item) => item.trim())
		.filter(Boolean)
		.map((item) => {
			const [, main, note] = /^(.*\S)\s+\(([^()]*(?:\([^()]*\)[^()]*)*)\)$/s.exec(item) ?? [, item]
			const noteHtml = note ? `<span class="fd-related-note">${md.renderInline(note, env)}</span>` : ""
			return `<li>${md.renderInline(main, env)}${noteHtml}</li>`
		})
	const kind = label === "Try it" ? "try" : "reference"
	return `<div class="fd-related-row" data-kind="${kind}"><span class="fd-related-label">${label}</span><ul>${items.join("")}</ul></div>`
}

function relatedLinks(md: any) {
	md.core.ruler.push("related_links", (state: any) => {
		const tokens = state.tokens
		for (let i = 0; i < tokens.length; i++) {
			const content: string = tokens[i + 1]?.content ?? ""
			if (tokens[i].type !== "paragraph_open" || !/^\*\*(Try it|Reference):\*\*/.test(content)) continue
			const parts = content.split(RELATED_LABEL).slice(1)
			const rows: string[] = []
			for (let p = 0; p < parts.length; p += 2) rows.push(relatedRow(md, state.env, parts[p], parts[p + 1]))
			const previous = tokens[i - 1]
			if (previous?.meta?.related) {
				previous.content = previous.content.replace(/<\/div>\n$/, `${rows.join("")}</div>\n`)
				tokens.splice(i, 3)
				i--
			} else {
				const block = htmlToken(state, `<div class="fd-related">${rows.join("")}</div>\n`)
				block.meta = { related: true }
				tokens.splice(i, 3, block)
			}
		}
	})
}

// GitHub shows the light diagram; the site swaps in name-dark.webp next to it when one exists
function themedImages(md: any) {
	const image = md.renderer.rules.image
	md.renderer.rules.image = (tokens: any, idx: number, options: any, env: any, self: any) => {
		const token = tokens[idx]
		const src: string = token.attrGet("src") ?? ""
		const dark = src.replace(/\.webp$/, "-dark.webp")
		const exists = env?.relativePath && dark !== src && fs.existsSync(path.resolve(DOCS, path.dirname(env.relativePath), dark))
		if (!exists) return image(tokens, idx, options, env, self)
		token.attrJoin("class", "fd-only-light")
		const light = image(tokens, idx, options, env, self)
		token.attrSet("src", dark)
		token.attrSet("class", "fd-only-dark")
		return light + image(tokens, idx, options, env, self)
	}
}
