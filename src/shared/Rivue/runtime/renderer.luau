--!strict
--!optimize 2

--[[
	renderer.luau
    =============

	Virtual DOM renderer with efficient diffing, lifecycle management, and advanced features
	including transitions, directives, keyed children, Teleport, and Suspense.
	
	Type Definitions:
    -----------------

        type VNode = {
            type: string | ComponentDef | ((props: any) -> VNode),
            props: { [string]: any }?,
            children: { VNode | string }?,
            key: any?,
            el: Instance?,
            _instance: ComponentInstance?,
            _conns: { [string]: RBXScriptConnection }?,
            _dirs: { [string]: any }?
        }
	
        type PoolOptions = {
            usePool: boolean?
        }
        
        type TransitionConfig = Types.TransitionConfig
        
        type App = {
            mount: (self: App, container: Instance) -> any,
            unmount: (self: App) -> (),
            rerender: (self: App, newRoot: VNode?) -> any,
            swapRoot: (self: App, newRoot: VNode) -> any,
            mountToPlayerGui: (self: App, player: Player) -> ()
        }
	
	Public API:
    -----------

        createApp(rootVNode: VNode, opts: { usePool: boolean? }?) -> App
            Creates a new application instance with the given root virtual node.
            Options:
            - usePool: Enable instance pooling for performance (default: false)
            
            Returns App object with mount/unmount/rerender capabilities.
        
        patch(oldVNode: VNode?, newVNode: VNode?, container: Instance, poolOpt: PoolOptions?) -> ()
            Core diffing algorithm that reconciles virtual DOM changes with Roblox instances.
            - Mounts new nodes when oldVNode is nil
            - Unmounts nodes when newVNode is nil
            - Updates existing nodes when types match
            - Replaces nodes when types differ
        
        unmountVNode(vnode: VNode?, poolOpt: PoolOptions?) -> ()
            Recursively unmounts a virtual node tree:
            - Disconnects event listeners
            - Runs unmounted lifecycle hooks
            - Cleans up directive connections
            - Returns pooled instances or destroys them
	
	Implementation Features:
    ------------------------

	1. Event Handling:
		- Aliased event names (onClick → Activated/MouseButton1Click)
		- Dynamic event connection with fallback detection
		- Special TextBox handling (onTextChanged via PropertyChangedSignal)
		- Automatic connection cleanup on prop changes
	
	2. Property Patching:
		- Per-property connection replacement strategy
		- Class capability checking with caching
		- Case-insensitive property name matching
		- Special handling for Text, Name, and layout properties
	
	3. Directives:
		- mounted/unmounted lifecycle hooks for custom directives
		- Connection state tracked in vnode._dirs
		- mounted runs once the tree is parented, like onMounted
	
	4. TextBox Preservation:
		- Preserves text, selection, and focus state during updates
		- Prevents input interruption during reactive updates
	
	5. Transitions:
		- Enter/leave animations using TweenService
		- Configurable tween info and goal properties
		- Leave tweens run in the background, the Instance is destroyed when done
	
	6. Instance Pooling:
		- Opt-in per-app via createApp options
		- Reuses instances for better performance
		- Respects pool for release but never pools ScreenGui
	
	7. Keyed Children:
		- Efficiently diffs children using keys
		- Reuses DOM nodes by key matching
		- Handles mixed keyed/unkeyed children
		- Maintains LayoutOrder for UIListLayout compatibility
	
	8. Teleport Support:
		- Renders children to different container
		- Dynamic target resolution via function props
		- Enables portal-like behavior
	
	9. Suspense/Async:
		- Handles async render functions with __async flag
		- Shows fallback during promise resolution
		- Defers mount until data is ready
	
	10. Component Rendering:
		- Setup and render lifecycle
		- Error boundaries via fallback prop
		- State isolation per instance
	
	Usage Example:
    --------------

        -- Create and mount app
        local app = createApp(h("ScreenGui", {}, {
            h("TextLabel", { Text = "Hello!" })
        }), { usePool = true })
        
        app:mount(game.Players.LocalPlayer:WaitForChild("PlayerGui"))
        
        -- Update with new tree
        app:rerender(h("ScreenGui", {}, {
            h("TextLabel", { Text = "Updated!" })
        }))
        
        -- Unmount
        app:unmount()
	
	Performance Notes:
    ------------------
	
	- Event connections are replaced only when handler changes
	- Property cache reduces reflection overhead
	- Keyed children minimize DOM thrashing
	- Instance pooling reduces allocation cost
	- TextBox preservation avoids focus loss
	- pcall wrapping ensures error resilience
	
	Architecture Notes:
    -------------------
	
	The renderer follows a reconciliation algorithm similar to React:
	1. Mount phase: Create DOM from VNode tree
	2. Update phase: Diff old/new VNodes and patch differences
	3. Unmount phase: Clean up resources and destroy instances
	
	Each VNode tracks its corresponding Roblox Instance, event connections,
	and directive state. Component VNodes track their ComponentInstance.
	The diffing algorithm preserves instances when possible and only
	creates/destroys as needed.
]]

