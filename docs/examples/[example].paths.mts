import { exampleMarkdown, loadExamples } from "../.vitepress/examples.mts"

export default {
	paths() {
		return loadExamples().map((example) => ({ params: { example: example.slug }, content: exampleMarkdown(example) }))
	},
}
