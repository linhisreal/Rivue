--!strict
--!optimize 2
--!native

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
        
        type TransitionConfig = {
            tweenInfo: TweenInfo?,
            info: TweenInfo?,
            enterGoals: { [string]: any }?,
            leaveGoals: { [string]: any }?,
            goals: { [string]: any }?,
            enter: boolean?,
            leave: boolean?
        }
        
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
		- Applied before other props for proper initialization
	
	4. TextBox Preservation:
		- Preserves text, selection, and focus state during updates
		- Prevents input interruption during reactive updates
	
	5. Transitions:
		- Enter/leave animations using TweenService
		- Configurable tween info and goal properties
		- Blocks until transition completes
	
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

local componentAPI = require(script.Parent:WaitForChild("component"))
local _reactivity = require(script.Parent:WaitForChild("reactivity"))
local Pool = require(script.Parent:WaitForChild("pool"))
local _utils = require(script.Parent:WaitForChild("utils"))
local directives = require(script.Parent:WaitForChild("directives"))

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local debugModule = require(script.Parent:WaitForChild("debug"))

local eventAlias: { [string]: { string } } = {
	onClick = { "Activated", "MouseButton1Click" },
	onActivated = { "Activated" },
	onMouseButton1Click = { "MouseButton1Click" },
	onTouched = { "Touched" },
}

-- Event signal cache to reduce reflection overhead
local eventSignalCache: { [string]: { [string]: string? } } = {}

local _isString = function(x)
	return type(x) == "string"
end

local _isFunction = function(x)
	return type(x) == "function"
end

local _isTable = function(x)
	return type(x) == "table"
end

local classPropCache = {}
--- Checks if an Instance class has a specific property (cached)
--- @param inst any -- Instance to check
--- @param prop any -- Property name
--- @return boolean -- True if property exists
local function classHasProp(inst, prop)
	if not inst or not inst.ClassName then
		return false
	end

	local cn = inst.ClassName
	classPropCache[cn] = classPropCache[cn] or {}
	local cache = classPropCache[cn]

	if cache[prop] ~= nil then
		return cache[prop]
	end

	local ok, has = pcall(function()
		return inst[prop] ~= nil
	end)

	cache[prop] = ok and has
	return cache[prop]
end

--- Attempts to get an RBXScriptSignal from an Instance
--- @param inst Instance -- Instance to get signal from
--- @param evName string -- Signal/event name
--- @return RBXScriptSignal? -- Signal if found, nil otherwise
local function tryGetSignal(inst: Instance, evName: string): RBXScriptSignal?
	if (inst :: any)[evName] and typeof((inst :: any)[evName]) == "RBXScriptSignal" then
		return (inst :: any)[evName]
	end

	local ok, signal = pcall(function()
		return inst:GetPropertyChangedSignal(evName)
	end)

	if ok and signal then
		return signal :: RBXScriptSignal
	end

	return nil
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

	-- If we've cached the signal name for this prop on this class, use it directly
	if classCache[propName] then
		local cachedSignalName = classCache[propName]
		if cachedSignalName then
			local signal = tryGetSignal(inst, cachedSignalName)
			if signal then
				return signal:Connect(function(...)
					pcall(handler, ...)
				end)
			end
		end
		-- If cache says nil, we already tried and failed
		return nil
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
		end
	end

	for _, evName in ipairs(names) do
		local signal = tryGetSignal(inst, evName)
		if signal then
			-- Cache the successful signal name
			classCache[propName] = evName
			return signal:Connect(function(...)
				pcall(handler, ...)
			end)
		end
	end

	-- Cache that we couldn't find a signal
	classCache[propName] = nil
	return nil
end

