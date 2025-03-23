--!strict
-- Mounts every component in examples/components and uses it like a player would, so the examples in
-- the docs keep working.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local Examples = ReplicatedStorage:WaitForChild("Examples")

local h = Rivue.h

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

local function find(root: Instance, name: string): any
	for _, child in root:GetDescendants() do
		if child.Name == name then
			return child
		end
	end
	return nil
end

local function mount(component: any, props: any?): (Instance, any)
	local container = Instance.new("Frame")
	local app = Rivue.createApp(h(component, props))
	app:mount(container)
	return container, app
end

local function runTests()
	print("\n========== EXAMPLES TEST SUITE ==========\n")

	print("Example: Counter")
	do
		local container, app = mount(require(Examples:WaitForChild("Counter")), { start = 2 })
		local button = find(container, "Counter")
		assertEquals(button.Text, "Clicked 2 times (x2 = 4)", "Starts from the start prop")
		Rivue.testing.trigger(button, "onClick")
		task.wait()
		assertEquals(button.Text, "Clicked 3 times (x2 = 6)", "Click increments")
		app:unmount()
	end

	print("Example: TodoList")
	do
		local container, app = mount(require(Examples:WaitForChild("TodoList")))
		local input = find(container, "Input")
		for _, text in { "Milk", "Eggs" } do
			input.Text = text
			Rivue.testing.trigger(input, "onFocusLost", true)
			task.wait()
		end
		assertEquals(input.Text, "", "Input clears after adding")
		assertEquals(find(container, "Remaining").Text, "2 left", "Two todos")
		local first = find(container, "Toggle")
		assertEquals(first.Text, "[ ] Milk", "First todo rendered")
		assertTrue(
			first.Parent.LayoutOrder > find(container, "Input").LayoutOrder,
			"Todo rows are ordered after the input"
		)
		Rivue.testing.trigger(first, "onClick")
		task.wait()
		assertEquals(first.Text, "[x] Milk", "Toggle marks it done")
		assertEquals(find(container, "Remaining").Text, "1 left", "Remaining updates")
		Rivue.testing.trigger(find(container, "Remove"), "onClick")
		task.wait()
		assertEquals(find(container, "Toggle").Text, "[ ] Eggs", "Remove drops the todo")
		app:unmount()
	end

	print("Example: Inventory")
	do
		local items = {}
		for i = 1, 200 do
			items[i] = { id = i, name = `Item {i}`, count = 1 }
		end
		local container, app = mount(require(Examples:WaitForChild("Inventory")), { items = items })
		task.wait()
		local list = container:FindFirstChildOfClass("ScrollingFrame") :: ScrollingFrame
		assertTrue(#list:GetChildren() < 20, "Only visible rows are rendered")
		local row = list:GetChildren()[1] :: TextButton
		Rivue.testing.trigger(row, "onClick")
		task.wait()
		local color = row.BackgroundColor3
		assertTrue(
			math.abs(color.B - 220 / 255) < 1e-3 and math.abs(color.R - 60 / 255) < 1e-3,
			"Selecting a row highlights it"
		)
		app:unmount()
	end

	print("Example: Modal")
	do
		local Modal = require(Examples:WaitForChild("Modal"))
		local open = Rivue.ref(true)
		local Host = Rivue.defineComponent(function()
			return function()
				return h(Modal, {
					open = open.value,
					onClose = function()
						open.value = false
					end,
				}, {
					title = function()
						return h("TextLabel", { Name = "Title", Text = "Settings" })
					end,
				})
			end
		end, { name = "Host" })
		local container, app = mount(Host)
		local dialog = find(container, "Dialog")
		assertTrue(dialog ~= nil and find(dialog, "Title") ~= nil, "Dialog renders the title slot")
		open.value = false
		task.wait(0.3)
		assertTrue(find(container, "Dialog") == nil, "Dialog leaves when closed")
		app:unmount()
	end

	print("Example: Tabs")
	do
		local Tabs = require(Examples:WaitForChild("Tabs"))
		local Counter = require(Examples:WaitForChild("Counter"))
		local container, app = mount(Tabs, { tabs = { "One", "Two" } }, nil)
		app:unmount()
		local Host = Rivue.defineComponent(function()
			return function()
				return h(Tabs, { tabs = { "One", "Two" } }, {
					One = function()
						return h(Counter)
					end,
					Two = function()
						return h("TextLabel", { Name = "Second" })
					end,
				})
			end
		end, { name = "TabsHost" })
		container, app = mount(Host)
		local counter = find(container, "Counter")
		Rivue.testing.trigger(counter, "onClick")
		task.wait()
		Rivue.testing.trigger(find(container, "Two"), "onClick")
		task.wait()
		assertTrue(find(container, "Second") ~= nil, "Second tab shown")
		Rivue.testing.trigger(find(container, "One"), "onClick")
		task.wait()
		assertEquals(find(container, "Counter").Text, "Clicked 1 times (x2 = 2)", "First tab kept its state")
		app:unmount()
	end

	print("Example: Shop")
	do
		local bought: { string } = {}
		local api = {
			list = function()
				task.wait(0.1)
				return { { id = "sword", name = "Sword", price = 100 } }, nil
			end,
			buy = function(id: string)
				task.wait(0.1)
				table.insert(bought, id)
				return true, nil
			end,
		}
		local container, app = mount(require(Examples:WaitForChild("Shop")), { api = api })
		assertTrue(find(container, "Loading") ~= nil, "Shows loading first")
		task.wait(0.2)
		local sword = find(container, "sword")
		assertEquals(sword.Text, "Sword - 100", "Products render after loading")
		Rivue.testing.trigger(sword, "onClick")
		task.wait()
		assertEquals(sword.Text, "Buying...", "Pending state while buying")
		task.wait(0.2)
		assertEquals(bought[1], "sword", "Purchase went through the api")
		assertEquals(sword.Text, "Sword - 100", "Back to normal after buying")
		app:unmount()
	end

	print("Example: Hud")
	if not game:GetService("Players").LocalPlayer then
		print("  skipped: needs a local player")
	else
		local player = game:GetService("Players").LocalPlayer
		player:SetAttribute("Health", 100)
		local container, app = mount(require(Examples:WaitForChild("Hud")), { player = player })
		local fill = find(container, "Fill")
		assertEquals(fill.Size, UDim2.fromScale(1, 1), "Full health")
		player:SetAttribute("Health", 50)
		task.wait()
		assertEquals(find(container, "Value").Text, "50 / 100", "Label follows the attribute")
		task.wait(1)
		assertTrue(math.abs(fill.Size.X.Scale - 0.5) < 0.01, "Bar springs to the new value")
		app:unmount()
	end

	print("Demo app (dev/Demo)")
	do
		local Demo = ReplicatedStorage:WaitForChild("Demo")
		local App = require(Demo:WaitForChild("App"))
		local styles = require(Demo:WaitForChild("styles"))
		local container = Instance.new("Frame")
		local app = Rivue.createApp(App):styles(styles)
		app:mount(container)
		local window = container:FindFirstChild("DemoApp") :: Frame
		assertTrue(window:FindFirstChildOfClass("UICorner") ~= nil, "Styles from app:styles() are applied")

		local counter = find(container, "Counter")
		local buttons = {}
		for _, d in counter:GetDescendants() do
			if d:IsA("TextButton") then
				buttons[d.Text] = d
			end
		end
		Rivue.testing.trigger(buttons["+ Increment"], "onClick")
		task.wait()
		local countLabel
		for _, d in counter:GetDescendants() do
			if d:IsA("TextLabel") and string.find(d.Text, "Count:", 1, true) then
				countLabel = d
			end
		end
		assertEquals(countLabel.Text, "Count: 1  |  Double: 2", "Counter increments")

		local list = find(container, "ItemList")
		local function rows(): number
			local n = 0
			for _, d in list:GetDescendants() do
				if d.Name == "ListItem" then
					n += 1
				end
			end
			return n
		end
		assertEquals(rows(), 3, "Three starting items")
		local input: TextBox
		for _, d in list:GetDescendants() do
			if d:IsA("TextBox") then
				input = d
			end
		end
		input.Text = "Durian"
		for _, d in list:GetDescendants() do
			if d:IsA("TextButton") and d.Text == "Add" then
				Rivue.testing.trigger(d, "onClick")
			end
		end
		task.wait()
		assertEquals(rows(), 4, "Add pushes an item")
		assertEquals(input.Text, "", "Input clears")
		for _, d in list:GetDescendants() do
			if d:IsA("TextButton") and d.Text == "x" then
				Rivue.testing.trigger(d, "onClick")
				break
			end
		end
		task.wait()
		assertEquals(rows(), 3, "x removes an item")
		app:unmount()
	end

	print("\n========== EXAMPLES TESTS COMPLETE ==========\n")
end

return runTests
