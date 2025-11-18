--!strict
--!optimize 2
--!native

--[[
	roblox.luau
	===========
	
	Roblox-specific reactive utilities that integrate native Roblox APIs
	with the Rivue's reactivity system.
	
	@module roblox
	
	@author Rivue
	
	@version 1.0.0
	
	Public API:
	-----------
	
        attributeRef(instance: Instance, attributeName: string, defaultValue?: T) -> Ref<T>
            Creates a reactive reference to an Instance attribute that syncs bidirectionally.
            Changes to ref.value update the attribute, attribute changes update ref.value.
            
        useTag(tagName: string, onAdded: (instance: Instance) -> (() -> ())?) -> ()
            Registers callbacks 'for' instances with a CollectionService tag.
            Returns cleanup 'function' from onAdded callback 'for' automatic cleanup.
            Must be called during component setup().
            
        onRenderStepped(callback: (deltaTime: number) -> ()) -> ()
            Registers a callback 'for' RunService.RenderStepped event.
            Auto-disconnects on component unmount. Must be called during setup().
            
        onHeartbeat(callback: (deltaTime: number) -> ()) -> ()
            Registers a callback 'for' RunService.Heartbeat event.
            Auto-disconnects on component unmount. Must be called during setup().
            
        onStepped(callback: (time: number, deltaTime: number) -> ()) -> ()
            Registers a callback 'for' RunService.Stepped event.
            Auto-disconnects on component unmount. Must be called during setup().
	
	Usage Examples:
	---------------
	
        -- Attribute reactivity
        local health = Rivue.attributeRef(character, "Health", 100)
        watch(health, function(newHealth)
            print("Health changed:", newHealth)
        end)
        
        -- CollectionService integration
        Rivue.useTag("Enemy", function(enemy)
            print("Enemy spawned:", enemy.Name)
            return function()
                print("Enemy despawned:", enemy.Name)
            end
        end)
        
        -- RunService hooks
        Rivue.onRenderStepped(function(dt)
            -- Update camera or UI every frame
        end)
	
	Implementation Notes:
	---------------------
	
	- attributeRef creates a two-way binding with GetAttributeChangedSignal
	- useTag automatically handles tag addition/removal during component lifecycle
	- RunService hooks auto-disconnect on component unmount via onUnmounted
	- All utilities require being called during component setup() for proper cleanup
]]

local reactivity = require(script.Parent:WaitForChild("reactivity"))
local componentAPI = require(script.Parent:WaitForChild("component"))
local debugModule = require(script.Parent:WaitForChild("debug"))
local utils = require(script.Parent:WaitForChild("utils"))

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

--- Creates a reactive reference to an Instance attribute with bidirectional sync
--- @param instance Instance -- Instance to watch
--- @param attributeName string -- Name of the attribute
--- @param defaultValue T? -- Default value if attribute doesn't exist
--- @param opts { throttle: number? }? -- Options (throttle in ms for high-frequency updates)
--- @return Ref<T> -- Reactive reference synced with the attribute
local function attributeRef<T>(
	instance: Instance,
	attributeName: string,
	defaultValue: T?,
	opts: { throttle: number? }?
): any
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

	local r = reactivity.ref(initialValue)
	local isUpdatingFromAttribute = false
	local isUpdatingFromRef = false

	-- Sync attribute changes to ref (with optional throttling)
	local updateFromAttribute = function()
		if isUpdatingFromRef then
			return -- Prevent circular update
		end

		local newValue = instance:GetAttribute(attributeName)
		-- Only update if value actually changed
		if r.value ~= newValue then
			isUpdatingFromAttribute = true
			r.value = newValue
			isUpdatingFromAttribute = false
		end
	end

	-- Apply throttling if specified
	if opts and opts.throttle and opts.throttle > 0 then
		updateFromAttribute = utils.throttle(updateFromAttribute, opts.throttle)
	end

	local conn = instance:GetAttributeChangedSignal(attributeName):Connect(updateFromAttribute)

	-- Sync ref changes to attribute
	local stopWatch = reactivity.watch(r, function(newValue)
		if isUpdatingFromAttribute then
			return -- Prevent circular update
		end

		local currentAttr = instance:GetAttribute(attributeName)
		-- Only set attribute if value actually changed to avoid redundant signals
		if currentAttr ~= newValue then
			isUpdatingFromRef = true
			instance:SetAttribute(attributeName, newValue)
			isUpdatingFromRef = false
		end
	end)

	-- Auto-cleanup on component unmount
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance then
		componentAPI.onUnmounted(function()
			conn:Disconnect()
			stopWatch()
		end)
	else
		-- If not in component context, at least provide manual cleanup
		-- Store cleanup functions on the ref for manual cleanup if needed
		(r :: any)._cleanup = function()
			conn:Disconnect()
			stopWatch()
		end
	end

	return r
end

--- Registers callbacks for instances with a CollectionService tag
--- @param tagName string -- Tag name to watch
--- @param onAdded (instance: Instance) -> (() -> ())? -- Callback when instance is tagged (returns optional cleanup)
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

	-- Process existing tagged instances
	for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
		local cleanup = onAdded(instance)
		if cleanup and type(cleanup) == "function" then
			cleanupMap[instance] = cleanup
		end
	end

	-- Auto-cleanup on component unmount
	local currentInstance = componentAPI.getCurrentInstance()
	if currentInstance then
		componentAPI.onUnmounted(function()
			addedConn:Disconnect()
			removedConn:Disconnect()
			for _, cleanup in pairs(cleanupMap) do
				pcall(cleanup)
			end
			table.clear(cleanupMap)
		end)
	end
end

--- Registers a callback for RunService.RenderStepped
--- @param callback (deltaTime: number) -> () -- Function to call each render step
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
--- @param callback (deltaTime: number) -> () -- Function to call each heartbeat
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
--- @param callback (time: number, deltaTime: number) -> () -- Function to call each physics step
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

return {
	attributeRef = attributeRef,
	useTag = useTag,
	onRenderStepped = onRenderStepped,
	onHeartbeat = onHeartbeat,
	onStepped = onStepped,
}
