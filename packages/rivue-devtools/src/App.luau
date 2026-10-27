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
local MAX_EVENTS = 100
local INDENT = 14
local KINDS = { "render", "emit", "navigation", "request" }

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
export type View = "components" | "events" | "timeline" | "router" | "settings"

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

export type Settings = { slowMs: number, timelineLimit: number, highlightUpdates: boolean }
export type SettingsStore = { get: (key: string) -> any, set: (key: string, value: any) -> () }

local DEFAULT_SETTINGS: Settings = { slowMs = 2, timelineLimit = 200, highlightUpdates = false }
local settings = Rivue.reactive(table.clone(DEFAULT_SETTINGS)) :: Settings
local settingsStore: SettingsStore? = nil
local kindsShown = Rivue.reactive({ render = true, emit = true, navigation = true, request = true })
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
	while #list > settings.timelineLimit do
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

local function setSettingsStore(store: SettingsStore?)
	settingsStore = store
	if not store then
		return
	end
	for key, default in DEFAULT_SETTINGS do
		local saved = store.get(key)
		if type(saved) == type(default) then
			(settings :: any)[key] = saved
		end
	end
end

local function setSetting(key: string, value: any)
	(settings :: any)[key] = value
	if settingsStore then
		settingsStore.set(key, value)
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
				if name == "RivueRenders" and settings.highlightUpdates then
					Highlight.flash(instance)
				end
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
		Highlight.clearFlashes()
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

local function lines(text: string): { string }
	local list = {}
	for line in string.gmatch(text, "[^\n]+") do
		table.insert(list, line)
	end
	return list
end

local function splitPair(line: string): (string, string)
	local key, value = string.match(line, "^(.-) = (.*)$")
	return key or line, value or ""
end

local function tableFields(text: string): { { key: string, value: string } }
	local inner = string.match(text, "^{ (.*) }$")
	local fields = {}
	if not inner then
		return fields
	end
	local depth, quoted, start = 0, false, 1
	local function push(piece: string)
		local key, value = splitPair(piece)
		table.insert(fields, { key = key, value = value })
	end
	for i = 1, #inner do
		local c = string.sub(inner, i, i)
		if c == '"' then
			quoted = not quoted
		elseif not quoted and c == "{" then
			depth += 1
		elseif not quoted and c == "}" then
			depth -= 1
		elseif not quoted and depth == 0 and c == "," then
			push(string.sub(inner, start, i - 1))
			start = i + 2
		end
	end
	push(string.sub(inner, start))
	return fields
end

export type RouteInfo = {
	name: string,
	fields: { { section: string, key: string, value: string } },
	history: { { name: string, current: boolean } },
}

local function parseRoute(text: string): RouteInfo?
	if text == "" then
		return nil
	end
	local info: RouteInfo = { name = "", fields = {}, history = {} }
	for _, line in lines(text) do
		local key, value = splitPair(line)
		if key == "name" then
			info.name = value
		elseif key == "history" then
			for item in string.gmatch(value, "[^,%s]+") do
				local current = string.match(item, "^%[(.*)%]$")
				table.insert(info.history, { name = current or item, current = current ~= nil })
			end
		else
			for _, field in tableFields(value) do
				table.insert(info.fields, { section = key, key = field.key, value = field.value })
			end
		end
	end
	return info
end

local function findComponent(name: string): Instance?
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:GetAttribute("RivueComponent") == name then
			return instance
		end
	end
	return nil
end

local ROW = 24
local KEY_WIDTH = 104
local MS_WIDTH = 64
local COUNT_WIDTH = 34

