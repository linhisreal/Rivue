--!nonstrict
-- A modal put together from Teleport, Transition and vClickOutside, with named slots for the title
-- and the content. Rivue.Dialog does the same job out of the box.
--
--   h(Modal, { open = isOpen.value, onClose = function() isOpen.value = false end }, {
--       title = function() return h("TextLabel", { Text = "Settings" }) end,
--       default = function() return h(SettingsForm) end,
--   })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local h = Rivue.h

return Rivue.defineComponent({
	name = "Modal",
	props = {
		open = { type = "boolean", default = false },
		-- Where to render, usually a ScreenGui with a high DisplayOrder. Defaults to in place.
		target = { type = "Instance" },
	},
	emits = { "close" },
	styles = {
		dialog = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(360, 240),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			cornerRadius = 12,
			padding = 16,
		},
	},

	render = function(ctx)
		local dialog = ctx.open
			and h("Frame", {
				Name = "Dialog",
				class = "dialog",
				layout = { gap = 8 },
				vClickOutside = function()
					ctx.emit("close")
				end,
			}, {
				ctx.renderSlot("title"),
				ctx.renderSlot("default"),
			})

		return h(Rivue.Teleport, { to = ctx.target, disabled = ctx.target == nil }, {
			h(Rivue.Transition, {
				tweenInfo = TweenInfo.new(0.15),
				from = { BackgroundTransparency = 1, Size = UDim2.fromOffset(340, 220) },
			}, { dialog or nil }),
		})
	end,
})
