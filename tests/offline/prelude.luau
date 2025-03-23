--!nocheck
--[[
	Offline test prelude
	====================

	Minimal Roblox stand-ins (game, task, signals, Instances) so the test suites can run in
	Lune. Time is virtual: each step advances 1/60s and fires RenderStepped/Stepped/Heartbeat.
	Only what the runtime and tests use is implemented.

	Run with `lune run test`
]]

local now = 0
local deferred = {}
-- Roblox errors when deferred threads keep deferring more than 80 levels deep
local deferDepth = 0
local timers = {}
local function makeSignal()
	local sig = { _conns = {} }
	function sig:Connect(fn)
		local c = { Connected = true, fn = fn }
		function c:Disconnect()
			self.Connected = false
		end
		table.insert(sig._conns, c)
		return c
	end
	function sig:Once(fn)
		local c
		c = sig:Connect(function(...)
			c:Disconnect()
			fn(...)
		end)
		return c
	end
	function sig:Fire(...)
		local list = table.clone(sig._conns)
		for _, c in list do
			if c.Connected then
				c.fn(...)
			end
		end
		local keep = {}
		for _, c in sig._conns do
			if c.Connected then
				table.insert(keep, c)
			end
		end
		sig._conns = keep
	end
	return sig
end
local heartbeat = makeSignal()
local renderStepped = makeSignal()
local function resumeThread(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		print("THREAD ERROR:", err)
	end
end
local function spawnFn(f, ...)
	if type(f) == "thread" then
		return resumeThread(f, ...)
	end
	local co = coroutine.create(f)
	resumeThread(co, ...)
	return co
end
task = {
	defer = function(f, ...)
		if deferDepth >= 80 then
			error("Maximum re-entrancy depth (80) exceeded calling task.defer", 2)
		end
		local co = type(f) == "thread" and f or coroutine.create(f)
		table.insert(deferred, { co, table.pack(...), depth = deferDepth + 1 })
		return co
	end,
	spawn = spawnFn,
	delay = function(t, f, ...)
		local co = coroutine.create(f)
		table.insert(timers, { at = now + (t or 0), co = co, args = table.pack(...) })
		return co
	end,
	wait = function(t)
		local co = coroutine.running()
		table.insert(timers, { at = now + (t or 0), co = co, args = table.pack() })
		coroutine.yield()
		return t
	end,
	cancel = function(co)
		for i = #timers, 1, -1 do
			if timers[i].co == co then
				table.remove(timers, i)
			end
		end
		for i = #deferred, 1, -1 do
			if deferred[i][1] == co then
				table.remove(deferred, i)
			end
		end
	end,
	desynchronize = function() end,
	synchronize = function() end,
}
local function flushDeferred()
	local guard = 0
	while #deferred > 0 do
		guard += 1
		if guard > 100000 then
			error("deferred loop")
		end
		local d = table.remove(deferred, 1)
		if coroutine.status(d[1]) == "suspended" then
			deferDepth = d.depth
			resumeThread(d[1], table.unpack(d[2], 1, d[2].n))
			deferDepth = 0
		end
	end
end
local services
local function step(dt)
	flushDeferred()
	now += dt
	local due = {}
	for i = #timers, 1, -1 do
		if timers[i].at <= now then
			table.insert(due, 1, table.remove(timers, i))
		end
	end
	for _, t in due do
		if coroutine.status(t.co) == "suspended" then
			resumeThread(t.co, table.unpack(t.args, 1, t.args.n))
		end
	end
	flushDeferred()
	renderStepped:Fire(dt)
	if services and services.RunService.Stepped then
		services.RunService.Stepped:Fire(now, dt)
	end
	heartbeat:Fire(dt)
	flushDeferred()
end
tick = function()
	return now
end
-- Tests that fire engine input signals check this: Studio scripts can't fire them
__OFFLINE = true
local realOs = os
-- Real wall clock for benchmarks (os.clock is virtual here)
__realClock = realOs.clock
os = setmetatable({
	clock = function()
		return now
	end,
}, { __index = realOs })
Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
local sequenceMt = {}
ColorSequence = {
	new = function(a, b)
		return setmetatable({ __rbxtype = "ColorSequence", from = a, to = b or a }, sequenceMt)
	end,
}
NumberSequence = {
	new = function(a, b)
		return setmetatable({ __rbxtype = "NumberSequence", from = a, to = b or a }, sequenceMt)
	end,
}
warn = function(...)
	print("WARN", ...)
	-- Like Roblox, warnings also reach LogService.MessageOut
	local logService = services and services.LogService
	if logService then
		local parts = {}
		for i = 1, select("#", ...) do
			table.insert(parts, tostring((select(i, ...))))
		end
		logService.MessageOut:Fire(table.concat(parts, " "), Enum.MessageType.MessageWarning)
	end
end
typeof = function(v)
	if type(v) == "table" and rawget(v, "__rbxtype") then
		return v.__rbxtype
	end
	return type(v)
end
services = {
	RunService = {
		IsStudio = function()
			return false
		end,
		IsClient = function()
			return true
		end,
		IsServer = function()
			return false
		end,
		Heartbeat = heartbeat,
		RenderStepped = renderStepped,
		Stepped = makeSignal(),
		PreRender = renderStepped,
		PostSimulation = heartbeat,
	},
	HttpService = {
		GenerateGUID = function()
			return tostring(math.random(1, 1e9))
		end,
		JSONEncode = function(_, v)
			local function enc(x)
				local t = type(x)
				if t == "table" then
					local parts = {}
					for k, val in x do
						table.insert(parts, enc(k) .. ":" .. enc(val))
					end
					return "{" .. table.concat(parts, ",") .. "}"
				elseif t == "string" then
					return '"' .. x .. '"'
				elseif t == "number" or t == "boolean" or t == "nil" then
					return tostring(x)
				elseif t == "userdata" then
					return "null" -- Roblox encodes Instances as null
				end
				error("Cannot encode " .. t)
			end
			return enc(v)
		end,
	},
	TextService = {
		FilterStringAsync = function(_, str)
			return {
				GetNonChatStringForBroadcastAsync = function()
					return str
				end,
			}
		end,
	},
	UserInputService = {
		GetFocusedTextBox = function()
			return nil
		end,
		GetLastInputType = function()
			return Enum.UserInputType.MouseMovement
		end,
		LastInputTypeChanged = makeSignal(),
		InputBegan = makeSignal(),
		InputEnded = makeSignal(),
		InputChanged = makeSignal(),
		TouchEnabled = false,
		KeyboardEnabled = true,
		GamepadEnabled = false,
	},
	Players = { LocalPlayer = nil },
}
local ReplicatedStorage = setmetatable({ _children = {} }, {
	__index = function(t, k)
		return rawget(t, "_children")[k]
	end,
})
local function makeFolder(name, parent)
	local f = setmetatable({ Name = name, Parent = parent, _children = {} }, {
		__index = function(t, k)
			return rawget(t, "_children")[k]
		end,
	})
	function f:FindFirstChild(n)
		return self._children[n]
	end
	function f:WaitForChild(n)
		return assert(self._children[n], "missing child " .. n)
	end
	return f
end
function ReplicatedStorage:FindFirstChild(n)
	return self._children[n]
end
function ReplicatedStorage:GetFullName()
	return "ReplicatedStorage"
end
function ReplicatedStorage:WaitForChild(n, timeout)
	if timeout then
		return self._children[n]
	end
	return assert(self._children[n], "missing " .. n)
end
services.ReplicatedStorage = ReplicatedStorage
game = setmetatable({
	GetService = function(_, n)
		return services[n] or {}
	end,
}, {
	-- game.ReplicatedStorage, game.Players, ...
	__index = function(_, k)
		return services[k]
	end,
})
local rivueScript = makeFolder("Rivue", ReplicatedStorage)
ReplicatedStorage._children.Rivue = rivueScript
local runtimeFolder = makeFolder("runtime", rivueScript)
rivueScript._children.runtime = runtimeFolder
local cache = {}
local realRequire = require
require = function(obj)
	if type(obj) ~= "table" or not obj.__load then
		return realRequire(obj)
	end
	if cache[obj] == nil then
		cache[obj] = obj.__load(obj)
	end
	return cache[obj]
end
-- String requires, resolved like Roblox does: "./x" from the module's parent, "../x" one level
-- up, "@self/x" from the module itself
function __requireFrom(script)
	return function(target)
		if type(target) ~= "string" then
			return require(target)
		end
		local node, rest
		if string.sub(target, 1, 6) == "@self/" then
			node, rest = script, string.sub(target, 7)
		elseif string.sub(target, 1, 2) == "./" or string.sub(target, 1, 3) == "../" then
			node, rest = script.Parent, target
		else
			error("unsupported require path " .. target, 2)
		end
		for _, part in string.split(rest, "/") do
			if part == ".." then
				node = node.Parent
			elseif part ~= "." and part ~= "" then
				node = node._children[part] or error(`require("{target}"): no module '{part}'`, 2)
			end
		end
		return require(node)
	end
end
function __defineModule(parent, name, fn)
	local obj = parent and makeFolder(name, parent) or rivueScript
	obj.__load = fn
	if parent then
		parent._children[name] = obj
	end
end
local failures, passes = 0, 0
function __runTest(name, fn)
	print("=== " .. name)
	local co = coroutine.create(function()
		local ok, err = pcall(function()
			local r = fn({})
			if type(r) == "function" then
				r()
			elseif type(r) == "table" and type(r.runAllTests) == "function" then
				r.runAllTests()
			else
				error("test module returned nothing runnable")
			end
		end)
		if not ok then
			failures += 1
			print("FAIL " .. name .. ": " .. tostring(err))
		else
			passes += 1
		end
	end)
	resumeThread(co)
	local frames = 0
	while coroutine.status(co) ~= "dead" and frames < 100000 do
		step(1 / 60)
		frames += 1
	end
	if coroutine.status(co) ~= "dead" then
		failures += 1
		print("TIMEOUT " .. name)
	end
end
function __finish()
	print(string.format("RESULT: %d passed, %d failed", passes, failures))
	if failures > 0 then
		error("offline tests failed", 0)
	end
end

-- Minimal Instance stub
UDIM2_MT = {
	__eq = function(a, b)
		return a.X.Scale == b.X.Scale
			and a.X.Offset == b.X.Offset
			and a.Y.Scale == b.Y.Scale
			and a.Y.Offset == b.Y.Offset
	end,
	__rbxtype = "UDim2",
}
UDim2 = {
	new = function(a, b, c, d)
		-- UDim2.new(xUDim, yUDim)
		if type(a) == "table" and type(b) == "table" then
			a, b, c, d = a.Scale, a.Offset, b.Scale, b.Offset
		end
		return setmetatable(
			{ X = { Scale = a or 0, Offset = b or 0 }, Y = { Scale = c or 0, Offset = d or 0 } },
			UDIM2_MT
		)
	end,
	fromOffset = function(x, y)
		return UDim2.new(0, x, 0, y)
	end,
	fromScale = function(x, y)
		return UDim2.new(x, 0, y, 0)
	end,
}
VECTOR2_MT = {
	__rbxtype = "Vector2",
	__eq = function(a, b)
		return a.X == b.X and a.Y == b.Y
	end,
}
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, VECTOR2_MT)
	end,
}
VECTOR3_MT = {
	__rbxtype = "Vector3",
	__index = function(v, k)
		if k == "Magnitude" then
			return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		end
		return nil
	end,
	__add = function(a, b)
		return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end,
	__mul = function(a, b)
		if type(a) == "number" then
			a, b = b, a
		end
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end,
	__sub = function(a, b)
		return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end,
	__eq = function(a, b)
		return a.X == b.X and a.Y == b.Y and a.Z == b.Z
	end,
}
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, VECTOR3_MT)
	end,
}
UDIM_MT = {
	__rbxtype = "UDim",
	__eq = function(a, b)
		return a.Scale == b.Scale and a.Offset == b.Offset
	end,
}
UDim = {
	new = function(scale, offset)
		return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDIM_MT)
	end,
}
TweenInfo = {
	new = function(time, style, direction)
		return { Time = time or 1, EasingStyle = style or "Quad", EasingDirection = direction or "Out" }
	end,
}
Enum = setmetatable({}, {
	__index = function(_, k)
		return setmetatable({}, {
			__index = function(_, k2)
				return k .. "." .. k2
			end,
		})
	end,
})
local GUI_PROPS = {
	Size = UDim2.new(),
	Position = UDim2.new(),
	AnchorPoint = Vector2.new(),
	BackgroundTransparency = 0,
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = true,
	LayoutOrder = 0,
	ZIndex = 1,
	BorderSizePixel = 1,
	NextSelectionUp = nil,
	AutomaticSize = "None",
	ClipsDescendants = false,
	Active = false,
	AbsoluteSize = Vector2.new(100, 100),
	AbsolutePosition = Vector2.new(0, 0),
	Selectable = false,
	Interactable = true,
}
local TEXT_PROPS = {
	Text = "",
	TextColor3 = Color3.new(0, 0, 0),
	TextTransparency = 0,
	TextSize = 14,
	Font = "Legacy",
	TextScaled = false,
	TextWrapped = false,
	TextXAlignment = "Center",
}
local IMAGE_PROPS = { Image = "", ImageTransparency = 0, ImageColor3 = Color3.new(1, 1, 1) }
local CLASSES = {
	Folder = { bases = {}, props = {} },
	Frame = { bases = { "GuiObject", "GuiBase2d" }, props = { GUI_PROPS } },
	ScrollingFrame = {
		bases = { "GuiObject", "GuiBase2d" },
		props = {
			GUI_PROPS,
			{
				CanvasSize = UDim2.new(),
				CanvasPosition = Vector2.new(),
				ScrollingDirection = "XY",
				AbsoluteCanvasSize = Vector2.new(100, 100),
				AbsoluteWindowSize = Vector2.new(100, 100),
			},
		},
	},
	TextLabel = { bases = { "GuiObject", "GuiBase2d" }, props = { GUI_PROPS, TEXT_PROPS } },
	TextButton = {
		bases = { "GuiObject", "GuiButton", "GuiBase2d" },
		props = { GUI_PROPS, TEXT_PROPS },
		events = { "MouseButton1Click", "Activated" },
	},
	TextBox = {
		bases = { "GuiObject", "GuiBase2d" },
		props = {
			GUI_PROPS,
			TEXT_PROPS,
			{
				PlaceholderText = "",
				PlaceholderColor3 = Color3.new(0.7, 0.7, 0.7),
				ClearTextOnFocus = true,
				CursorPosition = -1,
			},
		},
		events = { "FocusLost", "Focused" },
	},
	ImageLabel = { bases = { "GuiObject", "GuiBase2d" }, props = { GUI_PROPS, IMAGE_PROPS } },
	ImageButton = {
		bases = { "GuiObject", "GuiButton", "GuiBase2d" },
		props = { GUI_PROPS, IMAGE_PROPS },
		events = { "MouseButton1Click", "Activated" },
	},
	ScreenGui = {
		bases = { "LayerCollector", "GuiBase2d" },
		props = { { ResetOnSpawn = true, Enabled = true, IgnoreGuiInset = false, DisplayOrder = 0 } },
	},
	SurfaceGui = { bases = { "LayerCollector", "GuiBase2d" }, props = { { Enabled = true } } },
	UIListLayout = {
		bases = { "UIGridStyleLayout", "UILayout" },
		props = {
			{
				Padding = 0,
				SortOrder = "LayoutOrder",
				FillDirection = "Vertical",
				HorizontalAlignment = "Left",
				VerticalAlignment = "Top",
				Wraps = false,
				HorizontalFlex = "None",
				VerticalFlex = "None",
			},
		},
	},
	UIGridLayout = {
		bases = { "UIGridStyleLayout", "UILayout" },
		props = {
			{
				CellSize = UDim2.new(),
				CellPadding = UDim2.new(),
				SortOrder = "LayoutOrder",
				FillDirection = "Horizontal",
				HorizontalAlignment = "Left",
				VerticalAlignment = "Top",
			},
		},
	},
	UIFlexItem = { bases = {}, props = { { FlexMode = "None", GrowRatio = 1, ShrinkRatio = 1 } } },
	RemoteEvent = { bases = {}, props = {}, events = { "OnClientEvent", "OnServerEvent" }, methods = true },
	RemoteFunction = { bases = {}, props = {}, methods = true },
	BindableEvent = { bases = {}, props = {}, events = { "Event" } },
	Part = {
		bases = { "BasePart", "PVInstance" },
		props = {
			{
				Anchored = false,
				Transparency = 0,
				Size = Vector2.new(4, 1),
				Color = Color3.new(0.6, 0.6, 0.6),
				CanCollide = true,
			},
		},
		events = { "Touched" },
	},
	Model = { bases = { "PVInstance" }, props = {} },
	Player = {
		bases = {},
		props = { { UserId = 1, DisplayName = "Player", LocaleId = "en-us" } },
		events = { "CharacterAdded" },
	},
	ViewportFrame = { bases = { "GuiObject", "GuiBase2d" }, props = { GUI_PROPS, { CurrentCamera = false } } },
	CanvasGroup = { bases = { "GuiObject", "GuiBase2d" }, props = { GUI_PROPS, { GroupTransparency = 0 } } },
	UICorner = { bases = {}, props = { { CornerRadius = 0 } } },
	UIStroke = { bases = {}, props = { { Thickness = 1, Transparency = 0, Color = Color3.new(0, 0, 0) } } },
	UIPadding = { bases = {}, props = { { PaddingTop = 0, PaddingLeft = 0, PaddingBottom = 0, PaddingRight = 0 } } },
	UIAspectRatioConstraint = { bases = {}, props = { { AspectRatio = 1 } } },
	UIGradient = { bases = {}, props = { { Color = false, Rotation = 0, Offset = false, Transparency = false } } },
	UIScale = { bases = {}, props = { { Scale = 1 } } },
	UISizeConstraint = { bases = {}, props = { { MinSize = false, MaxSize = false } } },
	UITextSizeConstraint = { bases = {}, props = { { MinTextSize = 1, MaxTextSize = 100 } } },
	Camera = { bases = {}, props = { { ViewportSize = Vector2.new(1280, 720) } } },
	Workspace = { bases = {}, props = { { CurrentCamera = false } } },
}
local COMMON_EVENTS = {
	"Changed",
	"ChildAdded",
	"ChildRemoved",
	"Destroying",
	"AncestryChanged",
	"InputBegan",
	"InputChanged",
	"InputEnded",
	"MouseEnter",
	"MouseLeave",
	"SelectionGained",
	"SelectionLost",
	"AttributeChanged",
}
local instanceCount = 0
Instance = {}
function Instance.new(className, parent)
	local def = CLASSES[className]
	if not def then
		error('Unable to create an Instance of type "' .. tostring(className) .. '"')
	end
	instanceCount += 1
	local props = { Name = className, ClassName = className }
	local known = { Name = true, ClassName = true, Parent = true }
	for _, group in def.props do
		for k, v in group do
			props[k] = v
			known[k] = true
		end
	end
	known.NextSelectionUp = def.props[1] == GUI_PROPS or nil
	local children, attrs, signals, propSignals = {}, {}, {}, {}
	local destroyed = false
	local parent_ = nil
	local events = {}
	for _, e in COMMON_EVENTS do
		events[e] = true
	end
	for _, e in def.events or {} do
		events[e] = true
	end
	-- Userdata like real Instances, so type(inst) == "userdata"
	local self = newproxy(true)
	local selfMt = getmetatable(self)
	local methods = {}
	function methods:GetChildren()
		return table.clone(children)
	end
	function methods:GetDescendants()
		local out = {}
		for _, c in children do
			table.insert(out, c)
			for _, d in c:GetDescendants() do
				table.insert(out, d)
			end
		end
		return out
	end
	function methods:FindFirstChild(n)
		for _, c in children do
			if c.Name == n then
				return c
			end
		end
		return nil
	end
	function methods:WaitForChild(n)
		return self:FindFirstChild(n)
	end
	function methods:FindFirstChildWhichIsA(cn)
		for _, c in children do
			if c:IsA(cn) then
				return c
			end
		end
		return nil
	end
	function methods:FindFirstChildOfClass(cn)
		for _, c in children do
			if c.ClassName == cn then
				return c
			end
		end
		return nil
	end
	function methods:GetFullName()
		return (parent_ and parent_.GetFullName and parent_:GetFullName() .. "." or "") .. props.Name
	end
	function methods:IsA(cn)
		if cn == className or cn == "Instance" then
			return true
		end
		for _, b in def.bases do
			if b == cn then
				return true
			end
		end
		return false
	end
	function methods:SetAttribute(k, v)
		local old = attrs[k]
		attrs[k] = v
		if old ~= v and propSignals["@" .. k] then
			propSignals["@" .. k]:Fire()
		end
		if old ~= v and signals.AttributeChanged then
			signals.AttributeChanged:Fire(k)
		end
	end
	function methods:GetAttribute(k)
		return attrs[k]
	end
	function methods:GetAttributes()
		return table.clone(attrs)
	end
	function methods:GetPropertyChangedSignal(p)
		if not known[p] then
			error(p .. " is not a valid property name.")
		end
		propSignals[p] = propSignals[p] or makeSignal()
		local s = propSignals[p]
		s.__rbxtype = "RBXScriptSignal"
		return s
	end
	function methods:GetAttributeChangedSignal(a)
		propSignals["@" .. a] = propSignals["@" .. a] or makeSignal()
		return propSignals["@" .. a]
	end
	function methods:FireServer(...)
		if signals.OnServerEvent then
			signals.OnServerEvent:Fire(services.Players.LocalPlayer, ...)
		end
	end
	function methods:FireClient(_, ...)
		if signals.OnClientEvent then
			signals.OnClientEvent:Fire(...)
		end
	end
	function methods:FireAllClients(...)
		if signals.OnClientEvent then
			signals.OnClientEvent:Fire(...)
		end
	end
	function methods:Fire(...)
		if signals.Event then
			signals.Event:Fire(...)
		end
	end
	function methods:IsDescendantOf(a)
		local p = parent_
		while p do
			if p == a then
				return true
			end
			p = p.Parent
		end
		return false
	end
	function methods:ClearAllChildren()
		for _, c in table.clone(children) do
			c:Destroy()
		end
	end
	function methods:Destroy()
		if destroyed then
			return
		end
		if signals.Destroying then
			signals.Destroying:Fire()
		end
		self.Parent = nil
		for _, c in table.clone(children) do
			c:Destroy()
		end
		destroyed = true
	end
	function methods:CaptureFocus()
		__focusCalls = (__focusCalls or 0) + 1
	end
	function methods:ReleaseFocus() end
	function methods:Clone()
		return Instance.new(className)
	end
	methods.__children = children
	for key, value in
		{
			__rbxtype = "Instance",
			__index = function(_, k)
				__instanceOps = (__instanceOps or 0) + 1
				if __opKeys then
					__opKeys["get " .. tostring(k)] = (__opKeys["get " .. tostring(k)] or 0) + 1
				end
				if k == "Parent" then
					return parent_
				end
				if methods[k] then
					return methods[k]
				end
				if known[k] then
					return props[k]
				end
				if events[k] then
					signals[k] = signals[k] or makeSignal()
					signals[k].__rbxtype = "RBXScriptSignal"
					return signals[k]
				end
				for _, c in children do
					if c.Name == k then
						return c
					end
				end
				error(tostring(k) .. " is not a valid member of " .. className, 2)
			end,
			__newindex = function(_, k, v)
				__instanceOps = (__instanceOps or 0) + 1
				if __opKeys then
					__opKeys["set " .. tostring(k)] = (__opKeys["set " .. tostring(k)] or 0) + 1
				end
				if k == "Parent" then
					if destroyed then
						error("The Parent property of " .. props.Name .. " is locked")
					end
					if parent_ then
						local list = if type(parent_) == "table"
							then rawget(parent_, "_children") and nil or nil
							else parent_.__children
						if list then
							local i = table.find(list, self)
							if i then
								table.remove(list, i)
							end
						end
					end
					parent_ = v
					if type(v) == "table" and rawget(v, "_children") then
						v._children[props.Name] = self
					elseif v and v.__children then
						table.insert(v.__children, self)
					end
					return
				end
				if k == "ClassName" or not known[k] then
					error(tostring(k) .. " is not a valid member of " .. className, 2)
				end
				if v == nil and k ~= "NextSelectionUp" then
					error("invalid nil for " .. k, 2)
				end
				local old = props[k]
				props[k] = v
				if old ~= v and propSignals[k] then
					propSignals[k]:Fire()
				end
			end,
			__tostring = function()
				return props.Name
			end,
		}
	do
		selfMt[key] = value
	end
	if parent then
		self.Parent = parent
	end
	return self
