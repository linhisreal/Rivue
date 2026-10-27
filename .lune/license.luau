-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

--[[
	Copies the root LICENSE.md into every package, as LICENSE.md and LICENSE.txt.

	lune run license
]]

local fs = require("@lune/fs")
local license = require("./lib/license")

for path, content in license.expected() do
	fs.writeFile(path, content)
	print(`wrote {path}`)
end
