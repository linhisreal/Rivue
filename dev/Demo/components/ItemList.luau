--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local h = Rivue.h
local array = Rivue.array

local ListItem = require("./ListItem")

type Item = { id: number, name: string }

return Rivue.defineComponent({
	name = "ItemList",
	components = { ListItem = ListItem },

	setup = function()
		local items = Rivue.ref({
			{ id = 1, name = "Apple" },
			{ id = 2, name = "Banana" },
			{ id = 3, name = "Cherry" },
		} :: { Item })
		local draft = Rivue.ref("")
		local nextId = 4

		local function add()
			local name = if draft.value ~= "" then draft.value else `Item {nextId}`
			array.push(items.value, { id = nextId, name = name })
			nextId += 1
			draft.value = ""
		end

		local function remove(id: number)
			array.removeWhere(items.value, function(item)
				return item.id == id
			end)
		end

		return { items = items, draft = draft, add = add, remove = remove }
	end,

	render = function(ctx)
		return h("Frame", { class = "card", layout = { gap = 8 } }, {
			h("TextLabel", { class = "title", Text = `Items ({#ctx.items})` }),
			h("Frame", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
				layout = { direction = "horizontal", gap = 8 },
			}, {
				h("TextBox", {
					class = "input",
					PlaceholderText = "New item...",
					model = "draft",
					flex = "fill",
				}),
				h("TextButton", { class = "button", Text = "Add", onClick = ctx.add }),
			}),
			Rivue.hFor(ctx.items, function(item)
				return h("ListItem", {
					key = item.id,
					name = item.name,
					onRemove = function()
						ctx.remove(item.id)
					end,
				})
			end),
		})
	end,
})
