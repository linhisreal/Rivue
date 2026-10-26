--!nonstrict
-- The DevTools window and the data behind it. Main.server.luau wires it into the plugin; tests
-- mount it on their own.

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local Rivue = require(script.Parent:WaitForChild("Rivue"))
local h = Rivue.h

local TAG = "RivueComponent"
-- An eighth of a frame at 60 fps. A render this slow is worth a look even if it's rare
local SLOW_MS = 2

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
	-- Rendered again since the last refresh
	changed: boolean,
}

export type SortMode = "tree" | "renders" | "slowest"

local SORT_LABELS: { [SortMode]: string } = { tree = "tree", renders = "most renders", slowest = "slowest" }
local NEXT_SORT: { [SortMode]: SortMode } = { tree = "renders", renders = "slowest", slowest = "tree" }

local entries = Rivue.shallowRef({} :: { Entry })
local selected = Rivue.shallowRef(nil :: Instance?)
local paused = Rivue.ref(false)
local sortMode = Rivue.ref("tree" :: SortMode)
local lastRenders: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local baselines: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: RBXScriptConnection } = {}

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
				changed = before ~= nil and renders > before,
			})
		end
	end
	-- Full names put children right after their parents
	table.sort(list, function(a, b)
		return fullName(a.instance) < fullName(b.instance)
	end)
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

local function watch(instance: Instance)
	if not watched[instance] then
		watched[instance] = instance.AttributeChanged:Connect(refreshSoon)
	end
end

--- Starts following tagged components. Returns a function that stops
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
	for _, instance in CollectionService:GetTagged(TAG) do
		watch(instance)
	end
	collect()
	return function()
		for _, conn in conns do
			conn:Disconnect()
		end
		for instance, conn in watched do
			conn:Disconnect()
			watched[instance] = nil
		end
	end
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

local function detailsFor(entry: Entry): string
	local trigger = if entry.trigger == "mount"
		then "first render"
		elseif entry.trigger == "parent" then "its parent updated it (new slots or forceUpdate)"
		elseif entry.trigger == "" then "(unknown)"
		else `{entry.trigger} changed`
	return table.concat({
		`<{entry.name}>  rendered {entry.renders}×, the last one took {formatMs(entry.renderMs)}`,
		`Last render: {trigger}`,
		"",
		"Props",
		if entry.props == "" then "(none)" else entry.props,
		"",
		"State",
		if entry.state == "" then "(none)" else entry.state,
	}, "\n")
end

local App = Rivue.defineComponent({
	name = "RivueDevTools",
	styles = {
		panel = {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(37, 37, 37),
			BorderSizePixel = 0,
			layout = { gap = 4 },
			padding = 6,
		},
		header = {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(150, 150, 150),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 12,
		},
		filter = {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = Color3.fromRGB(46, 46, 46),
			BorderSizePixel = 0,
			TextColor3 = Color3.fromRGB(220, 220, 220),
			PlaceholderColor3 = Color3.fromRGB(120, 120, 120),
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
			BackgroundColor3 = Color3.fromRGB(53, 53, 53),
			BorderSizePixel = 0,
			TextColor3 = Color3.fromRGB(220, 220, 220),
			TextSize = 13,
			padding = { x = 8 },
			cornerRadius = 4,
			hover = { BackgroundColor3 = Color3.fromRGB(66, 66, 66) },
		},
		activeTool = { BackgroundColor3 = Color3.fromRGB(31, 111, 235) },
		row = {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundColor3 = Color3.fromRGB(37, 37, 37),
			BorderSizePixel = 0,
			TextColor3 = Color3.fromRGB(220, 220, 220),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Code,
			TextSize = 14,
			hover = { BackgroundColor3 = Color3.fromRGB(55, 55, 55) },
		},
		changedRow = { TextColor3 = Color3.fromRGB(255, 170, 60) },
		slowRow = { TextColor3 = Color3.fromRGB(255, 95, 95) },
		selectedRow = { BackgroundColor3 = Color3.fromRGB(31, 111, 235) },
		details = {
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(200, 200, 200),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = Enum.Font.Code,
			TextSize = 13,
			TextWrapped = true,
		},
	},
	setup = function()
		return {
			entries = entries,
			selected = selected,
			paused = paused,
			sortMode = sortMode,
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
		}
	end,
	render = function(ctx)
		local query = string.lower(ctx.filter)
		local tree = ctx.sortMode == "tree"
		local shown = {}
		local current: Entry? = nil
		for _, entry in sorted(ctx.entries, ctx.sortMode) do
			if query == "" or string.find(string.lower(entry.name), query, 1, true) then
				table.insert(shown, entry)
			end
			if entry.instance == ctx.selected then
				current = entry
			end
		end

		local details = if current
			then detailsFor(current)
			elseif
				#ctx.entries == 0
			then "No components yet.\n\nPress Play, and set app.config.devtools = true before app:mount()."
			else `Click a component to see its props and state. Orange ones just re-rendered, red ones took over {SLOW_MS} ms.`

		return h("Frame", { class = "panel" }, {
			h("TextLabel", {
				Name = "Header",
				class = "header",
				Text = `Rivue {Rivue.version} · {#ctx.entries} components{if ctx.paused then " · paused" else ""}`,
			}),
			h("TextBox", { Name = "Filter", class = "filter", model = "filter", PlaceholderText = "Filter by name" }),
			h("Frame", { Name = "Toolbar", class = "toolbar" }, {
				h("TextButton", {
					Name = "Sort",
					class = "tool",
					Text = `Sort: {SORT_LABELS[ctx.sortMode]}`,
					onClick = ctx.nextSort,
				}),
				h("TextButton", {
					Name = "Pause",
					class = { "tool", if ctx.paused then "activeTool" else nil },
					Text = if ctx.paused then "Resume" else "Pause",
					onClick = ctx.togglePause,
				}),
				h("TextButton", { Name = "Reset", class = "tool", Text = "Reset counts", onClick = ctx.reset }),
			}),
			h("ScrollingFrame", {
				Name = "Tree",
				Size = UDim2.new(1, 0, 0.55, -76),
				BackgroundTransparency = 1,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				layout = "vertical",
			}, {
				Rivue.hFor(shown, function(entry: Entry)
					local slow = entry.renderMs >= SLOW_MS
					return h("TextButton", {
						key = entry.instance,
						class = {
							"row",
							if entry.changed then "changedRow" else nil,
							if slow then "slowRow" else nil,
							if entry.instance == ctx.selected then "selectedRow" else nil,
						},
						Text = `{if tree then string.rep("  ", entry.depth) else ""}<{entry.name}>  {entry.renders}{if slow
							then `  {formatMs(entry.renderMs)}`
							else ""}`,
						onClick = function()
							ctx.pick(entry.instance)
						end,
					})
				end),
			}),
			h("TextLabel", {
				Name = "Details",
				class = "details",
				Size = UDim2.fromScale(1, 0.45),
				padding = 8,
				Text = details,
			}),
		})
	end,
})

return {
	App = App,
	start = start,
	collect = collect,
	entries = entries,
	selected = selected,
	paused = paused,
	sortMode = sortMode,
	resetCounts = resetCounts,
	SLOW_MS = SLOW_MS,
}
