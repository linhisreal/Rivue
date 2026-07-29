--!strict
--!optimize 2

local Types = require("./types")

type DirectiveHooks = Types.Directive
type Ref<T> = Types.Ref<T>

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local reactivity = require("./reactivity")
local debugModule = require("./debug")

local directives = {}
local registry: { [string]: DirectiveHooks } = {}

function directives.register(name: string, hooks: DirectiveHooks): ()
	local hookCount = 0
	if hooks.mounted then
		hookCount = hookCount + 1
	end
	if hooks.updated then
		hookCount = hookCount + 1
	end
	if hooks.unmounted then
		hookCount = hookCount + 1
	end
	debugModule.log("Directives", "Registering directive", { name = name, hookCount = hookCount })
	registry[name] = hooks
end

function directives.get(name: string): DirectiveHooks?
	debugModule.log("Directives", "Getting directive", { name = name, found = registry[name] ~= nil })
	return registry[name]
end

directives.register("focus", {
	mounted = function(el, val)
		if val and el:IsA("TextBox") then
			el:CaptureFocus()
		end
		return { on = val and true or false }
	end,
	updated = function(el, val, state)
		local on = val and true or false
		if on and not (state and state.on) and el:IsA("TextBox") then
			el:CaptureFocus()
		end
		return { on = on }
	end,
})

directives.register("select", {
	mounted = function(el, val)
		if val and el:IsA("GuiObject") then
			GuiService.SelectedObject = el
		end
		return { on = val and true or false }
	end,
	updated = function(el, val, state)
		local on = val and true or false
		local was = state and state.on
		if el:IsA("GuiObject") then
			if on and not was then
				GuiService.SelectedObject = el
			elseif not on and was and GuiService.SelectedObject == el then
				GuiService.SelectedObject = nil
			end
		end
		return { on = on }
	end,
	unmounted = function(el)
		if GuiService.SelectedObject == el then
			GuiService.SelectedObject = nil
		end
	end,
})

type ClickOutsideState = { conn: RBXScriptConnection, fn: () -> () }

directives.register("click-outside", {
	mounted = function(el, fn): ClickOutsideState?
		if type(fn) ~= "function" then
			return nil
		end

		local state: ClickOutsideState
		local conn = UserInputService.InputBegan:Connect(function(input)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end

			if el:IsA("GuiObject") then
				local pos, size = el.AbsolutePosition, el.AbsoluteSize
				local x, y = input.Position.X, input.Position.Y
				local inside = x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
				if inside then
					return
				end
			end

			local ok, err = pcall(state.fn :: () -> ...unknown)
			if not ok then
				warn(`[Rivue] click-outside handler failed: {err}`)
			end
		end)
		state = { conn = conn, fn = fn }
		return state
	end,
	updated = function(_el, fn, state: ClickOutsideState?)
		if state and type(fn) == "function" then
			state.fn = fn
		end
		return state
	end,
	unmounted = function(_el, state: ClickOutsideState?)
		if state then
			state.conn:Disconnect()
		end
	end,
})

type DragState = { RBXScriptConnection }

local function startDrag(el: GuiObject): DragState
	local dragging = false
	local dragInput: InputObject?
	local dragStart: Vector3
	local startPos: UDim2

	local function update(input: InputObject)
		local delta = input.Position - dragStart
		el.Position =
			UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end

	return {
		el.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				dragStart = input.Position
				startPos = el.Position
			end
		end),
		UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
			end
		end),
		el.InputChanged:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragInput = input
			end
		end),
		UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				update(input)
			end
		end),
	}
end

local function stopDrag(state: DragState?)
	if state then
		for _, conn in state do
			conn:Disconnect()
		end
	end
end

directives.register("drag", {
	mounted = function(el, enabled): DragState | false
		if not enabled or not el:IsA("GuiObject") then
			return false
		end
		return startDrag(el)
	end,
	updated = function(el, enabled, state: (DragState | false)?): DragState | false
		if enabled and not state and el:IsA("GuiObject") then
			return startDrag(el)
		elseif not enabled and state then
			stopDrag(state)
			return false
		end
		return state or false
	end,
	unmounted = function(_el, state: (DragState | false)?)
		if state then
			stopDrag(state)
		end
	end,
})

directives.register("model-lazy", {
	mounted = function(el, commit)
		local state = { commit = commit, conn = nil :: RBXScriptConnection? }
		if el:IsA("TextBox") then
			local box = el
			state.conn = box.FocusLost:Connect(function()
				state.commit(box.Text)
			end)
		end
		return state
	end,
	updated = function(_el, commit, state)
		if state then
			state.commit = commit
		end
		return state
	end,
	unmounted = function(_el, state)
		if state and state.conn then
			state.conn:Disconnect()
		end
	end,
})

directives.register("show", {
	mounted = function(el, value)
		if el:IsA("GuiObject") then
			el.Visible = not not value
		end
		return nil
	end,
	updated = function(el, value)
		if el:IsA("GuiObject") then
			el.Visible = not not value
		end
		return nil
	end,
})

directives.register("preload", {
	mounted = function(_el, assetIds)
		if not assetIds then
			return
		end

		local ContentProvider = game:GetService("ContentProvider")
		local assets = {}

		if type(assetIds) == "number" or type(assetIds) == "string" then
			table.insert(assets, "rbxassetid://" .. tostring(assetIds))
		elseif type(assetIds) == "table" then
			for _, id in ipairs(assetIds) do
				table.insert(assets, "rbxassetid://" .. tostring(id))
			end
		end

		if #assets > 0 then
			task.spawn(function()
				ContentProvider:PreloadAsync(assets)
			end)
		end

		return nil
	end,
})