-- renderer.luau
-- Renderer with per-prop connection replacement, directives hooks, Teleport, Suspense, keyed children, TextBox preservation, transitions, pool opt-in

local Types = require(script.Parent:WaitForChild("types"))
local componentAPI = require(script.Parent:WaitForChild("component"))
local hModule = require(script.Parent:WaitForChild("h"))
local _reactivity = require(script.Parent:WaitForChild("reactivity"))
local Pool = require(script.Parent:WaitForChild("pool"))
local scheduler = require(script.Parent:WaitForChild("scheduler"))
local _utils = require(script.Parent:WaitForChild("utils"))
local directives = require(script.Parent:WaitForChild("directives"))

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local debugModule = require(script.Parent:WaitForChild("debug"))

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

-- Forward declared, defined below
local patch: (oldVNode: RenderVNode?, newVNode: RenderVNode?, container: Instance, poolOpt: PoolOptions?) -> ()

-- Component currently rendering, used as parent for nested components
local currentRenderingInstance: ComponentInstance? = nil
-- App being mounted, handed to root components
local currentAppContext: AppContext? = nil

-- Work that needs the finished tree parented (mounted hooks, directives, enter tweens).
-- Runs once the outermost patch is done.
local postQueue: { () -> () } = {}
local patching = false

local function queuePost(fn: () -> ())
	table.insert(postQueue, fn)
end

local function flushPostQueue()
	while #postQueue > 0 do
		-- Swapped so callbacks that patch can queue more
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

--- Warns once per message, Studio only
--- @param message string -- Warning text
local function devWarn(message: string)
	if IS_STUDIO and not warnedOnce[message] then
		warnedOnce[message] = true
		warn(`[Rivue] {message}`)
	end
end

--- Converts a number (pixels) or UDim to UDim
--- @param v unknown -- Number or UDim
--- @return UDim -- UDim value
local function toUDim(v: unknown): UDim
	return if type(v) == "number" then UDim.new(0, v) else v :: UDim
end

type SugarSpec = { className: string, apply: (child: Instance, value: any) -> () }

-- Props that manage a UI modifier child: cornerRadius = 8, padding = 12, stroke = Color3, aspectRatio = 1
const SUGAR_PROPS: { [string]: SugarSpec } = table.freeze({
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
				-- { top, right, bottom, left } or { x, y }
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
})

--- Creates, updates or removes (value nil) the modifier child behind a sugar prop
--- @param inst Instance -- GuiObject the prop is on
--- @param key string -- Prop name
--- @param value unknown -- Prop value
--- @param vnode VNode -- Owning vnode
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
	local created = false
	if not child then
		child = Instance.new(spec.className)
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

-- Prop name -> how to connect it on a class (false = no signal)
type SignalTarget = { name: string, isProperty: boolean }
local eventSignalCache: { [string]: { [string]: SignalTarget | false } } = {}

local classPropCache: { [string]: { [string]: boolean } } = {}
--- Checks if an Instance class has a specific property (cached)
--- @param inst any -- Instance to check
--- @param prop any -- Property name
--- @return boolean -- True if property exists
local function classHasProp(inst: Instance, prop: string): boolean
	if not inst or not inst.ClassName then
		return false
	end

	local cn = inst.ClassName
	local cache = classPropCache[cn]
	if not cache then
		cache = {}
		classPropCache[cn] = cache
	end

	local cached = cache[prop]
	if cached ~= nil then
		return cached
	end

	-- Read can succeed with a nil value (e.g. NextSelectionUp)
	local has = pcall(function()
		return (inst :: any)[prop]
	end)

	cache[prop] = has
	return has
end

--- Attempts to get an event, or a property's changed signal, from an Instance
--- @param inst Instance -- Instance to get signal from
--- @param evName string -- Event or property name
--- @return RBXScriptSignal? -- Signal if found, nil otherwise
--- @return boolean -- True when it's a property changed signal
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

--- Connects a handler to a cached signal target
--- @param inst Instance -- Instance
--- @param target SignalTarget -- Event or property
--- @param handler (...any) -> () -- Handler
--- @return RBXScriptConnection? -- Connection
local function connectTarget(inst: Instance, target: SignalTarget, handler: (...any) -> ()): RBXScriptConnection?
	local signal = tryGetSignal(inst, target.name)
	if not signal then
		return nil
	end
	if target.isProperty then
		-- Property changed signals pass nothing, hand the new value over
		local name = target.name
		return signal:Connect(function()
			handler((inst :: any)[name])
		end)
	end
	return signal:Connect(handler)
end

