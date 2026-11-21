import { h, nextTick } from "vue"
import DefaultTheme from "vitepress/theme"
import type { Theme } from "vitepress"
import DocBanner from "./DocBanner.vue"
import HomeFooter from "./HomeFooter.vue"
import Landing from "./Landing.vue"
import NotFound from "./NotFound.vue"
import OutlineTree from "./OutlineTree.vue"
import PageActions from "./PageActions.vue"
import BlogLayout from "./BlogLayout.vue"
import RepoLink from "./RepoLink.vue"
import NavMenu from "./NavMenu.vue"
import SidebarOpen from "./SidebarOpen.vue"
import { applySavedTab, holdHashTarget, onCodeTabClick, onHeadingAnchorClick, onSearchToggleClick } from "./composables"
import { animateSearchClose, fadeInPage, fixSidebarGroups, onImageClick, onTypeHover, trackChapters } from "./enhance"
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
import "./styles/blog.css"

export default {
	extends: DefaultTheme,
	enhanceApp({ app, router }) {
		app.component("PageActions", PageActions)
		app.component("BlogLayout", BlogLayout)
		if (typeof document === "undefined") return
		document.fonts.ready.then(() => document.documentElement.setAttribute("data-fonts", "ready"))
		document.addEventListener("click", onSearchToggleClick, true)
		document.addEventListener("click", onHeadingAnchorClick)
		document.addEventListener("click", onCodeTabClick)
		document.addEventListener("click", onImageClick)
		document.addEventListener("mouseover", onTypeHover)
		window.addEventListener("load", applySavedTab)
		window.addEventListener("load", trackChapters)
		window.addEventListener("load", fixSidebarGroups)
		animateSearchClose()
		window.addEventListener("load", holdHashTarget)
		window.addEventListener("hashchange", holdHashTarget)
		const afterRouteChange = router.onAfterRouteChange
		let hydrated = false
		router.onAfterRouteChange = async (to) => {
			await afterRouteChange?.(to)
			await nextTick()
			if (hydrated) fadeInPage()
			hydrated = true
			trackChapters()
			fixSidebarGroups()
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
