--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))

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
	local printHeader = "COMPONENT TEST SUITE"
	print("\n" .. string.rep("=", 40))
	print(printHeader)
	print(string.rep("=", 40) .. "\n")

	print("Test 1: onMounted hook registration")
	do
		local mounted = false
		local TestComponent = Rivue.defineComponent({
			name = "TestMounted",
			setup = function()
				Rivue.onMounted(function()
					mounted = true
				end)
				return function()
					return Rivue.h("Frame")
				end
			end,
		})

		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.1)
		assertTrue(mounted, "Should call onMounted hook")
		app:unmount()
		container:Destroy()
	end

	print("Test 2: onUnmounted hook registration")
	do
		local unmounted = false
		local TestComponent = Rivue.defineComponent({
			name = "TestUnmounted",
			setup = function()
				Rivue.onUnmounted(function()
					unmounted = true
				end)
				return function()
					return Rivue.h("Frame")
				end
			end,
		})

		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.05)
		app:unmount()
		task.wait(0.05)
		assertTrue(unmounted, "Should call onUnmounted hook")
		container:Destroy()
	end

	print("Test 3: onBeforeMount hook registration")
	do
		local beforeMountCalled = false
		local TestComponent = Rivue.defineComponent({
			name = "TestBeforeMount",
			setup = function()
				Rivue.onBeforeMount(function()
					beforeMountCalled = true
				end)
				return function()
					return Rivue.h("Frame")
				end
			end,
		})

		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.1)
		assertTrue(beforeMountCalled, "Should call onBeforeMount hook")
		app:unmount()
		container:Destroy()
	end

	print("Test 4: onBeforeUnmount hook registration")
	do
		local beforeUnmountCalled = false
		local TestComponent = Rivue.defineComponent({
			name = "TestBeforeUnmount",
			setup = function()
				Rivue.onBeforeUnmount(function()
					beforeUnmountCalled = true
				end)
				return function()
					return Rivue.h("Frame")
				end
			end,
		})

		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.05)
		app:unmount()
		task.wait(0.05)
		assertTrue(beforeUnmountCalled, "Should call onBeforeUnmount hook")
		container:Destroy()
	end

	print("Test 5: Prop defaults are applied")
	do
		local receivedProps: any = nil
		local TestComponent = Rivue.defineComponent({
			name = "TestDefaults",
			props = {
				count = {
					type = "number",
					default = 10,
				},
			},
			setup = function(props)
				receivedProps = props
				return function()
					return Rivue.h("Frame")
				end
			end,
		})

		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.05)
		assertEquals(receivedProps.count, 10, "Should apply default prop value")
		app:unmount()
		container:Destroy()
	end

	print("Test 6: Factory function defaults")
	do
		local receivedProps: any = nil
		local TestComponent = Rivue.defineComponent({
			name = "TestFactoryDefaults",
			props = {
				config = {
					type = "table",
					default = function()
						return { x = 1, y = 2 }
					end,
				},
			},
			setup = function(props)
				receivedProps = props
				return function()
					return Rivue.h("Frame")
				end
			end,
		})

		local container = Instance.new("Folder")
		local app = Rivue.mount(TestComponent, container)
		task.wait(0.05)
		assertTrue(type(receivedProps.config) == "table", "Should apply factory default")
		assertTrue(receivedProps.config.x == 1, "Should have correct factory values")
		app:unmount()
		container:Destroy()
	end

	print("Test 7: ctx.expose() works")
	do
		local testRef = Rivue.ref(nil)
		local TestComponent = Rivue.defineComponent({
			name = "TestExpose",
			setup = function(_props, ctx)
				ctx.expose({
					testMethod = function()
						return "exposed"
					end,
				})
				return function()
					return Rivue.h("Frame")
				end
			end,
		})

		local container = Instance.new("Folder")
		local app = Rivue.mount(Rivue.h(TestComponent, { ref = testRef }), container)
		task.wait(0.1)
		assertTrue(testRef.value and true or false, "Ref should be set")
		if testRef.value then
			assertTrue(type(testRef.value.testMethod) == "function", "Should have exposed method")
			assertEquals(testRef.value.testMethod(), "exposed", "Exposed method should work")
		end
		app:unmount()
		container:Destroy()
	end

	local printFooter = "COMPONENT TESTS COMPLETE"
	print("Children run onUnmounted before their parent")
	do
		local order = {}
		local failed = nil
		local Item = Rivue.defineComponent({
			name = "RegistryItem",
			setup = function()
				local registry = Rivue.inject("registry") :: any
				registry.items.item = true
				Rivue.onUnmounted(function()
					table.insert(order, "child")
					registry.items.item = nil
				end)
				return {}
			end,
			render = function()
				return Rivue.h("Frame")
			end,
		})
		local List = Rivue.defineComponent({
			name = "RegistryList",
			setup = function()
				local registry = { items = {} }
				Rivue.provide("registry", registry)
				Rivue.onUnmounted(function()
					table.insert(order, "parent")
					registry.items = nil
				end)
				return {}
			end,
			render = function()
				return Rivue.h("Frame", nil, { Rivue.h(Item) })
			end,
		})
		local app = Rivue.createApp(List)
		app.config.errorHandler = function(err)
			failed = tostring(err)
		end
		app:mount(Instance.new("Folder"))
		app:unmount()
		assertEquals(table.concat(order, ","), "child,parent", "children first, like Vue")
		assertEquals(failed, nil, "so a child can still clean up into what its parent owns")
	end

	print("A re-render with unchanged props skips the props update, but keeps listeners current")
	do
		local h = Rivue.h
		local renders = 0
		local Child = Rivue.defineComponent({
			name = "PropsChild",
			props = { label = { type = "string" } },
			emits = { "select" },
			setup = function(_, ctx)
				return {
					fire = function()
						ctx.emit("select")
					end,
				}
			end,
			render = function(ctx)
				renders += 1
				return h("TextButton", { Name = "Btn", Text = ctx.label, onClick = ctx.fire })
			end,
		})
		local tick = Rivue.ref(0)
		local label = Rivue.ref("a")
		local selected = nil
		local App = Rivue.defineComponent(function()
			return function()
				local n = tick.value
				return h("Frame", nil, {
					h(Child, {
						label = label.value,
						onSelect = function()
							selected = n
						end,
					}),
				})
			end
		end, { name = "PropsHost" })
		local root = Instance.new("Folder")
		local app = Rivue.createApp(App)
		app:mount(root)
		local btn
		for _, d in root:GetDescendants() do
			if d.Name == "Btn" then
				btn = d
			end
		end
		tick.value = 1
		Rivue.nextTick()
		assertEquals(renders, 1, "a new listener closure alone doesn't re-render the child")
		Rivue.testing.trigger(btn, "onClick")
		assertEquals(selected, 1, "but emit calls the newest listener")
		label.value = "b"
		Rivue.nextTick()
		assertEquals(btn.Text, "b", "a changed prop still updates")
		app:unmount()
	end

	print("\n" .. string.rep("=", 40))
	print(printFooter)
	print(string.rep("=", 40) .. "\n")
end

return runTests
