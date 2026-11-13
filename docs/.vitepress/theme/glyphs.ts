// Copyright (c) 2025-2026 linhisreal (ThisisLinh)
// Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

export const COLS = 15
export const ROWS = 8
export const GLYPH_START = 5
export const DIGITS = [3, 4, 5] as const
export type Digit = (typeof DIGITS)[number]

export const GLYPHS: Record<Digit, string[]> = {
	3: ["01110", "10001", "00001", "00110", "00001", "10001", "01110"],
	4: ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	5: ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
}

export const pixels = Array.from({ length: COLS * ROWS }, (_, i) =>
	DIGITS.map((digit) => GLYPHS[digit][Math.floor(i / COLS)]?.[(i % COLS) - GLYPH_START] ?? "0").join(""),
)

export const nextDigit = (digit: Digit) => DIGITS[(DIGITS.indexOf(digit) + 1) % DIGITS.length]

export const writesFrom = (digit: Digit) => {
	const from = DIGITS.indexOf(digit)
	const to = DIGITS.indexOf(nextDigit(digit))
	return pixels.filter((p) => p[from] !== p[to]).length
}
