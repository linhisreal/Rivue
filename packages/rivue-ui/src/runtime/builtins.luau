--!strict
--!optimize 2

local componentModule = require("./component")
local hModule = require("./h")
local reactivity = require("./reactivity")

local h = hModule.h
local Fragment = hModule.Fragment
local ref = reactivity.ref
local shallowRef = reactivity.shallowRef
local computed = reactivity.computed

local Types = require("./types")

type VNode = Types.VNode
type Child = Types.Child
type TransitionConfig = Types.TransitionConfig
type ComponentDef = Types.ComponentDef
type Props = Types.Props
type SetupContext = Types.SetupContext
type AsyncComponentOptions = Types.AsyncComponentOptions
type SuspenseContext = Types.SuspenseContext

local builtins = {}

builtins.Suspense = nil :: ComponentDef?

local function createSuspense(): ComponentDef
	return {
		__is_component = true :: true,
		__name = "Suspense",
		props = {
			fallback = { type = "table" :: "table" },
			timeout = { type = "number" :: "number", default = 5000 },
		},
		setup = function(props: Props, context: SetupContext)
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

builtins.KeepAlive = nil :: ComponentDef?

local function listContains(list: unknown, name: string): boolean
	if type(list) ~= "table" then
		return false
	end
	local names = list :: { string }
	for i = 1, #names do
		if names[i] == name then
			return true
		end
	end
	return false
end

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
			local marker = { disposed = false }
			local cache: { [unknown]: VNode } = {}
			local keys: { unknown } = {}
			local current: VNode? = nil

			local function shouldCache(name: string): boolean
				if props.include and not listContains(props.include, name) then
					return false
				end
				return not listContains(props.exclude, name)
			end

			local function isCurrent(cached: VNode): boolean
				return cached == current
					or (cached._instance ~= nil and current ~= nil and cached._instance == current._instance)
			end

			local function evict(key: unknown)
				local cached = cache[key]
				cache[key] = nil
				local index = table.find(keys, key)
				if index then
					table.remove(keys, index)
				end
				if cached and not isCurrent(cached) and renderer then
					renderer.unmount(cached)
				elseif cached then
					cached._keepAlive = nil
				end
			end

			componentModule.onBeforeUnmount(function()
				marker.disposed = true
			end)
			componentModule.onUnmounted(function()
				for _, cached in cache do
					if not isCurrent(cached) and renderer then
						renderer.unmount(cached)
					end
				end
				table.clear(cache)
				table.clear(keys)
			end)

			reactivity.watch(function()
				return { props.include, props.exclude }
			end, function()
				for key, cached in cache do
					local def = cached.type :: ComponentDef
					if not shouldCache(def.__name or "anonymous") then
						evict(key)
					end
				end
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

local function hasElement(vnode: VNode): boolean
	local inst = vnode._instance :: any
	return vnode.el ~= nil or (inst ~= nil and inst.el ~= nil)
end

builtins.Transition = table.freeze({
	__is_component = true :: true,
	__name = "Transition",
	setup = function(props: Props, context: SetupContext)
		local mounted = false
		componentModule.onMounted(function()
			mounted = true
		end)

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

local virtualList: ComponentDef = {
	__is_component = true :: true,
	__name = "VirtualList",
	props = {
		items = { type = "table" :: "table", required = true },
		itemSize = { type = { "number", "function" }, required = true },
		render = { type = "function" :: "function", required = true },
		key = { type = "function" :: "function" },
		overscan = { type = "number" :: "number", default = 2 },
		horizontal = { type = "boolean" :: "boolean", default = false },
		columns = { type = "number" :: "number", default = 1 },
		gap = { type = "number" :: "number", default = 0 },
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

		local offsets = computed(function(): { number }?
			local sizeOf = props.itemSize
			if type(sizeOf) ~= "function" then
				return nil
			end
			local items = props.items :: { unknown }
			local gap = props.gap :: number
			local count = #items
			local list = table.create(count + 1)
			local total = 0
			for i = 1, count do
				list[i] = total
				total += (sizeOf :: (unknown, number) -> number)(items[i], i) + gap
			end
			list[count + 1] = total
			return list
		end)

		local function indexAt(list: { number }, count: number, position: number): number
			local low, high = 1, count
			while low < high do
				local mid = (low + high + 1) // 2
				if list[mid] <= position then
					low = mid
				else
					high = mid - 1
				end
			end
			return low
		end

		return function(): VNode
			local items = props.items :: { unknown }
			local overscan = props.overscan :: number
			local horizontal = props.horizontal == true
			local render = props.render :: (item: unknown, index: number) -> VNode?
			local keyFn = props.key :: ((item: unknown, index: number) -> unknown)?
			local gap = props.gap :: number
			local columns = math.max(1, math.floor(props.columns :: number))
			local count = #items
			local variable = offsets.value

			local first, last, total
			-- CanvasPosition isn't clamped until the shorter canvas applies
			local function clampScroll(contentSize: number): number
				return math.clamp(scroll.value, 0, math.max(0, contentSize - viewport.value))
			end
			if variable then
				if columns > 1 then
					error("[Rivue] VirtualList: itemSize as a function needs columns = 1", 0)
				end
				total = math.max(0, variable[count + 1] - gap)
				local offset = clampScroll(total)
				first = math.max(1, indexAt(variable, count, offset) - overscan)
				last = math.min(count, indexAt(variable, count, offset + viewport.value) + overscan)
			else
				local stride = (props.itemSize :: number) + gap
				local rowCount = math.ceil(count / columns)
				total = math.max(0, rowCount * stride - gap)
				local firstRow = math.max(0, math.floor(clampScroll(total) / stride) - overscan)
				local lastRow = math.min(rowCount - 1, firstRow + math.ceil(viewport.value / stride) + overscan * 2)
				first = firstRow * columns + 1
				last = math.min(count, (lastRow + 1) * columns)
			end

			local rows: { Child } = table.create(math.max(last - first + 1, 0))
			for i = first, last do
				local item = items[i]
				local row = render(item, i)
				if row then
					local rowProps: Props = row.props or {}
					row.props = rowProps
					local offset, cross, crossSize
					if variable then
						offset = variable[i]
					else
						local column = (i - 1) % columns
						offset = ((i - 1) // columns) * ((props.itemSize :: number) + gap)
						cross = UDim.new(column / columns, column * gap / columns)
						crossSize = UDim.new(1 / columns, -gap * (columns - 1) / columns)
					end
					if horizontal then
						rowProps.Position = UDim2.new(UDim.new(0, offset), cross or UDim.new(0, 0))
					else
						rowProps.Position = UDim2.new(cross or UDim.new(0, 0), UDim.new(0, offset))
					end
					if columns > 1 and rowProps.Size == nil then
						local mainSize = UDim.new(0, props.itemSize :: number)
						rowProps.Size = if horizontal
							then UDim2.new(mainSize, crossSize :: UDim)
							else UDim2.new(crossSize :: UDim, mainSize)
					end
					row.key = if keyFn then keyFn(item, i) else i
					table.insert(rows, row)
				end
			end

			return h("ScrollingFrame", {
				ref = frameRef,
				CanvasSize = if horizontal then UDim2.fromOffset(total, 0) else UDim2.fromOffset(0, total),
				ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
			}, rows)
		end
	end,
}
builtins.VirtualList = table.freeze(virtualList)

--- Where to put the camera so a box of this size fills the view: on a sphere around its centre,
--- turned angle degrees around and pitch degrees up
local function viewportCamera(
	center: Vector3,
	size: Vector3,
	fieldOfView: number,
	angle: number,
	pitch: number,
	distance: number
): (Vector3, Vector3)
	local radius = size.Magnitude / 2
	local away = radius / math.tan(math.rad(fieldOfView) / 2) * distance
	local yaw, tilt = math.rad(angle), math.rad(pitch)
	local direction = Vector3.new(math.sin(yaw) * math.cos(tilt), math.sin(tilt), math.cos(yaw) * math.cos(tilt))
	return center + direction * away, center
end
builtins.viewportCamera = viewportCamera

local viewportModel = {
	__is_component = true,
	__name = "ViewportModel",
	props = {
		model = { type = "Instance" :: "Instance", required = true },
		angle = { type = "number" :: "number", default = 30 },
		pitch = { type = "number" :: "number", default = 20 },
		fieldOfView = { type = "number" :: "number", default = 40 },
		distance = { type = "number" :: "number", default = 1 },
	},
	setup = function(props: Props, _context: SetupContext)
		local frameRef = shallowRef(nil :: ViewportFrame?)
		local clone: Instance? = nil
		local camera: Camera? = nil

		local function refresh()
			local frame = frameRef.value
			if not frame then
				return
			end
			if clone then
				clone:Destroy()
				clone = nil
			end
			local copy = (props.model :: Instance):Clone()
			if not copy then
				warn("[Rivue] ViewportModel: the model isn't Archivable, so it can't be cloned")
				return
			end
			local view = camera or Instance.new("Camera")
			camera = view
			view.FieldOfView = props.fieldOfView :: number
			view.Parent = frame
			frame.CurrentCamera = view

			local center: CFrame, size: Vector3
			if copy:IsA("Model") then
				center, size = copy:GetBoundingBox()
			elseif copy:IsA("BasePart") then
				center, size = copy.CFrame, copy.Size
			else
				warn(`[Rivue] ViewportModel needs a Model or a BasePart, got a {copy.ClassName}`)
				copy:Destroy()
				return
			end
			local eye, target = viewportCamera(
				center.Position,
				size,
				props.fieldOfView :: number,
				props.angle :: number,
				props.pitch :: number,
				props.distance :: number
			)
			view.CFrame = CFrame.lookAt(eye, target)
			copy.Parent = frame
			clone = copy
		end

		componentModule.onMounted(function()
			refresh()
			reactivity.watch(function()
				return { props.model, props.angle, props.pitch, props.fieldOfView, props.distance }
			end, refresh)
		end)
		componentModule.onUnmounted(function()
			if clone then
				clone:Destroy()
			end
			if camera then
				camera:Destroy()
			end
		end)

		return function(): VNode
			return h("ViewportFrame", { ref = frameRef, BackgroundTransparency = 1 })
		end
	end,
}
builtins.ViewportModel = table.freeze(viewportModel)

function builtins.defineAsyncComponent(loader: () -> ComponentDef, opts: AsyncComponentOptions?): ComponentDef
	local options: AsyncComponentOptions = opts or {}

	return {
		__is_component = true,
		__name = "AsyncComponent",
		setup = function(props: Props, context: SetupContext)
			local component = shallowRef(nil :: ComponentDef?)
			local loading = ref(false)
			local error = ref(nil :: string?)
			local showLoading = ref(false)

			local suspense = context.inject("suspense") :: SuspenseContext?

			local delayTimer: thread? = nil
			if options.delay and options.delay > 0 then
				delayTimer = task.delay(options.delay / 1000, function()
					if loading.value then
						showLoading.value = true
					end
				end)
			else
				showLoading.value = true
			end

			local timeoutTimer: thread? = nil
			local attempts = 0
			local finished = false

			local function stopTimers()
				if delayTimer then
					task.cancel(delayTimer)
					delayTimer = nil
				end
				if timeoutTimer then
					task.cancel(timeoutTimer)
					timeoutTimer = nil
				end
			end

			local function finish(loaded: ComponentDef?, message: string?)
				if finished then
					return
				end
				finished = true
				stopTimers()
				component.value = loaded
				error.value = message
				loading.value = false
				showLoading.value = false
				if suspense then
					if message then
						suspense.reject(message)
					else
						suspense.resolve()
					end
				end
			end

			local attempt: () -> ()

			local function failed(message: string)
				local onError = options.onError
				if not onError then
					finish(nil, message)
					return
				end
				local ok, handlerErr = pcall(onError :: (...any) -> ...any, message, function()
					if not finished then
						attempt()
					end
				end, function()
					finish(nil, message)
				end, attempts)
				if not ok then
					finish(nil, tostring(handlerErr))
				end
			end

			function attempt()
				attempts += 1
				local this = attempts
				if timeoutTimer then
					task.cancel(timeoutTimer)
					timeoutTimer = nil
				end
				if options.timeout and options.timeout > 0 then
					timeoutTimer = task.delay(options.timeout / 1000, function()
						timeoutTimer = nil
						if not finished and this == attempts then
							failed("Component load timeout")
						end
					end)
				end
				task.spawn(function()
					local success, result = pcall(loader)
					if finished or this ~= attempts then
						return
					end
					if success then
						finish(result, nil)
					else
						failed(tostring(result))
					end
				end)
			end

			if suspense then
				suspense.register()
			end

			loading.value = true
			attempt()

			componentModule.onUnmounted(function()
				finished = true
				stopTimers()
			end)

			return function()
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

				if component.value then
					return h(component.value, props)
				end

				return nil
			end
		end,
	}
end

return builtins
