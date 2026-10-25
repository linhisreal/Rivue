[Docs](../README.md) › [Guide](../GUIDE.md) › **16. Testing UI**

# 16. Testing UI

**You'll learn:** how to test composables on their own, how to mount a component in a test and
click its buttons, why `Rivue.nextTick()` matters, and what can't be tested from a script.

The examples use plain `assert`, so they work in any test runner (TestEZ, Jest Lua, or a Script
that runs them in Studio).

## What to test where

| What | How | Speed |
|---|---|---|
| Logic: rules, limits, sorting, what happens on save | Call the composable or store in an `effectScope` | Fastest, no Instances |
| A component: it shows the right thing and reacts to clicks | Mount it into a Frame, use `Rivue.testing.trigger` | Fast |
| Player input: dragging, click outside, gamepad | Play-test it | By hand |

Push as much as you can into the first row. A composable is a function: give it values, call it,
check what it returns. This is the main reason for [Guide 12](12-writing-composables.md).

## Testing a composable

Here's a stepper for a "buy how many" picker. It clamps the amount and says which buttons are
usable:

```lua
local function useStepper(options: { min: number, max: number, start: number? })
	local value = Rivue.ref(options.start or options.min)
	local canDecrease = Rivue.computed(function()
		return value.value > options.min
	end)
	local canIncrease = Rivue.computed(function()
		return value.value < options.max
	end)
	return {
		value = value,
		canDecrease = canDecrease,
		canIncrease = canIncrease,
		increase = function()
			if canIncrease.value then
				value.value += 1
			end
		end,
		decrease = function()
			if canDecrease.value then
				value.value -= 1
			end
		end,
	}
end
```

Run it inside an `effectScope`, so its computeds and watchers are cleaned up when the test ends:

```lua
local scope = Rivue.effectScope()
local stepper = scope:run(function()
	return useStepper({ min = 1, max = 3 })
end)

stepper.increase()
stepper.increase()
stepper.increase() -- already at 3, does nothing
assert(stepper.value.value == 3)
assert(stepper.canIncrease.value == false)
assert(stepper.canDecrease.value == true)

scope:stop()
```

Refs and computeds update right away, so no waiting is needed.

### Watchers need `nextTick()`

Watchers are different. They run after the current batch of changes, not on each change. This
composable saves settings whenever they change:

```lua
local function useAutosave(settings, save: (any) -> ())
	Rivue.watch(settings, function(value)
		save(value)
	end, { deep = true })
end
```

The test changes the volume twice and expects **one** save, with the last value:

```lua
local saves = {}
local settings = Rivue.reactive({ music = true, volume = 50 })

local scope = Rivue.effectScope()
scope:run(function()
	useAutosave(settings, function(value)
		table.insert(saves, value.volume)
	end)
end)

settings.volume = 60
settings.volume = 70
assert(#saves == 0) -- not yet: the watcher hasn't run
Rivue.nextTick()
assert(#saves == 1 and saves[1] == 70) -- one save, with the latest value

scope:stop()
settings.volume = 80
Rivue.nextTick()
assert(#saves == 1) -- stopped with the scope
```

The last three lines test something easy to get wrong: a composable that keeps running after its
component is gone.

## Testing a component

To test a component, mount it into a Frame that isn't in the game. It still builds real
Instances, so you can read their `Text`, `Visible` and so on, just like a player would see them.

A small helper keeps tests short. It mounts a component and returns a `find` that looks up
elements by `Name`:

```lua
local h = Rivue.h

local function mountForTest(component, props: { [string]: any }?)
	local root = Instance.new("Frame")
	local app = Rivue.mount(h(component, props), root)
	local function find(name: string): any
		for _, child in root:GetDescendants() do
			if child.Name == name then
				return child
			end
		end
		error(`no element named {name}`, 2)
	end
	return app, find
end
```

Give the elements you test a `Name`. It's also what you'll see in the Explorer, so it helps when
debugging too.

Here's a component built on `useStepper`. It emits `change` with the new amount:

```lua
local QuantityPicker = Rivue.defineComponent({
	name = "QuantityPicker",
	props = {
		max = { type = "number", default = 10 },
	},
	emits = { "change" },
	setup = function(props, ctx)
		local stepper = useStepper({ min = 1, max = props.max })
		local function change(step: () -> ())
			step()
			ctx.emit("change", stepper.value.value)
		end
		return {
			value = stepper.value,
			canIncrease = stepper.canIncrease,
			canDecrease = stepper.canDecrease,
			increase = function()
				change(stepper.increase)
			end,
			decrease = function()
				change(stepper.decrease)
			end,
		}
	end,
	render = function(ctx)
		return h("Frame", { layout = "horizontal", Size = UDim2.fromOffset(160, 40) }, {
			h("TextButton", { Name = "Minus", Text = "-", Active = ctx.canDecrease, onClick = ctx.decrease }),
			h("TextLabel", { Name = "Amount", Text = tostring(ctx.value) }),
			h("TextButton", { Name = "Plus", Text = "+", Active = ctx.canIncrease, onClick = ctx.increase }),
		})
	end,
})
```

