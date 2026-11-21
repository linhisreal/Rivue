import { readStorage, writeStorage } from "./storage"

let popup: HTMLDivElement | undefined
let hoveredType: Element | undefined

function showType(target: Element) {
	const id = target.getAttribute("data-type")
	const source = target.closest("div[class*='language-']")?.querySelector(`.fd-type-pops > [data-pop="${id}"]`)
	if (!source) return
	popup ??= Object.assign(document.createElement("div"), { className: "fd-type-float", role: "tooltip" })
	if (!popup.isConnected) document.body.append(popup)
	popup.innerHTML = source.innerHTML
	popup.hidden = false
	hoveredType = target
	const anchor = target.getBoundingClientRect()
	const box = popup.getBoundingClientRect()
	const left = Math.min(Math.max(8, anchor.left), window.innerWidth - box.width - 8)
	const below = anchor.bottom + 6
	const top = below + box.height > window.innerHeight - 8 ? anchor.top - box.height - 6 : below
	popup.style.translate = `${Math.round(left)}px ${Math.round(top)}px`
}

function hideType() {
	if (popup) popup.hidden = true
	hoveredType = undefined
}

export function onTypeHover(event: MouseEvent) {
	const target = (event.target as Element | null)?.closest?.(".fd-type")
	if (target === hoveredType) return
	if (target) showType(target)
	else hideType()
}

let zoom: HTMLDialogElement | undefined

export function onImageClick(event: MouseEvent) {
	const target = event.target as Element | null
	const image = target?.closest?.<HTMLImageElement>(".vp-doc img")
	const diagram = target?.closest?.(".vp-doc .mermaid")?.querySelector("svg")
	const plainImage = image && !image.closest("a") ? image : undefined
	if (!plainImage && !diagram) return
	if (!zoom) {
		zoom = document.createElement("dialog")
		zoom.className = "fd-zoom"
		zoom.addEventListener("click", () => zoom?.close())
		document.body.append(zoom)
	}
	zoom.innerHTML = `<button type="button" class="fd-zoom-close" aria-label="Close">
		<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" /></svg></button>`
	if (plainImage) {
		const big = document.createElement("img")
		big.src = plainImage.currentSrc || plainImage.src
		big.alt = plainImage.alt
		zoom.append(big)
	} else if (diagram) {
		const copy = diagram.cloneNode(true) as SVGSVGElement
		copy.classList.add("fd-zoom-figure")
		copy.removeAttribute("style")
		copy.setAttribute("role", "img")
		zoom.append(copy)
	}
	zoom.showModal()
}

export function animateSearchClose() {
	const observer = new MutationObserver((records) => {
		if (matchMedia("(prefers-reduced-motion: reduce)").matches) return
		for (const record of records)
			for (const node of record.removedNodes) {
				if (!(node instanceof HTMLElement) || !node.matches(".VPLocalSearchBox:not(.fd-closing)")) continue
				const ghost = node.cloneNode(true) as HTMLElement
				const query = node.querySelector("input")?.value
				const ghostInput = ghost.querySelector("input")
				if (ghostInput && query) ghostInput.value = query
				ghost.classList.add("fd-closing")
				ghost.setAttribute("aria-hidden", "true")
				ghost.inert = true
				document.body.append(ghost)
				const remove = () => ghost.remove()
				ghost.querySelector(".shell")?.addEventListener("animationend", remove, { once: true })
				setTimeout(remove, 300)
			}
	})
	observer.observe(document.body, { childList: true })
}

export function fadeInPage() {
	if (matchMedia("(prefers-reduced-motion: reduce)").matches) return
	document
		.querySelector(".VPContent")
		?.animate([{ opacity: 0, translate: "0 6px" }, { opacity: 1, translate: "0 0" }], { duration: 180, easing: "ease-out" })
}

const READ_KEY = "rivue-read-chapters"

function readChapters(): string[] {
	try {
		const saved: unknown = JSON.parse(readStorage(READ_KEY) ?? "[]")
		return Array.isArray(saved) ? saved.filter((item): item is string => typeof item === "string") : []
	} catch {
		return []
	}
}

export function trackChapters() {
	const read = readChapters()
	const chapter = /\/guide\/(\d\d-[\w-]+)/.exec(location.pathname)?.[1]
	if (chapter && !read.includes(chapter)) {
		read.push(chapter)
		writeStorage(READ_KEY, JSON.stringify(read))
	}
	for (const card of document.querySelectorAll<HTMLElement>(".fd-chapter-card[data-chapter]"))
		card.classList.toggle("is-read", read.includes(card.dataset.chapter ?? ""))
}

