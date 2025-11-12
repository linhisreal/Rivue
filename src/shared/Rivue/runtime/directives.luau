--!strict
--!optimize 2
--!native

--[[
	Directives.luau
    ===============
	
	Directive system for custom element behaviors and v-model helpers.
	
	@module directives

	@author Rivue

	@version 1.0.0
	
	Type Definitions:
    -----------------

		type DirectiveHooks = {
			mounted: ((el: Instance, value: any) -> any)?,
			updated: ((el: Instance, value: any, cleanup: any) -> any)?,
			unmounted: ((el: Instance, cleanup: any) -> ())?
		}
		
		type Ref<T> = { value: T, _is_ref: true }
	
	Public API:
    -----------

		register(name: string, hooks: DirectiveHooks)
			'Registers a custom directive'
			
		get(name: string) -> DirectiveHooks?
			'Gets a registered directives hooks'
			
		vModelText(ref: Ref<string>) -> { Text: string, onTextChanged: function }
			'Two-way binding helper for text inputs'
			
		vModelProp(ref: Ref<any>, propName: string, eventName?: string) -> table
			'Generic two-way binding helper'
	
	Built-in Directives:
    --------------------

		focus - Auto-focuses an element when mounted
		click-outside - Triggers callback when clicking outside element
]]

type DirectiveHooks = {
	mounted: ((el: any, value: any) -> any)?,
	updated: ((el: any, value: any, cleanup: any) -> any)?,
	unmounted: ((el: any, cleanup: any) -> ())?,
}

type Ref<T> = { value: T, _is_ref: boolean }

local UserInputService = game:GetService("UserInputService")
local reactivity = require(script.Parent:WaitForChild("reactivity"))
local debugModule = require(script.Parent:WaitForChild("debug"))

local directives: any = {}
local registry: { [string]: DirectiveHooks } = {}

--- Registers a custom directive with lifecycle hooks
--- @param name string -- Directive name (without 'v-' prefix)
--- @param hooks DirectiveHooks -- Object with mounted/updated/unmounted hooks
--- @return
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

--- Gets a registered directive's hooks by name
--- @param name string -- Directive name
--- @return DirectiveHooks? -- Directive hooks or nil if not found
function directives.get(name: string): DirectiveHooks?
	debugModule.log("Directives", "Getting directive", { name = name, found = registry[name] ~= nil })
	return registry[name]
end

directives.register("focus", {
	mounted = function(el, val)
		if el and val then
			debugModule.log("Directives", "Applying focus directive", { elementName = el.Name })
			pcall(function()
				el:CaptureFocus()
			end)
		end
	end,
	updated = function(el, val)
		if el and val then
			pcall(function()
				el:CaptureFocus()
			end)
		end
	end,
})

directives.register("click-outside", {
	mounted = function(el, fn)
		if type(fn) ~= "function" then
			return
		end

		debugModule.log("Directives", "Setting up click-outside listener", { elementName = el.Name })
		local conn = UserInputService.InputBegan:Connect(function(_input, gameProcessed)
			if gameProcessed then
				return
			end

			local mouse = game:GetService("Players").LocalPlayer:GetMouse()
			local isDesc = false
			local cur = mouse.Target

			while cur do
				if cur == el then
					isDesc = true
					break
				end

				cur = cur.Parent
			end

			if not isDesc then
				pcall(fn)
			end
		end)

		return conn
	end,
	unmounted = function(_el, conn)
		if conn and conn.Disconnect then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end,
})

directives.register("drag", {
	mounted = function(el, enabled)
		if not enabled or not el:IsA("GuiObject") then
			return
		end

		local dragging = false
		local dragInput: InputObject?
		local dragStart: Vector3
		local startPos: UDim2

		local function update(input: InputObject)
			local delta = input.Position - dragStart
			el.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end

		local inputBeganConn = el.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				dragStart = input.Position
				startPos = el.Position

				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)

		local inputChangedConn = el.InputChanged:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragInput = input
			end
		end)

		local inputChangedGlobalConn = UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				update(input)
			end
		end)

		return {
			inputBeganConn = inputBeganConn,
			inputChangedConn = inputChangedConn,
			inputChangedGlobalConn = inputChangedGlobalConn,
		}
	end,
	unmounted = function(_el, cleanup)
		if cleanup then
			if cleanup.inputBeganConn then
				cleanup.inputBeganConn:Disconnect()
			end
			if cleanup.inputChangedConn then
				cleanup.inputChangedConn:Disconnect()
			end
			if cleanup.inputChangedGlobalConn then
				cleanup.inputChangedGlobalConn:Disconnect()
			end
		end
	end,
})

directives.register("show", {
	mounted = function(el, value)
		if not el:IsA("GuiObject") then
			return
		end
		el.Visible = not not value
	end,
	updated = function(el, value)
		if not el:IsA("GuiObject") then
			return
		end
		el.Visible = not not value
	end,
})

