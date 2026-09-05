import { useData } from "vitepress"
import type { DefaultTheme } from "vitepress/theme"
import type { Post } from "../blog.mts"
import type { landingData } from "../landing.mts"

export type Landing = ReturnType<typeof landingData>
export type Repo = { name: string; url: string; stars?: number; forks?: number; tag?: string }
export type Scene = "reactivity" | "components" | "styling" | "animation" | "lists" | "typed"

export interface ThemeConfig extends DefaultTheme.Config {
	version: string
	repo: Repo
	landing: Landing
	blog: Post[]
}

export const useTheme = () => useData<ThemeConfig>()
