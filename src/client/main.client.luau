-- main.client.lua (LocalScript)
-- Mount the example App into PlayerGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Require the Rivue ModuleScript
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local SimpleApp = require(ReplicatedStorage:WaitForChild("SimpleApp"))

Rivue.dev = true

print("==== Rivue TEST ====")
print("Rivue loaded")

local h = Rivue.h
local reactive = Rivue.reactive
local ref = Rivue.ref

-- Test reactive proxy printing with new __tostring
local state = reactive({ user = { name = "Alice", age = 30 } })
local count = ref(42)

print("\n=== Testing Reactive Printing ===")
print("Direct print of reactive proxy:", state)
print("Direct print of ref:", count)

print("\n=== Testing Rivue.prettyPrint ===")
print("prettyPrint unwraps reactive proxies:")
Rivue.prettyPrint(state)

print("\nprettyPrint with ref:")
Rivue.prettyPrint(count)

print("\n=== Testing Rivue.inspect ===")
local inspected = Rivue.inspect(state)
print("inspect() returns:", inspected)

print("\n=== Testing nested reactive structures ===")
local complexState = reactive({
	users = {
		{ name = "Alice", age = 30 },
		{ name = "Bob", age = 25 },
	},
	settings = {
		theme = "dark",
		notifications = true,
	},
})
print("Complex state with prettyPrint:")
Rivue.prettyPrint(complexState)

print("\n=== Testing circular reference handling ===")
local circular: any = reactive({ name = "circular" })
circular.self = circular
print("Circular reference (should handle gracefully):")
Rivue.prettyPrint(circular)

local vnode = h(SimpleApp)
print("VNode created")

local app = Rivue.createApp(vnode, { usePool = false })
print("App created")

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Name = "AppRoot"
screenGui.Parent = playerGui
print("ScreenGui created")

print("Mounting app...")
app:mount(screenGui)
print("✓ App mounted successfully!")
