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

local NetworkView = Rivue.defineComponent({
	name = "NetworkView",
	styles = styles,
	render = function()
		local totals = {}
		local messages, bytes = 0, 0
		for _, total in Store.netTotals.value do
			table.insert(totals, total)
			messages += total.count
			bytes += total.bytes
		end
		table.sort(totals, function(a, b)
			if a.count ~= b.count then
				return a.count > b.count
			end
			return a.key < b.key
		end)
		local states = {}
		for _, state in Store.netState.value do
			table.insert(states, state)
		end
		table.sort(states, function(a, b)
			return a.name < b.name
		end)
		local entries = Store.netEntries.value
		local log = {}
		for i = 1, math.min(#entries, 50) do
			log[i] = entries[i]
		end
		return h(Rivue.Column, { Name = "NetworkView", gap = 6, Size = UDim2.fromScale(1, 1) }, {
			h(Rivue.Row, { class = "toolbar", gap = 6, align = "center" }, {
				h("TextLabel", { Name = "Summary", class = "statusText", Text = `{messages} messages · {bytes} B` }),
				h(Rivue.Spacer),
				h("TextButton", { Name = "Clear", class = "tool", Text = "Clear", onClick = Store.clearNetwork }),
			}),
			h(
				"ScrollingFrame",
				{ Name = "Network", class = "list", Size = UDim2.new(1, 0, 1, -30), layout = { gap = 6 } },
				{
					if #totals == 0 and #states == 0
						then h(Widgets.EmptyState, {
							title = "No traffic yet",
							text = "RivueRemote requests, sends, events from the server and replicated state show up here while DevTools is open.",
						})
						else nil,
					if #totals > 0
						then h(Widgets.Card, { key = "totals", title = "By action", count = #totals }, {
							Rivue.hFor(totals, function(total)
								local average = if total.count > 0 then total.totalMs / total.count else 0
								return Widgets.summaryRow(`Total_{total.key}`, {
									Widgets.kindCell("network", total.kind),
									h("TextLabel", { Name = "Label", class = "label", Text = total.label }),
									h("TextLabel", {
										Name = "Detail",
										class = "detail",
										Text = `{total.count}× · {total.bytes} B{if total.kind == "request"
											then ` · avg {Store.formatMs(average)}`
											else ""}{if total.failed > 0 then ` · {total.failed} failed` else ""}`,
									}),
								})
							end),
						})
						else nil,
					if #states > 0
						then h(Widgets.Card, { key = "state", title = "Replicated state", count = #states }, {
							Rivue.hFor(states, function(state)
								return h(Widgets.KeyValue, {
									key = state.name,
									field = state.name,
									value = `{state.value}  (v{state.version})`,
								})
							end),
						})
						else nil,
					if #log > 0
						then h(Widgets.Card, { key = "log", title = "Latest", count = #entries }, {
							Rivue.hFor(log, function(entry)
								return Widgets.summaryRow(`Log_{entry.seq}`, {
									Widgets.kindCell(if entry.failed then "error" else "network", entry.kind),
									h("TextLabel", { Name = "Label", class = "label", Text = entry.label }),
									h("TextLabel", { Name = "Detail", class = "detail", Text = entry.detail }),
									h("TextLabel", {
										Name = "Ms",
										class = "ms",
										Text = if entry.ms then Store.formatMs(entry.ms) else "",
									}),
								})
							end),
						})
						else nil,
				}
			),
		})
	end,
})

return NetworkView
