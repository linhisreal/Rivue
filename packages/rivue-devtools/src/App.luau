--!nonstrict
-- The DevTools window and the data behind it. Main.server.luau wires it into the plugin; tests
-- mount it on their own.

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local Rivue = require(script.Parent:WaitForChild("RivueUI"))
local Highlight = require(script.Parent:WaitForChild("Highlight"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local h = Rivue.h

local TAG = "RivueComponent"
-- An eighth of a frame at 60 fps. A render this slow is worth a look even if it's rare
local SLOW_MS = 2
local MAX_EVENTS = 100
local INDENT = 14

export type Entry = {
	instance: Instance,
	depth: number,
	name: string,
	props: string,
	state: string,
	-- Since the last Reset
	renders: number,
	renderMs: number,
	trigger: string,
	source: string,
	hasChildren: boolean,
	-- Rendered again since the last refresh
	changed: boolean,
}

export type EmitEvent = {
	id: number,
	name: string,
	event: string,
	args: string,
	instance: Instance,
}

export type SortMode = "tree" | "renders" | "slowest"

local SORT_LABELS: { [SortMode]: string } = { tree = "tree", renders = "most renders", slowest = "slowest" }
local NEXT_SORT: { [SortMode]: SortMode } = { tree = "renders", renders = "slowest", slowest = "tree" }

local entries = Rivue.shallowRef({} :: { Entry })
local events = Rivue.shallowRef({} :: { EmitEvent })
local selected = Rivue.shallowRef(nil :: Instance?)
local collapsed = Rivue.shallowRef(setmetatable({}, { __mode = "k" }) :: any)
local paused = Rivue.ref(false)
local sortMode = Rivue.ref("tree" :: SortMode)
local view = Rivue.ref("components" :: "components" | "events")
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
				hasChildren = false,
				changed = before ~= nil and renders > before,
			})
		end
	end
	-- Full names put children right after their parents
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

-- Many renders in one frame become one refresh
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

-- Defined with the styles below
local setPalette: (next: Theme.Palette) -> ()

--- Starts following tagged components and Studio's theme. Returns a function that stops
local function start(): () -> ()
	local conns = {
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
			-- A pooled Instance can come back as another component, which starts counting at 1
			baselines[instance] = nil
			refreshSoon()
		end),
	}
	local stopTheme = Theme.watch(setPalette)
	for _, instance in CollectionService:GetTagged(TAG) do
		watch(instance)
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
	-- A source that isn't a script path ("[string ...]" from loadstring) must not break the render
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

-- Numbers, booleans and strings can be typed back in; tables and Roblox types can't
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
			Size = UDim2.new(1, -150, 1, 0),
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

-- Class styles are read on every render, so a theme change swaps their contents in place
local styles = buildStyles(palette.value)

function setPalette(next: Theme.Palette)
	for name, style in buildStyles(next) do
		styles[name] = style
	end
	palette.value = next
end

--- One editable state value. Enter or clicking away sends it to the game
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
	}
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
			clearEvents = function()
				events.value = {}
			end,
			showView = function(name: "components" | "events")
				view.value = name
			end,
		}
	end,
	render = function(ctx)
		local _ = ctx.palette
		local query = string.lower(ctx.filter)
		local tree = ctx.sortMode == "tree" and query == ""
		local shown = {}
		local current: Entry? = nil
		local hiddenBelow: number? = nil
		for _, entry in sorted(ctx.entries, ctx.sortMode) do
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
			if query == "" or string.find(string.lower(entry.name), query, 1, true) then
				table.insert(shown, entry)
			end
		end
		local components = ctx.view == "components"
		local list = if components
			then Rivue.hFor(shown, function(entry: Entry)
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
					class = { "tool", if components then nil else "activeTool" },
					Text = "Events",
					onClick = function()
						ctx.showView("events")
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
					else h(
						"TextButton",
						{ Name = "Clear", class = "tool", Text = "Clear", onClick = ctx.clearEvents }
					),
			}),
			h("ScrollingFrame", {
				Name = if components then "Tree" else "Events",
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
	palette = palette,
	setPalette = setPalette,
	resetCounts = resetCounts,
	resolveSource = resolveSource,
	setOpenScript = function(handler: ((script: LuaSourceContainer, line: number) -> ())?)
		openScript = handler
	end,
	SLOW_MS = SLOW_MS,
}
