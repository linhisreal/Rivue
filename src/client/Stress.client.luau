--!nonstrict
-- Mounts and unmounts the demo app 300 times, then reports UI Instances that weren't cleaned up.
-- Opt in: set the attribute RivueStressTest = true on Workspace before playing.

if not workspace:GetAttribute("RivueStressTest") then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local Demo = ReplicatedStorage:WaitForChild("Demo")
local App = require(Demo:WaitForChild("App"))
local styles = require(Demo:WaitForChild("styles"))

const RUNS = 300
-- Classes Rivue creates; anything else that changes is the engine's
const UI_CLASSES = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	ScreenGui = true,
	CanvasGroup = true,
	ViewportFrame = true,
	UIListLayout = true,
	UIGridLayout = true,
	UIFlexItem = true,
	UIPadding = true,
	UICorner = true,
	UIStroke = true,
	UIGradient = true,
	UIAspectRatioConstraint = true,
	UISizeConstraint = true,
	UITextSizeConstraint = true,
	Folder = true,
}

local function countByClass(): { [string]: number }
	local counts = {}
	for _, inst in game:GetDescendants() do
		counts[inst.ClassName] = (counts[inst.ClassName] or 0) + 1
	end
	return counts
end

local app = Rivue.createApp(App, { usePool = true }):styles(styles)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StressRoot"
screenGui.ResetOnSpawn = false
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local before = countByClass()
for i = 1, RUNS do
	app:mount(screenGui)
	app:unmount()
	if i % 50 == 0 then
		task.wait(0.05)
		print(string.format("[%d/%d] memory: %.2f MB", i, RUNS, gcinfo() / 1024))
	end
end
task.wait(1.5)

local leaks = {}
for className, count in countByClass() do
	local delta = count - (before[className] or 0)
	if UI_CLASSES[className] and delta > 0 then
		table.insert(leaks, { className = className, delta = delta })
	end
end
table.sort(leaks, function(a, b)
	return a.delta > b.delta
end)

if #leaks == 0 then
	print(`Stress test passed: {RUNS} mounts, no UI Instances left behind`)
else
	for _, leak in leaks do
		warn(`Leaked {leak.className}: +{leak.delta}`)
	end
	warn(`Stress test failed: {#leaks} UI classes leaked`)
end
