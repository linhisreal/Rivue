--!strict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))

local TestSupport = require(game:GetService("ReplicatedStorage"):WaitForChild("TestSupport"))
local assertEquals = TestSupport.assertEquals
local assertTrue = TestSupport.assertTrue

local function captureWarnings(fn: () -> ()): { string }
	local warnings = {}
	local connection = LogService.MessageOut:Connect(function(message: string, kind: Enum.MessageType)
		if kind == Enum.MessageType.MessageWarning then
			table.insert(warnings, message)
		end
	end)
	fn()
	task.wait()
	connection:Disconnect()
	return warnings
end

local function runTests()
	print("\n========== VAPOR TEST SUITE ==========\n")

	print("Without the flag, a vapor component renders normally and warns once")
	do
		local count = Rivue.ref(0)
		local renders = 0
		local Counter = Rivue.defineComponent({
			name = "VaporCounterOff",
			vapor = true,
			setup = function()
				return function()
					renders += 1
					return Rivue.h("TextLabel", { Name = "Label", Text = tostring(count.value) })
				end
			end,
		})
		local warnings = captureWarnings(function()
			local app = Rivue.createApp(Counter)
			app:mount(Instance.new("Folder"))
			count.value = 1
			Rivue.nextTick()
			app:unmount()
			local again = Rivue.createApp(Counter)
			again:mount(Instance.new("Folder"))
			again:unmount()
		end)
		assertEquals(renders, 3, "it re-renders like a normal component")
		local matching = 0
		for _, message in warnings do
			if string.find(message, "experimental.vapor", 1, true) then
				matching += 1
			end
		end
		assertEquals(matching, 1, "one warning per component, naming the flag")
	end

	print("A vapor component renders once and updates through bindings")
	do
		local count = Rivue.ref(0)
		local renders, mounted, unmounted = 0, 0, 0
		local Counter = Rivue.defineComponent({
			name = "VaporCounter",
			vapor = true,
			setup = function()
				Rivue.onMounted(function()
					mounted += 1
				end)
				Rivue.onUnmounted(function()
					unmounted += 1
				end)
				return function()
					renders += 1
					return Rivue.h("Frame", { Name = "Root" }, {
						Rivue.h("TextLabel", {
							Name = "Bound",
							Text = Rivue.bind(function()
								return tostring(count.value)
							end),
						}),
						Rivue.h("TextLabel", { Name = "Read", Text = tostring(count.value) }),
					})
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Counter)
		app.config.experimental = { vapor = true }
		app:mount(container)
		count.value = 5
		Rivue.nextTick()
		local root = container:FindFirstChild("Root") :: Frame
		assertEquals(renders, 1, "render ran once")
		assertEquals((root:FindFirstChild("Bound") :: TextLabel).Text, "5", "the bound label updates")
		assertEquals((root:FindFirstChild("Read") :: TextLabel).Text, "0", "a value read directly stays as rendered")
		assertEquals(mounted, 1, "onMounted ran")
		app:unmount()
		assertEquals(unmounted, 1, "onUnmounted ran")
		count.value = 6
		Rivue.nextTick()
		assertEquals(#container:GetChildren(), 0, "nothing left after unmount, and the binding is stopped")
	end

	print("A vapor parent passes reactive data to a child through a getter prop")
	do
		local score = Rivue.ref(1)
		local childRenders = 0
		local Badge = Rivue.defineComponent({
			name = "Badge",
			props = { value = { type = "number" } },
			setup = function(props)
				return function()
					childRenders += 1
					return Rivue.h("TextLabel", { Name = "Badge", Text = tostring(props.value) })
				end
			end,
		})
		local Panel = Rivue.defineComponent({
			name = "VaporPanel",
			vapor = true,
			setup = function()
				return function()
					return Rivue.h(Badge, { value = score })
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Panel)
		app.config.experimental = { vapor = true }
		app:mount(container)
		score.value = 7
		Rivue.nextTick()
		assertEquals((container:FindFirstChild("Badge", true) :: TextLabel).Text, "7", "the child sees the new value")
		assertEquals(childRenders, 2, "the normal child re-renders for its changed prop")
		app:unmount()
		score.value = 8
		Rivue.nextTick()
		assertEquals(childRenders, 2, "the prop watcher stopped on unmount")
	end

	print("A vapor child inside a normal parent keeps getter props in sync without re-rendering")
	do
		local label = Rivue.ref("a")
		local tick = Rivue.ref(0)
		local vaporRenders = 0
		local Tag = Rivue.defineComponent({
			name = "VaporTag",
			vapor = true,
			props = { text = { type = "string" } },
			setup = function(props)
				return function()
					vaporRenders += 1
					return Rivue.h("TextLabel", {
						Name = "Tag",
						Text = Rivue.bind(function()
							return props.text
						end),
					})
				end
			end,
		})
		local Parent = Rivue.defineComponent(function()
			return function()
				local _ = tick.value
				return Rivue.h(Tag, { text = label })
			end
		end, { name = "NormalParent" })
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Parent)
		app.config.experimental = { vapor = true }
		app:mount(container)
		label.value = "b"
		tick.value += 1
		Rivue.nextTick()
		assertEquals((container:FindFirstChild("Tag", true) :: TextLabel).Text, "b", "the getter prop updated")
		assertEquals(vaporRenders, 1, "the vapor child didn't re-render")
		app:unmount()
	end

	print("With the flag off, a ref passed as a prop arrives unchanged")
	do
		local score = Rivue.ref(1)
		local received: any = nil
		local Child = Rivue.defineComponent({
			name = "PlainChild",
			props = { value = {} },
			setup = function(props)
				received = props.value
				return function()
					return Rivue.h("Frame")
				end
			end,
		})
		local Root = Rivue.defineComponent(function()
			return function()
				return Rivue.h(Child, { value = score })
			end
		end, { name = "PlainRoot" })
		local app = Rivue.createApp(Root)
		app:mount(Instance.new("Folder"))
		assertTrue(Rivue.isRef(received), "the child got the ref itself")
		app:unmount()
	end

	print("createIf swaps branches without re-rendering the vapor component")
	do
		local open = Rivue.ref(false)
		local renders = 0
		local Menu = Rivue.defineComponent({
			name = "VaporMenu",
			vapor = true,
			setup = function()
				return function()
					renders += 1
					return Rivue.h("Frame", { Name = "Root" }, {
						Rivue.createIf(function()
							return open.value
						end, function()
							return Rivue.h("TextLabel", { Name = "Open" })
						end, function()
							return Rivue.h("TextLabel", { Name = "Closed" })
						end),
					})
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Menu)
		app.config.experimental = { vapor = true }
		app:mount(container)
		local root = container:FindFirstChild("Root") :: Frame
		assertTrue(root:FindFirstChild("Closed") ~= nil, "starts on the no branch")
		open.value = true
		open.value = false
		open.value = true
		Rivue.nextTick()
		assertTrue(
			root:FindFirstChild("Open") ~= nil and root:FindFirstChild("Closed") == nil,
			"ends on the final branch"
		)
		assertEquals(#root:GetChildren(), 1, "exactly one branch mounted")
		assertEquals(renders, 1, "the component never re-rendered")
		app:unmount()
		open.value = false
		Rivue.nextTick()
		assertEquals(#container:GetChildren(), 0, "the block stopped on unmount")
	end

	print("createIf inside a normal component follows parent re-renders")
	do
		local open = Rivue.ref(true)
		local label = Rivue.ref("one")
		local Panel = Rivue.defineComponent(function()
			return function()
				local text = label.value
				return Rivue.h("Frame", { Name = "Root" }, {
					Rivue.createIf(function()
						return open.value
					end, function()
						return Rivue.h("TextLabel", { Name = "Shown", Text = text })
					end),
				})
			end
		end, { name = "NormalWithIf" })
		local container = Instance.new("Folder")
		local app = Rivue.createApp(Panel)
		app:mount(container)
		local root = container:FindFirstChild("Root") :: Frame
		label.value = "two"
		Rivue.nextTick()
		assertEquals((root:FindFirstChild("Shown") :: TextLabel).Text, "two", "a parent re-render reaches the branch")
		open.value = false
		Rivue.nextTick()
		assertEquals(root:FindFirstChild("Shown"), nil, "and the condition still works")
		app:unmount()
	end

	print("createFor adds, removes and reorders rows without rebuilding kept ones")
	do
		local rowA, rowB, rowC = { id = 1, name = "a" }, { id = 2, name = "b" }, { id = 3, name = "c" }
		local items = Rivue.ref({ rowA, rowB })
		local built = 0
		local List = Rivue.defineComponent({
			name = "VaporList",
			vapor = true,
			setup = function()
				return function()
					return Rivue.h("Frame", { Name = "Root" }, {
						Rivue.h("UIListLayout"),
						Rivue.createFor(function()
							return items.value
						end, function(item)
							return item.id
						end, function(item)
							built += 1
							return Rivue.h("TextLabel", { Name = `Row{item.id}`, Text = item.name })
						end),
					})
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(List)
		app.config.experimental = { vapor = true }
		app:mount(container)
		local root = container:FindFirstChild("Root") :: Frame
		local row1 = root:FindFirstChild("Row1")
		items.value = { rowB, rowC, rowA }
		Rivue.nextTick()
		assertEquals(built, 3, "only the new row was built")
		assertTrue(root:FindFirstChild("Row1") == row1, "kept rows keep their Instance")
		assertTrue(
			(root:FindFirstChild("Row2") :: TextLabel).LayoutOrder
				< (root:FindFirstChild("Row1") :: TextLabel).LayoutOrder,
			"and follow the new order"
		)
		items.value = { rowC }
		Rivue.nextTick()
		assertTrue(root:FindFirstChild("Row1") == nil and root:FindFirstChild("Row2") == nil, "removed rows are gone")
		local warnings = captureWarnings(function()
			items.value = { { id = 4, name = "d" }, { id = 4, name = "e" } }
			Rivue.nextTick()
		end)
		local duplicateWarned = false
		for _, message in warnings do
			if string.find(message, "Duplicate key", 1, true) then
				duplicateWarned = true
			end
		end
		if game:GetService("RunService"):IsStudio() then
			assertTrue(duplicateWarned, "duplicate keys warn")
		end
		assertTrue(root:FindFirstChild("Row4") ~= nil, "a list with duplicate keys still renders")
		app:unmount()
		items.value = {}
		Rivue.nextTick()
		assertEquals(#container:GetChildren(), 0, "the block stopped on unmount")
	end

	print("createFor rebuilds a row whose item was replaced under the same key")
	do
		local items = Rivue.ref({ { id = 1, name = "a" } })
		local List = Rivue.defineComponent({
			name = "VaporReplace",
			vapor = true,
			setup = function()
				return function()
					return Rivue.h("Frame", { Name = "Root" }, {
						Rivue.createFor(function()
							return items.value
						end, function(item)
							return item.id
						end, function(item)
							return Rivue.h("TextLabel", { Name = `Row{item.id}`, Text = item.name })
						end),
					})
				end
			end,
		})
		local container = Instance.new("Folder")
		local app = Rivue.createApp(List)
		app.config.experimental = { vapor = true }
		app:mount(container)
		local root = container:FindFirstChild("Root") :: Frame
		local row = root:FindFirstChild("Row1")
		items.value = { { id = 1, name = "renamed" } }
		Rivue.nextTick()
		assertEquals((root:FindFirstChild("Row1") :: TextLabel).Text, "renamed", "the new item's data shows")
		assertTrue(root:FindFirstChild("Row1") == row, "and the row keeps its Instance")
		app:unmount()
	end

	print("With the flag on, refs between two normal components still pass unchanged")
	do
		local score = Rivue.ref(1)
		local received: any = nil
		local Child = Rivue.defineComponent({
			name = "PlainChildFlagOn",
			props = { value = {} },
			setup = function(props)
				received = props.value
				return function()
					return Rivue.h("Frame")
				end
			end,
		})
		local Root = Rivue.defineComponent(function()
			return function()
				return Rivue.h(Child, { value = score })
			end
		end, { name = "PlainRootFlagOn" })
		local app = Rivue.createApp(Root)
		app.config.experimental = { vapor = true }
		app:mount(Instance.new("Folder"))
		assertTrue(Rivue.isRef(received), "only vapor parents or children get getter props")
		app:unmount()
	end

	print("\n========== VAPOR TESTS COMPLETE ==========\n")
end

return runTests
