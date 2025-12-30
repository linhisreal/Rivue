print("Hello, world!...")
print("November 4th.")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))

-- Create the remotes up front so clients don't wait for them
Rivue.Remote.setupServer()
