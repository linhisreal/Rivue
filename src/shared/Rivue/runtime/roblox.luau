--!strict
--!optimize 2

-- Roblox composables: viewport, input type, safe area, selection, tweens and springs,
-- attribute refs, CollectionService tags and frame callbacks.

local Types = require("./types")
local reactivity = require("./reactivity")
local componentAPI = require("./component")
local debugModule = require("./debug")
local utils = require("./utils")

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

type Ref<T> = Types.Ref<T>

export type InputType = "keyboard" | "gamepad" | "touch"

export type SafeArea = { top: number, left: number, bottom: number, right: number }

export type SpringOptions = {
	-- Angular frequency, higher is snappier (default 12)
	speed: number?,
	-- 1 = no overshoot, below 1 bounces (default 1)
	damping: number?,
}

--- A ref synced with an Instance attribute. Outside a component, call `_cleanup()` to disconnect.
export type AttributeRef<T> = Types.Ref<T> & { _cleanup: (() -> ())? }

--- A ref that reads and writes an Instance attribute, both ways
--- `opts.throttle`: minimum ms between updates for attributes that change often
local function attributeRef<T>(
	instance: Instance,
	attributeName: string,
	defaultValue: T?,
	opts: { throttle: number? }?
): AttributeRef<T?>
	assert(typeof(instance) == "Instance", "attributeRef expects an Instance")
	assert(
		type(attributeName) == "string" and attributeName ~= "",
		"attributeRef expects a non-empty string for attributeName"
	)

	debugModule.log(
		"Roblox",
		"Creating attributeRef",
		{ attributeName = attributeName, defaultValue = tostring(defaultValue) }
	)

	local initialValue = instance:GetAttribute(attributeName)
	if initialValue == nil then
		initialValue = defaultValue
		if defaultValue ~= nil then
			instance:SetAttribute(attributeName, defaultValue)
		end
	end

	local r: AttributeRef<T?> = reactivity.ref(initialValue :: T?) :: any
	local isUpdatingFromAttribute = false
	local isUpdatingFromRef = false

	local updateFromAttribute = function()
		if isUpdatingFromRef then
			return -- Prevent circular update
		end

		local newValue = instance:GetAttribute(attributeName) :: T?
		if r.value ~= newValue then
			isUpdatingFromAttribute = true
			r.value = newValue
			isUpdatingFromAttribute = false
		end
	end

	if opts and opts.throttle and opts.throttle > 0 then
		updateFromAttribute = utils.throttle(updateFromAttribute, opts.throttle)
	end

	local conn = instance:GetAttributeChangedSignal(attributeName):Connect(updateFromAttribute)

	local stopWatch = reactivity.watch(r, function(newValue)
		if isUpdatingFromAttribute then
			return -- Prevent circular update
		end

		local currentAttr = instance:GetAttribute(attributeName)
		-- Skip equal values, setting an attribute fires its changed signal
		if currentAttr ~= newValue then
			isUpdatingFromRef = true
			instance:SetAttribute(attributeName, newValue)
			isUpdatingFromRef = false
		end
	end)

	local function cleanup()
		conn:Disconnect()
		stopWatch()
	end
	-- Manual cleanup always works, and it runs with the component or effect scope
	r._cleanup = cleanup
	reactivity.onScopeDispose(cleanup, true)

	return r
end

--- Registers callbacks for instances with a CollectionService tag
--- `onAdded`: callback when instance is tagged (returns optional cleanup)
local function useTag(tagName: string, onAdded: (instance: Instance) -> (() -> ())?): ()
	if not onAdded then
		return
	end

	debugModule.log(
		"Roblox",
		"Registering tag listener",
		{ tagName = tagName, initialCount = #CollectionService:GetTagged(tagName) }
	)

	local cleanupMap: { [Instance]: () -> () } = {}

	local addedConn = CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
		local cleanup = onAdded(instance)
		if cleanup and type(cleanup) == "function" then
			cleanupMap[instance] = cleanup
		end
	end)

	local removedConn = CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
		local cleanup = cleanupMap[instance]
		if cleanup then
			pcall(cleanup)
			cleanupMap[instance] = nil
		end
	end)

	for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
		local cleanup = onAdded(instance)
		if cleanup and type(cleanup) == "function" then
			cleanupMap[instance] = cleanup
		end
	end

	-- Cleans up with the component or effect scope
	reactivity.onScopeDispose(function()
		addedConn:Disconnect()
		removedConn:Disconnect()
		for _, cleanup in pairs(cleanupMap) do
			pcall(cleanup)
		end
		table.clear(cleanupMap)
	end, true)
