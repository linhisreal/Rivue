// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import { execFileSync } from "node:child_process"
import fs from "node:fs"
import path from "node:path"
import { transformerMetaWordHighlight } from "@shikijs/transformers"
import { defineConfigWithTheme, type PageData } from "vitepress"
import { withMermaid } from "vitepress-plugin-mermaid"
import { exampleMarkdown, loadExamples } from "./examples.mts"
import { loadHovers, luaBlocks, stripPathComment, transformerLuauHovers, typeLines } from "./hovers.mts"
import { landingData, repoStats } from "./landing.mts"
import { writeLlmsFiles } from "./llms.mts"
import { markdownPlugins } from "./markdown.mts"
import { copyBanners, ogHead, ogPages, writeOgImages } from "./og.mts"
import { sidebar } from "./sidebar.mts"
import { loadPosts, writeFeed } from "./blog.mts"
import { DESCRIPTION, DOCS, packageVersion, REPO, ROOT, slug } from "./site.mts"
import type { ThemeConfig } from "./theme/types"

const PAGE_CLASSES: Record<string, string> = { "INSTALLATION.md": "fd-steps" }

const examples = loadExamples()
const posts = loadPosts()

function gitTime(file: string): number | undefined {
	try {
		const seconds = execFileSync("git", ["log", "-1", "--format=%ct", "--", file], { cwd: ROOT, encoding: "utf8" }).trim()
		return seconds ? Number(seconds) * 1000 : undefined
	} catch {
		return undefined
	}
}

function markdownFiles(dir: string): string[] {
	return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
		const full = path.join(dir, entry.name)
		if (entry.isDirectory()) return entry.name.startsWith(".") || entry.name === "superpowers" ? [] : markdownFiles(full)
		return entry.name.endsWith(".md") ? [full] : []
	})
}

const hovers = await loadHovers([
	...markdownFiles(DOCS).flatMap((file) => luaBlocks(fs.readFileSync(file, "utf8"))),
	...examples.map((example) => stripPathComment(example.code)),
])
const hoverLines = await typeLines()

function addPageData(pageData: PageData) {
	const page = pageData.relativePath
	if (page === "index.md") {
		pageData.frontmatter = { ...pageData.frontmatter, layout: "home" }
		return
	}
	const example = examples.find((e) => e.slug === pageData.params?.example)
	if (example) {
		pageData.lastUpdated = gitTime(example.file) ?? pageData.lastUpdated
		pageData.frontmatter = { ...pageData.frontmatter, githubPath: example.file, markdown: base64(exampleMarkdown(example)) }
		return
	}
	const source = pageData.params?.page === "introduction" ? "README.md" : pageData.filePath
	const isApi = page.startsWith("api/")
	pageData.lastUpdated = gitTime(`docs/${source}`) ?? pageData.lastUpdated
	pageData.frontmatter = {
		...pageData.frontmatter,
		githubPath: `docs/${source}`,
		pageClass: PAGE_CLASSES[page] ?? (isApi ? "fd-api" : undefined),
		...(page.startsWith("blog/") ? { layout: "BlogLayout", sidebar: false } : {}),
		...(isApi ? { outline: 2 } : {}),
		markdown: base64(fs.readFileSync(path.join(DOCS, source), "utf8")),
	}
}

const base64 = (text: string) => Buffer.from(text).toString("base64")

export default withMermaid(
	defineConfigWithTheme<ThemeConfig>({
		title: "Rivue",
		description: DESCRIPTION,
		base: "/Rivue/",
		cleanUrls: true,
		appearance: "dark",
		scrollOffset: { selector: ".VPLocalNav", padding: 24 },
		rewrites: { "README.md": "index.md" },
		srcExclude: ["assets/README.md", "superpowers/**"],
		lastUpdated: true,
		head: [
			["link", { rel: "icon", href: "/Rivue/favicon.ico", sizes: "any" }],
			["link", { rel: "icon", type: "image/png", sizes: "32x32", href: "/Rivue/favicon-32.png" }],
			["link", { rel: "apple-touch-icon", href: "/Rivue/apple-touch-icon.png" }],
			["link", { rel: "alternate", type: "application/rss+xml", title: "Rivue blog", href: "/Rivue/feed.xml" }],
			["meta", { name: "color-scheme", content: "dark light" }],
			["meta", { name: "theme-color", content: "#0a0a0a", media: "(prefers-color-scheme: dark)" }],
			["meta", { name: "theme-color", content: "#fafafa", media: "(prefers-color-scheme: light)" }],
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
		vite: { publicDir: path.join(DOCS, "assets/web") },
		buildEnd(site) {
			writeFeed(posts, site.outDir)
			writeLlmsFiles(site.pages, site.outDir, examples)
			writeOgImages(ogPages(site.pages, examples, posts), site.outDir, path.join(DOCS, "assets/web/icon-192.png"))
			copyBanners(posts, site.outDir)
		},
		transformHead: ({ pageData }) => ogHead(pageData, posts),
		transformPageData: addPageData,
		markdown: {
			codeTransformers: [transformerMetaWordHighlight(), transformerLuauHovers(hovers, hoverLines)],
			config: markdownPlugins,
			anchor: { slugify: slug },
			image: { lazyLoading: true },
		},
		mermaid: {
			fontFamily: "Geist, ui-sans-serif, system-ui, sans-serif",
			flowchart: { curve: "basis", padding: 12, nodeSpacing: 32, rankSpacing: 36 },
			sequence: { mirrorActors: false },
		},
		themeConfig: {
			logo: { src: "/icon-192.png", alt: "" },
			version: packageVersion("rivue-ui"),
			repo: { name: "linhisreal/Rivue", url: REPO, ...(await repoStats()) },
			landing: landingData(),
			blog: posts,
			outline: { level: [2, 3] },
			footer: {
				message: "Released under the Rivue License, based on PolyForm Noncommercial 1.0.0.",
				copyright: "Copyright © 2025-2026 linhisreal",
			},
			nav: [
				{ text: "Guide", link: "/GUIDE" },
				{ text: "API", link: "/API" },
				{ text: "Examples", link: `/examples/${examples[0].slug}` },
				{ text: "Blog", link: "/blog/", activeMatch: "^/blog/" },
			],
			sidebar: sidebar(examples),
			socialLinks: [{ icon: "github", link: REPO }],
			search: { provider: "local" },
		},
	}),
)
