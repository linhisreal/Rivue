--!strict
--!optimize 2
--!native

--[[
	builtins.luau
	=============
	
	Built-in components: Suspense, KeepAlive, and async component loader.
	Provides Vue 3-compatible async handling and component caching.
	
	@module builtins
	@author Rivue
	@version 1.0.0
]]

local componentModule = require(script.Parent:WaitForChild("component"))
local hModule = require(script.Parent:WaitForChild("h"))
local reactivity = require(script.Parent:WaitForChild("reactivity"))

local h = hModule.h
local ref = reactivity.ref

type VNode = any
type ComponentDef = any

local builtins = {}

--[=[
	Suspense Component
	==================
	
	Handles async component loading with fallback UI.
	Tracks pending async operations and shows loading/error states.
	
	Props:
		fallback: VNode?  -- UI to show while loading
		timeout: number?  -- Timeout in milliseconds
	
	Usage:
		h(Rivue.Suspense, {
			fallback = h("TextLabel", { Text = "Loading..." })
		}, {
			h(AsyncComponent)
		})
]=]
builtins.Suspense = nil :: any  -- Forward declaration

local function createSuspense()
	return {
		__is_component = true,
		__name = "Suspense",
		props = {
			fallback = { type = "table" },
			timeout = { type = "number", default = 5000 }
		},
		setup = function(props: any, context: any)
			local isLoading = ref(true)
			local error = ref(nil :: string?)
			local hasTimedOut = ref(false)
			local pendingCount = ref(0)
			
			-- Provide suspense context to children
			context.provide("suspense", {
				register = function()
					pendingCount.value = pendingCount.value + 1
					isLoading.value = true
				end,
				resolve = function()
					pendingCount.value = math.max(0, pendingCount.value - 1)
					if pendingCount.value == 0 then
						isLoading.value = false
					end
				end,
				reject = function(err: string)
					error.value = err
					isLoading.value = false
				end
			})
			
			-- Setup timeout
			if props.timeout and props.timeout > 0 then
				task.delay(props.timeout / 1000, function()
					if isLoading.value then
						hasTimedOut.value = true
						error.value = "Timeout: Component took too long to load"
					end
				end)
			end
			
			-- Cleanup on unmount
			componentModule.onUnmounted(function()
				pendingCount.value = 0
				isLoading.value = false
			end)
			
			return function()
				-- Error state
				if error.value then
					return h("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1
					}, {
						h("TextLabel", {
							Size = UDim2.fromScale(1, 1),
							Text = "Error: " .. tostring(error.value),
							TextColor3 = Color3.fromRGB(255, 100, 100),
							BackgroundTransparency = 1,
							TextWrapped = true
						})
					})
				end
				
				-- Loading state
				if isLoading.value then
					return props.fallback or h("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1
					}, {
						h("TextLabel", {
							Size = UDim2.fromScale(1, 1),
							Text = "Loading...",
							TextColor3 = Color3.fromRGB(200, 200, 200),
							BackgroundTransparency = 1
						})
					})
				end
				
				-- Loaded state - render children
				return h("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1
				}, context.slots)
			end
		end
	}
end

builtins.Suspense = createSuspense()

--[=[
	KeepAlive Component
	===================
	
	Caches component instances to preserve state when toggling visibility.
	Implements LRU cache with configurable size limits.
	
	Props:
		include: { string }?  -- Component names to cache
		exclude: { string }?  -- Component names NOT to cache
		max: number?          -- Maximum cached instances
	
	Usage:
		h(Rivue.KeepAlive, { max = 10 }, {
			currentTab.value == "tab1" and h(Tab1) or h(Tab2)
		})
]=]
builtins.KeepAlive = nil :: any

