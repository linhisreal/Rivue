let popup: HTMLDivElement | undefined
let current: Element | undefined

function showType(target: Element) {
	const id = target.getAttribute("data-type")
	const source = target.closest("div[class*='language-']")?.querySelector(`.fd-type-pops > [data-pop="${id}"]`)
	if (!source) return
	popup ??= Object.assign(document.createElement("div"), { className: "fd-type-float", role: "tooltip" })
	if (!popup.isConnected) document.body.append(popup)
	popup.innerHTML = source.innerHTML
	popup.hidden = false
	current = target
	const anchor = target.getBoundingClientRect()
	const box = popup.getBoundingClientRect()
	const left = Math.min(Math.max(8, anchor.left), window.innerWidth - box.width - 8)
	const below = anchor.bottom + 6
	const top = below + box.height > window.innerHeight - 8 ? anchor.top - box.height - 6 : below
	popup.style.translate = `${Math.round(left)}px ${Math.round(top)}px`
}

function hideType() {
	if (popup) popup.hidden = true
	current = undefined
}

export function onTypeHover(event: MouseEvent) {
	const target = (event.target as Element | null)?.closest?.(".fd-type")
	if (target === current) return
	if (target) showType(target)
	else hideType()
}

let zoom: HTMLDialogElement | undefined

export function onImageClick(event: MouseEvent) {
	const target = event.target as Element | null
	const image = target?.closest?.<HTMLImageElement>(".vp-doc img")
	const diagram = target?.closest?.(".vp-doc .mermaid")?.querySelector("svg")
	if ((!image || image.closest("a")) && !diagram) return
	if (!zoom) {
		zoom = document.createElement("dialog")
		zoom.className = "fd-zoom"
		zoom.addEventListener("click", () => zoom?.close())
		document.body.append(zoom)
	}
	zoom.innerHTML = `<button type="button" class="fd-zoom-close" aria-label="Close">
		<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" /></svg></button>`
	if (image && !image.closest("a")) {
		const big = document.createElement("img")
		big.src = image.currentSrc || image.src
		big.alt = image.alt
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

export function trackChapters() {
	let read: string[] = []
	try {
		read = JSON.parse(localStorage.getItem(READ_KEY) ?? "[]")
	} catch {}
	const current = /\/guide\/(\d\d-[\w-]+)/.exec(location.pathname)?.[1]
	if (current && !read.includes(current)) {
		read.push(current)
		try {
			localStorage.setItem(READ_KEY, JSON.stringify(read))
		} catch {}
	}
	for (const card of document.querySelectorAll<HTMLElement>(".fd-chapter-card[data-chapter]"))
		card.classList.toggle("is-read", read.includes(card.dataset.chapter ?? ""))
}

function patchSidebarGroups(root: ParentNode) {
	for (const item of root.querySelectorAll<HTMLElement>(".VPSidebarItem.collapsible > .item")) {
		const group = item.parentElement!
		const caret = item.querySelector<HTMLElement>(":scope > .caret")
		if (item.getAttribute("role") === "button") {
			caret?.removeAttribute("role")
			caret?.removeAttribute("tabindex")
			caret?.removeAttribute("aria-label")
			caret?.setAttribute("aria-hidden", "true")
			item.setAttribute("aria-expanded", String(!group.classList.contains("collapsed")))
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
			caret?.setAttribute("aria-expanded", String(!group.classList.contains("collapsed")))
		}
	}
}

export function fixSidebarGroups() {
	const sidebar = document.querySelector(".VPSidebar")
	if (!sidebar) return
	patchSidebarGroups(sidebar)
	if ("patched" in (sidebar as HTMLElement).dataset) return
	;(sidebar as HTMLElement).dataset.patched = ""
	new MutationObserver(() => patchSidebarGroups(sidebar)).observe(sidebar, {
		subtree: true,
		childList: true,
		attributeFilter: ["class"],
	})
}
