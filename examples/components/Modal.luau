--!nonstrict
-- A dialog that renders above everything (Teleport), animates in and out (Transition)
-- and closes when the player clicks outside it (vClickOutside). Content comes from slots.
--
--   h(Modal, { open = isOpen.value, onClose = function() isOpen.value = false end }, {
--       title = function() return h("TextLabel", { Text = "Settings" }) end,
--       default = function() return h(SettingsForm) end,
--   })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

return Rivue.defineComponent({
	name = "Modal",
	props = {
		open = { type = "boolean", default = false },
		-- Where to render, usually a ScreenGui with a high DisplayOrder. Defaults to in place.
		target = { type = "Instance" },
	},
	emits = { "close" },
	setup = function(props, ctx)
		local function close()
			ctx.emit("close")
		end

		return function()
			local dialog = props.open
				and h("Frame", {
					Name = "Dialog",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(360, 240),
					BackgroundColor3 = Color3.fromRGB(30, 30, 30),
					cornerRadius = 12,
					padding = 16,
					vClickOutside = close,
				}, {
					h("UIListLayout", { Padding = UDim.new(0, 8) }),
					ctx.renderSlot("title"),
					ctx.renderSlot("default"),
				})

			return h(Rivue.Teleport, { to = props.target, disabled = props.target == nil }, {
				h(Rivue.Transition, {
					tweenInfo = TweenInfo.new(0.15),
					from = { BackgroundTransparency = 1, Size = UDim2.fromOffset(340, 220) },
				}, { dialog or nil }),
			})
		end
	end,
})
