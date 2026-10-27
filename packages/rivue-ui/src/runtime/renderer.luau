--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local Types = require("./types")
local componentAPI = require("./component")
local hModule = require("./h")
local _reactivity = require("./reactivity")
local Pool = require("./pool")
local scheduler = require("./scheduler")
local _utils = require("./utils")
local directives = require("./directives")
local robloxModule = require("./roblox")

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local debugModule = require("./debug")

const IS_STUDIO = RunService:IsStudio()

type VNode = Types.VNode
type Props = Types.Props
type Child = Types.Child
type ComponentDef = Types.ComponentDef
type FunctionalComponent = Types.FunctionalComponent
type PoolOptions = Types.PoolOptions
type AppOptions = Types.AppOptions
type Effect = Types.Effect
type ComponentInstance = componentAPI.ComponentInstance
type AppContext = Types.AppContext

local Fragment = hModule.Fragment

type RenderVNode = VNode

export type TransitionConfig = Types.TransitionConfig

export type Plugin = ((app: App, ...any) -> ()) | { install: (app: App, ...any) -> () }

export type App = {
	config: Types.AppConfig,
	provide: (self: App, key: unknown, value: unknown) -> App,
	use: (self: App, plugin: Plugin, ...any) -> App,
	directive: (self: App, name: string, hooks: Types.Directive) -> App,
	component: (self: App, name: string, def: ComponentDef) -> App,
	styles: (self: App, styles: { [string]: Props }) -> App,
	onUnmount: (self: App, fn: () -> ()) -> App,
	runWithContext: <T>(self: App, fn: () -> T) -> T,
	printTree: (self: App) -> string,
	mount: (self: App, container: Instance) -> MountedState,
	unmount: (self: App) -> (),
	rerender: (self: App, newRoot: VNode?) -> MountedState,
	swapRoot: (self: App, newRoot: VNode) -> MountedState,
	mountToPlayerGui: (self: App, player: Player) -> (),
	getPoolStats: ((self: App) -> unknown)?,
	validatePoolHealth: ((self: App) -> boolean)?,
}

export type MountedState = {
	vnode: VNode?,
	container: Instance?,
	poolOpt: PoolOptions,
}

local formatTree: (vnode: VNode?) -> string
local patch: (oldVNode: RenderVNode?, newVNode: RenderVNode?, container: Instance, poolOpt: PoolOptions?) -> ()

local currentRenderingInstance: ComponentInstance? = nil
local currentAppContext: AppContext? = nil

local postQueue: { () -> () } = {}
local patching = false

local function queuePost(fn: () -> ())
	table.insert(postQueue, fn)
end

local function flushPostQueue()
	while #postQueue > 0 do
		local queue = postQueue
		postQueue = {}
		for _, fn in queue do
			local ok, err = pcall(fn :: () -> ...unknown)
			if not ok then
				warn(`[Rivue] Post-mount callback failed: {err}`)
			end
		end
	end
end

local warnedOnce: { [string]: true } = {}

local function devWarn(message: string)
	if IS_STUDIO and not warnedOnce[message] then
		warnedOnce[message] = true
		local appContext = if currentRenderingInstance then currentRenderingInstance.appContext else currentAppContext
		local warnHandler = if appContext then appContext.config.warnHandler else nil
		local trace = componentAPI.formatComponentTrace(currentRenderingInstance)
		if warnHandler then
			warnHandler(message, currentRenderingInstance, trace)
		else
			warn(`[Rivue] {message} (in {trace})`)
		end
	end
end

local function toUDim(v: unknown): UDim
	return if type(v) == "number" then UDim.new(0, v) else v :: UDim
end