--- Sets a property on an Instance, handling events, directives, and special cases
--- @param inst any -- Instance to set property on
--- @param key any -- Property key
--- @param value any -- Property value
--- @param vnode any -- VNode containing connection/directive state
--- @return
local function setProp(inst, key, value, vnode)
	vnode._conns = vnode._conns or {}
	vnode._dirs = vnode._dirs or {}

	if key == "__directives" and type(value) == "table" then
		for _, d in ipairs(value) do
			local hook = directives.get(d.name)

			if hook and hook.mounted and inst then
				local res = hook.mounted(inst, d.value)
				vnode._dirs[d.name] = res
			end
		end

		return
	end

	if type(key) == "string" and key:sub(1, 2) == "on" and type(value) == "function" then
		-- Optimization: Don't disconnect if handler is identical (this should be handled by caller, but safe to check here?)
		-- Actually, patchProps handles diffing. If we are here, value changed or key is new.

		if vnode._conns[key] and vnode._conns[key].Disconnect then
			pcall(function()
				vnode._conns[key]:Disconnect()
			end)

			vnode._conns[key] = nil
		end

		if key == "onTextChanged" then
			local ok, conn = pcall(function()
				return inst:GetPropertyChangedSignal("Text"):Connect(function()
					pcall(value, inst.Text)
				end)
			end)

			if ok and conn then
				vnode._conns[key] = conn
				return
			end
		end

		local conn = connectEvent(inst, key, value)

		if conn then
			vnode._conns[key] = conn
			return
		end

		if classHasProp(inst, key) and type(inst[key]) == "function" then
			pcall(function()
				inst[key](inst, value)
			end)

			return
		end

		return
	end

	if classHasProp(inst, key) then
		local ok, err = pcall(function()
			inst[key] = value
		end)

		if not ok then
			debugModule.log("Renderer", "Failed to set prop " .. tostring(key) .. ": " .. tostring(err))
		end

		return
	end

	local k2 = key:sub(1, 1):upper() .. key:sub(2)

	if classHasProp(inst, k2) then
		local ok, err = pcall(function()
			inst[k2] = value
		end)

		if not ok then
			debugModule.log("Renderer", "Failed to set prop " .. tostring(k2) .. ": " .. tostring(err))
		end

		return
	end

	if
		(key == "text" or key == "Text") and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox"))
	then
		inst.Text = value
		return
	end

	-- Avoid referencing global _G; use Studio mode warnings instead
	if RunService and RunService:IsStudio() then
		debugModule.log("Renderer", "Unknown prop", { key = key, className = inst.ClassName or "Instance" })
	end
end

--- Clears all event connections and directive state from a VNode
--- @param vnode any -- VNode to clear
--- @return
local function clearVNodeConns(vnode: any)
	if vnode and vnode._conns then
		for k, c in pairs(vnode._conns) do
			if c and c.Disconnect then
				-- Check if still connected before disconnecting
				local ok = pcall(function()
					if c.Connected then
						c:Disconnect()
					end
				end)
				if not ok then
					-- Fallback: try disconnecting anyway
					pcall(function()
						c:Disconnect()
					end)
				end
			end
			-- Explicitly nil each entry
			vnode._conns[k] = nil
		end

		(vnode :: any)._conns = nil
	end

	if vnode and vnode._dirs then
		for name, conn in pairs(vnode._dirs) do
			local hook = directives.get(name)
			if hook and hook.unmounted then
				pcall(function()
					hook.unmounted(vnode.el, conn)
				end)
			end
			-- Explicitly nil each entry
			vnode._dirs[name] = nil
		end

		(vnode :: any)._dirs = nil
	end
end

--- Executes a function while preserving TextBox state (focus, text, selection)
--- @param el Instance -- Element (should be TextBox)
--- @param fn () -> any -- Function to execute
--- @return any -- Result of fn()
local function withPreservedTextState(el: Instance, fn: () -> any): any
	if not el or not el.IsA or not el:IsA("TextBox") then
		return fn()
	end

	local focused = UserInputService:GetFocusedTextBox()
	local text = (el :: any).Text
	local sel
	local result

	pcall(function()
		sel = (el :: any).SelectionStart
	end)

	result = fn()

	pcall(function()
		(el :: any).Text = text

		if sel then
			(el :: any).SelectionStart = sel
		end
	end)

	if focused == el then
		pcall(function()
			(el :: any):CaptureFocus()
		end)
	end

	return result
end

--- Runs a transition animation on an Instance
--- @param inst any -- Instance to animate
--- @param transition any -- Transition config with tweenInfo and goals
--- @param phase any -- Transition phase ('enter' or 'leave')
--- @return
local function runTransition(inst, transition, phase)
	if not transition then
		return
	end

	local info = transition.tweenInfo or transition.info
	local goals

	if phase == "enter" then
		goals = transition.enterGoals or transition.goals
	elseif phase == "leave" then
		goals = transition.leaveGoals or transition.goals
	end

	if not info or not goals then
		return
	end

	local ok, tween = pcall(function()
		return TweenService:Create(inst, info, goals)
	end)

	if not ok or not tween then
		return
	end

	local done = Pool.acquire("BindableEvent") :: BindableEvent
	local conn

	conn = tween.Completed:Connect(function()
		done:Fire()
	end)

	tween:Play()
	done.Event:Wait()
	conn:Disconnect()
	Pool.release(done)
