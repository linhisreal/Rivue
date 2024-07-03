--!nonstrict
-- Tabs that keep their state: each tab is a named slot, KeepAlive caches the hidden ones
-- so scroll positions, typed text and component state survive switching.
--
--   h(Tabs, { tabs = { "Shop", "Inventory" } }, {
--       Shop = function() return h(Shop) end,
--       Inventory = function() return h(Inventory, { items = items }) end,
--   })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

return Rivue.defineComponent({
	name = "Tabs",
	props = {
		tabs = { type = "table", required = true },
	},
	setup = function(props, ctx)
		local tabs = props.tabs :: { string }
		local active = Rivue.ref(tabs[1])

		return function()
			local buttons = Rivue.hFor(props.tabs :: { string }, function(name)
				return h("TextButton", {
					key = name,
					Name = name,
					Size = UDim2.fromOffset(100, 32),
					Text = name,
					style = { active.value == name and { BackgroundColor3 = Color3.fromRGB(60, 120, 220) } },
					onClick = function()
						active.value = name
					end,
				})
			end)

			return h("Frame", { Size = UDim2.fromOffset(400, 420), BackgroundTransparency = 1 }, {
				h("Frame", { Name = "Bar", Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 }, {
					h("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal }),
					buttons,
				}),
				h("Frame", {
					Name = "Page",
					Position = UDim2.fromOffset(0, 40),
					Size = UDim2.new(1, 0, 1, -40),
					BackgroundTransparency = 1,
				}, {
					-- The slot returns a component vnode, KeepAlive caches it by component
					h(Rivue.KeepAlive, nil, ctx.renderSlot(active.value)),
				}),
			})
		end
	end,
})
