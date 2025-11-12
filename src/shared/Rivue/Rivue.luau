--!strict
--!optimize 2
--!native

--[[
	Rivue.luau
	==============
	
	Convenience wrapper ModuleScript that locates and requires the main runtime module.
	This file provides a clean entry point for requiring the Rivue from any location.
	
	Module Resolution Strategy:
	---------------------------
	
	1. Check for local "runtime" folder as child of this ModuleScript
		→ If found, require runtime/main
	
	2. Fallback: Check ReplicatedStorage for Rivue ModuleScript
		→ If found, require Rivue/main
	
	3. Error if neither location is found
	
	Project Structure:
	------------------
	
	Expected hierarchy:
	
		ReplicatedStorage/
		└── Rivue (ModuleScript) ← This file
			└── runtime/ (Folder)
				├── main.luau        ← Public API assembly
				├── reactivity.luau  ← Reactive state system
				├── h.luau           ← Virtual DOM creation
				├── component.luau   ← Component lifecycle
				├── renderer.luau    ← DOM reconciliation
				├── scheduler.luau   ← Job scheduling
				├── pool.luau        ← Instance pooling
				├── directives.luau  ← Directive system
				├── utils.luau       ← Utility functions
				└── remote.luau      ← Network communication
	
	Usage:
	------
	
	From any script:
	```lua
	local Rivue = require(game.ReplicatedStorage.Rivue)
	-- Now use Rivue.ref, Rivue.h, Rivue.mount, etc.
	```
	
	Design Philosophy:
	------------------
	
	This wrapper enables:
	- Clean require syntax (no need to know internal structure)
	- Flexibility in deployment (local or replicated)
	- Single source of truth for runtime location
	- Error messages that guide proper setup
	
	The actual Rivue implementation lives in the runtime folder.
	This file simply locates and delegates to it.
]]

-- Rivue.luau (ModuleScript)
-- Convenience ModuleScript. It expects a child Folder "runtime" containing the runtime ModuleScripts.

local runtimeFolder = script:FindFirstChild("runtime")
if runtimeFolder then
    return require(runtimeFolder:WaitForChild("main"))
else
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local runtimeModule = ReplicatedStorage:FindFirstChild("Rivue")
    if runtimeModule and runtimeModule:FindFirstChild("main") then
        return require(runtimeModule:WaitForChild("main"))
    end
    error("Rivue runtime not found. Place 'runtime' folder as child of this ModuleScript or place runtime in ReplicatedStorage.")
end