// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

const banners = import.meta.glob<string>("../../assets/blog/*.webp", { eager: true, import: "default" })

export const bannerUrl = (file?: string) => (file ? banners[`../../assets/blog/${file}`] : undefined)

export const formatDate = (date: string) =>
	new Date(`${date}T00:00:00Z`).toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" })
