--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local Demo = ReplicatedStorage:WaitForChild("Demo")

local App = require(Demo:WaitForChild("App"))
local styles = require(Demo:WaitForChild("styles"))

Rivue.createApp(App):styles(styles):mountToPlayerGui(Players.LocalPlayer)
