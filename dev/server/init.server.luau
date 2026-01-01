-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = require(ReplicatedStorage:WaitForChild("RivueRemote"))

-- Create the remotes up front so clients don't wait for them
Remote.setupServer()
