--!strict
--!optimize 2

--[[
	builtins.luau
	=============
	
	Built-in components: Suspense, KeepAlive, Transition, TransitionGroup, VirtualList,
	and the async component loader.
	Provides Vue 3-compatible async handling and component caching.
	
	@module builtins
	@author Rivue
	@version 1.0.0
]]

local componentModule = require(script.Parent:WaitForChild("component"))
local hModule = require(script.Parent:WaitForChild("h"))
local reactivity = require(script.Parent:WaitForChild("reactivity"))

local h = hModule.h
local Fragment = hModule.Fragment
local ref = reactivity.ref
local shallowRef = reactivity.shallowRef

local Types = require(script.Parent:WaitForChild("types"))

type VNode = Types.VNode
type Child = Types.Child
type TransitionConfig = Types.TransitionConfig
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
			-- Children render (hidden) from the start, async components inside register
			-- themselves while they mount and flip this on
			local isLoading = ref(false)
			local error = ref(nil :: string?)
			local pendingCount = 0
			local timeoutThread: thread? = nil

			local function clearTimeout()
				if timeoutThread then
					task.cancel(timeoutThread)
					timeoutThread = nil
				end
			end

			context.provide("suspense", {
				register = function()
					pendingCount += 1
					isLoading.value = true
					local timeout = props.timeout
					if not timeoutThread and type(timeout) == "number" and timeout > 0 then
						timeoutThread = task.delay(timeout / 1000, function()
							timeoutThread = nil
							if isLoading.value then
								error.value = "Timeout: Component took too long to load"
							end
						end)
					end
				end,
				resolve = function()
					pendingCount = math.max(0, pendingCount - 1)
					if pendingCount == 0 then
						isLoading.value = false
						clearTimeout()
					end
				end,
				reject = function(err: string)
					error.value = err
					isLoading.value = false
					clearTimeout()
				end,
			})

			componentModule.onUnmounted(clearTimeout)

			return function()
				local failed = error.value
				local loading = isLoading.value
				local overlay: VNode? = nil
				if failed then
					overlay = h("TextLabel", {
						Name = "SuspenseError",
						Size = UDim2.fromScale(1, 1),
						Text = "Error: " .. tostring(failed),
						TextColor3 = Color3.fromRGB(255, 100, 100),
						BackgroundTransparency = 1,
						TextWrapped = true,
					})
				elseif loading then
					overlay = props.fallback
						or h("TextLabel", {
							Name = "SuspenseFallback",
							Size = UDim2.fromScale(1, 1),
							Text = "Loading...",
							TextColor3 = Color3.fromRGB(200, 200, 200),
							BackgroundTransparency = 1,
						})
				end

				local children: { VNode } = {
					-- Kept mounted while hidden, so loading continues and state survives
					h("Frame", {
						Name = "SuspenseContent",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = not loading and not failed,
					}, context.slots),
				}
				if overlay then
					table.insert(children, overlay)
				end
				return h("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
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

--- Checks if a name is in an include/exclude list
--- @param list unknown -- Prop value ({ string } expected)
--- @param name string -- Component name
--- @return boolean -- True when listed
local function listContains(list: unknown, name: string): boolean
	return type(list) == "table" and table.find(list :: { string }, name) ~= nil
end

--- Returns the first vnode in a children list
--- @param list { Child } -- Children
--- @return VNode? -- First table child
local function firstVNode(list: { Child }): VNode?
	for _, child in list do
		if type(child) == "table" then
			return child
		end
	end
	return nil
end

local function createKeepAlive(): ComponentDef
	return {
		__is_component = true :: true,
		__name = "KeepAlive",
		__isKeepAlive = true :: true,
		props = {
			include = { type = "table" :: "table" },
			exclude = { type = "table" :: "table" },
			max = { type = "number" :: "number", default = 10 },
		},
		setup = function(props: Props, context: SetupContext)
			local self = componentModule.getCurrentInstance()
			local renderer = if self then self._keepAliveRenderer else nil
			-- Shared by every cached vnode, the renderer detaches them instead of unmounting
			local marker = { disposed = false }
			-- Plain tables, not refs: render reads and writes these
			local cache: { [unknown]: VNode } = {}
			local keys: { unknown } = {} -- oldest first
			local current: VNode? = nil

			local function shouldCache(name: string): boolean
				if props.include and not listContains(props.include, name) then
					return false
				end
				return not listContains(props.exclude, name)
			end

			local function evict(key: unknown)
				local cached = cache[key]
				cache[key] = nil
				local index = table.find(keys, key)
				if index then
					table.remove(keys, index)
				end
				if cached and cached ~= current and renderer then
					renderer.unmount(cached)
				end
			end

			-- The active child is unmounted with the subtree, the rest here
			componentModule.onUnmounted(function()
				marker.disposed = true
				for _, cached in cache do
					if cached ~= current and renderer then
						renderer.unmount(cached)
					end
				end
				table.clear(cache)
				table.clear(keys)
			end)

			return function(): VNode?
				local child = firstVNode(context.slots)
				local def = if child then child.type else nil
				if not child or type(def) ~= "table" or not (def :: ComponentDef).__is_component then
					current = child
					return child
				end

				local name = (def :: ComponentDef).__name or "anonymous"
				if not shouldCache(name) then
					current = child
					return child
				end

				local key: unknown = if child.key ~= nil then child.key else def
				local cached = cache[key]
				if cached and cached._instance then
					-- Reuse the cached instance, move to the end (LRU)
					child._instance = cached._instance
					child._kept = true
					local index = table.find(keys, key)
					if index then
						table.remove(keys, index)
					end
				end
				table.insert(keys, key)
				child._keepAlive = marker
				cache[key] = child
				current = child

				local max = props.max
				while type(max) == "number" and max > 0 and #keys > max do
					evict(keys[1])
				end
				return child
			end
		end,
	}
end

builtins.KeepAlive = createKeepAlive()

--- Builds the transition config <Transition>/<TransitionGroup> hands to the renderer
--- @param props Props -- Component props
--- @param mounted boolean -- Whether the first render already happened (appear)
--- @param afterLeave ((el: Instance) -> ())? -- Extra after-leave callback
--- @return TransitionConfig -- Config for the children
local function transitionConfig(props: Props, mounted: boolean, afterLeave: ((el: Instance) -> ())?): TransitionConfig
	local onAfterLeave = props.onAfterLeave
	return {
		tweenInfo = props.tweenInfo,
		info = props.info,
		enterInfo = props.enterInfo,
		leaveInfo = props.leaveInfo,
		from = props.from,
		enterFrom = props.enterFrom,
		enterGoals = props.enterGoals,
		leaveGoals = props.leaveGoals,
		goals = props.goals,
		enter = mounted or props.appear == true,
		leave = true,
		onBeforeEnter = props.onBeforeEnter,
		onAfterEnter = props.onAfterEnter,
		onBeforeLeave = props.onBeforeLeave,
		onAfterLeave = if afterLeave
			then function(el: Instance)
				if onAfterLeave then
					onAfterLeave(el)
				end
				afterLeave(el)
			end
			else onAfterLeave,
	}
end

--- True if the vnode put an Instance on screen
--- @param vnode VNode -- Mounted vnode
--- @return boolean -- Has an element
local function hasElement(vnode: VNode): boolean
	local inst = vnode._instance :: any
	return vnode.el ~= nil or (inst ~= nil and inst.el ~= nil)
end

--[=[
	Transition Component
	====================

	Tweens its child in when it appears and out before it's destroyed.

	Props:
		tweenInfo: TweenInfo        -- Used for enter and leave (enterInfo/leaveInfo override)
		from: { [string]: any }?    -- Hidden state: applied before enter, tweened to on leave
		enterGoals/leaveGoals: { [string]: any }?  -- Explicit targets
		appear: boolean?            -- Also animate the first render
		mode: "out-in"?             -- Wait for the old child to leave before showing the new one
		onBeforeEnter/onAfterEnter/onBeforeLeave/onAfterLeave: ((el: Instance) -> ())?

	Usage:
		h(Rivue.Transition, {
			tweenInfo = TweenInfo.new(0.2),
			from = { BackgroundTransparency = 1 },
		}, {
			Rivue.hIf(open.value, h("Frame", { BackgroundTransparency = 0.2 })),
		})
]=]
builtins.Transition = table.freeze({
	__is_component = true :: true,
	__name = "Transition",
	setup = function(props: Props, context: SetupContext)
		local mounted = false
		componentModule.onMounted(function()
			mounted = true
		end)

		-- out-in: the old child is leaving, bumped when it's gone
		local leaving = false
		local leaveDone = ref(0)
		local shown: VNode? = nil

		local function onLeft()
			if leaving then
				leaving = false
				leaveDone.value += 1
			end
		end

		return function(): VNode?
			local _ = leaveDone.value
			local child = firstVNode(context.renderSlot("default"))
			if props.mode == "out-in" then
				if leaving then
					return nil
				end
				local prev = shown
				if prev and child and (prev.type ~= child.type or prev.key ~= child.key) and hasElement(prev) then
					leaving = true
					shown = nil
					return nil
				end
			end
			if child then
				child._transition = transitionConfig(props, mounted, onLeft)
			end
			shown = child
			return child
		end
	end,
}) :: ComponentDef

--[=[
	TransitionGroup Component
	=========================

	Transition for lists: keyed children tween in when added and out when removed.
	Takes the same props as Transition (no mode), plus:
		tag: string?          -- Wrap the children in this element (default: no wrapper)
		tagProps: Props?      -- Props for the wrapper

	Usage:
		h(Rivue.TransitionGroup, { tweenInfo = TweenInfo.new(0.15), from = { Size = UDim2.new() } },
			Rivue.hFor(items.value, function(item) return h("TextLabel", { key = item.id, Text = item.name }) end))
]=]
builtins.TransitionGroup = table.freeze({
	__is_component = true :: true,
	__name = "TransitionGroup",
	setup = function(props: Props, context: SetupContext)
		local mounted = false
		componentModule.onMounted(function()
			mounted = true
		end)

		return function(): VNode
			local config = transitionConfig(props, mounted, nil)
			local children: { Child } = {}
			for _, child in context.renderSlot("default") do
				if type(child) == "table" then
					child._transition = config
					table.insert(children, child)
				end
			end
			local tag = props.tag
			if type(tag) == "string" then
				return h(tag, props.tagProps, children)
			end
			return h(Fragment, nil, children)
		end
	end,
}) :: ComponentDef

--[=[
	VirtualList Component
	=====================

	A ScrollingFrame that only renders the rows in view. Rows have a fixed size.
	Undeclared props (Size, Position, ...) go to the ScrollingFrame.

	Props:
		items: { T }                          -- Plain or reactive array
		itemSize: number                      -- Row height (or width when horizontal), in pixels
		render: (item: T, index: number) -> VNode
		key: ((item: T, index: number) -> unknown)?  -- Defaults to the index
		overscan: number?                     -- Extra rows above and below (default 2)
		horizontal: boolean?

	Usage:
		h(Rivue.VirtualList, {
			Size = UDim2.fromScale(1, 1),
			items = inventory,
			itemSize = 40,
			key = function(item) return item.id end,
			render = function(item) return h(ItemRow, { item = item }) end,
		})
]=]
local virtualList: ComponentDef = {
	__is_component = true :: true,
	__name = "VirtualList",
	props = {
		items = { type = "table" :: "table", required = true },
		itemSize = { type = "number" :: "number", required = true },
		render = { type = "function" :: "function", required = true },
		key = { type = "function" :: "function" },
		overscan = { type = "number" :: "number", default = 2 },
		horizontal = { type = "boolean" :: "boolean", default = false },
	},
	setup = function(props: Props, _context: SetupContext)
		local scroll = ref(0)
		local viewport = ref(0)
		local frameRef = shallowRef(nil :: ScrollingFrame?)
		local conns: { RBXScriptConnection } = {}

		componentModule.onMounted(function()
			local frame = frameRef.value
			if not frame then
				return
			end
			local function sync()
				if props.horizontal then
					scroll.value = frame.CanvasPosition.X
					viewport.value = frame.AbsoluteSize.X
				else
					scroll.value = frame.CanvasPosition.Y
					viewport.value = frame.AbsoluteSize.Y
				end
			end
			table.insert(conns, frame:GetPropertyChangedSignal("CanvasPosition"):Connect(sync))
			table.insert(conns, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync))
			sync()
		end)

		componentModule.onUnmounted(function()
			for _, conn in conns do
				conn:Disconnect()
			end
			table.clear(conns)
		end)

		return function(): VNode
			local items = props.items :: { unknown }
			local size = props.itemSize :: number
			local overscan = props.overscan :: number
			local horizontal = props.horizontal == true
			local render = props.render :: (item: unknown, index: number) -> VNode?
			local keyFn = props.key :: ((item: unknown, index: number) -> unknown)?
			local count = #items

			local first = math.max(1, math.floor(scroll.value / size) + 1 - overscan)
			local last = math.min(count, first + math.ceil(viewport.value / size) + overscan * 2)

			local rows: { Child } = table.create(math.max(last - first + 1, 0))
			for i = first, last do
				local item = items[i]
				local row = render(item, i)
				if row then
					local offset = (i - 1) * size
					local rowProps: Props = row.props or {}
					row.props = rowProps
					rowProps.Position = if horizontal then UDim2.fromOffset(offset, 0) else UDim2.fromOffset(0, offset)
					row.key = if keyFn then keyFn(item, i) else i
					table.insert(rows, row)
				end
			end

			local total = count * size
			return h("ScrollingFrame", {
				ref = frameRef,
				CanvasSize = if horizontal then UDim2.fromOffset(total, 0) else UDim2.fromOffset(0, total),
				ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
			}, rows)
		end
	end,
}
builtins.VirtualList = table.freeze(virtualList)

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
			-- shallowRef so the component definition isn't wrapped in a proxy
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
