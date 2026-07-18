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

// VitePress unmounts the search box straight away, so play its exit on a copy that's left behind
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
