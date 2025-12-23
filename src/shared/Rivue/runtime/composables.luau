--!strict
--!optimize 2

--[[
	composables.luau
	================
	
	Composition API utilities and helper functions.
	Provides Vue 3-compatible composables for enhanced DX.
	
	@module composables
	@author Rivue
	@version 1.0.0
]]

local Types = require(script.Parent:WaitForChild("types"))
local componentModule = require(script.Parent:WaitForChild("component"))
local reactivity = require(script.Parent:WaitForChild("reactivity"))

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

--- useAttrs: Returns non-declared props (fallthrough attributes)
--- Must be called during setup()
function composables.useAttrs(): Props
	local instance = componentModule.getCurrentInstance()
	if not instance then
		error("useAttrs() must be called during setup()", 2)
	end
	return instance.attrs
end

--- useSlots: Returns slots (child content) passed to component
--- Must be called during setup()
function composables.useSlots(): { Child }
	local instance = componentModule.getCurrentInstance()
	if not instance then
		error("useSlots() must be called during setup()", 2)
	end
	return instance.slots
end

--- defineModel: Creates a writable ref for v-model style two-way binding
--- Reads the prop, and writes emit the update event to the parent
--- @param options ModelOptions? -- Prop and event names
--- @return (props: Props, context: SetupContext) -> Ref<T> -- Call inside setup with (props, ctx)
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

--- useTheme: Injects theme from ancestor component
--- Returns nil if no theme is provided
--- @return T? -- Provided theme (caller states its shape via the type argument)
function composables.useTheme<T>(): T?
	local current = componentModule.getCurrentInstance()

	-- Walk up the component tree looking for theme
	while current do
		local theme = current.provides.theme
		if theme ~= nil then
			return theme :: T
		end
		current = current.parent
	end

	return nil
end

--- useStyles: Creates computed styles based on theme
--- Returns a computed ref that updates when theme changes
--- @param styleFactory (theme: Theme) -> Styles -- Builds styles from the theme (empty table when none)
--- @return ComputedRef<Styles> -- Computed styles
function composables.useStyles<Theme, Styles>(styleFactory: (theme: Theme) -> Styles): ComputedRef<Styles>
	local themeRef = reactivity.ref(composables.useTheme() :: Theme?)

	return reactivity.computed(function(): Styles
		return styleFactory(themeRef.value or ({} :: any))
	end)
end

return composables
