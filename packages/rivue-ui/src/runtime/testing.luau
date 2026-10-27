--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

local Types = require("./types")
local renderer = require("./renderer")
local hModule = require("./h")
local scheduler = require("./scheduler")

type ComponentDef = Types.ComponentDef
type VNode = Types.VNode

export type TextMatch = string | (text: string) -> boolean

export type Screen = {
	container: Instance,
	app: any,
	getByText: (text: TextMatch) -> Instance,
	queryByText: (text: TextMatch) -> Instance?,
	getAllByText: (text: TextMatch) -> { Instance },
	getByName: (name: string) -> Instance,
	queryByName: (name: string) -> Instance?,
	unmount: () -> (),
}

local CLICK_HANDLERS = { "onClick", "onActivated", "onMouseButton1Click" }

local function textOf(inst: Instance): string?
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		return (inst :: TextLabel).Text
	end
	return nil
end

local function matches(text: string, match: TextMatch): boolean
	if type(match) == "function" then
		return match(text)
	end
	return text == match
end

local function describe(match: TextMatch): string
	return if type(match) == "string" then `"{match}"` else "a matching function"
end

local function render(component: ComponentDef | VNode, props: { [string]: any }?): Screen
	local vnode = if (component :: any).__is_component
		then hModule.h(component :: ComponentDef, props)
		else component :: VNode
	local container = Instance.new("Folder")
	container.Name = "RivueTestRoot"
	local app = renderer.createApp(vnode)
	app:mount(container)

	local function getAllByText(match: TextMatch): { Instance }
		local found = {}
		for _, inst in container:GetDescendants() do
			local text = textOf(inst)
			if text and matches(text, match) then
				table.insert(found, inst)
			end
		end
		return found
	end

	local function queryByText(match: TextMatch): Instance?
		local found = getAllByText(match)
		if #found > 1 then
			error(`[Rivue] Found {#found} elements with text {describe(match)}, expected one`, 2)
		end
		return found[1]
	end

	local function queryByName(name: string): Instance?
		for _, inst in container:GetDescendants() do
			if inst.Name == name then
				return inst
			end
		end
		return nil
	end

	return {
		container = container,
		app = app,
		getAllByText = getAllByText,
		queryByText = queryByText,
		getByText = function(match: TextMatch): Instance
			local found = queryByText(match)
			if not found then
				error(`[Rivue] No element with text {describe(match)}`, 2)
			end
			return found
		end,
		queryByName = queryByName,
		getByName = function(name: string): Instance
			local found = queryByName(name)
			if not found then
				error(`[Rivue] No element named "{name}"`, 2)
			end
			return found
		end,
		unmount = function()
			app:unmount()
			container:Destroy()
		end,
	}
end

--- Clicks a button the way the player would, then waits for the re-render
local function click(inst: Instance)
	for _, key in CLICK_HANDLERS do
		if renderer.hasHandler(inst, key) then
			renderer.trigger(inst, key)
			scheduler.nextTick()
			return
		end
	end
	error(`[Rivue] {inst:GetFullName()} has no click handler (onClick, onActivated or onMouseButton1Click)`, 2)
end

--- Types into a TextBox and presses Enter, then waits for the re-render
local function typeInto(box: Instance, text: string)
	assert(box:IsA("TextBox"), "typeInto expects a TextBox")
	local textBox = box :: TextBox
	textBox.Text = text
	if renderer.hasHandler(box, "onFocusLost") then
		renderer.trigger(box, "onFocusLost", true)
	end
	scheduler.nextTick()
end

return {
	render = render,
	click = click,
	typeInto = typeInto,
}
