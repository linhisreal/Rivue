--!strict
--!optimize 2

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
local shallowRef = reactivity.shallowRef

local Types = require(script.Parent:WaitForChild("types"))

type VNode = Types.VNode
type ComponentDef = Types.ComponentDef
type Props = Types.Props
type SetupContext = Types.SetupContext
type AsyncComponentOptions = Types.AsyncComponentOptions
type SuspenseContext = Types.SuspenseContext

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
builtins.Suspense = nil :: ComponentDef? -- Forward declaration

local function createSuspense(): ComponentDef
	return {
		__is_component = true :: true,
		__name = "Suspense",
		props = {
			fallback = { type = "table" :: "table" },
			timeout = { type = "number" :: "number", default = 5000 },
		},
		setup = function(props: Props, context: SetupContext)
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
				end,
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
						BackgroundTransparency = 1,
					}, {
						h("TextLabel", {
							Size = UDim2.fromScale(1, 1),
							Text = "Error: " .. tostring(error.value),
							TextColor3 = Color3.fromRGB(255, 100, 100),
							BackgroundTransparency = 1,
							TextWrapped = true,
						}),
					})
				end

				-- Loading state
				if isLoading.value then
					return props.fallback
						or h("Frame", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
						}, {
							h("TextLabel", {
								Size = UDim2.fromScale(1, 1),
								Text = "Loading...",
								TextColor3 = Color3.fromRGB(200, 200, 200),
								BackgroundTransparency = 1,
							}),
						})
				end

				-- Loaded state - render children
				return h("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
				}, context.slots)
			end
		end,
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
builtins.KeepAlive = nil :: ComponentDef?

--- Returns true if `name` is listed in an include/exclude array
--- @param list unknown -- Prop value ({ string } expected)
--- @param name string -- Component name
--- @return boolean -- True when listed
local function listContains(list: unknown, name: string): boolean
	return type(list) == "table" and table.find(list :: { string }, name) ~= nil
end

local function createKeepAlive(): ComponentDef
	return {
		__is_component = true :: true,
		__name = "KeepAlive",
		props = {
			include = { type = "table" :: "table" },
			exclude = { type = "table" :: "table" },
			max = { type = "number" :: "number", default = 10 },
		},
		setup = function(props: Props, context: SetupContext)
			-- Plain tables on purpose: this is bookkeeping, not render state. As refs, render both read
			-- and wrote them (re-triggering itself), and table.insert/remove bypassed the proxy anyway.
			local cache: { [string]: VNode } = {}
			local keys: { string } = {} -- LRU order, oldest first

			local function shouldCache(name: string): boolean
				if props.include and not listContains(props.include, name) then
					return false
				end
				return not listContains(props.exclude, name)
			end

			local function unmountCached(vnode: VNode)
				local inst = vnode._instance :: any
				if inst and inst.runUnmounted then
					pcall(inst.runUnmounted, inst)
				end
			end

			local function pruneCache()
				local max = props.max
				if type(max) == "number" and #keys > max then
					local oldest = table.remove(keys, 1)
					if oldest then
						local cached = cache[oldest]
						if cached then
							unmountCached(cached)
						end
						cache[oldest] = nil
					end
				end
			end

			-- Cleanup all cached instances on unmount
			componentModule.onUnmounted(function()
				for _, cached in cache do
					unmountCached(cached)
				end
				table.clear(cache)
				table.clear(keys)
			end)

			return function(): VNode?
				local child = context.slots[1]
				if type(child) ~= "table" then
					return nil
				end

				local def = child.type
				local name = if type(def) == "table" then def.__name or "anonymous" else "anonymous"
				if not shouldCache(name) then
					return child
				end

				local cached = cache[name]
				if cached then
					-- Move to the end (most recently used)
					local index = table.find(keys, name)
					if index then
						table.remove(keys, index)
					end
					table.insert(keys, name)

					-- Reuse the cached vnode with fresh props
					cached.props = child.props
					return cached
				end

				cache[name] = child
				table.insert(keys, name)
				pruneCache()
				return child
			end
		end,
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
function builtins.defineAsyncComponent(loader: () -> ComponentDef, opts: AsyncComponentOptions?): ComponentDef
	local options: AsyncComponentOptions = opts or {}

	return {
		__is_component = true,
		__name = "AsyncComponent",
		setup = function(props: Props, context: SetupContext)
			-- shallowRef: a deep ref would wrap the component definition itself in a reactive proxy
			local component = shallowRef(nil :: ComponentDef?)
			local loading = ref(false)
			local error = ref(nil :: string?)
			local showLoading = ref(false)

			-- Get suspense context if available
			local suspense = context.inject("suspense") :: SuspenseContext?

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
						local message = "Component load timeout"
						error.value = message
						loading.value = false
						if suspense then
							suspense.reject(message)
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
					local message = tostring(result)
					error.value = message
					loading.value = false
					showLoading.value = false

					if suspense then
						suspense.reject(message)
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
						BackgroundTransparency = 1,
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
						BackgroundTransparency = 1,
					})
				end

				-- Loaded state
				if component.value then
					return h(component.value, props)
				end

				-- Initial state (before delay)
				return nil
			end
		end,
	}
end

return builtins
