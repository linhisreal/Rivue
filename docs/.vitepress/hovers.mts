// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import { spawn, spawnSync } from "node:child_process"
import crypto from "node:crypto"
import fs from "node:fs"
import path from "node:path"
import { createHighlighter, type ShikiTransformer, type ThemedToken } from "shiki"

export interface Hover {
	line: number
	col: number
	length: number
	text: string
}

const ROOT = path.resolve(import.meta.dirname, "../..")
const CACHE = path.join(import.meta.dirname, "cache")
const DEFINITIONS_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.66.0/scripts/globalTypes.d.luau"

const PREAMBLE = `local Rivue = require(game:GetService("ReplicatedStorage"):WaitForChild("RivueUI"))
local h = Rivue.h
local Players = game:GetService("Players")
local array = Rivue.array
local Remote = require(game:GetService("ReplicatedStorage"):WaitForChild("RivueRemote"))
local Router = require(game:GetService("ReplicatedStorage"):WaitForChild("RivueRouter"))
`
const PREAMBLE_LINES = PREAMBLE.split("\n").length - 1

const KEYWORDS = new Set(
	"and break continue do else elseif end export false for function if in local nil not or repeat return then true type typeof until while".split(" "),
)

const MAX_LINES = 12
const MAX_WIDTH = 160

export const hoverKey = (code: string) => crypto.createHash("sha1").update(code.replace(/\s+$/, "")).digest("hex")

// the fence renderer drops a leading "-- path.luau" line before highlighting, so hovers must match the code without it
export function stripPathComment(code: string) {
	return code.replace(/^-- [\w./-]+\.luau\s*\n/, "")
}

export function luaBlocks(markdown: string): string[] {
	const blocks: string[] = []
	const fence = /^([ \t]*)(`{3,}|~{3,})(lua|luau)\b[^\n]*\n([\s\S]*?)^\1\2[ \t]*$/gm
	for (const match of markdown.matchAll(fence)) {
		const indent = match[1]
		const body = match[4].replace(new RegExp(`^${indent}`, "gm"), "")
		blocks.push(stripPathComment(body))
	}
	return blocks
}

function identifiers(code: string) {
	const found: { line: number; col: number; name: string }[] = []
	let i = 0
	let line = 0
	let lineStart = 0
	const longBracket = (at: number) => /^\[(=*)\[/.exec(code.slice(at))
	while (i < code.length) {
		const c = code[i]
		if (c === "\n") {
			line++
			i++
			lineStart = i
			continue
		}
		if (code.startsWith("--", i)) {
			const long = longBracket(i + 2)
			const end = long ? code.indexOf(`]${long[1]}]`, i) : code.indexOf("\n", i)
			const stop = end === -1 ? code.length : long ? end + long[0].length : end
			for (let k = i; k < stop; k++) if (code[k] === "\n") (line++, (lineStart = k + 1))
			i = stop
			continue
		}
		if (c === '"' || c === "'" || c === "`") {
			let k = i + 1
			while (k < code.length && code[k] !== c && code[k] !== "\n") k += code[k] === "\\" ? 2 : 1
			i = k + 1
			continue
		}
		const long = c === "[" && longBracket(i)
		if (long) {
			const end = code.indexOf(`]${long[1]}]`, i)
			const stop = end === -1 ? code.length : end + long[0].length
			for (let k = i; k < stop; k++) if (code[k] === "\n") (line++, (lineStart = k + 1))
			i = stop
			continue
		}
		if (/[0-9]/.test(c)) {
			const m = /^[0-9][\w.]*/.exec(code.slice(i))!
			i += m[0].length
			continue
		}
		if (/[A-Za-z_]/.test(c)) {
			const name = /^[A-Za-z_]\w*/.exec(code.slice(i))![0]
			if (!KEYWORDS.has(name)) found.push({ line, col: i - lineStart, name })
			i += name.length
			continue
		}
		i++
	}
	return found
}

function tidy(value: string): string | undefined {
	const code = /```luau?\n([\s\S]*?)```/.exec(value)?.[1]?.trimEnd().replaceAll("*TRUNCATED*", "...").replace(/\.\.\.(\s*\.\.\.)+/g, "...")
	if (!code || code.includes("*error-type*")) return undefined
	const lines = code.split("\n").map((line) => (line.length > MAX_WIDTH ? `${line.slice(0, MAX_WIDTH - 3)}...` : line))
	if (lines.length <= MAX_LINES) return lines.join("\n")
	return [...lines.slice(0, MAX_LINES - 2), "    ...", lines.at(-1)].join("\n")
}

