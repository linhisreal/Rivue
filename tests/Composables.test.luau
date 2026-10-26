--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local composables_module =
	require(ReplicatedStorage:WaitForChild("Rivue"):WaitForChild("runtime"):WaitForChild("composables"))

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

local function assertFalse(condition: boolean, message: string?)
	if condition then
		error("Assertion failed: " .. (message or "condition is true"))
	end
	print("✓", message or "Assertion passed")
end

local function runTests()
	local printHeader = "COMPOSABLES TEST SUITE"
	print("\n" .. string.rep("=", 40))
	print(printHeader)
	print(string.rep("=", 40) .. "\n")

	print("Test 1: defineModel creates two-way binding ref")
	do
		local emitted = false
		local emittedValue = nil

		local mockProps = { modelValue = "initial" }
		local mockContext = {
			emit = function(_eventName: string, value: any)
				emitted = true
				emittedValue = value
			end,
		}

		local modelFactory = composables_module.defineModel()
		local model = modelFactory(mockProps, mockContext)

		assertEquals(model.value, "initial", "Should read initial value from props")

		model.value = "updated"
		assertTrue(emitted, "Should emit update event")
		assertEquals(emittedValue, "updated", "Should emit new value")
	end

	print("Test 2: defineModel with custom name and event")
	do
		local emittedEvent = ""
		local emittedValue = nil

		local mockProps = { title = "Hello" }
		local mockContext = {
			emit = function(eventName: string, value: any)
				emittedEvent = eventName
				emittedValue = value
			end,
		}

		local modelFactory = composables_module.defineModel({ name = "title", event = "update:title" })
		local model = modelFactory(mockProps, mockContext)

		assertEquals(model.value, "Hello", "Should read custom prop")

		model.value = "World"
		assertEquals(emittedEvent, "update:title", "Should emit custom event name")
		assertEquals(emittedValue, "World", "Should emit new value")
	end

	print("Test 3: useAttrs outside setup throws error")
	do
		local success = pcall(function()
			composables_module.useAttrs()
		end)
		assertFalse(success, "useAttrs should throw error outside setup")
	end

	print("Test 4: useSlots outside setup throws error")
	do
		local success = pcall(function()
			composables_module.useSlots()
		end)
		assertFalse(success, "useSlots should throw error outside setup")
	end

	print("Test 5: useTheme returns nil when no theme provided")
	do
		local theme = composables_module.useTheme()
		assertTrue(theme == nil, "Should return nil when no theme is provided")
	end

	print("Test 6: useStyles creates computed styles")
	do
		local styles = composables_module.useStyles(function(theme)
			return {
				backgroundColor = theme.primaryColor or Color3.fromRGB(255, 255, 255),
				textColor = theme.textColor or Color3.fromRGB(0, 0, 0),
			}
		end)

		assertTrue(styles.value ~= nil, "Should create computed styles")
		assertTrue(styles.value.backgroundColor ~= nil, "Should have backgroundColor")
		assertTrue(styles.value.textColor ~= nil, "Should have textColor")
	end

	print("Test 7: defineModel with number types")
	do
		local emittedValue = nil
		local mockProps = { modelValue = 42 }
		local mockContext = {
			emit = function(_: string, value: any)
				emittedValue = value
			end,
		}

		local modelFactory = composables_module.defineModel()
		local model = modelFactory(mockProps, mockContext)

		assertEquals(model.value, 42, "Should handle number values")

		model.value = 100
		assertEquals(emittedValue, 100, "Should emit updated number value")
	end

	print("Test 8: defineModel tracks reactive changes")
	do
		local props = Rivue.reactive({ modelValue = "test" })
		local mockContext = {
			emit = function(_: string, _: any) end,
		}

		local modelFactory = composables_module.defineModel()
		local model = modelFactory(props, mockContext)

		assertEquals(model.value, "test", "Should read reactive prop")

		props.modelValue = "changed"
		assertEquals(model.value, "changed", "Should reflect prop changes")
	end

	local printFooter = "COMPOSABLES TESTS COMPLETE"
	print("defineModel keeps its own value when the parent passes no model")
	do
		local useModel = Rivue.defineModel()
		local model: any
		local Toggle = Rivue.defineComponent({
			name = "LocalToggle",
			props = { modelValue = {} },
			setup = function(props, ctx)
				model = useModel(props, ctx)
				return { on = model }
			end,
			render = function(ctx)
				return Rivue.h("TextLabel", { Name = "Label", Text = tostring(ctx.on) })
			end,
		})
		local folder = Instance.new("Folder")
		local app = Rivue.createApp(Toggle)
		app:mount(folder)
		assertEquals(model.value, nil, "unbound, it starts empty")
		model.value = true
		Rivue.nextTick()
		assertEquals(model.value, true, "writes stick locally")
		assertEquals((folder:FindFirstChild("Label") :: TextLabel).Text, "true", "and re-render")
		app:unmount()

		local bound = Rivue.ref(false)
		local Parent = Rivue.defineComponent({
			name = "BoundParent",
			render = function()
				return Rivue.h(Toggle, { model = bound })
			end,
		})
		local boundApp = Rivue.createApp(Parent)
		boundApp:mount(Instance.new("Folder"))
		model.value = true
		Rivue.nextTick()
		assertEquals(bound.value, true, "bound, writes still go to the parent")
		bound.value = false
		Rivue.nextTick()
		assertEquals(model.value, false, "and the parent's value wins")
		boundApp:unmount()
	end

	print("useStyles follows a theme provided as a ref")
	do
		local theme = Rivue.ref({ surface = "dark" })
		local seen = nil
		local Card = Rivue.defineComponent({
			name = "RefThemeCard",
			setup = function()
				return {
					styles = Rivue.useStyles(function(t: any)
						return { surface = t.surface }
					end),
				}
			end,
			render = function(ctx)
				seen = ctx.styles.surface
				return Rivue.h("Frame")
			end,
		})
		local app = Rivue.createApp(Card)
		app:provide("theme", theme)
		app:mount(Instance.new("Folder"))
		assertEquals(seen, "dark", "the ref's value reaches the factory")
		theme.value = { surface = "light" }
		Rivue.nextTick()
		assertEquals(seen, "light", "and swapping it rebuilds the styles")
		app:unmount()
	end

	print("\n" .. string.rep("=", 40))
	print(printFooter)
	print(string.rep("=", 40) .. "\n")
end

return runTests
