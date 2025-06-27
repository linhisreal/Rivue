--!nonstrict
-- Rivue DevTools: lists the Rivue components on screen during a playtest, with their props and
-- state. The game opts in with app.config.devtools = true, which tags each component's root
-- Instance and mirrors its data into attributes. A plugin can't read a game script's modules, so
-- attributes are how the data gets here.

local Rivue = require(script.Parent:WaitForChild("RivueUI"))
local DevTools = require(script.Parent:WaitForChild("App"))

local self = plugin :: Plugin

local toolbar = self:CreateToolbar("Rivue")
local button = toolbar:CreateButton("DevTools", "Show the Rivue components on screen", "")
button.ClickableWhenViewportHidden = true

local widget = self:CreateDockWidgetPluginGuiAsync(
	"RivueDevTools",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 340, 520, 260, 240)
)
widget.Title = `Rivue DevTools {Rivue.version}`

DevTools.setOpenScript(function(script, line)
	self:OpenScript(script, line)
end)

local app = nil
local stop: (() -> ())? = nil
local function setOpen(open: boolean)
	button:SetActive(open)
	if open and not app then
		stop = DevTools.start()
		local created = Rivue.createApp(DevTools.App)
		created:mount(widget)
		app = created
	elseif not open and app then
		app:unmount()
		app = nil
		if stop then
			stop()
			stop = nil
		end
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
end)