function patchSidebarGroups(root: ParentNode) {
	for (const item of root.querySelectorAll<HTMLElement>(".VPSidebarItem.collapsible > .item")) {
		const group = item.parentElement
		if (!group) continue
		const expanded = String(!group.classList.contains("collapsed"))
		const caret = item.querySelector<HTMLElement>(":scope > .caret")
		if (item.getAttribute("role") === "button") {
			caret?.removeAttribute("role")
			caret?.removeAttribute("tabindex")
			caret?.removeAttribute("aria-label")
			caret?.setAttribute("aria-hidden", "true")
			item.setAttribute("aria-expanded", expanded)
			if (!("space" in item.dataset)) {
				item.dataset.space = ""
				item.addEventListener("keydown", (event) => {
					if (event.key !== " ") return
					event.preventDefault()
					item.click()
				})
			}
		} else {
			item.removeAttribute("tabindex")
			caret?.setAttribute("aria-expanded", expanded)
		}
	}
}

export function fixSidebarGroups() {
	const sidebar = document.querySelector<HTMLElement>(".VPSidebar")
	if (!sidebar) return
	patchSidebarGroups(sidebar)
	if ("patched" in sidebar.dataset) return
	sidebar.dataset.patched = ""
	new MutationObserver(() => patchSidebarGroups(sidebar)).observe(sidebar, {
		subtree: true,
		childList: true,
		attributeFilter: ["class"],
	})
}

const DETAILED = "vitepress:local-search-detailed-list"

export function onSearchToggleClick(event: MouseEvent) {
	const button = (event.target as Element | null)?.closest?.(".VPLocalSearchBox .toggle-layout-button")
	if (!button || document.querySelector(".VPLocalSearchBox .result")) return
	const value = String(readStorage(DETAILED) !== "true")
	writeStorage(DETAILED, value)
	try {
		window.dispatchEvent(new StorageEvent("storage", { key: DETAILED, newValue: value, storageArea: localStorage }))
	} catch {}
}

const SCROLL_PADDING = 24
const STOP_ON = ["wheel", "touchstart", "keydown", "mousedown"]

export function holdHashTarget() {
	const id = decodeURIComponent(location.hash.slice(1))
	const target = id && document.getElementById(id)
	const doc = document.querySelector(".VPDoc")
	if (!target || !doc) return
	const place = () => {
		const bar = Math.max(0, document.querySelector(".VPLocalNav")?.getBoundingClientRect().bottom ?? 0)
		window.scrollTo({ top: target.getBoundingClientRect().top + window.scrollY - bar - SCROLL_PADDING })
	}
	const observer = new ResizeObserver(place)
	const stop = () => {
		observer.disconnect()
		for (const name of STOP_ON) window.removeEventListener(name, stop)
	}
	for (const name of STOP_ON) window.addEventListener(name, stop, { passive: true })
	observer.observe(doc)
	setTimeout(stop, 3000)
}

const copiedTimers = new WeakMap<Element, ReturnType<typeof setTimeout>>()

export function onHeadingAnchorClick(event: MouseEvent) {
	const anchor = (event.target as Element | null)?.closest?.<HTMLAnchorElement>(".vp-doc .header-anchor")
	if (!anchor) return
	navigator.clipboard?.writeText(anchor.href).then(
		() => {
			anchor.setAttribute("data-copied", "")
			clearTimeout(copiedTimers.get(anchor))
			copiedTimers.set(anchor, setTimeout(() => anchor.removeAttribute("data-copied"), 1500))
		},
		() => {},
	)
}

const TAB_KEY = "rivue-code-tab"

function selectTab(group: Element, index: number) {
	group.querySelectorAll(".fd-tab-list button").forEach((button, i) => button.setAttribute("aria-selected", String(i === index)))
	group.querySelectorAll(".fd-tab-panel").forEach((panel, i) => panel.classList.toggle("active", i === index))
}

function selectLabel(label: string, except?: Element) {
	for (const group of document.querySelectorAll(".fd-tabs")) {
		if (group === except) continue
		const buttons = [...group.querySelectorAll(".fd-tab-list button")]
		const index = buttons.findIndex((button) => button.textContent?.trim() === label)
		if (index !== -1) selectTab(group, index)
	}
}

export function onCodeTabClick(event: MouseEvent) {
	const tab = (event.target as Element | null)?.closest?.<HTMLButtonElement>(".fd-tab-list button")
	const group = tab?.closest(".fd-tabs")
	if (!tab || !group) return
	const label = tab.textContent?.trim() ?? ""
	const top = tab.getBoundingClientRect().top
	selectTab(group, [...group.querySelectorAll(".fd-tab-list button")].indexOf(tab))
	selectLabel(label, group)
	window.scrollBy(0, tab.getBoundingClientRect().top - top)
	writeStorage(TAB_KEY, label)
}

export function applySavedTab() {
	const label = readStorage(TAB_KEY)
	if (label) selectLabel(label)
}
