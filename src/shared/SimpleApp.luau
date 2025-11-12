-- SimpleApp.luau - Simplified working version
--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))

local h = Rivue.h
local defineComponent = Rivue.defineComponent
local ref = Rivue.ref
local reactive = Rivue.reactive
local computed = Rivue.computed

-- Simple Counter Component
local Counter = defineComponent({
    name = "Counter",
    setup = function()
        local state = reactive({ count = 0 })
        local double = computed(function()
            return state.count * 2
        end)

        local inc = function()
            print("[INC] Button clicked! Current count:", state.count)
            local oldValue = state.count
            state.count = state.count + 1
            local newValue = state.count
            print("[INC] After increment - old:", oldValue, "new:", newValue)
            print("[INC] Are they different?", oldValue ~= newValue)
        end

        local dec = function()
            print("[DEC] Button clicked! Current count:", state.count)
            local oldValue = state.count
            state.count = state.count - 1
            local newValue = state.count
            print("[DEC] After decrement - old:", oldValue, "new:", newValue)
            print("[DEC] Are they different?", oldValue ~= newValue)
        end

        return function()
            return h("Frame", {
                Size = UDim2.new(1, -20, 0, 120),
                Position = UDim2.fromOffset(10, 40),
                BackgroundColor3 = Color3.fromRGB(50, 50, 60),
                BorderSizePixel = 2,
                BorderColor3 = Color3.fromRGB(100, 100, 120),
            }, {
                -- Title
                h("TextLabel", {
                    key = "counter-title",
                    Size = UDim2.new(1, 0, 0, 30),
                    Position = UDim2.fromOffset(0, 5),
                    BackgroundTransparency = 1,
                    Text = "Counter Demo",
                    TextColor3 = Color3.fromRGB(220, 220, 255),
                    TextSize = 18,
                    Font = Enum.Font.SourceSansBold,
                    TextXAlignment = Enum.TextXAlignment.Center,
                }),
                -- Count Display
                h("TextLabel", {
                    key = "counter-display",
                    Size = UDim2.new(1, -20, 0, 25),
                    Position = UDim2.fromOffset(10, 40),
                    BackgroundColor3 = Color3.fromRGB(30, 30, 40),
                    BorderSizePixel = 1,
                    BorderColor3 = Color3.fromRGB(80, 80, 100),
                    Text = "Count: " .. tostring(state.count) .. "  |  Double: " .. tostring(double.value),
                    TextColor3 = Color3.fromRGB(150, 200, 255),
                    TextSize = 16,
                    Font = Enum.Font.SourceSans,
                    TextXAlignment = Enum.TextXAlignment.Center,
                }),
                -- Decrement Button
                h("TextButton", {
                    key = "dec-btn",
                    Size = UDim2.new(0.5, -15, 0, 35),
                    Position = UDim2.fromOffset(10, 75),
                    BackgroundColor3 = Color3.fromRGB(200, 60, 60),
                    BorderSizePixel = 1,
                    BorderColor3 = Color3.fromRGB(150, 40, 40),
                    Text = "- Decrement",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 16,
                    Font = Enum.Font.SourceSansBold,
                    onClick = dec,
                }),
                -- Increment Button
                h("TextButton", {
                    key = "inc-btn",
                    Size = UDim2.new(0.5, -15, 0, 35),
                    Position = UDim2.new(0.5, 5, 0, 75),
                    BackgroundColor3 = Color3.fromRGB(60, 180, 100),
                    BorderSizePixel = 1,
                    BorderColor3 = Color3.fromRGB(40, 140, 70),
                    Text = "+ Increment",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 16,
                    Font = Enum.Font.SourceSansBold,
                    onClick = inc,
                }),
            })
        end
    end
})

