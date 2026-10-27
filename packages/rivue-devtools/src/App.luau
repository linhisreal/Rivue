--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local Rivue = require(script.Parent:WaitForChild("RivueUI"))
local Highlight = require(script.Parent:WaitForChild("Highlight"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local h = Rivue.h

local TAG = "RivueComponent"
local CHANNEL_TAG = "RivueDevToolsChannel"
local SLOW_MS = 2
local MAX_EVENTS = 100
local MAX_TIMELINE = 200
local INDENT = 14

export type Entry = {
	instance: Instance,
	depth: number,
	name: string,
	props: string,
	state: string,
	renders: number,
	renderMs: number,
	trigger: string,
	source: string,
	provides: string,
	injects: string,
	hasChildren: boolean,
	changed: boolean,
}

export type EmitEvent = {
	id: number,
	name: string,
	event: string,
	args: string,
	instance: Instance,
}

export type TimelineEntry = {
	seq: number,
	at: number,
	kind: string,
	ms: string,
	label: string,
	detail: string,
}

export type SortMode = "tree" | "renders" | "slowest"
export type View = "components" | "events" | "timeline" | "router"

local SORT_LABELS: { [SortMode]: string } = { tree = "tree", renders = "most renders", slowest = "slowest" }
local NEXT_SORT: { [SortMode]: SortMode } = { tree = "renders", renders = "slowest", slowest = "tree" }

local entries = Rivue.shallowRef({} :: { Entry })
local events = Rivue.shallowRef({} :: { EmitEvent })
local selected = Rivue.shallowRef(nil :: Instance?)
local collapsed = Rivue.shallowRef(setmetatable({}, { __mode = "k" }) :: any)
local paused = Rivue.ref(false)
local sortMode = Rivue.ref("tree" :: SortMode)
local view = Rivue.ref("components" :: View)
local timeline = Rivue.shallowRef({} :: { TimelineEntry })
local routeText = Rivue.ref("")
local lastSeq = 0
local palette = Rivue.shallowRef(Theme.read())
local lastRenders: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local baselines: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: RBXScriptConnection } = {}
local eventCount = 0
local openScript: ((script: LuaSourceContainer, line: number) -> ())? = nil

local function depthOf(instance: Instance): number
	local depth = 0
	local parent = instance.Parent
	while parent do
		if CollectionService:HasTag(parent, TAG) then
			depth += 1
		end
		parent = parent.Parent
	end
	return depth
end

local function fullName(instance: Instance): string
	local ok, name = pcall(instance.GetFullName, instance)
	return if ok then name else instance.Name
end

local function collect()
	local list: { Entry } = {}
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance.Parent ~= nil then
			local renders = (instance:GetAttribute("RivueRenders") :: number?) or 0
			local before = lastRenders[instance]
			lastRenders[instance] = renders
			table.insert(list, {
				instance = instance,
				depth = depthOf(instance),
				name = (instance:GetAttribute("RivueComponent") :: string?) or instance.Name,
				props = (instance:GetAttribute("RivueProps") :: string?) or "",
				state = (instance:GetAttribute("RivueState") :: string?) or "",
				renders = renders - (baselines[instance] or 0),
				renderMs = (instance:GetAttribute("RivueRenderMs") :: number?) or 0,
				trigger = (instance:GetAttribute("RivueTrigger") :: string?) or "",
				source = (instance:GetAttribute("RivueSource") :: string?) or "",
				provides = (instance:GetAttribute("RivueProvides") :: string?) or "",
				injects = (instance:GetAttribute("RivueInjects") :: string?) or "",
				hasChildren = false,
				changed = before ~= nil and renders > before,
			})
		end
	end
	table.sort(list, function(a, b)
		return fullName(a.instance) < fullName(b.instance)
	end)
	for i, entry in list do
		local nextEntry = list[i + 1]
		entry.hasChildren = nextEntry ~= nil and nextEntry.depth > entry.depth
	end
	if selected.value and not table.find(CollectionService:GetTagged(TAG), selected.value) then
		selected.value = nil
	end
	entries.value = list
end

local pending = false
local function refreshSoon()
	if pending or paused.value then
		return
	end
	pending = true
	task.delay(0.2, function()
		pending = false
		if not paused.value then
			collect()
		end
	end)
end

local function logEmit(instance: Instance)
	if paused.value then
		return
	end
	local raw = instance:GetAttribute("RivueEmit")
	local event, args = string.match(if type(raw) == "string" then raw else "", "^%d+|([^|]*)|(.*)$")
	if not event then
		return
	end
	eventCount += 1
	local list = table.clone(events.value)
	table.insert(list, 1, {
		id = eventCount,
		name = (instance:GetAttribute("RivueComponent") :: string?) or instance.Name,
		event = event,
		args = args,
		instance = instance,
	})
	if #list > MAX_EVENTS then
		table.remove(list)
	end
	events.value = list
end

-- The channel keeps the last 50 events, and several apps can share them, so lines are matched by
-- their sequence number
local function readTimeline(channel: Instance)
	if paused.value then
		return
	end
	local raw = channel:GetAttribute("RivueTimeline")
	local added = {}
	for line in string.gmatch(if type(raw) == "string" then raw else "", "[^\n]+") do
		local seq, at, kind, ms, label, detail =
			string.match(line, "^(%d+)\t(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
		local number = tonumber(seq)
		if number and number > lastSeq then
			table.insert(added, 1, {
				seq = number,
				at = tonumber(at) :: number,
				kind = kind :: string,
				ms = ms :: string,
				label = label :: string,
				detail = detail :: string,
			})
		end
	end
	if #added == 0 then
		return
	end
	lastSeq = added[1].seq
	local list = table.clone(timeline.value)
	for i = #added, 1, -1 do
		table.insert(list, 1, added[i])
	end
	while #list > MAX_TIMELINE do
		table.remove(list)
	end
	timeline.value = list
end

local function readRoute(channel: Instance)
	local raw = channel:GetAttribute("RivueRoute")
	if type(raw) == "string" then
		routeText.value = raw
	end
end

local function setPaused(value: boolean)
	paused.value = value
	if not value then
		collect()
	end
end

--- Counts start again from zero, so you can measure one interaction
local function resetCounts()
	for _, instance in CollectionService:GetTagged(TAG) do
		baselines[instance] = (instance:GetAttribute("RivueRenders") :: number?) or 0
	end
	collect()
end

local function toggleCollapsed(instance: Instance)
	local next = setmetatable(table.clone(collapsed.value), { __mode = "k" })
	next[instance] = if next[instance] then nil else true
	collapsed.value = next
end

local function watch(instance: Instance)
	if not watched[instance] then
		watched[instance] = instance.AttributeChanged:Connect(function(name)
			if name == "RivueEmit" then
				logEmit(instance)
			elseif name ~= "RivueEdit" then
				refreshSoon()
			end
		end)
	end
end

local setPalette: (next: Theme.Palette) -> ()

local function watchChannel(channel: Instance)
	if watched[channel] then
		return
	end
	watched[channel] = channel.AttributeChanged:Connect(function(name)
		if name == "RivueTimeline" then
			readTimeline(channel)
		elseif name == "RivueRoute" then
			readRoute(channel)
		end
	end)
	readTimeline(channel)
	readRoute(channel)
end

local function start(): () -> ()
	local conns = {
		CollectionService:GetInstanceAddedSignal(CHANNEL_TAG):Connect(watchChannel),
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
			watch(instance)
			refreshSoon()
		end),
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
			local conn = watched[instance]
			if conn then
				conn:Disconnect()
				watched[instance] = nil
			end
			baselines[instance] = nil
			refreshSoon()
		end),
	}
	local stopTheme = Theme.watch(setPalette)
	for _, instance in CollectionService:GetTagged(TAG) do
		watch(instance)
	end
	for _, channel in CollectionService:GetTagged(CHANNEL_TAG) do
		watchChannel(channel)
	end
	collect()
	return function()
		stopTheme()
		Highlight.hide()
		for _, conn in conns do
			conn:Disconnect()
		end
		for instance, conn in watched do
			conn:Disconnect()
			watched[instance] = nil
		end
	end