function findBinary(name: string): string | undefined {
	const result = spawnSync(name, ["--version"], { encoding: "utf8" })
	return result.status === 0 ? name : undefined
}

async function definitions(): Promise<string | undefined> {
	if (process.env.LUAU_DEFINITIONS && fs.existsSync(process.env.LUAU_DEFINITIONS)) return process.env.LUAU_DEFINITIONS
	const file = path.join(CACHE, "globalTypes.d.luau")
	if (fs.existsSync(file)) return file
	try {
		const response = await fetch(DEFINITIONS_URL)
		if (!response.ok) return undefined
		fs.mkdirSync(CACHE, { recursive: true })
		fs.writeFileSync(file, await response.text())
		return file
	} catch {
		return undefined
	}
}

function sourceSalt(): string {
	const hash = crypto.createHash("sha1")
	const walk = (dir: string) => {
		for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
			const full = path.join(dir, entry.name)
			if (entry.isDirectory()) walk(full)
			else if (entry.name.endsWith(".luau")) hash.update(full).update(fs.readFileSync(full))
		}
	}
	walk(path.join(ROOT, "packages"))
	return hash.digest("hex")
}

class LuauServer {
	private buffer = Buffer.alloc(0)
	private id = 0
	private pending = new Map<number, (result: any) => void>()
	private child

	constructor(binary: string, defs: string) {
		const settings = {
			platform: { type: "roblox" },
			sourcemap: { enabled: true, rojoProjectFile: "default.project.json", autogenerate: false },
			types: { definitionFiles: [defs] },
			diagnostics: { workspace: false },
		}
		this.child = spawn(binary, ["lsp", `--definitions=${defs}`], { cwd: ROOT, stdio: ["pipe", "pipe", "ignore"] })
		this.child.stdout.on("data", (chunk: Buffer) => {
			this.buffer = Buffer.concat([this.buffer, chunk])
			for (;;) {
				const head = this.buffer.indexOf("\r\n\r\n")
				if (head < 0) return
				const length = Number(/Content-Length: (\d+)/i.exec(this.buffer.subarray(0, head).toString())?.[1])
				if (this.buffer.length < head + 4 + length) return
				const message = JSON.parse(this.buffer.subarray(head + 4, head + 4 + length).toString())
				this.buffer = this.buffer.subarray(head + 4 + length)
				if (message.method === "workspace/configuration") this.send({ id: message.id, result: message.params.items.map(() => settings) })
				else if (message.method && message.id != null) this.send({ id: message.id, result: null })
				else if (message.id != null) {
					this.pending.get(message.id)?.(message.result)
					this.pending.delete(message.id)
				}
			}
		})
	}

	send(message: object) {
		const body = JSON.stringify({ jsonrpc: "2.0", ...message })
		this.child.stdin.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`)
	}

	request(method: string, params?: object): Promise<any> {
		return new Promise((resolve) => {
			const id = ++this.id
			this.pending.set(id, resolve)
			this.send({ id, method, params })
		})
	}

	async start() {
		const uri = `file://${ROOT}`
		await this.request("initialize", {
			processId: process.pid,
			rootUri: uri,
			capabilities: { workspace: { configuration: true } },
			workspaceFolders: [{ uri, name: "Rivue" }],
		})
		this.send({ method: "initialized", params: {} })
	}

	async hovers(code: string, n: number): Promise<Hover[]> {
		const uri = `file://${path.join(ROOT, "docs/.vitepress/cache/hover", `block${n}.luau`)}`
		this.send({ method: "textDocument/didOpen", params: { textDocument: { uri, languageId: "luau", version: 1, text: PREAMBLE + code } } })
		const results = await Promise.all(
			identifiers(code).map(async (spot) => {
				const result = await this.request("textDocument/hover", {
					textDocument: { uri },
					position: { line: spot.line + PREAMBLE_LINES, character: spot.col },
				})
				const text = tidy(result?.contents?.value ?? "")
				return text ? { line: spot.line, col: spot.col, length: spot.name.length, text } : undefined
			}),
		)
		this.send({ method: "textDocument/didClose", params: { textDocument: { uri } } })
		return results.filter((hover): hover is Hover => hover !== undefined)
	}