directives.register("preload", {
	mounted = function(_el, assetIds)
		if not assetIds then
			return
		end

		local ContentProvider = game:GetService("ContentProvider")
		local assets = {}

		-- Convert single ID or array of IDs to array of asset strings
		if type(assetIds) == "number" or type(assetIds) == "string" then
			table.insert(assets, "rbxassetid://" .. tostring(assetIds))
		elseif type(assetIds) == "table" then
			for _, id in ipairs(assetIds) do
				table.insert(assets, "rbxassetid://" .. tostring(id))
			end
		end

		-- Preload assets asynchronously
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

		-- Maps to store original transparency values for all descendants
		local transparencyMap = {}
		local textTransparencyMap = {}
		local imageTransparencyMap = {}
		local strokeTransparencyMap = {}
		local canvasGroupMap = {}

		-- Recursively store original transparency and set to 1 (invisible)
		local function storeAndHide(obj)
			if obj:IsA("GuiObject") then
				-- Store and hide background transparency
				transparencyMap[obj] = obj.BackgroundTransparency
				obj.BackgroundTransparency = 1

				-- Handle text transparency for text elements
				if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
					textTransparencyMap[obj] = obj.TextTransparency
					obj.TextTransparency = 1
				end

				-- Handle image transparency for image elements
				if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
					imageTransparencyMap[obj] = obj.ImageTransparency
					obj.ImageTransparency = 1
				end
			end

			-- Handle CanvasGroup for performance optimization
			if obj:IsA("CanvasGroup") then
				canvasGroupMap[obj] = obj.GroupTransparency
				obj.GroupTransparency = 1
			end

			-- Handle UIStroke transparency
			if obj:IsA("UIStroke") then
				strokeTransparencyMap[obj] = obj.Transparency
				obj.Transparency = 1
			end

			-- Recursively process all children
			for _, child in ipairs(obj:GetChildren()) do
				storeAndHide(child)
			end
		end

		-- Recursively create and play fade-in tweens for all elements
		local function fadeIn(obj, tweens)
			if obj:IsA("GuiObject") then
				local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

				-- Tween background transparency
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

				-- Tween text transparency
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

				-- Tween image transparency
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

			-- Tween CanvasGroup for better performance
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

			-- Tween UIStroke transparency
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

			-- Recursively process all children
			for _, child in ipairs(obj:GetChildren()) do
				fadeIn(child, tweens)
			end
		end

		-- Create array to store all tweens for cleanup
		local allTweens = {}

		-- Start fade-in animation
		task.spawn(function()
			-- Wait for game to load if requested
			if waitForLoad and not game:IsLoaded() then
				game.Loaded:Wait()
			end

			-- Wait for initial render to complete (children to be added)
			-- Configurable wait time to ensure reactive components are fully mounted
			task.wait(renderWait)

			-- Store original values and hide all elements recursively
			storeAndHide(el)

			-- Apply delay
			if delay > 0 then
				task.wait(delay)
			end

			-- Recursively fade in all elements
			fadeIn(el, allTweens)
		end)

		return allTweens
	end,
	unmounted = function(_el, cleanup)
		-- Clean up all tweens
		if cleanup and type(cleanup) == "table" then
			for _, tween in ipairs(cleanup) do
				if tween then
					tween:Cancel()
				end
			end
		end
	end,
})

--- v-once directive: Renders element and children only once
--- Useful for static content that never changes
directives.register("once", {
	mounted = function(el, _val)
		debugModule.log("Directives", "v-once applied", { elementName = el.Name })
		-- Mark element as static (for renderer optimization)
		-- The actual "only render once" logic is handled by renderer
		-- This directive mainly serves as a marker
		return { isStatic = true }
	end,
})

--- v-memo directive: Memoizes rendering based on dependency array
--- Only re-renders when dependencies change (shallow comparison)
--- @param deps any[] -- Array of dependencies to watch
directives.register("memo", {
	mounted = function(el, deps)
		if type(deps) ~= "table" then
			debugModule.log("Directives", "v-memo expects an array of dependencies (warning)")
			return
		end

		debugModule.log("Directives", "v-memo applied", {
			elementName = el.Name,
			depCount = #deps,
		})

		-- Store the dependency snapshot
		local snapshot = table.clone(deps)

		return { deps = snapshot }
	end,
	updated = function(el, deps, cleanup)
		if type(deps) ~= "table" or not cleanup or type(cleanup.deps) ~= "table" then
			return cleanup
		end

		-- Shallow compare dependencies
		local hasChanged = false
		if #deps ~= #cleanup.deps then
			hasChanged = true
		else
			for i, dep in ipairs(deps) do
				if dep ~= cleanup.deps[i] then
					hasChanged = true
					break
				end
			end
		end

		if hasChanged then
			debugModule.log("Directives", "v-memo dependencies changed", {
				elementName = el.Name,
			})

			-- Update snapshot
			local newSnapshot = table.clone(deps)

			return { deps = newSnapshot }
		else
			debugModule.log("Directives", "v-memo skipped update (no changes)", {
				elementName = el.Name,
			})
		end

		return cleanup
	end,
})

--- Two-way binding helper for TextBox.Text property with optional debounce
--- @param r Ref<string> -- Reactive ref to bind
--- @param opts { debounce: number? }? -- Optional config with debounce delay in ms
--- @return { Text: string, onTextChanged: (new: string) -> () } -- Props object for text binding
function directives.vModelText(
	r: Ref<string>,
	opts: { debounce: number? }?
): { Text: string, onTextChanged: (new: string) -> () }
	if not reactivity.isRef(r) then
		error("vModelText expects a ref")
	end

	local debounceMs = opts and opts.debounce or 0

	if debounceMs > 0 then
		-- Load utils for debounce
		local utils = require(script.Parent:WaitForChild("utils"))
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

--- Generic two-way binding helper for any property
--- @param r Ref<any> -- Reactive ref to bind
--- @param propName string -- Property name to bind
--- @param eventName string? -- Optional event name (defaults to 'on' + capitalized propName)
--- @return { [string]: any } -- Props object with property and event handler
function directives.vModelProp(r: Ref<any>, propName: string, eventName: string?): { [string]: any }
	if not reactivity.isRef(r) then
		error("vModelProp expects a ref")
	end

	local evtName = eventName or ("on" .. propName:sub(1, 1):upper() .. propName:sub(2))

	local t: { [string]: any } = {}
	t[propName] = r.value
	t[evtName] = function(new: any)
		r.value = new
	end

	return t
end

return directives
