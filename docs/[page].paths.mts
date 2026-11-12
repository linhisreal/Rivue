import { introMarkdown } from "./.vitepress/intro.mts"

export default {
	paths() {
		return [{ params: { page: "introduction" }, content: introMarkdown() }]
	},
}
