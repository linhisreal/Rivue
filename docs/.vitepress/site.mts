// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import fs from "node:fs"
import path from "node:path"
import { exampleMarkdown, type Example } from "./examples.mts"
import { introMarkdown } from "./intro.mts"

export const REPO = "https://github.com/linhisreal/Rivue"
export const SITE = "https://linhisreal.github.io/Rivue/"
export const DESCRIPTION = "Vue 3's component model for Roblox UI, in Luau"
export const ROOT = path.resolve(import.meta.dirname, "../..")
export const DOCS = path.join(ROOT, "docs")

export function slug(text: string) {
	return text
		.trim()
		.toLowerCase()
		.replace(/<[^>]*>/g, "")
		.replace(/[^\p{L}\p{N}\s_-]/gu, "")
		.replace(/\s/g, "-")
}

export function packageVersion(pkg: string) {
	const manifest = fs.readFileSync(path.join(ROOT, "packages", pkg, "wally.toml"), "utf8")
	return /^version = "([^"]+)"/m.exec(manifest)?.[1] ?? ""
}

export function pageUrl(page: string) {
	return SITE + (page === "README.md" || page === "index.md" ? "" : page.replace(/\.md$/, ""))
}

export function pageMarkdown(page: string, examples: Example[]) {
	const example = examples.find((e) => page === `examples/${e.slug}.md`)
	if (example) return exampleMarkdown(example)
	if (page === "introduction.md") return introMarkdown()
	return fs.readFileSync(path.join(DOCS, page), "utf8")
}

export function pageTitle(markdown: string, fallback: string) {
	return /^# (.+)$/m.exec(markdown)?.[1] ?? /<h1[^>]*>([^<]+)<\/h1>/.exec(markdown)?.[1] ?? fallback
}

export const plainTitle = (title: string) => title.replace(/`/g, "").replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")

export function htmlToken(state: any, content: string) {
	const token = new state.Token("html_block", "", 0)
	token.content = content
	return token
}
