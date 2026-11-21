import fs from "node:fs"
import path from "node:path"

const ROOT = path.resolve(__dirname, "../..")
const ROW = /^\| \[(\w+)\]\(components\/(\w+)\.luau\) \| (.+?) \| (.+?) \|$/
const CHAPTER = /\[(\d+)\]\(\.\.\/docs\/guide\/([\w-]+)\.md\)/g

export type Example = { slug: string; name: string; file: string; summary: string; chapters: string; code: string }

export function loadExamples(): Example[] {
	const readme = fs.readFileSync(path.join(ROOT, "examples/README.md"), "utf8")
	return readme.split("\n").flatMap((line) => {
		const match = ROW.exec(line.trim())
		if (!match) return []
		const [, name, base, summary, chapters] = match
		const file = `examples/components/${base}.luau`
		return [
			{
				slug: base.toLowerCase(),
				name,
				file,
				summary,
				chapters: [...chapters.matchAll(CHAPTER)].map(([, n, page]) => `[Chapter ${n}](/guide/${page})`).join(", "),
				code: fs.readFileSync(path.join(ROOT, file), "utf8").trimEnd(),
			},
		]
	})
}

export function exampleMarkdown(example: Example) {
	return `# ${example.name}

![${example.name}, drawn from the component's sizes, colours and text](../assets/examples/${example.slug}.webp)

What's in it: ${example.summary}. The picture above is an illustration made from the code, not a screenshot from Roblox.

Learn the parts in ${example.chapters}. \`tests/Examples.test.luau\` mounts this component and clicks through it, so the code below keeps working as Rivue changes.

\`\`\`lua [${example.file}]
${example.code}
\`\`\`

Copy the file into your game and mount it:

\`\`\`lua
local ${example.name} = require(path.to.${example.name})
Rivue.createApp(${example.name}):mountToPlayerGui(game.Players.LocalPlayer)
\`\`\`
`
}