directives.register("fade-in", {
	mounted = function(el, opts)
		if not el:IsA("GuiObject") then
			return
		end

		local TweenService = game:GetService("TweenService")
		local duration = type(opts) == "table" and opts.duration or 0.5
		local delay = type(opts) == "table" and opts.delay or 0
		local waitForLoad = type(opts) == "table" and opts.waitForLoad or false
		local renderWait = type(opts) == "table" and opts.renderWait or 0.5

		local transparencyMap: { [Instance]: number } = {}
		local textTransparencyMap: { [Instance]: number } = {}
		local imageTransparencyMap: { [Instance]: number } = {}
		local strokeTransparencyMap: { [Instance]: number } = {}
		local canvasGroupMap: { [Instance]: number } = {}

		local function storeAndHide(obj: Instance)
			if obj:IsA("GuiObject") then
				transparencyMap[obj] = obj.BackgroundTransparency
				obj.BackgroundTransparency = 1

				if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
					local textObj = obj :: TextLabel
					textTransparencyMap[obj] = textObj.TextTransparency
					textObj.TextTransparency = 1
				end

				if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
					local imageObj = obj :: ImageLabel
					imageTransparencyMap[obj] = imageObj.ImageTransparency
					imageObj.ImageTransparency = 1
				end
			end

			if obj:IsA("CanvasGroup") then
				canvasGroupMap[obj] = obj.GroupTransparency
				obj.GroupTransparency = 1
			end

			if obj:IsA("UIStroke") then
				strokeTransparencyMap[obj] = obj.Transparency
				obj.Transparency = 1
			end

			for _, child in ipairs(obj:GetChildren()) do
				storeAndHide(child)
			end
		end

		local function fadeIn(obj: Instance, tweens: { Tween })
			if obj:IsA("GuiObject") then
				local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

				if transparencyMap[obj] then
					local tween = TweenService:Create(obj, tweenInfo, {
						BackgroundTransparency = transparencyMap[obj],
					})
					table.insert(tweens, tween)
					tween.Completed:Connect(function()
						tween:Destroy()
					end)
					tween:Play()
				end

				if textTransparencyMap[obj] then
					local textTween = TweenService:Create(obj, tweenInfo, {
						TextTransparency = textTransparencyMap[obj],
					})
					table.insert(tweens, textTween)
					textTween.Completed:Connect(function()
						textTween:Destroy()
					end)
					textTween:Play()
				end

				if imageTransparencyMap[obj] then
					local imageTween = TweenService:Create(obj, tweenInfo, {
						ImageTransparency = imageTransparencyMap[obj],
					})
					table.insert(tweens, imageTween)
					imageTween.Completed:Connect(function()
						imageTween:Destroy()
					end)
					imageTween:Play()
				end
			end

			if obj:IsA("CanvasGroup") and canvasGroupMap[obj] then
				local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local canvasTween = TweenService:Create(obj, tweenInfo, {
					GroupTransparency = canvasGroupMap[obj],
				})
				table.insert(tweens, canvasTween)
				canvasTween.Completed:Connect(function()
					canvasTween:Destroy()
				end)
				canvasTween:Play()
			end

			if obj:IsA("UIStroke") and strokeTransparencyMap[obj] then
				local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local strokeTween = TweenService:Create(obj, tweenInfo, {
					Transparency = strokeTransparencyMap[obj],
				})
				table.insert(tweens, strokeTween)
				strokeTween.Completed:Connect(function()
					strokeTween:Destroy()
				end)
				strokeTween:Play()
			end

			for _, child in ipairs(obj:GetChildren()) do
				fadeIn(child, tweens)
			end
		end

		local allTweens: { Tween } = {}

		local thread = task.spawn(function()
			if waitForLoad and not game:IsLoaded() then
				game.Loaded:Wait()
			end

			task.wait(renderWait)

			storeAndHide(el)

			if delay > 0 then
				task.wait(delay)
			end

			fadeIn(el, allTweens)
		end)

		return { tweens = allTweens, thread = thread }
	end,
	unmounted = function(_el, state)
		if type(state) ~= "table" then
			return
		end
		if coroutine.status(state.thread) == "suspended" then
			task.cancel(state.thread)
		end
		for _, tween in state.tweens do
			tween:Cancel()
		end
	end,
})

--- With opts.debounce (ms), writes to the ref wait until typing pauses
function directives.vModelText(
	r: Ref<string>,
	opts: { debounce: number? }?
): { Text: string, onTextChanged: (new: string) -> () }
	if not reactivity.isRef(r) then
		error("vModelText expects a ref")
	end

	local debounceMs = opts and opts.debounce or 0

	if debounceMs > 0 then
		local utils = require("./utils")
		local debouncedUpdate = utils.debounce(function(new: string)
			r.value = new
		end, debounceMs)

		return {
			Text = r.value,
			onTextChanged = function(new: string)
				debouncedUpdate(new)
			end,
		}
	else
		return {
			Text = r.value,
			onTextChanged = function(new: string)
				r.value = new
			end,
		}
	end
end

--- eventName defaults to "on" .. PropName (Value -> onValue)
function directives.vModelProp<T>(r: Ref<T>, propName: string, eventName: string?): Types.Props
	if not reactivity.isRef(r) then
		error("vModelProp expects a ref")
	end

	local evtName = eventName or `on{propName:sub(1, 1):upper()}{propName:sub(2)}`

	return {
		[propName] = r.value,
		[evtName] = function(new: T)
			r.value = new
		end,
	}
end

return directives
