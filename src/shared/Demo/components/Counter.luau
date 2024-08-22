--!nonstrict
-- A counter with a derived value

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

return Rivue.defineComponent({
	name = "Counter",

	setup = function()
		local count = Rivue.ref(0)
		local doubled = Rivue.computed(function()
			return count.value * 2
		end)

		return {
			count = count,
			doubled = doubled,
			increment = function()
				count.value += 1
			end,
			decrement = function()
				count.value -= 1
			end,
		}
	end,

	render = function(ctx)
		return h("Frame", { class = "card", layout = { gap = 8 } }, {
			h("TextLabel", { class = "title", Text = "Counter" }),
			h("TextLabel", { class = "text", Text = `Count: {ctx.count}  |  Double: {ctx.doubled}` }),
			h("Frame", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
				layout = { direction = "horizontal", gap = 8 },
			}, {
				h("TextButton", { class = { "button", "danger" }, Text = "- Decrement", onClick = ctx.decrement }),
				h("TextButton", { class = "button", Text = "+ Increment", onClick = ctx.increment }),
			}),
		})
	end,
})
