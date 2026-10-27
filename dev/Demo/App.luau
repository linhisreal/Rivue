--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
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
