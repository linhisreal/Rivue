--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local Root = script.Parent.Parent
local Rivue = require(Root:WaitForChild("RivueUI"))
local Store = require(Root:WaitForChild("Store"))
local Styles = require(Root:WaitForChild("Styles"))
local Widgets = require(Root:WaitForChild("Widgets"))
local h = Rivue.h
local styles = Styles.styles

export type Item = {
	id: string,
	at: number,
	group: string,
	kind: string,
	label: string,
	detail: string,
	ms: number?,
	component: string?,
}

local function groupOf(kind: string): string
	return if Store.NETWORK_KINDS[kind] then "network" else kind
end

local function items(): { Item }
	local list: { Item } = {}
	for _, entry in Store.timeline.value do
		local group = groupOf(entry.kind)
		if Store.kindsShown[group] == false then
			continue
		end
		local component = if entry.kind == "render"
			then entry.label
			elseif entry.kind == "emit" then string.match(entry.label, "^([^:]+):")
			else nil
		table.insert(list, {
			id = `t{entry.seq}`,
			at = entry.at,
			group = group,
			kind = entry.kind,
			label = entry.label,
			detail = entry.detail,
			ms = tonumber(entry.ms),
			component = component,
		})
	end
	if Store.kindsShown.warning ~= false then
		for _, warning in Store.warnings.value do
			table.insert(list, {
				id = `w{warning.id}`,
				at = warning.at,
				group = "warning",
				kind = warning.level,
				label = if warning.component then `<{warning.component}>` else "",
				detail = (string.gsub(warning.message, "^%[Rivue[%w]*%]%s*", "")),
				component = warning.component,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.at ~= b.at then
			return a.at > b.at
		end
		return a.id > b.id
	end)
	return list
end

local function routeCard(info: any): any
	local rows = {}
	for _, section in { "params", "query", "meta" } do
		for _, field in info.fields do
			if field.section == section then
				table.insert(
					rows,
					h(
						Widgets.KeyValue,
						{ key = `{section}.{field.key}`, field = `{section}.{field.key}`, value = field.value }
					)
				)
			end
		end
	end
	local history = {}
	for i, item in info.history do
		table.insert(history, if item.current then `[{item.name}]` else item.name)
	end
	return h(Widgets.Card, { key = "route", title = "Route" }, {
		h("TextLabel", { Name = "RouteName", class = { "text", "strong" }, Text = info.name }),
		h(Rivue.Fragment, nil, rows),
		h(Widgets.KeyValue, { key = "history", field = "history", value = table.concat(history, " › ") }),
	})
end

local ActivityView = Rivue.defineComponent({
	name = "ActivityView",
	styles = styles,
	render = function()
		local row = Styles.rowHeight(Store.settings.density)
		local list = items()
		local slowest = 0
		for _, item in list do
			slowest = math.max(slowest, item.ms or 0)
		end
		local first = if #list > 0 then list[#list].at else 0
		local chips = {}
		for i, kind in Store.KINDS do
			local on = Store.kindsShown[kind] ~= false
			chips[i] = h("TextButton", {
				key = kind,
				Name = `Chip_{kind}`,
				class = { "chip", if on then "activeTool" else nil },
				Text = kind,
				onClick = function()
					Store.kindsShown[kind] = not on
				end,
			})
		end
		local route = Store.parseRoute(Store.routeText.value)
		return h(Rivue.Column, { Name = "ActivityView", gap = 6, Size = UDim2.fromScale(1, 1) }, {
			h(Rivue.Row, { class = "toolbar", gap = 4, align = "center" }, {
				h(Rivue.Fragment, nil, chips),
				h(Rivue.Spacer),
				h("TextButton", {
					Name = "Clear",
					class = "tool",
					Text = "Clear",
					onClick = function()
						Store.timeline.value = {}
						Store.events.value = {}
						Store.warnings.value = {}
					end,
				}),
			}),
			if route then routeCard(route) else nil,
			if #list == 0
				then h(Widgets.EmptyState, {
					title = "Nothing happened yet",
					text = "Renders, emits, navigations, network traffic and warnings show up here, newest first.",
				})
				else h(Rivue.VirtualList, {
					Name = "Activity",
					class = "vlist",
					items = list,
					itemSize = row + 2,
					Size = UDim2.new(1, 0, 0, 0),
					flex = "fill",
					key = function(item: Item)
						return item.id
					end,
					render = function(item: Item)
						return h("TextButton", {
							class = "row",
							onClick = function()
								if item.group == "network" then
									Store.view.value = "network"
								elseif item.component then
									local instance = Store.findComponent(item.component)
									if instance then
										Store.selectComponent(instance)
									end
								end
							end,
						}, {
							h("TextLabel", {
								Name = "Time",
								class = "time",
								Text = string.format("+%.2fs", (item.at - first) / 1000),
							}),
							Widgets.kindCell(item.group, item.kind),
							h("TextLabel", { Name = "Label", class = "label", Text = item.label }),
							h("TextLabel", { Name = "Detail", class = "detail", Text = item.detail }),
							if item.ms
								then h("Frame", { key = "bar", Name = "Bar", class = "bar" }, {
									h("Frame", {
										class = { "barFill", item.group },
										Size = UDim2.fromScale(
											if slowest > 0 then math.clamp(item.ms / slowest, 0.04, 1) else 0,
											1
										),
									}),
								})
								else nil,
							h("TextLabel", {
								Name = "Ms",
								class = { "ms", if (item.ms or 0) >= Store.settings.slowMs then "slowMs" else nil },
								Text = if item.ms then Store.formatMs(item.ms) else "",
							}),
						})
					end,
				}),
		})
	end,
})

return ActivityView
