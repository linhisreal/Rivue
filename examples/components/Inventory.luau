--!nonstrict
-- A long list that stays fast: VirtualList only renders the rows on screen, and each row is
-- its own component, so selecting one only re-renders two rows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
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
	styles = {
		row = { Size = UDim2.new(1, 0, 0, ROW_HEIGHT), TextColor3 = Color3.new(1, 1, 1) },
		idle = { BackgroundColor3 = Color3.fromRGB(40, 40, 40) },
		selected = { BackgroundColor3 = Color3.fromRGB(60, 120, 220) },
	},

	render = function(ctx)
		local item = ctx.item :: Item
		return h("TextButton", {
			class = { "row", if ctx.selected then "selected" else "idle" },
			Text = `{item.name}  x{item.count}`,
			onClick = function()
				ctx.emit("select", item.id)
			end,
		})
	end,
})

return Rivue.defineComponent({
	name = "Inventory",
	props = {
		-- Plain or reactive array of items
		items = { type = "table", required = true },
	},

	setup = function()
		local selectedId = Rivue.ref(nil :: number?)
		return {
			selectedId = selectedId,
			select = function(id: number)
				selectedId.value = id
			end,
		}
	end,

	render = function(ctx)
		return h(Rivue.VirtualList, {
			-- Undeclared props like Size go to the ScrollingFrame
			Size = UDim2.fromOffset(300, 360),
			items = ctx.items,
			itemSize = ROW_HEIGHT,
			key = function(item: Item)
				return item.id
			end,
			render = function(item: Item)
				return h(ItemRow, { item = item, selected = ctx.selectedId == item.id, onSelect = ctx.select })
			end,
		})
	end,
})
