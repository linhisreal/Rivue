--!nonstrict
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the Rivue License, based on PolyForm Noncommercial 1.0.0. See LICENSE.

local CollectionService = game:GetService("CollectionService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")
local UserInputService = game:GetService("UserInputService")
local Rivue = require(script.Parent:WaitForChild("RivueUI"))
local Highlight = require(script.Parent:WaitForChild("Highlight"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local TAG = "RivueComponent"
local CHANNEL_TAG = "RivueDevToolsChannel"
local MAX_EVENTS = 100
local INDENT = 14
local KINDS = { "render", "emit", "navigation", "network", "warning" }
local NETWORK_KINDS = { request = true, send = true, event = true, state = true }
local MAX_NETWORK = 200
local MAX_WARNINGS = 100
local MAX_SLOWEST = 15
local MAX_RENDER_TIMES = 64
local MAX_CAUSES = 5
local SPARK_BUCKETS = 10

export type Entry = {
	instance: Instance,
	path: string,
	depth: number,
	name: string,
	props: string,
	state: string,
	renders: number,
	renderMs: number,
	trigger: string,
	source: string,
	provides: string,
	injects: string,
	hasChildren: boolean,
	changed: boolean,
	previous: { [string]: string },
}

export type PerfRow = { name: string, renders: number, totalMs: number, maxMs: number, causes: { [string]: number } }
export type SlowUpdate = { seq: number, name: string, ms: number, cause: string }

export type NetEntry = {
	seq: number,
	at: number,
	kind: string,
	label: string,
	detail: string,
	ms: number?,
	bytes: number?,
	failed: boolean,
}
export type NetTotal = {
	key: string,
	kind: string,
	label: string,
	count: number,
	totalMs: number,
	failed: number,
	bytes: number,
}
export type NetState = { name: string, value: string, version: number }

export type Warning = { id: number, at: number, level: string, message: string, component: string? }
export type Cause = { at: number, cause: string, ms: number }

export type EmitEvent = {
	id: number,
	name: string,
	event: string,
	args: string,
	instance: Instance,
}

export type TimelineEntry = {
	seq: number,
	at: number,
	kind: string,
	ms: string,
	label: string,
	detail: string,
}

export type SortMode = "tree" | "renders" | "slowest"
export type View = "components" | "activity" | "performance" | "network" | "settings"
export type Density = "comfortable" | "compact"

local SORT_LABELS: { [SortMode]: string } = { tree = "tree", renders = "most renders", slowest = "slowest" }
local NEXT_SORT: { [SortMode]: SortMode } = { tree = "renders", renders = "slowest", slowest = "tree" }

local entries = Rivue.shallowRef({} :: { Entry })
local events = Rivue.shallowRef({} :: { EmitEvent })
local selected = Rivue.shallowRef(nil :: Instance?)
local collapsed = Rivue.shallowRef({} :: { [string]: boolean })
local pinned = Rivue.shallowRef({} :: { [string]: boolean })
local onlySlow = Rivue.ref(false)
local onlyChanged = Rivue.ref(false)
local picking = Rivue.ref(false)
local recording = Rivue.ref(false)
local perfRows = Rivue.shallowRef({} :: { [string]: PerfRow })
local perfSlowest = Rivue.shallowRef({} :: { SlowUpdate })
local perfSpan = Rivue.shallowRef({ first = 0, last = 0 })
local netEntries = Rivue.shallowRef({} :: { NetEntry })
local netTotals = Rivue.shallowRef({} :: { [string]: NetTotal })
local netState = Rivue.shallowRef({} :: { [string]: NetState })
local warnings = Rivue.shallowRef({} :: { Warning })
local statusMessage = Rivue.ref("")
local warningCount = 0
local previousState: { [Instance]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any
local lastState: { [Instance]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any
local paused = Rivue.ref(false)
local sortMode = Rivue.ref("tree" :: SortMode)
local view = Rivue.ref("components" :: View)
local timeline = Rivue.shallowRef({} :: { TimelineEntry })
local routeText = Rivue.ref("")
local lastSeq = 0
local palette = Rivue.shallowRef(Theme.read())
local searchOpen = Rivue.ref(false)
local tick = Rivue.ref(0)
local renderTimes: { [Instance]: { number } } = setmetatable({}, { __mode = "k" }) :: any
local recentCauses: { [Instance]: { Cause } } = setmetatable({}, { __mode = "k" }) :: any

export type Settings = {
	slowMs: number,
	timelineLimit: number,
	highlightUpdates: boolean,
	collapsed: { string },
	pinned: { string },
	lastSnapshot: string,
	density: string,
}
export type SettingsStore = { get: (key: string) -> any, set: (key: string, value: any) -> () }

local DEFAULT_SETTINGS: Settings = {
	slowMs = 2,
	timelineLimit = 200,
	highlightUpdates = false,
	collapsed = {},
	pinned = {},
	lastSnapshot = "",
	density = "comfortable",
}
local settings = Rivue.reactive(table.clone(DEFAULT_SETTINGS)) :: Settings
local settingsStore: SettingsStore? = nil
local kindsShown = Rivue.reactive({ render = true, emit = true, navigation = true, network = true, warning = true })
local lastRenders: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local baselines: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: RBXScriptConnection } = {}
local eventCount = 0
local openScript: ((script: LuaSourceContainer, line: number) -> ())? = nil

local function depthOf(instance: Instance): number
	local depth = 0
	local parent = instance.Parent
	while parent do
		if CollectionService:HasTag(parent, TAG) then
			depth += 1
		end
		parent = parent.Parent
	end
	return depth
end

local function fullName(instance: Instance): string
	local ok, name = pcall(instance.GetFullName, instance)
	return if ok then name else instance.Name
end

local function collect()
	local list: { Entry } = {}
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance.Parent ~= nil then
			local renders = (instance:GetAttribute("RivueRenders") :: number?) or 0
			local before = lastRenders[instance]
			lastRenders[instance] = renders
			local stateText = (instance:GetAttribute("RivueState") :: string?) or ""
			local fields: { [string]: string } = {}
			for line in string.gmatch(stateText, "[^\n]+") do
				local key, value = string.match(line, "^(.-) = (.*)$")
				if key then
					fields[key] = value
				end
			end
			local seen = lastState[instance]
			local previous = previousState[instance] or {}
			if seen then
				for key, value in fields do
					if seen[key] ~= nil and seen[key] ~= value then
						previous[key] = seen[key]
					end
				end
			end
			lastState[instance] = fields
			previousState[instance] = previous
			table.insert(list, {
				instance = instance,
				path = fullName(instance),
				previous = previous,
				depth = depthOf(instance),
				name = (instance:GetAttribute("RivueComponent") :: string?) or instance.Name,
				props = (instance:GetAttribute("RivueProps") :: string?) or "",
				state = stateText,
				renders = renders - (baselines[instance] or 0),
				renderMs = (instance:GetAttribute("RivueRenderMs") :: number?) or 0,
				trigger = (instance:GetAttribute("RivueTrigger") :: string?) or "",
				source = (instance:GetAttribute("RivueSource") :: string?) or "",
				provides = (instance:GetAttribute("RivueProvides") :: string?) or "",
				injects = (instance:GetAttribute("RivueInjects") :: string?) or "",
				hasChildren = false,
				changed = before ~= nil and renders > before,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.path < b.path
	end)
	for i, entry in list do
		local nextEntry = list[i + 1]
		entry.hasChildren = nextEntry ~= nil and nextEntry.depth > entry.depth
	end
	if selected.value and not table.find(CollectionService:GetTagged(TAG), selected.value) then
		selected.value = nil
	end
	entries.value = list
end

local pending = false
local function refreshSoon()
	if pending or paused.value then
		return
	end
	pending = true
	task.delay(0.2, function()
		pending = false
		if not paused.value then
			collect()
		end
	end)
end

local function logEmit(instance: Instance)
	if paused.value then
		return
	end
	local raw = instance:GetAttribute("RivueEmit")
	local event, args = string.match(if type(raw) == "string" then raw else "", "^%d+|([^|]*)|(.*)$")
	if not event then
		return
	end
	eventCount += 1
	local list = table.clone(events.value)
	table.insert(list, 1, {
		id = eventCount,
		name = (instance:GetAttribute("RivueComponent") :: string?) or instance.Name,
		event = event,
		args = args,
		instance = instance,
	})
	if #list > MAX_EVENTS then
		table.remove(list)
	end
	events.value = list
end

local function ingestPerf(added: { TimelineEntry })
	if not recording.value then
		return
	end
	local rows: { [string]: PerfRow }? = nil
	local slowest: { SlowUpdate }? = nil
	local span = perfSpan.value
	for i = #added, 1, -1 do
		local entry = added[i]
		if entry.kind ~= "render" then
			continue
		end
		local ms = tonumber(entry.ms) or 0
		local map = rows or table.clone(perfRows.value)
		rows = map
		local row = map[entry.label]
		if not row then
			row = { name = entry.label, renders = 0, totalMs = 0, maxMs = 0, causes = {} }
			map[entry.label] = row
		end
		row.renders += 1
		row.totalMs += ms
		row.maxMs = math.max(row.maxMs, ms)
		local cause = if entry.detail == "" then "parent" else entry.detail
		row.causes[cause] = (row.causes[cause] or 0) + 1
		local list = slowest or table.clone(perfSlowest.value)
		slowest = list
		table.insert(list, { seq = entry.seq, name = entry.label, ms = ms, cause = cause })
		span = { first = if span.first == 0 then entry.at else span.first, last = entry.at }
	end
	if rows then
		perfRows.value = rows
		perfSpan.value = span
	end
	if slowest then
		table.sort(slowest, function(a, b)
			return a.ms > b.ms
		end)
		while #slowest > MAX_SLOWEST do
			table.remove(slowest)
		end
		perfSlowest.value = slowest
	end
end

local function ingestNetwork(added: { TimelineEntry })
	local list: { NetEntry }? = nil
	local totals: { [string]: NetTotal }? = nil
	local states: { [string]: NetState }? = nil
	for i = #added, 1, -1 do
		local entry = added[i]
		if not NETWORK_KINDS[entry.kind] then
			continue
		end
		local bytes = tonumber(string.match(entry.detail, "(%d+) B$"))
		local ms = tonumber(entry.ms)
		local failed = entry.kind == "request" and string.sub(entry.detail, 1, 2) ~= "ok"
		local items = list or table.clone(netEntries.value)
		list = items
		table.insert(items, 1, {
			seq = entry.seq,
			at = entry.at,
			kind = entry.kind,
			label = entry.label,
			detail = entry.detail,
			ms = ms,
			bytes = bytes,
			failed = failed,
		})
		while #items > MAX_NETWORK do
			table.remove(items)
		end
		if entry.kind == "state" then
			local version, value = string.match(entry.detail, "^v(%d+) = (.*)$")
			local map = states or table.clone(netState.value)
			states = map
			map[entry.label] = { name = entry.label, value = value or entry.detail, version = tonumber(version) or 0 }
		else
			local key = `{entry.kind}:{entry.label}`
			local map = totals or table.clone(netTotals.value)
			totals = map
			local total = map[key]
			if not total then
				total =
					{ key = key, kind = entry.kind, label = entry.label, count = 0, totalMs = 0, failed = 0, bytes = 0 }
				map[key] = total
			end
			total.count += 1
			total.totalMs += ms or 0
			total.bytes += bytes or 0
			if failed then
				total.failed += 1
			end
		end
	end
	if list then
		netEntries.value = list
	end
	if totals then
		netTotals.value = totals
	end
	if states then
		netState.value = states
	end
end

local function readTimeline(channel: Instance)
	if paused.value then
		return
	end
	local raw = channel:GetAttribute("RivueTimeline")
	local added = {}
	for line in string.gmatch(if type(raw) == "string" then raw else "", "[^\n]+") do
		local seq, at, kind, ms, label, detail =
			string.match(line, "^(%d+)\t(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
		local number = tonumber(seq)
		if number and number > lastSeq then
			table.insert(added, 1, {
				seq = number,
				at = tonumber(at) :: number,
				kind = kind :: string,
				ms = ms :: string,
				label = label :: string,
				detail = detail :: string,
			})
		end
	end
	if #added == 0 then
		return
	end
	lastSeq = added[1].seq
	ingestPerf(added)
	ingestNetwork(added)
	local list = table.clone(timeline.value)
	for i = #added, 1, -1 do
		table.insert(list, 1, added[i])
	end
	while #list > settings.timelineLimit do
		table.remove(list)
	end
	timeline.value = list
end

local function readRoute(channel: Instance)
	local raw = channel:GetAttribute("RivueRoute")
	if type(raw) == "string" then
		routeText.value = raw
	end
end

local function toSet(list: { string }): { [string]: boolean }
	local set = {}
	for _, item in list do
		set[item] = true
	end
	return set
end

local function setSettingsStore(store: SettingsStore?)
	settingsStore = store
	if not store then
		return
	end
	for key, default in DEFAULT_SETTINGS do
		local saved = store.get(key)
		if type(saved) == type(default) then
			(settings :: any)[key] = saved
		end
	end
	collapsed.value = toSet(settings.collapsed)
	pinned.value = toSet(settings.pinned)
end

local function setSetting(key: string, value: any)
	(settings :: any)[key] = value
	if settingsStore then
		settingsStore.set(key, value)
	end
end

local function setPaused(value: boolean)
	paused.value = value
	if not value then
		collect()
	end
end

--- Counts start again from zero, so you can measure one interaction
local function resetCounts()
	for _, instance in CollectionService:GetTagged(TAG) do
		baselines[instance] = (instance:GetAttribute("RivueRenders") :: number?) or 0
	end
	collect()
end

local function saveSet(key: string, set: { [string]: boolean })
	local list = {}
	for item in set do
		table.insert(list, item)
	end
	table.sort(list)
	setSetting(key, list)
end

local function setCollapsed(next: { [string]: boolean })
	collapsed.value = next
	saveSet("collapsed", next)
end

local function toggleCollapsed(path: string)
	local next = table.clone(collapsed.value)
	next[path] = if next[path] then nil else true
	setCollapsed(next)
end

local function collapseAll()
	local next = {}
	for _, entry in entries.value do
		if entry.hasChildren then
			next[entry.path] = true
		end
	end
	setCollapsed(next)
end

local function expandAll()
	setCollapsed({})
end

local function togglePinned(path: string)
	local next = table.clone(pinned.value)
	next[path] = if next[path] then nil else true
	pinned.value = next
	saveSet("pinned", next)
end

local function startRecording()
	perfRows.value = {}
	perfSlowest.value = {}
	perfSpan.value = { first = 0, last = 0 }
	recording.value = true
end

local function stopRecording()
	recording.value = false
end

local function clearNetwork()
	netEntries.value = {}
	netTotals.value = {}
end

local function componentNameIn(message: string): string?
	return string.match(message, "<([^<>]+)>")
		or string.match(message, "%[Rivue%] ([%w_]+) emitted")
		or string.match(message, "event '[^']*' in ([%w_]+)")
end

local function logMessage(message: string, messageType: Enum.MessageType)
	if not string.find(message, "[Rivue", 1, true) then
		return
	end
	local level = if messageType == Enum.MessageType.MessageError
		then "error"
		elseif messageType == Enum.MessageType.MessageWarning then "warning"
		else nil
	if not level then
		return
	end
	warningCount += 1
	local list = table.clone(warnings.value)
	table.insert(list, 1, {
		id = warningCount,
		at = math.round(os.clock() * 1000),
		level = level,
		message = message,
		component = componentNameIn(message),
	})
	while #list > MAX_WARNINGS do
		table.remove(list)
	end
	warnings.value = list
end

local function componentOf(instance: Instance?): Instance?
	local node = instance
	while node do
		if CollectionService:HasTag(node, TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function selectComponent(instance: Instance)
	selected.value = instance
	view.value = "components"
	picking.value = false
	searchOpen.value = false
	Selection:Set({ instance })
end

local function pickAt(position: Vector2): boolean
	local player = Players.LocalPlayer
	local gui = if player then player:FindFirstChildOfClass("PlayerGui") else nil
	if not gui then
		return false
	end
	local ok, hits = pcall(function()
		return (gui :: PlayerGui):GetGuiObjectsAtPosition(position.X, position.Y)
	end)
	if not ok then
		return false
	end
	for _, hit in hits do
		local found = componentOf(hit)
		if found then
			selectComponent(found)
			return true
		end
	end
	return false
end

local function snapshotSource(): string
	local out = { "return {", `\tcreatedAt = {os.time()},`, "\tcomponents = {" }
	for _, entry in entries.value do
		table.insert(
			out,
			string.format(
				"\t\t{ name = %q, path = %q, depth = %d, renders = %d, renderMs = %s, trigger = %q, props = %q, state = %q },",
				entry.name,
				entry.path,
				entry.depth,
				entry.renders,
				tostring(entry.renderMs),
				entry.trigger,
				entry.props,
				entry.state
			)
		)
	end
	table.insert(out, "\t},")
	table.insert(out, "\ttimeline = {")
	for i = #timeline.value, 1, -1 do
		local entry = timeline.value[i]
		table.insert(
			out,
			string.format(
				"\t\t{ at = %d, kind = %q, label = %q, detail = %q, ms = %q },",
				entry.at,
				entry.kind,
				entry.label,
				entry.detail,
				entry.ms
			)
		)
	end
	table.insert(out, "\t},")
	table.insert(out, "}")
	return table.concat(out, "\n")
end

local function exportSnapshot(): string
	if #entries.value > 0 then
		setSetting("lastSnapshot", snapshotSource())
	end
	local source = settings.lastSnapshot
	if source == "" then
		statusMessage.value = "Nothing to export yet"
	elseif RunService:IsRunning() then
		statusMessage.value = "Snapshot kept. Stop the game and press Export again to save it to ServerStorage"
	else
		local module = ServerStorage:FindFirstChild("RivueSnapshot")
		if not (module and module:IsA("ModuleScript")) then
			module = Instance.new("ModuleScript")
			module.Name = "RivueSnapshot"
			module.Parent = ServerStorage
		end
		(module :: ModuleScript).Source = source
		statusMessage.value = "Snapshot saved to ServerStorage.RivueSnapshot"
	end
	task.delay(4, function()
		statusMessage.value = ""
	end)
	return statusMessage.value
end

local function noteRender(instance: Instance)
	local times = renderTimes[instance] or {}
	renderTimes[instance] = times
	table.insert(times, os.clock())
	if #times > MAX_RENDER_TIMES then
		table.remove(times, 1)
	end
end

local function noteCause(instance: Instance)
	local cause = instance:GetAttribute("RivueTrigger")
	if type(cause) ~= "string" then
		return
	end
	local list = recentCauses[instance] or {}
	recentCauses[instance] = list
	table.insert(list, 1, {
		at = os.clock(),
		cause = cause,
		ms = (instance:GetAttribute("RivueRenderMs") :: number?) or 0,
	})
	if #list > MAX_CAUSES then
		table.remove(list)
	end
end

local function sparkline(instance: Instance): { number }
	local buckets = table.create(SPARK_BUCKETS, 0)
	local now = os.clock()
	local times = renderTimes[instance]
	if not times then
		return buckets
	end
	for _, at in times do
		local age = now - at
		if age < SPARK_BUCKETS then
			local index = SPARK_BUCKETS - math.floor(age)
			buckets[index] += 1
		end
	end
	return buckets
end

local function causesOf(instance: Instance): { Cause }
	return recentCauses[instance] or {}
end

local function watch(instance: Instance)
	if not watched[instance] then
		watched[instance] = instance.AttributeChanged:Connect(function(name)
			if name == "RivueEmit" then
				logEmit(instance)
			elseif name ~= "RivueEdit" then
				if name == "RivueRenders" then
					noteRender(instance)
					if settings.highlightUpdates then
						Highlight.flash(instance)
					end
				elseif name == "RivueTrigger" then
					noteCause(instance)
				end
				refreshSoon()
			end
		end)
	end
end

local function setPalette(next: Theme.Palette)
	palette.value = next
end

local function watchChannel(channel: Instance)
	if watched[channel] then
		return
	end
	watched[channel] = channel.AttributeChanged:Connect(function(name)
		if name == "RivueTimeline" then
			readTimeline(channel)
		elseif name == "RivueRoute" then
			readRoute(channel)
		end
	end)
	readTimeline(channel)
	readRoute(channel)
end

local function start(): () -> ()
	local conns = {
		LogService.MessageOut:Connect(logMessage),
		Selection.SelectionChanged:Connect(function()
			if picking.value then
				local found = componentOf(Selection:Get()[1])
				if found then
					selectComponent(found)
				end
			end
		end),
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if picking.value and input.UserInputType == Enum.UserInputType.MouseButton1 then
				pickAt(Vector2.new(input.Position.X, input.Position.Y))
			end
		end),
		CollectionService:GetInstanceAddedSignal(CHANNEL_TAG):Connect(watchChannel),
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
			watch(instance)
			refreshSoon()
		end),
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
			local conn = watched[instance]
			if conn then
				conn:Disconnect()
				watched[instance] = nil
			end
			baselines[instance] = nil
			refreshSoon()
		end),
	}
	local stopTheme = Theme.watch(setPalette)
	local ticking = true
	task.spawn(function()
		while ticking do
			task.wait(1)
			if not paused.value then
				tick.value += 1
			end
		end
	end)
	for _, instance in CollectionService:GetTagged(TAG) do
		watch(instance)
	end
	for _, channel in CollectionService:GetTagged(CHANNEL_TAG) do
		watchChannel(channel)
	end
	collect()
	return function()
		ticking = false
		stopTheme()
		Highlight.hide()
		Highlight.clearFlashes()
		for _, conn in conns do
			conn:Disconnect()
		end
		for instance, conn in watched do
			conn:Disconnect()
			watched[instance] = nil
		end
	end
end

--- Finds the script behind a RivueSource value like "ReplicatedStorage.UI.Shop:12"
local function resolveSource(source: string, root: Instance?): (LuaSourceContainer?, number?)
	local path, line = string.match(source, "^(.+):(%d+)$")
	if not path then
		return nil, nil
	end
	local ok, found = pcall(function(): Instance?
		local node: Instance? = root or game
		for name in string.gmatch(path, "[^%.]+") do
			node = (node :: Instance):FindFirstChild(name)
			if not node then
				return nil
			end
		end
		return node
	end)
	if ok and found and found:IsA("LuaSourceContainer") then
		return found :: LuaSourceContainer, tonumber(line)
	end
	return nil, nil
end

local function sorted(list: { Entry }, mode: SortMode): { Entry }
	if mode == "tree" then
		return list
	end
	local copy = table.clone(list)
	table.sort(copy, function(a, b)
		if mode == "renders" and a.renders ~= b.renders then
			return a.renders > b.renders
		elseif mode == "slowest" and a.renderMs ~= b.renderMs then
			return a.renderMs > b.renderMs
		end
		return a.name < b.name
	end)
	return copy
end

local function formatMs(ms: number): string
	return string.format("%.2f ms", ms)
end

local function causeText(trigger: string): string
	return if trigger == "mount"
		then "first render"
		elseif trigger == "parent" then "parent update"
		elseif trigger == "" then ""
		else `{trigger} changed`
end

local function isEditable(value: string): boolean
	return value == "true"
		or value == "false"
		or tonumber(value) ~= nil
		or (string.sub(value, 1, 1) == '"' and string.sub(value, -4) ~= '..."')
end

local function lines(text: string): { string }
	local list = {}
	for line in string.gmatch(text, "[^\n]+") do
		table.insert(list, line)
	end
	return list
end

local function splitPair(line: string): (string, string)
	local key, value = string.match(line, "^(.-) = (.*)$")
	return key or line, value or ""
end

local function tableFields(text: string): { { key: string, value: string } }
	local inner = string.match(text, "^{ (.*) }$")
	local fields = {}
	if not inner then
		return fields
	end
	local depth, quoted, start = 0, false, 1
	local function push(piece: string)
		local key, value = splitPair(piece)
		table.insert(fields, { key = key, value = value })
	end
	for i = 1, #inner do
		local c = string.sub(inner, i, i)
		if c == '"' then
			quoted = not quoted
		elseif not quoted and c == "{" then
			depth += 1
		elseif not quoted and c == "}" then
			depth -= 1
		elseif not quoted and depth == 0 and c == "," then
			push(string.sub(inner, start, i - 1))
			start = i + 2
		end
	end
	push(string.sub(inner, start))
	return fields
end

export type RouteInfo = {
	name: string,
	fields: { { section: string, key: string, value: string } },
	history: { { name: string, current: boolean } },
}

local function parseRoute(text: string): RouteInfo?
	if text == "" then
		return nil
	end
	local info: RouteInfo = { name = "", fields = {}, history = {} }
	for _, line in lines(text) do
		local key, value = splitPair(line)
		if key == "name" then
			info.name = value
		elseif key == "history" then
			for item in string.gmatch(value, "[^,%s]+") do
				local current = string.match(item, "^%[(.*)%]$")
				table.insert(info.history, { name = current or item, current = current ~= nil })
			end
		else
			for _, field in tableFields(value) do
				table.insert(info.fields, { section = key, key = field.key, value = field.value })
			end
		end
	end
	return info
end

local function findComponent(name: string): Instance?
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:GetAttribute("RivueComponent") == name then
			return instance
		end
	end
	return nil
end

local function ancestorsOf(instance: Instance): { Instance }
	local chain = {}
	local node = instance.Parent
	while node do
		if CollectionService:HasTag(node, TAG) then
			table.insert(chain, 1, node)
		end
		node = node.Parent
	end
	return chain
end

local visibleRows: { Entry } = {}
local focusFilter: (() -> ())? = nil

local function setDensity(value: Density)
	setSetting("density", value)
end

return {
	TAG = TAG,
	KINDS = KINDS,
	NETWORK_KINDS = NETWORK_KINDS,
	SORT_LABELS = SORT_LABELS,
	NEXT_SORT = NEXT_SORT,
	SPARK_BUCKETS = SPARK_BUCKETS,
	entries = entries,
	events = events,
	selected = selected,
	collapsed = collapsed,
	pinned = pinned,
	onlySlow = onlySlow,
	onlyChanged = onlyChanged,
	picking = picking,
	recording = recording,
	perfRows = perfRows,
	perfSlowest = perfSlowest,
	perfSpan = perfSpan,
	netEntries = netEntries,
	netTotals = netTotals,
	netState = netState,
	warnings = warnings,
	statusMessage = statusMessage,
	paused = paused,
	sortMode = sortMode,
	view = view,
	timeline = timeline,
	routeText = routeText,
	palette = palette,
	searchOpen = searchOpen,
	tick = tick,
	settings = settings,
	kindsShown = kindsShown,
	collect = collect,
	start = start,
	setSettingsStore = setSettingsStore,
	setSetting = setSetting,
	setPaused = setPaused,
	setPalette = setPalette,
	setDensity = setDensity,
	resetCounts = resetCounts,
	toggleCollapsed = toggleCollapsed,
	collapseAll = collapseAll,
	expandAll = expandAll,
	togglePinned = togglePinned,
	startRecording = startRecording,
	stopRecording = stopRecording,
	clearNetwork = clearNetwork,
	selectComponent = selectComponent,
	pickAt = pickAt,
	exportSnapshot = exportSnapshot,
	resolveSource = resolveSource,
	sorted = sorted,
	formatMs = formatMs,
	causeText = causeText,
	isEditable = isEditable,
	lines = lines,
	splitPair = splitPair,
	tableFields = tableFields,
	parseRoute = parseRoute,
	findComponent = findComponent,
	componentOf = componentOf,
	ancestorsOf = ancestorsOf,
	sparkline = sparkline,
	causesOf = causesOf,
	openScript = function(script: LuaSourceContainer, line: number): boolean
		if openScript then
			openScript(script, line)
			return true
		end
		return false
	end,
	setVisible = function(list: { Entry })
		visibleRows = list
	end,
	visible = function(): { Entry }
		return visibleRows
	end,
	setFilterFocus = function(fn: (() -> ())?)
		focusFilter = fn
	end,
	focusFilter = function()
		if focusFilter then
			focusFilter()
		end
	end,
	setOpenScript = function(handler: ((script: LuaSourceContainer, line: number) -> ())?)
		openScript = handler
	end,
}
