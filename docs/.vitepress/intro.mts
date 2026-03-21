import fs from "node:fs"
import path from "node:path"

const README = path.resolve(import.meta.dirname, "../README.md")

export function introMarkdown(): string {
	const readme = fs.readFileSync(README, "utf8")
	const body = readme.slice(readme.search(/^\|/m))
	const lead = /<h1[^>]*>[^<]*<\/h1>\s*<p[^>]*>\s*([\s\S]*?)\s*<\/p>/.exec(readme)?.[1] ?? ""
	return `# Introduction\n\n${lead}\n\n${body}`
}