--- Connects an event handler to an Instance event with aliasing support
--- @param inst Instance -- Instance to connect to
--- @param propName string -- Event prop name (e.g., 'onClick')
--- @param handler (...any) -> () -- Event handler function
--- @return RBXScriptConnection? -- Connection if successful, nil otherwise
local function connectEvent(inst: Instance, propName: string, handler: (...any) -> ()): RBXScriptConnection?
	if type(propName) ~= "string" or type(handler) ~= "function" then
		return nil
	end

	local className = inst.ClassName

	-- Check cache first
	if not eventSignalCache[className] then
		eventSignalCache[className] = {}
	end

	local classCache = eventSignalCache[className]

	-- If we've resolved this prop on this class before, use it directly
	local cached = classCache[propName]
	if cached == false then
		-- Already tried and failed
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
			-- onSizeChanged -> Size changed signal
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

	-- Cache that we couldn't find a signal
	classCache[propName] = false
	return nil
end

--- Sets an Instance property by name
--- @param inst Instance -- Target Instance
--- @param prop string -- Property name
--- @param value unknown -- Value to assign
--- @return boolean -- True if the write succeeded
--- @return unknown -- Error when it failed
local function writeProp(inst: Instance, prop: string, value: unknown): (boolean, unknown)
	return pcall(function()
		(inst :: any)[prop] = value
	end)
end

--- Sets a property on an Instance, handling events, directives, and special cases
--- @param inst Instance -- Instance to set property on
--- @param key string -- Property key
--- @param value any -- Property value (heterogeneous by nature: Instance props, handlers, directives)
--- @param vnode RenderVNode -- VNode holding connection/directive state
local function setProp(inst: Instance, key: string, value: any, vnode: RenderVNode)
	local conns = vnode._conns or {}
	local dirs = vnode._dirs or {}
	local touched = vnode._touched or {}
	vnode._conns, vnode._dirs, vnode._touched = conns, dirs, touched

	if key == "__directives" and type(value) == "table" then
		for _, d in value do
			local hook = directives.get(d.name)
			if hook and hook.mounted then
				-- false keeps the name bound so unmounted still runs
				local state = hook.mounted(inst, d.value)
				dirs[d.name] = if state == nil then false else state
			end
		end
		return
	end

	if key:sub(1, 2) == "on" and type(value) == "function" then
		local existing = conns[key]
		if existing then
			existing:Disconnect()
			conns[key] = nil
		end

		if key == "onTextChanged" and (inst:IsA("TextBox") or inst:IsA("TextLabel") or inst:IsA("TextButton")) then
			local textInst = inst :: TextBox
			conns[key] = textInst:GetPropertyChangedSignal("Text"):Connect(function()
				value(textInst.Text)
			end)
			return
		end

		local conn = connectEvent(inst, key, value)
		if conn then
			conns[key] = conn
		end
		return
	end

	if SUGAR_PROPS[key] and inst:IsA("GuiObject") then
		setSugarProp(inst, key, value, vnode)
		return
	end

	if classHasProp(inst, key) then
		local ok, err = writeProp(inst, key, value)
		if ok then
			-- Tracked so the pool can reset it
			touched[key] = true
		else
			debugModule.log("Renderer", `Failed to set prop {key}: {err}`)
		end
		return
	end

	-- Allow camelCase props (size -> Size)
	local pascalKey = key:sub(1, 1):upper() .. key:sub(2)
	if classHasProp(inst, pascalKey) then
		local ok, err = writeProp(inst, pascalKey, value)
		if ok then
			touched[pascalKey] = true
		else
			debugModule.log("Renderer", `Failed to set prop {pascalKey}: {err}`)
		end
		return
	end

	devWarn(`{inst.ClassName} has no property '{key}'`)
end

--- Clears all event connections and directive state from a VNode
--- @param vnode any -- VNode to clear
--- @return
local function clearVNodeConns(vnode: RenderVNode?)
	if not vnode then
		return
	end

	local conns = vnode._conns
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		vnode._conns = nil
	end

	local dirs = vnode._dirs
	local el = vnode.el
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

--- Runs a patch on a TextBox, keeping what the player typed, the cursor and focus
--- @param el Instance -- Element (should be TextBox)
--- @param fn () -> () -- Patch work
--- @param textFromProps boolean -- The patch sets a new Text, so that one wins
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

--- Gets a vnode's transition config (<Transition> or the transition prop)
--- @param vnode RenderVNode -- Element vnode
--- @return TransitionConfig? -- Config, if any
local function getTransition(vnode: RenderVNode): TransitionConfig?
	local t = vnode._transition
	if t then
		return t
	end
	local props = vnode.props
	local p = if props then props.transition else nil
	return if type(p) == "table" then p :: TransitionConfig else nil
end

