--!nonstrict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local Selection = game:GetService("Selection")
local Root = script.Parent.Parent
local Rivue = require(Root:WaitForChild("RivueUI"))
local Highlight = require(Root:WaitForChild("Highlight"))
local Store = require(Root:WaitForChild("Store"))
local Styles = require(Root:WaitForChild("Styles"))
local Widgets = require(Root:WaitForChild("Widgets"))
local h = Rivue.h
local styles = Styles.styles

type Entry = any

local function open(entry: Entry)
	local script, line = Store.resolveSource(entry.source)
	if script then
		Store.openScript(script, line or 1)
	end
end

local function ago(seconds: number): string
	return if seconds < 1
		then "now"
		elseif seconds < 60 then `{math.floor(seconds)}s ago`
		else `{math.floor(seconds / 60)}m ago`
end

local Details = Rivue.defineComponent({
	name = "Details",
	styles = styles,
	props = { entry = { required = true } },
	setup = function(props)
		return function()
			local _ = Store.tick.value
			local current: Entry = props.entry
			local script = Store.resolveSource(current.source)
			local provides = Store.lines(current.provides)
			local injects = Store.lines(current.injects)
			local slow = current.renderMs >= Store.settings.slowMs
			local crumbs = {}
			for i, ancestor in Store.ancestorsOf(current.instance) do
				table.insert(
					crumbs,
					h("TextButton", {
						key = i,
						Name = `Crumb{i}`,
						class = "crumb",
						Text = `<{(ancestor:GetAttribute("RivueComponent") :: string?) or ancestor.Name}> ›`,
						onClick = function()
							Store.selectComponent(ancestor)
						end,
					})
				)
			end
			local causes = {}
			local now = os.clock()
			for i, cause in Store.causesOf(current.instance) do
				causes[i] = h("Frame", { key = i, Name = `Cause{i}`, class = "kv" }, {
					h("TextLabel", { Name = "When", class = "kvKey", Text = ago(now - cause.at) }),
					h("TextLabel", { Name = "Value", class = "kvValue", Text = Store.causeText(cause.cause) }),
					h("TextLabel", {
						Name = "Ms",
						class = { "ms", if cause.ms >= Store.settings.slowMs then "slowMs" else nil },
						Text = Store.formatMs(cause.ms),
					}),
				})
			end
			return h(Rivue.Fragment, nil, {
				h("Frame", { Name = "Overview", class = "card" }, {
					if #crumbs > 0
						then h(Rivue.Row, { Name = "Crumbs", class = "crumbs", gap = 4, align = "center" }, crumbs)
						else nil,
					h(Rivue.Row, { gap = 8, align = "center", Size = UDim2.new(1, 0, 0, 24) }, {
						h("TextLabel", { Name = "Title", class = { "text", "strong" }, Text = `<{current.name}>` }),
						h(Rivue.Spacer),
						if script
							then h("TextButton", {
								Name = "OpenSource",
								class = "tool",
								Text = "Open source",
								onClick = function()
									open(current)
								end,
							})
							else nil,
					}),
					h(Rivue.Row, { gap = 6, align = "center", Size = UDim2.new(1, 0, 0, 18) }, {
						h(
							"TextLabel",
							{ Name = "Renders", class = { "text", "dim" }, Text = `{current.renders} renders` }
						),
						h("TextLabel", { class = { "text", "dim" }, Text = "·" }),
						h("TextLabel", {
							Name = "Time",
							class = { "text", "dim" },
							TextColor3 = if slow then Store.palette.value.slow else nil,
							Text = Store.formatMs(current.renderMs),
						}),
						h("TextLabel", { class = { "text", "dim" }, Text = "·" }),
						h(
							"TextLabel",
							{ Name = "Cause", class = { "text", "dim" }, Text = Store.causeText(current.trigger) }
						),
					}),
				}),
				if #causes > 0
					then h(Widgets.Card, { key = "recent", title = "Recent", count = #causes }, causes)
					else nil,
				h(Widgets.Card, { key = "props", title = "Props" }, Widgets.fieldRows(current.props, nil)),
				h(
					Widgets.Card,
					{ key = "state", title = "State" },
					Widgets.fieldRows(current.state, current.instance, current.previous)
				),
				h(
					Widgets.Card,
					{ key = "provides", title = "Provides", count = #provides },
					Widgets.keyList("Provides", provides)
				),
				h(
					Widgets.Card,
					{ key = "injects", title = "Injects", count = #injects },
					Widgets.keyList("Injects", injects)
				),
			})
		end
	end,
})

local function componentRow(entry: Entry, tree: boolean, selected: Instance?, collapsed, pinned, spark: boolean): any
	local slow = entry.renderMs >= Store.settings.slowMs
	return h("TextButton", {
		key = entry.path,
		class = { "row", if entry.instance == selected then "selectedRow" else nil },
		padding = { left = 6 + (if tree then Widgets.INDENT * entry.depth else 0), right = 6 },
		onClick = function()
			Store.selected.value = entry.instance
			Selection:Set({ entry.instance })
		end,
		onMouseEnter = function()
			Highlight.show(entry.instance)
		end,
		onMouseLeave = Highlight.hide,
	}, {
		if tree and entry.hasChildren
			then h("TextButton", {
				Name = "Toggle",
				class = "icon",
				onClick = function()
					Store.toggleCollapsed(entry.path)
				end,
			}, {
				h(Widgets.Chevron, { key = "chevron", open = not collapsed[entry.path] }),
			})
			elseif tree then h("Frame", { Name = "Gap", class = "icon" })
			else nil,
		h("TextLabel", { Name = "Label", class = "name", Text = `<{entry.name}>` }),
		h("Frame", { Name = "Dot", class = "dot", BackgroundTransparency = if entry.changed then 0 else 1 }),
		h(Rivue.Spacer),
		if spark then h(Widgets.Sparkline, { key = "spark", values = Store.sparkline(entry.instance) }) else nil,
		if slow
			then h("TextLabel", { Name = "Ms", class = "slowPill", Text = Store.formatMs(entry.renderMs) })
			else nil,
		h(
			Widgets.Pill,
			{ key = "renders", text = tostring(entry.renders), tone = if entry.changed then "hot" else nil }
		),
		h("TextButton", {
			Name = "Pin",
			class = "icon",
			onClick = function()
				Store.togglePinned(entry.path)
			end,
		}, {
			h(Widgets.PinIcon, { key = "mark", on = pinned[entry.path] == true }),
		}),
	})
end

local function visibleEntries(query: string): ({ Entry }, boolean)
	local tree = Store.sortMode.value == "tree"
	local ordered = Store.sorted(Store.entries.value, Store.sortMode.value)
	local keep: { [Entry]: boolean }? = nil
	if query ~= "" or Store.onlySlow.value or Store.onlyChanged.value then
		local matches: { [Entry]: boolean } = {}
		keep = matches
		for i, entry in ordered do
			local nameMatches = query == "" or string.find(string.lower(entry.name), query, 1, true) ~= nil
			local slowMatches = not Store.onlySlow.value or entry.renderMs >= Store.settings.slowMs
			local changedMatches = not Store.onlyChanged.value or entry.changed
			if not (nameMatches and slowMatches and changedMatches) then
				continue
			end
			matches[entry] = true
			local depth = entry.depth
			for j = i - 1, 1, -1 do
				if not tree or depth == 0 then
					break
				end
				local above = ordered[j]
				if above.depth < depth then
					matches[above] = true
					depth = above.depth
				end
			end
		end
	end
	local shown = {}
	local hiddenBelow: number? = nil
	for _, entry in ordered do
		if hiddenBelow and entry.depth > hiddenBelow then
			continue
		end
		hiddenBelow = nil
		if tree and Store.collapsed.value[entry.path] then
			hiddenBelow = entry.depth
		end
		if keep == nil or keep[entry] then
			table.insert(shown, entry)
		end
	end
	return shown, tree
end

local ComponentsView = Rivue.defineComponent({
	name = "ComponentsView",
	styles = styles,
	props = { wide = { type = "boolean" } },
	setup = function(props)
		local filter = Rivue.ref("")
		local split = Rivue.ref(0.55)
		local menuOpen = Rivue.ref(false)
		local dragging = false
		local body = Rivue.useTemplateRef("body")
		local filterBox = Rivue.useTemplateRef("filterBox")
		Store.setFilterFocus(function()
			local box = filterBox.value
			if box then
				(box :: TextBox):CaptureFocus()
			end
		end)
		Rivue.onUnmounted(function()
			Store.setFilterFocus(nil)
		end)

		local function menuItems()
			local folded = next(Store.collapsed.value) ~= nil
			return {
				{
					name = "Sort",
					label = `Sort: {Store.SORT_LABELS[Store.sortMode.value]}`,
					run = function()
						Store.sortMode.value = Store.NEXT_SORT[Store.sortMode.value]
					end,
				},
				{ name = "Reset", label = "Reset counts", run = Store.resetCounts },
				{
					name = if folded then "ExpandAll" else "CollapseAll",
					label = if folded then "Open all" else "Fold all",
					run = if folded then Store.expandAll else Store.collapseAll,
				},
				{
					name = "Pick",
					label = "Pick from the game",
					run = function()
						Store.picking.value = true
					end,
				},
				{ name = "Export", label = "Export snapshot", run = Store.exportSnapshot },
			}
		end

		return function()
			local _ = Store.tick.value
			local row = Styles.rowHeight(Store.settings.density)
			local shown, tree = visibleEntries(string.lower(filter.value))
			Store.setVisible(shown)
			local selected = Store.selected.value
			local collapsed = Store.collapsed.value
			local pinned = Store.pinned.value
			local current: Entry? = nil
			for _, entry in Store.entries.value do
				if entry.instance == selected then
					current = entry
				end
			end
			local pinnedRows = {}
			for _, entry in Store.entries.value do
				if pinned[entry.path] then
					table.insert(pinnedRows, entry)
				end
			end
			local pinnedHeight = if #pinnedRows > 0 then math.min(#pinnedRows, 4) * (row + 2) + 6 else 0
			local spark = true
			local bannerHeight = if Store.picking.value then row + 6 else 0

			local treeList = h(Rivue.VirtualList, {
				Name = "Tree",
				class = "vlist",
				items = shown,
				itemSize = row + 2,
				key = function(entry: Entry)
					return entry.path
				end,
				Size = if props.wide then UDim2.new(0.45, -4, 1, 0) else UDim2.new(1, 0, split.value, -4),
				render = function(entry: Entry)
					return componentRow(entry, tree, selected, collapsed, pinned, spark)
				end,
			})
			local details = h("ScrollingFrame", {
				Name = "Details",
				class = "list",
				Position = if props.wide then UDim2.new(0.45, 4, 0, 0) else UDim2.new(0, 0, split.value, 4),
				Size = if props.wide then UDim2.new(0.55, -4, 1, 0) else UDim2.new(1, 0, 1 - split.value, -4),
				layout = { gap = 6 },
			}, {
				if current
					then h(Details, { entry = current })
					elseif #Store.entries.value == 0 then h(Widgets.EmptyState, {
						title = "No components yet",
						text = "Set app.config.devtools = true before app:mount(), then press Play. Components appear here as they render.",
						action = "Refresh",
						onAction = Store.collect,
					})
					else h(Widgets.EmptyState, {
						title = "Nothing selected",
						text = "Click a component, use Up and Down, or Pick one from the game.",
					}),
			})

			return h(Rivue.Column, { Name = "ComponentsView", gap = 6, Size = UDim2.fromScale(1, 1) }, {
				h(Rivue.Row, { Name = "Toolbar", class = "toolbar", gap = 6, align = "center", ZIndex = 5 }, {
					h(
						Rivue.Row,
						{ Name = "FilterBox", class = "filter", gap = 4, align = "center", padding = { x = 4 } },
						{
							h("TextBox", {
								Name = "Filter",
								ref = "filterBox",
								model = filter,
								BackgroundTransparency = 1,
								Size = UDim2.fromScale(0, 1),
								flex = "fill",
								TextXAlignment = Enum.TextXAlignment.Left,
								TextColor3 = Store.palette.value.text,
								PlaceholderColor3 = Store.palette.value.dimText,
								PlaceholderText = "Filter (Ctrl+F)",
								TextSize = 13,
								Font = Enum.Font.SourceSans,
								ClearTextOnFocus = false,
								padding = { x = 4 },
							}),
							h("TextButton", {
								Name = "OnlySlow",
								class = { "chip", if Store.onlySlow.value then "activeTool" else nil },
								Text = "Slow",
								onClick = function()
									Store.onlySlow.value = not Store.onlySlow.value
								end,
							}),
							h("TextButton", {
								Name = "OnlyChanged",
								class = { "chip", if Store.onlyChanged.value then "activeTool" else nil },
								Text = "Changed",
								onClick = function()
									Store.onlyChanged.value = not Store.onlyChanged.value
								end,
							}),
						}
					),
					h("TextButton", {
						Name = "More",
						class = { "tool", if menuOpen.value then "activeTool" else nil },
						Text = "⋯",
						onClick = function()
							menuOpen.value = not menuOpen.value
						end,
					}),
					if menuOpen.value
						then h(Widgets.Menu, {
							items = menuItems(),
							Position = UDim2.new(1, 0, 1, 4),
							onClose = function()
								menuOpen.value = false
							end,
						})
						else nil,
				}),
				if Store.picking.value
					then h("TextButton", {
						Name = "PickBanner",
						class = { "row", "selectedRow" },
						Text = "",
						onClick = function()
							Store.picking.value = false
						end,
					}, {
						h("TextLabel", {
							class = "label",
							Text = "Select a GUI object in the Explorer, or click it in the game. Esc cancels.",
						}),
					})
					else nil,
				if #pinnedRows > 0
					then h("ScrollingFrame", {
						Name = "Pinned",
						class = "list",
						Size = UDim2.new(1, 0, 0, pinnedHeight - 6),
					}, {
						Rivue.hFor(pinnedRows, function(entry: Entry)
							return componentRow(entry, false, selected, collapsed, pinned, false)
						end),
					})
					else nil,
				h("Frame", {
					Name = "Body",
					ref = "body",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, -(row + 6) - pinnedHeight - bannerHeight),
					onInputChanged = function(input: InputObject)
						local frame = body.value
						if
							props.wide
							or not dragging
							or not frame
							or input.UserInputType ~= Enum.UserInputType.MouseMovement
						then
							return
						end
						local height = frame.AbsoluteSize.Y
						if height > 0 then
							split.value = math.clamp((input.Position.Y - frame.AbsolutePosition.Y) / height, 0.2, 0.85)
						end
					end,
					onInputEnded = function(input: InputObject)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							dragging = false
						end
					end,
					onMouseLeave = function()
						dragging = false
					end,
				}, {
					treeList,
					if props.wide
						then nil
						else h("TextButton", {
							Name = "Divider",
							class = "divider",
							Position = UDim2.new(0, 0, split.value, -4),
							onInputBegan = function(input: InputObject)
								if input.UserInputType == Enum.UserInputType.MouseButton1 then
									dragging = true
								end
							end,
						}, { h("Frame", { class = "dividerLine" }) }),
					details,
				}),
			})
		end
	end,
})

return ComponentsView
