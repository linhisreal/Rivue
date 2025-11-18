--!optimize 2
--[[
    TestEnhancements.luau
    =====================
    
    Comprehensive test demonstrating all new Vue 3 component enhancements:
    1. Default prop values (primitive and factory functions)
    2. Prop validators (custom validation functions)
    3. ctx.expose() API for parent-child communication
    4. ctx.attrs for non-declared attributes
    5. onBeforeMount, onBeforeUpdate, onBeforeUnmount lifecycle hooks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))

local h = Rivue.h
local ref = Rivue.ref
local reactive = Rivue.reactive
local onBeforeMount = Rivue.onBeforeMount
local onMounted = Rivue.onMounted
local onBeforeUpdate = Rivue.onBeforeUpdate
local onUpdated = Rivue.onUpdated
local onBeforeUnmount = Rivue.onBeforeUnmount
local onUnmounted = Rivue.onUnmounted

--[[
    Feature 1 & 2: Default Props and Validators
    
    Demonstrates:
    - Primitive default values
    - Factory function defaults for objects/tables
    - Custom validator functions with validation logic
]]
local Counter = Rivue.defineComponent({
	name = "Counter",
	props = {
		-- Primitive default value
		initialCount = {
			type = "number",
			default = 0,
			validator = function(val: number): boolean
				return val >= 0 and val <= 100 -- Count must be between 0-100
			end,
		},

		-- Factory function default for object
		config = {
			type = "table",
			default = function(): { step: number, max: number }
				return {
					step = 1,
					max = 10,
				}
			end,
		},

		-- Required prop with type validation
		label = {
			type = "string",
			required = true,
		},

		-- Optional prop with validator
		color = {
			type = "string",
			validator = function(val: string): boolean
				local validColors = { "red", "green", "blue", "yellow" }
				for _, color in ipairs(validColors) do
					if val == color then
						return true
					end
				end
				return false
			end,
		},
	},

	setup = function(props, ctx)
		local count = ref(props.initialCount)
		local lifecycleLogs = reactive({ events = {} })

		local function log(event: string)
			table.insert(lifecycleLogs.events, {
				event = event,
				timestamp = os.clock(),
				count = count.value,
			})
			print(string.format("[%s] %s - Count: %d", props.label, event, count.value))
		end

		--[[
            Feature 5: Before* Lifecycle Hooks
            
            Demonstrates the execution order:
            1. onBeforeMount -> before first render
            2. onMounted -> after first render
            3. onBeforeUpdate -> before re-render
            4. onUpdated -> after re-render
            5. onBeforeUnmount -> before cleanup
            6. onUnmounted -> after cleanup
        ]]
		onBeforeMount(function()
			log("onBeforeMount")
			-- Good place to: prepare data, validate props, setup external connections
		end)

		onMounted(function()
			log("onMounted")
			-- Good place to: access DOM, start animations, fetch data
		end)

		onBeforeUpdate(function()
			log("onBeforeUpdate")
			-- Good place to: save state, cancel pending operations
		end)

		onUpdated(function()
			log("onUpdated")
			-- Good place to: react to DOM changes, restart animations
		end)

		onBeforeUnmount(function()
			log("onBeforeUnmount")
			-- Good place to: save final state, show confirmation dialogs
		end)

		onUnmounted(function()
			log("onUnmounted")
			-- Good place to: cleanup connections, remove event listeners
		end)

		--[[
            Feature 3: ctx.expose() API
            
            Exposes specific methods/values to parent via template ref
            Only exposed members are accessible, internal state stays private
        ]]
		ctx.expose({
			increment = function()
				if count.value < props.config.max then
					count.value = math.min(props.config.max, count.value + props.config.step)
				end
			end,
			decrement = function()
				if count.value > 0 then
					count.value = math.max(0, count.value - props.config.step)
				end
			end,
			reset = function()
				count.value = props.initialCount
			end,
			getCount = function()
				return count.value
			end,
			getLogs = function()
				return lifecycleLogs.events
			end,
		})

		--[[
            Feature 4: ctx.attrs
            
            Non-declared props are automatically separated into attrs
            Useful for passing through HTML-like attributes
        ]]
		print(string.format("[%s] Received attrs:", props.label))
		for key, value in pairs(ctx.attrs) do
			print(string.format("  - %s: %s", key, tostring(value)))
		end

		return function()
			return h("Frame", {
				Size = UDim2.new(1, 0, 0, 100),
				BackgroundColor3 = Color3.fromRGB(240, 240, 240),
			}, {
				h("TextLabel", {
					Size = UDim2.new(1, -20, 0, 30),
					Position = UDim2.fromOffset(10, 10),
					Text = string.format("%s: %d / %d", props.label, count.value, props.config.max),
					TextColor3 = if props.color == "red"
						then Color3.fromRGB(255, 0, 0)
						elseif props.color == "green" then Color3.fromRGB(0, 255, 0)
						elseif props.color == "blue" then Color3.fromRGB(0, 0, 255)
						else Color3.fromRGB(0, 0, 0),
				}),

				h("TextButton", {
					Size = UDim2.new(0.3, -10, 0, 40),
					Position = UDim2.fromOffset(10, 50),
					Text = "-",
					onClick = function()
						if count.value > 0 then
							count.value = math.max(0, count.value - props.config.step)
						end
					end,
				}),

				h("TextButton", {
					Size = UDim2.new(0.3, -10, 0, 40),
					Position = UDim2.new(0.35, 5, 0, 50),
					Text = "Reset",
					onClick = function()
						count.value = props.initialCount
					end,
				}),

				h("TextButton", {
					Size = UDim2.new(0.3, -10, 0, 40),
					Position = UDim2.new(0.7, 10, 0, 50),
					Text = "+",
					onClick = function()
						if count.value < props.config.max then
							count.value = math.min(props.config.max, count.value + props.config.step)
						end
					end,
				}),
			})
		end
	end,
})