end

--- Mounts a VNode as a new Instance in the DOM
--- @param vnode any -- VNode to mount
--- @param container any -- Parent container Instance
--- @param poolOpt any -- Pool options for instance reuse
--- @return any -- Mounted Instance
local function mountElement(vnode, container, poolOpt)
	local tag = vnode.type
	local propCount = 0
	if vnode.props then
		for _ in pairs(vnode.props) do
			propCount = propCount + 1
		end
	end
	debugModule.log("Renderer", "Mounting element", {
		type = tostring(tag),
		usePool = poolOpt ~= nil and poolOpt.usePool == true,
		propCount = propCount,
		childCount = vnode.children and #vnode.children or 0,
		hasKey = vnode.key ~= nil,
	})
	local inst

	if poolOpt and poolOpt.usePool and type(tag) == "string" then
		inst = Pool.acquire(tag)
	else
		local ok, created = pcall(function()
			return Instance.new(tag)
		end)

		inst = (ok and created) or Instance.new("Frame")
	end

	if vnode.key and inst.SetAttribute then
		pcall(function()
			inst:SetAttribute("__vkey", vnode.key)
		end)
	end

	if inst:IsA("TextBox") and inst.SetAttribute then
		pcall(function()
			inst:SetAttribute("__v_is_textbox", true)
		end)
	end

	if vnode.props and vnode.props.Name then
		pcall(function()
			inst.Name = vnode.props.Name
		end)
	end

	inst.Parent = container
	vnode.el = inst

	-- Handle template ref: if ref prop is provided, assign instance to ref.value
	if vnode.props and vnode.props.ref and type(vnode.props.ref) == "table" and vnode.props.ref._is_ref then
		vnode.props.ref.value = inst
	end

	-- Handle directives before other props
	if vnode.props then
		local vnodeDirectives = (vnode.props :: any).__directives
		if vnodeDirectives and type(vnodeDirectives) == "table" then
			setProp(inst, "__directives", vnodeDirectives, vnode)
		end
	end

	for k, v in pairs(vnode.props or {}) do
		if k ~= "__directives" and k ~= "key" and k ~= "ref" and k ~= "transition" then
			setProp(inst, k, v, vnode)
		end
	end

	if vnode.children then
		for _, child in ipairs(vnode.children) do
			if type(child) == "string" then
				if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
					(inst :: any).Text = child
				else
					local tl = Instance.new("TextLabel")
					tl.Size = UDim2.fromOffset(200, 50)
					tl.Text = child
					tl.Parent = inst
				end
			elseif type(child) == "table" then
				patch(nil, child, inst, poolOpt)
			elseif type(child) == "function" then
				local c = child()
				patch(nil, c, inst, poolOpt)
			end
		end
	end

	-- Handle enter transition
	if vnode.props then
		local transition = (vnode.props :: any).transition
		if transition and type(transition) == "table" and transition.enter then
			pcall(function()
				runTransition(inst, transition, "enter")
			end)
		end
	end

	return inst
end

--- Unmounts a VNode and destroys/pools its Instance
--- @param vnode any -- VNode to unmount
--- @param poolOpt any -- Pool options for instance reuse
--- @return
local function unmountVNode(vnode, poolOpt)
	if vnode == nil then
		return
	end

	local childCount = vnode.children and #vnode.children or 0
	debugModule.log("Renderer", "Unmounting VNode", {
		type = type(vnode.type) == "string" and vnode.type or "component",
		childCount = childCount,
		isComponent = type(vnode.type) == "table" and vnode.type.__is_component == true,
	})

	clearVNodeConns(vnode)

	-- Clear template ref if present
	if vnode.props and vnode.props.ref and type(vnode.props.ref) == "table" and vnode.props.ref._is_ref then
		vnode.props.ref.value = nil
	end

	if type(vnode.type) == "table" and vnode.type.__is_component then
		local inst = vnode._instance

		if inst then
			-- Clear template ref before unmounting
			if vnode.props and vnode.props.ref and type(vnode.props.ref) == "table" and vnode.props.ref._is_ref then
				vnode.props.ref.value = nil
			end

			-- Stop the render effect to prevent further updates
			if (inst :: any)._renderEffect then
				((inst :: any)._renderEffect :: any):stop();
				(inst :: any)._renderEffect = nil
			end

			inst:runBeforeUnmount()
			inst:runUnmounted()

			if inst.subTree then
				unmountVNode(inst.subTree, poolOpt)
			end

			(vnode :: any)._instance = nil
		end
	else
		if vnode.props and vnode.props.transition and vnode.props.transition.leave then
			pcall(function()
				runTransition(vnode.el, vnode.props.transition, "leave")
			end)
		end

		if vnode.children then
			for _, c in ipairs(vnode.children) do
				if type(c) == "table" then
					unmountVNode(c, poolOpt)
				end
			end
		end

		if vnode.el and vnode.el.Destroy then
			if poolOpt and poolOpt.usePool and vnode.el.ClassName and vnode.el.ClassName ~= "ScreenGui" then
				clearVNodeConns(vnode)
				Pool.release(vnode.el)
			else
				pcall(function()
					vnode.el:Destroy()
				end)
			end

			vnode.el = nil
		end
	end
