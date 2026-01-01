--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local UserInputService = game:GetService("UserInputService")
local Rivue = require(script.Parent:WaitForChild("RivueUI"))
local Store = require(script.Parent:WaitForChild("Store"))
local Styles = require(script.Parent:WaitForChild("Styles"))
local Widgets = require(script.Parent:WaitForChild("Widgets"))
local Views = script.Parent:WaitForChild("Views")
local ComponentsView = require(Views:WaitForChild("Components"))
local ActivityView = require(Views:WaitForChild("Activity"))
local PerfView = require(Views:WaitForChild("Perf"))
local NetworkView = require(Views:WaitForChild("Network"))
local SettingsView = require(Views:WaitForChild("Settings"))
local SearchView = require(Views:WaitForChild("Search"))
local h = Rivue.h
local styles = Styles.styles

local WIDE = 600

local function moveSelection(step: number)
	local visible = Store.visible()
	if #visible == 0 then
		return
	end
	local index = 0
	for i, entry in visible do
		if entry.instance == Store.selected.value then
			index = i
		end
	end
	local nextEntry = visible[math.clamp(index + step, 1, #visible)]
	Store.selected.value = nextEntry.instance
	game:GetService("Selection"):Set({ nextEntry.instance })
end

local function openSelected()
	for _, entry in Store.entries.value do
		if entry.instance == Store.selected.value then
			local script, line = Store.resolveSource(entry.source)
			if script then
				Store.openScript(script, line or 1)
			end
		end
	end
end

local function shortcut(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local key = input.KeyCode
	local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if key == Enum.KeyCode.K and ctrl then
		Store.searchOpen.value = not Store.searchOpen.value
	elseif key == Enum.KeyCode.F and ctrl then
		Store.view.value = "components"
		Store.focusFilter()
	elseif key == Enum.KeyCode.Escape then
		if Store.searchOpen.value then
			Store.searchOpen.value = false
		elseif Store.picking.value then
			Store.picking.value = false
		else
			Store.selected.value = nil
		end
	elseif Store.view.value == "components" and (key == Enum.KeyCode.Up or key == Enum.KeyCode.Down) then
		moveSelection(if key == Enum.KeyCode.Down then 1 else -1)
	elseif key == Enum.KeyCode.Return then
		openSelected()
	end
end

local App = Rivue.defineComponent({
	name = "RivueDevTools",
	styles = styles,
	setup = function()
		local width = Rivue.ref(0)
		local root = Rivue.useTemplateRef("root")
		local conn: RBXScriptConnection? = nil
		Rivue.onMounted(function()
			local frame = root.value
			if frame then
				width.value = frame.AbsoluteSize.X
				conn = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					width.value = frame.AbsoluteSize.X
				end)
			end
		end)
		Rivue.onUnmounted(function()
			if conn then
				conn:Disconnect()
			end
		end)
		return { width = width }
	end,
	render = function(ctx)
		Styles.sync(Store.palette.value, Store.settings.density)
		local viewName = Store.view.value
		local content: any
		if viewName == "activity" then
			content = h(ActivityView)
		elseif viewName == "performance" then
			content = h(PerfView)
		elseif viewName == "network" then
			content = h(NetworkView)
		elseif viewName == "settings" then
			content = h(SettingsView)
		else
			content = h(ComponentsView, { wide = ctx.width >= WIDE })
		end

		local function tab(key: string, name: string, label: string, count: number?): any
			return h(Widgets.TabButton, {
				key = key,
				Name = name,
				label = label,
				active = viewName == key,
				count = count,
				onSelect = function()
					Store.view.value = key
				end,
			})
		end

		local warnings = #Store.warnings.value
		return h("Frame", { ref = "root", class = "panel", layout = { gap = 8 }, onInputBegan = shortcut }, {
			h(Rivue.Row, { Name = "TabBar", class = "tabBar", gap = 2, align = "center" }, {
				tab("components", "ComponentsTab", "Components", #Store.entries.value),
				tab(
					"activity",
					"ActivityTab",
					if warnings > 0 then `Activity ⚠{warnings}` else "Activity",
					#Store.timeline.value
				),
				tab("performance", "PerformanceTab", if Store.recording.value then "● Perf" else "Perf"),
				tab("network", "NetworkTab", "Network", #Store.netEntries.value),
			}),
			h("Frame", { Name = "View", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64) }, { content }),
			h(Rivue.Row, { Name = "StatusBar", class = "statusBar", gap = 6, align = "center" }, {
				h("TextLabel", {
					Name = "Header",
					class = "statusText",
					Text = `Rivue {Rivue.version} · {#Store.entries.value} components{if Store.paused.value
						then " · paused"
						else ""}`,
				}),
				h("TextLabel", { Name = "Message", class = "statusText", Text = Store.statusMessage.value }),
				h(Rivue.Spacer),
				h("TextButton", {
					Name = "SearchButton",
					class = { "tool", "smallTool" },
					Text = "Search",
					onClick = function()
						Store.searchOpen.value = true
					end,
				}),
				h("TextButton", {
					Name = "Highlight",
					class = { "tool", "smallTool", if Store.settings.highlightUpdates then "activeTool" else nil },
					Text = "Highlight",
					onClick = function()
						Store.setSetting("highlightUpdates", not Store.settings.highlightUpdates)
					end,
				}),
				h("TextButton", {
					Name = "Pause",
					class = { "tool", "smallTool", if Store.paused.value then "activeTool" else nil },
					Text = if Store.paused.value then "Resume" else "Pause",
					onClick = function()
						Store.setPaused(not Store.paused.value)
					end,
				}),
				h("TextButton", {
					Name = "SettingsTab",
					class = { "tool", "smallTool", if viewName == "settings" then "activeTool" else nil },
					Text = "⚙",
					onClick = function()
						Store.view.value = if viewName == "settings" then "components" else "settings"
					end,
				}),
			}),
			if Store.searchOpen.value then h(SearchView) else nil,
		})
	end,
})

local api = { App = App }
for key, value in Store do
	api[key] = value
end
return api
