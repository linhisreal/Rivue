// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import { COLS, DIGITS, GLYPH_START, type Digit, pixels } from "./glyphs"
import type { Scene } from "./types"

type Point = [number, Keyframe]
type Track = { el: HTMLElement; points: Point[] }
type Plan = { tracks: Track[]; lineAt: (index: number) => number }

const EASE = "cubic-bezier(0.65, 0, 0.35, 1)"
const OUT = "cubic-bezier(0.16, 1, 0.3, 1)"
const HALF = 0.5
const ART_RETURN_LEAD = 34

const PIXELS = { glyphWidth: 5, glyphHeight: 7, inset: 2 }
const REACTIVITY = { flipStep: 16, flipStart: 40, flipMid: 150, flipEnd: 260, gather: 640, land: 1000, gone: 1100, fadeOff: 220, fadeScale: 0.4, line: 900, linesFrom: 620, lineStep: 35 }
const COMPONENTS = { rowStep: 90, rowTravel: 420, rowGone: 480, rowFade: 0.9, press: 440, pressDeep: 560, pressUp: 680, unfold: 1000, unfoldGone: 1160, pressScale: 1.05, unfoldFade: 0.5, labelLand: 980, labelGone: 1060, linesFrom: 760, lineStep: 55 }
const STYLING = { frameHold: 480, frameLand: 900, frameGone: 1040, frameRadius: "4px", labelStep: 110, labelLift: 220, labelLand: 660, labelGone: 740, liftY: -10, widthRise: 160, widthDrop: 520, widthRiseY: -4, widthDropY: 24, headLine: 820, paddingLine: 600, radiusLine: 720, layoutLine: 1000, otherLines: 880 }
const ANIMATION = { ride: 760, passCurve: 1.6, collect: 160, collectScale: 0.85, settle: 1060, settleGone: 1200, lineRadius: "4px", easeGone: 320, easeDropY: 6, focusLine: 980, linesFrom: 600, linesSpan: 600 }
const LISTS = { maxRows: 4, rowStep: 70, travel: 380, gone: 480, lineLead: 80, cycle: 520, reenter: 40, belowY: 36, barHeight: 0.6 }
const TYPED = { hold: 120, grow: 600, growGone: 800, linesGone: 700, errorGone: 240, errorDropY: 8, codeLines: 540, newFrom: 660, newStep: 60 }

class Stage {
	readonly origin: DOMRect
	readonly lines: HTMLElement[]
	readonly layer: HTMLElement

	constructor(
		readonly stage: HTMLElement,
		readonly art: HTMLElement,
	) {
		this.origin = stage.getBoundingClientRect()
		this.lines = [...stage.querySelectorAll<HTMLElement>(".rv-spec-src .line")]
		this.layer = document.createElement("div")
		this.layer.className = "rv-spec-morph"
		this.layer.setAttribute("aria-hidden", "true")
	}

	piece(selector: string) {
		return this.art.querySelector<HTMLElement>(selector)
	}

	pieces(selector: string) {
		return [...this.art.querySelectorAll<HTMLElement>(selector)]
	}

	codeScale(piece: Element) {
		return fontSize(this.lines[0]) / fontSize(piece)
	}

	line(text: string) {
		return this.lines.findIndex((line) => line.textContent?.includes(text))
	}

	text(index: number, text?: string) {
		const line = this.lines[index]
		const box = line.getBoundingClientRect()
		const range = document.createRange()
		const at = text ? (line.textContent ?? "").indexOf(text) : -1
		if (!text || at < 0) {
			range.selectNodeContents(line)
			const words = range.getBoundingClientRect()
			return words.width ? new DOMRect(words.left, box.top, words.width, box.height) : box
		}
		const nodes = textNodes(line)
		const starts = nodes.map((_, i) => nodes.slice(0, i).reduce((sum, node) => sum + node.length, 0))
		const end = at + text.length
		const first = starts.findLastIndex((start) => start <= at)
		const last = starts.findLastIndex((start) => start < end)
		range.setStart(nodes[first], at - starts[first])
		range.setEnd(nodes[last], end - starts[last])
		const words = range.getBoundingClientRect()
		return new DOMRect(words.left, box.top, words.width, box.height)
	}

