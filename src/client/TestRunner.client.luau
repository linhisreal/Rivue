--!nonstrict
-- Runs every suite in ReplicatedStorage.Tests when the test place is played, prints a summary,
-- and stores the results as JSON in ReplicatedStorage.TestResults for external tools.
-- A suite is a ModuleScript returning a function, or a table with runAllTests.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type SuiteResult = { suite: string, passed: boolean, error: string? }

local function runSuite(module: ModuleScript): SuiteResult
	local ok, err = pcall(function()
		local suite = require(module) :: any
		if type(suite) == "function" then
			suite()
		elseif type(suite) == "table" and type(suite.runAllTests) == "function" then
			suite.runAllTests()
		else
			error("suite returned nothing runnable")
		end
	end)
	return { suite = module.Name, passed = ok, error = if ok then nil else tostring(err) }
end

local modules = ReplicatedStorage:WaitForChild("Tests"):GetChildren()
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

local results: { SuiteResult } = {}
local failed = 0
for _, module in modules do
	if module:IsA("ModuleScript") then
		print(`Running {module.Name}...`)
		local result = runSuite(module)
		table.insert(results, result)
		if not result.passed then
			failed += 1
			warn(`{module.Name} failed: {result.error}`)
		end
	end
end

local storage = ReplicatedStorage:FindFirstChild("TestResults") or Instance.new("StringValue")
storage.Name = "TestResults"
storage.Value = HttpService:JSONEncode({ timestamp = os.time(), failed = failed, suites = results })
storage.Parent = ReplicatedStorage

print(`{#results - failed}/{#results} suites passed`)
