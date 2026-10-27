--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

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
local ContextActionService = game:GetService("ContextActionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

type Ref<T> = Types.Ref<T>

export type InputType = "keyboard" | "gamepad" | "touch"

export type SafeArea = { top: number, left: number, bottom: number, right: number }

export type SpringOptions = {
	speed: number?,
	damping: number?,
}

--- A ref synced with an Instance attribute. Outside a component, call `_cleanup()` to disconnect.
export type AttributeRef<T> = Types.Ref<T> & { _cleanup: (() -> ())? }

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
			return
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
			return
		end

		local currentAttr = instance:GetAttribute(attributeName)
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
	r._cleanup = cleanup
	reactivity.onScopeDispose(cleanup, true)

	return r
end

--- onAdded may return a cleanup, which runs when the tag is removed
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

	reactivity.onScopeDispose(function()
		addedConn:Disconnect()
		removedConn:Disconnect()
		for _, cleanup in pairs(cleanupMap) do
			pcall(cleanup)
		end
		table.clear(cleanupMap)
	end, true)
end

local frameSignal: RBXScriptSignal = if RunService:IsClient() then RunService.RenderStepped else RunService.Heartbeat

local function onRenderStepped(callback: (deltaTime: number) -> ()): ()
	debugModule.log("Roblox", "Registering RenderStepped callback")
	local currentInstance = componentAPI.getCurrentInstance()
	if not currentInstance then
		error("onRenderStepped must be called during component setup()")
	end

	local conn = frameSignal:Connect(callback)

	componentAPI.onUnmounted(function()
		conn:Disconnect()
	end)
end

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

local viewportSize: Ref<Vector2>? = nil
local inputType: Ref<InputType>? = nil
local safeArea: Ref<SafeArea>? = nil
local selectedObject: Ref<GuiObject?>? = nil

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

export type KeybindOptions = {
	enabled: Types.MaybeRefOrGetter<boolean>?,
	priority: number?,
	passThrough: boolean?,
}

local keybindCount = 0

local function useKeybind(
	keys: Enum.KeyCode | Enum.UserInputType | { Enum.KeyCode | Enum.UserInputType },
	callback: (input: InputObject) -> (),
	options: KeybindOptions?
): ()
	local opts: KeybindOptions = options or {}
	keybindCount += 1
	local name = `Rivue_Keybind_{keybindCount}`
	local list = if type(keys) == "table" then keys else { keys }
	local bound = false

	local function handle(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			callback(input)
			if not opts.passThrough then
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end
	local function setBound(on: boolean)
		if on and not bound then
			ContextActionService:BindActionAtPriority(
				name,
				handle,
				false,
				opts.priority or Enum.ContextActionPriority.High.Value,
				table.unpack(list)
			)
		elseif not on and bound then
			ContextActionService:UnbindAction(name)
		end
		bound = on
	end

	local enabled = opts.enabled
	if enabled == nil then
		setBound(true)
	else
		reactivity.watch(function()
			return reactivity.toValue(enabled) == true
		end, setBound, { immediate = true })
	end
	reactivity.onScopeDispose(function()
		setBound(false)
	end, true)
end

local locale: Ref<string>? = nil
local translator: Ref<Translator?>? = nil

local function useLocale(): Ref<string>
	local existing = locale
	if existing then
		return existing
	end
	local player = Players.LocalPlayer
	local created = reactivity.ref(if player then player.LocaleId else LocalizationService.RobloxLocaleId)
	locale = created
	if player then
		player:GetPropertyChangedSignal("LocaleId"):Connect(function()
			created.value = player.LocaleId
		end)
	end
	return created
end

local function loadTranslator(target: Ref<Translator?>)
	local player = Players.LocalPlayer
	if not player then
		return
	end
	task.spawn(function()
		local ok, result = pcall(LocalizationService.GetTranslatorForPlayerAsync, LocalizationService, player)
		if ok then
			target.value = result
		else
			warn(`[Rivue] Couldn't load the translator: {result}`)
		end
	end)
end

--- A function that translates a key from the game's localization table. Text using it updates when
--- the translations load and when the player changes language. Missing keys return the key
local function useTranslator(): (key: string, args: { [string]: any }?) -> string
	local current = translator
	if not current then
		local created: Ref<Translator?> = reactivity.shallowRef(nil :: Translator?)
		translator = created
		current = created
		loadTranslator(created)
		local language = useLocale()
		reactivity.effectScope(true):run(function()
			reactivity.watch(language, function()
				loadTranslator(created)
			end)
			return nil
		end)
	end
	local source = current :: Ref<Translator?>
	return function(key: string, args: { [string]: any }?): string
		local loaded = source.value
		if loaded then
			local ok, text = pcall(loaded.FormatByKey, loaded, key, args)
			if ok then
				return text
			end
		end
		return key
	end
end

export type ScrollOptions = {
	onReachEnd: (() -> ())?,
	threshold: number?,
}

export type Scroll = {
	position: Ref<Vector2>,
	atEnd: Ref<boolean>,
	scrollTo: (position: Vector2 | number, tweenInfo: TweenInfo?) -> (),
	scrollToEnd: (tweenInfo: TweenInfo?) -> (),
}

local function useScroll(frame: Ref<any>, options: ScrollOptions?): Scroll
	local opts: ScrollOptions = options or {}
	local threshold = opts.threshold or 100
	local position = reactivity.ref(Vector2.new(0, 0))
	local atEnd = reactivity.ref(false)
	local conns: { RBXScriptConnection } = {}

	local function disconnect()
		for _, conn in conns do
			conn:Disconnect()
		end
		table.clear(conns)
	end

	local function measure(target: ScrollingFrame)
		position.value = target.CanvasPosition
		local window = target.AbsoluteWindowSize
		local canvas = target.AbsoluteCanvasSize
		local vertical = target.ScrollingDirection ~= Enum.ScrollingDirection.X
		local reached = if vertical
			then target.CanvasPosition.Y + window.Y >= canvas.Y - threshold
			else target.CanvasPosition.X + window.X >= canvas.X - threshold
		if reached and not atEnd.value and opts.onReachEnd then
			atEnd.value = true
			opts.onReachEnd()
		else
			atEnd.value = reached
		end
	end

	reactivity.watch(function()
		return frame.value
	end, function(target)
		disconnect()
		if typeof(target) == "Instance" and (target :: Instance):IsA("ScrollingFrame") then
			local scrolling = target :: ScrollingFrame
			local function update()
				measure(scrolling)
			end
			table.insert(conns, scrolling:GetPropertyChangedSignal("CanvasPosition"):Connect(update))
			table.insert(conns, scrolling:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(update))
			table.insert(conns, scrolling:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(update))
			update()
		end
	end, { immediate = true })
	reactivity.onScopeDispose(disconnect, true)

	local function scrollTo(target: Vector2 | number, tweenInfo: TweenInfo?)
		local scrolling = frame.value :: ScrollingFrame?
		if not scrolling then
			return
		end
		local goal = if type(target) == "number" then Vector2.new(scrolling.CanvasPosition.X, target) else target
		if tweenInfo then
			TweenService:Create(scrolling, tweenInfo, { CanvasPosition = goal }):Play()
		else
			scrolling.CanvasPosition = goal
		end
	end

	return {
		position = position,
		atEnd = atEnd,
		scrollTo = scrollTo,
		scrollToEnd = function(tweenInfo: TweenInfo?)
			local scrolling = frame.value :: ScrollingFrame?
			if scrolling then
				local window, canvas = scrolling.AbsoluteWindowSize, scrolling.AbsoluteCanvasSize
				scrollTo(Vector2.new(math.max(0, canvas.X - window.X), math.max(0, canvas.Y - window.Y)), tweenInfo)
			end
		end,
	}
end

export type Device = "phone" | "tablet" | "desktop" | "console"

const PHONE_SHORT_SIDE = 500

local device: Ref<Device>? = nil

local function deviceFor(size: Vector2): Device
	if GuiService:IsTenFootInterface() then
		return "console"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return if math.min(size.X, size.Y) < PHONE_SHORT_SIDE then "phone" else "tablet"
	end
	return "desktop"
end

--- The kind of device the game runs on. Shared by every caller and never stopped, so it's safe to
--- read in render, which is what responsive style classes do
local function useDevice(): Ref<Device>
	local existing = device
	if existing then
		return existing
	end
	local created: Ref<Device> = reactivity.ref(deviceFor(Vector2.new(0, 0))) :: any
	device = created
	bindViewport(function(size)
		local current: Device = deviceFor(size)
		if created.value ~= current then
			created.value = current
		end
	end)
	return created
end

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

export type GamepadFocusOptions = {
	always: boolean?,
	restore: boolean?,
}

--- Selects `target` (usually a template ref) for gamepad navigation: when the component mounts,
--- and when the player switches to a gamepad with nothing selected. Without this, a gamepad
--- player opening a menu has to press the select button before anything responds
local function useGamepadFocus(target: Ref<any>, options: GamepadFocusOptions?)
	if not RunService:IsClient() then
		return
	end
	local opts: GamepadFocusOptions = options or {}
	local input = useInputType()
	local previous: GuiObject? = nil
	local captured = false

	local function focus(object: unknown)
		if typeof(object) ~= "Instance" or not (object :: Instance):IsA("GuiObject") then
			return
		end
		local current = GuiService.SelectedObject
		if current and current ~= object and current:IsDescendantOf(game) and not opts.always then
			return
		end
		if not captured then
			captured = true
			previous = current
		end
		GuiService.SelectedObject = object :: GuiObject
	end

	reactivity.watch({ target :: any, input :: any }, function(values: { any })
		if opts.always or values[2] == "gamepad" then
			focus(values[1])
		end
	end, { immediate = true, flush = "post" })

	reactivity.onScopeDispose(function()
		if opts.restore == false or not captured then
			return
		end
		local current = GuiService.SelectedObject
		if current == nil or not current:IsDescendantOf(game) then
			GuiService.SelectedObject = if previous and previous:IsDescendantOf(game) then previous else nil
		end
	end, true)
end

local function toGetter<T>(source: Ref<T> | () -> T): () -> T
	if type(source) == "function" then
		return source
	end
	local r = source :: Ref<T>
	return function(): T
		return r.value
	end
end

local function lerp<T>(a: T, b: T, t: number): T
	if type(a) == "number" then
		return (a + ((b :: any) - a) * t) :: any
	end
	return (a :: any):Lerp(b, t)
end

--- Works for numbers and anything with :Lerp. Only info's time, style and direction are used
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

local function toNumbers(v: unknown): { number }
	local t = typeof(v)
	if t == "number" then
		return { v :: number }
	elseif t == "Vector2" then
		local x = v :: Vector2
		return { x.X, x.Y }
	elseif t == "Vector3" then
		local x = v :: Vector3
		return { x.X, x.Y, x.Z }
	elseif t == "UDim" then
		local x = v :: UDim
		return { x.Scale, x.Offset }
	elseif t == "UDim2" then
		local x = v :: UDim2
		return { x.X.Scale, x.X.Offset, x.Y.Scale, x.Y.Offset }
	elseif t == "Color3" then
		local x = v :: Color3
		return { x.R, x.G, x.B }
	end
	error(`[Rivue] useSpring can't animate a {t}: use a number, Vector2, Vector3, UDim, UDim2 or Color3`, 3)
end

local function fromNumbers(kind: string, n: { number }): any
	if kind == "number" then
		return n[1]
	elseif kind == "Vector2" then
		return Vector2.new(n[1], n[2])
	elseif kind == "Vector3" then
		return Vector3.new(n[1], n[2], n[3])
	elseif kind == "UDim" then
		return UDim.new(n[1], n[2])
	elseif kind == "UDim2" then
		return UDim2.new(n[1], n[2], n[3], n[4])
	end
	return Color3.new(math.clamp(n[1], 0, 1), math.clamp(n[2], 0, 1), math.clamp(n[3], 0, 1))
end

local function useSpring<T>(source: Ref<T> | () -> T, opts: SpringOptions?): Ref<T>
	local options: SpringOptions = opts or {}
	local speed = options.speed or 12
	local damping = options.damping or 1
	local getter = toGetter(source)
	local initial = getter()
	local kind = typeof(initial)
	local out = reactivity.ref(initial)
	local position = toNumbers(initial)
	local velocity = table.create(#position, 0)
	local target = table.clone(position)
	local conn: RBXScriptConnection? = nil

	local function step(dt: number)
		local steps = math.max(1, math.ceil(dt / (1 / 120)))
		local h = dt / steps
		for _ = 1, steps do
			for i = 1, #position do
				local accel = (target[i] - position[i]) * (speed * speed) - velocity[i] * (2 * damping * speed)
				velocity[i] += accel * h
				position[i] += velocity[i] * h
			end
		end
		local settled = true
		for i = 1, #position do
			if math.abs(target[i] - position[i]) >= 1e-3 or math.abs(velocity[i]) >= 1e-3 then
				settled = false
				break
			end
		end
		if settled then
			position = table.clone(target)
			for i = 1, #position do
				velocity[i] = 0
			end
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end
		out.value = fromNumbers(kind, position)
	end

	local stopWatch = reactivity.watch(getter, function(value: T)
		target = toNumbers(value)
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
	useDevice = useDevice,
	useKeybind = useKeybind,
	useLocale = useLocale,
	useTranslator = useTranslator,
	useScroll = useScroll,
	useInputType = useInputType,
	useSafeArea = useSafeArea,
	useSelection = useSelection,
	useGamepadFocus = useGamepadFocus,
	useTween = useTween,
	useSpring = useSpring,
	useTag = useTag,
	onRenderStepped = onRenderStepped,
	onHeartbeat = onHeartbeat,
	onStepped = onStepped,
}