-- Simple List Item
local Item = defineComponent({
    name = "ListItem",
    setup = function(props)
        return function()
            return h("TextLabel", {
                Size = UDim2.new(1, -20, 0, 30),
                BackgroundColor3 = Color3.fromRGB(60, 60, 70),
                BorderSizePixel = 1,
                BorderColor3 = Color3.fromRGB(90, 90, 110),
                Text = "  • " .. (props.name or "Item"),
                TextColor3 = Color3.fromRGB(230, 230, 245),
                TextSize = 15,
                Font = Enum.Font.SourceSans,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
        end
    end
})

-- Main App
local SimpleApp = defineComponent({
    name = "SimpleApp",
    setup = function()
        local items = ref({
            { id = 1, name = "Apple" },
            { id = 2, name = "Banana" },
            { id = 3, name = "Cherry" },
        })
        local input = ref("")

        local add = function()
            local oldTbl = items.value
            local newId = #oldTbl + 1
            local newName = input.value ~= "" and input.value or ("Item " .. tostring(newId))
            -- Create a new array to trigger reactivity
            -- NOTE: Numeric iteration is the standard pattern for reactive arrays.
            -- See docs/RUNTIME_REFERENCE.md "Iterating Reactive Arrays" section.
            local newTbl = {}
            for i = 1, #oldTbl do
                table.insert(newTbl, oldTbl[i])
            end
            table.insert(newTbl, { id = newId, name = newName })
            items.value = newTbl
            input.value = ""
            print("Added item:", newName)
        end

        return function()
            return h("ScreenGui", { ResetOnSpawn = false }, {
                -- CanvasGroup wrapper for optimized fade-in (single GroupTransparency tween)
                h("CanvasGroup", {
                    Size = UDim2.fromOffset(400, 550),
                    Position = UDim2.new(0.5, -200, 0.5, -275),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    __directives = {
                        { name = "drag", value = true },
                        { name = "fade-in", value = { duration = 1.5, delay = 0.3, waitForLoad = true } }
                    }
                }, {
                    -- Main Container Frame
                    h("Frame", {
                        Size = UDim2.fromScale(1, 1),
                        Position = UDim2.fromScale(0, 0),
                        BackgroundColor3 = Color3.fromRGB(35, 35, 45),
                        BorderSizePixel = 3,
                        BorderColor3 = Color3.fromRGB(100, 150, 255),
                    }, {
                    -- Header (Drag Handle)
                    h("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 35),
                        BackgroundColor3 = Color3.fromRGB(100, 150, 255),
                        BorderSizePixel = 0,
                        Text = "Vue-like Rivue Demo (Drag Me!)",
                        TextColor3 = Color3.new(1, 1, 1),
                        TextSize = 20,
                        Font = Enum.Font.SourceSansBold,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    }),
                    -- Counter Component
                    h(Counter),
                    -- Divider
                    h("Frame", {
                        Size = UDim2.new(1, -20, 0, 2),
                        Position = UDim2.fromOffset(10, 170),
                        BackgroundColor3 = Color3.fromRGB(80, 80, 100),
                        BorderSizePixel = 0,
                    }),
                    -- List Title
                    h("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 25),
                        Position = UDim2.fromOffset(0, 180),
                        BackgroundTransparency = 1,
                        Text = "Dynamic List",
                        TextColor3 = Color3.fromRGB(200, 200, 220),
                        TextSize = 17,
                        Font = Enum.Font.SourceSansBold,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    }),
                    -- Input Box
                    h("TextBox", {
                        Size = UDim2.new(1, -130, 0, 35),
                        Position = UDim2.fromOffset(10, 215),
                        BackgroundColor3 = Color3.fromRGB(50, 50, 60),
                        BorderSizePixel = 2,
                        BorderColor3 = Color3.fromRGB(100, 100, 120),
                        Text = input.value,
                        PlaceholderText = "Enter item name...",
                        PlaceholderColor3 = Color3.fromRGB(130, 130, 150),
                        TextColor3 = Color3.fromRGB(240, 240, 255),
                        TextSize = 15,
                        Font = Enum.Font.SourceSans,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ClearTextOnFocus = false,
                        onTextChanged = function(new)
                            input.value = new
                        end,
                    }),
                    -- Add Button
                    h("TextButton", {
                        Size = UDim2.fromOffset(110, 35),
                        Position = UDim2.new(1, -120, 0, 215),
                        BackgroundColor3 = Color3.fromRGB(100, 150, 255),
                        BorderSizePixel = 1,
                        BorderColor3 = Color3.fromRGB(70, 120, 220),
                        Text = "+ Add",
                        TextColor3 = Color3.new(1, 1, 1),
                        TextSize = 16,
                        Font = Enum.Font.SourceSansBold,
                        onClick = add,
                    }),
                    -- Items List Container with ScrollingFrame with ScrollingFrame
                    h("ScrollingFrame", {
                        Size = UDim2.new(1, -20, 0, 280),
                        Position = UDim2.fromOffset(10, 260),
                        BackgroundColor3 = Color3.fromRGB(45, 45, 55),
                        BorderSizePixel = 2,
                        BorderColor3 = Color3.fromRGB(70, 70, 90),
                        ScrollBarThickness = 8,
                        ScrollBarImageColor3 = Color3.fromRGB(100, 150, 255),
                        CanvasSize = UDim2.fromOffset(0, math.max(#items.value * 35, 280)),
                    }, (function()
                        local children = {}
                        local itemsArray = items.value
                        -- print("[RENDER] SimpleApp rendering, itemsArray length:", #itemsArray)
                        
                        -- Add UIListLayout for automatic positioning
                        table.insert(children, h("UIListLayout", {
                            SortOrder = Enum.SortOrder.LayoutOrder,
                            Padding = UDim.new(0, 0),
                        }))
                        
                        for i = 1, #itemsArray do
                            local it = itemsArray[i]
                            table.insert(children, h("Frame", {
                                key = it.id,
                                Size = UDim2.new(1, -10, 0, 35),
                                BackgroundTransparency = 1,
                                LayoutOrder = i,
                            }, {
                                h(Item, { name = it.name })
                            }))
                        end
                        
                        if #children == 1 then -- Only UIListLayout
                            table.insert(children, h("TextLabel", {
                                Size = UDim2.fromScale(1, 1),
                                BackgroundTransparency = 1,
                                Text = "No items yet.\nAdd some using the input above!",
                                TextColor3 = Color3.fromRGB(140, 140, 160),
                                TextSize = 14,
                                Font = Enum.Font.SourceSansItalic,
                                TextXAlignment = Enum.TextXAlignment.Center,
                                TextYAlignment = Enum.TextYAlignment.Center,
                                LayoutOrder = 999,
                            }))
                        end
                        
                        return children
                    end)()),
                }),
                }),
            })
        end
    end
})

return SimpleApp