	block() {
		const first = this.lines[0].getBoundingClientRect()
		const last = this.lines[this.lines.length - 1].getBoundingClientRect()
		const pre = this.stage.querySelector(".rv-spec-src pre")?.getBoundingClientRect() ?? first
		return new DOMRect(pre.left, first.top, pre.width, last.bottom - first.top)
	}

	place(box: DOMRect): Keyframe {
		return {
			left: `${box.left - this.origin.left}px`,
			top: `${box.top - this.origin.top}px`,
			width: `${box.width}px`,
			height: `${box.height}px`,
		}
	}

	ghost(piece: Element, box = piece.getBoundingClientRect(), keepPath = false) {
		const ghost = withLook(piece)
		Object.assign(ghost.style, {
			position: "absolute",
			...this.place(box),
			margin: "0",
			transform: "none",
			translate: "none",
			rotate: "none",
			scale: "none",
			transformOrigin: "50% 50%",
			...(keepPath ? {} : { offsetPath: "none" }),
		})
		this.layer.append(ghost)
		return ghost
	}

	dot(piece: Element, box: DOMRect) {
		const dot = document.createElement("i")
		Object.assign(dot.style, { position: "absolute", ...this.place(box), borderRadius: getComputedStyle(piece).borderRadius })
		this.layer.append(dot)
		return dot
	}

	shell(piece: Element, box = piece.getBoundingClientRect()) {
		const shell = this.ghost(piece, box)
		shell.replaceChildren()
		return shell
	}

	label(piece: Element, text: string) {
		const box = piece.getBoundingClientRect()
		const style = getComputedStyle(piece)
		const label = document.createElement("span")
		label.textContent = text
		Object.assign(label.style, {
			position: "absolute",
			...this.place(box),
			width: "auto",
			font: style.font,
			lineHeight: `${box.height}px`,
			color: style.color,
			whiteSpace: "nowrap",
			transformOrigin: "0 50%",
		})
		this.layer.append(label)
		return label
	}
}

export function shownTick(tick: Element) {
	const window = tick.getBoundingClientRect()
	const overlap = (span: Element) => {
		const box = span.getBoundingClientRect()
		return Math.min(box.bottom, window.bottom) - Math.max(box.top, window.top)
	}
	const spans = [...tick.children]
	const best = spans.reduce((a, b) => (overlap(b) > overlap(a) ? b : a), spans[0])
	return best?.textContent?.trim() ?? ""
}

const LOOK = [
	"display", "position", "top", "right", "bottom", "left", "z-index", "box-sizing", "width", "height", "overflow",
	"padding-top", "padding-right", "padding-bottom", "padding-left",
	"border-top", "border-right", "border-bottom", "border-left",
	"border-top-left-radius", "border-top-right-radius", "border-bottom-right-radius", "border-bottom-left-radius",
	"background-color", "background-image", "background-size", "background-position", "background-repeat", "box-shadow", "opacity",
	"color", "font-family", "font-size", "font-weight", "font-style", "line-height", "letter-spacing", "text-transform",
	"text-align", "white-space", "vertical-align", "text-decoration",
	"flex-direction", "flex-grow", "flex-shrink", "flex-basis", "align-items", "align-content", "justify-content", "justify-items",
	"grid-template-columns", "grid-template-rows", "grid-column", "grid-row", "column-gap", "row-gap",
	"offset-path", "offset-distance", "offset-rotate", "offset-anchor", "transform", "transform-origin",
	"mask-image", "mask-size", "mask-position", "mask-repeat", "clip-path",
	"fill", "stroke", "stroke-width", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap",
]

