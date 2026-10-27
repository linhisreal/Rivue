--!nonstrict

local Highlight = {}

local overlay: ScreenGui? = nil
local box: Frame? = nil
local conns: { RBXScriptConnection } = {}
local parentOverride: Instance? = nil

--- Tests mount the overlay somewhere they can inspect
function Highlight.setParent(parent: Instance?)
	parentOverride = parent
end

local function container(): Instance?
	if parentOverride then
		return parentOverride
	end
	local ok, coreGui = pcall(game.GetService, game, "CoreGui")
	return if ok then coreGui else nil
end

local function disconnect()
	for _, conn in conns do
		conn:Disconnect()
	end
	table.clear(conns)
end

function Highlight.hide()
	disconnect()
	if overlay then
		overlay:Destroy()
		overlay = nil
		box = nil
	end
end

--- Only GuiObjects on a ScreenGui have a screen position. Anything else (a SurfaceGui, a Folder
--- root) is skipped rather than outlined in the wrong place
function Highlight.show(target: Instance)
	Highlight.hide()
	if not target:IsA("GuiObject") then
		return
	end
	local screen = target.Parent
	while screen and not screen:IsA("LayerCollector") do
		screen = screen.Parent
	end
	local parent = container()
	if not (screen and screen:IsA("ScreenGui")) or not parent then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RivueDevToolsHighlight"
	gui.DisplayOrder = 2 ^ 31 - 1
	gui.IgnoreGuiInset = screen.IgnoreGuiInset
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Name = "Outline"
	frame.BackgroundColor3 = Color3.fromRGB(31, 111, 235)
	frame.BackgroundTransparency = 0.85
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(31, 111, 235)
	stroke.Thickness = 2
	stroke.Parent = frame
	frame.Parent = gui

	local guiObject = target :: GuiObject
	local function place()
		frame.Position = UDim2.fromOffset(guiObject.AbsolutePosition.X, guiObject.AbsolutePosition.Y)
		frame.Size = UDim2.fromOffset(guiObject.AbsoluteSize.X, guiObject.AbsoluteSize.Y)
	end
	place()
	table.insert(conns, guiObject:GetPropertyChangedSignal("AbsolutePosition"):Connect(place))
	table.insert(conns, guiObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
	table.insert(
		conns,
		guiObject.AncestryChanged:Connect(function()
			if not guiObject:IsDescendantOf(game) then
				Highlight.hide()
			end
		end)
	)

	gui.Parent = parent
	overlay = gui
	box = frame
end

function Highlight.current(): Frame?
	return box
end

return Highlight
