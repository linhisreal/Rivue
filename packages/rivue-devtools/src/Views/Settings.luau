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

local SettingsView = Rivue.defineComponent({
	name = "SettingsView",
	styles = styles,
	setup = function()
		local slowDraft = Rivue.ref(tostring(Store.settings.slowMs))
		local limitDraft = Rivue.ref(tostring(Store.settings.timelineLimit))
		return {
			slowDraft = slowDraft,
			limitDraft = limitDraft,
			commitSlow = function()
				local value = tonumber(slowDraft.value)
				if value and value > 0 then
					Store.setSetting("slowMs", value)
				end
				slowDraft.value = tostring(Store.settings.slowMs)
			end,
			commitLimit = function()
				local value = tonumber(limitDraft.value)
				if value and value >= 10 then
					Store.setSetting("timelineLimit", math.floor(value))
				end
				limitDraft.value = tostring(Store.settings.timelineLimit)
			end,
		}
	end,
	render = function(ctx)
		local compact = Store.settings.density == "compact"
		return h("ScrollingFrame", { Name = "SettingsView", class = "list", Size = UDim2.fromScale(1, 1) }, {
			h(Widgets.Card, { key = "settings", title = "Settings" }, {
				h("Frame", { Name = "SlowMs", class = "kv" }, {
					h("TextLabel", { class = "kvKey", Text = "slow render, ms" }),
					h(
						"TextBox",
						{ Name = "Value", class = "field", model = "slowDraft", onFocusLost = ctx.commitSlow }
					),
				}),
				h("Frame", { Name = "TimelineLimit", class = "kv" }, {
					h("TextLabel", { class = "kvKey", Text = "activity length" }),
					h(
						"TextBox",
						{ Name = "Value", class = "field", model = "limitDraft", onFocusLost = ctx.commitLimit }
					),
				}),
				h("Frame", { Name = "Density", class = "kv" }, {
					h("TextLabel", { class = "kvKey", Text = "row density" }),
					h("TextButton", {
						Name = "Comfortable",
						class = { "chip", if compact then nil else "activeTool" },
						Text = "comfortable",
						onClick = function()
							Store.setDensity("comfortable")
						end,
					}),
					h("TextButton", {
						Name = "Compact",
						class = { "chip", if compact then "activeTool" else nil },
						Text = "compact",
						onClick = function()
							Store.setDensity("compact")
						end,
					}),
				}),
			}),
			h(Widgets.Card, { key = "shortcuts", title = "Shortcuts" }, {
				h(Widgets.KeyValue, { key = "k", field = "Ctrl+K", value = "search everything" }),
				h(Widgets.KeyValue, { key = "f", field = "Ctrl+F", value = "filter components" }),
				h(Widgets.KeyValue, { key = "arrows", field = "Up / Down", value = "move through the tree" }),
				h(Widgets.KeyValue, { key = "enter", field = "Enter", value = "open the source" }),
				h(Widgets.KeyValue, { key = "esc", field = "Esc", value = "close, clear, stop picking" }),
			}),
		})
	end,
})

return SettingsView
