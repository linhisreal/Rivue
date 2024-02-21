--!strict
--!optimize 2
--!native

--[[
	Hyperscript.luau
    ================
	
	Provides functions for creating virtual DOM nodes (VNodes).
	
	@module h

	@author Rivue
    
	@version 1.0.0
	
	Type Definitions:
    -----------------

		type VNode = {
			type: string | table | (props: table) -> VNode,
			props: { [string]: any }?,
			children: { VNode | string | (() -> VNode) },
			key: any?,
			_uid: {}
		}
	
	Public API:
    -----------
    
		h(type, props?, children?) -> VNode
			'Creates a virtual node representing a UI element'
			
		hIf(condition: boolean, vnode: VNode?) -> VNode?
			'Conditional rendering helper'
			
		hFor<T>(list: { T }, mapper: (T, number) -> VNode?) -> { VNode }
			'List rendering helper'
]]

local Types = require(script.Parent:WaitForChild("types"))

type VNode = Types.VNode
type VNodeType = Types.VNodeType
type Props = Types.Props
type Child = Types.Child

local debugModule = require(script.Parent:WaitForChild("debug"))
local utils = require(script.Parent:WaitForChild("utils"))

--- Normalizes children to an array format
--- @param children unknown -- Child nodes (string, number, array, function, or nil)
--- @return { Child } -- Normalized array of children
local function normalizeChildren(children: unknown): { Child }
	if children == nil then
		return {}
	end
	local t = type(children)
	if t == "table" then
		return children :: { Child }
	elseif t == "function" then
		return { children :: () -> VNode? }
	end
	return { tostring(children) }
end

local vnodeIdCounter = 0

--- Creates a virtual DOM node
--- @param type_ VNodeType -- ClassName ("Frame"), component definition, or functional component
--- @param props Props? -- Element properties and attributes
--- @param children Children? -- Child nodes (array, single child, or text)
--- @return VNode -- Virtual DOM node
local function h(type_: VNodeType, propsIn: Props?, children: Types.Children?): VNode
	local props: Props = propsIn or {}
	local ch = normalizeChildren(children)
	vnodeIdCounter += 1

	-- h() is the hottest call in the framework: never build log payloads unless debugging
	if debugModule.enabled then
		debugModule.log("H", "Creating VNode", {
			type = if type(type_) == "string" then type_ elseif type(type_) == "table" then type_.__name else "function",
			childCount = #ch,
			hasKey = props.key ~= nil,
			uid = vnodeIdCounter,
		})
	end

	return {
		type = type_,
		props = props,
		children = ch,
		key = props.key,
		_uid = vnodeIdCounter,
	}
end

--- Conditionally renders a VNode
--- @param cond boolean -- Condition to check
--- @param vnode VNode? -- VNode to render if condition is true
--- @return VNode? -- VNode if condition is true, nil otherwise
local function hIf(cond: boolean, vnode: VNode?): VNode?
	if cond then
		return vnode
	end
	return nil
end

--- Maps a list to VNodes
--- @param list { T } -- List to map over (plain or reactive array)
--- @param mapper (item: T, index: number) -> VNode? -- Mapping function; nil skips the item
--- @return { VNode } -- Array of VNodes
local function hFor<T>(list: { T }, mapper: (item: T, index: number) -> VNode?): { VNode }
	local count = #list
	if debugModule.enabled then
		debugModule.log("H", "Rendering list with hFor", { itemCount = count })
	end

	-- Profile list rendering for performance monitoring
	local profileName = if utils.profiler.active then `hFor_{count}` else nil
	if profileName then
		utils.profiler:start(profileName)
	end

	-- Numeric loop so reactive arrays work: ipairs() bypasses proxies (and their tracking) in Luau
	local out: { VNode } = table.create(count)
	for i = 1, count do
		local node = mapper(list[i], i)
		if node then
			table.insert(out, node)
		end
	end

	if profileName then
		utils.profiler:stop(profileName)
	end

	return out
end

--- List rendering helper for large lists that also assigns keys
--- (Kept for API compatibility; rendering is serial, see renderer.patchChildrenParallel.)
--- @param items { T } -- Array of items to render
--- @param mapper (item: T, index: number) -> VNode? -- Map function; nil skips the item
--- @param keyFn ((item: T) -> unknown)? -- Optional key function
--- @return { VNode } -- Array of VNodes
local function hForParallel<T>(
	items: { T },
	mapper: (item: T, index: number) -> VNode?,
	keyFn: ((item: T) -> unknown)?
): { VNode }
	local count = #items
	if debugModule.enabled then
		debugModule.log("H", "Rendering large list with hForParallel", { itemCount = count, hasKeyFn = keyFn ~= nil })
	end

	local out: { VNode } = table.create(count)
	for i = 1, count do
		local item = items[i]
		local vnode = mapper(item, i)
		if vnode then
			if keyFn then
				vnode.key = keyFn(item)
			end
			table.insert(out, vnode)
		end
	end

	-- (The old `out.__parallel = true` marker was never read, and it put a string key into
	-- the children array that every children loop then had to skip.)
	return out
end

return {
	h = h,
	hIf = hIf,
	hFor = hFor,
	hForParallel = hForParallel,
}