local function createKeepAlive()
	return {
		__is_component = true,
		__name = "KeepAlive",
		props = {
			include = { type = "table" },
			exclude = { type = "table" },
			max = { type = "number", default = 10 }
		},
		setup = function(props: any, context: any)
			local cache = ref({} :: { [string]: { vnode: VNode, instance: any } })
			local keys = ref({} :: { string })
			
			local shouldCache = function(name: string): boolean
				if props.include then
					local found = false
					for _, n in ipairs(props.include) do
						if n == name then
							found = true
							break
						end
					end
					if not found then return false end
				end
				
				if props.exclude then
					for _, n in ipairs(props.exclude) do
						if n == name then
							return false
						end
					end
				end
				
				return true
			end
			
			local pruneCache = function()
				if props.max and #keys.value > props.max then
					local oldest = table.remove(keys.value, 1)
					if oldest then
						local cached = cache.value[oldest]
						if cached and cached.instance then
							-- Unmount oldest instance
							pcall(function()
								if cached.instance.runUnmounted then
									cached.instance:runUnmounted()
								end
							end)
						end
						cache.value[oldest] = nil
					end
				end
			end
			
			-- Cleanup all cached instances on unmount
			componentModule.onUnmounted(function()
				for _, cached in pairs(cache.value) do
					if cached.instance then
						pcall(function()
							if cached.instance.runUnmounted then
								cached.instance:runUnmounted()
							end
						end)
					end
				end
				cache.value = {}
				keys.value = {}
			end)
			
			return function()
				local slots = context.slots
				if not slots or #slots == 0 then
					return nil
				end
				
				local child = slots[1]
				if not child or not child.type then
					return child
				end
				
				local name = (child.type :: any).__name or "anonymous"
				
				if shouldCache(name) then
					if cache.value[name] then
						-- Return cached instance (move to end for LRU)
						local index = table.find(keys.value, name)
						if index then
							table.remove(keys.value, index)
						end
						table.insert(keys.value, name)
						
						-- Restore cached vnode but update props
						local cached = cache.value[name]
						if child.props then
							cached.vnode.props = child.props
						end
						
						return cached.vnode
					else
						-- Cache new instance
						cache.value[name] = {
							vnode = child,
							instance = (child :: any)._instance
						}
						table.insert(keys.value, name)
						pruneCache()
						
						return child
					end
				end
				
				-- Don't cache this component
				return child
			end
		end
	}
end

builtins.KeepAlive = createKeepAlive()

--[=[
	defineAsyncComponent
	====================
	
	Creates an async component that loads lazily with loading/error states.
	
	Parameters:
		loader: () -> ComponentDef  -- Async function that returns component
		options: {
			loadingComponent: VNode?,
			errorComponent: VNode?,
			delay: number?,      -- Delay before showing loading (ms)
			timeout: number?     -- Timeout for loading (ms)
		}?
	
	Usage:
		local AsyncComponent = Rivue.defineAsyncComponent(function()
			task.wait(2)  -- Simulate async loading
			return MyComponent
		end, {
			loadingComponent = h("TextLabel", { Text = "Loading..." }),
			errorComponent = h("TextLabel", { Text = "Failed!" }),
			delay = 200,
			timeout = 5000
		})
]=]
function builtins.defineAsyncComponent(loader: () -> ComponentDef, options: any?): ComponentDef
	options = options or {}
	
	return {
		__is_component = true,
		__name = "AsyncComponent",
		setup = function(props: any, context: any)
			local component = ref(nil :: ComponentDef?)
			local loading = ref(false)
			local error = ref(nil :: string?)
			local showLoading = ref(false)
			
			-- Get suspense context if available
			local suspense = context.inject("suspense")
			
			-- Delay before showing loading component
			local delayTimer
			if options.delay and options.delay > 0 then
				delayTimer = task.delay(options.delay / 1000, function()
					if loading.value then
						showLoading.value = true
					end
				end)
			else
				showLoading.value = true
			end
			
			-- Timeout for loading
			local timeoutTimer
			if options.timeout and options.timeout > 0 then
				timeoutTimer = task.delay(options.timeout / 1000, function()
					if loading.value then
						error.value = "Component load timeout"
						loading.value = false
						if suspense then
							suspense.reject(error.value)
						end
					end
				end)
			end
			
			-- Register with suspense
			if suspense then
				suspense.register()
			end
			
			-- Start loading
			loading.value = true
			task.spawn(function()
				local success, result = pcall(loader)
				
				if success then
					component.value = result
					loading.value = false
					showLoading.value = false
					
					if suspense then
						suspense.resolve()
					end
				else
					error.value = tostring(result)
					loading.value = false
					showLoading.value = false
					
					if suspense then
						suspense.reject(error.value)
					end
				end
				
				-- Cancel timers
				if delayTimer then
					task.cancel(delayTimer)
				end
				if timeoutTimer then
					task.cancel(timeoutTimer)
				end
			end)
			
			-- Cleanup on unmount
			componentModule.onUnmounted(function()
				if delayTimer then
					task.cancel(delayTimer)
				end
				if timeoutTimer then
					task.cancel(timeoutTimer)
				end
			end)
			
			return function()
				-- Error state
				if error.value then
					if options.errorComponent then
						return options.errorComponent
					end
					return h("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						Text = "Failed to load component",
						TextColor3 = Color3.fromRGB(255, 100, 100),
						BackgroundTransparency = 1
					})
				end
				
				-- Loading state
				if loading.value and showLoading.value then
					if options.loadingComponent then
						return options.loadingComponent
					end
					return h("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						Text = "Loading...",
						TextColor3 = Color3.fromRGB(200, 200, 200),
						BackgroundTransparency = 1
					})
				end
				
				-- Loaded state
				if component.value then
					return h(component.value, props)
				end
				
				-- Initial state (before delay)
				return nil
			end
		end
	}
end

return builtins
