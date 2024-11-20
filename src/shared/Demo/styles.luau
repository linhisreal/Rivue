--!strict

local styles = {
	window = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 480),
		BackgroundColor3 = Color3.fromRGB(35, 35, 45),
		cornerRadius = 10,
		padding = 12,
		stroke = Color3.fromRGB(100, 150, 255),
	},
	card = {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(50, 50, 60),
		cornerRadius = 8,
		padding = 10,
	},
	title = {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(220, 220, 255),
		TextSize = 20,
		Font = Enum.Font.GothamBold,
	},
	text = {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(230, 230, 245),
		TextSize = 15,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	},
	input = {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(28, 28, 36),
		TextColor3 = Color3.fromRGB(240, 240, 255),
		PlaceholderColor3 = Color3.fromRGB(130, 130, 150),
		TextSize = 15,
		Font = Enum.Font.Gotham,
		ClearTextOnFocus = false,
		cornerRadius = 6,
		padding = { x = 8 },
	},
	button = {
		Size = UDim2.fromOffset(110, 34),
		BackgroundColor3 = Color3.fromRGB(70, 110, 220),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		cornerRadius = 6,
	},
	danger = {
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
	},
}

return styles