const textNodes = (node: Node): Text[] => (node instanceof Text ? [node] : [...node.childNodes].flatMap(textNodes))

function withLook(from: Element): HTMLElement {
	const clone = from.cloneNode(false) as HTMLElement
	const style = getComputedStyle(from)
	LOOK.forEach((name) => clone.style.setProperty(name, style.getPropertyValue(name)))
	clone.style.animation = "none"
	clone.style.transition = "none"
	clone.append(...[...from.childNodes].map((node) => (node instanceof Element ? withLook(node) : node.cloneNode())))
	return clone
}

function fly(from: DOMRect, to: DOMRect) {
	const s = Math.min(to.width / from.width, to.height / from.height)
	const dx = to.left + to.width * HALF - (from.left + from.width * HALF)
	const dy = to.top + to.height * HALF - (from.top + from.height * HALF)
	return `translate(${dx}px, ${dy}px) scale(${s})`
}

function onto(from: DOMRect, to: DOMRect, scale: number) {
	return `translate(${to.left - from.left}px, ${to.top + to.height * HALF - (from.top + from.height * HALF)}px) scale(${scale})`
}

const fontSize = (el: Element) => parseFloat(getComputedStyle(el).fontSize)

const at = (ms: number, transform: string, opacity = 1, extra: Keyframe = {}): Point => [ms, { transform, opacity, ...extra }]

