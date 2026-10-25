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
local componentModule = require(script.Parent:WaitForChild("component"))
local directives = require(script.Parent:WaitForChild("directives"))

const IS_STUDIO = game:GetService("RunService"):IsStudio()

local warnedMissingKey = false

local vnodeIdCounter = 0

-- Groups children without creating a wrapper Instance: h(Fragment, nil, { ... })
local Fragment: Types.FragmentType = table.freeze({ __fragment = true :: true, __name = "Fragment" :: "Fragment" })

--- True for a children list nested inside another list (a table that isn't a vnode)
--- @param child unknown -- Child entry
--- @return boolean -- Is a nested list
local function isNestedList(child: unknown): boolean
	return type(child) == "table" and (child :: { [unknown]: unknown }).type == nil
end

--- Copies a children list. A nested list ({ header, hFor(...), footer }) becomes a Fragment,
--- so its keyed diff stays separate and its siblings keep their positions.
--- @param list { [number]: unknown } -- Children list (may have holes from hIf)
--- @return { Child } -- New list
local function copyChildren(list: { [number]: unknown }): { Child }
	-- Copy so a reused array (like ctx.slots) can't change an already-rendered vnode
	local out = table.clone(list) :: { [number]: unknown }
	for i = 1, table.maxn(out) do
		local child = out[i]
		if isNestedList(child) then
			vnodeIdCounter += 1
			out[i] = {
				type = Fragment,
				props = {},
				children = copyChildren(child :: { [number]: unknown }),
				key = nil,
				_uid = vnodeIdCounter,
			}
		end
	end
	return out :: { Child }
end

--- Normalizes children to an array format
--- @param children unknown -- Child nodes (string, number, array, function, or nil)
--- @return { Child } -- Normalized array of children
local function normalizeChildren(children: unknown): { Child }
	if children == nil or children == false then
		return {}
	end
	local t = type(children)
	if t == "table" then
		-- A single vnode, not a list
		if (children :: { [unknown]: unknown }).type ~= nil then
			return { children :: VNode }
		end
		return copyChildren(children :: { [number]: unknown })
	elseif t == "function" then
		return { children :: () -> VNode? }
	end
	return { tostring(children) }
end

--- Splits a component's children table into default children and named slot functions
--- @param children { [unknown]: unknown } -- Children table passed to h()
--- @return { Child } -- Array part (default slot)
--- @return Types.Slots? -- Named slot functions, if any
local function splitSlots(children: { [unknown]: unknown }): ({ Child }, Types.Slots?)
	local slots: Types.Slots? = nil
	local list: { Child } = {}
	for key, value in children do
		if type(key) == "string" then
			if type(value) ~= "function" then
				error(`slot '{key}' must be a function`, 3)
			end
			local named = slots or {}
			slots = named
			named[key] = value :: Types.SlotFunction
		end
	end
	if not slots then
		return copyChildren(children :: { [number]: unknown }), nil
	end
	local positional: { [number]: unknown } = {}
	for i = 1, table.maxn(children :: { [number]: unknown }) do
		positional[i] = children[i]
	end
	list = copyChildren(positional)
	return list, slots
end

--- Turns a directive prop name into the registered directive: vClickOutside -> "click-outside"
--- @param key string -- Prop name
--- @return string? -- Directive name, nil when the prop isn't a registered directive
local function directiveName(key: string): string?
	-- "v" followed by an uppercase letter
	local second = string.byte(key, 2)
	if string.byte(key, 1) ~= 118 or not second or second < 65 or second > 90 then
		return nil
	end
	local name = string.lower(string.sub(key, 2, 2))
		.. string.gsub(string.sub(key, 3), "%u", function(c: string)
			return "-" .. string.lower(c)
		end)
	return if directives.get(name) then name else nil
end

--- Applies the props sugar h() understands: style, model and v* directive props
--- @param isElement boolean -- type is a ClassName
--- @param props Props -- Props as passed (not modified)
--- @return Props -- Props to store (a copy if anything changed)
local function expandProps(isElement: boolean, props: Props): Props
	local out: Props? = nil

	-- style = { base, isActive and active }: merged in order, the vnode's own props win
	local style = props.style
	if type(style) == "table" then
		local merged: Props = {}
		local list = if (style :: { unknown })[1] ~= nil or next(style) == nil then style else { style }
		for i = 1, table.maxn(list) do
			local entry = list[i]
			if type(entry) == "table" then
				for k, v in entry do
					merged[k] = v
				end
			end
		end
		for k, v in props do
			if k ~= "style" then
				merged[k] = v
			end
		end
		out = merged
	end

	local model = props.model
	if model ~= nil then
		local target: Props = out or table.clone(props)
		out = target
		target.model = nil
		local r = model :: Types.Ref<any>
		if isElement then
			-- Two-way Text binding, keeps any onTextChanged of its own
			local own = target.onTextChanged
			target.Text = r.value
			target.onTextChanged = function(text: string)
				r.value = text
				if own then
					own(text)
				end
			end
		else
			-- Same contract as defineModel(): modelValue + update:modelValue
			target.modelValue = r.value
			target["onUpdate:modelValue"] = function(value: unknown)
				r.value = value
			end
		end
	end

	if isElement then
		local bindings: { { name: string, value: unknown } }? = nil
		local bound: { string }? = nil
		for key, value in out or props do
			local name = if type(key) == "string" then directiveName(key) else nil
			if name then
				local list = bindings or {}
				local keys = bound or {}
				bindings, bound = list, keys
				table.insert(list, { name = name, value = value })
				table.insert(keys, key)
			end
		end
		if bindings and bound then
			local target: Props = out or table.clone(props)
			out = target
			for _, key in bound do
				target[key] = nil
			end
			local existing = target.__directives
			if type(existing) == "table" then
				for _, binding in existing do
					table.insert(bindings, binding)
				end
			end
			target.__directives = bindings
		end
	end

	return out or props
end

--- Creates a virtual DOM node
--- @param type_ VNodeType -- ClassName ("Frame"), component definition, or functional component
--- @param props Props? -- Element properties and attributes
--- @param children Children? -- Child nodes (array, single child, or text)
--- @return VNode -- Virtual DOM node
local function h(type_: VNodeType, propsIn: Props?, children: Types.Children?): VNode
	if type(type_) == "string" then
		-- Components registered on the rendering component (components = { ... })
		local owner = componentModule.getRenderingInstance()
		local localComponents = if owner then owner.type.components else nil
		local resolved = if localComponents then localComponents[type_] else nil
		if resolved then
			type_ = resolved
		end
	end
	local props: Props = propsIn or {}
	if propsIn and (props.style ~= nil or props.model ~= nil or type(type_) == "string") then
		props = expandProps(type(type_) == "string", props)
	end
	local ch: { Child }
	local slots: Types.Slots? = nil
	if type(type_) ~= "string" and type(children) == "table" and (children :: { [unknown]: unknown }).type == nil then
		-- Components can take named slots: { header = function(scope) ... end }
		ch, slots = splitSlots(children :: { [unknown]: unknown })
	else
		ch = normalizeChildren(children)
	end
	vnodeIdCounter += 1

	-- Hot path, only build the log payload when debugging
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
		slots = slots,
		key = props.key,
		_uid = vnodeIdCounter,
		-- String refs resolve on the component that rendered them
		_owner = if type(props.ref) == "string" then componentModule.getRenderingInstance() else nil,
	}
