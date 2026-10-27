--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

-- A text box bound with model, a keyed list, and a child row that emits events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local h = Rivue.h
local array = Rivue.array

type Todo = { id: number, text: string, done: boolean }

local TodoItem = Rivue.defineComponent({
	name = "TodoItem",
	props = {
		todo = { type = "table", required = true },
	},
	emits = { "toggle", "remove" },

	render = function(ctx)
		local todo = ctx.todo :: Todo
		return h("Frame", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			layout = { direction = "horizontal", gap = 4 },
		}, {
			h("TextButton", {
				Name = "Toggle",
				Text = if todo.done then `[x] {todo.text}` else `[ ] {todo.text}`,
				TextXAlignment = Enum.TextXAlignment.Left,
				flex = "fill",
				onClick = function()
					ctx.emit("toggle", todo.id)
				end,
			}),
			h("TextButton", {
				Name = "Remove",
				Size = UDim2.fromOffset(32, 32),
				Text = "x",
				onClick = function()
					ctx.emit("remove", todo.id)
				end,
			}),
		})
	end,
})

return Rivue.defineComponent({
	name = "TodoList",
	components = { TodoItem = TodoItem },
	styles = {
		panel = { Size = UDim2.fromOffset(320, 400), padding = 8, cornerRadius = 8 },
		row = { Size = UDim2.new(1, 0, 0, 32) },
		muted = { BackgroundTransparency = 1, TextTransparency = 0.3 },
	},

	setup = function()
		local todos = Rivue.ref({} :: { Todo })
		local draft = Rivue.ref("")
		local nextId = 1

		local remaining = Rivue.computed(function()
			return array.count(todos.value, function(todo)
				return not todo.done
			end)
		end)

		local function add()
			if draft.value == "" then
				return
			end
			array.push(todos.value, { id = nextId, text = draft.value, done = false })
			nextId += 1
			draft.value = ""
		end

		local function toggle(id: number)
			local todo = array.find(todos.value, function(item)
				return item.id == id
			end)
			if todo then
				todo.done = not todo.done
			end
		end

		local function remove(id: number)
			array.removeWhere(todos.value, function(item)
				return item.id == id
			end)
		end

		return { todos = todos, draft = draft, remaining = remaining, add = add, toggle = toggle, remove = remove }
	end,

	render = function(ctx)
		return h("Frame", { class = "panel", layout = { gap = 4 } }, {
			h("TextBox", {
				Name = "Input",
				class = "row",
				PlaceholderText = "What needs doing?",
				model = "draft",
				onFocusLost = function(enterPressed: boolean)
					if enterPressed then
						ctx.add()
					end
				end,
			}),
			Rivue.hFor(ctx.todos, function(todo)
				return h("TodoItem", { key = todo.id, todo = todo, onToggle = ctx.toggle, onRemove = ctx.remove })
			end),
			h("TextLabel", { Name = "Remaining", class = { "row", "muted" }, Text = `{ctx.remaining} left` }),
		})
	end,
})
