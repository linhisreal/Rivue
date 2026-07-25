// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import fs from "node:fs"
import path from "node:path"
import { DESCRIPTION, DOCS, SITE } from "./site.mts"

export type Post = {
	slug: string
	title: string
	description: string
	date: string
	author: string
	avatar: string
	tags: string[]
	banner?: string
	minutes: number
}

const BLOG = path.join(DOCS, "blog")

// GitHub user ids, so avatars load from avatars.githubusercontent.com without a redirect
const AUTHORS: Record<string, number> = { linhisreal: 97074586 }

// only the flat "key: value" and "key: [a, b]" lines posts use
function frontmatter(text: string) {
	const block = /^---\n([\s\S]*?)\n---\n/.exec(text)?.[1] ?? ""
	const fields: Record<string, string | string[]> = {}
	for (const line of block.split("\n")) {
		const [, key, raw] = /^(\w+):\s*(.*)$/.exec(line) ?? []
		if (!key) continue
		const list = /^\[(.*)\]$/.exec(raw)
		fields[key] = list ? list[1].split(",").map((tag) => tag.trim()).filter(Boolean) : raw.replace(/^["']|["']$/g, "")
	}
	return fields
}

export function loadPosts(): Post[] {
	if (!fs.existsSync(BLOG)) return []
	return fs
		.readdirSync(BLOG)
		.filter((file) => file.endsWith(".md") && file !== "index.md")
		.map((file) => {
			const text = fs.readFileSync(path.join(BLOG, file), "utf8")
			const fields = frontmatter(text)
			const body = text.replace(/^---\n[\s\S]*?\n---\n/, "")
			return {
				slug: file.replace(/\.md$/, ""),
				title: String(fields.title ?? /^# (.+)$/m.exec(body)?.[1] ?? file),
				description: String(fields.description ?? ""),
				date: String(fields.date ?? ""),
				author: String(fields.author ?? "linhisreal"),
				avatar: `https://avatars.githubusercontent.com/u/${AUTHORS[String(fields.author ?? "linhisreal")] ?? 0}?s=96`,
				tags: Array.isArray(fields.tags) ? fields.tags : [],
				banner: /!\[[^\]]*\]\(([^)]+)\)/.exec(body)?.[1]?.split("/").pop(),
				minutes: Math.max(1, Math.round(body.split(/\s+/).length / 220)),
			}
		})
		.sort((a, b) => b.date.localeCompare(a.date))
}

const escape = (text: string) => text.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!)

export function writeFeed(posts: Post[], outDir: string) {
	const items = posts
		.map(
			(post) => `<item>
<title>${escape(post.title)}</title>
<link>${SITE}blog/${post.slug}</link>
<guid>${SITE}blog/${post.slug}</guid>
<pubDate>${new Date(post.date).toUTCString()}</pubDate>
<description>${escape(post.description)}</description>
</item>`,
		)
		.join("\n")
	fs.writeFileSync(
		path.join(outDir, "feed.xml"),
		`<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
<title>Rivue blog</title>
<link>${SITE}blog/</link>
<description>${escape(DESCRIPTION)}</description>
${items}
</channel>
</rss>
`,
	)
}