--- Runs a transition callback and the owning component's onTransition hooks
--- @param vnode RenderVNode -- Transitioning vnode
--- @param name string -- onTransition hook name ("before-enter", "after-leave", ...)
--- @param fn ((el: Instance) -> ())? -- Callback from the config
--- @param el Instance -- Transitioning Instance
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

--- Creates a tween, nil when there's nothing to animate
--- @param el Instance -- Instance to tween
--- @param info TweenInfo? -- Tween info
--- @param goals { [string]: any }? -- Target properties
--- @return Tween? -- Tween (not playing yet)
local function createTween(el: Instance, info: TweenInfo?, goals: { [string]: any }?): Tween?
	if not info or not goals then
		return nil
	end
	local ok, tween = pcall(TweenService.Create, TweenService, el, info, goals)
	return if ok then tween else nil
end

--- Plays the enter tween (queued after mount)
--- @param vnode RenderVNode -- Entering vnode
--- @param el Instance -- Its Instance
--- @param t TransitionConfig -- Transition config
--- @param goals { [string]: any }? -- Values to tween to
local function runEnter(vnode: RenderVNode, el: Instance, t: TransitionConfig, goals: { [string]: any }?)
	-- Left before the flush
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

--- Plays the leave tween, then destroys the Instance. Doesn't block.
--- @param vnode RenderVNode -- Leaving vnode
--- @param el Instance -- Its Instance
--- @param t TransitionConfig -- Transition config
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

--- Points a template ref at a value: a Ref, a function, or a name for useTemplateRef()
--- @param props Props? -- VNode props
--- @param owner unknown -- Component that rendered the vnode (string refs)
--- @param value unknown -- Instance, exposed API, or nil on unmount
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

--- Shallow compares two memo dependency arrays
--- @param a unknown -- Previous deps
--- @param b unknown -- New deps
--- @return boolean -- True if every entry matches
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

--- Returns the component definition if the vnode type is one
--- @param vnodeType unknown -- vnode.type
--- @return ComponentDef? -- The definition when it's a component
local function asComponent(vnodeType: unknown): ComponentDef?
	if type(vnodeType) == "table" and (vnodeType :: ComponentDef).__is_component then
		return vnodeType :: ComponentDef
	end
	return nil
end

-- Props handled by the renderer, not set on the Instance
const RESERVED_PROPS = table.freeze({ __directives = true, key = true, ref = true, transition = true, memo = true })

--- Mounts a VNode as a new Instance in the DOM
--- @param vnode RenderVNode -- Element VNode (type is a ClassName)
--- @param container Instance -- Parent Instance
--- @param poolOpt PoolOptions? -- Pool options for instance reuse
--- @return Instance -- Mounted Instance
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

	local key = vnode.key
	if key ~= nil then
		pcall(inst.SetAttribute, inst, "__vkey", key)
	end

	if inst:IsA("TextBox") then
		inst:SetAttribute("__v_is_textbox", true)
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

	local transition = getTransition(vnode)
	local enterGoals: { [string]: any }? = nil
	if transition and transition.enter then
		runTransitionHooks(vnode, "before-enter", transition.onBeforeEnter, inst)
		enterGoals = transition.enterGoals or transition.goals
		local from: { [string]: any }? = transition.enterFrom or transition.from
		if from then
			if not enterGoals then
				-- Tween back to the values the props just set
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
			-- Store the result so later diffs compare against it
			local rendered = child()
			children[i] = rendered :: any
			child = rendered :: any
		end

		if type(child) == "string" or type(child) == "number" then
			local text = tostring(child)
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
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

	-- Parent last so the engine lays out the finished subtree once
	inst.Parent = container

	-- Directives run once the whole tree is parented
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

--- Calls fn for every component in a rendered subtree, children first
--- @param vnode RenderVNode? -- Subtree root
--- @param fn (inst: ComponentInstance) -> () -- Callback
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

--- Collects the top-level Instances a vnode rendered (skips teleported content)
--- @param vnode RenderVNode? -- Rendered vnode
--- @param out { Instance } -- List to fill
--- @return { Instance } -- out
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

--- Detaches a KeepAlive child instead of unmounting it
--- @param vnode RenderVNode -- Cached component vnode
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

--- Unmounts a VNode and destroys/pools its Instance
--- @param vnode RenderVNode? -- VNode to unmount
--- @param poolOpt PoolOptions? -- Pool options for instance reuse
--- @param doRemove boolean? -- false when an ancestor Instance is destroyed anyway
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
			-- Teleported children live elsewhere, always remove them
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
			-- Stop the render effect to prevent further updates
			local renderEffect = inst._renderEffect
			if renderEffect then
				renderEffect:stop()
				inst._renderEffect = nil
			end

			inst:runBeforeUnmount()
			inst:runUnmounted()

			unmountVNode(inst.subTree, poolOpt, doRemove)
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

	-- Functional component, unmount its rendered tree
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
	local pooled = poolOpt ~= nil and poolOpt.usePool == true and el ~= nil and not el:IsA("ScreenGui")
	local transition = getTransition(vnode)
	local leaving = el ~= nil and doRemove ~= false and transition ~= nil and transition.leave == true

	-- Without the pool, destroying this element takes its descendants with it
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

