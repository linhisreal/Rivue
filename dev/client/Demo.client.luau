--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local Demo = ReplicatedStorage:WaitForChild("Demo")

local App = require(Demo:WaitForChild("App"))
local styles = require(Demo:WaitForChild("styles"))

Rivue.createApp(App):styles(styles):mountToPlayerGui(Players.LocalPlayer)
