// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

const banners = import.meta.glob<string>("../../assets/blog/*.webp", { eager: true, import: "default" })

export const BANNER_SIZE = { width: 3200, height: 1680 }

const asset = (file: string) => banners[`../../assets/blog/${file}`]

export function bannerImage(file: string | undefined, dark = false) {
	if (!file) return undefined
	const name = dark ? file.replace(/\.webp$/, "-dark.webp") : file
	const src = asset(name)
	if (!src) return undefined
	const small = asset(name.replace(/\.webp$/, "-1600.webp"))
	return { src, srcset: small ? `${small} 1600w, ${src} ${BANNER_SIZE.width}w` : undefined }
}

export const formatDate = (date: string, month: "long" | "short" = "long") =>
	new Date(`${date}T00:00:00Z`).toLocaleDateString("en-GB", { day: "numeric", month, year: "numeric", timeZone: "UTC" })
