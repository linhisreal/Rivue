--!nonstrict
-- One row of the item list

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

return Rivue.defineComponent({
	name = "ListItem",
	props = {
		name = { type = "string", required = true },
	},
	emits = { "remove" },

	render = function(ctx)
		return h("Frame", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			layout = { direction = "horizontal", gap = 6, align = "center" },
		}, {
			h("TextLabel", { class = "text", Text = `• {ctx.name}`, flex = "fill" }),
			h("TextButton", {
				class = { "button", "danger" },
				Size = UDim2.fromOffset(30, 26),
				Text = "x",
				onClick = function()
					ctx.emit("remove")
				end,
			}),
		})
	end,
})