local function buildStyles(p: Theme.Palette): { [string]: any }
	local function label(size: number, color: Color3, mono: boolean?): { [string]: any }
		return {
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			TextSize = size,
			Font = if mono then Enum.Font.Code else Enum.Font.SourceSans,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}
	end
	local cell = function(width: number, align: Enum.TextXAlignment?, mono: boolean?)
		local style = label(13, p.text, mono)
		style.Size = UDim2.new(0, width, 1, 0)
		style.TextXAlignment = align or Enum.TextXAlignment.Left
		return style
	end
	local fill = function(mono: boolean?)
		local style = label(13, p.text, mono)
		style.Size = UDim2.fromScale(0, 1)
		style.flex = "fill"
		return style
	end
	local auto = function(mono: boolean?)
		local style = label(13, p.text, mono)
		style.Size = UDim2.fromScale(0, 1)
		style.AutomaticSize = Enum.AutomaticSize.X
		return style
	end
	local button = {
		Size = UDim2.new(0, 0, 0, ROW),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = p.button,
		BorderSizePixel = 0,
		TextColor3 = p.text,
		TextSize = 13,
		Font = Enum.Font.SourceSans,
		AutoButtonColor = false,
		padding = { x = 10 },
		cornerRadius = 4,
		hover = { BackgroundColor3 = p.buttonHover },
	}
	return {
		panel = {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = p.background,
			BorderSizePixel = 0,
			padding = 8,
		},
		tabBar = {
			Size = UDim2.new(1, 0, 0, ROW + 4),
			BackgroundColor3 = p.input,
			BorderSizePixel = 0,
			cornerRadius = 6,
			padding = 2,
		},
		tab = {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BackgroundColor3 = p.accent,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			cornerRadius = 4,
			padding = { x = 10 },
			layout = { direction = "horizontal", gap = 6, align = "center" },
			hover = { BackgroundTransparency = 0.85 },
		},
		activeTab = { BackgroundTransparency = 0, hover = { BackgroundTransparency = 0 } },
		tabLabel = auto(),
		tabCount = (function()
			local style = auto(true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			return style
		end)(),
		activeTabText = { TextColor3 = p.accentText },
		pill = {
			Size = UDim2.fromOffset(COUNT_WIDTH, 18),
			BackgroundColor3 = p.pill,
			BorderSizePixel = 0,
			TextColor3 = p.dimText,
			Font = Enum.Font.Code,
			TextSize = 12,
			cornerRadius = 9,
		},
		hotPill = { BackgroundColor3 = p.changed, TextColor3 = p.accentText },
		toolbar = { Size = UDim2.new(1, 0, 0, ROW), BackgroundTransparency = 1 },
		tool = button,
		activeTool = { BackgroundColor3 = p.accent, TextColor3 = p.accentText, hover = { BackgroundColor3 = p.accent } },
		filter = {
			Size = UDim2.new(0, 0, 0, ROW),
			BackgroundColor3 = p.input,
			BorderSizePixel = 0,
			TextColor3 = p.text,
			PlaceholderColor3 = p.dimText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 13,
			Font = Enum.Font.SourceSans,
			ClearTextOnFocus = false,
			padding = { x = 8 },
			cornerRadius = 4,
			flex = "fill",
		},
		list = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = p.dimText,
			layout = { gap = 2 },
			padding = { right = 6 },
		},
		row = {
			Size = UDim2.new(1, 0, 0, ROW),
			BackgroundColor3 = p.rowHover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			cornerRadius = 4,
			padding = { x = 6 },
			layout = { direction = "horizontal", gap = 6, align = "center" },
			hover = { BackgroundTransparency = 0 },
		},
		selectedRow = {
			BackgroundColor3 = p.accent,
			BackgroundTransparency = 0.7,
			hover = { BackgroundTransparency = 0.6 },
		},
		toggle = {
			Size = UDim2.new(0, 12, 1, 0),
			BackgroundTransparency = 1,
			TextColor3 = p.dimText,
			TextSize = 10,
		},
		dot = { Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0, BackgroundColor3 = p.changed, cornerRadius = 3 },
		name = auto(true),
		changedName = { TextColor3 = p.changed },
		slowName = { TextColor3 = p.slow },
		ms = (function()
			local style = cell(MS_WIDTH, Enum.TextXAlignment.Right, true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			return style
		end)(),
		slowMs = { TextColor3 = p.slow },
		time = (function()
			local style = cell(52, Enum.TextXAlignment.Left, true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			return style
		end)(),
		kind = cell(80, Enum.TextXAlignment.Left, true),
		label = auto(true),
		detail = (function()
			local style = fill(true)
			style.TextColor3 = p.dimText
			return style
		end)(),
		text = (function()
			local style = label(13, p.text)
			style.AutomaticSize = Enum.AutomaticSize.XY
			return style
		end)(),
		dim = { TextColor3 = p.dimText },
		strong = { Font = Enum.Font.SourceSansBold, TextSize = 15 },
		divider = {
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
		},
		dividerLine = {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 0.5, 0),
			BorderSizePixel = 0,
			BackgroundColor3 = p.border,
		},
		card = {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = p.card,
			BorderSizePixel = 0,
			cornerRadius = 6,
			padding = 8,
			layout = { gap = 2 },
		},
		cardTitle = {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			layout = { direction = "horizontal", gap = 6, align = "center" },
		},
		heading = (function()
			local style = auto()
			style.TextColor3 = p.dimText
			style.TextSize = 12
			style.Font = Enum.Font.SourceSansSemibold
			return style
		end)(),
		kv = {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			layout = { direction = "horizontal", gap = 8, align = "center" },
		},
		kvKey = (function()
			local style = cell(KEY_WIDTH, Enum.TextXAlignment.Left, true)
			style.TextSize = 12
			style.TextColor3 = p.dimText
			return style
		end)(),
		kvValue = (function()
			local style = fill(true)
			style.TextSize = 12
			return style
		end)(),
		field = {
			Size = UDim2.new(0, 0, 1, 0),
			flex = "fill",
			BackgroundColor3 = p.input,
			BorderSizePixel = 0,
			TextColor3 = p.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Code,
			TextSize = 12,
			ClearTextOnFocus = false,
			padding = { x = 6 },
			cornerRadius = 3,
		},
		chip = {
			Size = UDim2.new(0, 0, 0, ROW - 4),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = p.button,
			BorderSizePixel = 0,
			TextColor3 = p.dimText,
			TextSize = 12,
			Font = Enum.Font.SourceSans,
			AutoButtonColor = false,
			cornerRadius = 10,
			padding = { x = 10 },
		},
		bar = { Size = UDim2.fromOffset(40, 4), BackgroundColor3 = p.pill, BorderSizePixel = 0, cornerRadius = 2 },
		barFill = { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, cornerRadius = 2 },
		statusBar = { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 },
		statusText = (function()
			local style = auto()
			style.TextColor3 = p.dimText
			style.TextSize = 12
			return style
		end)(),
		smallTool = { Size = UDim2.new(0, 0, 0, 20), TextSize = 12, padding = { x = 8 } },
		render = { TextColor3 = p.render, BackgroundColor3 = p.render },
		emit = { TextColor3 = p.emit, BackgroundColor3 = p.emit },
		navigation = { TextColor3 = p.navigation, BackgroundColor3 = p.navigation },
		request = { TextColor3 = p.request, BackgroundColor3 = p.request },
	}
end

local styles = buildStyles(palette.value)

function setPalette(next: Theme.Palette)
	for name, style in buildStyles(next) do
		styles[name] = style
	end
	palette.value = next
end

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
				h("TextLabel", { class = "toggle", Text = if ctx.open then "▾" else "▸" }),
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

local KeyValue = Rivue.defineComponent({
	name = "KeyValue",
	styles = styles,
	props = { field = { type = "string", required = true }, value = { type = "string", required = true } },
	render = function(ctx)
		return h("Frame", { Name = ctx.field, class = "kv" }, {
			h("TextLabel", { Name = "Key", class = "kvKey", Text = ctx.field }),
			h("TextLabel", { Name = "Value", class = "kvValue", Text = ctx.value }),
		})
	end,
})

local StateField = Rivue.defineComponent({
	name = "StateField",
	styles = styles,
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
		return h("Frame", { Name = ctx.field, class = "kv" }, {
			h("TextLabel", { Name = "Key", class = "kvKey", Text = ctx.field }),
			h("TextBox", { Name = "Value", class = "field", model = "draft", onFocusLost = ctx.commit }),
		})
	end,
})

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

local function emptyNote(name: string, text: string): any
	return h("TextLabel", {
		Name = name,
		class = { "text", "dim" },
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Text = text,
	})
end

local function fieldRows(text: string, target: Instance?): { any }
	local rows = {}
	for _, line in lines(text) do
		local key, value = splitPair(line)
		if target and isEditable(value) then
			table.insert(rows, h(StateField, { key = key, field = key, target = target, value = value }))
		else
			table.insert(rows, h(KeyValue, { key = key, field = key, value = value }))
		end
	end
	if #rows == 0 then
		table.insert(rows, h("TextLabel", { class = { "text", "dim" }, Text = "(none)" }))
	end
	return rows
end

local function keyList(name: string, keys: { string }): { any }
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

local Details = Rivue.defineComponent({
	name = "Details",
	styles = styles,
	props = { entry = { required = true } },
	render = function(ctx)
		local current: Entry = ctx.entry
		local script, line = resolveSource(current.source)
		local provides = lines(current.provides)
		local injects = lines(current.injects)
		local slow = current.renderMs >= settings.slowMs
		return h(Rivue.Fragment, nil, {
			h("Frame", { Name = "Overview", class = "card" }, {
				h(Rivue.Row, { gap = 8, align = "center", Size = UDim2.new(1, 0, 0, ROW) }, {
					h("TextLabel", { Name = "Title", class = { "text", "strong" }, Text = `<{current.name}>` }),
					h(Rivue.Spacer),
					if script
						then h("TextButton", {
							Name = "OpenSource",
							class = "tool",
							Text = "Open source",
							onClick = function()
								if openScript then
									openScript(script, line or 1)
								end
							end,
						})
						else nil,
				}),
				h(Rivue.Row, { gap = 6, align = "center", Size = UDim2.new(1, 0, 0, 18) }, {
					h("TextLabel", { Name = "Renders", class = { "text", "dim" }, Text = `{current.renders} renders` }),
					h("TextLabel", { class = { "text", "dim" }, Text = "·" }),
					h("TextLabel", {
						Name = "Time",
						class = { "text", "dim" },
						TextColor3 = if slow then palette.value.slow else nil,
						Text = formatMs(current.renderMs),
					}),
					h("TextLabel", { class = { "text", "dim" }, Text = "·" }),
					h("TextLabel", { Name = "Cause", class = { "text", "dim" }, Text = causeText(current.trigger) }),
				}),
			}),
			h(Card, { key = "props", title = "Props" }, fieldRows(current.props, nil)),
			h(Card, { key = "state", title = "State" }, fieldRows(current.state, current.instance)),
			h(Card, { key = "provides", title = "Provides", count = #provides }, keyList("Provides", provides)),
			h(Card, { key = "injects", title = "Injects", count = #injects }, keyList("Injects", injects)),
		})
	end,
})

local function componentRow(ctx, entry: Entry, tree: boolean): any
	local slow = entry.renderMs >= settings.slowMs
	local isSelected = entry.instance == ctx.selected
	return h("TextButton", {
		key = entry.instance,
		class = { "row", if isSelected then "selectedRow" else nil },
		padding = { left = 6 + (if tree then INDENT * entry.depth else 0), right = 6 },
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
			elseif tree then h("Frame", { Name = "Gap", class = "toggle" })
			else nil,
		h("TextLabel", {
			Name = "Label",
			class = {
				"name",
				if entry.changed then "changedName" else nil,
				if slow then "slowName" else nil,
			},
			Text = `<{entry.name}>`,
		}),
		h("Frame", {
			Name = "Dot",
			class = "dot",
			BackgroundTransparency = if entry.changed then 0 else 1,
		}),
		h(Rivue.Spacer),
		h("TextLabel", {
			Name = "Ms",
			class = { "ms", if slow then "slowMs" else nil },
			Text = if slow then formatMs(entry.renderMs) else "",
		}),
		h(Pill, { key = "renders", text = tostring(entry.renders), tone = if entry.changed then "hot" else nil }),
	})
end

local App = Rivue.defineComponent({
	name = "RivueDevTools",
	styles = styles,
	setup = function()
		local split = Rivue.ref(0.55)
		local dragging = false
		local body = Rivue.useTemplateRef("body")
		local route = Rivue.computed(function()
			return parseRoute(routeText.value)
		end)
		local shownTimeline = Rivue.computed(function()
			local list = {}
			for _, entry in timeline.value do
				if kindsShown[entry.kind] ~= false then
					table.insert(list, entry)
				end
			end
			return list
		end)
		local slowestTimeline = Rivue.computed(function()
			local most = 0
			for _, entry in shownTimeline.value do
				most = math.max(most, tonumber(entry.ms) or 0)
			end
			return most
		end)

		local slowDraft = Rivue.ref(tostring(settings.slowMs))
		local limitDraft = Rivue.ref(tostring(settings.timelineLimit))

		local function pick(instance: Instance)
			selected.value = instance
			Selection:Set({ instance })
		end

		return {
			entries = entries,
			events = events,
			selected = selected,
			collapsed = collapsed,
			paused = paused,
			sortMode = sortMode,
			view = view,
			palette = palette,
			timeline = shownTimeline,
			timelineCount = Rivue.computed(function()
				return #timeline.value
			end),
			slowestTimeline = slowestTimeline,
			kindsShown = kindsShown,
			route = route,
			settings = settings,
			split = split,
			filter = Rivue.ref(""),
			pick = pick,
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
			clearTimeline = function()
				timeline.value = {}
			end,
			showView = function(name: View)
				view.value = name
			end,
			toggleKind = function(kind: string)
				kindsShown[kind] = not kindsShown[kind]
			end,
			openTimelineEntry = function(entry: TimelineEntry)
				local name = if entry.kind == "emit" then string.match(entry.label, "^([^:]+):") else entry.label
				local instance = if entry.kind == "render" or entry.kind == "emit"
					then findComponent(name or "")
					else nil
				if instance then
					pick(instance)
					view.value = "components"
				end
			end,
			setSetting = setSetting,
			slowDraft = slowDraft,
			limitDraft = limitDraft,
			commitSlow = function()
				local value = tonumber(slowDraft.value)
				if value and value > 0 then
					setSetting("slowMs", value)
				end
				slowDraft.value = tostring(settings.slowMs)
			end,
			commitLimit = function()
				local value = tonumber(limitDraft.value)
				if value and value >= 10 then
					setSetting("timelineLimit", math.floor(value))
				end
				limitDraft.value = tostring(settings.timelineLimit)
			end,
			startDrag = function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = true
				end
			end,
			drag = function(input: InputObject)
				local frame = body.value
				if not dragging or not frame or input.UserInputType ~= Enum.UserInputType.MouseMovement then
					return
				end
				local height = frame.AbsoluteSize.Y
				if height > 0 then
					split.value = math.clamp((input.Position.Y - frame.AbsolutePosition.Y) / height, 0.2, 0.85)
				end
			end,
			stopDrag = function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end,
		}
	end,
	render = function(ctx)
		local _ = ctx.palette
		local query = string.lower(ctx.filter)
		local tree = ctx.sortMode == "tree"
		local ordered = sorted(ctx.entries, ctx.sortMode)
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

		local viewName = ctx.view
		local content: any
		if viewName == "components" then
			content = h(Rivue.Column, { Name = "ComponentsView", gap = 6, Size = UDim2.fromScale(1, 1) }, {
				h(Rivue.Row, { Name = "Toolbar", class = "toolbar", gap = 6, align = "center" }, {
					h(
						"TextBox",
						{ Name = "Filter", class = "filter", model = "filter", PlaceholderText = "Filter by name" }
					),
					h("TextButton", {
						Name = "Sort",
						class = "tool",
						Text = `Sort: {SORT_LABELS[ctx.sortMode]}`,
						onClick = ctx.nextSort,
					}),
					h("TextButton", { Name = "Reset", class = "tool", Text = "Reset counts", onClick = ctx.reset }),
				}),
				h("Frame", {
					Name = "Body",
					ref = "body",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, -30),
					onInputChanged = ctx.drag,
					onInputEnded = ctx.stopDrag,
				}, {
					h("ScrollingFrame", {
						Name = "Tree",
						class = "list",
						Size = UDim2.new(1, 0, ctx.split, -4),
					}, {
						Rivue.hFor(shown, function(entry: Entry)
							return componentRow(ctx, entry, tree)
						end),
					}),
					h("TextButton", {
						Name = "Divider",
						class = "divider",
						Position = UDim2.new(0, 0, ctx.split, -4),
						onInputBegan = ctx.startDrag,
					}, { h("Frame", { class = "dividerLine" }) }),
					h("ScrollingFrame", {
						Name = "Details",
						class = "list",
						Position = UDim2.new(0, 0, ctx.split, 4),
						Size = UDim2.new(1, 0, 1 - ctx.split, -4),
						layout = { gap = 6 },
					}, {
						if current
							then h(Details, { entry = current })
							else emptyNote(
								"Empty",
								if #ctx.entries == 0
									then "No components yet. Press Play, and set app.config.devtools = true before app:mount()."
									else "Click a component to see its props and state."
							),
					}),
				}),
			})
		elseif viewName == "events" then
			content = h(Rivue.Column, { Name = "EventsView", gap = 6, Size = UDim2.fromScale(1, 1) }, {
				h(Rivue.Row, { class = "toolbar", gap = 6, align = "center" }, {
					h("TextLabel", { class = "statusText", Text = "Newest first" }),
					h(Rivue.Spacer),
					h("TextButton", { Name = "Clear", class = "tool", Text = "Clear", onClick = ctx.clearEvents }),
				}),
				h("ScrollingFrame", { Name = "Events", class = "list", Size = UDim2.new(1, 0, 1, -30) }, {
					Rivue.hFor(ctx.events, function(event: EmitEvent)
						return h("TextButton", {
							key = event.id,
							class = "row",
							onClick = function()
								ctx.pick(event.instance)
							end,
							onMouseEnter = function()
								Highlight.show(event.instance)
							end,
							onMouseLeave = Highlight.hide,
						}, {
							h("TextLabel", { Name = "Label", class = "label", Text = `<{event.name}>` }),
							h(
								"TextLabel",
								{ Name = "Detail", class = { "detail", "emit" }, Text = `{event.event}({event.args})` }
							),
						})
					end),
				}),
			})
		elseif viewName == "timeline" then
			local slowest = ctx.slowestTimeline
			local chips = {}
			for i, kind in KINDS do
				local on = ctx.kindsShown[kind] ~= false
				chips[i] = h("TextButton", {
					key = kind,
					Name = `Chip_{kind}`,
					class = { "chip", if on then kind else nil },
					BackgroundTransparency = if on then 0.8 else 0,
					Text = kind,
					onClick = function()
						ctx.toggleKind(kind)
					end,
				})
			end
			content = h(Rivue.Column, { Name = "TimelineView", gap = 6, Size = UDim2.fromScale(1, 1) }, {
				h(Rivue.Row, { class = "toolbar", gap = 6, align = "center" }, {
					h(Rivue.Fragment, nil, chips),
					h(Rivue.Spacer),
					h("TextButton", { Name = "Clear", class = "tool", Text = "Clear", onClick = ctx.clearTimeline }),
				}),
				h("ScrollingFrame", { Name = "Timeline", class = "list", Size = UDim2.new(1, 0, 1, -30) }, {
					Rivue.hFor(ctx.timeline, function(entry: TimelineEntry)
						local ms = tonumber(entry.ms)
						return h("TextButton", {
							key = entry.seq,
							class = "row",
							onClick = function()
								ctx.openTimelineEntry(entry)
							end,
						}, {
							h(
								"TextLabel",
								{ Name = "Time", class = "time", Text = string.format("%.2fs", entry.at / 1000) }
							),
							h("TextLabel", {
								Name = "Kind",
								class = { "kind", entry.kind },
								BackgroundTransparency = 1,
								Text = entry.kind,
							}),
							h("TextLabel", { Name = "Label", class = "label", Text = entry.label }),
							h("TextLabel", { Name = "Detail", class = "detail", Text = entry.detail }),
							h("Frame", { Name = "Bar", class = "bar", BackgroundTransparency = if ms then 0 else 1 }, {
								if ms
									then h("Frame", {
										class = { "barFill", entry.kind },
										Size = UDim2.fromScale(
											if slowest > 0 then math.clamp(ms / slowest, 0.04, 1) else 0,
											1
										),
									})
									else nil,
							}),
							h("TextLabel", { Name = "Ms", class = "ms", Text = if ms then `{entry.ms} ms` else "" }),
						})
					end),
				}),
			})
		elseif viewName == "router" then
			local info: RouteInfo? = ctx.route
			if not info then
				content =
					emptyNote("Route", "No router yet. Use RivueRouter in an app with app.config.devtools = true.")
			else
				local sections = {}
				for _, section in { "params", "query", "meta" } do
					local rows = {}
					for _, field in info.fields do
						if field.section == section then
							table.insert(rows, h(KeyValue, { key = field.key, field = field.key, value = field.value }))
						end
					end
					table.insert(
						sections,
						h(
							Card,
							{ key = section, title = section, count = #rows },
							if #rows == 0
								then { h("TextLabel", { class = { "text", "dim" }, Text = "(none)" }) }
								else rows
						)
					)
				end
				content = h(
					"ScrollingFrame",
					{ Name = "RouterView", class = "list", Size = UDim2.fromScale(1, 1), layout = { gap = 6 } },
					{
						h("Frame", { Name = "Current", class = "card" }, {
							h("TextLabel", { class = "heading", Text = "CURRENT ROUTE" }),
							h("TextLabel", { Name = "RouteName", class = { "text", "strong" }, Text = info.name }),
						}),
						h(Rivue.Fragment, nil, sections),
						h(Card, { key = "history", title = "History", count = #info.history }, {
							Rivue.hFor(info.history, function(item, i)
								return h("Frame", {
									key = i,
									Name = `Entry{i}`,
									class = { "row", if item.current then "selectedRow" else nil },
								}, {
									h("TextLabel", {
										Name = "Index",
										class = "kvKey",
										Size = UDim2.new(0, 20, 1, 0),
										Text = tostring(i),
									}),
									h("TextLabel", { Name = "Label", class = "label", Text = item.name }),
									h(Rivue.Spacer),
									if item.current
										then h("TextLabel", { Name = "Current", class = "tabCount", Text = "current" })
										else nil,
								})
							end),
						}),
					}
				)
			end
		else
			content = h("ScrollingFrame", { Name = "SettingsView", class = "list", Size = UDim2.fromScale(1, 1) }, {
				h(Card, { key = "settings", title = "Settings" }, {
					h("Frame", { Name = "SlowMs", class = "kv" }, {
						h("TextLabel", { class = "kvKey", Text = "slow render, ms" }),
						h(
							"TextBox",
							{ Name = "Value", class = "field", model = "slowDraft", onFocusLost = ctx.commitSlow }
						),
					}),
					h("Frame", { Name = "TimelineLimit", class = "kv" }, {
						h("TextLabel", { class = "kvKey", Text = "timeline length" }),
						h(
							"TextBox",
							{ Name = "Value", class = "field", model = "limitDraft", onFocusLost = ctx.commitLimit }
						),
					}),
				}),
			})
		end

		local tabs = {
			h(TabButton, {
				key = "components",
				Name = "ComponentsTab",
				label = "Components",
				active = viewName == "components",
				count = #ctx.entries,
				onSelect = function()
					ctx.showView("components")
				end,
			}),
			h(TabButton, {
				key = "events",
				Name = "EventsTab",
				label = "Events",
				active = viewName == "events",
				count = #ctx.events,
				onSelect = function()
					ctx.showView("events")
				end,
			}),
			h(TabButton, {
				key = "timeline",
				Name = "TimelineTab",
				label = "Timeline",
				active = viewName == "timeline",
				count = ctx.timelineCount,
				onSelect = function()
					ctx.showView("timeline")
				end,
			}),
			h(TabButton, {
				key = "router",
				Name = "RouterTab",
				label = "Router",
				active = viewName == "router",
				onSelect = function()
					ctx.showView("router")
				end,
			}),
			h(TabButton, {
				key = "settings",
				Name = "SettingsTab",
				label = "⚙",
				active = viewName == "settings",
				onSelect = function()
					ctx.showView("settings")
				end,
			}),
		}

		return h("Frame", { class = "panel", layout = { gap = 8 } }, {
			h(Rivue.Row, { Name = "TabBar", class = "tabBar", gap = 2, align = "center" }, tabs),
			h("Frame", { Name = "View", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64) }, { content }),
			h(Rivue.Row, { Name = "StatusBar", class = "statusBar", gap = 6, align = "center" }, {
				h("TextLabel", {
					Name = "Header",
					class = "statusText",
					Text = `Rivue {Rivue.version} · {#ctx.entries} components{if ctx.paused then " · paused" else ""}`,
				}),
				h(Rivue.Spacer),
				h("TextButton", {
					Name = "Highlight",
					class = { "tool", "smallTool", if ctx.settings.highlightUpdates then "activeTool" else nil },
					Text = "Highlight updates",
					onClick = function()
						ctx.setSetting("highlightUpdates", not ctx.settings.highlightUpdates)
					end,
				}),
				h("TextButton", {
					Name = "Pause",
					class = { "tool", "smallTool", if ctx.paused then "activeTool" else nil },
					Text = if ctx.paused then "Resume" else "Pause",
					onClick = ctx.togglePause,
				}),
			}),
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
	settings = settings,
	setSettingsStore = setSettingsStore,
	setSetting = setSetting,
	palette = palette,
	setPalette = setPalette,
	resetCounts = resetCounts,
	resolveSource = resolveSource,
	parseRoute = parseRoute,
	setOpenScript = function(handler: ((script: LuaSourceContainer, line: number) -> ())?)
		openScript = handler
	end,
}