	async stop() {
		await this.request("shutdown")
		this.send({ method: "exit" })
	}
}

export async function loadHovers(blocks: string[]): Promise<Map<string, Hover[]>> {
	const table = new Map<string, Hover[]>()
	const binary = process.env.LUAU_LSP ?? findBinary("luau-lsp")
	const defs = binary && (await definitions())
	if (!binary || !defs || !fs.existsSync(path.join(ROOT, "sourcemap.json"))) {
		console.warn("Type hovers skipped: needs luau-lsp, its Roblox definitions and sourcemap.json (rojo sourcemap).")
		return table
	}

	const cacheFile = path.join(CACHE, "luau-hovers.json")
	const salt = sourceSalt()
	let cache: Record<string, Hover[]> = {}
	try {
		const stored = JSON.parse(fs.readFileSync(cacheFile, "utf8"))
		if (stored.salt === salt) cache = stored.blocks
	} catch {}

	const unique = [...new Set(blocks)]
	const missing = unique.filter((code) => !cache[hoverKey(code)])
	if (missing.length > 0) {
		const server = new LuauServer(binary, defs)
		await server.start()
		let n = 0
		for (const code of missing) cache[hoverKey(code)] = await server.hovers(code, n++)
		await server.stop()
	}

	const kept: Record<string, Hover[]> = {}
	for (const code of unique) {
		const key = hoverKey(code)
		kept[key] = cache[key]
		table.set(key, cache[key])
	}
	fs.mkdirSync(CACHE, { recursive: true })
	fs.writeFileSync(cacheFile, JSON.stringify({ salt, blocks: kept }))
	return table
}

export async function typeLines(): Promise<(code: string) => any[]> {
	const highlighter = await createHighlighter({ themes: ["github-light", "github-dark"], langs: ["luau"] })
	return (code) => {
		const root: any = highlighter.codeToHast(code, { lang: "luau", themes: { light: "github-light", dark: "github-dark" } })
		return root.children[0].children[0].children
	}
}

export function transformerLuauHovers(table: Map<string, Hover[]>, highlight: (code: string) => any[]): ShikiTransformer {
	return {
		name: "rivue:luau-hovers",
		tokens(lines) {
			if (this.options.lang !== "lua" && this.options.lang !== "luau") return
			const hovers = table.get(hoverKey(this.source))
			if (!hovers?.length) return
			const byLine = new Map<number, Hover[]>()
			for (const hover of hovers) byLine.set(hover.line, [...(byLine.get(hover.line) ?? []), hover])
			return lines.map((tokens, lineIndex) => {
				const spots = byLine.get(lineIndex)
				if (!spots) return tokens
				const out: ThemedToken[] = []
				const start = tokens[0]?.offset ?? 0
				for (const token of tokens) {
					let cuts = [0, token.content.length]
					for (const spot of spots) {
						const from = spot.col - (token.offset - start)
						if (from >= 0 && from + spot.length <= token.content.length) cuts.push(from, from + spot.length)
					}
					cuts = [...new Set(cuts)].sort((a, b) => a - b)
					for (let k = 0; k < cuts.length - 1; k++) {
						const content = token.content.slice(cuts[k], cuts[k + 1])
						if (content) out.push({ ...token, content, offset: token.offset + cuts[k] })
					}
				}
				return out
			})
		},
		span(node, line, col, _lineElement, token) {
			if (this.options.lang !== "lua" && this.options.lang !== "luau") return
			const hover = table.get(hoverKey(this.source))?.find((h) => h.line === line - 1 && h.col === col && h.length === token.content.length)
			if (!hover) return
			const pops: string[] = (this.meta.luauPops ??= [])
			let id = pops.indexOf(hover.text)
			if (id === -1) id = pops.push(hover.text) - 1
			node.properties.class = [node.properties.class, "fd-type"].filter(Boolean).join(" ")
			node.properties["data-type"] = String(id)
		},
		root(root) {
			const pops: string[] | undefined = this.meta.luauPops
			if (!pops?.length) return
			root.children.push({
				type: "element",
				tagName: "div",
				properties: { class: "fd-type-pops", hidden: true, "v-pre": "" },
				children: pops.map((text, id) => ({
					type: "element",
					tagName: "span",
					properties: { "data-pop": String(id) },
					children: highlight(text),
				})),
			})
		},
	}
}
