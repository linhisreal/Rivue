--!nonstrict
-- A long list that stays fast: VirtualList only renders the rows on screen,
-- and each row is its own component so selecting one only re-renders two rows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

export type Item = { id: number, name: string, count: number }

local ROW_HEIGHT = 36

local ItemRow = Rivue.defineComponent({
	name = "ItemRow",
	props = {
		item = { type = "table", required = true },
		selected = { type = "boolean", default = false },
	},
	emits = { "select" },
	setup = function(props, ctx)
		return function()
			local item = props.item :: Item
			return h("TextButton", {
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				Text = `{item.name}  x{item.count}`,
				BackgroundColor3 = if props.selected then Color3.fromRGB(60, 120, 220) else Color3.fromRGB(40, 40, 40),
				TextColor3 = Color3.new(1, 1, 1),
				onClick = function()
					ctx.emit("select", item.id)
				end,
			})
		end
	end,
})

return Rivue.defineComponent({
	name = "Inventory",
	props = {
		-- Plain or reactive array of items
		items = { type = "table", required = true },
	},
	setup = function(props)
		local selectedId = Rivue.ref(nil :: number?)

		return function()
			return h(Rivue.VirtualList, {
				-- Undeclared props like Size go to the ScrollingFrame
				Size = UDim2.fromOffset(300, 360),
				items = props.items,
				itemSize = ROW_HEIGHT,
				key = function(item: Item)
					return item.id
				end,
				render = function(item: Item)
					return h(ItemRow, {
						item = item,
						selected = selectedId.value == item.id,
						onSelect = function(id: number)
							selectedId.value = id
						end,
					})
				end,
			})
		end
	end,
})
