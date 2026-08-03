--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

-- A ref, a computed value and a click handler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local h = Rivue.h

return Rivue.defineComponent({
	name = "Counter",
	props = {
		start = { type = "number", default = 0 },
	},
	styles = {
		button = { Size = UDim2.fromOffset(220, 48), cornerRadius = 8, TextSize = 18 },
	},

	setup = function(props)
		local count = Rivue.ref(props.start)
		local doubled = Rivue.computed(function()
			return count.value * 2
		end)

		return {
			count = count,
			doubled = doubled,
			increment = function()
				count.value += 1
			end,
		}
	end,

	render = function(ctx)
		return h("TextButton", {
			class = "button",
			Text = `Clicked {ctx.count} times (x2 = {ctx.doubled})`,
			onClick = ctx.increment,
		})
	end,
})
