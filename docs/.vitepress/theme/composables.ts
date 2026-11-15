import { onMounted, onUnmounted, ref, type Ref } from "vue"

export function useDismiss(root: Ref<HTMLElement | undefined>, open: Ref<boolean>) {
	function onClick(event: MouseEvent) {
		if (root.value && !root.value.contains(event.target as Node)) open.value = false
	}
	function onKeydown(event: KeyboardEvent) {
		if (event.key !== "Escape" || !open.value) return
		open.value = false
		if (root.value?.contains(document.activeElement)) root.value.querySelector("button")?.focus()
	}
	onMounted(() => {
		document.addEventListener("click", onClick)
		document.addEventListener("keydown", onKeydown)
	})
	onUnmounted(() => {
		document.removeEventListener("click", onClick)
		document.removeEventListener("keydown", onKeydown)
	})
}

export function openSearch() {
	document.querySelector<HTMLButtonElement>(".VPNavBarSearch .DocSearch-Button")?.click()
}

const KEY = "rivue-sidebar-collapsed"
export const sidebarCollapsed = ref(false)

export function setSidebarCollapsed(value: boolean) {
	sidebarCollapsed.value = value
	document.documentElement.classList.toggle("fd-collapsed", value)
	document.documentElement.classList.remove("fd-peek")
	try {
		localStorage.setItem(KEY, value ? "1" : "0")
	} catch {}
}

export function restoreSidebar() {
	let value = false
	try {
		value = localStorage.getItem(KEY) === "1"
	} catch {}
	setSidebarCollapsed(value)
}

const DETAILED = "vitepress:local-search-detailed-list"

// VitePress ignores the layout toggle until a search has results, so flip the stored value ourselves.
export function onSearchToggleClick(event: MouseEvent) {
	const button = (event.target as Element | null)?.closest?.(".VPLocalSearchBox .toggle-layout-button")
	if (!button || document.querySelector(".VPLocalSearchBox .result")) return
	try {
		const value = String(localStorage.getItem(DETAILED) !== "true")
		localStorage.setItem(DETAILED, value)
		window.dispatchEvent(new StorageEvent("storage", { key: DETAILED, newValue: value, storageArea: localStorage }))
	} catch {}
}

const SCROLL_PADDING = 24
const STOP_ON = ["wheel", "touchstart", "keydown", "mousedown"]

// Diagrams render after the page opens and push headings down, so hold a #heading in place until they settle.
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
			copiedTimers.set(
				anchor,
				setTimeout(() => anchor.removeAttribute("data-copied"), 1500),
			)
		},
		() => {},
	)
}

export function onCodeTabClick(event: MouseEvent) {
	const tab = (event.target as Element | null)?.closest?.<HTMLButtonElement>(".fd-tab-list button")
	const group = tab?.closest(".fd-tabs")
	if (!tab || !group) return
	const tabs = [...group.querySelectorAll<HTMLButtonElement>(".fd-tab-list button")]
	const panels = [...group.querySelectorAll(".fd-tab-panel")]
	const index = tabs.indexOf(tab)
	tabs.forEach((button, i) => button.setAttribute("aria-selected", String(i === index)))
	panels.forEach((panel, i) => panel.classList.toggle("active", i === index))
}