end

--- Finds a child Instance by its key attribute
--- @param parent Instance -- Parent Instance to search in
--- @param key any -- Key value to find
--- @return Instance? -- Found Instance or nil
local function findChildByKey(parent: Instance, key: any): Instance?
	for _, c in ipairs(parent:GetChildren()) do
		local ok, v = pcall(function()
			return c:GetAttribute("__vkey")
		end)

		if ok and v == key then
			return c :: Instance
		end
	end
	return nil
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

--- Renders large lists in parallel using Parallel Luau (task.desynchronize/synchronize)
--- Useful for CPU-intensive rendering operations (1000+ elements)
--- @param items any -- Array of items to render
--- @param renderFn function -- Render function (item, index) -> VNode
--- @param parent Instance -- Parent container
--- @param poolOpt any -- Pool options
--- @param threshold number? -- Minimum items to enable parallel (default: 500)
local function patchChildrenParallel(items: any, renderFn: any, parent: Instance, poolOpt: any, threshold: number?)
	local itemCount = #items
	local minThreshold = threshold or 500

	-- Only use parallel rendering for large lists
	if itemCount < minThreshold then
		-- Use regular synchronous rendering for small lists
		for i, item in ipairs(items) do
			local vnode = renderFn(item, i)
			if vnode then
				patch(nil, vnode, parent, poolOpt)
			end
		end
		return
	end

	-- Parallel rendering for large lists
	-- Split work into chunks to avoid blocking
	local chunkSize = math.ceil(itemCount / 4) -- 4 parallel workers

	for chunkStart = 1, itemCount, chunkSize do
		task.desynchronize() -- Enter parallel mode

		local chunkEnd = math.min(chunkStart + chunkSize - 1, itemCount)
		local vnodes = {}

		-- Build VNodes in parallel (CPU-intensive work)
		for i = chunkStart, chunkEnd do
			local item = items[i]
			local vnode = renderFn(item, i)
			if vnode then
				table.insert(vnodes, vnode)
			end
		end

		task.synchronize() -- Return to main thread

		-- Mount VNodes on main thread (must be synchronous for Roblox API)
		for _, vnode in ipairs(vnodes) do
			patch(nil, vnode, parent, poolOpt)
		end
	end
end

--- Patches keyed children using efficient diffing algorithm
--- @param oldChildren any -- Previous VNode children
--- @param newChildren any -- New VNode children
--- @param parent Instance -- Parent Instance
--- @param poolOpt any -- Pool options
--- @return
local function patchKeyedChildren(oldChildren: any, newChildren: any, parent: Instance, poolOpt: any)
	oldChildren = oldChildren or {}
	newChildren = newChildren or {}

	local oldMap = {}

	for _, oc in ipairs(oldChildren) do
		local k = (type(oc) == "table" and oc.key) or nil

		if k then
			oldMap[k] = oc
		end
	end

	local useLayout = parentHasUILayout(parent)

	for i, nc in ipairs(newChildren) do
		local k = (type(nc) == "table" and nc.key) or nil

		if k then
			local oc = oldMap[k]

			if oc then
				patch(oc, nc, parent, poolOpt)
				oldMap[k] = nil
			else
				local found = findChildByKey(parent, k)

				if found then
					local placeholder = { type = found.ClassName, el = found, props = {}, children = {}, key = k }
					patch(placeholder, nc, parent, poolOpt)
				else
					patch(nil, nc, parent, poolOpt)
				end
			end

			if useLayout and nc.el and nc.el.LayoutOrder ~= i then
				pcall(function()
					nc.el.LayoutOrder = i
				end)
			end
		else
			local oc = oldChildren[i]
			patch(oc, nc, parent, poolOpt)
		end
	end

	for _, v in pairs(oldMap) do
		if v then
			unmountVNode(v, poolOpt)
		end
	end