const CHOREOGRAPHY: Record<Scene, (s: Stage, opening: boolean) => Plan | null> = {
	reactivity(s) {
		const t = REACTIVITY
		const field = s.piece(".rv-field")
		const start = s.line("Rivue.ref(")
		const target = s.line("coins.value =")
		if (!field || start < 0 || target < 0) return null
		const from = Number(s.lines[start].textContent?.match(/ref\((\d)\)/)?.[1]) as Digit
		const to = Number(s.lines[target].textContent?.match(/coins\.value = (\d)/)?.[1]) as Digit
		if (!DIGITS.includes(from) || !DIGITS.includes(to)) return null
		const before = DIGITS.indexOf(from)
		const after = DIGITS.indexOf(to)
		const glyph = s.text(target, String(to))
		const palette = getComputedStyle(field)
		const color = (lit: boolean) => ({ backgroundColor: palette.getPropertyValue(lit ? "--rv-px-on" : "--rv-px-off") })
		const cell = (glyph.height - PIXELS.inset - PIXELS.inset) / PIXELS.glyphHeight
		const cells = s.pieces(".rv-field i").map((el, i) => ({ el, i, was: pixels[i][before] === "1", now: pixels[i][after] === "1" }))
		const changing = cells.filter(({ was, now }) => was !== now)
		const tracks = cells.map(({ el, i, was, now }) => {
			const box = el.getBoundingClientRect()
			const flip = changing.findIndex((c) => c.el === el) * t.flipStep
			const flipping: Point[] =
				was === now ? [] : [at(flip + t.flipStart, "none", 1, color(was)), at(flip + t.flipMid, "scaleX(0)", 1, color(was)), at(flip + t.flipEnd, "none", 1, color(now))]
			const row = Math.floor(i / COLS)
			const col = (i % COLS) - GLYPH_START
			const dot = new DOMRect(glyph.left + (col / PIXELS.glyphWidth) * glyph.width, glyph.top + PIXELS.inset + row * cell, glyph.width / PIXELS.glyphWidth, cell)
			const ending: Point[] = now
				? [at(t.gather, "none", 1, color(true)), at(t.land, fly(box, dot), 1, color(true)), at(t.gone, fly(box, dot), 0, color(true))]
				: [at(t.gather, "none", 1, color(false)), at(t.gather + t.fadeOff, `scale(${t.fadeScale})`, 0, color(false))]
			return { el: s.dot(el, box), points: [at(0, "none", 1, color(was)), ...flipping, ...ending] }
		})
		return { tracks, lineAt: (i) => (i === target ? t.line : t.linesFrom + i * t.lineStep) }
	},

	components(s) {
		const t = COMPONENTS
		const mould = s.piece(".rv-mould-print")
		const name = s.piece(".rv-mould-print .rv-lbl")
		const head = s.line("ItemRow")
		if (!mould || head < 0) return null
		const mouldBox = mould.getBoundingClientRect()
		const rows = s.pieces(".rv-copy-row").map((row, i) => {
			const box = row.getBoundingClientRect()
			const into = fly(box, mouldBox)
			const start = i * t.rowStep
			return { el: s.ghost(row, box), points: [at(0, "none"), at(start, "none"), at(start + t.rowTravel, into, t.rowFade), at(start + t.rowGone, into, 0)] }
		})
		const from = s.place(mouldBox)
		const to = s.place(s.block())
		const press = {
			el: s.shell(mould, mouldBox),
			points: [
				at(0, "none", 1, from),
				at(t.press, "none", 1, from),
				at(t.pressDeep, `scale(${t.pressScale})`, 1, from),
				at(t.pressUp, "none", 1, from),
				at(t.unfold, "none", t.unfoldFade, to),
				at(t.unfoldGone, "none", 0, to),
			],
		}
		const label = name ? s.label(name, "ItemRow") : null
		const tag = label
			? [
					{
						el: label,
						points: [
							at(0, "none"),
							at(t.pressUp, "none"),
							at(t.labelLand, onto(name!.getBoundingClientRect(), s.text(head, "ItemRow"), s.codeScale(name!))),
							at(t.labelGone, onto(name!.getBoundingClientRect(), s.text(head, "ItemRow"), s.codeScale(name!)), 0),
						],
					},
				]
			: []
		return { tracks: [...rows, press, ...tag], lineAt: (i) => t.linesFrom + i * t.lineStep }
	},

	styling(s) {
		const t = STYLING
		const frame = s.piece(".rv-spec-frame")
		const head = s.line('h("Frame"')
		const padding = s.line("padding")
		const radius = s.line("cornerRadius")
		if (!frame || head < 0) return null
		const frameBox = frame.getBoundingClientRect()
		const from = s.place(frameBox)
		const to = { ...s.place(s.text(head)), borderRadius: t.frameRadius }
		const box = {
			el: s.shell(frame, frameBox),
			points: [at(0, "none", 1, from), at(t.frameHold, "none", 1, from), at(t.frameLand, "none", 1, to), at(t.frameGone, "none", 0, to)],
		}
		const value = (selector: string) => {
			const tick = s.piece(`${selector} .rv-tick`)
			return tick ? shownTick(tick) : (s.piece(selector)?.textContent?.match(/\d+/)?.[0] ?? "")
		}
		const labels = (
			[
				[".rv-spec-pad-top em", padding],
				[".rv-spec-pad-left em", padding],
				[".rv-spec-radius em", radius],
			] as const
		)
			.map(([selector, line]) => ({ source: s.piece(selector), line, text: value(selector) }))
			.filter(({ source, line, text }) => source && line >= 0 && text)
			.map(({ source, line, text }, i) => {
				const label = s.label(source!, text)
				const land = onto(source!.getBoundingClientRect(), s.text(line, text), s.codeScale(source!))
				const start = i * t.labelStep
				return {
					el: label,
					points: [at(0, "none"), at(start, "none"), at(start + t.labelLift, `translate(0, ${t.liftY}px)`), at(start + t.labelLand, land), at(start + t.labelGone, land, 0)],
				}
			})
		const width = s.piece(".rv-spec-width")
		const drop = width
			? [{ el: s.ghost(width), points: [at(0, "none"), at(t.widthRise, `translate(0, ${t.widthRiseY}px)`), at(t.widthDrop, `translate(0, ${t.widthDropY}px)`, 0)] }]
			: []
		const lineAt = (i: number) =>
			({ [head]: t.headLine, [padding]: t.paddingLine, [radius]: t.radiusLine })[i] ??
			(s.lines[i].textContent?.includes("layout") ? t.layoutLine : t.otherLines)
		return { tracks: [box, ...labels, ...drop], lineAt }
	},

	animation(s) {
		const t = ANIMATION
		const onion = s.piece(".rv-onion")
		const end = s.piece(".rv-onion-frame.is-end")
		const curve = s.piece(".rv-onion-path")
		const tween = s.line("TweenInfo")
		if (!onion || !end || !curve || tween < 0) return null
		const rail = s.shell(onion)
		Object.assign(rail.style, { border: "0", background: "none" })
		const rider = withLook(end)
		rail.append(rider)
		const ride = {
			el: rider,
			points: [
				[0, { offsetDistance: "0%", opacity: 1, easing: OUT }],
				[t.ride, { offsetDistance: "100%", opacity: 1 }],
				[t.ride + 1, { offsetDistance: "100%", opacity: 0 }],
			] as Point[],
		}
		const wipe = {
			el: s.ghost(curve),
			points: [
				[0, { clipPath: "inset(0 0 0 0)", opacity: 1, easing: OUT }],
				[t.ride, { clipPath: "inset(0 0 0 100%)", opacity: 1 }],
			] as Point[],
		}
		const stops = s.pieces(".rv-onion-frame:not(.is-end):not(.rv-onion-live)").map((frame, i, all) => {
			const passed = t.ride * Math.pow((i + 1) / (all.length + 1), t.passCurve)
			return { el: s.ghost(frame), points: [at(0, "none"), at(passed, "none"), at(passed + t.collect, `scale(${t.collectScale})`, 0)] }
		})
		const endBox = end.getBoundingClientRect()
		const highlight = { ...s.place(s.lines[tween].getBoundingClientRect()), borderRadius: t.lineRadius }
		const outline = s.shell(end, endBox)
		Object.assign(outline.style, { background: "none" })
		const settle = {
			el: outline,
			points: [
				at(0, "none", 0, s.place(endBox)),
				at(t.ride, "none", 0, s.place(endBox)),
				at(t.ride + 1, "none", 1, s.place(endBox)),
				at(t.settle, "none", 1, highlight),
				at(t.settleGone, "none", 0, highlight),
			],
		}
		const ease = s.piece(".rv-ease")
		const graph = ease ? [{ el: s.ghost(ease), points: [at(0, "none"), at(t.easeGone, `translate(0, ${t.easeDropY}px)`, 0)] }] : []
		const last = Math.max(1, s.lines.length - 1)
		const lineAt = (i: number) => (i === tween ? t.focusLine : t.linesFrom + t.linesSpan * (1 - Math.cbrt(1 - i / last)))
		return { tracks: [...stops, wipe, ride, settle, ...graph], lineAt }
	},

	lists(s, opening) {
		const t = LISTS
		const view = s.piece(".rv-list-window")?.getBoundingClientRect()
		if (!view) return null
		const rows = s
			.pieces(".rv-list-live i")
			.filter((row) => {
				const box = row.getBoundingClientRect()
				return box.bottom > view.top && box.top < view.bottom
			})
			.slice(0, t.maxRows)
		if (!rows.length) return null
		const visits = rows.map((_, r) => s.lines.map((__, k) => k).filter((k) => k % rows.length === r && (opening || k < rows.length)))
		const arrival = (r: number, visit: number) => r * t.rowStep + t.travel + visit * t.cycle
		const bar = (k: number) => {
			const words = s.text(k)
			const height = words.height * t.barHeight
			return s.place(new DOMRect(words.left, words.top + (words.height - height) * HALF, words.width, height))
		}
		const tracks = rows.map((row, r) => {
			const box = row.getBoundingClientRect()
			const ghost = s.ghost(row, box)
			;[...ghost.children].forEach((child) => Object.assign((child as HTMLElement).style, { width: "100%" }))
			const points = visits[r].flatMap((k, visit): Point[] => {
				const land = arrival(r, visit)
				const below = { ...bar(k), transform: `translate(0, ${t.belowY}px)` }
				const enter: Point[] = visit === 0 ? [at(r * t.rowStep, "none", 1, s.place(box))] : [[land - t.travel + t.reenter, { opacity: 0, ...below }]]
				return [...enter, at(land, "none", 1, bar(k)), at(land + t.gone - t.travel, "none", 0, bar(k))]
			})
			return { el: ghost, points: [at(0, "none", 1, s.place(box)), ...points] }
		})
		const lineAt = (k: number) => (opening || k < rows.length ? arrival(k % rows.length, Math.floor(k / rows.length)) - t.lineLead : 0)
		return { tracks, lineAt }
	},

	typed(s) {
		const t = TYPED
		const editor = s.piece(".rv-editor")
		const local = s.line("local hp")
		const assign = s.line("hp.value")
		if (!editor || local < 0 || assign < 0) return null
		const editorBox = editor.getBoundingClientRect()
		const from = s.place(editorBox)
		const to = s.place(s.block())
		const frame = { el: s.shell(editor, editorBox), points: [at(0, "none", 1, from), at(t.hold, "none", 1, from), at(t.grow, "none", 1, to), at(t.growGone, "none", 0, to)] }
		const code = s.pieces(".rv-code-line").map((el, i) => {
			const box = el.getBoundingClientRect()
			const land = onto(box, s.lines[i === 0 ? local : assign].getBoundingClientRect(), s.codeScale(el))
			return { el: s.ghost(el, box), points: [at(0, "none"), at(t.hold, "none"), at(t.grow, land), at(t.linesGone, land, 0)] }
		})
		code.forEach(({ el }) => Object.assign(el.style, { transformOrigin: "0 50%" }))
		const error = s.piece(".rv-error")
		const tip = error ? [{ el: s.ghost(error), points: [at(0, "none"), at(t.errorGone, `translate(0, ${t.errorDropY}px)`, 0)] }] : []
		const lineAt = (i: number) => (i === local || i === assign ? t.codeLines : t.newFrom + i * t.newStep)
		return { tracks: [frame, ...code, ...tip], lineAt }
	},
}