--[[
    Parent Component - Demonstrates ctx.expose() usage via template refs
]]
local ParentComponent = Rivue.defineComponent({
	name = "ParentComponent",

	setup = function()
		-- Template refs to access child components via exposed API
		local counter1Ref = ref(nil)
		local counter2Ref = ref(nil)

		onMounted(function()
			print("\n=== Parent Component Mounted ===")
			print("Testing ctx.expose() API via template refs:\n")

			-- Wait a bit for children to mount
			task.wait(1)

			if counter1Ref.value then
				print("Counter 1 initial count:", counter1Ref.value.getCount())
				print("Incrementing counter 1...")
				counter1Ref.value.increment()
				counter1Ref.value.increment()
				print("Counter 1 new count:", counter1Ref.value.getCount())
			end

			task.wait(1)

			if counter2Ref.value then
				print("\nCounter 2 initial count:", counter2Ref.value.getCount())
				print("Decrementing counter 2...")
				counter2Ref.value.decrement()
				print("Counter 2 new count:", counter2Ref.value.getCount())
				print("\nCounter 2 lifecycle logs:")
				for i, log in ipairs(counter2Ref.value.getLogs()) do
					print(string.format("  %d. %s at %.3fs", i, log.event, log.timestamp))
				end
			end
		end)

		return function()
			return h("ScreenGui", {}, {
				-- Counter 1: Uses default props
				h(Counter, {
					ref = counter1Ref,
					label = "Counter A",
					color = "blue",
					-- Non-declared props go to attrs
					customAttr1 = "test1",
					customAttr2 = 42,
				}),

				-- Counter 2: Overrides defaults with custom config
				h(Counter, {
					ref = counter2Ref,
					label = "Counter B",
					initialCount = 5,
					config = {
						step = 2,
						max = 20,
					},
					color = "red",
					-- Non-declared props go to attrs
					dataId = "counter-b",
					testFlag = true,
				}),
			})
		end
	end,
})

--[[
    Test Execution
]]
print("\n========================================")
print("Vue 3 Component Enhancements Test Suite")
print("========================================\n")

print("Testing Features:")
print("1. Default prop values (primitive + factory)")
print("2. Prop validators (custom validation)")
print("3. ctx.expose() API (template refs)")
print("4. ctx.attrs (non-declared props)")
print("5. Before* lifecycle hooks (onBeforeMount/Update/Unmount)\n")

return {
	Counter = Counter,
	ParentComponent = ParentComponent,

	-- Test runner
	runTest = function(parent: Instance)
		print("Mounting test application...")
		return Rivue.mount(ParentComponent, parent)
	end,
}
