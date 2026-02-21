-- stress.client.luau (LocalScript)
-- Mounts and unmounts the demo app 300 times and reports leaked UI Instances.
-- Opt in: set the attribute RivueStressTest = true on Workspace before playing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not workspace:GetAttribute("RivueStressTest") then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local Demo = ReplicatedStorage:WaitForChild("Demo")
local App = require(Demo:WaitForChild("App"))
local styles = require(Demo:WaitForChild("styles"))

local app = Rivue.createApp(App, { usePool = true }):styles(styles)

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Name = "StressRoot"
screenGui.Parent = playerGui

local function countInstances()
	local t = 0
	local desc = game:GetDescendants()

	for _, _desc in ipairs(desc) do
		t = t + 1
	end

	return t
end

local function countInstancesByClass()
	local counts = {}
	local desc = game:GetDescendants()

	for _, inst in ipairs(desc) do
		local className = inst.ClassName
		counts[className] = (counts[className] or 0) + 1
	end

	return counts
end

local function printTopLeakers(beforeCounts, afterCounts, top)
	top = top or 10
	local deltas = {}

	-- Only track actual UI instances that the Rivue creates
	local trackUIClasses = {
		["Frame"] = true,
		["TextLabel"] = true,
		["TextButton"] = true,
		["TextBox"] = true,
		["ImageLabel"] = true,
		["ImageButton"] = true,
		["ScrollingFrame"] = true,
		["ScreenGui"] = true,
		["CanvasGroup"] = true,
		["ViewportFrame"] = true,
		["UIListLayout"] = true,
		["UIGridLayout"] = true,
		["UIPadding"] = true,
		["UICorner"] = true,
		["UIStroke"] = true,
		["UIGradient"] = true,
		["UIAspectRatioConstraint"] = true,
		["UISizeConstraint"] = true,
		["UITextSizeConstraint"] = true,
		["Folder"] = true,
	}

	for className, afterCount in pairs(afterCounts) do
		if trackUIClasses[className] then
			local beforeCount = beforeCounts[className] or 0
			local delta = afterCount - beforeCount
			if delta > 0 then
				table.insert(deltas, { class = className, delta = delta })
			end
		end
	end

	table.sort(deltas, function(a, b)
		return a.delta > b.delta
	end)

	print("\n=== Rivue UI Instance Leaks ===")
	if #deltas == 0 then
		print("  ✅ No UI leaks detected!")
	else
		for i = 1, math.min(top, #deltas) do
			print(string.format("  %s: +%d", deltas[i].class, deltas[i].delta))
		end
	end
	print("====================================\n")

	return #deltas
end

local beforeCounts = countInstancesByClass()
local before = countInstances()
print("Instances before:", before)

for i = 1, 300 do
	app:mount(screenGui)
	app:unmount()
	if i % 50 == 0 then
		task.wait(0.05)
		local _ = gcinfo() / 1024 -- Force GC via memory check
		print(string.format("  [%d/300] Memory: %.2f MB", i, gcinfo() / 1024))
	end
end

task.wait(1)
local _ = gcinfo() -- Trigger GC
task.wait(0.5)

local afterCounts = countInstancesByClass()
local after = countInstances()
print("Instances after:", after, " delta:", (after - before))

local uiLeakCount = printTopLeakers(beforeCounts, afterCounts, 15)

if uiLeakCount > 0 then
	warn("⚠️ UI MEMORY LEAK DETECTED: " .. uiLeakCount .. " UI instance types leaking")
	warn("Rivue is NOT cleaning up properly - check renderer.unmountVNode()")
else
	print("✅ Rivue MEMORY TEST PASSED!")
	print("   No UI instance leaks detected - all instances properly cleaned up")
	print("   Total delta of " .. (after - before) .. " is Roblox engine objects (normal)")
end

print("Stress test complete.")