### Clicking buttons

Scripts can't fire engine events like `Activated`. `Rivue.testing.trigger` calls the handler the
element has, as if the player clicked:

```lua
local changes = {}
local app, find = mountForTest(QuantityPicker, {
	max = 2,
	onChange = function(amount)
		table.insert(changes, amount)
	end,
})

assert(find("Amount").Text == "1")

Rivue.testing.trigger(find("Plus"), "onClick")
Rivue.testing.trigger(find("Plus"), "onClick") -- already at max
Rivue.nextTick()

assert(find("Amount").Text == "2")
assert(find("Plus").Active == false)
assert(changes[1] == 2 and changes[2] == 2) -- emits are sync, one per click

app:unmount()
```

Three things to notice:

- **`Rivue.nextTick()` before reading Instances.** Re-renders are batched like watchers. Without
  it, `Amount` would still say `1`.
- **Listeners are props.** `onChange` catches the `change` emit, the same way a parent would.
- **Unmount at the end.** Each test gets its own fresh component, and nothing leaks into the next.

### Typing text

Setting `Text` from a script works like the player typing, so `model` picks it up. Then trigger
`onFocusLost` with `true`, which means the player pressed Enter:

```lua
local NameInput = Rivue.defineComponent({
	name = "NameInput",
	emits = { "submit" },
	setup = function(_props, ctx)
		local draft = Rivue.ref("")
		return {
			draft = draft,
			submit = function(enterPressed: boolean)
				if enterPressed and draft.value ~= "" then
					ctx.emit("submit", draft.value)
					draft.value = ""
				end
			end,
		}
	end,
	render = function(ctx)
		return h("TextBox", { Name = "Input", model = "draft", onFocusLost = ctx.submit })
	end,
})

local submitted
local app, find = mountForTest(NameInput, {
	onSubmit = function(text)
		submitted = text
	end,
})

local box = find("Input")
box.Text = "Sword"
Rivue.testing.trigger(box, "onFocusLost", true)
Rivue.nextTick()

assert(submitted == "Sword")
assert(box.Text == "") -- cleared after submitting

app:unmount()
```

`trigger` errors if the element has no handler for that event. So a test that clicks the wrong
element fails loudly instead of passing for nothing.

## What a script can't test

`UserInputService` events (`InputBegan`, `LastInputTypeChanged`) and engine-only properties like
the camera's `ViewportSize` can't be set or fired from a script. That covers `vClickOutside`,
`vDrag`, `useInputType()` and `useViewportSize()`.

Don't try to fake them. Keep the decision in plain code you can test, and leave only the wiring
to the engine:

```lua
-- Testable: a plain function
local function columnsFor(width: number): number
	return if width < 600 then 1 elseif width < 1000 then 2 else 3
end

assert(columnsFor(400) == 1)
assert(columnsFor(1280) == 3)

-- Wiring, checked by play-testing on a phone and a PC
local Grid = Rivue.defineComponent(function()
	local viewport = Rivue.useViewportSize()
	local columns = Rivue.computed(function()
		return columnsFor(viewport.value.X)
	end)
	return function()
		return h("Frame", { layout = { grid = UDim2.new(1 / columns.value, -8, 0, 120), gap = 8 } })
	end
end, { name = "Grid" })
```

## Tips

- **Test what the player sees.** Check `Text`, `Visible` and emitted values, not a component's
  internal refs. Then refactoring doesn't break the tests.
- **One behaviour per test.** "Plus stops at max" is easier to fix when it fails than "the picker
  works".
- **Test the bug first.** When you fix a bug, write the test that fails without the fix.
- **Wait with `nextTick()`, not `task.wait()`.** `task.wait()` happens to work, but `nextTick()`
  waits exactly as long as needed and says why.

---

**Reference:** [testing.trigger()](../api/utilities.md#testingtrigger) ·
[nextTick()](../api/scheduler.md#nexttick) · [effectScope()](../api/reactivity-advanced.md#effectscope) ·
[mount()](../api/application.md#mount)

[← 15. Performance in depth](15-performance-in-depth.md) · [Guide contents](../GUIDE.md)
