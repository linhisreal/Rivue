--!strict
--!optimize 2

-- Composition helpers for setup(): useAttrs, useSlots, defineModel, useTheme and useStyles.

local Types = require("./types")
local componentModule = require("./component")
local reactivity = require("./reactivity")

type Props = Types.Props
type Child = Types.Child
type Ref<T> = Types.Ref<T>
type ComputedRef<T> = Types.ComputedRef<T>
type SetupContext = Types.SetupContext

export type ModelOptions = {
	--- Prop holding the value (default "modelValue")
	name: string?,
	--- Event emitted on write (default "update:<name>")
	event: string?,
}

local composables = {}

--- Undeclared props (fallthrough attrs) of the current component. Call in setup()
function composables.useAttrs(): Props
	local instance = componentModule.getCurrentInstance()
	if not instance then
		error("useAttrs() must be called during setup()", 2)
	end
	return instance.attrs
end

--- Slot content passed to the current component. Call in setup()
function composables.useSlots(): { Child }
	local instance = componentModule.getCurrentInstance()
	if not instance then
		error("useSlots() must be called during setup()", 2)
	end
	return instance.slots
end

--- Returns a function that gives setup() a ref bound to the `model` prop
function composables.defineModel<T>(options: ModelOptions?): (props: Props, context: SetupContext) -> Ref<T>
	local opts: ModelOptions = options or {}
	local propName = opts.name or "modelValue"
	local eventName = opts.event or `update:{propName}`

	return function(props: Props, context: SetupContext): Ref<T>
		return reactivity.customRef(function(track, trigger)
			return {
				get = function(): T
					track()
					return props[propName]
				end,
				set = function(value: T)
					context.emit(eventName, value)
					trigger()
				end,
			}
		end)
	end
end

--- The nearest theme provided by an ancestor, or nil
function composables.useTheme<T>(): T?
	local current = componentModule.getCurrentInstance()

	while current do
		local theme = current.provides.theme
		if theme ~= nil then
			return theme :: T
		end
		current = current.parent
	end

	return nil
end

--- Styles computed from the current theme, recomputed when it changes
--- `styleFactory`: builds styles from the theme (empty table when none)
function composables.useStyles<Theme, Styles>(styleFactory: (theme: Theme) -> Styles): ComputedRef<Styles>
	local themeRef = reactivity.ref(composables.useTheme() :: Theme?)

	return reactivity.computed(function(): Styles
		return styleFactory(themeRef.value or ({} :: any))
	end)
end

return composables
