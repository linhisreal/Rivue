--!nonstrict
-- A form and a keyed list: model binding, emits from a child, computed filters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

type Todo = { id: number, text: string, done: boolean }

local TodoItem = Rivue.defineComponent({
	name = "TodoItem",
	props = {
		todo = { type = "table", required = true },
	},
	emits = { "toggle", "remove" },
	setup = function(props, ctx)
		return function()
			local todo = props.todo :: Todo
			return h("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 }, {
				h("TextButton", {
					Name = "Toggle",
					Size = UDim2.new(1, -40, 1, 0),
					Text = if todo.done then `[x] {todo.text}` else `[ ] {todo.text}`,
					TextXAlignment = Enum.TextXAlignment.Left,
					onClick = function()
						ctx.emit("toggle", todo.id)
					end,
				}),
				h("TextButton", {
					Name = "Remove",
					Size = UDim2.fromOffset(32, 32),
					Position = UDim2.new(1, -32, 0, 0),
					Text = "x",
					onClick = function()
						ctx.emit("remove", todo.id)
					end,
				}),
			})
		end
	end,
})

return Rivue.defineComponent({
	name = "TodoList",
	setup = function()
		local todos = Rivue.ref({} :: { Todo })
		local draft = Rivue.ref("")
		local nextId = 1

		local remaining = Rivue.computed(function()
			local count = 0
			for _, todo in todos.value do
				if not todo.done then
					count += 1
				end
			end
			return count
		end)

		local function add()
			if draft.value == "" then
				return
			end
			-- Replace the array so the change is obvious; list[#list + 1] = x also works
			local list = table.clone(Rivue.toRaw(todos.value))
			table.insert(list, { id = nextId, text = draft.value, done = false })
			nextId += 1
			todos.value = list
			draft.value = ""
		end

		local function toggle(id: number)
			for _, todo in todos.value do
				if todo.id == id then
					todo.done = not todo.done
				end
			end
		end

		local function remove(id: number)
			local list = {}
			for _, todo in Rivue.toRaw(todos.value) do
				if todo.id ~= id then
					table.insert(list, todo)
				end
			end
			todos.value = list
		end

		return function()
			return h("Frame", { Size = UDim2.fromOffset(320, 400), padding = 8, cornerRadius = 8 }, {
				h("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
				h("TextBox", {
					Name = "Input",
					Size = UDim2.new(1, 0, 0, 32),
					PlaceholderText = "What needs doing?",
					model = draft,
					onFocusLost = function(enterPressed: boolean)
						if enterPressed then
							add()
						end
					end,
				}),
				Rivue.hFor(todos.value, function(todo)
					return h(TodoItem, { key = todo.id, todo = todo, onToggle = toggle, onRemove = remove })
				end),
				h("TextLabel", {
					Name = "Remaining",
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = `{remaining.value} left`,
				}),
			})
		end
	end,
})
