--!nonstrict
-- Tabs that keep their state: each tab is a named slot, and KeepAlive caches the hidden ones, so
-- scroll positions, typed text and component state survive switching. When tabs need a back
-- button or links from other screens, make them child routes instead (see GameMenu).
--
--   h(Tabs, { tabs = { "Shop", "Inventory" } }, {
--       Shop = function() return h(Shop) end,
--       Inventory = function() return h(Inventory, { items = items }) end,
--   })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local h = Rivue.h

return Rivue.defineComponent({
	name = "Tabs",
	props = {
		tabs = { type = "table", required = true },
	},
	styles = {
		root = { Size = UDim2.fromOffset(400, 420), BackgroundTransparency = 1 },
		bar = { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 },
		tab = { Size = UDim2.fromOffset(100, 32) },
		active = { BackgroundColor3 = Color3.fromRGB(60, 120, 220) },
		page = { Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1 },
	},

	setup = function(props)
		local active = Rivue.ref((props.tabs :: { string })[1])
		return {
			active = active,
			open = function(name: string)
				active.value = name
			end,
		}
	end,

	render = function(ctx)
		return h("Frame", { class = "root", layout = { gap = 8 } }, {
			h("Frame", { Name = "Bar", class = "bar", layout = "horizontal" }, {
				Rivue.hFor(ctx.tabs :: { string }, function(name)
					return h("TextButton", {
						key = name,
						Name = name,
						class = { tab = true, active = ctx.active == name },
						Text = name,
						onClick = function()
							ctx.open(name)
						end,
					})
				end),
			}),
			h("Frame", { Name = "Page", class = "page" }, {
				-- The slot returns a component vnode, KeepAlive caches it per component
				h(Rivue.KeepAlive, nil, ctx.renderSlot(ctx.active)),
			}),
		})
	end,
})