--- Maps __vkey -> child Instance for a parent
--- @param parent Instance -- Parent Instance to index
--- @return { [any]: Instance } -- Children by their __vkey attribute
local function indexChildrenByKey(parent: Instance): { [unknown]: Instance }
	local byKey = {}
	for _, c in parent:GetChildren() do
		local key = c:GetAttribute("__vkey")
		if key ~= nil then
			byKey[key] = c
		end
	end
	return byKey
end

--- Checks if parent has a UILayout component (affects manual positioning)
--- @param parent Instance? -- Parent Instance to check
--- @return boolean -- True if UILayout found
local function parentHasUILayout(parent: Instance?): boolean
	if not parent then
		return false
	end
	for _, c in ipairs(parent:GetChildren()) do
		if c:IsA("UIListLayout") or c:IsA("UIGridLayout") then
			return true
		end
	end

	return false
end

--- Renders a large list of items into a parent
--- @deprecated Renders synchronously, use hFor() children instead
--- @param items any -- Array of items to render
--- @param renderFn function -- Render function (item, index) -> VNode
--- @param parent Instance -- Parent container
--- @param poolOpt any -- Pool options
--- @param _threshold number? -- Unused, kept for API compatibility
local function patchChildrenParallel<T>(
	items: { T },
	renderFn: (item: T, index: number) -> VNode?,
	parent: Instance,
	poolOpt: PoolOptions?,
	_threshold: number?
)
	for i = 1, #items do
		local vnode = renderFn(items[i], i)
		if vnode then
			patch(nil, vnode, parent, poolOpt)
		end
	end
end

--- Patches keyed children using efficient diffing algorithm
--- @param oldChildren { Child }? -- Previous VNode children
--- @param newChildren { Child }? -- New VNode children
--- @param parent Instance -- Parent Instance
--- @param poolOpt PoolOptions? -- Pool options
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

	local useLayout = parentHasUILayout(parent)

	-- Built only when needed
	local existingByKey: { [unknown]: Instance }? = nil
	local seenKeys: { [unknown]: true }? = if IS_STUDIO then {} else nil

	for i, nc in newList do
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
				local byKey = existingByKey or indexChildrenByKey(parent)
				existingByKey = byKey
				local found = byKey[k]

				if found then
					local placeholder: VNode =
						{ type = found.ClassName, el = found, props = {}, children = {}, key = k, _uid = 0 }
					patch(placeholder, nc, parent, poolOpt)
				else
					patch(nil, nc, parent, poolOpt)
				end
			end

			local el = nc.el
			if useLayout and el and el:IsA("GuiObject") and el.LayoutOrder ~= i then
				el.LayoutOrder = i
			end
		else
			local oc = oldList[i]
			patch(if type(oc) == "table" then oc else nil, nc, parent, poolOpt)
		end
	end

	for _, v in oldMap do
		unmountVNode(v, poolOpt)
	end

	-- Unmount leftover unkeyed children
	for i = #newList + 1, #oldList do
		local oc = oldList[i]
		if type(oc) == "table" and oc.key == nil then
			unmountVNode(oc, poolOpt)
		end
	end
end

type DirectiveBinding = { name: string, value: unknown }

--- Diffs directive bindings and calls mounted/updated/unmounted
--- @param el Instance -- Element the directives are bound to
--- @param oldBindings { DirectiveBinding }? -- Previous __directives
--- @param newBindings { DirectiveBinding }? -- New __directives
--- @param vnode RenderVNode -- VNode holding directive state
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

	-- Hooks can return nil, so check old bindings instead
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

--- Patches properties on an Instance by diffing old and new props
--- @param el Instance -- Instance to patch
--- @param oldPropsIn Props? -- Previous props
--- @param newPropsIn Props? -- New props
--- @param vnode RenderVNode -- VNode containing state
local function patchProps(el: Instance, oldPropsIn: Props?, newPropsIn: Props?, vnode: RenderVNode)
	local oldProps: Props = oldPropsIn or {}
	local newProps: Props = newPropsIn or {}

	local removedProps: { [string]: boolean }? = nil
	for k in oldProps do
		if newProps[k] ~= nil or RESERVED_PROPS[k] then
			continue
		end
		if k:sub(1, 2) == "on" then
			local conns = vnode._conns
			local conn = if conns then conns[k] else nil
			if conns and conn then
				conn:Disconnect()
				conns[k] = nil
			end
		elseif SUGAR_PROPS[k] and vnode._sugar then
			setSugarProp(el, k, nil, vnode)
		elseif classHasProp(el, k) then
			-- Most properties can't be nil, reset to default instead
			local removed = removedProps or {}
			removedProps = removed
			removed[k] = true
		end
	end
	if removedProps then
		Pool.restoreDefaults(el, removedProps)
	end

	for k, v in newProps do
		-- Only update props that actually changed
		if oldProps[k] ~= v and not RESERVED_PROPS[k] then
			setProp(el, k, v, vnode)
		end
	end

	if oldProps.__directives ~= nil or newProps.__directives ~= nil then
		patchDirectives(el, oldProps.__directives, newProps.__directives, vnode)
	end