end

--- Merges props tables left to right. Event handlers are chained (both run), directives
--- and styles are combined, everything else is overwritten.
--- @param ... Props? -- Props tables (nil is skipped)
--- @return Props -- New props table
local function mergeProps(...: Props?): Props
	local out: Props = {}
	for i = 1, select("#", ...) do
		local props = select(i, ...)
		if not props then
			continue
		end
		for k, v in props do
			local existing = out[k]
			if existing == nil or existing == v then
				out[k] = v
			elseif k == "__directives" then
				local combined = table.clone(existing)
				table.move(v, 1, #v, #combined + 1, combined)
				out[k] = combined
			elseif k == "style" then
				out[k] = { existing, v }
			elseif
				type(k) == "string"
				and string.sub(k, 1, 2) == "on"
				and type(v) == "function"
				and type(existing) == "function"
			then
				out[k] = function(...)
					existing(...)
					v(...)
				end
			else
				out[k] = v
			end
		end
	end
	return out
end

--- True for vnodes made by h()
--- @param value unknown -- Anything
--- @return boolean -- Is a vnode
local function isVNode(value: unknown): boolean
	return type(value) == "table" and (value :: VNode)._uid ~= nil and (value :: VNode).type ~= nil
end

--- Copies a vnode, optionally merging extra props in (see mergeProps)
--- @param vnode VNode -- Vnode to copy (mounted or not)
--- @param extraProps Props? -- Props to merge over its own
--- @return VNode -- New, unmounted vnode
local function cloneVNode(vnode: VNode, extraProps: Props?): VNode
	local props = if extraProps then mergeProps(vnode.props, extraProps) else table.clone(vnode.props or {})
	local copy = h(vnode.type, props, nil)
	copy.children = table.clone(vnode.children)
	copy.slots = vnode.slots
	copy._owner = vnode._owner
	copy._transition = vnode._transition
	return copy
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

	-- Numeric loop so reactive arrays work (ipairs skips proxies)
	local out: { VNode } = table.create(count)
	for i = 1, count do
		local node = mapper(list[i], i)
		if node then
			table.insert(out, node)
		end
	end

	if IS_STUDIO and not warnedMissingKey and count > 1 and out[1] and out[1].key == nil then
		warnedMissingKey = true
		warn("[Rivue] hFor() items have no `key`, so reordering the list re-patches every item")
	end

	if profileName then
		utils.profiler:stop(profileName)
	end

	return out
end

local warnedParallel = false

--- @deprecated Use hFor() and set `key` in the mapper. Kept so existing code keeps working.
--- List rendering helper that also assigns keys
--- @param items { T } -- Array of items to render
--- @param mapper (item: T, index: number) -> VNode? -- Map function; nil skips the item
--- @param keyFn ((item: T) -> unknown)? -- Optional key function
--- @return { VNode } -- Array of VNodes
local function hForParallel<T>(
	items: { T },
	mapper: (item: T, index: number) -> VNode?,
	keyFn: ((item: T) -> unknown)?
): { VNode }
	if IS_STUDIO and not warnedParallel then
		warnedParallel = true
		warn("[Rivue] hForParallel() is deprecated, use hFor() and set `key` in the mapper")
	end

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

	return out
end

return {
	h = h,
	Fragment = Fragment,
	mergeProps = mergeProps,
	cloneVNode = cloneVNode,
	isVNode = isVNode,
	hIf = hIf,
	hFor = hFor,
	hForParallel = hForParallel,
}
