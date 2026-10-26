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
		-- Like Vue 3.4: with no model from the parent, the ref keeps its own value
		local localValue: T? = nil
		return reactivity.customRef(function(track, trigger)
			return {
				get = function(): T
					track()
					local passed = props[propName]
					if passed ~= nil then
						return passed
					end
					return localValue :: T
				end,
				set = function(value: T)
					localValue = value
					context.emit(eventName, value)
					trigger()
				end,
			}
		end)
	end
end

--- Vue's runtime useModel: a ref bound to a model prop of the component being set up
function composables.useModel<T>(props: Props, context: SetupContext, name: string?): Ref<T>
	return composables.defineModel({ name = name })(props, context)
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
	local provided = composables.useTheme() :: unknown

	return reactivity.computed(function(): Styles
		-- A theme provided as a ref is read here, so swapping its value rebuilds the styles
		local theme = reactivity.unref(provided :: any) :: Theme?
		return styleFactory(theme or ({} :: any))
	end)
end

export type AsyncOptions<T> = {
	--- Run once straight away (default true), with `args`
	immediate: boolean?,
	args: { any }?,
	--- `data` before the first result
	initial: T?,
}

export type AsyncState<T> = {
	data: Ref<T?>,
	loading: Ref<boolean>,
	error: Ref<string?>,
	run: (...any) -> (),
	refresh: () -> (),
}

--- Runs a yielding function, such as a RemoteFunction call, and keeps its result in refs. Only the
--- latest run's result lands, so a slow answer to an old request never overwrites a newer one
function composables.useAsync<T>(fn: (...any) -> T, options: AsyncOptions<T>?): AsyncState<T>
	local opts: AsyncOptions<T> = options or {}
	local data = reactivity.shallowRef(opts.initial :: T?)
	local loading = reactivity.ref(false)
	local err = reactivity.ref(nil :: string?)
	local latest = 0
	local lastArgs = table.pack(table.unpack(opts.args or {}))
	local disposed = false

	local function run(...: any)
		latest += 1
		local id = latest
		lastArgs = table.pack(...)
		loading.value = true
		err.value = nil
		task.spawn(function(...: any)
			local ok, result = pcall(fn, ...)
			if disposed or id ~= latest then
				return
			end
			if ok then
				data.value = result
			else
				err.value = tostring(result)
			end
			loading.value = false
		end, ...)
	end

	-- Results that arrive after the component is gone are dropped
	reactivity.onScopeDispose(function()
		disposed = true
	end, true)

	if opts.immediate ~= false then
		run(table.unpack(lastArgs, 1, lastArgs.n))
	end

	return {
		data = data,
		loading = loading,
		error = err,
		run = run,
		refresh = function()
			run(table.unpack(lastArgs, 1, lastArgs.n))
		end,
	}
end

return composables
