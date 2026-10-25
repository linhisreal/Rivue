[Docs](../README.md) › [API](../API.md) › **Built-in Components**

# Built-in Components

**Learn it:** [Guide 7: Effects and animation](../guide/07-effects-and-animation.md) · [Guide 9: Performance and debugging](../guide/09-performance-and-debugging.md)

Components that ship with Rivue. Use them like any component: `h(Rivue.Transition, props, children)`.
All examples assume:

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
local h = Rivue.h
```

- [Transition](#transition)
- [TransitionGroup](#transitiongroup)
- [KeepAlive](#keepalive)
- [Teleport](#teleport)
- [Suspense](#suspense)
- [VirtualList](#virtuallist)

---

## Transition

Animates a single child with TweenService when it appears and before it's removed.

- **Props**

  ```lua
  type TransitionProps = {
  	tweenInfo: TweenInfo?, -- used for both phases
  	enterInfo: TweenInfo?, -- overrides tweenInfo when entering
  	leaveInfo: TweenInfo?, -- overrides tweenInfo when leaving
  	from: { [string]: any }?, -- hidden state: applied before enter, tweened to on leave
  	enterFrom: { [string]: any }?, -- overrides `from` when entering
  	enterGoals: { [string]: any }?, -- explicit enter target (default: the element's own props)
  	leaveGoals: { [string]: any }?, -- explicit leave target (default: `from`)
  	appear: boolean?, -- also animate the first render (default false)
  	mode: "out-in"?, -- wait for the old child to leave before showing the new one
  	onBeforeEnter: ((el: Instance) -> ())?,
  	onAfterEnter: ((el: Instance) -> ())?,
  	onBeforeLeave: ((el: Instance) -> ())?,
  	onAfterLeave: ((el: Instance) -> ())?,
  }
  ```

- **Details**

  - **What triggers it.** Keep the `Transition` mounted and toggle its child (with `hIf`, an
    `if` expression, or a changing `key`).
  - **Entering.** The child starts at `from` and tweens back to its own prop values.
  - **Leaving.** The child tweens to `from`, stays on screen until the tween finishes, and is
    then destroyed. Leaving never blocks rendering.
  - **Component children.** A component child animates its root element.

  The same config can also be set per element with the `transition` prop. There, `enter = true`
  and `leave = true` turn each phase on.

- **Example**

  ```lua
  local Panel = Rivue.defineComponent(function()
  	local open = Rivue.ref(false)
  	return function()
  		return h("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
  			h("TextButton", {
  				Text = "Toggle",
  				onClick = function()
  					open.value = not open.value
  				end,
  			}),
  			h(Rivue.Transition, {
  				tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad),
  				from = { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.55) },
  			}, {
  				Rivue.hIf(
  					open.value,
  					h("Frame", {
  						AnchorPoint = Vector2.new(0.5, 0.5),
  						Position = UDim2.fromScale(0.5, 0.5),
  						Size = UDim2.fromOffset(300, 200),
  					})
  				),
  			}),
  		})
  	end
  end, { name = "Panel" })
  ```

  Switching between tabs, one at a time:

  ```lua
  local tab = Rivue.ref("Shop")

  h(Rivue.Transition, { mode = "out-in", tweenInfo = TweenInfo.new(0.15), from = { GroupTransparency = 1 } }, {
  	h("CanvasGroup", { key = tab.value, Size = UDim2.fromScale(1, 1) }),
  })
  ```

  The `transition` prop on one element:

  ```lua
  h("Frame", {
  	transition = {
  		tweenInfo = TweenInfo.new(0.3),
  		from = { BackgroundTransparency = 1 },
  		enter = true,
  		leave = true,
  	},
  })
  ```

---

## TransitionGroup

Animates items as they're added to or removed from a list.

- **Props**

  Same as [Transition](#transition) except `mode`, plus:

  ```lua
  type TransitionGroupProps = TransitionProps & {
  	tag: string?, -- wrap the items in this element (default: no wrapper)
  	tagProps: Props?, -- props for that element
  }
  ```

- **Details**

  Every child must have a unique `key`. Added items enter, removed items leave, and items that
  stay are moved without animating.

- **Example**

  ```lua
  local notifications = Rivue.ref({
  	{ id = 1, text = "Welcome!" },
  })

  h(Rivue.TransitionGroup, {
  	tag = "Frame",
  	tagProps = { Size = UDim2.new(0, 300, 1, 0), BackgroundTransparency = 1 },
  	tweenInfo = TweenInfo.new(0.2),
  	from = { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) },
  }, {
  	h("UIListLayout"),
  	Rivue.hFor(notifications.value, function(n)
  		return h("TextLabel", { key = n.id, Text = n.text, Size = UDim2.new(1, 0, 0, 40) })
  	end),
  })
  ```

---

## KeepAlive

Caches the component it wraps instead of destroying it when it's switched out.

- **Props**

  ```lua
  type KeepAliveProps = {
  	include: { string }?, -- only cache these component names
  	exclude: { string }?, -- never cache these
  	max: number?, -- most entries to keep, least recently used dropped first (default 10)
  }
  ```

- **Details**

  - **Switching away.** The cached component's Instances are detached (Parent = nil) instead of
    destroyed, and its state is kept.
  - **Switching back.** The same Instances are re-attached. Re-renders triggered while cached run
    when it comes back.
  - **Cache key.** Entries are cached by `key`, or by component when there's no key.

  Cached components get [`onActivated`](lifecycle.md#onactivated) and
  [`onDeactivated`](lifecycle.md#ondeactivated).

- **Example**

  ```lua
  local Inventory = Rivue.defineComponent({ name = "Inventory", render = function() return h("Frame") end })
  local Settings = Rivue.defineComponent({ name = "Settings", render = function() return h("Frame") end })

  local Menu = Rivue.defineComponent(function()
  	local tab = Rivue.ref("inventory")
  	return function()
  		return h(Rivue.KeepAlive, { max = 5, exclude = { "Settings" } }, {
  			if tab.value == "inventory" then h(Inventory) else h(Settings),
  		})
  	end
  end, { name = "Menu" })
  ```

---

## Teleport

Renders its children into another Instance, outside the component's own tree.

- **Props**

  ```lua
  type TeleportProps = {
  	to: Instance | () -> Instance?, -- where to render (must be parented)
  	disabled: boolean?, -- render in place instead
  	defer: boolean?, -- wait until the rest of the tree is mounted to resolve `to`
  }
  ```

- **Details**

  Use it for modals, tooltips and toasts that must escape a parent with `ClipsDescendants`, or
  that belong in another ScreenGui.
  - Children update in place.
  - If `to` changes, the children move to the new target.
  - Children are removed when the Teleport unmounts.
  - With `defer = true`, `to` can point at something rendered later in the same tree.

- **Example**

  ```lua
  local Players = game:GetService("Players")
  local overlay = Instance.new("ScreenGui")
  overlay.DisplayOrder = 100
  overlay.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

  local Shop = Rivue.defineComponent(function()
  	local confirming = Rivue.ref(false)
  	return function()
  		return h("Frame", { ClipsDescendants = true, Size = UDim2.fromOffset(300, 300) }, {
  			h("TextButton", {
  				Text = "Buy",
  				onClick = function()
  					confirming.value = true
  				end,
  			}),
  			h(Rivue.Teleport, { to = overlay }, {
  				Rivue.hIf(confirming.value, h("Frame", { Name = "ConfirmDialog" })),
  			}),
  		})
  	end
  end, { name = "Shop" })
  ```

---

## Suspense

Shows a fallback while async components inside it are loading.

- **Props**

  ```lua
  type SuspenseProps = {
  	fallback: VNode?, -- shown while loading (default: a "Loading..." label)
  	timeout: number?, -- ms before showing an error (default 5000)
  }
  ```

- **Details**

  - **While loading.** The children are mounted inside a hidden Frame, so async components can
    load, and the fallback shows on top.
  - **When everything has loaded,** the content becomes visible.
  - **On failure or timeout,** an error message is shown.

  Components made with [`defineAsyncComponent()`](component.md#defineasynccomponent) register
  themselves automatically.

- **Example**

  ```lua
  local Profile = Rivue.defineAsyncComponent(function()
  	task.wait(1) -- e.g. waiting for data
  	return Rivue.defineComponent({
  		name = "ProfileLoaded",
  		render = function()
  			return h("TextLabel", { Text = "Player profile" })
  		end,
  	})
  end)

  h(Rivue.Suspense, { fallback = h("TextLabel", { Text = "Loading profile..." }) }, {
  	h(Profile),
  })
  ```

---

## VirtualList

A ScrollingFrame that only renders the rows in view.

- **Props**

  ```lua
  type VirtualListProps<T> = {
  	items: { T }, -- plain or reactive array (required)
  	itemSize: number, -- row height in pixels, or width when horizontal (required)
  	render: (item: T, index: number) -> VNode, -- (required)
  	key: ((item: T, index: number) -> unknown)?, -- default: the index
  	overscan: number?, -- extra rows rendered above and below (default 2)
  	horizontal: boolean?,
  	-- Any other prop (Size, Position, ...) goes to the ScrollingFrame
  }
  ```

- **Details**

  - **Fixed size.** Every row has the same size, and Rivue sets each row's `Position` and `key`.
    Make rows fill the cross axis (`Size = UDim2.new(1, 0, 0, itemSize)`).
  - **Cost.** Scrolling re-renders only the rows coming into view, so a list of 10,000 items
    costs about as much as the ones on screen.

- **Example**

  ```lua
  local items = {}
  for i = 1, 5000 do
  	items[i] = { id = i, name = `Item {i}` }
  end

  h(Rivue.VirtualList, {
  	Size = UDim2.fromOffset(300, 400),
  	items = items,
  	itemSize = 40,
  	key = function(item)
  		return item.id
  	end,
  	render = function(item)
  		return h("TextLabel", { Size = UDim2.new(1, 0, 0, 40), Text = item.name })
  	end,
  })
  ```

---

[← Lifecycle Hooks](lifecycle.md) · [API reference](../API.md) · [Directives →](directives.md)