end

--- Finds the script behind a RivueSource value like "ReplicatedStorage.UI.Shop:12"
local function resolveSource(source: string, root: Instance?): (LuaSourceContainer?, number?)
	local path, line = string.match(source, "^(.+):(%d+)$")
	if not path then
		return nil, nil
	end
	local ok, found = pcall(function(): Instance?
		local node: Instance? = root or game
		for name in string.gmatch(path, "[^%.]+") do
			node = (node :: Instance):FindFirstChild(name)
			if not node then
				return nil
			end
		end
		return node
	end)
	if ok and found and found:IsA("LuaSourceContainer") then
		return found :: LuaSourceContainer, tonumber(line)
	end
	return nil, nil
end

local function sorted(list: { Entry }, mode: SortMode): { Entry }
	if mode == "tree" then
		return list
	end
	local copy = table.clone(list)
	table.sort(copy, function(a, b)
		if mode == "renders" and a.renders ~= b.renders then
			return a.renders > b.renders
		elseif mode == "slowest" and a.renderMs ~= b.renderMs then
			return a.renderMs > b.renderMs
		end
		return a.name < b.name
	end)
	return copy
end

local function formatMs(ms: number): string
	return string.format("%.2f ms", ms)
end

local function causeText(trigger: string): string
	return if trigger == "mount"
		then "first render"
		elseif trigger == "parent" then "parent update"
		elseif trigger == "" then ""
		else `{trigger} changed`
