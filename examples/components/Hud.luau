--!nonstrict
-- A HUD that adapts to the device and animates smoothly:
-- useInputType/useViewportSize for layout, useSpring for the health bar, attributeRef to read
-- game state the server writes as attributes on the player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

local panel = {
	BackgroundColor3 = Color3.fromRGB(20, 20, 20),
	BackgroundTransparency = 0.3,
	cornerRadius = 8,
}

return Rivue.defineComponent({
	name = "Hud",
	props = {
		player = { type = "Instance" },
		maxHealth = { type = "number", default = 100 },
	},
	setup = function(props)
		local player = (props.player or Players.LocalPlayer) :: Player
		-- Server code does player:SetAttribute("Health", value)
		local health = Rivue.attributeRef(player, "Health", 100)
		local input = Rivue.useInputType()
		local viewport = Rivue.useViewportSize()

		local ratio = Rivue.computed(function()
			return math.clamp((health.value or 0) / props.maxHealth, 0, 1)
		end)
		-- Springs toward the real value, so damage slides instead of jumping
		local shown = Rivue.useSpring(ratio, { speed = 10 })

		return function()
			local compact = input.value == "touch" or viewport.value.X < 700
			return h("Frame", {
				Name = "Health",
				style = panel,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, if compact then -90 else -24),
				Size = UDim2.fromOffset(if compact then 200 else 320, 20),
			}, {
				h("Frame", {
					Name = "Fill",
					Size = UDim2.fromScale(shown.value, 1),
					BackgroundColor3 = if ratio.value < 0.3
						then Color3.fromRGB(220, 60, 60)
						else Color3.fromRGB(80, 200, 90),
					cornerRadius = 8,
				}),
				h("TextLabel", {
					Name = "Value",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = `{health.value or 0} / {props.maxHealth}`,
				}),
			})
		end
	end,
})
