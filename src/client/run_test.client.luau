-- run_test.client.luau (LocalScript)
-- Mount the TestEnhancements (Test4) into PlayerGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Prevent double-execution: check if already running
if playerGui:FindFirstChild("TestEnhancementsRoot") then
    print("⚠️ TestEnhancements already mounted, skipping duplicate execution")
    return
end

-- Require the test module (mapped as Test4 in default.project.json)
local Test4 = require(ReplicatedStorage:WaitForChild("Test4"))

print("==== TEST ENHANCEMENTS RUNNER ====")

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Name = "TestEnhancementsRoot"
screenGui.Parent = playerGui

print("Mounting TestEnhancements...")
local mounted = Test4.runTest(screenGui)
print("TestEnhancements mounted, returned:", mounted)

-- End of runner