end

local function isEditable(value: string): boolean
	return value == "true"
		or value == "false"
		or tonumber(value) ~= nil
		or (string.sub(value, 1, 1) == '"' and string.sub(value, -4) ~= '..."')
end

local function buildStyles(p: Theme.Palette): { [string]: any }
	local label = {
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = p.text,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}
	return {
		panel = {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = p.background,
			BorderSizePixel = 0,
			layout = { gap = 4 },
			padding = 6,
		},
		headerRow = {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			layout = { direction = "horizontal", gap = 4, align = "center" },
		},
		header = {
			Size = UDim2.new(1, -310, 1, 0),
			BackgroundTransparency = 1,
			TextColor3 = p.dimText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
		},
		filter = {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = p.input,
			BorderSizePixel = 0,
			TextColor3 = p.text,
			PlaceholderColor3 = p.dimText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 14,
			ClearTextOnFocus = false,
			padding = { x = 6 },
			cornerRadius = 4,
		},
		toolbar = {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			layout = { direction = "horizontal", gap = 4 },
		},
		tool = {
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = p.button,
			BorderSizePixel = 0,
			TextColor3 = p.text,
			TextSize = 13,
			padding = { x = 8 },
			cornerRadius = 4,
			hover = { BackgroundColor3 = p.buttonHover },
		},
		activeTool = { BackgroundColor3 = p.accent, TextColor3 = p.accentText },
		list = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = p.dimText,
			layout = "vertical",
		},
		row = {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundColor3 = p.background,
			BorderSizePixel = 0,
			TextColor3 = p.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			hover = { BackgroundColor3 = p.rowHover },
		},
		toggle = {
			Size = UDim2.fromOffset(INDENT + 2, 22),
			Position = UDim2.fromOffset(-(INDENT + 2), 0),
			BackgroundTransparency = 1,
			TextColor3 = p.dimText,
			TextSize = 12,
		},
		changedRow = { TextColor3 = p.changed },
		slowRow = { TextColor3 = p.slow },
		selectedRow = { BackgroundColor3 = p.accent },
		divider = { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = p.border, BorderSizePixel = 0 },
		label = label,
		heading = table.clone(label),
		dim = { TextColor3 = p.dimText },
		fieldRow = {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			layout = { direction = "horizontal", gap = 4, align = "center" },
		},
		fieldKey = {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			TextColor3 = p.text,
			Font = Enum.Font.Code,
			TextSize = 13,
		},
		field = {
			Size = UDim2.new(0, 120, 1, 0),
			BackgroundColor3 = p.input,
			BorderSizePixel = 0,
			TextColor3 = p.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Code,
			TextSize = 13,
			ClearTextOnFocus = false,
			padding = { x = 4 },
			cornerRadius = 3,
		},
	}
