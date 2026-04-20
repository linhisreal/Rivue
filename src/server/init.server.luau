local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = require(ReplicatedStorage:WaitForChild("RivueRemote"))

-- Create the remotes up front so clients don't wait for them
Remote.setupServer()
