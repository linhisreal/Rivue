--!nonstrict
-- The DevTools window and the data behind it. Main.server.luau wires it into the plugin; tests
-- mount it on their own.

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local Rivue = require(script.Parent:WaitForChild("Rivue"))
local h = Rivue.h

local TAG = "RivueComponent"

export type Entry = {
	instance: Instance,
	depth: number,
	name: string,
	props: string,
	state: string,
	renders: number,
	-- Rendered again since the last refresh
	changed: boolean,
}

local entries = Rivue.shallowRef({} :: { Entry })
local selected = Rivue.shallowRef(nil :: Instance?)
local lastRenders: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
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
				renders = renders,
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
	if pending then
		return
	end
	pending = true
	task.delay(0.2, function()
		pending = false
		collect()
	end)
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
			filter = Rivue.ref(""),
			pick = function(instance: Instance)
				selected.value = instance
				Selection:Set({ instance })
			end,
		}
	end,
	render = function(ctx)
		local query = string.lower(ctx.filter)
		local shown = {}
		local current: Entry? = nil
		for _, entry in ctx.entries do
			if query == "" or string.find(string.lower(entry.name), query, 1, true) then
				table.insert(shown, entry)
			end
			if entry.instance == ctx.selected then
				current = entry
			end
		end

		local details = if current
			then `<{current.name}>  rendered {current.renders}×\n\nProps\n{if current.props == ""
				then "(none)"
				else current.props}\n\nState\n{if current.state == "" then "(none)" else current.state}`
			elseif
				#ctx.entries == 0
			then "No components yet.\n\nPress Play, and set app.config.devtools = true before app:mount()."
			else "Click a component to see its props and state. Orange ones just re-rendered."

		return h("Frame", { class = "panel" }, {
			h("TextLabel", {
				Name = "Header",
				class = "header",
				Text = `Rivue {Rivue.version} · {#ctx.entries} components`,
			}),
			h("TextBox", { Name = "Filter", class = "filter", model = "filter", PlaceholderText = "Filter by name" }),
			h("ScrollingFrame", {
				Name = "Tree",
				Size = UDim2.new(1, 0, 0.55, -50),
				BackgroundTransparency = 1,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				layout = "vertical",
			}, {
				Rivue.hFor(shown, function(entry: Entry)
					return h("TextButton", {
						key = entry.instance,
						class = {
							"row",
							if entry.changed then "changedRow" else nil,
							if entry.instance == ctx.selected then "selectedRow" else nil,
						},
						Text = `{string.rep("  ", entry.depth)}<{entry.name}>  {entry.renders}`,
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
}
