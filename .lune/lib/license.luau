-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

--[[
	The license copies that ship with each package, generated from the root LICENSE.md: a
	LICENSE.md with its image path fixed, and a plain LICENSE.txt that Rojo turns into a
	StringValue inside every model.
]]

local fs = require("@lune/fs")

local function plain(markdown: string): string
	local body = string.gsub(markdown, "^<p.-</p>%s*", "")
	return body
end

local function expected(): { [string]: string }
	local root = fs.readFile("LICENSE.md")
	local files = {}
	for _, name in fs.readDir("packages") do
		if fs.isDir(`packages/{name}`) then
			files[`packages/{name}/LICENSE.md`] = (string.gsub(root, 'src="docs/', 'src="../../docs/'))
			files[`packages/{name}/LICENSE.txt`] = plain(root)
		end
	end
	return files
end

return { expected = expected }