const layers = new WeakMap<HTMLElement, HTMLElement>()

export async function morph(stage: HTMLElement, kind: Scene, opening: boolean) {
	layers.get(stage)?.remove()
	const art = stage.querySelector<HTMLElement>(".rv-art")
	if (!art || matchMedia("(prefers-reduced-motion: reduce)").matches) return
	const s = new Stage(stage, art)
	const plan = CHOREOGRAPHY[kind](s, opening)
	if (!plan) return
	stage.append(s.layer)
	layers.set(stage, s.layer)

	s.lines.forEach((line, i) => line.style.setProperty("--rv-in", `${Math.round(plan.lineAt(i))}ms`))
	const spans = plan.tracks.map(({ points }) => [points[0][0], points[points.length - 1][0]] as const)
	const total = Math.max(...spans.map(([, end]) => end))
	stage.style.setProperty("--rv-back", `${Math.max(0, total - ART_RETURN_LEAD)}ms`)

	const runs = plan.tracks.map(({ el, points }, i) => {
		const [start, end] = spans[i]
		const span = Math.max(1, end - start)
		const frames = points.map(([ms, frame]) => ({ easing: EASE, ...frame, offset: (ms - start) / span }))
		return el.animate(frames, {
			duration: span,
			delay: opening ? start : total - end,
			direction: opening ? "normal" : "reverse",
			fill: "both",
		}).finished
	})
	try {
		await Promise.all(runs)
		s.layer.remove()
	} catch {
		return
	}
}
