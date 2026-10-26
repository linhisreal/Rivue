--!strict
--!optimize 2

-- Hot reload for edit mode: plugins, story previews and other tools that run in Studio while you
-- edit. A playtest runs a copy of the place that edits never reach, so this can't help there.
--
-- require() caches each ModuleScript, so new code is loaded from a fresh clone. Cloning the whole
-- watched folder means the component's own modules reload with it, while anything outside the
-- folder (Rivue included) stays shared.

export type HotReloadOptions = {
	-- Reload when any ModuleScript under this changes (default: just the module)
	watch: Instance?,
	-- Seconds to wait for more edits before reloading (default 0.15)
	debounce: number?,
	-- Swappable for tests
	require: ((module: ModuleScript) -> any)?,
}

export type HotReloadHandle = {
	reload: () -> (),
	stop: () -> (),
}

local function pathFrom(root: Instance, target: Instance): { string }?
	local path = {}
	local node: Instance? = target
	while node and node ~= root do
		table.insert(path, 1, node.Name)
		node = node.Parent
	end
	return if node == root then path else nil
end

local function follow(root: Instance, path: { string }): Instance?
	local node: Instance? = root
	for _, name in path do
		node = (node :: Instance):FindFirstChild(name)
		if not node then
			return nil
		end
	end
	return node
end

local function hotReload(
	module: ModuleScript,
	onReload: (exported: any) -> (),
	options: HotReloadOptions?
): HotReloadHandle
	local opts: HotReloadOptions = options or {}
	local root: Instance = opts.watch or module
	local path = pathFrom(root, module)
	assert(path, "hotReload: the module must be inside the watched folder")
	local load = opts.require or require
	local debounce = opts.debounce or 0.15

	local conns: { RBXScriptConnection } = {}
	local current: Instance? = nil
	local pending: thread? = nil
	local stopped = false

	local function reload()
		if stopped then
			return
		end
		local copy: Instance = root:Clone()
		-- Next to the original, so requires that climb out of the folder still find their targets
		copy.Name = `{root.Name}_HotReload`
		copy.Parent = root.Parent
		local target = follow(copy, path :: { string })
		local ok, result = pcall(load, target :: ModuleScript)
		if not ok then
			copy:Destroy()
			warn(`[Rivue] Hot reload of {module:GetFullName()} failed: {result}`)
			return
		end
		if current then
			current:Destroy()
		end
		current = copy
		local called, err = pcall(onReload :: (any) -> ...any, result)
		if not called then
			warn(`[Rivue] Hot reload callback failed: {err}`)
		end
	end

	local function schedule()
		if pending then
			task.cancel(pending)
		end
		pending = task.delay(debounce, function()
			pending = nil
			reload()
		end)
	end

	local function watchScript(inst: Instance)
		if inst:IsA("LuaSourceContainer") then
			table.insert(conns, (inst :: any):GetPropertyChangedSignal("Source"):Connect(schedule))
		end
	end

	watchScript(root)
	for _, d in root:GetDescendants() do
		watchScript(d)
	end
	table.insert(
		conns,
		root.DescendantAdded:Connect(function(d)
			watchScript(d)
			schedule()
		end)
	)
	table.insert(conns, root.DescendantRemoving:Connect(schedule))

	return {
		reload = reload,
		stop = function()
			stopped = true
			if pending then
				task.cancel(pending)
				pending = nil
			end
			for _, conn in conns do
				conn:Disconnect()
			end
			table.clear(conns)
			if current then
				current:Destroy()
				current = nil
			end
		end,
	}
end

return {
	hotReload = hotReload,
}
