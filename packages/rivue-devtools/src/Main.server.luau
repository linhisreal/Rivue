--!nonstrict
-- Rivue DevTools: lists the Rivue components on screen during a playtest, with their props and
-- state. The game has to opt in with app.config.devtools = true, which tags each component's
-- root Instance and mirrors its data into attributes. A plugin can't read a game script's
-- modules, so attributes are how the data gets here.

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local Rivue = require(script.Parent:WaitForChild("Rivue"))
local h = Rivue.h

local TAG = "RivueComponent"
local self = plugin :: Plugin

type Entry = {
	instance: Instance,
	depth: number,
	name: string,
	props: string,
	state: string,
	renders: number,
}

local entries = Rivue.shallowRef({} :: { Entry })
local selected = Rivue.shallowRef(nil :: Instance?)
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

local function collect()
	local list: { Entry } = {}
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsDescendantOf(game) then
			table.insert(list, {
				instance = instance,
				depth = depthOf(instance),
				name = (instance:GetAttribute("RivueComponent") :: string?) or instance.Name,
				props = (instance:GetAttribute("RivueProps") :: string?) or "",
				state = (instance:GetAttribute("RivueState") :: string?) or "",
				renders = (instance:GetAttribute("RivueRenders") :: number?) or 0,
			})
		end
	end
	-- Full names put children right after their parents
	table.sort(list, function(a, b)
		return a.instance:GetFullName() < b.instance:GetFullName()
	end)
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

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
	watch(instance)
	refreshSoon()
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
	local conn = watched[instance]
	if conn then
		conn:Disconnect()
		watched[instance] = nil
	end
	if selected.value == instance then
		selected.value = nil
	end
	refreshSoon()
end)
for _, instance in CollectionService:GetTagged(TAG) do
	watch(instance)
end

local DevTools = Rivue.defineComponent({
	name = "RivueDevTools",
	styles = {
		panel = { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(37, 37, 37), BorderSizePixel = 0 },
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
			pick = function(instance: Instance)
				selected.value = instance
				Selection:Set({ instance })
			end,
		}
	end,
	render = function(ctx)
		local current: Entry? = nil
		for _, entry in ctx.entries do
			if entry.instance == ctx.selected then
				current = entry
			end
		end
		local details = if current
			then `<{current.name}>  rendered {current.renders}×\n\nProps\n{if current.props == ""
				then "(none)"
				else current.props}\n\nState\n{if current.state == "" then "(none)" else current.state}`
			else if #ctx.entries == 0
				then "No components yet.\n\nPress Play, and set app.config.devtools = true before app:mount()."
				else "Click a component to see its props and state."

		return h("Frame", { class = "panel" }, {
			h("ScrollingFrame", {
				Name = "Tree",
				Size = UDim2.fromScale(1, 0.55),
				BackgroundTransparency = 1,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				layout = "vertical",
			}, {
				Rivue.hFor(ctx.entries, function(entry: Entry)
					return h("TextButton", {
						key = entry.instance,
						class = { "row", if entry.instance == ctx.selected then "selectedRow" else nil },
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
				Position = UDim2.fromScale(0, 0.57),
				Size = UDim2.fromScale(1, 0.43),
				padding = 8,
				Text = details,
			}),
		})
	end,
})

local toolbar = self:CreateToolbar("Rivue")
local button = toolbar:CreateButton("DevTools", "Show the Rivue components on screen", "")
button.ClickableWhenViewportHidden = true

local widget = self:CreateDockWidgetPluginGuiAsync(
	"RivueDevTools",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 320, 480, 240, 200)
)
widget.Title = "Rivue DevTools"

local app = nil
local function setOpen(open: boolean)
	button:SetActive(open)
	if open and not app then
		collect()
		local created = Rivue.createApp(DevTools)
		created:mount(widget)
		app = created
	elseif not open and app then
		app:unmount()
		app = nil
	end
end

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	setOpen(widget.Enabled)
end)
setOpen(widget.Enabled)

self.Unloading:Connect(function()
	setOpen(false)
	for _, conn in watched do
		conn:Disconnect()
	end
end)