end

--- Runs fn with inst as the parent for nested components
--- @param inst ComponentInstance -- Component whose subtree is being patched
--- @param fn () -> () -- Patch work
local function withRenderingInstance(inst: ComponentInstance, fn: () -> ())
	local prev = currentRenderingInstance
	currentRenderingInstance = inst
	local ok, err = pcall(fn :: () -> ...unknown)
	currentRenderingInstance = prev
	if not ok then
		error(err, 0)
	end
end

type AsyncRenderResult = { __async: true, promise: () -> VNode? }

--- Resolves where a Teleport renders: props.to, or in place when props.disabled
--- @param vnode RenderVNode -- Teleport vnode
--- @param container Instance -- Where the Teleport itself sits
--- @return Instance? -- Target, nil if props.to isn't a parented Instance
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

--- Renders Teleport children into its target
--- @param vnode RenderVNode -- Teleport vnode
--- @param container Instance -- Where the Teleport itself sits
--- @param poolOpt PoolOptions? -- Pool options
local function mountTeleport(vnode: RenderVNode, container: Instance, poolOpt: PoolOptions?)
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

--- Patches Teleport children, remounting them if the target changed
--- @param oldVNode RenderVNode -- Mounted Teleport vnode
--- @param newVNode RenderVNode -- Next Teleport vnode
--- @param container Instance -- Where the Teleport itself sits
--- @param poolOpt PoolOptions? -- Pool options
local function patchTeleport(oldVNode: RenderVNode, newVNode: RenderVNode, container: Instance, poolOpt: PoolOptions?)
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

