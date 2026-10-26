--!strict
--!optimize 2

-- Pinia-style setup stores: shared state that lives outside any one component

local Types = require("./types")
local reactivity = require("./reactivity")

local IS_STUDIO = game:GetService("RunService"):IsStudio()

type Setup = () -> { [string]: any }

type Entry = {
	setup: Setup,
	store: any,
	scope: Types.EffectScope,
}

local entries: { [string]: Entry } = {}

--- Returns a function that gives the store with this id, creating it on first call. Every caller
--- gets the same store: refs read and write without `.value`, like a component's `ctx`
local function defineStore<T>(id: string, setup: () -> T): () -> T
	assert(type(id) == "string" and id ~= "", "defineStore expects an id string")
	assert(type(setup) == "function", "defineStore expects a setup function")
	return function(): T
		local entry = entries[id]
		if entry then
			if IS_STUDIO and entry.setup ~= setup then
				warn(`[Rivue] Two defineStore calls use the id '{id}', the first one wins`)
			end
			return entry.store
		end
		-- Detached, so watchers and computeds in the store outlive whichever component used it first
		local scope = reactivity.effectScope(true)
		local state = scope:run(function()
			return setup() :: any
		end)
		if type(state) ~= "table" then
			scope:stop()
			error(`[Rivue] Store '{id}' setup must return a table`, 2)
		end
		local result = state :: { [string]: any }
		local created: Entry = { setup = setup :: any, store = reactivity.proxyRefs(result), scope = scope }
		result["$id"] = id
		-- Stops its watchers and forgets it, so the next call builds a fresh one (handy in tests)
		result["$dispose"] = function()
			scope:stop()
			if entries[id] == created then
				entries[id] = nil
			end
		end
		entries[id] = created
		return created.store
	end
end

return {
	defineStore = defineStore,
}
