// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import fs from "node:fs"
import { createRequire } from "node:module"
import path from "node:path"

export interface OgPage {
	slug: string
	title: string
	section: string
}

const WIDTH = 1200
const HEIGHT = 630
const require = createRequire(import.meta.url)

export const ogSlug = (page: string) => (page === "README.md" || page === "index.md" ? "index" : page.replace(/\.md$/, "").replaceAll("/", "-"))

export function ogSection(page: string) {
	if (page.startsWith("api/") || page === "API.md") return "API reference"
	if (page.startsWith("examples/")) return "Examples"
	if (page.startsWith("guide/") || page === "GUIDE.md") return "Guide"
	return "Docs"
}

const escape = (text: string) => text.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!)

function wrap(title: string, perLine = 26, maxLines = 3) {
	const lines: string[] = []
	let line = ""
	for (const word of title.split(/\s+/)) {
		if (line && (line + " " + word).length > perLine) {
			lines.push(line)
			line = word
		} else line = line ? `${line} ${word}` : word
	}
	if (line) lines.push(line)
	if (lines.length > maxLines) {
		lines.length = maxLines
		lines[maxLines - 1] = lines[maxLines - 1].replace(/\s*\S*$/, "") + "…"
	}
	return lines
}

function card(page: OgPage, icon: string) {
	const lines = wrap(page.title)
	const top = 324
	const title = lines.map((line, i) => `<text x="80" y="${top + i * 82}" font-family="Geist" font-size="72" font-weight="600" letter-spacing="-1.5" fill="#ededed">${escape(line)}</text>`).join("")
	const rings = [0, 1, 2, 3]
		.map((i) => {
			const size = 380 + i * 80
			const at = 256 - size / 2
			return `<rect x="${at}" y="${at}" width="${size}" height="${size}" rx="${84 + i * 20}" fill="none" stroke="#1f6feb" stroke-opacity="${[0.55, 0.32, 0.18, 0.09][i]}" stroke-width="2"/>`
		})
		.join("")
	return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
	<rect width="${WIDTH}" height="${HEIGHT}" fill="#0a0a0a"/>
	<g transform="translate(880 120) rotate(-15 256 256)">${rings}</g>
	<image x="80" y="72" width="56" height="56" href="data:image/png;base64,${icon}"/>
	<text x="152" y="112" font-family="Geist" font-size="34" font-weight="600" fill="#ededed">Rivue</text>
	<text x="80" y="236" font-family="Geist" font-size="28" font-weight="500" fill="#a1a1a1">${escape(page.section)}</text>
	${title}
	<text x="80" y="566" font-family="Geist" font-size="28" font-weight="500" fill="#a1a1a1">linhisreal.github.io/Rivue</text>
</svg>`
}

export function writeOgImages(pages: OgPage[], outDir: string, iconFile: string) {
	let Resvg: any
	let fontDir: string
	try {
		Resvg = require("@resvg/resvg-js").Resvg
		fontDir = path.join(path.dirname(require.resolve("geist/font")), "fonts/geist-sans")
	} catch {
		console.warn("Social preview images skipped: install @resvg/resvg-js and geist.")
		return
	}
	const icon = fs.readFileSync(iconFile).toString("base64")
	const fontFiles = ["Geist-Medium.ttf", "Geist-SemiBold.ttf"].map((name) => path.join(fontDir, name))
	fs.mkdirSync(path.join(outDir, "og"), { recursive: true })
	for (const page of pages) {
		const png = new Resvg(card(page, icon), { font: { fontFiles, loadSystemFonts: false, defaultFontFamily: "Geist" } }).render().asPng()
		fs.writeFileSync(path.join(outDir, "og", `${page.slug}.png`), png)
	}
}
