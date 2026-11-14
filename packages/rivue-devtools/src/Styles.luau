--!nonstrict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local Theme = require(script.Parent:WaitForChild("Theme"))

local KEY_WIDTH = 104
local MS_WIDTH = 64
local COUNT_WIDTH = 34
local ROWS = { comfortable = 24, compact = 20 }

local function build(p: Theme.Palette, ROW: number): { [string]: any }
	local function label(size: number, color: Color3, mono: boolean?): { [string]: any }
		return {
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			TextSize = size,
			Font = if mono then Enum.Font.Code else Enum.Font.SourceSans,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}
	end
	local cell = function(width: number, align: Enum.TextXAlignment?, mono: boolean?)
		local style = label(13, p.text, mono)
		style.Size = UDim2.new(0, width, 1, 0)
		style.TextXAlignment = align or Enum.TextXAlignment.Left
		return style
	end
	local fill = function(mono: boolean?)
		local style = label(13, p.text, mono)
		style.Size = UDim2.fromScale(0, 1)
		style.flex = "fill"
		return style
	end
	local auto = function(mono: boolean?)
		local style = label(13, p.text, mono)
		style.Size = UDim2.fromScale(0, 1)
		style.AutomaticSize = Enum.AutomaticSize.X
		return style
	end
	local button = {
		Size = UDim2.new(0, 0, 0, ROW),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = p.button,
		BorderSizePixel = 0,
		TextColor3 = p.text,
		TextSize = 13,
		Font = Enum.Font.SourceSans,
		AutoButtonColor = false,
		padding = { x = 10 },
		cornerRadius = 4,
		hover = { BackgroundColor3 = p.buttonHover },
	}
	return {
		panel = {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = p.background,
			BorderSizePixel = 0,
			padding = 8,
		},
		tabBar = {
			Size = UDim2.new(1, 0, 0, ROW + 4),
			BackgroundColor3 = p.input,
			BorderSizePixel = 0,
			cornerRadius = 6,
			padding = 2,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
		},
		tab = {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BackgroundColor3 = p.accent,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			cornerRadius = 4,
			padding = { x = 10 },
			layout = { direction = "horizontal", gap = 6, align = "center" },
			hover = { BackgroundTransparency = 0.85 },
		},
		activeTab = { BackgroundTransparency = 0, hover = { BackgroundTransparency = 0 } },
		tabLabel = auto(),
		tabCount = (function()
			local style = auto(true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			return style
		end)(),
		activeTabText = { TextColor3 = p.accentText },
		pill = {
			Size = UDim2.fromOffset(COUNT_WIDTH, 18),
			BackgroundColor3 = p.pill,
			BorderSizePixel = 0,
			TextColor3 = p.dimText,
			Font = Enum.Font.Code,
			TextSize = 12,
			cornerRadius = 9,
		},
		hotPill = { BackgroundColor3 = p.changed, TextColor3 = p.accentText },
		toolbar = { Size = UDim2.new(1, 0, 0, ROW), BackgroundTransparency = 1 },
		tool = button,
		activeTool = { BackgroundColor3 = p.accent, TextColor3 = p.accentText, hover = { BackgroundColor3 = p.accent } },
		filter = {
			Size = UDim2.new(0, 0, 0, ROW),
			BackgroundColor3 = p.input,
			BorderSizePixel = 0,
			TextColor3 = p.text,
			PlaceholderColor3 = p.dimText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 13,
			Font = Enum.Font.SourceSans,
			ClearTextOnFocus = false,
			padding = { x = 8 },
			cornerRadius = 4,
			flex = "fill",
		},
		list = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = p.dimText,
			layout = { gap = 2 },
			padding = { right = 6 },
		},
		row = {
			Size = UDim2.new(1, 0, 0, ROW),
			BackgroundColor3 = p.rowHover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			cornerRadius = 4,
			padding = { x = 6 },
			layout = { direction = "horizontal", gap = 6, align = "center" },
			hover = { BackgroundTransparency = 0 },
		},
		selectedRow = {
			BackgroundColor3 = p.accent,
			BackgroundTransparency = 0.7,
			hover = { BackgroundTransparency = 0.6 },
		},
		toggle = {
			Size = UDim2.new(0, 12, 1, 0),
			BackgroundTransparency = 1,
			TextColor3 = p.dimText,
			TextSize = 10,
		},
		dot = { Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0, BackgroundColor3 = p.changed, cornerRadius = 3 },
		vlist = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = p.dimText,
		},
		icon = { BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(14, 14) },
		iconStroke = { BorderSizePixel = 0, BackgroundColor3 = p.dimText, AnchorPoint = Vector2.new(0.5, 0.5) },
		slowPill = {
			Size = UDim2.new(0, 0, 0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = p.slow,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			TextColor3 = p.slow,
			Font = Enum.Font.Code,
			TextSize = 12,
			cornerRadius = 9,
			padding = { x = 6 },
		},
		kindDot = { Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0, cornerRadius = 3, BackgroundColor3 = p.dimText },
		spark = {
			Size = UDim2.fromOffset(32, 14),
			BackgroundTransparency = 1,
			layout = { direction = "horizontal", gap = 1, align = "end" },
		},
		sparkBar = { BorderSizePixel = 0, BackgroundColor3 = p.dimText, Size = UDim2.new(0, 2, 0, 1) },
		hotSpark = { BackgroundColor3 = p.changed },
		crumbs = { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 },
		crumb = (function()
			local style = auto(true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			style.hover = { TextColor3 = p.text }
			return style
		end)(),
		menu = {
			Size = UDim2.fromOffset(170, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = p.card,
			BorderSizePixel = 0,
			cornerRadius = 6,
			padding = 4,
			layout = { gap = 2 },
			ZIndex = 20,
		},
		menuItem = {
			Size = UDim2.new(1, 0, 0, ROW),
			BackgroundColor3 = p.rowHover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextColor3 = p.text,
			TextSize = 13,
			Font = Enum.Font.SourceSans,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			cornerRadius = 4,
			padding = { x = 8 },
			ZIndex = 21,
			hover = { BackgroundTransparency = 0 },
		},
		overlay = {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 30,
		},
		searchPanel = {
			Size = UDim2.new(1, -24, 0, 0),
			Position = UDim2.fromOffset(12, 36),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = p.background,
			BorderSizePixel = 0,
			cornerRadius = 8,
			padding = 8,
			layout = { gap = 4 },
			ZIndex = 31,
		},
		emptyCard = {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = p.card,
			BorderSizePixel = 0,
			cornerRadius = 6,
			padding = 12,
			layout = { gap = 6 },
		},
		pin = {
			Size = UDim2.new(0, 16, 1, 0),
			BackgroundTransparency = 1,
			TextColor3 = p.dimText,
			TextSize = 12,
			Text = "☆",
		},
		pinned = { TextColor3 = p.changed, Text = "★" },
		warning = { TextColor3 = p.changed, BackgroundColor3 = p.changed },
		error = { TextColor3 = p.slow, BackgroundColor3 = p.slow },
		name = auto(true),
		changedName = {},
		slowName = {},
		ms = (function()
			local style = cell(MS_WIDTH, Enum.TextXAlignment.Right, true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			return style
		end)(),
		slowMs = { TextColor3 = p.slow },
		time = (function()
			local style = cell(52, Enum.TextXAlignment.Left, true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			return style
		end)(),
		kind = (function()
			local style = cell(72, Enum.TextXAlignment.Left, true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			return style
		end)(),
		label = auto(true),
		detail = (function()
			local style = fill(true)
			style.TextColor3 = p.dimText
			return style
		end)(),
		text = (function()
			local style = label(13, p.text)
			style.AutomaticSize = Enum.AutomaticSize.XY
			return style
		end)(),
		dim = { TextColor3 = p.dimText },
		strong = { Font = Enum.Font.SourceSansBold, TextSize = 15 },
		divider = {
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
		},
		dividerLine = {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 0.5, 0),
			BorderSizePixel = 0,
			BackgroundColor3 = p.border,
		},
		card = {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = p.card,
			BorderSizePixel = 0,
			cornerRadius = 6,
			padding = 8,
			layout = { gap = 2 },
		},
		cardTitle = {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			layout = { direction = "horizontal", gap = 6, align = "center" },
		},
		heading = (function()
			local style = auto()
			style.TextColor3 = p.dimText
			style.TextSize = 12
			style.Font = Enum.Font.SourceSansSemibold
			return style
		end)(),
		kv = {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			layout = { direction = "horizontal", gap = 8, align = "center" },
		},
		kvKey = (function()
			local style = cell(KEY_WIDTH, Enum.TextXAlignment.Left, true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			return style
		end)(),
		kvValue = (function()
			local style = fill(true)
			style.TextSize = 12
			return style
		end)(),
		field = {
			Size = UDim2.new(0, 0, 1, 0),
			flex = "fill",
			BackgroundColor3 = p.input,
			BorderSizePixel = 0,
			TextColor3 = p.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Code,
			TextSize = 12,
			ClearTextOnFocus = false,
			padding = { x = 6 },
			cornerRadius = 3,
		},
		chip = {
			Size = UDim2.new(0, 0, 0, ROW - 4),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = p.button,
			BorderSizePixel = 0,
			TextColor3 = p.dimText,
			TextSize = 12,
			Font = Enum.Font.SourceSans,
			AutoButtonColor = false,
			cornerRadius = 10,
			padding = { x = 10 },
		},
		bar = { Size = UDim2.fromOffset(40, 4), BackgroundColor3 = p.pill, BorderSizePixel = 0, cornerRadius = 2 },
		barFill = { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, cornerRadius = 2 },
		statusBar = { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 },
		statusText = (function()
			local style = auto()
			style.TextColor3 = p.dimText
			style.TextSize = 12
			return style
		end)(),
		smallTool = { Size = UDim2.new(0, 0, 0, 20), TextSize = 12, padding = { x = 8 } },
		render = { BackgroundColor3 = p.render },
		emit = { BackgroundColor3 = p.emit },
		navigation = { BackgroundColor3 = p.navigation },
		network = { BackgroundColor3 = p.request },
		request = { BackgroundColor3 = p.request },
		warning = { BackgroundColor3 = p.changed },
		error = { BackgroundColor3 = p.slow },
	}
end

local styles: { [string]: any } = {}
local built: { palette: Theme.Palette?, density: string? } = {}

local function rowHeight(density: string?): number
	return ROWS[density or "comfortable"] or ROWS.comfortable
end

--- Rebuilds the shared style table in place when the palette or density changed, so components
--- holding `styles` see the new values on their next render
local function sync(palette: Theme.Palette, density: string?)
	if built.palette == palette and built.density == density then
		return
	end
	built.palette, built.density = palette, density
	for name, style in build(palette, rowHeight(density)) do
		styles[name] = style
	end
end

sync(Theme.read(), "comfortable")

return {
	styles = styles,
	sync = sync,
	rowHeight = rowHeight,
	KEY_WIDTH = KEY_WIDTH,
	MS_WIDTH = MS_WIDTH,
	COUNT_WIDTH = COUNT_WIDTH,
}
