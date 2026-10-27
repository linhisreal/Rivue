--!strict
--!optimize 2

local Types = require("./types")
local componentModule = require("./component")
local hModule = require("./h")
local reactivity = require("./reactivity")
local roblox = require("./roblox")
local builtins = require("./builtins")

local h = hModule.h
local Fragment = hModule.Fragment

type ComponentDef = Types.ComponentDef
type Props = Types.Props
type SetupContext = Types.SetupContext
type VNode = Types.VNode

local ui = {}

--- Shows `fallback` instead of its children when something inside throws, so one broken widget
--- doesn't take the whole screen with it. `fallback` can be a vnode or a function of
--- (message, reset) that returns one; reset() tries the children again
ui.ErrorBoundary = table.freeze({
	__is_component = true :: true,
	__name = "ErrorBoundary",
	props = {
		fallback = {},
		onError = { type = "function" :: "function" },
	},
	setup = function(props: Props, context: SetupContext)
		local failure = reactivity.shallowRef(nil :: { message: string, info: string }?)
		componentModule.onErrorCaptured(function(err: string, _instance: unknown, info: string)
			failure.value = { message = err, info = info }
			local onError = props.onError
			if type(onError) == "function" then
				local ok, handlerErr = pcall(onError, err, info)
				if not ok then
					warn(`[Rivue] ErrorBoundary onError failed: {handlerErr}`)
				end
			end
			return false
		end)
		local function reset()
			failure.value = nil
		end
		return function(): VNode?
			local failed = failure.value
			if failed then
				local fallback = props.fallback
				if type(fallback) == "function" then
					return fallback(failed.message, reset)
				end
				return fallback
			end
			return h(Fragment, nil, context.renderSlot("default"))
		end
	end,
}) :: any

local function firstSelectable(root: Instance): GuiObject?
	for _, d in root:GetDescendants() do
		if (d:IsA("GuiButton") or d:IsA("TextBox")) and (d :: GuiObject).Selectable then
			return d :: GuiObject
		end
	end
	return nil
end

ui.Dialog = table.freeze({
	__is_component = true :: true,
	__name = "Dialog",
	props = {
		open = { type = "boolean" :: "boolean", required = true },
		onClose = { type = "function" :: "function" },
		closeOnBackdrop = { type = "boolean" :: "boolean", default = true },
		closeOnEscape = { type = "boolean" :: "boolean", default = true },
		backdropColor = { default = Color3.new(0, 0, 0) },
		backdropTransparency = { type = "number" :: "number", default = 0.4 },
		zIndex = { type = "number" :: "number", default = 100 },
		-- Transition props for the panel, such as Rivue.transitions.pop()
		transition = { type = "table" :: "table" },
	},
	setup = function(props: Props, context: SetupContext)
		local panel = componentModule.useTemplateRef("dialogPanel")
		local focusTarget = reactivity.shallowRef(nil :: GuiObject?)

		local function close()
			local onClose = props.onClose
			if type(onClose) == "function" then
				onClose()
			end
		end

		roblox.useKeybind({ Enum.KeyCode.Escape, Enum.KeyCode.ButtonB }, close, {
			enabled = function(): boolean
				return props.open == true and props.closeOnEscape ~= false
			end,
		})

		-- Once the panel is on screen, its first button is what a gamepad starts on
		reactivity.watch(function()
			return { props.open, panel.value }
		end, function(values: { any })
			local root = values[2]
			focusTarget.value = if values[1] and typeof(root) == "Instance" then firstSelectable(root) else nil
		end, { immediate = true, flush = "post" })
		roblox.useGamepadFocus(focusTarget)

		return function(): VNode?
			if not props.open then
				return nil
			end
			local content = h("Frame", {
				Name = "DialogPanel",
				ref = "dialogPanel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				ZIndex = (props.zIndex :: number) + 1,
				-- Keeps gamepad navigation inside the dialog
				SelectionGroup = true,
				SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
				SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
				SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			}, context.renderSlot("default"))
			if props.transition then
				local transitionProps = table.clone(props.transition :: { [string]: any })
				transitionProps.appear = true
				content = h(builtins.Transition :: ComponentDef, transitionProps, { content })
			end
			return h("TextButton", {
				Name = "DialogBackdrop",
				Text = "",
				AutoButtonColor = false,
				Selectable = false,
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = props.backdropColor,
				BackgroundTransparency = props.backdropTransparency,
				ZIndex = props.zIndex,
				onActivated = function()
					if props.closeOnBackdrop ~= false then
						close()
					end
				end,
			}, { content })
		end
	end,
}) :: any

local function layoutComponent(name: string, direction: string): ComponentDef
	return table.freeze({
		__is_component = true :: true,
		__name = name,
		props = {
			gap = {},
			align = { type = "string" :: "string" },
			justify = { type = "string" :: "string" },
			wrap = { type = "boolean" :: "boolean" },
		},
		setup = function(props: Props, context: SetupContext)
			return function(): VNode
				-- Anything not declared above (Size, Position, Name, ...) falls through to the Frame
				return h("Frame", {
					BackgroundTransparency = 1,
					Size = if direction == "horizontal" then UDim2.fromScale(1, 0) else UDim2.fromScale(0, 1),
					AutomaticSize = if direction == "horizontal" then Enum.AutomaticSize.Y else Enum.AutomaticSize.X,
					layout = {
						direction = direction,
						gap = props.gap,
						align = props.align,
						justify = props.justify,
						wrap = props.wrap,
					},
				}, context.renderSlot("default"))
			end
		end,
	}) :: any
end

ui.Row = layoutComponent("Row", "horizontal")
ui.Column = layoutComponent("Column", "vertical")

ui.Spacer = table.freeze({
	__is_component = true :: true,
	__name = "Spacer",
	render = function(): VNode
		return h("Frame", { BackgroundTransparency = 1, Size = UDim2.new(), flex = "fill" })
	end,
}) :: any

return table.freeze(ui)
