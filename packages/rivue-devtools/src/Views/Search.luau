--!nonstrict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local Root = script.Parent.Parent
local Rivue = require(Root:WaitForChild("RivueUI"))
local Store = require(Root:WaitForChild("Store"))
local Styles = require(Root:WaitForChild("Styles"))
local Widgets = require(Root:WaitForChild("Widgets"))
local h = Rivue.h
local styles = Styles.styles

local MAX_RESULTS = 20

export type Result = { kind: string, label: string, detail: string, go: () -> () }

local function search(query: string): { Result }
	local results: { Result } = {}
	if query == "" then
		return results
	end
	local function add(result: Result)
		if #results < MAX_RESULTS then
			table.insert(results, result)
		end
	end
	local function matches(text: string): boolean
		return string.find(string.lower(text), query, 1, true) ~= nil
	end
	for _, entry in Store.entries.value do
		if matches(entry.name) then
			add({
				kind = "component",
				label = `<{entry.name}>`,
				detail = entry.path,
				go = function()
					Store.selectComponent(entry.instance)
				end,
			})
		end
	end
	for _, entry in Store.entries.value do
		for _, line in Store.lines(entry.state) do
			local key, value = Store.splitPair(line)
			if matches(key) then
				add({
					kind = "state",
					label = key,
					detail = `{value} in <{entry.name}>`,
					go = function()
						Store.selectComponent(entry.instance)
					end,
				})
			end
		end
	end
	for _, total in Store.netTotals.value do
		if matches(total.label) then
			add({
				kind = "network",
				label = total.label,
				detail = `{total.kind} · {total.count}×`,
				go = function()
					Store.view.value = "network"
					Store.searchOpen.value = false
				end,
			})
		end
	end
	for _, warning in Store.warnings.value do
		if matches(warning.message) then
			add({
				kind = warning.level,
				label = if warning.component then `<{warning.component}>` else warning.level,
				detail = (string.gsub(warning.message, "^%[Rivue[%w]*%]%s*", "")),
				go = function()
					local instance = if warning.component then Store.findComponent(warning.component) else nil
					if instance then
						Store.selectComponent(instance)
					else
						Store.view.value = "activity"
						Store.searchOpen.value = false
					end
				end,
			})
		end
	end
	return results
end

local SearchView = Rivue.defineComponent({
	name = "SearchView",
	styles = styles,
	setup = function()
		local query = Rivue.ref("")
		local box = Rivue.useTemplateRef("searchBox")
		Rivue.onMounted(function()
			local input = box.value
			if input then
				pcall(function()
					(input :: TextBox):CaptureFocus()
				end)
			end
		end)
		return { query = query }
	end,
	render = function(ctx)
		local results = search(string.lower(ctx.query))
		local rows = {}
		for i, result in results do
			rows[i] = h("TextButton", {
				key = i,
				Name = `Result{i}`,
				class = "row",
				ZIndex = 32,
				onClick = result.go,
			}, {
				Widgets.kindCell(if result.kind == "state" then "emit" else result.kind, result.kind),
				h("TextLabel", { Name = "Label", class = "label", Text = result.label }),
				h("TextLabel", { Name = "Detail", class = "detail", Text = result.detail }),
			})
		end
		return h("TextButton", {
			Name = "Search",
			class = "overlay",
			onClick = function()
				Store.searchOpen.value = false
			end,
		}, {
			h("Frame", { Name = "Panel", class = "searchPanel" }, {
				h("TextBox", {
					Name = "SearchBox",
					ref = "searchBox",
					class = "filter",
					Size = UDim2.new(1, 0, 0, 28),
					model = "query",
					PlaceholderText = "Search components, state, network and warnings",
					ZIndex = 32,
				}),
				if ctx.query ~= "" and #rows == 0
					then h(
						"TextLabel",
						{ Name = "NoResults", class = { "text", "dim" }, Text = "No matches", ZIndex = 32 }
					)
					else nil,
				h(Rivue.Fragment, nil, rows),
			}),
		})
	end,
})

return SearchView
