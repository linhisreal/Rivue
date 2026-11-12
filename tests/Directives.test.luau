--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local directives_module =
	require(ReplicatedStorage:WaitForChild("RivueUI"):WaitForChild("runtime"):WaitForChild("directives"))

local TestSupport = require(game:GetService("ReplicatedStorage"):WaitForChild("TestSupport"))
local assertEquals = TestSupport.assertEquals
local assertTrue = TestSupport.assertTrue

local function runTests()
	local printHeader = "DIRECTIVES TEST SUITE"
	print("\n" .. string.rep("=", 40))
	print(printHeader)
	print(string.rep("=", 40) .. "\n")

	print("Test 1: register() adds directive to registry")
	do
		local testDirective = {
			mounted = function() end,
		}
		directives_module.register("test-directive", testDirective)
		local retrieved = directives_module.get("test-directive")
		assertTrue(retrieved, "Should register and retrieve directive")
	end

	print("Test 2: Built-in focus directive exists")
	do
		local focusDirective = directives_module.get("focus")
		assertTrue(focusDirective, "Should have focus directive")
		assertTrue(focusDirective.mounted, "Should have mounted hook")
	end

	print("Test 3: Built-in click-outside directive exists")
	do
		local clickOutsideDirective = directives_module.get("click-outside")
		assertTrue(clickOutsideDirective, "Should have click-outside directive")
		assertTrue(clickOutsideDirective.mounted, "Should have mounted hook")
	end

	print("Test 4: vModelText creates two-way binding props")
	do
		local textRef = Rivue.ref("initial")
		local props = directives_module.vModelText(textRef)

		assertEquals(props.Text, "initial", "Should have Text property with ref value")
		assertTrue(type(props.onTextChanged) == "function", "Should have onTextChanged handler")

		props.onTextChanged("updated")
		task.wait(0.05)
		assertEquals(textRef.value, "updated", "Should update ref when onTextChanged is called")
	end

	print("Test 5: vModelText with debounce option")
	do
		local textRef = Rivue.ref("initial")
		local props = directives_module.vModelText(textRef, { debounce = 100 })

		assertEquals(props.Text, "initial", "Should have Text property")
		assertTrue(type(props.onTextChanged) == "function", "Should have debounced handler")
	end

	print("Test 6: vModelProp creates generic two-way binding")
	do
		local valueRef = Rivue.ref(50)
		local props = directives_module.vModelProp(valueRef, "Value")

		assertEquals(props.Value, 50, "Should have Value property with ref value")
		assertTrue(type(props.onValue) == "function", "Should have onValue handler")

		props.onValue(75)
		assertEquals(valueRef.value, 75, "Should update ref when handler is called")
	end

	print("Test 7: vModelProp with custom event name")
	do
		local valueRef = Rivue.ref(100)
		local props = directives_module.vModelProp(valueRef, "Position", "onPositionChanged")

		assertEquals(props.Position, 100, "Should have Position property")
		assertTrue(type(props.onPositionChanged) == "function", "Should have custom event handler")
	end

	print("Test 8: Built-in show directive exists")
	do
		local showDirective = directives_module.get("show")
		assertTrue(showDirective, "Should have show directive")
		assertTrue(showDirective.mounted, "Should have mounted hook")
		assertTrue(showDirective.updated, "Should have updated hook")
	end

	print("Test 9: Built-in drag directive exists")
	do
		local dragDirective = directives_module.get("drag")
		assertTrue(dragDirective, "Should have drag directive")
		assertTrue(dragDirective.mounted, "Should have mounted hook")
	end

	print("Test 10: Built-in fade-in directive exists")
	do
		local fadeInDirective = directives_module.get("fade-in")
		assertTrue(fadeInDirective, "Should have fade-in directive")
		assertTrue(fadeInDirective.mounted, "Should have mounted hook")
		assertTrue(fadeInDirective.unmounted, "Should have unmounted hook")
	end

	print("Test 11: Built-in preload directive exists")
	do
		local preloadDirective = directives_module.get("preload")
		assertTrue(preloadDirective, "Should have preload directive")
		assertTrue(preloadDirective.mounted, "Should have mounted hook")
	end

	print("Test 11b: preload takes a reactive list")
	if __OFFLINE then
		local icons = Rivue.reactive({ 101, 102 })
		local App = Rivue.defineComponent({
			name = "PreloadApp",
			render = function()
				return Rivue.h("ImageLabel", { vPreload = icons })
			end,
		})
		local app = Rivue.createApp(App)
		app:mount(Instance.new("Folder"))
		task.wait()
		assertEquals(table.concat(__preloaded, ","), "rbxassetid://101,rbxassetid://102", "both icons preload")
		app:unmount()
	end

	print("Test 12: vModelText handles debounce correctly")
	do
		local textRef = Rivue.ref("initial")
		local props = directives_module.vModelText(textRef, { debounce = 50 })

		props.onTextChanged("a")
		props.onTextChanged("ab")
		props.onTextChanged("abc")

		assertEquals(textRef.value, "initial", "Should not update immediately when debounced")

		task.wait(0.1)
		assertEquals(textRef.value, "abc", "Should update after debounce delay")
	end

	local printFooter = "DIRECTIVES TESTS COMPLETE"
	print("\n" .. string.rep("=", 40))
	print(printFooter)
	print(string.rep("=", 40) .. "\n")
end

return runTests