local elementHandlers: { [Instance]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any
local elementOwners: { [Instance]: any } = setmetatable({}, { __mode = "k" }) :: any

local function callHandler(owner: any, handler: (...any) -> ...any, ...: any)
	local ok, err = pcall(handler, ...)
	if not ok then
		if owner then
			owner:handleError(tostring(err), "component event handler")
		else
			warn(`[Rivue] Error in event handler: {err}`)
		end
	end
end

type StateRecord = {
	vnode: RenderVNode,
	variants: { [string]: Props },
	active: { [string]: boolean },
	applied: { [string]: boolean },
	original: { [string]: unknown },
	conns: { RBXScriptConnection },
}

local stateRecords: { [Instance]: StateRecord } = setmetatable({}, { __mode = "k" }) :: any

local function clearStates(el: Instance)
	local record = stateRecords[el]
	if record then
		for _, conn in record.conns do
			conn:Disconnect()
		end
		stateRecords[el] = nil
	end
end

const DEVTOOLS_TAG = "RivueComponent"

const DEVTOOLS_ATTRIBUTES = {
	"RivueComponent",
	"RivueProps",
	"RivueState",
	"RivueRenders",
	"RivueRenderMs",
	"RivueTrigger",
	"RivueSource",
	"RivueEmit",
	"RivueEdit",
	"RivueProvides",
	"RivueInjects",
}

const DEVTOOLS_CHANNEL_TAG = "RivueDevToolsChannel"
const TIMELINE_LIMIT = 50

local devtoolsChannels: { [Instance]: boolean } = {}
local timeline: { string } = {}
local timelineSeq = 0
local lastRoute: string? = nil

local function oneLine(text: string): string
	return (string.gsub(text, "[\t\n]", " "))
end

local function devtoolsEvent(kind: string, label: string, detail: string?, ms: number?)
	if next(devtoolsChannels) == nil then
		return
	end
	timelineSeq += 1
	local msText = if ms then tostring(math.round(ms * 100) / 100) else ""
	table.insert(
		timeline,
		`{timelineSeq}\t{math.round(os.clock() * 1000)}\t{kind}\t{msText}\t{oneLine(label)}\t{oneLine(detail or "")}`
	)
	if #timeline > TIMELINE_LIMIT then
		table.remove(timeline, 1)
	end
	local text = table.concat(timeline, "\n")
	for channel in devtoolsChannels do
		channel:SetAttribute("RivueTimeline", text)
	end
end

local function devtoolsRoute(text: string)
	lastRoute = text
	for channel in devtoolsChannels do
		channel:SetAttribute("RivueRoute", text)
	end
end

local function openDevtoolsChannel(container: Instance): Instance
	local channel = Instance.new("Configuration")
	channel.Name = "RivueDevTools"
	channel:SetAttribute("RivueTimeline", table.concat(timeline, "\n"))
	if lastRoute then
		channel:SetAttribute("RivueRoute", lastRoute)
	end
	CollectionService:AddTag(channel, DEVTOOLS_CHANNEL_TAG)
	channel.Parent = container
	devtoolsChannels[channel] = true
	return channel
end

local function closeDevtoolsChannel(channel: Instance)
	devtoolsChannels[channel] = nil
	channel:Destroy()
end

local devtoolsEditConns: { [Instance]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

local function clearDevtools(el: Instance)
	local conn = devtoolsEditConns[el]
	if conn then
		conn:Disconnect()
		devtoolsEditConns[el] = nil
	end
	CollectionService:RemoveTag(el, DEVTOOLS_TAG)
	for _, name in DEVTOOLS_ATTRIBUTES do
		el:SetAttribute(name, nil)
	end
end

local guiObjectClasses: { [string]: boolean } = {}

local function isGuiObject(el: Instance, className: string?): boolean
	local cn = className or el.ClassName
	local cached = guiObjectClasses[cn]
	if cached == nil then
		cached = el:IsA("GuiObject")
		guiObjectClasses[cn] = cached
	end
	return cached
end

const TEXT_CLASSES = table.freeze({ TextLabel = true, TextButton = true, TextBox = true })

local function isTextObject(el: Instance, className: string?): boolean
	return TEXT_CLASSES[className or el.ClassName] == true
end

type SugarSpec = {
	className: string,
	classFor: ((value: any) -> string)?,
	apply: (child: Instance, value: any) -> (),
}

type LayoutOptions = {
	direction: ("vertical" | "horizontal")?,
	gap: (number | UDim)?,
	align: string?,
	justify: string?,
	wrap: boolean?,
	grid: UDim2?,
}

local function layoutOptions(value: any): LayoutOptions
	if value == "grid" then
		return { grid = UDim2.fromOffset(100, 100), direction = "horizontal" }
	elseif type(value) == "string" then
		return { direction = value :: any }
	end
	return value :: LayoutOptions
end

const HORIZONTAL_ALIGN = table.freeze({
	start = Enum.HorizontalAlignment.Left,
	center = Enum.HorizontalAlignment.Center,
	["end"] = Enum.HorizontalAlignment.Right,
})
const VERTICAL_ALIGN = table.freeze({
	start = Enum.VerticalAlignment.Top,
	center = Enum.VerticalAlignment.Center,
	["end"] = Enum.VerticalAlignment.Bottom,
})
const FLEX_JUSTIFY = table.freeze({
	["space-between"] = Enum.UIFlexAlignment.SpaceBetween,
	["space-around"] = Enum.UIFlexAlignment.SpaceAround,
	["space-evenly"] = Enum.UIFlexAlignment.SpaceEvenly,
	fill = Enum.UIFlexAlignment.Fill,
})
const FLEX_MODES = table.freeze({
	fill = Enum.UIFlexMode.Fill,
	grow = Enum.UIFlexMode.Grow,
	shrink = Enum.UIFlexMode.Shrink,
	none = Enum.UIFlexMode.None,
})

local function applyLayout(layout: Instance, options: LayoutOptions)
	local horizontal = options.direction == "horizontal"
	local list = layout :: UIListLayout
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical

	local gap = options.gap
	local gapUDim = if type(gap) == "number" then UDim.new(0, gap) else (gap :: UDim?) or UDim.new(0, 0)

	local alongX = if horizontal then options.justify else options.align
	local alongY = if horizontal then options.align else options.justify
	list.HorizontalAlignment = alongX and HORIZONTAL_ALIGN[alongX] or Enum.HorizontalAlignment.Left
	list.VerticalAlignment = alongY and VERTICAL_ALIGN[alongY] or Enum.VerticalAlignment.Top

	if layout:IsA("UIGridLayout") then
		local grid = layout :: UIGridLayout
		grid.CellSize = options.grid or UDim2.fromOffset(100, 100)
		grid.CellPadding = UDim2.new(gapUDim.Scale, gapUDim.Offset, gapUDim.Scale, gapUDim.Offset)
		return
	end

	list.Padding = gapUDim
	list.Wraps = options.wrap == true
	local flex = options.justify and FLEX_JUSTIFY[options.justify] or Enum.UIFlexAlignment.None
	list.HorizontalFlex = if horizontal then flex else Enum.UIFlexAlignment.None
	list.VerticalFlex = if horizontal then Enum.UIFlexAlignment.None else flex
end

local sugarSpecs: { [string]: SugarSpec } = {
	cornerRadius = {
		className = "UICorner",
		apply = function(c: Instance, v: any)
			(c :: UICorner).CornerRadius = toUDim(v)
		end,
	},
	padding = {
		className = "UIPadding",
		apply = function(c: Instance, v: any)
			local p = c :: UIPadding
			if typeof(v) == "table" then
				p.PaddingTop = toUDim(v.top or v.y or 0)
				p.PaddingBottom = toUDim(v.bottom or v.y or 0)
				p.PaddingLeft = toUDim(v.left or v.x or 0)
				p.PaddingRight = toUDim(v.right or v.x or 0)
			else
				local u = toUDim(v)
				p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = u, u, u, u
			end
		end,
	},
	stroke = {
		className = "UIStroke",
		apply = function(c: Instance, v: any)
			local stroke = c :: UIStroke
			if typeof(v) == "Color3" then
				stroke.Color = v
			elseif type(v) == "number" then
				stroke.Thickness = v
			else
				for k, x in v do
					(stroke :: any)[k] = x
				end
			end
		end,
	},
	aspectRatio = {
		className = "UIAspectRatioConstraint",
		apply = function(c: Instance, v: any)
			(c :: UIAspectRatioConstraint).AspectRatio = v
		end,
	},
	layout = {
		className = "UIListLayout",
		classFor = function(v: any): string
			return if layoutOptions(v).grid then "UIGridLayout" else "UIListLayout"
		end,
		apply = function(c: Instance, v: any)
			applyLayout(c, layoutOptions(v))
		end,
	},
	flex = {
		className = "UIFlexItem",
		apply = function(c: Instance, v: any)
			local item = c :: UIFlexItem
			if type(v) == "number" then
				item.FlexMode = Enum.UIFlexMode.Custom
				item.GrowRatio = v
				item.ShrinkRatio = v
			elseif type(v) == "string" then
				item.FlexMode = FLEX_MODES[v] or error(`unknown flex mode '{v}'`)
			else
				for k, x in v do
					(item :: any)[k] = x
				end
			end
		end,
	},
	gradient = {
		className = "UIGradient",
		apply = function(c: Instance, v: any)
			local gradient = c :: UIGradient
			local kind = typeof(v)
			if kind == "ColorSequence" or kind == "Color3" then
				gradient.Color = if kind == "Color3" then ColorSequence.new(v) else v
				return
			end
			local first, second = v[1], v[2]
			if first ~= nil then
				gradient.Color = if second ~= nil then ColorSequence.new(first, second) else ColorSequence.new(first)
			elseif v.color ~= nil then
				gradient.Color = if typeof(v.color) == "Color3" then ColorSequence.new(v.color) else v.color
			end
			gradient.Rotation = v.rotation or 0
			gradient.Offset = v.offset or Vector2.new(0, 0)
			local transparency = v.transparency or 0
			gradient.Transparency = if type(transparency) == "number"
				then NumberSequence.new(transparency)
				else transparency
		end,
	},
	scale = {
		className = "UIScale",
		apply = function(c: Instance, v: any)
			(c :: UIScale).Scale = v
		end,
	},
	sizeLimit = {
		className = "UISizeConstraint",
		apply = function(c: Instance, v: any)
			local constraint = c :: UISizeConstraint
			constraint.MinSize = v.min or Vector2.new(0, 0)
			constraint.MaxSize = v.max or Vector2.new(math.huge, math.huge)
		end,
	},
	textSizeLimit = {
		className = "UITextSizeConstraint",
		apply = function(c: Instance, v: any)
			local constraint = c :: UITextSizeConstraint
			constraint.MinTextSize = v.min or 1
			constraint.MaxTextSize = v.max or 100
		end,
	},
}
const SUGAR_PROPS = table.freeze(sugarSpecs)

local function setSugarProp(inst: Instance, key: string, value: unknown, vnode: VNode)
	local sugar = vnode._sugar or {}
	vnode._sugar = sugar
	local child = sugar[key]
	if value == nil then
		if child then
			child:Destroy()
			sugar[key] = nil
		end
		return
	end

	local spec = SUGAR_PROPS[key]
	local classFor = spec.classFor
	local className = if classFor then classFor(value) else spec.className
	if child and child.ClassName ~= className then
		child:Destroy()
		child = nil
	end
	local created = false
	if not child then
		child = Instance.new(className)
		sugar[key] = child
		created = true
	end
	local ok, err = pcall(spec.apply :: (Instance, unknown) -> ...unknown, child :: Instance, value)
	if not ok then
		devWarn(`Bad value for {key}: {err}`)
	end
	if created then
		(child :: Instance).Parent = inst
	end
end

local eventAlias: { [string]: { string } } = {
	onClick = { "Activated", "MouseButton1Click" },
	onActivated = { "Activated" },
	onMouseButton1Click = { "MouseButton1Click" },
	onTouched = { "Touched" },
}

type SignalTarget = { name: string, isProperty: boolean }
local eventSignalCache: { [string]: { [string]: SignalTarget | false } } = {}

local classPropCache: { [string]: { [string]: boolean } } = {}
local function classHasProp(inst: Instance, prop: string, className: string?): boolean
	local cn = className or inst.ClassName
	local cache = classPropCache[cn]
	if not cache then
		cache = {}
		classPropCache[cn] = cache
	end

	local cached = cache[prop]
	if cached ~= nil then
		return cached
	end

	local has = pcall(function()
		return (inst :: any)[prop]
	end)

	cache[prop] = has
	return has
end

local function tryGetSignal(inst: Instance, evName: string): (RBXScriptSignal?, boolean)
	local ok, member = pcall(function()
		return (inst :: any)[evName]
	end)
	if ok and typeof(member) == "RBXScriptSignal" then
		return member, false
	end

	local okProp, signal = pcall(function()
		return inst:GetPropertyChangedSignal(evName)
	end)

	if okProp and signal then
		return signal :: RBXScriptSignal, true
	end

	return nil, false
end

local function connectTarget(inst: Instance, target: SignalTarget, handler: (...any) -> ()): RBXScriptConnection?
	local signal = tryGetSignal(inst, target.name)
	if not signal then
		return nil
	end
	if target.isProperty then
		local name = target.name
		return signal:Connect(function()
			handler((inst :: any)[name])
		end)
	end
	return signal:Connect(handler)
end

local function connectEvent(
	inst: Instance,
	propName: string,
	handler: (...any) -> (),
	knownClassName: string?
): RBXScriptConnection?
	if type(propName) ~= "string" or type(handler) ~= "function" then
		return nil
	end

	local className = knownClassName or inst.ClassName

	if not eventSignalCache[className] then
		eventSignalCache[className] = {}
	end

	local classCache = eventSignalCache[className]

	local cached = classCache[propName]
	if cached == false then
		return nil
	elseif cached then
		return connectTarget(inst, cached :: SignalTarget, handler)
	end

	local aliases = eventAlias[propName]
	local names: { string } = {}

	if aliases then
		for _, n in ipairs(aliases) do
			table.insert(names, n)
		end
	else
		local eventName = propName:match("^on(.+)")
		if eventName then
			table.insert(names, eventName)
			table.insert(names, eventName:sub(1, 1):upper() .. eventName:sub(2))
			local property = eventName:match("^(.+)Changed$")
			if property then
				table.insert(names, property:sub(1, 1):upper() .. property:sub(2))
			end
		end
	end

	for _, evName in ipairs(names) do
		local signal, isProperty = tryGetSignal(inst, evName)
		if signal then
			local target = { name = evName, isProperty = isProperty }
			classCache[propName] = target
			return connectTarget(inst, target, handler)
		end
	end

	classCache[propName] = false
	return nil
end

local function writeProp(inst: Instance, prop: string, value: unknown): (boolean, unknown)
	return pcall(function()
		(inst :: any)[prop] = value
	end)
end

local BINDING_MARKER = "__rivueBinding"

local function bindingGetter(value: unknown): (() -> unknown)?
	if type(value) ~= "table" then
		return nil
	end
	local getter = rawget(value :: any, BINDING_MARKER)
	if type(getter) == "function" then
		return getter
	elseif _reactivity.isRef(value) then
		local r = value :: any
		return function(): unknown
			return r.value
		end
	end
	return nil
end

local BINDING_VNODE = newproxy(false)

local function stopBinding(vnode: RenderVNode, key: string)
	local bindings = vnode._bindings
	if bindings and bindings[key] then
		bindings[key]:stop()
		bindings[key] = nil
	end
end

local applyProp: (inst: Instance, key: string, value: any, vnode: RenderVNode) -> ()

--- The property is written from its own small effect: when what the getter reads changes, only
--- this property is written, and the component that rendered it doesn't run again
local function bindProp(inst: Instance, key: string, getter: () -> unknown, vnode: RenderVNode)
	local bindings: { [any]: any } = vnode._bindings or {}
	vnode._bindings = bindings
	bindings[BINDING_VNODE] = vnode
	local eff = _reactivity.effect(function()
		local value = getter()
		-- Untracked: in Immediate signal mode handlers run here and would become deps
		_reactivity._untracked(function()
			applyProp(inst, key, value, bindings[BINDING_VNODE])
		end)
	end, { lazy = true })
	bindings[key] = eff
	eff.run()
end

local function setProp(inst: Instance, key: string, value: any, vnode: RenderVNode)
	if vnode._bindings and vnode._bindings[key] then
		stopBinding(vnode, key)
	end
	if key:sub(1, 2) ~= "on" and key ~= "__directives" then
		local getter = bindingGetter(value)
		if getter then
			bindProp(inst, key, getter, vnode)
			return
		end
	end
	applyProp(inst, key, value, vnode)
end

function applyProp(inst: Instance, key: string, value: any, vnode: RenderVNode)
	local className: string? = if type(vnode.type) == "string" then vnode.type else nil

	if key == "__directives" and type(value) == "table" then
		local dirs = vnode._dirs or {}
		vnode._dirs = dirs
		for _, d in value do
			local hook = directives.get(d.name)
			if hook and hook.mounted then
				local state = hook.mounted(inst, d.value)
				dirs[d.name] = if state == nil then false else state
			end
		end
		return
	end

	if key:sub(1, 2) == "on" and type(value) == "function" then
		local conns = vnode._conns or {}
		local handlers: { [string]: (...any) -> () } = vnode._handlers :: any
		if not handlers then
			handlers = {}
			elementHandlers[inst] = handlers
			elementOwners[inst] = currentRenderingInstance
		end
		vnode._conns, vnode._handlers = conns, handlers
		handlers[key] = value
		if conns[key] then
			return
		end

		local function invoke(...: any)
			local handler = handlers[key]
			if handler then
				callHandler(elementOwners[inst], handler, ...)
			end
		end

		if key == "onTextChanged" and isTextObject(inst, className) then
			local textInst = inst :: TextBox
			conns[key] = textInst:GetPropertyChangedSignal("Text"):Connect(function()
				invoke(textInst.Text)
			end)
			return
		end

		local conn = connectEvent(inst, key, invoke, className)
		if conn then
			conns[key] = conn
		end
		return
	end

	if SUGAR_PROPS[key] and isGuiObject(inst, className) then
		setSugarProp(inst, key, value, vnode)
		return
	end

	if classHasProp(inst, key, className) then
		local ok, err = writeProp(inst, key, value)
		if ok then
			local touched = vnode._touched or {}
			vnode._touched = touched
			touched[key] = true
		else
			debugModule.log("Renderer", `Failed to set prop {key}: {err}`)
		end
		return
	end

	local pascalKey = key:sub(1, 1):upper() .. key:sub(2)
	if classHasProp(inst, pascalKey, className) then
		local ok, err = writeProp(inst, pascalKey, value)
		if ok then
			local touched = vnode._touched or {}
			vnode._touched = touched
			touched[pascalKey] = true
		else
			debugModule.log("Renderer", `Failed to set prop {pascalKey}: {err}`)
		end
		return
	end

	devWarn(`{inst.ClassName} has no property '{key}'`)
end

local function clearVNodeConns(vnode: RenderVNode?)
	if not vnode then
		return
	end

	local bindings = vnode._bindings
	if bindings then
		for key, eff in bindings do
			if key ~= BINDING_VNODE then
				eff:stop()
			end
		end
		vnode._bindings = nil
	end

	local conns = vnode._conns
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		vnode._conns = nil
		vnode._handlers = nil
		if vnode.el then
			elementHandlers[vnode.el] = nil
			elementOwners[vnode.el] = nil
		end
	end

	local dirs = vnode._dirs
	local el = vnode.el
	if el and stateRecords[el] then
		clearStates(el)
	end
	if dirs then
		for name, state in dirs do
			local hook = directives.get(name)
			if hook and hook.unmounted and el then
				pcall(hook.unmounted, el, state)
			end
		end
		vnode._dirs = nil
	end
end

local function withPreservedTextState(el: Instance, fn: () -> (), textFromProps: boolean)
	if not el:IsA("TextBox") then
		fn()
		return
	end

	local box = el :: TextBox
	local focused = UserInputService:GetFocusedTextBox() == box
	local text = box.Text
	local cursor = box.CursorPosition

	fn()

	if not textFromProps and box.Text ~= text then
		box.Text = text
	end
	if focused then
		if box.Text == text then
			box.CursorPosition = cursor
		end
		if UserInputService:GetFocusedTextBox() ~= box then
			box:CaptureFocus()
		end
	end
end

local function getTransition(vnode: RenderVNode): TransitionConfig?
	local t = vnode._transition
	if t then
		return t
	end
	local props = vnode.props
	local p = if props then props.transition else nil
	return if type(p) == "table" then p :: TransitionConfig else nil
end

local function runTransitionHooks(vnode: RenderVNode, name: string, fn: ((el: Instance) -> ())?, el: Instance)
	if fn then
		local ok, err = pcall(fn :: (Instance) -> ...unknown, el)
		if not ok then
			warn(`[Rivue] Transition {name} callback failed: {err}`)
		end
	end
	local hooks = vnode._transitionHooks
	local list = if hooks then hooks[name] else nil
	if list then
		for _, hook in list do
			pcall(hook, el)
		end
	end
end

--- Keeps only properties this element has, so one preset can serve a Frame and a TextLabel (one
--- unknown property makes TweenService reject the whole tween). A function value gets the current
--- value and returns the goal, for relative moves like "20 px below where it is"
local function resolveGoals(el: Instance, goals: { [string]: any }): { [string]: any }
	local out = {}
	for k, v in goals do
		local ok, current = pcall(function()
			return (el :: any)[k]
		end)
		if ok and current ~= nil then
			out[k] = if type(v) == "function" then v(current) else v
		end
	end
	return out
end

local function createTween(el: Instance, info: TweenInfo?, goals: { [string]: any }?): Tween?
	if not info or not goals then
		return nil
	end
	local ok, tween = pcall(TweenService.Create, TweenService, el, info, resolveGoals(el, goals))
	return if ok then tween else nil
end

local function runEnter(vnode: RenderVNode, el: Instance, t: TransitionConfig, goals: { [string]: any }?)
	if el.Parent == nil then
		return
	end
	runTransitionHooks(vnode, "enter", nil, el)
	local tween = createTween(el, t.enterInfo or t.tweenInfo or t.info, goals)
	if not tween then
		runTransitionHooks(vnode, "after-enter", t.onAfterEnter, el)
		return
	end
	vnode._tween = tween
	tween.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			runTransitionHooks(vnode, "after-enter", t.onAfterEnter, el)
		end
	end)
	tween:Play()
end

local function runLeave(vnode: RenderVNode, el: Instance, t: TransitionConfig)
	local running = vnode._tween
	if running then
		running:Cancel()
		vnode._tween = nil
	end
	runTransitionHooks(vnode, "before-leave", t.onBeforeLeave, el)

	local function finish()
		runTransitionHooks(vnode, "after-leave", t.onAfterLeave, el)
		el:Destroy()
	end

	local tween = createTween(el, t.leaveInfo or t.tweenInfo or t.info, t.leaveGoals or t.from or t.goals)
	if not tween then
		finish()
		return
	end
	runTransitionHooks(vnode, "leave", nil, el)
	tween.Completed:Once(finish)
	tween:Play()
end

local function setTemplateRef(props: Props?, owner: unknown, value: unknown)
	local r = if props then props.ref else nil
	if r == nil then
		return
	end
	if type(r) == "string" then
		local inst = owner :: ComponentInstance?
		if inst then
			inst.refs[r] = value
			local tracked = inst.templateRefs[r]
			if tracked then
				tracked.value = value
			end
		end
	elseif type(r) == "function" then
		pcall(r, value)
	elseif type(r) == "table" and r._is_ref then
		r.value = value
	end
end

local function memoEqual(a: unknown, b: unknown): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	local listA, listB = a :: { unknown }, b :: { unknown }
	local count = #listA
	if count ~= #listB then
		return false
	end
	for i = 1, count do
		if listA[i] ~= listB[i] then
			return false
		end
	end
	return true
end

local function asComponent(vnodeType: unknown): ComponentDef?
	if type(vnodeType) == "table" and (vnodeType :: ComponentDef).__is_component then
		return vnodeType :: ComponentDef
	end
	return nil
end

const RESERVED_PROPS = table.freeze({
	__directives = true,
	__states = true,
	key = true,
	ref = true,
	transition = true,
	memo = true,
	class = true,
	disabled = true,
})

local function collectClassNames(value: unknown, out: { string })
	if type(value) == "string" then
		for name in string.gmatch(value, "%S+") do
			table.insert(out, name)
		end
	elseif type(value) == "table" then
		local list = value :: { [unknown]: unknown }
		for i = 1, table.maxn(list :: { unknown }) do
			collectClassNames(list[i], out)
		end
		local keyed: { string } = {}
		for key, enabled in list do
			if type(key) == "string" and enabled then
				table.insert(keyed, key)
			end
		end
		table.sort(keyed)
		table.move(keyed, 1, #keyed, #out + 1, out)
	end
end

const STYLE_VARIANTS = table.freeze({
	hover = true,
	pressed = true,
	selected = true,
	disabled = true,
	phone = true,
	tablet = true,
	desktop = true,
	console = true,
})
const INTERACTION_STATES = table.freeze({ "selected", "hover", "pressed" })

local function mergeInto(into: Props, from: unknown)
	if type(from) == "table" then
		for k, v in from :: Props do
			into[k] = v
		end
	end
end

--- The owner's styles option is checked before the app's styles. Device variants are merged here,
--- interaction states are left in __states for the element to apply on input
local function applyClasses(props: Props, owner: ComponentInstance?, appContext: AppContext?): Props
	local names: { string } = {}
	collectClassNames(props.class, names)
	if #names == 0 and props.disabled == nil then
		return props
	end
	local disabled = props.disabled == true
	local localStyles = if owner then owner.type.styles else nil
	local appStyles = if appContext then appContext.styles else nil
	local fromClasses: Props = {}
	local states: { [string]: Props }? = nil
	local device: string? = nil
	for _, name in names do
		local style = (localStyles and localStyles[name]) or (appStyles and appStyles[name])
		if style then
			for k, v in style do
				if not STYLE_VARIANTS[k] then
					fromClasses[k] = v
				end
			end
			if style.phone or style.tablet or style.desktop or style.console then
				device = device or robloxModule.useDevice().value
				mergeInto(fromClasses, style[device :: string])
			end
			if disabled then
				mergeInto(fromClasses, style.disabled)
			end
			for _, state in INTERACTION_STATES do
				local variant = style[state]
				if type(variant) == "table" and not (disabled and state ~= "selected") then
					local all = states or {}
					states = all
					local into = all[state] or {}
					all[state] = into
					mergeInto(into, variant)
				end
			end
		elseif IS_STUDIO then
			devWarn(`Unknown class '{name}', register it with app:styles() or the component's styles option`)
		end
	end
	local merged = table.clone(props)
	for k, v in fromClasses do
		if merged[k] == nil then
			merged[k] = v
		end
	end
	if props.disabled ~= nil and merged.Interactable == nil then
		merged.Interactable = not disabled
	end
	if states then
		for _, variant in states do
			for k in variant do
				if props[k] ~= nil then
					variant[k] = nil
				end
			end
		end
		merged.__states = states
	end
	return merged
end

local function statesEqual(a: unknown, b: unknown): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	local left, right = a :: { [string]: Props }, b :: { [string]: Props }
	for _, state in INTERACTION_STATES do
		local x, y = left[state], right[state]
		if (x == nil) ~= (y == nil) then
			return false
		elseif x and y then
			for k, v in x do
				if y[k] ~= v then
					return false
				end
			end
			for k in y do
				if x[k] == nil then
					return false
				end
			end
		end
	end
	return true
end

local function applyStates(el: Instance, record: StateRecord)
	local props: Props = record.vnode.props or {}
	local wanted: Props = {}
	for _, state in INTERACTION_STATES do
		if record.active[state] then
			mergeInto(wanted, record.variants[state])
		end
	end
	for k in record.applied do
		if wanted[k] == nil then
			local base = props[k]
			if base == nil then
				base = record.original[k]
			end
			if base ~= nil then
				setProp(el, k, base, record.vnode)
			end
			record.applied[k] = nil
		end
	end
	for k, v in wanted do
		if not record.applied[k] and props[k] == nil and record.original[k] == nil then
			local ok, current = pcall(function()
				return (el :: any)[k]
			end)
			if ok then
				record.original[k] = current
			end
		end
		setProp(el, k, v, record.vnode)
		record.applied[k] = true
	end
end

local function setInteraction(el: Instance, state: string, on: boolean)
	local record = stateRecords[el]
	if record and record.active[state] ~= on then
		record.active[state] = on
		applyStates(el, record)
	end
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

--- Runs after an element's props are written, so active states sit on top of the new base values
local function syncStates(vnode: RenderVNode, el: Instance)
	local props = vnode.props
	local variants = if props then props.__states else nil
	local record = stateRecords[el]
	if type(variants) ~= "table" then
		if record then
			record.vnode = vnode
			record.variants = {}
			applyStates(el, record)
		end
		return
	end
	if not el:IsA("GuiObject") then
		return
	end
	if not record then
		local gui = el :: GuiObject
		local created: StateRecord =
			{ vnode = vnode, variants = variants, active = {}, applied = {}, original = {}, conns = {} }
		record = created
		stateRecords[el] = created
		table.insert(
			created.conns,
			gui.MouseEnter:Connect(function()
				setInteraction(el, "hover", true)
			end)
		)
		table.insert(
			created.conns,
			gui.MouseLeave:Connect(function()
				created.active.pressed = false
				setInteraction(el, "hover", false)
			end)
		)
		table.insert(
			created.conns,
			gui.InputBegan:Connect(function(input)
				if isPress(input) then
					setInteraction(el, "pressed", true)
				end
			end)
		)
		table.insert(
			created.conns,
			gui.InputEnded:Connect(function(input)
				if isPress(input) then
					setInteraction(el, "pressed", false)
				end
			end)
		)
		table.insert(
			created.conns,
			gui.SelectionGained:Connect(function()
				setInteraction(el, "selected", true)
			end)
		)
		table.insert(
			created.conns,
			gui.SelectionLost:Connect(function()
				setInteraction(el, "selected", false)
			end)
		)
	end
	local current = record :: StateRecord
	current.vnode = vnode
	current.variants = variants :: { [string]: Props }
	applyStates(el, current)
end

const LAYOUT_CLASSES =
	table.freeze({ UIListLayout = true, UIGridLayout = true, UIPageLayout = true, UITableLayout = true })

local function hasLayoutChild(children: { Child }): boolean
	for _, child in children do
		if type(child) == "table" and LAYOUT_CLASSES[child.type :: any] then
			return true
		end
	end
	return false
end

local appliedLayoutOrder: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

const LAYOUT_STEP = 64

local function collectLayoutTargets(children: { Child }, out: { GuiObject })
	for i = 1, table.maxn(children) do
		local child = children[i]
		if type(child) ~= "table" then
			continue
		end
		if child.type == Fragment then
			collectLayoutTargets(child.children, out)
			continue
		end
		local props = child.props
		if props and props.LayoutOrder ~= nil then
			continue
		end
		local inst = child._instance :: ComponentInstance?
		local el = child.el or (if inst then inst.el else nil)
		if not el then
			continue
		end
		local subTree = if inst then inst.subTree else nil
		local className = if type(child.type) == "string"
			then child.type :: string
			elseif subTree and type(subTree.type) == "string" then subTree.type :: string
			else nil
		if isGuiObject(el, className) then
			table.insert(out, el :: GuiObject)
		end
	end
end

local function writeLayoutOrder(el: GuiObject, value: number)
	if appliedLayoutOrder[el] ~= value then
		appliedLayoutOrder[el] = value
		el.LayoutOrder = value
	end
end

--- Gives children increasing LayoutOrder in list order, so a layout shows them as rendered.
--- The longest run of children already in order keeps its values; only the others are written,
--- into the gaps between their neighbours. Removing, appending or prepending a row writes one
--- value. Fragments are counted through, and a child that sets LayoutOrder itself keeps it.
local function syncLayoutOrder(children: { Child })
	local els: { GuiObject } = {}
	collectLayoutTargets(children, els)
	local n = #els
	if n == 0 then
		return
	end

	local tails: { number } = {}
	local tailAt: { number } = {}
	local before: { number } = table.create(n, 0)
	for i = 1, n do
		local v = appliedLayoutOrder[els[i]]
		if v ~= nil then
			local lo, hi = 1, #tails
			while lo <= hi do
				local mid = (lo + hi) // 2
				if tails[mid] < v then
					lo = mid + 1
				else
					hi = mid - 1
				end
			end
			tails[lo] = v
			tailAt[lo] = i
			before[i] = if lo > 1 then tailAt[lo - 1] else 0
		end
	end
	local keep: { [number]: true } = {}
	local k = tailAt[#tails] or 0
	while k > 0 do
		keep[k] = true
		k = before[k]
	end

	local i = 1
	local low: number? = nil
	while i <= n do
		if keep[i] then
			low = appliedLayoutOrder[els[i]]
			i += 1
			continue
		end
		local j = i
		while j <= n and not keep[j] do
			j += 1
		end
		local count = j - i
		local high: number? = if j <= n then appliedLayoutOrder[els[j]] else nil
		if low and high and high - low - 1 < count then
			for t = 1, n do
				writeLayoutOrder(els[t], t * LAYOUT_STEP)
			end
			return
		end
		for t = 1, count do
			local value = if low and high
				then low + (t * (high - low)) // (count + 1)
				elseif low then low + t * LAYOUT_STEP
				elseif high then high - (count - t + 1) * LAYOUT_STEP
				else t * LAYOUT_STEP
			writeLayoutOrder(els[i + t - 1], value)
		end
		low = appliedLayoutOrder[els[j - 1]]
		i = j
	end
end

local function mountElement(vnode: RenderVNode, container: Instance, poolOpt: PoolOptions?): Instance
	local tag = vnode.type :: string
	local props = vnode.props
	if debugModule.enabled then
		debugModule.log("Renderer", "Mounting element", {
			type = tag,
			usePool = poolOpt ~= nil and poolOpt.usePool == true,
			childCount = #vnode.children,
			hasKey = vnode.key ~= nil,
		})
	end

	local inst: Instance
	if poolOpt and poolOpt.usePool then
		inst = Pool.acquire(tag)
	else
		local ok, created = pcall(Instance.new, tag)
		if ok then
			inst = created
		else
			warn(`[Rivue] Unknown element type '{tag}', falling back to Frame`)
			inst = Instance.new("Frame")
		end
	end

	vnode.el = inst
	setTemplateRef(props, vnode._owner, inst)

	if props then
		for k, v in props do
			if not RESERVED_PROPS[k] then
				setProp(inst, k, v, vnode)
			end
		end
	end

	if props and props.__states ~= nil then
		syncStates(vnode, inst)
	end

	local transition = getTransition(vnode)
	local enterGoals: { [string]: any }? = nil
	if transition and transition.enter then
		runTransitionHooks(vnode, "before-enter", transition.onBeforeEnter, inst)
		enterGoals = transition.enterGoals or transition.goals
		local fromIn: { [string]: any }? = transition.enterFrom or transition.from
		local from = if fromIn then resolveGoals(inst, fromIn) else nil
		if from then
			if not enterGoals then
				local back = {}
				for k in from do
					local ok, v = pcall(function()
						return (inst :: any)[k]
					end)
					if ok then
						back[k] = v
					end
				end
				enterGoals = back
			end
			for k, v in from do
				writeProp(inst, k, v)
			end
		end
	end

	local children = vnode.children
	for i, child in children do
		if type(child) == "function" then
			local rendered = child()
			children[i] = rendered :: any
			child = rendered :: any
		end

		if type(child) == "string" or type(child) == "number" then
			local text = tostring(child)
			if isTextObject(inst, tag) then
				(inst :: TextLabel).Text = text
			else
				local tl = Instance.new("TextLabel")
				tl.Size = UDim2.fromOffset(200, 50)
				tl.Text = text
				tl.Parent = inst
			end
		elseif type(child) == "table" then
			patch(nil, child, inst, poolOpt)
		end
	end

	if hasLayoutChild(children) or (props ~= nil and props.layout ~= nil) then
		syncLayoutOrder(children)
	end

	inst.Parent = container

	local vnodeDirectives = if props then props.__directives else nil
	if type(vnodeDirectives) == "table" then
		queuePost(function()
			if vnode.el == inst then
				setProp(inst, "__directives", vnodeDirectives, vnode)
			end
		end)
	end

	if transition and transition.enter then
		local t = transition
		queuePost(function()
			runEnter(vnode, inst, t, enterGoals)
		end)
	end

	return inst
end

local function walkComponents(vnode: RenderVNode?, fn: (inst: ComponentInstance) -> ())
	if vnode == nil then
		return
	end
	local inst = vnode._instance :: ComponentInstance?
	if inst then
		walkComponents(inst.subTree, fn)
		fn(inst)
		return
	end
	if vnode._fnTree then
		walkComponents(vnode._fnTree, fn)
		return
	end
	for _, c in vnode.children do
		if type(c) == "table" then
			walkComponents(c, fn)
		end
	end
end

local function collectRootEls(vnode: RenderVNode?, out: { Instance }): { Instance }
	if vnode == nil then
		return out
	end
	local inst = vnode._instance :: ComponentInstance?
	if inst then
		return collectRootEls(inst.subTree, out)
	elseif vnode._fnTree then
		return collectRootEls(vnode._fnTree, out)
	elseif vnode.type == Fragment then
		for _, c in vnode.children do
			if type(c) == "table" then
				collectRootEls(c, out)
			end
		end
	elseif vnode.el and type(vnode.type) == "string" then
		table.insert(out, vnode.el)
	end
	return out
end

local function deactivateComponent(vnode: RenderVNode)
	local inst = vnode._instance :: ComponentInstance
	inst.isDeactivated = true
	for _, el in collectRootEls(vnode, {}) do
		el.Parent = nil
	end
	walkComponents(vnode, function(c)
		c:runDeactivated()
	end)
end

--- doRemove is false when an ancestor Instance is destroyed anyway
local function unmountVNode(vnode: RenderVNode?, poolOpt: PoolOptions?, doRemove: boolean?)
	if vnode == nil then
		return
	end

	local def = asComponent(vnode.type)
	if debugModule.enabled then
		debugModule.log("Renderer", "Unmounting VNode", {
			type = if type(vnode.type) == "string" then vnode.type else "component",
			childCount = #vnode.children,
			isComponent = def ~= nil,
		})
	end

	if def then
		if def == componentAPI.Teleport then
			vnode._deferred = nil
			for _, child in vnode.children do
				if type(child) == "table" then
					unmountVNode(child, poolOpt)
				end
			end
			vnode._teleportTarget = nil
			return
		end

		local keepAlive = vnode._keepAlive
		if keepAlive and not keepAlive.disposed and vnode._instance then
			deactivateComponent(vnode)
			return
		end

		setTemplateRef(vnode.props, vnode._owner, nil)
		local inst = vnode._instance :: ComponentInstance?
		if inst then
			inst.isUnmounted = true
			local renderEffect = inst._renderEffect
			if renderEffect then
				renderEffect:stop()
				inst._renderEffect = nil
			end

			inst:runBeforeUnmount()

			local root = inst.el
			if root and inst.appContext.config.devtools then
				clearDevtools(root)
			end
			unmountVNode(inst.subTree, poolOpt, doRemove)
			inst:runUnmounted()
			vnode._instance = nil
		end
		return
	end

	if vnode.type == Fragment then
		for _, child in vnode.children do
			if type(child) == "table" then
				unmountVNode(child, poolOpt, doRemove)
			end
		end
		vnode.el = nil
		return
	end

	if type(vnode.type) == "function" then
		unmountVNode(vnode._fnTree, poolOpt, doRemove)
		vnode._fnTree = nil
		vnode.el = nil
		return
	end

	clearVNodeConns(vnode)
	setTemplateRef(vnode.props, vnode._owner, nil)

	local el = vnode.el
	vnode.el = nil
	if el then
		appliedLayoutOrder[el] = nil
	end
	local pooled = poolOpt ~= nil and poolOpt.usePool == true and el ~= nil and not el:IsA("ScreenGui")
	local transition = getTransition(vnode)
	local leaving = el ~= nil and doRemove ~= false and transition ~= nil and transition.leave == true

	local removeChildren = pooled and not leaving
	for _, c in vnode.children do
		if type(c) == "table" then
			unmountVNode(c, poolOpt, removeChildren)
		end
	end

	if not el or doRemove == false then
		return
	end

	if leaving then
		runLeave(vnode, el, transition :: TransitionConfig)
	elseif pooled then
		local sugar = vnode._sugar
		if sugar then
			for _, child in sugar do
				child:Destroy()
			end
			vnode._sugar = nil
		end
		Pool.release(el, vnode._touched)
	else
		el:Destroy()
	end
end

local function patchKeyedChildren(
	oldChildren: { Child }?,
	newChildren: { Child }?,
	parent: Instance,
	poolOpt: PoolOptions?
)
	local oldList: { Child } = oldChildren or {}
	local newList: { Child } = newChildren or {}

	local oldMap: { [unknown]: VNode } = {}
	for _, oc in oldList do
		if type(oc) == "table" and oc.key ~= nil then
			oldMap[oc.key] = oc
		end
	end

	local seenKeys: { [unknown]: true }? = if IS_STUDIO then {} else nil
	local reusedUnkeyed: { [number]: true } = {}

	for i = 1, table.maxn(newList) do
		local nc = newList[i]
		if type(nc) ~= "table" then
			continue
		end

		local k = nc.key
		if k ~= nil then
			if seenKeys then
				if seenKeys[k] then
					devWarn(`Duplicate key '{tostring(k)}' in children of {parent:GetFullName()}`)
				end
				seenKeys[k] = true
			end
			local oc = oldMap[k]
			if oc then
				patch(oc, nc, parent, poolOpt)
				oldMap[k] = nil
			else
				-- Don't look rows up by key in the parent, another list there may own one
				patch(nil, nc, parent, poolOpt)
			end
		else
			local oc = oldList[i]
			if type(oc) == "table" and oc.key == nil then
				reusedUnkeyed[i] = true
				patch(oc, nc, parent, poolOpt)
			else
				patch(nil, nc, parent, poolOpt)
			end
		end
	end

	for _, v in oldMap do
		unmountVNode(v, poolOpt)
	end

	for i = 1, table.maxn(oldList) do
		local oc = oldList[i]
		if type(oc) == "table" and oc.key == nil and not reusedUnkeyed[i] then
			unmountVNode(oc, poolOpt)
		end
	end
end

type DirectiveBinding = { name: string, value: unknown }

local function patchDirectives(
	el: Instance,
	oldBindings: { DirectiveBinding }?,
	newBindings: { DirectiveBinding }?,
	vnode: RenderVNode
)
	local dirs = vnode._dirs or {}
	vnode._dirs = dirs

	local newList: { DirectiveBinding } = newBindings or {}
	local oldList: { DirectiveBinding } = oldBindings or {}

	local wasBound: { [string]: true } = {}
	for _, d in oldList do
		wasBound[d.name] = true
	end

	local seen: { [string]: true } = {}
	for _, d in newList do
		seen[d.name] = true
		local hook = directives.get(d.name)
		if not hook then
			continue
		end
		if not wasBound[d.name] then
			if hook.mounted then
				local state = hook.mounted(el, d.value)
				dirs[d.name] = if state == nil then false else state
			end
		elseif hook.updated then
			local nextState = hook.updated(el, d.value, dirs[d.name])
			if nextState ~= nil then
				dirs[d.name] = nextState
			end
		end
	end

	for _, d in oldList do
		if not seen[d.name] then
			local hook = directives.get(d.name)
			if hook and hook.unmounted then
				pcall(hook.unmounted, el, dirs[d.name])
			end
			dirs[d.name] = nil
		end
	end
end

local function patchProps(el: Instance, oldPropsIn: Props?, newPropsIn: Props?, vnode: RenderVNode)
	local oldProps: Props = oldPropsIn or {}
	local newProps: Props = newPropsIn or {}

	local removedProps: { [string]: boolean }? = nil
	for k in oldProps do
		if newProps[k] ~= nil or RESERVED_PROPS[k] then
			continue
		end
		if vnode._bindings and vnode._bindings[k] then
			stopBinding(vnode, k)
		end
		if k:sub(1, 2) == "on" then
			local conns = vnode._conns
			local conn = if conns then conns[k] else nil
			if conns and conn then
				conn:Disconnect()
				conns[k] = nil
			end
			local handlers = vnode._handlers
			if handlers then
				handlers[k] = nil
			end
		elseif SUGAR_PROPS[k] and vnode._sugar then
			setSugarProp(el, k, nil, vnode)
		elseif classHasProp(el, k, if type(vnode.type) == "string" then vnode.type else nil) then
			local removed = removedProps or {}
			removedProps = removed
			removed[k] = true
		end
	end
	if removedProps then
		Pool.restoreDefaults(el, removedProps)
	end

	for k, v in newProps do
		if oldProps[k] ~= v and not RESERVED_PROPS[k] then
			setProp(el, k, v, vnode)
		end
	end

	if oldProps.__directives ~= nil or newProps.__directives ~= nil then
		patchDirectives(el, oldProps.__directives, newProps.__directives, vnode)
	end
end

local function withRenderingInstance(inst: ComponentInstance, fn: () -> ())
	local prev = currentRenderingInstance
	currentRenderingInstance = inst
	local ok, err = pcall(fn :: () -> ...unknown)
	currentRenderingInstance = prev
	if not ok then
		error(err, 0)
	end
end

--- props.to, or in place when props.disabled. Nil if props.to isn't parented yet
local function resolveTeleportTarget(vnode: RenderVNode, container: Instance): Instance?
	local props = vnode.props
	if props and props.disabled then
		return container
	end
	local target: unknown = if props then props.to else nil
	if type(target) == "function" then
		target = (target :: () -> unknown)()
	end
	if typeof(target) == "Instance" and target.Parent ~= nil then
		return target
	end
	devWarn("Teleport target is missing or not parented")
	return nil
end

local function mountTeleport(vnode: RenderVNode, container: Instance, poolOpt: PoolOptions?, now: boolean?)
	local props = vnode.props
	if props and props.defer and not now then
		vnode._deferred = true
		queuePost(function()
			if vnode._deferred then
				vnode._deferred = nil
				mountTeleport(vnode, container, poolOpt, true)
			end
		end)
		return
	end
	local target = resolveTeleportTarget(vnode, container)
	vnode._teleportTarget = target
	if not target then
		return
	end
	for _, child in vnode.children do
		if type(child) == "table" then
			patch(nil, child, target, poolOpt)
		end
	end
end

local function patchTeleport(oldVNode: RenderVNode, newVNode: RenderVNode, container: Instance, poolOpt: PoolOptions?)
	oldVNode._deferred = nil
	local target = resolveTeleportTarget(newVNode, container)
	local oldTarget = oldVNode._teleportTarget
	if target and target == oldTarget then
		newVNode._teleportTarget = target
		patchKeyedChildren(oldVNode.children, newVNode.children, target, poolOpt)
		return
	end
	for _, child in oldVNode.children do
		if type(child) == "table" then
			unmountVNode(child, poolOpt)
		end
	end
	mountTeleport(newVNode, container, poolOpt)
end

local function describeValue(value: unknown): string
	local t = typeof(value)
	if t == "string" then
		local text = value :: string
		return if #text > 24 then `"{string.sub(text, 1, 21)}..."` else `"{text}"`
	elseif t == "number" or t == "boolean" or t == "EnumItem" then
		return tostring(value)
	elseif t == "Instance" then
		return (value :: Instance).Name
	end
	return t
end

const DEVTOOLS_TEXT_LIMIT = 1000

local function devtoolsText(lines: { string }): string
	table.sort(lines)
	local text = table.concat(lines, "\n")
	return if #text > DEVTOOLS_TEXT_LIMIT then string.sub(text, 1, DEVTOOLS_TEXT_LIMIT - 3) .. "..." else text
end

local function describeKey(key: unknown): string
	return if type(key) == "string" then `.{key}` elseif type(key) == "number" then `[{key}]` else " (items)"
end

local function describeTrigger(inst: ComponentInstance, target: unknown, key: unknown): string
	if target == _reactivity.toRaw(inst.props) then
		return `props{describeKey(key)}`
	end
	local setupState = inst.setupState
	if type(setupState) == "table" then
		for name, value in next, setupState do
			if value == target then
				return tostring(name)
			elseif type(value) == "table" and _reactivity.toRaw(value) == target then
				return `{name}{describeKey(key)}`
			end
		end
	end
	return "a computed or outside state"
end

local function recordTrigger(inst: ComponentInstance, event: Types.DebuggerEvent)
	local list: { string } = inst._devtoolsTriggers or {}
	inst._devtoolsTriggers = list
	local text = describeTrigger(inst, event.target, event.key)
	if #list < 3 and not table.find(list, text) then
		table.insert(list, text)
	end
end

local function writeDevtoolsState(inst: ComponentInstance, el: Instance)
	local state: { string } = {}
	local setupState = inst.setupState
	if type(setupState) == "table" then
		for key, value in next, setupState do
			if type(value) == "table" and rawget(value :: any, "_is_ref") then
				table.insert(state, `{key} = {describeValue(rawget(value :: any, "_value"))}`)
			end
		end
	end
	el:SetAttribute("RivueState", devtoolsText(state))
end

--- Applies "key=value" from the DevTools plugin to the ref setup returned as `key`. Only numbers,
--- strings and booleans, and only when the text parses as the ref's current type
local function applyDevtoolsEdit(inst: ComponentInstance, el: Instance)
	local raw = el:GetAttribute("RivueEdit")
	if type(raw) ~= "string" then
		return
	end
	el:SetAttribute("RivueEdit", nil)
	local key, text = string.match(raw, "^([^=]+)=(.*)$")
	local setupState = inst.setupState
	if not key or not text or type(setupState) ~= "table" then
		return
	end
	local target = rawget(setupState :: any, key)
	if type(target) ~= "table" or not rawget(target, "_is_ref") then
		return
	end
	local current = rawget(target, "_value")
	local value: unknown = nil
	if type(current) == "number" then
		value = tonumber(text)
	elseif type(current) == "boolean" then
		value = if text == "true" then true elseif text == "false" then false else nil
	elseif type(current) == "string" then
		value = string.match(text, '^"(.*)"$') or text
	end
	if value ~= nil then
		(target :: any).value = value
		writeDevtoolsState(inst, el)
	end
end

local devtoolsEmitCount = 0

componentAPI.devtoolsHooks.emit = function(inst: ComponentInstance, eventName: string, args: { unknown })
	local el = inst.el
	if not el then
		return
	end
	local parts = {}
	for i = 1, #args do
		parts[i] = describeValue(args[i])
	end
	devtoolsEmitCount += 1
	local text = `{devtoolsEmitCount}|{eventName}|{table.concat(parts, ", ")}`
	_reactivity._untracked(function()
		(el :: Instance):SetAttribute("RivueEmit", text)
	end)
	devtoolsEvent("emit", `{inst.type.__name or "Anonymous"}: {eventName}`, table.concat(parts, ", "))
end

--- Mirrors a component's name, props and state onto its root Instance for the DevTools plugin.
--- Reads refs' raw values, so it never adds dependencies to the render
local function writeDevtools(inst: ComponentInstance, el: Instance, renderMs: number)
	if not devtoolsEditConns[el] then
		devtoolsEditConns[el] = el:GetAttributeChangedSignal("RivueEdit"):Connect(function()
			applyDevtoolsEdit(inst, el)
		end)
		el:SetAttribute("RivueSource", inst.type.__source)
	end
	local props: { string } = {}
	for key, value in _reactivity.toRaw(inst.props) do
		table.insert(props, `{key} = {describeValue(value)}`)
	end
	if not CollectionService:HasTag(el, DEVTOOLS_TAG) then
		CollectionService:AddTag(el, DEVTOOLS_TAG)
	end
	el:SetAttribute("RivueComponent", inst.type.__name or "Anonymous")
	el:SetAttribute("RivueProps", devtoolsText(props))
	writeDevtoolsState(inst, el)
	local renders = ((el:GetAttribute("RivueRenders") :: number?) or 0) + 1
	el:SetAttribute("RivueRenders", renders)
	el:SetAttribute("RivueRenderMs", math.round(renderMs * 100) / 100)
	local triggers = inst._devtoolsTriggers
	inst._devtoolsTriggers = nil
	local trigger = if renders == 1 then "mount" elseif triggers then table.concat(triggers, ", ") else "parent"
	el:SetAttribute("RivueTrigger", trigger)

	local provided: { string } = {}
	if not inst.parent or inst.provides ~= inst.parent.provides then
		for key in next, inst.provides do
			table.insert(provided, tostring(key))
		end
	end
	el:SetAttribute("RivueProvides", devtoolsText(provided))
	local injected: { string } = {}
	for key in (inst._injected or {}) :: { [unknown]: boolean } do
		table.insert(injected, tostring(key))
	end
	el:SetAttribute("RivueInjects", devtoolsText(injected))

	devtoolsEvent("render", inst.type.__name or "Anonymous", trigger, renderMs)
end

local function applyFallthroughAttrs(props: Props?, attrs: Props): Props?
	local merged: Props? = nil
	for key, value in attrs do
		if not RESERVED_PROPS[key] and (props == nil or props[key] == nil) then
			if not merged then
				merged = if props then table.clone(props) else {}
			end
			(merged :: Props)[key] = value
		end
	end
	local parentClass = attrs.class
	if parentClass ~= nil then
		local result: Props = merged or (if props then table.clone(props) else {})
		merged = result
		local own = if props then props.class else nil
		result.class = if own ~= nil then { own, parentClass } else parentClass
	end
	return merged or props
end

local function mountComponent(vnode: RenderVNode, container: Instance, poolOpt: PoolOptions?)
	local inst = componentAPI.createComponentInstance(vnode, currentRenderingInstance, currentAppContext)
	vnode._instance = inst
	inst.container = container
	if inst.type.__isKeepAlive then
		inst._keepAliveRenderer = {
			unmount = function(cached: VNode)
				cached._keepAlive = nil
				unmountVNode(cached, poolOpt)
			end,
		}
	end
	inst:setupComponent()
	inst:runBeforeMount()

	local devtools = inst.appContext.config.devtools == true
	local renderStart = 0

	local function commit(nextTree: VNode?)
		if nextTree then
			if inst.type.inheritAttrs ~= false and type(nextTree.type) == "string" then
				nextTree.props = applyFallthroughAttrs(nextTree.props, inst.attrs)
			end
			local transition = inst.vnode._transition
			if transition and nextTree._transition == nil then
				nextTree._transition = transition
			end
			if inst._transitionHooks then
				nextTree._transitionHooks = inst._transitionHooks
			end
		end

		local prevTree = inst.subTree
		inst.subTree = nextTree
		withRenderingInstance(inst, function()
			patch(prevTree, nextTree, inst.container or container, poolOpt)
		end)

		local el = if nextTree then nextTree.el else nil
		local name = inst.type.__name
		if el and el ~= inst.el and name and nextTree and type(nextTree.type) == "string" then
			local rootProps = nextTree.props
			if rootProps == nil or rootProps.Name == nil then
				el.Name = name
				local touched: { [string]: boolean } = nextTree._touched or {}
				nextTree._touched = touched
				touched.Name = true
			end
		end
		inst.el = el
		if el and devtools then
			local renderMs = (os.clock() - renderStart) * 1000
			_reactivity._untracked(function()
				writeDevtools(inst, el, renderMs)
			end)
		end
	end

	local renderEffect: Effect
	local updateJob = {
		id = inst.uid,
		run = function()
			if not renderEffect.active then
				return
			elseif inst.isDeactivated then
				inst._pendingUpdate = true
				return
			end
			renderEffect.run()
		end,
	}
	renderEffect = _reactivity.effect(function()
		if devtools then
			renderStart = os.clock()
		end
		local render = inst.render
		local profiled = inst.appContext.config.performance == true
		local label = if profiled then `Rivue {inst.type.__name or "Anonymous"}` else ""
		local prevRendering = componentAPI.setRenderingInstance(inst)
		if profiled then
			debug.profilebegin(label .. " render")
		end
		local ok, sub = pcall(function(): unknown
			return if render then render() else nil
		end)
		if profiled then
			debug.profileend()
		end
		componentAPI.setRenderingInstance(prevRendering)

		if not ok then
			inst:handleError(tostring(sub), "render")
			return
		end

		local nextTree = sub :: VNode?
		if type(sub) == "table" and (sub :: any).type == nil and #(sub :: { unknown }) > 0 then
			nextTree = hModule.h(Fragment, nil, sub :: { Child })
		end
		if inst.isMounted then
			local prevTree = inst.subTree
			inst:runBeforeUpdate()
			if profiled then
				debug.profilebegin(label .. " patch")
			end
			local patched, err = pcall(commit :: (VNode?) -> ...unknown, nextTree)
			if profiled then
				debug.profileend()
			end
			if not patched then
				inst.subTree = prevTree
				inst:handleError(tostring(err), "patch")
				return
			end
			inst:runUpdated()
		else
			if profiled then
				debug.profilebegin(label .. " patch")
				local mounted, err = pcall(commit :: (VNode?) -> ...unknown, nextTree)
				debug.profileend()
				if not mounted then
					error(err, 0)
				end
			else
				commit(nextTree)
			end
			inst.isMounted = true
			queuePost(function()
				if inst.isUnmounted then
					return
				end
				inst:runMounted()
				setTemplateRef(vnode.props, vnode._owner, inst.exposed or inst)
				if #inst.activatedCbs > 0 and inst:isInKeepAlive() then
					inst:runActivated()
				end
			end)
		end
	end, {
		lazy = true,
		scheduler = function()
			scheduler.queueUpdate(updateJob)
		end,
		allowRecurse = true,
		onTrack = if #inst.renderTrackedCbs > 0
			then function(event: Types.DebuggerEvent)
				for _, fn in inst.renderTrackedCbs do
					pcall(fn, event)
				end
			end
			else nil,
		onTrigger = if #inst.renderTriggeredCbs > 0 or devtools
			then function(event: Types.DebuggerEvent)
				if devtools then
					recordTrigger(inst, event)
				end
				for _, fn in inst.renderTriggeredCbs do
					pcall(fn, event)
				end
			end
			else nil,
	})

	renderEffect.run()
	inst._renderEffect = renderEffect
end

local function activateComponent(vnode: RenderVNode, container: Instance)
	local inst = vnode._instance :: ComponentInstance
	vnode._kept = nil
	inst.vnode = vnode
	inst.container = container
	componentAPI.updateComponentProps(inst, vnode.props)
	local slotsChanged = componentAPI.updateComponentSlots(inst, vnode.children, vnode.slots)
	for _, el in collectRootEls(vnode, {}) do
		el.Parent = container
	end
	inst.isDeactivated = false

	local renderEffect = inst._renderEffect
	if renderEffect and renderEffect.scheduler and (slotsChanged or inst._pendingUpdate) then
		inst._pendingUpdate = false
		renderEffect.scheduler(renderEffect.run)
	end
	queuePost(function()
		walkComponents(vnode, function(c)
			c:runActivated()
		end)
	end)
end

local function onlyText(children: { Child }): string?
	local only = children[1]
	if #children == 1 and (type(only) == "string" or type(only) == "number") then
		return tostring(only)
	end
	return nil
end

local function trySetOnlyText(el: Instance, className: string, children: { Child }, oldChildren: { Child }): boolean
	if not isTextObject(el, className) then
		return false
	end
	local text = onlyText(children)
	if text then
		(el :: TextLabel).Text = text
		return true
	end
	if onlyText(oldChildren) then
		(el :: TextLabel).Text = ""
	end
	return false
end

--- Compares props, treating a new event handler as equal: it's swapped into the live
--- connection instead, so rows re-rendered with fresh closures skip the prop diff
local function propsEqualSwappingHandlers(oldProps: Props?, newProps: Props?, vnode: RenderVNode): boolean
	if oldProps == newProps then
		return true
	elseif oldProps == nil or newProps == nil then
		return false
	end
	local handlers = vnode._handlers
	local count = 0
	for key, value in newProps do
		count += 1
		local old = oldProps[key]
		if old ~= value and not (key == "__states" and statesEqual(old, value)) then
			if
				handlers
				and handlers[key] ~= nil
				and type(value) == "function"
				and type(old) == "function"
				and string.sub(key, 1, 2) == "on"
			then
				handlers[key] = value
			else
				return false
			end
		end
	end
	for _ in oldProps do
		count -= 1
	end
	return count == 0
end

local function patchElement(oldVNode: RenderVNode, newVNode: RenderVNode, poolOpt: PoolOptions?)
	local el = oldVNode.el
	local className = newVNode.type :: string
	newVNode.el = el
	if not el then
		return
	end

	newVNode._conns = oldVNode._conns or {}
	newVNode._handlers = oldVNode._handlers
	newVNode._dirs = oldVNode._dirs or {}
	newVNode._touched = oldVNode._touched
	newVNode._sugar = oldVNode._sugar
	newVNode._tween = oldVNode._tween
	local bindings = oldVNode._bindings
	if bindings then
		newVNode._bindings = bindings
		bindings[BINDING_VNODE] = newVNode
	end
	local stateRecord = stateRecords[el]
	if stateRecord then
		stateRecord.vnode = newVNode
	end

	local oldProps, newProps = oldVNode.props, newVNode.props
	local memo = if newProps then newProps.memo else nil
	if memo ~= nil and oldProps and memoEqual(oldProps.memo, memo) then
		newVNode.props = oldProps
		newVNode.children = oldVNode.children
		return
	end

	local oldRef = if oldProps then oldProps.ref else nil
	local newRef = if newProps then newProps.ref else nil
	if oldRef ~= newRef then
		setTemplateRef(oldProps, oldVNode._owner, nil)
		setTemplateRef(newProps, newVNode._owner, el)
	end

	local propsChanged = not propsEqualSwappingHandlers(oldProps, newProps, newVNode)
	local oldChildren, newChildren = oldVNode.children, newVNode.children
	local childrenChanged = oldChildren ~= newChildren and (next(oldChildren) ~= nil or next(newChildren) ~= nil)
	if not propsChanged and not childrenChanged then
		if newProps and newProps.onTextChanged ~= nil and newProps.Text ~= nil and className == "TextBox" then
			local box = el :: TextBox
			if box.Text ~= newProps.Text then
				box.Text = newProps.Text
			end
		end
		return
	end

	local function update()
		if propsChanged then
			patchProps(el, oldVNode.props, newVNode.props, newVNode)
		end
		if childrenChanged and not trySetOnlyText(el, className, newVNode.children, oldVNode.children) then
			patchKeyedChildren(oldVNode.children, newVNode.children, el, poolOpt)
			if
				hasLayoutChild(newVNode.children) or (newVNode.props ~= nil and (newVNode.props :: Props).layout ~= nil)
			then
				syncLayoutOrder(newVNode.children)
			end
		end
	end

	if className == "TextBox" then
		local oldText = if oldVNode.props then oldVNode.props.Text else nil
		local textProps = newVNode.props
		local newText = if textProps then textProps.Text else nil
		local controlled = textProps ~= nil and textProps.onTextChanged ~= nil and newText ~= nil
		withPreservedTextState(el, update, controlled or newText ~= oldText)
		if controlled and (el :: TextBox).Text ~= newText then
			(el :: TextBox).Text = newText
		end
	else
		update()
	end

	if propsChanged and ((newProps and newProps.__states ~= nil) or stateRecords[el]) then
		syncStates(newVNode, el)
	end
end

local function firstChildEl(children: { Child }): Instance?
	for _, child in children do
		if type(child) == "table" and child.el then
			return child.el
		end
	end
	return nil
end

local function mountFragment(vnode: RenderVNode, container: Instance, poolOpt: PoolOptions?)
	for i, child in vnode.children do
		if type(child) == "function" then
			local rendered = child()
			vnode.children[i] = rendered :: any
			child = rendered :: any
		end
		if type(child) == "table" then
			patch(nil, child, container, poolOpt)
		end
	end
	vnode.el = firstChildEl(vnode.children)
end

local function patchInner(oldVNode: RenderVNode?, newVNode: RenderVNode?, container: Instance, poolOpt: PoolOptions?)
	if newVNode == nil then
		unmountVNode(oldVNode, poolOpt)
		return
	end

	local newType = newVNode.type
	if type(newType) == "string" then
		local appContext = if currentRenderingInstance then currentRenderingInstance.appContext else currentAppContext
		local registered = if appContext then appContext.components[newType] else nil
		if registered then
			newVNode.type = registered
			newType = registered
		end
	end
	if type(newType) == "string" then
		local props = newVNode.props
		if props and (props.class ~= nil or props.disabled ~= nil) and not newVNode._classApplied then
			newVNode._classApplied = true
			newVNode.props = applyClasses(
				props,
				(newVNode._owner :: ComponentInstance?) or currentRenderingInstance,
				if currentRenderingInstance then currentRenderingInstance.appContext else currentAppContext
			)
		end
	end
	local def = asComponent(newType)
	if not def and type(newType) == "table" and newType ~= Fragment then
		local raw = newType :: any
		if raw.setup or raw.render then
			error("[Rivue] h() got a table with setup/render, wrap it in Rivue.defineComponent({ ... })", 0)
		end
		error("[Rivue] h() got a table that isn't a component, use a ClassName, a component or a function", 0)
	end

	if oldVNode == nil then
		if newType == Fragment then
			mountFragment(newVNode, container, poolOpt)
		elseif def == componentAPI.Teleport then
			mountTeleport(newVNode, container, poolOpt)
		elseif def and newVNode._kept and newVNode._instance then
			activateComponent(newVNode, container)
		elseif def then
			mountComponent(newVNode, container, poolOpt)
		elseif type(newType) == "function" then
			local res = newType(newVNode.props or {})
			newVNode._fnTree = res
			patch(nil, res, container, poolOpt)
			newVNode.el = if res then res.el else nil
		else
			newVNode.el = mountElement(newVNode, container, poolOpt)
		end
		return
	end

	if oldVNode.type ~= newType or oldVNode.key ~= newVNode.key then
		local oldEl = oldVNode.el
		local parent = if oldEl and oldEl.Parent then oldEl.Parent else container
		unmountVNode(oldVNode, poolOpt)
		patch(nil, newVNode, parent, poolOpt)
		return
	end

	if newType == Fragment then
		patchKeyedChildren(oldVNode.children, newVNode.children, container, poolOpt)
		newVNode.el = firstChildEl(newVNode.children)
	elseif def == componentAPI.Teleport then
		patchTeleport(oldVNode, newVNode, container, poolOpt)
	elseif def then
		local inst = oldVNode._instance :: ComponentInstance?
		newVNode._instance = inst
		newVNode._kept = nil
		local oldProps, newProps = oldVNode.props, newVNode.props
		local memo = if newProps then newProps.memo else nil
		if memo ~= nil and oldProps and memoEqual(oldProps.memo, memo) then
			newVNode.props, newVNode.children, newVNode.slots = oldProps, oldVNode.children, oldVNode.slots
			if inst then
				inst.vnode = newVNode
			end
		elseif inst then
			inst.vnode = newVNode
			if not componentAPI.propsUnchanged(def, oldProps, newProps) then
				componentAPI.updateComponentProps(inst, newProps)
			end
			local renderEffect = inst._renderEffect
			if
				componentAPI.updateComponentSlots(inst, newVNode.children, newVNode.slots)
				and renderEffect
				and renderEffect.scheduler
			then
				renderEffect.scheduler(renderEffect.run)
			end
		end
	elseif type(newType) == "function" then
		local res = newType(newVNode.props or {})
		newVNode._fnTree = res
		patch(oldVNode._fnTree, res, container, poolOpt)
		newVNode.el = if res then res.el else nil
	else
		patchElement(oldVNode, newVNode, poolOpt)
	end
end

function patch(oldVNode: RenderVNode?, newVNode: RenderVNode?, container: Instance, poolOpt: PoolOptions?)
	if patching then
		patchInner(oldVNode, newVNode, container, poolOpt)
		return
	end
	patching = true
	local ok, err = pcall(patchInner :: (...any) -> ...unknown, oldVNode, newVNode, container, poolOpt)
	patching = false
	flushPostQueue()
	if not ok then
		error(err, 0)
	end
end

function formatTree(vnode: VNode?): string
	local lines: { string } = {}
	local function walk(node: VNode?, depth: number)
		if node == nil then
			return
		end
		local indent = string.rep("  ", depth)
		local def = asComponent(node.type)
		if def then
			local inst = node._instance :: ComponentInstance?
			local parts: { string } = {}
			if inst then
				for key, value in _reactivity.toRaw(inst.props) do
					table.insert(parts, `{key}={describeValue(value)}`)
				end
			end
			table.sort(parts)
			local suffix = if #parts > 0 then " " .. table.concat(parts, " ") else ""
			if def == componentAPI.Teleport then
				local target = node._teleportTarget
				table.insert(lines, `{indent}<Teleport -> {if target then target:GetFullName() else "nowhere"}>`)
				for _, child in node.children do
					if type(child) == "table" then
						walk(child, depth + 1)
					end
				end
				return
			end
			local state = if inst and inst.isDeactivated then " (cached)" else ""
			table.insert(lines, `{indent}<{def.__name or "Anonymous"}{suffix}>{state}`)
			walk(if inst then inst.subTree else nil, depth + 1)
		elseif node.type == Fragment then
			for _, child in node.children do
				if type(child) == "table" then
					walk(child, depth)
				end
			end
		elseif type(node.type) == "function" then
			walk(node._fnTree, depth)
		else
			local el = node.el
			local key = if node.key ~= nil then ` key={describeValue(node.key)}` else ""
			table.insert(lines, `{indent}{node.type} "{if el then el.Name else "?"}"{key}`)
			for _, child in node.children do
				if type(child) == "table" then
					walk(child, depth + 1)
				end
			end
		end
	end
	walk(vnode, 0)
	return table.concat(lines, "\n")
end

local function createApp(root: VNode | ComponentDef, opts: AppOptions?): App
	local rootVNode: VNode = if asComponent(root) then hModule.h(root :: ComponentDef) else root :: VNode
	local options: AppOptions = opts or {}
	local usePool = options.usePool == true
	local poolOpt: PoolOptions = { usePool = usePool }

	if debugModule.enabled then
		debugModule.log("Renderer", "Creating app", {
			usePool = usePool,
			rootType = if type(rootVNode.type) == "string" then rootVNode.type else "component",
		})
	end

	if usePool then
		local poolConfig: Types.PoolConfig = options.poolConfig or {}
		Pool.configure({
			maxPoolSize = poolConfig.maxPoolSize or 50,
			maxTotalSize = poolConfig.maxTotalSize or 500,
			enableMetrics = poolConfig.enableMetrics ~= false,
			enableDebug = poolConfig.enableDebug or false,
			defaultTTL = poolConfig.defaultTTL,
			enableAutoWarmup = poolConfig.enableAutoWarmup or false,
		})

		local warmupConfig = options.poolWarmup
		if warmupConfig then
			for className, count in warmupConfig do
				Pool.warmup(className, count)
			end
		elseif not poolConfig.enableAutoWarmup then
			Pool.warmup("Frame", 10)
			Pool.warmup("TextLabel", 20)
			Pool.warmup("TextButton", 5)
		end
	end

	local mounted: MountedState = { vnode = nil, container = nil, poolOpt = poolOpt }
	local devtoolsChannel: Instance? = nil
	local appContext: AppContext = { provides = {}, config = { globalProperties = {} }, components = {}, styles = {} }

	local api = { config = appContext.config } :: App

	function api.provide(self: App, key: unknown, value: unknown): App
		appContext.provides[key] = value
		return self
	end

	function api.use(self: App, plugin: Plugin, ...: any): App
		if type(plugin) == "function" then
			plugin(self, ...)
		elseif type(plugin) == "table" and type(plugin.install) == "function" then
			plugin.install(self, ...)
		else
			error("app:use() expects a function or a table with install()", 2)
		end
		return self
	end

	function api.directive(self: App, name: string, hooks: Types.Directive): App
		directives.register(name, hooks)
		return self
	end

	function api.styles(self: App, styles: { [string]: Props }): App
		for name, style in styles do
			appContext.styles[name] = style
		end
		return self
	end

	function api.component(self: App, name: string, def: ComponentDef): App
		if not asComponent(def) then
			error("app:component() expects a component definition", 2)
		end
		appContext.components[name] = def
		return self
	end

	function api.mount(self: App, container: Instance): MountedState
		if typeof(container) ~= "Instance" then
			error("mount() requires Roblox Instance", 2)
		end

		if mounted.vnode then
			self:unmount()
		end

		mounted.container = container
		if appContext.config.devtools and not devtoolsChannel then
			devtoolsChannel = openDevtoolsChannel(container)
		end
		local prevContext = currentAppContext
		currentAppContext = appContext
		local ok, err = pcall(patch :: (...any) -> ...unknown, nil, rootVNode, container, poolOpt)
		currentAppContext = prevContext
		if not ok then
			error(err, 0)
		end
		mounted.vnode = rootVNode

		return mounted
	end

	local unmountCallbacks: { () -> () } = {}
	local ownedGui: ScreenGui? = nil

	function api.onUnmount(self: App, fn: () -> ()): App
		table.insert(unmountCallbacks, fn)
		return self
	end

	function api.runWithContext<T>(_self: App, fn: () -> T): T
		return componentAPI.runWithInjectionContext(appContext, fn)
	end

	function api.printTree(_self: App): string
		local tree = formatTree(mounted.vnode)
		print(tree)
		return tree
	end

	function api.unmount(_self: App)
		if mounted.vnode then
			unmountVNode(mounted.vnode, poolOpt)
			mounted.vnode = nil
			for _, fn in unmountCallbacks do
				local ok, err = pcall(fn :: () -> ...unknown)
				if not ok then
					warn(`[Rivue] app:onUnmount callback failed: {err}`)
				end
			end
		end
		mounted.container = nil
		if devtoolsChannel then
			closeDevtoolsChannel(devtoolsChannel)
			devtoolsChannel = nil
		end
		if ownedGui then
			ownedGui:Destroy()
			ownedGui = nil
		end
	end

	function api.rerender(self: App, newRoot: VNode?): MountedState
		local container = mounted.container or error("no previous container", 2)
		local keep = ownedGui
		ownedGui = nil
		self:unmount()
		ownedGui = keep
		rootVNode = newRoot or rootVNode
		return self:mount(container)
	end

	function api.swapRoot(self: App, newRoot: VNode): MountedState
		local container = mounted.container or error("no previous container", 2)
		local keep = ownedGui
		ownedGui = nil
		self:unmount()
		ownedGui = keep
		rootVNode = newRoot
		return self:mount(container)
	end

	function api.mountToPlayerGui(self: App, player: Player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			error("mountToPlayerGui expects a Player", 2)
		end

		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "AppRoot"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = player:WaitForChild("PlayerGui")
		self:mount(screenGui)
		ownedGui = screenGui
	end

	if usePool then
		function api.getPoolStats(_self: App): unknown
			return Pool.getStatistics()
		end

		function api.validatePoolHealth(_self: App): boolean
			return Pool.validateHealth()
		end
	end

	return api
end

--- Calls an element's current handler for an event prop, as if the event fired. Scripts can't fire
--- engine signals like Activated, so tests use this instead. Updates are batched as usual: call
--- Rivue.nextTick() before checking the result
local function trigger(inst: Instance, key: string, ...: any)
	local handlers = elementHandlers[inst]
	local handler = if handlers then handlers[key] else nil
	if not handler then
		error(`[Rivue] {inst:GetFullName()} has no {key} handler`, 2)
	end
	callHandler(elementOwners[inst], handler, ...)
end

local function hasHandler(inst: Instance, key: string): boolean
	local handlers = elementHandlers[inst]
	return handlers ~= nil and handlers[key] ~= nil
end

return {
	trigger = trigger,
	hasHandler = hasHandler,
	setInteraction = setInteraction,
	createApp = createApp,
	patch = patch,
	formatTree = formatTree,
	unmountVNode = unmountVNode,
	devtoolsEvent = devtoolsEvent,
	devtoolsRoute = devtoolsRoute,
}
