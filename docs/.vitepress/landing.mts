// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import fs from "node:fs"
import path from "node:path"
import { createHighlighter } from "shiki"
import { siteLink } from "./markdown.mts"
import { DOCS, packageVersion } from "./site.mts"

const SHOP = `local ITEMS = {
	{ name = "Sword", price = 20 },
	{ name = "Shield", price = 30 },
	{ name = "Potion", price = 10 },
}

local Shop = Rivue.defineComponent({
	name = "Shop",
	setup = function()
		local coins = Rivue.ref(30)
		local owned = Rivue.reactive({})
		return {
			coins = coins,
			owned = owned,
			buy = function(item)
				coins.value -= item.price
				owned[item.name] = true
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { Name = "Shop", class = "shop" }, {
			h("UIListLayout"),
			h("TextLabel", { Name = "Coins", Text = \`{ctx.coins} coins\` }),
			h("TextButton", {
				Name = "Earn",
				Text = "+10 coins",
				onClick = function()
					ctx.coins += 10
				end,
			}),
			Rivue.hFor(ITEMS, function(item)
				return h(ItemRow, {
					key = item.name,
					name = item.name,
					price = item.price,
					owned = ctx.owned[item.name] == true,
					affordable = ctx.coins >= item.price,
					onBuy = function()
						ctx.buy(item)
					end,
				})
			end),
		})
	end,
})`

const ITEM_ROW = `local ItemRow = Rivue.defineComponent({
	name = "ItemRow",
	props = {
		name = { type = "string" },
		price = { type = "number" },
		owned = { type = "boolean", default = false },
		affordable = { type = "boolean", default = true },
	},
	emits = { "buy" },
	render = function(ctx)
		return h("TextButton", {
			Name = ctx.name,
			class = "row",
			Text = if ctx.owned then \`{ctx.name} · Owned\` else \`{ctx.name} · {ctx.price}\`,
			disabled = ctx.owned or not ctx.affordable,
			onClick = function()
				ctx.emit("buy")
			end,
		})
	end,
})`

const VUE_COUNTER = `<script setup>
import { ref } from "vue"

const count = ref(0)
</script>

<template>
  <button @click="count++">Clicked {{ count }} times</button>
</template>`

const highlighter = await createHighlighter({ themes: ["github-light", "github-dark"], langs: ["luau", "vue"] })

function highlight(code: string, lang: string, steps: Record<string, string> = {}) {
	const lines = code.split("\n")
	const stepAt = new Map(Object.entries(steps).map(([text, step]) => [lines.findIndex((l) => l.includes(text)) + 1, step]))
	return highlighter.codeToHtml(code, {
		lang,
		themes: { light: "github-light", dark: "github-dark" },
		transformers: [
			{
				line(node, line) {
					const step = stepAt.get(line)
					if (step) node.properties["data-step"] = step
				},
			},
		],
	})
}

// read from the comparison page so the landing page and the docs can't drift apart
function counters() {
	const page = fs.readFileSync(path.join(DOCS, "COMING-FROM-REACT.md"), "utf8")
	const section = page.slice(page.indexOf("## The same counter in each"), page.indexOf("## API map"))
	const [react, fusion, rivue] = [...section.matchAll(/```lua\n([\s\S]*?)```/g)].map((m) => m[1].trimEnd())
	return { react, fusion, rivue }
}

function lookup() {
	const readme = fs.readFileSync(path.join(DOCS, "README.md"), "utf8")
	const table = readme.slice(readme.indexOf("## I want to"))
	const href = (link: string) => {
		const [file, hash] = link.split("#")
		const target = path.resolve(DOCS, file)
		return siteLink(target) ?? `/${path.relative(DOCS, target).replace(/\.md$/, "")}${hash ? `#${hash}` : ""}`
	}
	const links = (cell: string) => [...cell.matchAll(/\[([^\]]+)\]\(([^)]+)\)/g)].map((m) => ({ text: m[1], href: href(m[2]) }))
	return table
		.split("\n")
		.filter((line) => line.startsWith("| ") && !line.startsWith("| I want to"))
		.map((line) => {
			const [task, learn, api, example] = line.split("|").slice(1, -1).map((cell) => cell.trim())
			return { task: task[0].toUpperCase() + task.slice(1), learn: links(learn), api: links(api), example: links(example) }
		})
}

export function landingData() {
	const { react, fusion, rivue } = counters()
	return {
		lookup: lookup(),
		shop: highlight(SHOP, "luau", {
			"coins.value -= item.price": "spend",
			"owned[item.name] = true": "own",
			"ctx.coins += 10": "earn",
			"Text = `{ctx.coins} coins`": "coins",
			"owned = ctx.owned": "props",
			"affordable = ctx.coins": "props",
			"ctx.buy(item)": "call",
		}),
		itemRow: highlight(ITEM_ROW, "luau", {
			'ctx.emit("buy")': "emit",
			"Text = if ctx.owned": "text",
			"disabled = ctx.owned": "disabled",
		}),
		compare: [
			{ name: "Vue", lang: "vue", html: highlight(VUE_COUNTER, "vue") },
			{ name: "Rivue", lang: "luau", html: highlight(rivue, "luau") },
			{ name: "React-lua", lang: "luau", html: highlight(react, "luau") },
			{ name: "Fusion", lang: "luau", html: highlight(fusion, "luau") },
		],
		packages: [
			{
				name: "RivueUI",
				version: packageVersion("rivue-ui"),
				text: "Components, reactivity, styling and the built-ins.",
				link: "/guide/01-introduction",
				example: "Rivue.createApp(App):mount(gui)",
			},
			{ name: "RivueRemote", version: packageVersion("rivue-remote"), text: "Checked client/server calls, events and replicated state.", link: "/api/remote" },
			{ name: "RivueRouter", version: packageVersion("rivue-router"), text: "Screens with history, guards and nested routes.", link: "/api/router" },
			{ name: "RivueDevTools", version: "", text: "Props, state, renders and network, live during a playtest.", link: "/DEVTOOLS" },
		],
	}
}

// the docs workflow passes its GITHUB_TOKEN; without it (or offline) the repo card just shows the name
export async function repoStats() {
	const headers: Record<string, string> = { "User-Agent": "rivue-docs" }
	if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`
	const get = (url: string) => fetch(`https://api.github.com/repos/linhisreal/Rivue${url}`, { headers, signal: AbortSignal.timeout(5000) })
	try {
		const [repo, releases] = await Promise.all([get(""), get("/releases?per_page=1")])
		if (!repo.ok) return {}
		const data = await repo.json()
		const latest = releases.ok ? (await releases.json())[0] : undefined
		return { stars: data.stargazers_count as number, forks: data.forks_count as number, tag: latest?.tag_name as string | undefined }
	} catch {
		return {}
	}
}
