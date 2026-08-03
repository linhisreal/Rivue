--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

export type Palette = {
	background: Color3,
	input: Color3,
	text: Color3,
	dimText: Color3,
	button: Color3,
	buttonHover: Color3,
	rowHover: Color3,
	accent: Color3,
	accentText: Color3,
	border: Color3,
	changed: Color3,
	slow: Color3,
}

local DARK: Palette = {
	background = Color3.fromRGB(46, 46, 46),
	input = Color3.fromRGB(37, 37, 37),
	text = Color3.fromRGB(220, 220, 220),
	dimText = Color3.fromRGB(150, 150, 150),
	button = Color3.fromRGB(60, 60, 60),
	buttonHover = Color3.fromRGB(75, 75, 75),
	rowHover = Color3.fromRGB(66, 66, 66),
	accent = Color3.fromRGB(31, 111, 235),
	accentText = Color3.fromRGB(255, 255, 255),
	border = Color3.fromRGB(34, 34, 34),
	changed = Color3.fromRGB(255, 170, 60),
	slow = Color3.fromRGB(255, 95, 95),
}

local function studioTheme(): any
	local ok, theme = pcall(function()
		return (settings() :: any).Studio.Theme
	end)
	return if ok then theme else nil
end

local function read(): Palette
	local theme = studioTheme()
	if not theme then
		return DARK
	end
	local C = Enum.StudioStyleGuideColor
	local M = Enum.StudioStyleGuideModifier
	local background = theme:GetColor(C.MainBackground)
	local light = (background.R + background.G + background.B) / 3 > 0.5
	return {
		background = background,
		input = theme:GetColor(C.InputFieldBackground),
		text = theme:GetColor(C.MainText),
		dimText = theme:GetColor(C.DimmedText),
		button = theme:GetColor(C.Button),
		buttonHover = theme:GetColor(C.Button, M.Hover),
		rowHover = theme:GetColor(C.Item, M.Hover),
		accent = theme:GetColor(C.MainButton),
		accentText = theme:GetColor(C.BrightText),
		border = theme:GetColor(C.Border),
		changed = if light then Color3.fromRGB(188, 76, 0) else DARK.changed,
		slow = if light then Color3.fromRGB(207, 34, 46) else DARK.slow,
	}
end

local function watch(onChange: (Palette) -> ()): () -> ()
	local ok, conn = pcall(function()
		return (settings() :: any).Studio.ThemeChanged:Connect(function()
			onChange(read())
		end)
	end)
	return function()
		if ok and conn then
			conn:Disconnect()
		end
	end
end

return {
	read = read,
	watch = watch,
	DARK = DARK,
}