--- Merges a component's undeclared props onto its root element (inheritAttrs)
--- @param props Props? -- Root element props
--- @param attrs Props -- Component attrs
--- @return Props? -- Merged props (root's own props win)
local function applyFallthroughAttrs(props: Props?, attrs: Props): Props?
	local merged: Props? = nil
	-- Iterates the reactive attrs inside the render effect, so changes are tracked
	for key, value in attrs do
		if not RESERVED_PROPS[key] and (props == nil or props[key] == nil) then
			if not merged then
				merged = if props then table.clone(props) else {}
			end
			(merged :: Props)[key] = value
		end
	end
	return merged or props
end

--- Mounts a component and wraps its render in an effect
--- @param vnode RenderVNode -- Component vnode
--- @param container Instance -- Parent Instance
--- @param poolOpt PoolOptions? -- Pool options
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

	local props: Props = vnode.props or {}

	local function commit(nextTree: VNode?)
		if nextTree then
			if inst.type.inheritAttrs ~= false and type(nextTree.type) == "string" then
				nextTree.props = applyFallthroughAttrs(nextTree.props, inst.attrs)
			end
			-- <Transition> around a component animates its root
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
		inst.el = if nextTree then nextTree.el else nil
	end

	local function renderAsync(result: AsyncRenderResult)
		if props.fallback then
			patch(nil, props.fallback, container, poolOpt)
		end

		task.spawn(function()
			local ok, res = pcall(result.promise)
			if ok and res then
				task.defer(function()
					if inst.isMounted then
						inst:runBeforeUpdate()
						commit(res)
						inst:runUpdated()
					else
						commit(res)
						inst:runMounted()
					end
				end)
				return
			end

			debugModule.log("Renderer", "Async component promise failed", { error = res })
			local onError = props.onError
			if type(onError) == "function" then
				pcall(onError, res)
			end
			-- Keep the fallback as the error state
			local fallback = props.fallback
			if fallback then
				task.defer(function()
					inst.subTree = fallback
					inst.el = fallback.el
				end)
			end
		end)
	end

	local renderEffect: Effect
	local updateJob = {
		id = inst.uid,
		run = function()
			-- Skip if the component was unmounted after this update was queued
			if not renderEffect.active then
				return
			elseif inst.isDeactivated then
				-- Cached by KeepAlive, render when it comes back
				inst._pendingUpdate = true
				return
			end
			renderEffect.run()
		end,
	}
	renderEffect = _reactivity.effect(function()
		local render = inst.render
		local prevRendering = componentAPI.setRenderingInstance(inst)
		local ok, sub = pcall(function(): unknown
			return if render then render() else nil
		end)
		componentAPI.setRenderingInstance(prevRendering)

		if not ok then
			if props.fallback then
				patch(nil, props.fallback, container, poolOpt)
			else
				inst:handleError(tostring(sub), "render")
			end
			return
		end

		if type(sub) == "table" and (sub :: AsyncRenderResult).__async and (sub :: AsyncRenderResult).promise then
			renderAsync(sub :: AsyncRenderResult)
			return
		end

		local nextTree = sub :: VNode?
		-- Multiple root nodes: render returned an array
		if type(sub) == "table" and (sub :: any).type == nil and #(sub :: { unknown }) > 0 then
			nextTree = hModule.h(Fragment, nil, sub :: { Child })
		end
		if inst.isMounted then
			-- Re-render
			local prevTree = inst.subTree
			inst:runBeforeUpdate()
			local patched, err = pcall(commit :: (VNode?) -> ...unknown, nextTree)
			if not patched then
				inst.subTree = prevTree -- rollback
				inst:handleError(tostring(err), "patch")
				return
			end
			inst:runUpdated()
		else
			-- Initial mount, hooks run once the whole tree is parented
			commit(nextTree)
			inst.isMounted = true
			queuePost(function()
				if inst.isUnmounted then
					return
				end
				inst:runMounted()
				-- Template ref gets the exposed API or the instance
				setTemplateRef(vnode.props, vnode._owner, inst.exposed or inst)
				if #inst.activatedCbs > 0 and inst:isInKeepAlive() then
					inst:runActivated()
				end
			end)
		end
	end, {
		lazy = true,
		scheduler = function()
			-- Batched with other components, parents first
			scheduler.queueUpdate(updateJob)
		end,
	})

	-- First render now so dependencies are tracked
	renderEffect.run()
	inst._renderEffect = renderEffect
end

--- Puts a KeepAlive-cached component back
--- @param vnode RenderVNode -- New vnode carrying the cached instance
--- @param container Instance -- Parent Instance
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

--- Sets Text when the only child is a string
--- @param el Instance -- Element
--- @param children { Child } -- New children
--- @return boolean -- True if handled as text
local function trySetOnlyText(el: Instance, children: { Child }): boolean
	local only = children[1]
	if #children ~= 1 or type(only) ~= "string" then
		return false
	end
	if el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("TextBox") then
		(el :: TextLabel).Text = only
		return true
	end
	return false
end

--- Patches an element in place
--- @param oldVNode RenderVNode -- Mounted vnode
--- @param newVNode RenderVNode -- Next vnode
--- @param poolOpt PoolOptions? -- Pool options
local function patchElement(oldVNode: RenderVNode, newVNode: RenderVNode, poolOpt: PoolOptions?)
	local el = oldVNode.el
	newVNode.el = el
	if not el then
		return
	end

	-- Transfer state so old handlers can still be disconnected
	newVNode._conns = oldVNode._conns or {}
	newVNode._dirs = oldVNode._dirs or {}
	newVNode._touched = oldVNode._touched
	newVNode._sugar = oldVNode._sugar
	newVNode._tween = oldVNode._tween

	local oldProps, newProps = oldVNode.props, newVNode.props
	local memo = if newProps then newProps.memo else nil
	if memo ~= nil and oldProps and memoEqual(oldProps.memo, memo) then
		-- Same memo deps, keep the mounted subtree as is
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

	local propsChanged = not _utils.shallowEqual(oldVNode.props, newVNode.props)
	local childrenChanged = oldVNode.children ~= newVNode.children
	if not propsChanged and not childrenChanged then
		return
	end

	local function update()
		if propsChanged then
			patchProps(el, oldVNode.props, newVNode.props, newVNode)
		end
		if childrenChanged and not trySetOnlyText(el, newVNode.children) then
			patchKeyedChildren(oldVNode.children, newVNode.children, el, poolOpt)
		end
	end

	if el:IsA("TextBox") then
		local oldText = if oldVNode.props then oldVNode.props.Text else nil
		local newText = if newVNode.props then newVNode.props.Text else nil
		withPreservedTextState(el, update, newText ~= oldText)
	else
		update()
	end
end

--- Returns the Instance of the first mounted child
--- @param children { Child } -- Fragment children
--- @return Instance? -- First child's Instance
local function firstChildEl(children: { Child }): Instance?
	for _, child in children do
		if type(child) == "table" and child.el then
			return child.el
		end
	end
	return nil
end

--- Mounts fragment children straight into the container
--- @param vnode RenderVNode -- Fragment vnode
--- @param container Instance -- Parent Instance
--- @param poolOpt PoolOptions? -- Pool options
local function mountFragment(vnode: RenderVNode, container: Instance, poolOpt: PoolOptions?)
	for i, child in vnode.children do
		if type(child) == "function" then
			-- Store the result so later diffs compare against it
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
		-- Components registered with app:component()
		local appContext = if currentRenderingInstance then currentRenderingInstance.appContext else currentAppContext
		local registered = if appContext then appContext.components[newType] else nil
		if registered then
			newVNode.type = registered
			newType = registered
		end
	end
	local def = asComponent(newType)

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

	-- Different type or key, replace instead of patching
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
		-- The child's render effect handles re-rendering
		local inst = oldVNode._instance :: ComponentInstance?
		newVNode._instance = inst
		newVNode._kept = nil
		local oldProps, newProps = oldVNode.props, newVNode.props
		local memo = if newProps then newProps.memo else nil
		if memo ~= nil and oldProps and memoEqual(oldProps.memo, memo) then
			-- Same memo deps, skip the child's props and slots
			newVNode.props, newVNode.children, newVNode.slots = oldProps, oldVNode.children, oldVNode.slots
			if inst then
				inst.vnode = newVNode
			end
		elseif inst then
			inst.vnode = newVNode
			componentAPI.updateComponentProps(inst, newVNode.props)
			-- Slots aren't reactive, so queue the child's re-render ourselves
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
		-- Diff the previous output against the new one
		local res = newType(newVNode.props or {})
		newVNode._fnTree = res
		patch(oldVNode._fnTree, res, container, poolOpt)
		newVNode.el = if res then res.el else nil
	else
		patchElement(oldVNode, newVNode, poolOpt)
	end
end

--- Main patch function that diffs and updates the DOM tree
--- @param oldVNode RenderVNode? -- Previous VNode tree (nil = mount)
--- @param newVNode RenderVNode? -- New VNode tree (nil = unmount)
--- @param container Instance -- Parent container
--- @param poolOpt PoolOptions? -- Pool options
function patch(oldVNode: RenderVNode?, newVNode: RenderVNode?, container: Instance, poolOpt: PoolOptions?)
	if patching then
		patchInner(oldVNode, newVNode, container, poolOpt)
		return
	end
	-- Outermost patch, run mounted hooks and friends once it's done
	patching = true
	local ok, err = pcall(patchInner :: (...any) -> ...unknown, oldVNode, newVNode, container, poolOpt)
	patching = false
	flushPostQueue()
	if not ok then
		error(err, 0)
	end
end

--- Creates an application instance with mount/unmount API
--- @param rootVNode VNode -- Root VNode or component
--- @param opts AppOptions? -- App options (pooling)
--- @return App -- App API with mount/unmount methods
local function createApp(rootVNode: VNode, opts: AppOptions?): App
	local options: AppOptions = opts or {}
	local usePool = options.usePool == true
	local poolOpt: PoolOptions = { usePool = usePool }

	if debugModule.enabled then
		debugModule.log("Renderer", "Creating app", {
			usePool = usePool,
			rootType = if type(rootVNode.type) == "string" then rootVNode.type else "component",
		})
	end

	-- Configure pool if enabled
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

		-- Warmup common UI elements if configured
		local warmupConfig = options.poolWarmup
		if warmupConfig then
			for className, count in warmupConfig do
				Pool.warmup(className, count)
			end
		elseif not poolConfig.enableAutoWarmup then
			-- Default warmup for common elements
			Pool.warmup("Frame", 10)
			Pool.warmup("TextLabel", 20)
			Pool.warmup("TextButton", 5)
		end
	end

	local mounted: MountedState = { vnode = nil, container = nil, poolOpt = poolOpt }
	local appContext: AppContext = { provides = {}, config = { globalProperties = {} }, components = {} }

	local api = { config = appContext.config } :: App

	--- Provides a value to every component in the app
	function api.provide(self: App, key: unknown, value: unknown): App
		appContext.provides[key] = value
		return self
	end

	--- Installs a plugin: a function(app, ...) or a table with install(app, ...)
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

	--- Registers a directive (directives are global, this is for plugin convenience)
	function api.directive(self: App, name: string, hooks: Types.Directive): App
		directives.register(name, hooks)
		return self
	end

	--- Registers a component so h("Name") renders it anywhere in this app
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

	function api.unmount(_self: App)
		if mounted.vnode then
			unmountVNode(mounted.vnode, poolOpt)
			mounted.vnode = nil
		end
		mounted.container = nil
	end

	function api.rerender(self: App, newRoot: VNode?): MountedState
		-- unmount() clears mounted.container
		local container = mounted.container or error("no previous container", 2)
		self:unmount()
		rootVNode = newRoot or rootVNode
		return self:mount(container)
	end

	function api.swapRoot(self: App, newRoot: VNode): MountedState
		local container = mounted.container or error("no previous container", 2)
		self:unmount()
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
	end

	-- Expose pool statistics if pooling is enabled
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

return {
	createApp = createApp,
	patch = patch,
	unmountVNode = unmountVNode,
	patchChildrenParallel = patchChildrenParallel,
}