end
typeof = function(v)
	if type(v) == "table" or type(v) == "userdata" then
		local mt = getmetatable(v)
		if type(mt) == "table" and rawget(mt, "__rbxtype") then
			return mt.__rbxtype
		end
		if type(v) == "table" and rawget(v, "__rbxtype") then
			return v.__rbxtype
		end
	end
	return type(v)
end
-- Folder-like stubs created by makeFolder() must also accept Instance children

-- Players / CollectionService / workspace stubs
do
	local player = Instance.new("Player")
	player.Name = "LocalPlayer"
	local pg = Instance.new("Folder")
	pg.Name = "PlayerGui"
	pg.Parent = player
	services.Players = { LocalPlayer = player, PlayerRemoving = makeSignal(), PlayerAdded = makeSignal() }
	services.LogService = { MessageOut = makeSignal() }
	local selection = {}
	services.Selection = {
		Set = function(_, list)
			selection = list
		end,
		Get = function()
			return selection
		end,
	}
	-- Keybinds: tests press keys with __pressKey(Enum.KeyCode.X)
	local actions = {}
	services.ContextActionService = {
		BindActionAtPriority = function(_, name, fn, _button, _priority, ...)
			actions[name] = { fn = fn, keys = { ... } }
		end,
		UnbindAction = function(_, name)
			actions[name] = nil
		end,
	}
	function __pressKey(key)
		for name, action in actions do
			if table.find(action.keys, key) then
				action.fn(name, Enum.UserInputState.Begin, { KeyCode = key })
			end
		end
	end
	-- Translations: tests set __translations[locale][key]
	__translations = {}
	services.LocalizationService = {
		RobloxLocaleId = "en-us",
		GetTranslatorForPlayerAsync = function(_, who)
			local localeId = who.LocaleId
			return {
				LocaleId = localeId,
				FormatByKey = function(_, key, args)
					local text = (__translations[localeId] or {})[key]
					if not text then
						error("missing key " .. key)
					end
					return (
						string.gsub(text, "{(%w+)}", function(name)
							return tostring(args and args[name])
						end)
					)
				end,
			}
		end,
	}
	workspace = Instance.new("Workspace")
	services.Workspace = workspace
	local camera = Instance.new("Camera")
	camera.Parent = workspace
	workspace.CurrentCamera = camera

	-- GuiService: SelectedObject with a change signal, fixed top bar inset
	local guiSignals = {}
	local selected = nil
	services.GuiService = setmetatable({
		IsTenFootInterface = function()
			return false
		end,
		GetGuiInset = function()
			return Vector2.new(0, 58), Vector2.new(0, 0)
		end,
		GetPropertyChangedSignal = function(_, prop)
			guiSignals[prop] = guiSignals[prop] or makeSignal()
			return guiSignals[prop]
		end,
	}, {
		__index = function(_, k)
			if k == "SelectedObject" then
				return selected
			end
			return nil
		end,
		__newindex = function(_, k, v)
			if k == "SelectedObject" then
				if selected ~= v then
					selected = v
					if guiSignals.SelectedObject then
						guiSignals.SelectedObject:Fire()
					end
				end
				return
			end
			rawset(services.GuiService, k, v)
		end,
	})

	-- TweenService on virtual time: tweens finish after info.Time worth of frames
	services.TweenService = {
		GetValue = function(_, alpha)
			return alpha
		end,
		Create = function(_, inst, info, goals)
			local tween = { Completed = makeSignal(), PlaybackState = "Begin" }
			local conn
			function tween:Play()
				local start = {}
				for k in goals do
					start[k] = inst[k]
				end
				local elapsed = 0
				tween.PlaybackState = "Playing"
				conn = heartbeat:Connect(function(dt)
					elapsed += dt
					if elapsed >= info.Time then
						conn:Disconnect()
						for k, v in goals do
							inst[k] = v
						end
						tween.PlaybackState = Enum.PlaybackState.Completed
						tween.Completed:Fire(Enum.PlaybackState.Completed)
					end
				end)
			end
			function tween:Cancel()
				if conn then
					conn:Disconnect()
				end
				tween.PlaybackState = Enum.PlaybackState.Cancelled
				tween.Completed:Fire(Enum.PlaybackState.Cancelled)
			end
			return tween
		end,
	}
	local tags, added, removed = {}, {}, {}
	local function sigFor(t, name)
		t[name] = t[name] or makeSignal()
		return t[name]
	end
	services.CollectionService = {
		GetTagged = function(_, name)
			return table.clone(tags[name] or {})
		end,
		AddTag = function(_, inst, name)
			tags[name] = tags[name] or {}
			if not table.find(tags[name], inst) then
				table.insert(tags[name], inst)
				sigFor(added, name):Fire(inst)
			end
		end,
		RemoveTag = function(_, inst, name)
			local list = tags[name] or {}
			local i = table.find(list, inst)
			if i then
				table.remove(list, i)
				sigFor(removed, name):Fire(inst)
			end
		end,
		HasTag = function(_, inst, name)
			return table.find(tags[name] or {}, inst) ~= nil
		end,
		GetInstanceAddedSignal = function(_, name)
			return sigFor(added, name)
		end,
		GetInstanceRemovedSignal = function(_, name)
			return sigFor(removed, name)
		end,
	}
end