end

--- Patches properties on an Instance by diffing old and new props
--- @param el any -- Instance to patch
--- @param oldProps any -- Previous props
--- @param newProps any -- New props
--- @param vnode any -- VNode containing state
--- @return
local function patchProps(el, oldProps, newProps, vnode)
	oldProps = oldProps or {}
	newProps = newProps or {}

	-- Handle ref prop changes
	local oldRef = (oldProps :: any).ref
	local newRef = (newProps :: any).ref

	if oldRef and oldRef._is_ref and oldRef ~= newRef then
		-- Clear old ref
		oldRef.value = nil
	end

	if newRef and newRef._is_ref then
		-- Set new ref
		newRef.value = el
	end

	for k, _ in pairs(oldProps) do
		if newProps[k] == nil then
			if type(k) == "string" and k:sub(1, 2) == "on" then
				if vnode._conns and vnode._conns[k] and vnode._conns[k].Disconnect then
					pcall(function()
						vnode._conns[k]:Disconnect()
					end)

					vnode._conns[k] = nil
				end
			else
				if classHasProp(el, k) then
					pcall(function()
						el[k] = nil
					end)
				end
			end
		end
	end

	for k, v in pairs(newProps) do
		-- Only update props that actually changed (event handlers no longer need special treatment)
		if oldProps[k] ~= v and k ~= "key" and k ~= "ref" and k ~= "transition" and k ~= "__directives" then
			setProp(el, k, v, vnode)
		end
	end
end

