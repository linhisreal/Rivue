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

local function openByName(name: string)
	local instance = Store.findComponent(name)
	if instance then
		Store.selectComponent(instance)
	end
end

local function msCell(ms: number): any
	return if ms >= Store.settings.slowMs
		then h("TextLabel", { Name = "Ms", class = "slowPill", Text = Store.formatMs(ms) })
		else h("TextLabel", { Name = "Ms", class = "ms", Text = Store.formatMs(ms) })
end

local PerfView = Rivue.defineComponent({
	name = "PerfView",
	styles = styles,
	render = function()
		local rows = {}
		for _, row in Store.perfRows.value do
			table.insert(rows, row)
		end
		table.sort(rows, function(a, b)
			return a.totalMs > b.totalMs
		end)
		local renders, totalMs = 0, 0
		for _, row in rows do
			renders += row.renders
			totalMs += row.totalMs
		end
		local span = Store.perfSpan.value
		local seconds = math.max((span.last - span.first) / 1000, 0)
		local recording = Store.recording.value
		local toggle = function()
			if Store.recording.value then
				Store.stopRecording()
			else
				Store.startRecording()
			end
		end
		return h(Rivue.Column, { Name = "PerformanceView", gap = 6, Size = UDim2.fromScale(1, 1) }, {
			h(Rivue.Row, { class = "toolbar", gap = 6, align = "center" }, {
				h("TextButton", {
					Name = "Record",
					class = { "tool", if recording then "activeTool" else nil },
					Text = if recording then "Stop" else "Record",
					onClick = toggle,
				}),
				h("TextLabel", {
					Name = "Summary",
					class = "statusText",
					Text = `{renders} renders · {Store.formatMs(totalMs)} over {string.format("%.1f", seconds)}s`,
				}),
			}),
			h(
				"ScrollingFrame",
				{ Name = "Perf", class = "list", Size = UDim2.new(1, 0, 1, -30), layout = { gap = 6 } },
				{
					if #rows == 0
						then h(Widgets.EmptyState, {
							title = if recording then "Recording" else "Find what renders too much",
							text = if recording
								then "Use the UI, then press Stop."
								else "Press Record, use the UI, then Stop. You'll see which components rendered most, how long they took and why.",
							action = if recording then nil else "Record",
							onAction = toggle,
						})
						else nil,
					if #rows > 0
						then h(Widgets.Card, { key = "components", title = "By component", count = #rows }, {
							Rivue.hFor(rows, function(row)
								local topCause, topCount = "", 0
								for cause, count in row.causes do
									if count > topCount then
										topCause, topCount = cause, count
									end
								end
								return Widgets.summaryRow(`Row_{row.name}`, {
									h("TextLabel", { Name = "Label", class = "label", Text = `<{row.name}>` }),
									h("TextLabel", {
										Name = "Detail",
										class = "detail",
										Text = `{row.renders}× · max {Store.formatMs(row.maxMs)} · {Store.causeText(
											topCause
										)} ({topCount})`,
									}),
									msCell(row.totalMs),
								}, function()
									openByName(row.name)
								end)
							end),
						})
						else nil,
					if #Store.perfSlowest.value > 0
						then h(
							Widgets.Card,
							{ key = "slowest", title = "Slowest updates", count = #Store.perfSlowest.value },
							{
								Rivue.hFor(Store.perfSlowest.value, function(update)
									return Widgets.summaryRow(`Slow_{update.seq}`, {
										h("TextLabel", { Name = "Label", class = "label", Text = `<{update.name}>` }),
										h(
											"TextLabel",
											{ Name = "Detail", class = "detail", Text = Store.causeText(update.cause) }
										),
										msCell(update.ms),
									}, function()
										openByName(update.name)
									end)
								end),
							}
						)
						else nil,
				}
			),
		})
	end,
})

return PerfView
