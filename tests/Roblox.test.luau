--!strict
-- Tests for roblox.luau - attributeRef, useTag, RunService hooks

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local CollectionService = game:GetService("CollectionService")

local function assertEquals(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(
			string.format(
				"Assertion failed: %s\nExpected: %s\nActual: %s",
				message or "values not equal",
				tostring(expected),
				tostring(actual)
			)
		)
	end
	print("✓", message or "Assertion passed")
end

local function assertTrue(condition: boolean, message: string?)
	if not condition then
		error("Assertion failed: " .. (message or "condition is false"))
	end
	print("✓", message or "Assertion passed")
end

local function runTests()
	print("\n========== ROBLOX UTILS TEST SUITE ==========\n")

	-- Test 1: attributeRef creates reactive attribute binding
	print("Test 1: attributeRef creates reactive attribute binding")
	do
		local instance = Instance.new("Folder")
		instance:SetAttribute("testValue", 42)
		local attrRef = Rivue.attributeRef(instance, "testValue")
		assertEquals(attrRef.value, 42, "Should read initial attribute value")
		instance:Destroy()
	end

	-- Test 2: attributeRef syncs changes from attribute to ref
	print("Test 2: attributeRef syncs changes from attribute to ref")
	do
		local instance = Instance.new("Folder")
		instance.Parent = workspace
		instance:SetAttribute("counter", 0)

		local refValue = nil
		local TestComponent = Rivue.defineComponent({
			name = "AttrSyncTest",
			setup = function()
				local attrRef = Rivue.attributeRef(instance, "counter")

				-- Watch the ref and update our test variable
				Rivue.watch(attrRef, function(newVal)
					refValue = newVal
				end)

				return function()
					return Rivue.h("Frame", {})
				end
			end,
		})

		local container = Instance.new("Folder")
		local renderer =
			require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)

		task.wait(0.2)
		instance:SetAttribute("counter", 10)
		task.wait(0.3)

		assertEquals(refValue, 10, "Should sync attribute changes to ref")

		app:unmount()
		container:Destroy()
		instance:Destroy()
	end

	-- Test 3: attributeRef syncs changes from ref to attribute
	print("Test 3: attributeRef syncs changes from ref to attribute")
	do
		local instance = Instance.new("Folder")
		instance.Parent = workspace
		instance:SetAttribute("value", 100)

		local TestComponent = Rivue.defineComponent({
			name = "RefToAttrTest",
			setup = function()
				local attrRef = Rivue.attributeRef(instance, "value")

				Rivue.onMounted(function()
					attrRef.value = 200
				end)

				return function()
					return Rivue.h("Frame", {})
				end
			end,
		})

		local container = Instance.new("Folder")
		local renderer =
			require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.1)

		assertEquals(instance:GetAttribute("value"), 200, "Attribute should sync with ref changes")

		app:unmount()
		container:Destroy()
		instance:Destroy()
	end

	-- Test 4: attributeRef applies default value
	print("Test 4: attributeRef applies default value")
	do
		local instance = Instance.new("Folder")
		local attrRef = Rivue.attributeRef(instance, "newAttr", 999)
		assertEquals(attrRef.value, 999, "Should apply default value")
		assertEquals(instance:GetAttribute("newAttr"), 999, "Should set attribute to default")
		instance:Destroy()
	end

	-- Test 5: useTag detects tagged instances
	print("Test 5: useTag detects tagged instances")
	do
		local container = Instance.new("Folder")
		container.Parent = workspace -- CollectionService needs instances in workspace
		local detected = {}

		local TestComponent = Rivue.defineComponent({
			name = "TagTest",
			setup = function()
				Rivue.useTag("TestTag", function(inst)
					table.insert(detected, inst.Name)
					return nil
				end)
				return function()
					return Rivue.h("Frame", {})
				end
			end,
		})

		local renderer =
			require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.1)

		local obj1 = Instance.new("Part")
		obj1.Name = "Tagged1"
		obj1.Parent = container
		CollectionService:AddTag(obj1, "TestTag")
		task.wait(0.2) -- Longer wait for CollectionService events

		assertTrue(#detected > 0, "Should detect tagged instance")
		assertTrue(detected[1] == "Tagged1", "Should call callback with correct instance")

		app:unmount()
		container:Destroy()
	end

	-- Test 6: useTag cleanup on tag removal
	print("Test 6: useTag cleanup on tag removal")
	do
		local container = Instance.new("Folder")
		container.Parent = workspace -- CollectionService needs instances in workspace
		local cleanedUp = false

		local TestComponent = Rivue.defineComponent({
			name = "TagCleanupTest",
			setup = function()
				Rivue.useTag("CleanupTag", function()
					return function()
						cleanedUp = true
					end
				end)
				return function()
					return Rivue.h("Frame", {})
				end
			end,
		})

		local renderer =
			require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.1)

		local obj = Instance.new("Part")
		obj.Parent = container
		CollectionService:AddTag(obj, "CleanupTag")
		task.wait(0.2) -- Longer wait for CollectionService events

		CollectionService:RemoveTag(obj, "CleanupTag")
		task.wait(0.2)

		assertTrue(cleanedUp, "Should call cleanup on tag removal")

		app:unmount()
		container:Destroy()
	end

	-- Test 7: onRenderStepped executes each frame
	print("Test 7: onRenderStepped executes each frame")
	do
		local container = Instance.new("Folder")
		local frameCount = 0

		local TestComponent = Rivue.defineComponent({
			name = "RenderSteppedTest",
			setup = function()
				Rivue.onRenderStepped(function()
					frameCount = frameCount + 1
				end)
				return function()
					return Rivue.h("Frame", {})
				end
			end,
		})

		local renderer =
			require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.3) -- Wait longer for frames to accumulate

		assertTrue(frameCount >= 3, "Should execute multiple times per frame")

		app:unmount()
		container:Destroy()
	end

	-- Test 8: onHeartbeat executes regularly
	print("Test 8: onHeartbeat executes regularly")
	do
		local container = Instance.new("Folder")
		local heartbeatCount = 0

		local TestComponent = Rivue.defineComponent({
			name = "HeartbeatTest",
			setup = function()
				Rivue.onHeartbeat(function()
					heartbeatCount = heartbeatCount + 1
				end)
				return function()
					return Rivue.h("Frame", {})
				end
			end,
		})

		local renderer =
			require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.3) -- Wait longer for heartbeats

		assertTrue(heartbeatCount >= 3, "Should execute multiple heartbeats")

		app:unmount()
		container:Destroy()
	end

	-- Test 9: onStepped executes with time parameters
	print("Test 9: onStepped executes with time parameters")
	do
		local container = Instance.new("Folder")
		local steppedCount = 0
		local receivedTime = false

		local TestComponent = Rivue.defineComponent({
			name = "SteppedTest",
			setup = function()
				Rivue.onStepped(function(time, dt)
					steppedCount = steppedCount + 1
					if type(time) == "number" and type(dt) == "number" then
						receivedTime = true
					end
				end)
				return function()
					return Rivue.h("Frame", {})
				end
			end,
		})

		local renderer =
			require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.3) -- Wait longer for steps

		assertTrue(steppedCount >= 3, "Should execute multiple steps")
		assertTrue(receivedTime, "Should receive time and deltaTime parameters")

		app:unmount()
		container:Destroy()
	end

	-- Test 10: RunService hooks auto-disconnect on unmount
	print("Test 10: RunService hooks auto-disconnect on unmount")
	do
		local container = Instance.new("Folder")
		local heartbeatCount = 0

		local TestComponent = Rivue.defineComponent({
			name = "AutoDisconnectTest",
			setup = function()
				Rivue.onHeartbeat(function()
					heartbeatCount = heartbeatCount + 1
				end)
				return function()
					return Rivue.h("Frame", {})
				end
			end,
		})

		local renderer =
			require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.1)
		local countBeforeUnmount = heartbeatCount

		app:unmount()
		task.wait(0.1)

		assertTrue(heartbeatCount == countBeforeUnmount, "Should stop executing after unmount")

		container:Destroy()
	end

	-- Test 11: attributeRef reactivity triggers watchers
	print("Test 11: attributeRef reactivity triggers watchers")
	do
		local instance = Instance.new("Folder")
		instance.Parent = workspace
		instance:SetAttribute("reactive", 1)
		local watchTriggered = false

		local TestComponent = Rivue.defineComponent({
			name = "WatchTest",
			setup = function()
				local attrRef = Rivue.attributeRef(instance, "reactive")

				Rivue.watch(attrRef, function()
					watchTriggered = true
				end)

				Rivue.onMounted(function()
					task.wait(0.05)
					attrRef.value = 2
				end)

				return function()
					return Rivue.h("Frame", {})
				end
			end,
		})

		local container = Instance.new("Folder")
		local renderer =
			require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("renderer"))
		local app = renderer.createApp(Rivue.h(TestComponent, {}))
		app:mount(container)
		task.wait(0.15)

		assertTrue(watchTriggered, "Should trigger watcher on ref change")

		app:unmount()
		container:Destroy()
		instance:Destroy()
	end

	print("\n========== ROBLOX UTILS TESTS COMPLETE ==========\n")
end

return runTests
