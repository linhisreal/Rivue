--!strict
--!optimize 2
-- Copyright (c) 2025-2026 linhisreal (ThisisLinh)
-- Licensed under the PolyForm Noncommercial License 1.0.0 with the Rivue games permission.
-- See LICENSE.md for the terms.

export type PresetOptions = {
	duration: number?,
	easing: Enum.EasingStyle?,
	[string]: any,
}

local HIDDEN = {
	BackgroundTransparency = 1,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	ImageTransparency = 1,
	GroupTransparency = 1,
}

local OWN_OPTIONS = { duration = true, easing = true, direction = true, distance = true, fade = true, scale = true }

local function build(options: PresetOptions?, defaultDuration: number, from: { [string]: any }): { [string]: any }
	local opts: PresetOptions = options or {}
	local props: { [string]: any } = {
		tweenInfo = TweenInfo.new(
			opts.duration or defaultDuration,
			opts.easing or Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		from = from,
	}
	for k, v in opts do
		if not OWN_OPTIONS[k] then
			props[k] = v
		end
	end
	return props
end

local transitions = {}

--- Fades in and out. To fade a panel together with everything inside it, make the panel a
--- CanvasGroup: its GroupTransparency is faded too
function transitions.fade(options: PresetOptions?): { [string]: any }
	return build(options, 0.2, table.clone(HIDDEN))
end

--- Slides in from a side, fading by default. `direction` is where it moves to when entering
function transitions.slide(options: PresetOptions?): { [string]: any }
	local opts: PresetOptions = options or {}
	local distance: number = opts.distance or 24
	local direction: string = opts.direction or "up"
	local offset = if direction == "up"
		then UDim2.fromOffset(0, distance)
		elseif direction == "down" then UDim2.fromOffset(0, -distance)
		elseif direction == "left" then UDim2.fromOffset(distance, 0)
		else UDim2.fromOffset(-distance, 0)
	local from: { [string]: any } = if opts.fade == false then {} else table.clone(HIDDEN)
	from.Position = function(position: UDim2): UDim2
		return position + offset
	end
	return build(opts, 0.25, from)
end

--- Grows in from slightly smaller, fading by default. Looks best with AnchorPoint 0.5, 0.5, so it
--- grows from its centre
function transitions.pop(options: PresetOptions?): { [string]: any }
	local opts: PresetOptions = options or {}
	local scale: number = opts.scale or 0.9
	local from: { [string]: any } = if opts.fade == false then {} else table.clone(HIDDEN)
	from.Size = function(size: UDim2): UDim2
		return UDim2.new(size.X.Scale * scale, size.X.Offset * scale, size.Y.Scale * scale, size.Y.Offset * scale)
	end
	return build(opts, 0.18, from)
end

return table.freeze(transitions)
