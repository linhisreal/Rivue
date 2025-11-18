-- TestApp.luau - Simple test to verify Rivue is working

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))

local h = Rivue.h
local defineComponent = Rivue.defineComponent

-- Extremely simple test - just colored frames with text
local TestApp = defineComponent({
	name = "Testapp",
	setup = function()
		return function()
			return h("ScreenGui", { ResetOnSpawn = false }, {
				-- Red box
				h("Frame", {
					Size = UDim2.fromOffset(200, 200),
					Position = UDim2.fromOffset(100, 100),
					BackgroundColor3 = Color3.fromRGB(255, 0, 0),
					BorderSizePixel = 2,
					BorderColor3 = Color3.new(1, 1, 1),
				}, {
					h("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "HELLO WORLD",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 24,
						Font = Enum.Font.SourceSansBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}),
				-- Blue box
				h("Frame", {
					Size = UDim2.fromOffset(200, 200),
					Position = UDim2.fromOffset(350, 100),
					BackgroundColor3 = Color3.fromRGB(0, 0, 255),
					BorderSizePixel = 2,
					BorderColor3 = Color3.new(1, 1, 1),
				}, {
					h("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "TEST 123",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 24,
						Font = Enum.Font.SourceSansBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}),
			})
		end
	end,
})

return TestApp
