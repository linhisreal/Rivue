--[[
	Runs the test suites inside a real Roblox server with Open Cloud's Luau Execution API.

	ROBLOX_API_KEY=... ROBLOX_UNIVERSE_ID=... ROBLOX_PLACE_ID=... lune run cloud-test

	Builds the dev place, uploads it as a new version of the place, runs every module in
	ReplicatedStorage.Tests there, prints the logs and exits non-zero if a suite failed. The
	API key needs Luau Execution Session (write) and Universe Places (write) on that experience.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local API = "https://apis.roblox.com"
local key = process.env.ROBLOX_API_KEY
local universe = process.env.ROBLOX_UNIVERSE_ID
local place = process.env.ROBLOX_PLACE_ID
if not (key and universe and place) then
	print("Set ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID and ROBLOX_PLACE_ID")
	process.exit(1)
end

-- Runs in the place. Scripts in the place don't start on their own, so this requires the suites
-- itself, like dev/client/TestRunner.client.luau does
local RUNNER = [[
__CLOUD = true
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modules = ReplicatedStorage:WaitForChild("Tests"):GetChildren()
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)
local results = { passed = 0, failed = 0, failures = {} }
-- A suite that hangs is reported and skipped, so one wait that never ends doesn't hide the rest
local SUITE_TIMEOUT = 30
for _, module in modules do
	if module:IsA("ModuleScript") then
		print(`Running {module.Name}...`)
		local started = os.clock()
		local done, ok, err = false, false, nil
		task.spawn(function()
			ok, err = pcall(function()
				local suite = require(module)
				if type(suite) == "function" then
					suite()
				elseif type(suite) == "table" and type(suite.runAllTests) == "function" then
					suite.runAllTests()
				else
					error("suite returned nothing runnable")
				end
			end)
			done = true
		end)
		while not done and os.clock() - started < SUITE_TIMEOUT do
			task.wait(0.1)
		end
		if not done then
			ok, err = false, `didn't finish within {SUITE_TIMEOUT} s`
		end
		local took = string.format("%.1f s", os.clock() - started)
		if ok then
			results.passed += 1
			print(`passed {module.Name} ({took})`)
		else
			results.failed += 1
			table.insert(results.failures, `{module.Name}: {err}`)
			print(`FAILED {module.Name} ({took}): {err}`)
		end
	end
end
return results
]]

local function call(method: string, url: string, body: string?, contentType: string?): any
	local response = net.request({
		url = url,
		method = method :: any,
		body = body,
		headers = { ["x-api-key"] = key :: string, ["content-type"] = contentType or "application/json" },
	})
	if not response.ok then
		print(`{method} {url} failed: {response.statusCode} {response.body}`)
		process.exit(1)
	end
	return if response.body ~= "" then serde.decode("json", response.body) else {}
end

local build = process.exec("lune", { "run", "build" }, { stdio = "inherit" })
if not build.ok then
	process.exit(1)
end

print("Uploading the dev place...")
local upload = call(
	"POST",
	`{API}/universes/v1/{universe}/places/{place}/versions?versionType=Saved`,
	fs.readFile("build/RivueDevPlace.rbxl"),
	"application/octet-stream"
)
local version = upload.versionNumber
print(`Uploaded as version {version}`)

local created = call(
	"POST",
	`{API}/cloud/v2/universes/{universe}/places/{place}/versions/{version}/luau-execution-session-tasks`,
	serde.encode("json", { script = RUNNER, timeout = "300s" })
)
local path = created.path
print(`Running tests: {path}`)

-- A key without the right permission can get a success response for a task that never runs, so
-- the task's own state decides
local current
for _ = 1, 120 do
	task.wait(3)
	current = call("GET", `{API}/cloud/v2/{path}`)
	if current.state == "COMPLETE" or current.state == "FAILED" or current.state == "CANCELLED" then
		break
	end
end

-- Logs come a page at a time
local pageToken = ""
repeat
	local logs = call("GET", `{API}/cloud/v2/{path}/logs?maxPageSize=10000&pageToken={pageToken}`)
	for _, entry in logs.luauExecutionSessionTaskLogs or {} do
		for _, message in entry.messages or {} do
			print(message)
		end
	end
	pageToken = logs.nextPageToken or ""
until pageToken == ""

if not current or current.state ~= "COMPLETE" then
	print(
		`Task ended as {current and current.state or "unknown"}: {serde.encode("json", current and current.error or {})}`
	)
	process.exit(1)
end

local results = current.output and current.output.results and current.output.results[1] or {}
print(`{results.passed or 0} suites passed, {results.failed or 0} failed in Roblox`)
for _, failure in results.failures or {} do
	print(`  {failure}`)
end
process.exit(if (results.failed or 0) == 0 and (results.passed or 0) > 0 then 0 else 1)
