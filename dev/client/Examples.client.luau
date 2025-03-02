--!strict
-- Mounts the examples in one ScreenGui.
-- Opt in: set the attribute RivueExamples = true on Workspace before playing.

if not workspace:GetAttribute("RivueExamples") then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local Examples = ReplicatedStorage:WaitForChild("Examples")
local h = Rivue.h

local Counter = require(Examples:WaitForChild("Counter"))
local TodoList = require(Examples:WaitForChild("TodoList"))
local Inventory = require(Examples:WaitForChild("Inventory"))
local Tabs = require(Examples:WaitForChild("Tabs"))
local Hud = require(Examples:WaitForChild("Hud"))

local items = Rivue.reactive({})
for i = 1, 500 do
	items[i] = { id = i, name = `Item {i}`, count = i % 7 + 1 }
end

local App = Rivue.defineComponent(function()
	return function()
		return h("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, padding = 24 }, {
			h("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16) }),
			h(Counter),
			h(Tabs, { tabs = { "Todo", "Inventory" } }, {
				Todo = function()
					return h(TodoList)
				end,
				Inventory = function()
					return h(Inventory, { items = items })
				end,
			}),
			h(Hud),
		})
	end
end, { name = "ExamplesApp" })

Rivue.createApp(App):mountToPlayerGui(Players.LocalPlayer)
