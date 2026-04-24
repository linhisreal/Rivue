import { h, nextTick } from "vue"
import DefaultTheme from "vitepress/theme"
import type { Theme } from "vitepress"
import DocBanner from "./DocBanner.vue"
import HomeFooter from "./HomeFooter.vue"
import Landing from "./Landing.vue"
import NotFound from "./NotFound.vue"
import OutlineTree from "./OutlineTree.vue"
import PageActions from "./PageActions.vue"
import RepoLink from "./RepoLink.vue"
import NavMenu from "./NavMenu.vue"
import SidebarOpen from "./SidebarOpen.vue"
import { applySavedTab, holdHashTarget, onCodeTabClick, onHeadingAnchorClick, onSearchToggleClick } from "./composables"
import { onImageClick, onTypeHover } from "./enhance"
import SidebarBottom from "./SidebarBottom.vue"
import SidebarTop from "./SidebarTop.vue"
import "./styles/tokens.css"
import "./styles/layout.css"
import "./styles/sidebar.css"
import "./styles/page.css"
import "./styles/outline.css"
import "./styles/diagrams.css"
import "./styles/search.css"
import "./styles/not-found.css"
import "./styles/landing.css"

export default {
	extends: DefaultTheme,
	enhanceApp({ app, router }) {
		app.component("PageActions", PageActions)
		if (typeof document === "undefined") return
		// mermaid sizes boxes with whatever font is loaded and redraws on <html> attribute changes, so poke it once Geist is in
		document.fonts.ready.then(() => document.documentElement.setAttribute("data-fonts", "ready"))
		document.addEventListener("click", onSearchToggleClick, true)
		document.addEventListener("click", onHeadingAnchorClick)
		document.addEventListener("click", onCodeTabClick)
		document.addEventListener("click", onImageClick)
		document.addEventListener("mouseover", onTypeHover)
		window.addEventListener("load", applySavedTab)
		window.addEventListener("load", holdHashTarget)
		window.addEventListener("hashchange", holdHashTarget)
		const afterRouteChange = router.onAfterRouteChange
		router.onAfterRouteChange = async (to) => {
			await afterRouteChange?.(to)
			await nextTick()
			applySavedTab()
			holdHashTarget()
		}
	},
	Layout: () =>
		h(DefaultTheme.Layout, null, {
			"home-hero-before": () => h(Landing),
			"not-found": () => h(NotFound),
			"nav-bar-content-after": () => [h(RepoLink), h(NavMenu)],
			"layout-bottom": () => h(HomeFooter),
			"layout-top": () => h(SidebarOpen),
			"sidebar-nav-before": () => h(SidebarTop),
			"sidebar-nav-after": () => h(SidebarBottom),
			"aside-outline-before": () => h(OutlineTree),
			"doc-before": () => h(DocBanner),
		}),
} satisfies Theme