end

local styles = buildStyles(palette.value)

function setPalette(next: Theme.Palette)
	for name, style in buildStyles(next) do
		styles[name] = style
	end
	palette.value = next
end

local StateField = Rivue.defineComponent({
	name = "StateField",
	props = {
		target = { required = true },
		field = { type = "string", required = true },
		value = { type = "string", required = true },
	},
	setup = function(props)
		local draft = Rivue.ref(props.value)
		Rivue.watch(function()
			return props.value
		end, function(value)
			draft.value = value
		end)
		return {
			draft = draft,
			commit = function()
				if draft.value ~= props.value then
					props.target:SetAttribute("RivueEdit", `{props.field}={draft.value}`)
				end
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { Name = ctx.field, class = "fieldRow" }, {
			h("TextLabel", { class = "fieldKey", Text = `{ctx.field} =` }),
			h("TextBox", { Name = "Value", class = "field", model = "draft", onFocusLost = ctx.commit }),
		})
	end,
})

local function detailsChildren(ctx, current: Entry?): { any }
	if not current then
		return {
			h("TextLabel", {
				Name = "Summary",
				class = { "label", "dim" },
				Text = if #ctx.entries == 0
					then "No components yet. Press Play, and set app.config.devtools = true before app:mount()."
					else "Click a component to see its props and state.",
			}),
		}
	end
	local script, line = resolveSource(current.source)
	local stateRows = {}
	for text in string.gmatch(current.state, "[^\n]+") do
		local key, value = string.match(text, "^(.-) = (.*)$")
		if key and isEditable(value) then
			table.insert(stateRows, h(StateField, { key = key, field = key, target = current.instance, value = value }))
		else
			table.insert(stateRows, h("TextLabel", { key = text, class = "label", Text = text }))
		end
	end
	return {
		h("TextLabel", {
			Name = "Summary",
			class = "label",
			Text = `<{current.name}>  rendered {current.renders}×, {formatMs(current.renderMs)}`,
		}),
		h("TextLabel", { Name = "Cause", class = { "label", "dim" }, Text = causeText(current.trigger) }),
		if script
			then h("TextButton", {
				Name = "OpenSource",
				class = "tool",
				Size = UDim2.new(0, 0, 0, 22),
				Text = "Open source",
				onClick = function()
					if openScript then
						openScript(script, line or 1)
					end
				end,
			})
			else nil,
		h("TextLabel", { Name = "PropsHeading", class = { "heading", "dim" }, Text = "Props" }),
		h("TextLabel", {
			Name = "Props",
			class = "label",
			Text = if current.props == "" then "(none)" else current.props,
		}),
		h("TextLabel", { Name = "StateHeading", class = { "heading", "dim" }, Text = "State" }),
		h("Frame", {
			Name = "State",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			layout = { gap = 2 },
		}, if #stateRows == 0 then { h("TextLabel", { class = "label", Text = "(none)" }) } else stateRows),
		h("TextLabel", { Name = "ProvidesHeading", class = { "heading", "dim" }, Text = "Provides" }),
		h("TextLabel", {
			Name = "Provides",
			class = "label",
			Text = if current.provides == "" then "(none)" else current.provides,
		}),
		h("TextLabel", { Name = "InjectsHeading", class = { "heading", "dim" }, Text = "Injects" }),
		h("TextLabel", {
			Name = "Injects",
			class = "label",
			Text = if current.injects == "" then "(none)" else current.injects,
		}),
	}
end

local function timelineText(entry: TimelineEntry): string
	local ms = if entry.ms == "" then "" else `  {entry.ms} ms`
	local detail = if entry.detail == "" then "" else `  {entry.detail}`
	return `{string.format("%7.2fs", entry.at / 1000)}  {entry.kind}  {entry.label}{detail}{ms}`
end

local App = Rivue.defineComponent({
	name = "RivueDevTools",
	styles = styles,
	setup = function()
		return {
			entries = entries,
			events = events,
			selected = selected,
			collapsed = collapsed,
			paused = paused,
			sortMode = sortMode,
			view = view,
			palette = palette,
			filter = Rivue.ref(""),
			pick = function(instance: Instance)
				selected.value = instance
				Selection:Set({ instance })
			end,
			nextSort = function()
				sortMode.value = NEXT_SORT[sortMode.value]
			end,
			togglePause = function()
				setPaused(not paused.value)
			end,
			reset = resetCounts,
			timeline = timeline,
			routeText = routeText,
			clearEvents = function()
				events.value = {}
			end,
			clearTimeline = function()
				timeline.value = {}
			end,
			showView = function(name: View)
				view.value = name
			end,
		}
	end,
	render = function(ctx)
		local _ = ctx.palette
		local query = string.lower(ctx.filter)
		local tree = ctx.sortMode == "tree"
		local ordered = sorted(ctx.entries, ctx.sortMode)
		-- A match keeps its parents, so it still shows where it sits in the tree
		local keep: { [Entry]: boolean }? = nil
		if query ~= "" then
			local matches: { [Entry]: boolean } = {}
			keep = matches
			for i, entry in ordered do
				if not string.find(string.lower(entry.name), query, 1, true) then
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
		local current: Entry? = nil
		local hiddenBelow: number? = nil
		for _, entry in ordered do
			if entry.instance == ctx.selected then
				current = entry
			end
			if hiddenBelow and entry.depth > hiddenBelow then
				continue
			end
			hiddenBelow = nil
			if tree and ctx.collapsed[entry.instance] then
				hiddenBelow = entry.depth
			end
			if keep == nil or keep[entry] then
				table.insert(shown, entry)
			end
		end
		local components = ctx.view == "components"
		local list = if ctx.view == "timeline"
			then Rivue.hFor(ctx.timeline, function(entry: TimelineEntry)
				return h("TextLabel", {
					key = entry.seq,
					class = "row",
					padding = { left = 6 },
					Text = timelineText(entry),
				})
			end)
			elseif ctx.view == "router" then h("TextLabel", {
				Name = "Route",
				class = "label",
				Text = if ctx.routeText == ""
					then "No router yet. Use RivueRouter in an app with app.config.devtools = true."
					else ctx.routeText,
			})
			elseif components then Rivue.hFor(shown, function(entry: Entry)
				local slow = entry.renderMs >= SLOW_MS
				local indent = if tree then 6 + INDENT * entry.depth + INDENT + 2 else 6
				return h("TextButton", {
					key = entry.instance,
					class = {
						"row",
						if entry.changed then "changedRow" else nil,
						if slow then "slowRow" else nil,
						if entry.instance == ctx.selected then "selectedRow" else nil,
					},
					padding = { left = indent },
					Text = `<{entry.name}>  {entry.renders}{if slow then `  {formatMs(entry.renderMs)}` else ""}`,
					onClick = function()
						ctx.pick(entry.instance)
					end,
					onMouseEnter = function()
						Highlight.show(entry.instance)
					end,
					onMouseLeave = Highlight.hide,
				}, {
					if tree and entry.hasChildren
						then h("TextButton", {
							Name = "Toggle",
							class = "toggle",
							Text = if ctx.collapsed[entry.instance] then "▸" else "▾",
							onClick = function()
								toggleCollapsed(entry.instance)
							end,
						})
						else nil,
				})
			end)
			else Rivue.hFor(ctx.events, function(event: EmitEvent)
				return h("TextButton", {
					key = event.id,
					class = "row",
					padding = { left = 6 },
					Text = `<{event.name}>  {event.event}({event.args})`,
					onClick = function()
						ctx.pick(event.instance)
					end,
					onMouseEnter = function()
						Highlight.show(event.instance)
					end,
					onMouseLeave = Highlight.hide,
				})
			end)

		return h("Frame", { class = "panel" }, {
			h("Frame", { Name = "HeaderRow", class = "headerRow" }, {
				h("TextLabel", {
					Name = "Header",
					class = "header",
					Text = `Rivue {Rivue.version} · {#ctx.entries} components{if ctx.paused then " · paused" else ""}`,
				}),
				h("TextButton", {
					Name = "ComponentsTab",
					class = { "tool", if components then "activeTool" else nil },
					Text = "Components",
					onClick = function()
						ctx.showView("components")
					end,
				}),
				h("TextButton", {
					Name = "EventsTab",
					class = { "tool", if ctx.view == "events" then "activeTool" else nil },
					Text = "Events",
					onClick = function()
						ctx.showView("events")
					end,
				}),
				h("TextButton", {
					Name = "TimelineTab",
					class = { "tool", if ctx.view == "timeline" then "activeTool" else nil },
					Text = "Timeline",
					onClick = function()
						ctx.showView("timeline")
					end,
				}),
				h("TextButton", {
					Name = "RouterTab",
					class = { "tool", if ctx.view == "router" then "activeTool" else nil },
					Text = "Router",
					onClick = function()
						ctx.showView("router")
					end,
				}),
			}),
			if components
				then h("TextBox", {
					Name = "Filter",
					class = "filter",
					model = "filter",
					PlaceholderText = "Filter by name",
				})
				else nil,
			h("Frame", { Name = "Toolbar", class = "toolbar" }, {
				if components
					then h("TextButton", {
						Name = "Sort",
						class = "tool",
						Text = `Sort: {SORT_LABELS[ctx.sortMode]}`,
						onClick = ctx.nextSort,
					})
					else nil,
				h("TextButton", {
					Name = "Pause",
					class = { "tool", if ctx.paused then "activeTool" else nil },
					Text = if ctx.paused then "Resume" else "Pause",
					onClick = ctx.togglePause,
				}),
				if components
					then h("TextButton", { Name = "Reset", class = "tool", Text = "Reset counts", onClick = ctx.reset })
					elseif ctx.view == "router" then nil
					else h("TextButton", {
						Name = "Clear",
						class = "tool",
						Text = "Clear",
						onClick = if ctx.view == "timeline" then ctx.clearTimeline else ctx.clearEvents,
					}),
			}),
			h("ScrollingFrame", {
				Name = if components
					then "Tree"
					elseif ctx.view == "timeline" then "Timeline"
					elseif ctx.view == "router" then "RouterView"
					else "Events",
				class = "list",
				Size = if components then UDim2.new(1, 0, 0.55, -84) else UDim2.new(1, 0, 1, -56),
			}, { list }),
			if components then h("Frame", { Name = "Divider", class = "divider" }) else nil,
			if components
				then h("ScrollingFrame", {
					Name = "Details",
					class = "list",
					Size = UDim2.new(1, 0, 0.45, -6),
					layout = { gap = 3 },
					padding = { x = 4, y = 4 },
				}, detailsChildren(ctx, current))
				else nil,
		})
	end,
})

return {
	App = App,
	start = start,
	collect = collect,
	entries = entries,
	events = events,
	selected = selected,
	paused = paused,
	sortMode = sortMode,
	view = view,
	timeline = timeline,
	routeText = routeText,
	palette = palette,
	setPalette = setPalette,
	resetCounts = resetCounts,
	resolveSource = resolveSource,
	setOpenScript = function(handler: ((script: LuaSourceContainer, line: number) -> ())?)
		openScript = handler
	end,
	SLOW_MS = SLOW_MS,
}