--- Main patch function that diffs and updates the DOM tree
--- @param oldVNode any -- Previous VNode tree
--- @param newVNode any -- New VNode tree
--- @param container Instance -- Parent container
--- @param poolOpt any -- Pool options
--- @return
function patch(oldVNode: any, newVNode: any, container: Instance, poolOpt: any)
	-- Profile patch operations for performance monitoring
	if _utils.profiler.active then
		local patchType = "update"
		if oldVNode == nil then
			patchType = "mount"
		elseif newVNode == nil then
			patchType = "unmount"
		end
		_utils.profiler:start("patch_" .. patchType)
	end

	if newVNode == nil then
		unmountVNode(oldVNode, poolOpt)
		if _utils.profiler.active then
			_utils.profiler:stop("patch_unmount")
		end
		return
	end
	if oldVNode == nil then
		local nv = newVNode :: any
		if type(nv.type) == "table" and nv.type.__name == "Teleport" then
			local target = nv.props and nv.props.to

			if type(target) == "function" then
				target = target()
			end

			if target and target.Parent ~= nil then
				for _, child in ipairs(nv.children or {}) do
					patch(nil, child, target, poolOpt)
				end
			end
			return
		end

		if type(nv.type) == "table" and nv.type.__is_component then
			local inst = componentAPI.createComponentInstance(nv :: any, nil)
			nv._instance = inst
			inst:setupComponent()
			inst:runBeforeMount()

			-- Wrap render in a reactive effect so it re-runs when dependencies change
			-- Create a deduplicated job queue for this specific component to batch updates
			local pendingRender = false
			local renderEffect = _reactivity.effect(function()
				local ok, sub = pcall(function()
					if inst.render then
						return inst.render()
					end
					return nil
				end)

				if not ok then
					if nv.props and nv.props.fallback then
						patch(nil, nv.props.fallback, container, poolOpt)
					else
						error("Component render error: " .. tostring(sub))
					end
					return
				end

				if type(sub) == "table" and (sub :: any).__async and (sub :: any).promise then
					if nv.props and nv.props.fallback then
						patch(nil, nv.props.fallback, container, poolOpt)
					end

					task.spawn(function()
						local ok2, res = pcall(function()
							return (sub :: any).promise()
						end)

						if ok2 and res then
							local prevTree = inst.subTree
							inst.subTree = res
							task.defer(function()
								if inst.isMounted then
									inst:runBeforeUpdate()
									patch(prevTree, res, container, poolOpt)
									inst:runUpdated()
								else
									patch(nil, res, container, poolOpt)
									inst.el = (res :: any).el
									inst.isMounted = true
									inst:runMounted()
								end
							end)
						else
							-- Handle async component error
							debugModule.log("Renderer", "Async component promise failed", { error = res })

							-- Call onError prop if provided
							if nv.props and nv.props.onError then
								pcall(nv.props.onError, res)
							end

							-- Render fallback if provided, otherwise leave loading state
							if nv.props and nv.props.fallback then
								task.defer(function()
									-- Update fallback to show error state permanently
									inst.subTree = nv.props.fallback
									inst.el = (nv.props.fallback :: any).el
								end)
							end
						end
					end)
				else
					if inst.isMounted then
						-- Component is mounted, this is a re-render
						local prevTree = inst.subTree
						inst.subTree = sub
						inst:runBeforeUpdate()
						local ok2, err2 = pcall(function()
							patch(prevTree, sub, container, poolOpt)
						end)
						if not ok2 then
							debugModule.log("Renderer", "Patch error during re-render", { error = err2 })
							inst.subTree = prevTree -- rollback
							return
						end
						inst.el = (sub :: any).el
						inst:runUpdated()
					else
						-- Initial mount
						inst.subTree = sub
						patch(nil, sub, container, poolOpt)
						inst.el = (sub :: any).el
						inst.isMounted = true
						inst:runMounted()

						-- Handle template ref for component: assign exposed API or instance
						if nv.props and nv.props.ref and type(nv.props.ref) == "table" and nv.props.ref._is_ref then
							if inst.exposed then
								nv.props.ref.value = inst.exposed
							else
								nv.props.ref.value = inst
							end
						end
					end
				end
			end, {
				lazy = true, -- We'll call run() manually for immediate initial execution
				scheduler = function(run)
					-- Deduplicate: only queue if not already pending
					if not pendingRender then
						pendingRender = true
						task.defer(function()
							local ok = pcall(run)
							pendingRender = false
							if not ok then
								debugModule.log("Renderer", "Effect execution error in scheduler")
							end
						end)
					end
				end,
			})

			-- Call run() immediately to execute initial render and capture dependencies
			-- This must be synchronous to properly track reactive dependencies
			renderEffect.run();

			-- Store the effect so it can be stopped on unmount
			(inst :: any)._renderEffect = renderEffect
		elseif type(nv.type) == "function" then
			local res = nv.type(nv.props or {})
			patch(nil, res, container, poolOpt)
			nv.el = (res :: any).el
		else
			local el = mountElement(nv :: any, container, poolOpt)
			nv.el = el
		end
		if _utils.profiler.active then
			_utils.profiler:stop("patch_mount")
		end
		return
	end

	local ov = oldVNode :: any
	local nv = newVNode :: any

	if ov.type ~= nv.type then
		local parent = (ov.el and ov.el.Parent) or container
		unmountVNode(oldVNode, poolOpt)
		patch(nil, newVNode, parent, poolOpt)
		return
	end

	if type(nv.type) == "table" and nv.type.__is_component then
		-- Component updates are handled automatically by the render effect
		-- We only need to update the vnode reference and props
		local inst = ov._instance
		nv._instance = inst
		inst.vnode = nv
		inst.props = nv.props or {}
		return
	elseif type(newVNode.type) == "function" then
		local res = newVNode.type(newVNode.props or {})
		patch(oldVNode, res, container, poolOpt)
		newVNode.el = res.el
		return
	else
		local el = oldVNode.el
		newVNode.el = el

		-- Transfer connection and directive state from old vnode to prevent memory leaks
		-- Without this, setProp creates a new empty _conns table and can't disconnect old handlers
		newVNode._conns = oldVNode._conns or {}
		newVNode._dirs = oldVNode._dirs or {}

		-- Skip patching if props haven't changed (shallow comparison)
		-- This is a critical performance optimization for stable props
		local propsChanged = not _utils.shallowEqual(oldVNode.props, newVNode.props)
		local childrenChanged = oldVNode.children ~= newVNode.children

		if not propsChanged and not childrenChanged then
			debugModule.log("Renderer", "Skipping patch (props and children unchanged)", {
				type = oldVNode.type,
			})
			return
		end

		if el and el.IsA and el:IsA("TextBox") then
			withPreservedTextState(el, function()
				if propsChanged then
					patchProps(el, oldVNode.props, newVNode.props, newVNode)
				end

				if childrenChanged then
					local onlyTextNew = #newVNode.children == 1 and type(newVNode.children[1]) == "string"

					if onlyTextNew and (el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("TextBox")) then
						el.Text = newVNode.children[1]
					else
						patchKeyedChildren(oldVNode.children, newVNode.children, el, poolOpt)
					end
				end
				return nil
			end)
		else
			if propsChanged then
				patchProps(el, oldVNode.props, newVNode.props, newVNode)
			end

			if childrenChanged then
				local onlyTextNew = #newVNode.children == 1 and type(newVNode.children[1]) == "string"

				if onlyTextNew and (el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("TextBox")) then
					el.Text = newVNode.children[1]
				else
					patchKeyedChildren(oldVNode.children, newVNode.children, el, poolOpt)
				end
			end
		end
		if _utils.profiler.active then
			_utils.profiler:stop("patch_update")
		end
		return
	end
