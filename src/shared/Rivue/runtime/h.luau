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

type VNode = {
	type: string | any,
	props: { [string]: any }?,
	children: { any },
	key: any?,
	_uid: number | {},
}

local debugModule = require(script.Parent:WaitForChild("debug"))
local utils = require(script.Parent:WaitForChild("utils"))

--- Normalizes children to an array format
--- @param children any -- Child nodes (can be string, number, table, function, or nil)
--- @return { any } -- Normalized array of children
local function nomalizeChildren(children: any): { any }
	if children == nil then
		return {}
	end
	local t = type(children)
	if t == "string" or t == "number" then
		return { tostring(children) }
	end
	if t == "table" then
		return children
	end
	if t == "function" then
		return { children }
	end
	return { tostring(children) }
end

local vnodeIdCounter: number = 0

--- Creates a virtual DOM node
--- @param type_ string | any -- Element type (string for DOM elements, table/function for components)
--- @param props { [string]: any }? -- Element properties and attributes
--- @param children any -- Child nodes
--- @return VNode -- Virtual DOM node
local function h(type_: string | any, props: { [string]: any }?, children: any): VNode
	if props == nil then
		props = {}
	end
	local ch = nomalizeChildren(children)
	vnodeIdCounter = vnodeIdCounter + 1

	local propCount = 0
	if props then
		for _ in pairs(props) do
			propCount = propCount + 1
		end
	end

	local typeStr = type(type_) == "string" and type_ or (type(type_) == "table" and type_.__name or "function")
	debugModule.log("H", "Creating VNode", {
		type = typeStr,
		childCount = #ch,
		propCount = propCount,
		hasKey = props and props.key ~= nil,
		uid = vnodeIdCounter,
	})

	return {
		type = type_,
		props = props,
		children = ch,
		key = props and props.key,
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
--- @param list { any } -- List to map over
--- @param mapper (any, number) -> VNode? -- Mapping function
--- @return { VNode } -- Array of VNodes
local function hFor<T>(list: { T }, mapper: (T, number) -> VNode?): { VNode }
	debugModule.log("H", "Rendering list with hFor", { itemCount = #list })

	-- Profile list rendering for performance monitoring
	if utils.profiler.active then
		utils.profiler:start("hFor_" .. tostring(#list))
	end

	local out: { VNode } = {}
	for i, v in ipairs(list) do
		local node = mapper(v, i)
		if node then
			table.insert(out, node)
		end
	end

	if utils.profiler.active then
		utils.profiler:stop("hFor_" .. tostring(#list))
	end

	return out
end

--- Parallel list rendering helper for large lists (1000+ items)
--- Uses Parallel Luau for CPU-intensive rendering operations
--- Note: Actual parallel execution is handled in renderer.patchChildrenParallel
--- @param items any -- Array of items to render
--- @param mapper function -- Map function (item, index) -> VNode | nil
--- @param keyFn function? -- Optional key function (item) -> any
--- @return { VNode } -- Array of VNodes with __parallel marker
local function hForParallel(items: any, mapper: any, keyFn: any?): { any }
	debugModule.log("H", "Rendering large list with hForParallel", { itemCount = #items, hasKeyFn = keyFn ~= nil })

	-- Profile parallel list rendering
	if utils.profiler.active then
		utils.profiler:start("hForParallel_" .. tostring(#items))
	end

	local out = {}
	for i, item in ipairs(items) do
		local vnode = mapper(item, i)
		if vnode then
			if keyFn then
				vnode.key = keyFn(item)
			end
			table.insert(out, vnode)
		end
	end

	if utils.profiler.active then
		utils.profiler:stop("hForParallel_" .. tostring(#items))
	end
	-- Marker for renderer to use parallel patching
	out.__parallel = true
	return out
end

return {
	h = h,
	hIf = hIf,
	hFor = hFor,
	hForParallel = hForParallel,
}
