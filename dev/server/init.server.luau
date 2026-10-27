-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = require(ReplicatedStorage:WaitForChild("RivueRemote"))

-- Create the remotes up front so clients don't wait for them
Remote.setupServer()