end

--- Creates an application instance with mount/unmount API
--- @param rootVNode any -- Root VNode or component
--- @param opts any? -- App options (dev mode, pool options)
--- @return any -- App API with mount/unmount methods
local function createApp(rootVNode: any, opts: any?): any
	local usePool = opts and opts.usePool or false
	debugModule.log("Renderer", "Creating app", {
		usePool = usePool,
		rootType = type(rootVNode.type) == "string" and rootVNode.type or "component",
	})
	opts = opts or {}
	local poolOpt = { usePool = (opts :: any).usePool }

	-- Configure pool if enabled
	if usePool then
		local poolConfig = (opts :: any).poolConfig or {}
		Pool.configure({
			maxPoolSize = poolConfig.maxPoolSize or 50,
			maxTotalSize = poolConfig.maxTotalSize or 500,
			enableMetrics = poolConfig.enableMetrics ~= false,
			enableDebug = poolConfig.enableDebug or false,
			defaultTTL = poolConfig.defaultTTL,
			enableAutoWarmup = poolConfig.enableAutoWarmup or false,
		})

		-- Warmup common UI elements if configured
		local warmupConfig = (opts :: any).poolWarmup
		if warmupConfig then
			for className, count in pairs(warmupConfig) do
				Pool.warmup(className, count)
			end
		elseif not poolConfig.enableAutoWarmup then
			-- Default warmup for common elements
			Pool.warmup("Frame", 10)
			Pool.warmup("TextLabel", 20)
			Pool.warmup("TextButton", 5)
		end

		debugModule.log("Renderer", "Pool configured and warmed up", {
			config = Pool.config,
			statistics = Pool.getStatistics(),
		})
	end

	local mounted: any = { vnode = nil, container = nil, poolOpt = poolOpt }

	local api = {}

	function api:mount(container)
		if not container or not container.IsA then
			error("mount() requires Roblox Instance")
		end

		debugModule.log(
			"Renderer",
			"Mounting app to container",
			{ containerName = container.Name, containerClass = container.ClassName }
		)

		if mounted.vnode then
			self:unmount()
		end

		(mounted :: any).container = container
		patch(nil, rootVNode, container, poolOpt)
		mounted.vnode = rootVNode

		return mounted
	end

	function api:unmount()
		debugModule.log("Renderer", "Unmounting app")
		if mounted.vnode then
			unmountVNode(mounted.vnode, poolOpt)
			mounted.vnode = nil
		end

		mounted.container = nil
	end

	function api:rerender(newRoot)
		self:unmount()
		rootVNode = newRoot or rootVNode
		return self:mount(mounted.container or error("no previous container"))
	end

	function api:swapRoot(newRoot)
		self:unmount()
		rootVNode = newRoot
		return self:mount(mounted.container or error("no previous container"))
	end

	function api:mountToPlayerGui(player)
		if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then
			error("mountToPlayerGui expects a Player")
		end

		local function tryMount()
			local pg = player:WaitForChild("PlayerGui")
			local screenGui = Instance.new("ScreenGui")
			screenGui.Name = "AppRoot"
			screenGui.ResetOnSpawn = false
			screenGui.Parent = pg
			self:mount(screenGui)
		end

		tryMount()

		player.CharacterAdded:Connect(function()
			if mounted.vnode == nil then
				tryMount()
			end
		end)
	end

	-- Expose pool statistics if pooling is enabled
	if usePool then
		function api:getPoolStats()
			return Pool.getStatistics()
		end

		function api:validatePoolHealth()
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