end

--- Registers a callback for RunService.RenderStepped
local function onRenderStepped(callback: (deltaTime: number) -> ()): ()
	debugModule.log("Roblox", "Registering RenderStepped callback")
	local currentInstance = componentAPI.getCurrentInstance()
	if not currentInstance then
		error("onRenderStepped must be called during component setup()")
	end

	local conn = RunService.RenderStepped:Connect(callback)

	componentAPI.onUnmounted(function()
		conn:Disconnect()
	end)
end

--- Registers a callback for RunService.Heartbeat
local function onHeartbeat(callback: (deltaTime: number) -> ()): ()
	debugModule.log("Roblox", "Registering Heartbeat callback")
	local currentInstance = componentAPI.getCurrentInstance()
	if not currentInstance then
		error("onHeartbeat must be called during component setup()")
	end

	local conn = RunService.Heartbeat:Connect(callback)

	componentAPI.onUnmounted(function()
		conn:Disconnect()
	end)
end

--- Registers a callback for RunService.Stepped
local function onStepped(callback: (time: number, deltaTime: number) -> ()): ()
	debugModule.log("Roblox", "Registering Stepped callback")
	local currentInstance = componentAPI.getCurrentInstance()
	if not currentInstance then
		error("onStepped must be called during component setup()")
	end

	local conn = RunService.Stepped:Connect(callback)

	componentAPI.onUnmounted(function()
		conn:Disconnect()
	end)
end

-- Shared refs for engine state, created on first use and kept for the session
local viewportSize: Ref<Vector2>? = nil
local inputType: Ref<InputType>? = nil
local safeArea: Ref<SafeArea>? = nil
local selectedObject: Ref<GuiObject?>? = nil

--- Watches the current camera's ViewportSize, rebinding when the camera changes
local function bindViewport(onChange: (size: Vector2) -> ())
	local cameraConn: RBXScriptConnection? = nil
	local function bindCamera()
		if cameraConn then
			cameraConn:Disconnect()
			cameraConn = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			cameraConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				onChange(camera.ViewportSize)
			end)
			onChange(camera.ViewportSize)
		end
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
end

--- Screen size in pixels, updates on resize and rotation. Read only.
local function useViewportSize(): Ref<Vector2>
	local size = viewportSize
	if size then
		return size
	end
	local created = reactivity.ref(Vector2.new(0, 0))
	viewportSize = created
	bindViewport(function(value)
		created.value = value
	end)
	return created
end

--- Maps a UserInputType to the input family it belongs to
--- Returns nil for types that don't say anything (Focus, TextInput, ...)
local function classifyInput(t: Enum.UserInputType): InputType?
	if t == Enum.UserInputType.Touch then
		return "touch"
	elseif t == Enum.UserInputType.Keyboard then
		return "keyboard"
	end
	local name = tostring(t)
	if string.find(name, "Gamepad", 1, true) then
		return "gamepad"
	elseif string.find(name, "Mouse", 1, true) then
		return "keyboard"
	end
	return nil
end

--- What the player is using right now: "keyboard" (and mouse), "gamepad" or "touch". Read only.
local function useInputType(): Ref<InputType>
	local current = inputType
	if current then
		return current
	end

	local initial: InputType
	local fromLastInput = classifyInput(UserInputService:GetLastInputType())
	if fromLastInput then
		initial = fromLastInput :: InputType
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		initial = "touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		initial = "gamepad"
	else
		initial = "keyboard"
	end
	local created = reactivity.ref(initial) :: Ref<InputType>
	inputType = created
	UserInputService.LastInputTypeChanged:Connect(function(t)
		local kind = classifyInput(t)
		if kind then
			created.value = kind :: InputType
		end
	end)
	return created
end

--- Insets (pixels) taken by the top bar and device cutouts. Read only.
local function useSafeArea(): Ref<SafeArea>
	local current = safeArea
	if current then
		return current
	end

	local function read(): SafeArea
		local topLeft, bottomRight = GuiService:GetGuiInset()
		return { top = topLeft.Y, left = topLeft.X, bottom = bottomRight.Y, right = bottomRight.X }
	end
	local created = reactivity.ref(read())
	safeArea = created
	-- Insets change with orientation, which also resizes the viewport
	bindViewport(function()
		local nextArea = read()
		local prev = created.value
		if
			nextArea.top ~= prev.top
			or nextArea.left ~= prev.left
			or nextArea.bottom ~= prev.bottom
			or nextArea.right ~= prev.right
		then
			created.value = nextArea
		end
	end)
	return created
