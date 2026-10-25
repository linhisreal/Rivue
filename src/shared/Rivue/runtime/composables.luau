--!strict
--!optimize 2

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

function composables.useAttrs(): Props
	local instance = componentModule.getCurrentInstance()
	if not instance then
		error("useAttrs() must be called during setup()", 2)
	end
	return instance.attrs
end

function composables.useSlots(): { Child }
	local instance = componentModule.getCurrentInstance()
	if not instance then
		error("useSlots() must be called during setup()", 2)
	end
	return instance.slots
end

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

--- styleFactory gets an empty table when no theme is provided
function composables.useStyles<Theme, Styles>(styleFactory: (theme: Theme) -> Styles): ComputedRef<Styles>
	local themeRef = reactivity.ref(composables.useTheme() :: Theme?)

	return reactivity.computed(function(): Styles
		return styleFactory(themeRef.value or ({} :: any))
	end)
end

return composables
