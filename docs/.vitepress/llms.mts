// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import fs from "node:fs"
import path from "node:path"
import type { Example } from "./examples.mts"
import { DESCRIPTION, pageMarkdown, pageTitle, pageUrl } from "./site.mts"

export function writeLlmsFiles(pages: string[], outDir: string, examples: Example[]) {
	const sources = [...pages].sort().map((page) => {
		const markdown = pageMarkdown(page, examples)
		return { url: pageUrl(page), markdown, title: pageTitle(markdown, page) }
	})
	const index = sources.map(({ url, title }) => `- [${title}](${url})`).join("\n")
	fs.writeFileSync(path.join(outDir, "llms.txt"), `# Rivue\n\n> ${DESCRIPTION}.\n\n## Docs\n\n${index}\n`)
	const full = sources.map(({ url, markdown }) => `<!-- ${url} -->\n\n${markdown}`).join("\n\n---\n\n")
	fs.writeFileSync(path.join(outDir, "llms-full.txt"), full)
}
