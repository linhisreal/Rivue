--!nonstrict
-- The demo screen: lays out the components, holds no logic of its own

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

local Counter = require("./components/Counter")
local ItemList = require("./components/ItemList")

return Rivue.defineComponent({
	name = "DemoApp",
	components = { Counter = Counter, ItemList = ItemList },

	render = function()
		return h("Frame", { class = "window", layout = { gap = 12 }, vDrag = true }, {
			h(
				"TextLabel",
				{ class = "title", Text = "Rivue Demo (drag me)", TextXAlignment = Enum.TextXAlignment.Center }
			),
			h("Counter"),
			h("ItemList"),
		})
	end,
})
