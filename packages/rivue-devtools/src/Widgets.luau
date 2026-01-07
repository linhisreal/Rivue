--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local Rivue = require(script.Parent:WaitForChild("RivueUI"))
local Store = require(script.Parent:WaitForChild("Store"))
local Styles = require(script.Parent:WaitForChild("Styles"))
local h = Rivue.h
local styles = Styles.styles

local Widgets = {}
Widgets.INDENT = 14

local Chevron = Rivue.defineComponent({
	name = "Chevron",
	styles = styles,
	props = { open = { type = "boolean" } },
	render = function(ctx)
		return h("Frame", { Name = "Chevron", class = "icon", Rotation = if ctx.open then 0 else -90 }, {
			h("Frame", {
				class = "iconStroke",
				Size = UDim2.fromOffset(6, 2),
				Position = UDim2.new(0.5, -2, 0.5, 0),
				Rotation = 45,
			}),
			h("Frame", {
				class = "iconStroke",
				Size = UDim2.fromOffset(6, 2),
				Position = UDim2.new(0.5, 2, 0.5, 0),
				Rotation = -45,
			}),
		})
	end,
})
Widgets.Chevron = Chevron

local PinIcon = Rivue.defineComponent({
	name = "PinIcon",
	styles = styles,
	props = { on = { type = "boolean" } },
	render = function(ctx)
		local p = Store.palette.value
		return h("Frame", {
			Name = "Mark",
			Size = UDim2.fromOffset(8, 8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = p.changed,
			BackgroundTransparency = if ctx.on then 0 else 1,
			BorderSizePixel = 0,
			cornerRadius = 4,
			stroke = { Color = if ctx.on then p.changed else p.dimText, Thickness = 1 },
		})
	end,
})
Widgets.PinIcon = PinIcon

local Sparkline = Rivue.defineComponent({
	name = "Sparkline",
	styles = styles,
	props = { values = { type = "table", required = true } },
	render = function(ctx)
		local values: { number } = ctx.values
		local most = 1
		for _, value in values do
			most = math.max(most, value)
		end
		local bars = {}
		for i, value in values do
			bars[i] = h("Frame", {
				key = i,
				class = { "sparkBar", if value > 0 and i == #values then "hotSpark" else nil },
				Size = UDim2.new(0, 2, 0, if value > 0 then math.max(2, math.round(12 * value / most)) else 1),
				BackgroundTransparency = if value > 0 then 0 else 0.6,
			})
		end
		return h("Frame", { Name = "Spark", class = "spark" }, bars)
	end,
})
Widgets.Sparkline = Sparkline

local Pill = Rivue.defineComponent({
	name = "Pill",
	styles = styles,
	props = { text = { type = "string", required = true }, tone = { type = "string" } },
	render = function(ctx)
		return h("TextLabel", {
			class = { "pill", if ctx.tone then `{ctx.tone}Pill` else nil },
			Text = ctx.text,
		})
	end,
})

Widgets.Pill = Pill

local Card = Rivue.defineComponent({
	name = "Card",
	styles = styles,
	props = { title = { type = "string", required = true }, count = { type = "number" } },
	setup = function()
		local open = Rivue.ref(true)
		return {
			open = open,
			toggle = function()
				open.value = not open.value
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { Name = `{ctx.title}Card`, class = "card" }, {
			h("TextButton", { Name = "Title", class = "cardTitle", onClick = ctx.toggle }, {
				h(Chevron, { key = "chevron", open = ctx.open }),
				h("TextLabel", { Name = "Heading", class = "heading", Text = string.upper(ctx.title) }),
				h(Rivue.Spacer),
				if ctx.count
					then h("TextLabel", { Name = "Count", class = "tabCount", Text = tostring(ctx.count) })
					else nil,
			}),
			if ctx.open then h(Rivue.Fragment, nil, ctx.renderSlot("default")) else nil,
		})
	end,
})
Widgets.Card = Card

local KeyValue = Rivue.defineComponent({
	name = "KeyValue",
	styles = styles,
	props = { field = { type = "string", required = true }, value = { type = "string", required = true } },
	render = function(ctx)
		return h("Frame", { Name = ctx.field, class = "kv" }, {
			h("TextLabel", { Name = "Key", class = "kvKey", Text = ctx.field }),
			h("TextBox", {
				Name = "Value",
				class = "kvValue",
				Text = ctx.value,
				TextEditable = false,
				ClearTextOnFocus = false,
			}),
		})
	end,
})

Widgets.KeyValue = KeyValue

local StateField
StateField = Rivue.defineComponent({
	name = "StateField",
	styles = styles,
	props = {
		target = { required = true },
		field = { type = "string", required = true },
		path = { type = "string" },
		value = { type = "string", required = true },
		previous = { type = "string" },
		depth = { type = "number", default = 0 },
	},
	setup = function(props)
		local draft = Rivue.ref(props.value)
		local open = Rivue.ref(false)
		Rivue.watch(function()
			return props.value
		end, function(value)
			draft.value = value
		end)
		local function send(value: string)
			props.target:SetAttribute("RivueEdit", `{props.path or props.field}={value}`)
		end
		return {
			draft = draft,
			open = open,
			commit = function()
				if draft.value ~= props.value then
					send(draft.value)
				end
			end,
			flip = function()
				send(if props.value == "true" then "false" else "true")
			end,
			toggleOpen = function()
				open.value = not open.value
			end,
		}
	end,
	render = function(ctx)
		local value: string = ctx.value
		local indent = { left = (ctx.depth :: number) * Widgets.INDENT }
		local isTable = string.sub(value, 1, 1) == "{" and value ~= "{}"
		local editor: any
		if value == "true" or value == "false" then
			editor = h("TextButton", {
				Name = "Value",
				class = { "chip", if value == "true" then "render" else nil },
				BackgroundTransparency = if value == "true" then 0.8 else 0,
				Text = value,
				onClick = ctx.flip,
			})
		elseif isTable then
			editor = h("TextButton", {
				Name = "Value",
				class = "kvValue",
				Text = value,
				onClick = ctx.toggleOpen,
			}, {
				h(Chevron, {
					key = "chevron",
					open = ctx.open,
					Position = UDim2.new(0, -14, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
				}),
			})
		elseif Store.isEditable(value) then
			editor = h("TextBox", { Name = "Value", class = "field", model = "draft", onFocusLost = ctx.commit })
		else
			editor = h("TextBox", {
				Name = "Value",
				class = "kvValue",
				Text = value,
				TextEditable = false,
				ClearTextOnFocus = false,
			})
		end
		local nested = {}
		if isTable and ctx.open then
			for _, field in Store.tableFields(value) do
				table.insert(
					nested,
					h(StateField, {
						key = field.key,
						target = ctx.target,
						field = field.key,
						path = `{ctx.path or ctx.field}.{field.key}`,
						value = field.value,
						depth = (ctx.depth :: number) + 1,
					})
				)
			end
		end
		return h(Rivue.Fragment, nil, {
			h("Frame", { Name = ctx.field, class = "kv", padding = indent }, {
				h("TextLabel", { Name = "Key", class = "kvKey", Text = ctx.field }),
				editor,
				if ctx.previous
					then h("TextLabel", { Name = "Previous", class = { "statusText" }, Text = `was {ctx.previous}` })
					else nil,
			}),
			h(Rivue.Fragment, nil, nested),
		})
	end,
})

Widgets.StateField = StateField

local TabButton = Rivue.defineComponent({
	name = "TabButton",
	styles = styles,
	emits = { "select" },
	props = {
		label = { type = "string", required = true },
		active = { type = "boolean" },
		count = { type = "number" },
	},
	render = function(ctx)
		return h("TextButton", {
			class = { "tab", if ctx.active then "activeTab" else nil },
			onClick = function()
				ctx.emit("select")
			end,
		}, {
			h("TextLabel", {
				Name = "Label",
				class = { "tabLabel", if ctx.active then "activeTabText" else nil },
				Text = ctx.label,
			}),
			if ctx.count and ctx.count > 0
				then h("TextLabel", {
					Name = "Count",
					class = { "tabCount", if ctx.active then "activeTabText" else nil },
					Text = tostring(ctx.count),
				})
				else nil,
		})
	end,
})

Widgets.TabButton = TabButton

local EmptyState = Rivue.defineComponent({
	name = "EmptyState",
	styles = styles,
	emits = { "action" },
	props = {
		title = { type = "string", required = true },
		text = { type = "string", required = true },
		action = { type = "string" },
	},
	render = function(ctx)
		return h("Frame", { Name = "Empty", class = "emptyCard" }, {
			h("TextLabel", { Name = "Title", class = { "text", "strong" }, Text = ctx.title }),
			h("TextLabel", {
				Name = "Body",
				class = { "text", "dim" },
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				Text = ctx.text,
			}),
			if ctx.action
				then h("TextButton", {
					Name = "Action",
					class = { "tool", "activeTool" },
					Text = ctx.action,
					onClick = function()
						ctx.emit("action")
					end,
				})
				else nil,
		})
	end,
})
Widgets.EmptyState = EmptyState

local Menu = Rivue.defineComponent({
	name = "Menu",
	styles = styles,
	emits = { "close" },
	props = { items = { type = "table", required = true } },
	render = function(ctx)
		local items = {}
		for i, item in ctx.items do
			items[i] = h("TextButton", {
				key = item.name,
				Name = item.name,
				class = "menuItem",
				Text = item.label,
				onClick = function()
					item.run()
					ctx.emit("close")
				end,
			})
		end
		return h("Frame", { Name = "Menu", class = "menu", AnchorPoint = Vector2.new(1, 0) }, items)
	end,
})
Widgets.Menu = Menu

function Widgets.fieldRows(text: string, target: Instance?, previous: { [string]: string }?): { any }
	local rows = {}
	for _, line in Store.lines(text) do
		local key, value = Store.splitPair(line)
		if target then
			table.insert(
				rows,
				h(StateField, {
					key = key,
					field = key,
					target = target,
					value = value,
					previous = if previous then previous[key] else nil,
				})
			)
		else
			table.insert(rows, h(KeyValue, { key = key, field = key, value = value }))
		end
	end
	if #rows == 0 then
		table.insert(rows, h("TextLabel", { class = { "text", "dim" }, Text = "(none)" }))
	end
	return rows
end

function Widgets.keyList(name: string, keys: { string }): { any }
	if #keys == 0 then
		return { h("TextLabel", { Name = name, class = { "text", "dim" }, Text = "(none)" }) }
	end
	return {
		h("TextLabel", {
			Name = name,
			class = { "text" },
			Font = Enum.Font.Code,
			TextSize = 12,
			LineHeight = 1.4,
			Text = table.concat(keys, "\n"),
		}),
	}
end

function Widgets.summaryRow(name: string, cells: { any }, onClick: (() -> ())?): any
	return h("TextButton", { key = name, Name = name, class = "row", onClick = onClick }, cells)
end

function Widgets.kindCell(kind: string, text: string?): any
	return h(Rivue.Row, { key = "kind", Name = "KindCell", gap = 6, align = "center", Size = UDim2.new(0, 96, 1, 0) }, {
		h("Frame", { Name = "Dot", class = { "kindDot", kind } }),
		h("TextLabel", { Name = "Kind", class = "kind", Text = text or kind }),
	})
end

return Widgets
