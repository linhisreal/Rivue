--!nonstrict
--[[
	Test Runner with JSON Reporter
	===============================
	
	Unified test runner that executes all test suites and outputs JSON results for CI integration
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type TestResult = {
	suite: string,
	name: string,
	passed: boolean,
	error: string?,
}

export type TestSuiteResult = {
	suite: string,
	passed: number,
	failed: number,
	tests: { TestResult },
}

export type TestRunResult = {
	timestamp: string,
	totalPassed: number,
	totalFailed: number,
	suites: { TestSuiteResult },
}

local HttpService = game:GetService("HttpService")

-- Wait for test modules to load
local Tests = ReplicatedStorage:WaitForChild("Tests")

local function runAllTests(): TestRunResult
	local results: TestRunResult = {
		timestamp = tostring(os.time()),
		totalPassed = 0,
		totalFailed = 0,
		suites = {},
	}

	local testSuites = {
		{ name = "ApiValidation", moduleName = "ApiValidation" },
		{ name = "Scheduler", moduleName = "Scheduler" },
		{ name = "Utils", moduleName = "Utils" },
		{ name = "Reactivity", moduleName = "Reactivity" },
		{ name = "Renderer", moduleName = "Renderer" },
		{ name = "Remote", moduleName = "Remote" },
		{ name = "Pool", moduleName = "Pool" },
		{ name = "H", moduleName = "H" },
		{ name = "Directives", moduleName = "Directives" },
		{ name = "Composables", moduleName = "Composables" },
		{ name = "Debug", moduleName = "Debug" },
		{ name = "Component", moduleName = "Component" },
		{ name = "Roblox", moduleName = "Roblox" },
		-- Enhancement Tests
		{ name = "SchedulerEnhancements", moduleName = "SchedulerEnhancements" },
		{ name = "PoolEnhancements", moduleName = "PoolEnhancements" },
		{ name = "AttributeRefEnhancements", moduleName = "AttributeRefEnhancements" },
		{ name = "VueFeatures", moduleName = "VueFeatures" },
	}

	for _, suite in ipairs(testSuites) do
		print(string.format("\n🧪 Running %s tests...", suite.name))

		local suiteResult: TestSuiteResult = {
			suite = suite.name,
			passed = 0,
			failed = 0,
			tests = {},
		}

		local testModuleInstance = Tests:FindFirstChild(suite.moduleName)
		if not testModuleInstance then
			suiteResult.failed = 1
			results.totalFailed = results.totalFailed + 1
			table.insert(suiteResult.tests, {
				suite = suite.name,
				name = "suite_resolution",
				passed = false,
				error = string.format("Test suite %s not found in ReplicatedStorage.Tests", suite.name),
			})
			warn(string.format("❌ %s not found", suite.name))
			table.insert(results.suites, suiteResult)
			continue
		end

		-- Safely require the module
		local ok, moduleOrErr = pcall(function()
			-- use 'any' to avoid static analyzer complaining about dynamic require locations
			return require(testModuleInstance :: any)
		end)

		if not ok then
			suiteResult.failed = 1
			results.totalFailed = results.totalFailed + 1
			table.insert(suiteResult.tests, {
				suite = suite.name,
				name = "suite_require",
				passed = false,
				error = tostring(moduleOrErr),
			})
			warn(string.format("❌ %s failed to require: %s", suite.name, moduleOrErr))
			table.insert(results.suites, suiteResult)
			continue
		end

		local testModule = moduleOrErr

		-- If the module is a function, call it. If it's a table with runAllTests, call that.
		local ranOk, runResult
		if type(testModule) == "function" then
			ranOk, runResult = pcall(testModule)
		elseif type(testModule) == "table" and type(testModule.runAllTests) == "function" then
			ranOk, runResult = pcall(testModule.runAllTests)
		else
			-- Module didn't return a callable test runner. Treat successful require as success.
			ranOk = true
			runResult = nil
		end

		if not ranOk then
			suiteResult.failed = 1
			results.totalFailed = results.totalFailed + 1
			table.insert(suiteResult.tests, {
				suite = suite.name,
				name = "suite_execution",
				passed = false,
				error = tostring(runResult),
			})
			warn(string.format("❌ %s errored during execution: %s", suite.name, runResult))
			table.insert(results.suites, suiteResult)
			continue
		end

		-- If the runner returned a structured result, merge counts. Otherwise, assume success.
		if type(runResult) == "table" then
			-- If it's a full run result
			if runResult.totalPassed and runResult.totalFailed and runResult.suites then
				results.totalPassed = results.totalPassed + runResult.totalPassed
				results.totalFailed = results.totalFailed + runResult.totalFailed
				for _, s in ipairs(runResult.suites) do
					table.insert(results.suites, s)
				end
				print(string.format("✅ %s returned structured TestRunResult", suite.name))
			elseif runResult.passed and runResult.failed and runResult.tests then
				-- Module returned a TestSuiteResult
				runResult.suite = runResult.suite or suite.name
				results.totalPassed = results.totalPassed + runResult.passed
				results.totalFailed = results.totalFailed + runResult.failed
				table.insert(results.suites, runResult)
				print(string.format("✅ %s returned TestSuiteResult", suite.name))
			else
				-- Unstructured table - count as a single passed suite
				suiteResult.passed = 1
				results.totalPassed = results.totalPassed + 1
				table.insert(results.suites, suiteResult)
				print(string.format("✅ %s executed (unstructured result)", suite.name))
			end
		else
			-- No structured result but execution succeeded
			suiteResult.passed = 1
			results.totalPassed = results.totalPassed + 1
			table.insert(results.suites, suiteResult)
			print(string.format("✅ %s passed", suite.name))
		end
	end

	return results
end

local function outputJSON(results: TestRunResult): ()
	local json = HttpService:JSONEncode(results)
	print("\n" .. string.rep("=", 60))
	print("TEST RESULTS (JSON)")
	print(string.rep("=", 60))
	print(json)
	print(string.rep("=", 60))

	-- Write to ReplicatedStorage for external tools to read
	local storage = ReplicatedStorage:FindFirstChild("TestResults")
	if not storage then
		storage = Instance.new("StringValue")
		storage.Name = "TestResults"
		storage.Parent = ReplicatedStorage
	end
	(storage :: StringValue).Value = json
end

local function printSummary(results: TestRunResult): ()
	print("\n" .. string.rep("=", 60))
	print("TEST SUMMARY")
	print(string.rep("=", 60))
	print(string.format("Total Passed: %d", results.totalPassed))
	print(string.format("Total Failed: %d", results.totalFailed))
	print(
		string.format("Success Rate: %.1f%%", results.totalPassed / (results.totalPassed + results.totalFailed) * 100)
	)
	print(string.rep("=", 60))

	if results.totalFailed > 0 then
		print("\n⚠️  Some tests failed - see details above")
	else
		print("\n🎉 All tests passed!")
	end
end

-- Auto-run tests when script loads
print("\n" .. string.rep("=", 60))
print("RUNNING ALL TESTS")
print(string.rep("=", 60) .. "\n")

local results = runAllTests()
outputJSON(results)
printSummary(results)