end

--- Gamepad selection: the selected GuiObject and a setter
local function useSelection(): (Ref<GuiObject?>, (target: GuiObject?) -> ())
	local current = selectedObject
	if not current then
		local created = reactivity.shallowRef(GuiService.SelectedObject :: GuiObject?)
		selectedObject = created
		GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
			created.value = GuiService.SelectedObject
		end)
		current = created
	end
	return current :: Ref<GuiObject?>, function(target: GuiObject?)
		GuiService.SelectedObject = target
	end
end

-- Per-frame signal for animations (RenderStepped only exists on the client)
local frameSignal: RBXScriptSignal = if RunService:IsClient() then RunService.RenderStepped else RunService.Heartbeat

--- Reads a ref or getter
local function toGetter<T>(source: Ref<T> | () -> T): () -> T
	if type(source) == "function" then
		return source
	end
	local r = source :: Ref<T>
	return function(): T
		return r.value
	end
end

--- Linear interpolation for numbers and anything with :Lerp (UDim2, Color3, Vector2, CFrame, ...)
local function lerp<T>(a: T, b: T, t: number): T
	if type(a) == "number" then
		return (a + ((b :: any) - a) * t) :: any
	end
	return (a :: any):Lerp(b, t)
end

--- A ref that tweens toward its source whenever the source changes
--- `source`: target value (number, UDim2, Color3, Vector2, CFrame, ...)
--- `info`: time, EasingStyle and EasingDirection are used
local function useTween<T>(source: Ref<T> | () -> T, info: TweenInfo): Ref<T>
	local getter = toGetter(source)
	local out = reactivity.ref(getter())
	local from: T = out.value
	local to: T = out.value
	local elapsed = 0
	local conn: RBXScriptConnection? = nil

	local function stopAnimating()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end

	local function step(dt: number)
		elapsed += dt
		local duration = info.Time
		local alpha = if duration > 0 then math.min(elapsed / duration, 1) else 1
		local eased = TweenService:GetValue(alpha, info.EasingStyle, info.EasingDirection)
		out.value = lerp(from, to, eased)
		if alpha >= 1 then
			stopAnimating()
		end
	end

	local stopWatch = reactivity.watch(getter, function(target: T)
		from = out.value
		to = target
		elapsed = 0
		if not conn then
			conn = frameSignal:Connect(step)
		end
	end)

	reactivity.onScopeDispose(function()
		stopWatch()
		stopAnimating()
	end, true)

	return out
end

--- Distance left for a spring value
local function magnitude(v: unknown): number
	return if type(v) == "number" then math.abs(v) else (v :: Vector3).Magnitude
end

--- A ref that springs toward its source (number, Vector2 or Vector3)
local function useSpring<T>(source: Ref<T> | () -> T, opts: SpringOptions?): Ref<T>
	local options: SpringOptions = opts or {}
	local speed = options.speed or 12
	local damping = options.damping or 1
	local getter = toGetter(source)
	local out = reactivity.ref(getter())
	local position: any = out.value
	local velocity: any = position * 0
	local target: any = position
	local conn: RBXScriptConnection? = nil

	local function step(dt: number)
		-- Fixed substeps keep it stable on long frames
		local steps = math.max(1, math.ceil(dt / (1 / 120)))
		local h = dt / steps
		for _ = 1, steps do
			local accel = (target - position) * (speed * speed) - velocity * (2 * damping * speed)
			velocity += accel * h
			position += velocity * h
		end
		if magnitude(target - position) < 1e-3 and magnitude(velocity) < 1e-3 then
			position = target
			velocity = target * 0
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end
		out.value = position
	end

	local stopWatch = reactivity.watch(getter, function(value: T)
		target = value
		if not conn then
			conn = frameSignal:Connect(step)
		end
	end)

	reactivity.onScopeDispose(function()
		stopWatch()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end, true)

	return out
end

return {
	attributeRef = attributeRef,
	useViewportSize = useViewportSize,
	useInputType = useInputType,
	useSafeArea = useSafeArea,
	useSelection = useSelection,
	useTween = useTween,
	useSpring = useSpring,
	useTag = useTag,
	onRenderStepped = onRenderStepped,
	onHeartbeat = onHeartbeat,
	onStepped = onStepped,
}
