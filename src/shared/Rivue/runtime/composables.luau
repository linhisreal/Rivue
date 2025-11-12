--!strict
--!optimize 2
--!native

--[[
	composables.luau
	================
	
	Composition API utilities and helper functions.
	Provides Vue 3-compatible composables for enhanced DX.
	
	@module composables
	@author Rivue
	@version 1.0.0
]]

local componentModule = require(script.Parent:WaitForChild("component"))
local reactivity = require(script.Parent:WaitForChild("reactivity"))

local composables = {}

--- useAttrs: Returns non-declared props (fallthrough attributes)
--- Must be called during setup()
function composables.useAttrs(): { [string]: any }
	local instance = componentModule.getCurrentInstance()
	if not instance then
		error("useAttrs() must be called during setup()", 2)
	end
	return (instance :: any).attrs or {}
end

--- useSlots: Returns slots (child content) passed to component
--- Must be called during setup()
function composables.useSlots(): { any }
	local instance = componentModule.getCurrentInstance()
	if not instance then
		error("useSlots() must be called during setup()", 2)
	end
	return (instance :: any).slots or {}
end

--- defineModel: Creates a computed ref for v-model binding
--- Simplifies two-way binding between parent and child
function composables.defineModel(options: { name: string?, event: string? }?)
	local opts = (options or {}) :: { name: string?, event: string? }
	local propName = opts.name or "modelValue"
	local eventName = opts.event or ("update:" .. propName)
	
	return function(props: any, context: any)
		-- Create a writable computed-like ref using customRef
		local model = reactivity.customRef(function(track, trigger)
			return {
				get = function()
					track()
					return props[propName]
				end,
				set = function(value: any)
					context.emit(eventName, value)
					trigger()
				end
			}
		end)
		
		return model
	end
end

--- useTheme: Injects theme from ancestor component
--- Returns nil if no theme is provided
function composables.useTheme(): any?
	local instance = componentModule.getCurrentInstance()
	if not instance then
		return nil
	end
	
	-- Walk up the component tree looking for theme
	local current = instance
	while current do
		if (current :: any).provides and (current :: any).provides.theme then
			return (current :: any).provides.theme
		end
		current = (current :: any).parent
	end
	
	return nil
end

--- useStyles: Creates computed styles based on theme
--- Returns a computed ref that updates when theme changes
function composables.useStyles(styleFactory: (theme: any) -> { [string]: any })
	local themeRef = reactivity.ref(composables.useTheme())
	
	-- Watch for theme changes via reactive tracking
	local styles = reactivity.computed(function()
		return styleFactory(themeRef.value or {})
	end)
	
	return styles
end

return composables
