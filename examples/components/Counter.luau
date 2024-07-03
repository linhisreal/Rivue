--!nonstrict
-- The smallest useful component: local state, a computed value and a click handler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

return Rivue.defineComponent({
	name = "Counter",
	props = {
		start = { type = "number", default = 0 },
	},
	setup = function(props)
		-- setup() runs once. Anything reactive read in the render function below is tracked.
		local count = Rivue.ref(props.start)
		local doubled = Rivue.computed(function()
			return count.value * 2
		end)

		return function()
			return h("TextButton", {
				Size = UDim2.fromOffset(220, 48),
				Text = `Clicked {count.value} times (x2 = {doubled.value})`,
				cornerRadius = 8,
				onClick = function()
					count.value += 1
				end,
			})
		end
	end,
})
