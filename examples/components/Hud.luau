--!nonstrict
-- A HUD that adapts to the device and animates smoothly: useInputType/useViewportSize for layout,
-- useSpring for the health bar, attributeRef to read state the server writes on the player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

return Rivue.defineComponent({
	name = "Hud",
	props = {
		player = { type = "Instance" },
		maxHealth = { type = "number", default = 100 },
	},
	styles = {
		panel = {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			BackgroundTransparency = 0.3,
			cornerRadius = 8,
		},
		fill = { cornerRadius = 8 },
		healthy = { BackgroundColor3 = Color3.fromRGB(80, 200, 90) },
		low = { BackgroundColor3 = Color3.fromRGB(220, 60, 60) },
		label = { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
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

		return {
			health = health,
			ratio = ratio,
			-- Springs toward the real value, so damage slides instead of jumping
			shown = Rivue.useSpring(ratio, { speed = 10 }),
			compact = Rivue.computed(function()
				return input.value == "touch" or viewport.value.X < 700
			end),
		}
	end,

	render = function(ctx)
		return h("Frame", {
			Name = "Health",
			class = "panel",
			Position = UDim2.new(0.5, 0, 1, if ctx.compact then -90 else -24),
			Size = UDim2.fromOffset(if ctx.compact then 200 else 320, 20),
		}, {
			h("Frame", {
				Name = "Fill",
				class = { "fill", if ctx.ratio < 0.3 then "low" else "healthy" },
				Size = UDim2.fromScale(ctx.shown, 1),
			}),
			h("TextLabel", { Name = "Value", class = "label", Text = `{ctx.health or 0} / {ctx.maxHealth}` }),
		})
	end,
})
