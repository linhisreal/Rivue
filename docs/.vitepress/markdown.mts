// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import fs from "node:fs"
import path from "node:path"
import type { MarkdownEnv, MarkdownRenderer } from "vitepress"
import { apiEntries } from "./api.mts"
import { CHAPTERS } from "./sidebar.mts"
import { DOCS, htmlToken, REPO, ROOT, type StateCore, type Token } from "./site.mts"

const EXAMPLE_FILE = /[\\/]examples[\\/]components[\\/]\w+\.luau$/

export function markdownPlugins(md: MarkdownRenderer) {
	githubLinks(md)
	softBreaks(md)
	codeBlocks(md)
	blogPostHeader(md)
	pageActions(md)
	chapterHeader(md)
	guideMap(md)
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

function githubLinks(md: MarkdownRenderer) {
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
function softBreaks(md: MarkdownRenderer) {
	md.renderer.rules.softbreak = () => " "
}

const titleOf = (info: string) => /\s\[([^\]]+)\]/.exec(info)?.[1]
const langOf = (info: string) => info.trim().split(/\s/)[0] || "text"
const isTab = (token?: Token) => token?.type === "fence" && /\stab(\s|$)/.test(token.info)

function codeBlocks(md: MarkdownRenderer) {
	md.core.ruler.push("code_tabs", (state: StateCore) => {
		const tokens = state.tokens
		for (let i = 0; i < tokens.length; i++) {
			if (!isTab(tokens[i])) continue
			let end = i
			while (isTab(tokens[end + 1])) end++
			const group = tokens.slice(i, end + 1)
			const buttons = group
				.map((token, n) => {
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

	const fence = md.renderer.rules.fence ?? ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options))
	md.renderer.rules.fence = (tokens, idx, options, env: MarkdownEnv, self) => {
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

function fileTree(md: MarkdownRenderer, content: string) {
	const escape = md.utils.escapeHtml
	const icon = (node: TreeNode) => {
		if (node.folder) return `<span class="fd-file-icon fd-folder" aria-hidden="true"></span>`
		const ext = node.name.split(".").pop()
		return `<span class="fd-file-icon" data-lang="${escape(ext === "luau" ? "lua" : (ext ?? ""))}" aria-hidden="true"></span>`
	}
	const item = (node: TreeNode): string => {
		const note = node.note ? `<span class="fd-file-note">${escape(node.note)}</span>` : ""
		const row = `<span class="fd-file-row">${icon(node)}<span class="fd-file-name">${escape(node.name)}</span>${note}</span>`
		return `<li>${row}${node.children.length ? list(node.children) : ""}</li>`
	}
	const list = (nodes: TreeNode[]): string => `<ul>${nodes.map(item).join("")}</ul>`
	return `<div class="fd-files">${list(parseTree(content))}</div>\n`
}

function pageActions(md: MarkdownRenderer) {
	md.core.ruler.push("page_actions", (state: StateCore) => {
		const tokens = state.tokens
		const close = tokens.findIndex((t) => t.type === "heading_close" && t.tag === "h1")
		if (close !== -1) tokens.splice(close + 1, 0, htmlToken(state, "<PageActions />\n"))
	})
}

function dropPagerLine(md: MarkdownRenderer) {
	md.core.ruler.push("drop_pager_line", (state: StateCore) => {
		const tokens = state.tokens
		const inline = tokens[tokens.length - 2]
		if (tokens[tokens.length - 1]?.type !== "paragraph_close" || inline?.type !== "inline") return
		if (/^\[(← |Guide contents\]|API reference\])/.test(inline.content) && /[←→]\]/.test(inline.content)) tokens.splice(-3, 3)
	})
}

const RELATED_LABEL = /\*\*(Try it|Reference):\*\*/g

function relatedRow(md: MarkdownRenderer, env: MarkdownEnv, label: string, source: string) {
	const items = source
		.replace(/\\\n/g, " ")
		.split(/\s+·\s+/)
		.map((item) => item.trim())
		.filter(Boolean)
		.map((item) => {
			const [, main, note] = /^(.*\S)\s+\(([^()]*(?:\([^()]*\)[^()]*)*)\)$/s.exec(item) ?? [, item]
			const noteHtml = note ? `<span class="fd-related-note">${md.renderInline(note, env)}</span>` : ""
			const example = /examples\/components\/(\w+)\.luau/.exec(main)?.[1]?.toLowerCase()
			const preview = example && fs.existsSync(path.join(DOCS, "assets/examples", `${example}.webp`))
			const thumb = preview ? `<img class="fd-related-thumb" src="${path.posix.relative(path.posix.dirname(env.relativePath), `assets/examples/${example}.webp`)}" alt="" loading="lazy" />` : ""
			return `<li${thumb ? ' class="fd-related-example"' : ""}>${thumb}<span>${md.renderInline(main, env)}${noteHtml}</span></li>`
		})
	const kind = label === "Try it" ? "try" : "reference"
	return `<div class="fd-related-row" data-kind="${kind}"><span class="fd-related-label">${label}</span><ul>${items.join("")}</ul></div>`
}

function relatedLinks(md: MarkdownRenderer) {
	md.core.ruler.push("related_links", (state: StateCore) => {
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

function themedImages(md: MarkdownRenderer) {
	const image = md.renderer.rules.image ?? ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options))
	md.renderer.rules.image = (tokens, idx, options, env: MarkdownEnv, self) => {
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

function blogPostHeader(md: MarkdownRenderer) {
	md.core.ruler.push("blog_post_header", (state: StateCore) => {
		const page: string = state.env?.relativePath ?? ""
		if (!page.startsWith("blog/") || page === "blog/index.md") return
		const tokens = state.tokens
		const h1 = tokens.findIndex((t) => t.type === "heading_open" && t.tag === "h1")
		if (h1 === -1) return
		tokens.splice(h1, 3)
		const banner = tokens[h1 + 1]
		if (tokens[h1]?.type === "paragraph_open" && banner?.children?.length === 1 && banner.children[0].type === "image") tokens.splice(h1, 3)
	})
}

const readingMinutes = (file: string) => Math.max(1, Math.round(fs.readFileSync(file, "utf8").split(/\s+/).length / 220))
const chapterOf = (page: string) => CHAPTERS.find((c) => page === `guide/${c.file}.md`)

function chapterHeader(md: MarkdownRenderer) {
	md.core.ruler.push("chapter_header", (state: StateCore) => {
		const page: string = state.env?.relativePath ?? ""
		const chapter = chapterOf(page)
		if (!chapter) return
		const close = state.tokens.findIndex((t) => t.type === "heading_close" && t.tag === "h1")
		if (close === -1) return
		const parts = [`Chapter ${chapter.number} of ${CHAPTERS.length}`, chapter.folder, `${readingMinutes(path.join(DOCS, page))} min read`]
		const html = `<p class="fd-chapter-meta">${parts.map((part) => `<span>${md.utils.escapeHtml(part)}</span>`).join("")}</p>\n`
		state.tokens.splice(close + 1, 0, htmlToken(state, html))
	})
}

function guideMap(md: MarkdownRenderer) {
	md.core.ruler.push("guide_map", (state: StateCore) => {
		if (state.env?.relativePath !== "GUIDE.md") return
		const tokens = state.tokens
		for (let i = 0; i < tokens.length; i++) {
			if (tokens[i].type !== "table_open") continue
			const close = tokens.findIndex((t, j) => j > i && t.type === "table_close")
			const rows: string[][] = []
			let row: string[] | undefined
			for (let j = i; j < close; j++) {
				if (tokens[j].type === "tr_open") row = []
				else if (tokens[j].type === "inline" && row) row.push(tokens[j].content)
				else if (tokens[j].type === "tr_close" && row) rows.push(row), (row = undefined)
			}
			const cards = rows.slice(1).map(([number, link, covers]) => {
				const [, title, href] = /\[([^\]]+)\]\(([^)]+)\)/.exec(link) ?? []
				const chapter = chapterOf(href ?? "")
				const minutes = chapter ? readingMinutes(path.join(DOCS, href)) : 0
				return `<li><a class="fd-chapter-card" href="${md.utils.escapeHtml(href.replace(/\.md$/, ""))}" data-chapter="${chapter?.file ?? ""}">
<span class="fd-chapter-num">${md.utils.escapeHtml(number)}</span>
<span class="fd-chapter-body"><strong>${md.utils.escapeHtml(title)}</strong><span>${md.renderInline(covers, state.env)}</span></span>
<span class="fd-chapter-time">${minutes} min<span class="fd-chapter-read"><span class="rv-visually-hidden">Read</span></span></span>
</a></li>`
			})
			tokens.splice(i, close - i + 1, htmlToken(state, `<ul class="fd-chapters">${cards.join("\n")}</ul>\n`))
		}
	})
}
