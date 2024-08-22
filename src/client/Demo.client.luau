--!strict
-- Mounts the demo app (src/shared/Demo) when the test place runs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local Demo = ReplicatedStorage:WaitForChild("Demo")

local App = require(Demo:WaitForChild("App"))
local styles = require(Demo:WaitForChild("styles"))

Rivue.createApp(App):styles(styles):mountToPlayerGui(Players.LocalPlayer)
