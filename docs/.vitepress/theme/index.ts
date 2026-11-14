import { h } from "vue"
import DefaultTheme from "vitepress/theme"
import Landing from "./Landing.vue"
import SidebarBottom from "./SidebarBottom.vue"
import SidebarTop from "./SidebarTop.vue"
import "./custom.css"

export default {
	extends: DefaultTheme,
	Layout: () =>
		h(DefaultTheme.Layout, null, {
			"home-hero-before": () => h(Landing),
			"sidebar-nav-before": () => h(SidebarTop),
			"sidebar-nav-after": () => h(SidebarBottom),
		}),
}
