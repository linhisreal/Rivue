// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

const banners = import.meta.glob<string>("../../assets/blog/*.webp", { eager: true, import: "default" })

export const bannerUrl = (file?: string, dark = false) =>
	file ? banners[`../../assets/blog/${dark ? file.replace(/\.webp$/, "-dark.webp") : file}`] : undefined

export const formatDate = (date: string, month: "long" | "short" = "long") =>
	new Date(`${date}T00:00:00Z`).toLocaleDateString("en-GB", { day: "numeric", month, year: "numeric", timeZone: "UTC" })
