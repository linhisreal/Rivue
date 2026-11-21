// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

import { onMounted, onUnmounted, ref, type Ref } from "vue"
import { readStorage, writeStorage } from "./storage"

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

export function useFlash(duration = 2000) {
	const message = ref("")
	let timer: ReturnType<typeof setTimeout> | undefined
	function flash(text: string) {
		clearTimeout(timer)
		message.value = text
		timer = setTimeout(() => (message.value = ""), duration)
	}
	onUnmounted(() => clearTimeout(timer))
	return { message, flash }
}

export function openSearch() {
	document.querySelector<HTMLButtonElement>(".VPNavBarSearch .DocSearch-Button")?.click()
}

const SIDEBAR_KEY = "rivue-sidebar-collapsed"
export const sidebarCollapsed = ref(false)

export function setSidebarCollapsed(value: boolean) {
	sidebarCollapsed.value = value
	document.documentElement.classList.toggle("fd-collapsed", value)
	document.documentElement.classList.remove("fd-peek")
	writeStorage(SIDEBAR_KEY, value ? "1" : "0")
}

export function restoreSidebar() {
	setSidebarCollapsed(readStorage(SIDEBAR_KEY) === "1")
}
