<div align="center">

# 🎨 Rivue

**A Vue.js-Inspired Reactive UI Framework for Roblox**

[![GPL-3.0 License](https://img.shields.io/badge/License-GPL--3.0-blue.svg?style=for-the-badge)](LICENSE)
[![Luau](https://img.shields.io/badge/Language-Luau-00A2FF.svg?style=for-the-badge&logo=lua)](https://luau-lang.org/)
[![Roblox](https://img.shields.io/badge/Platform-Roblox-E03A3E.svg?style=for-the-badge&logo=roblox)](https://www.roblox.com/)
[![GitHub release](https://img.shields.io/github/v/release/linhisreal/Rivue?style=for-the-badge)](https://github.com/linhisreal/Rivue/releases)

[![Tests](https://img.shields.io/badge/Tests-16%20Suites%20%7C%2045%2B%20Tests-success.svg?style=flat-square)](tests/)
[![Code Quality](https://img.shields.io/badge/Code%20Quality-A+-brightgreen.svg?style=flat-square)](https://github.com/linhisreal/Rivue)
[![Coverage](https://img.shields.io/badge/API%20Coverage-45%20APIs%20Validated-success.svg?style=flat-square)](tests/ApiValidation.test.luau)
[![Maintained](https://img.shields.io/badge/Maintained-Yes-green.svg?style=flat-square)](https://github.com/linhisreal/Rivue/commits/main)

[Features](#features) • [Installation](#installation) • [Quick Start](#quick-start) • [Documentation](#documentation) • [Examples](#examples) • [FAQ](#faq) • [Contributing](#contributing)

</div>

---

## Overview

Rivue brings the power and elegance of Vue.js's reactivity system to Roblox game development. Built with modern Luau, it provides a declarative, component-based approach to building dynamic UIs with automatic reactivity, virtual DOM diffing, and a comprehensive set of built-in features.

### Why Rivue?

<table>
<tr>
<td width="50%">

#### 🎯 **Developer Experience**
- **Familiar API**: If you know Vue.js, you already know Rivue
- **Type-Safe**: Built with strict Luau typing for better IDE support
- **Developer-Friendly**: Comprehensive lifecycle hooks and debugging tools
- **Well Documented**: Complete API docs with examples

</td>
<td width="50%">

#### ⚡ **Performance**
- **High Performance**: Virtual DOM with efficient diffing
- **Object Pooling**: Reduced garbage collection overhead
- **Reactive**: Automatic dependency tracking and updates
- **Optimized Updates**: Batched rendering with job scheduler

</td>
</tr>
<tr>
<td width="50%">

#### 🧩 **Architecture**
- **Component-Based**: Reusable, composable UI components
- **Composition API**: Modern composables (useAttrs, useSlots, etc.)
- **Modular**: Import only what you need
- **Extensible**: Custom directives and plugins

</td>
<td width="50%">

#### 🚀 **Production Ready**
- **Battle-Tested**: 16 comprehensive test suites
- **Stable API**: Semantic versioning
- **Active Development**: Regular updates and improvements
- **Community Support**: Open source with MIT license

</td>
</tr>
</table>

---

## Features

<details open>
<summary><h3>🎨 Core Reactivity & Rendering</h3></summary>

<table>
<tr><td>

**Reactivity System**
- `ref()` - Reactive primitives
- `reactive()` - Deep reactive objects  
- `computed()` - Derived state
- `watch()` / `watchEffect()` - Side effects
- `readonly()` - Immutable proxies

</td><td>

**Virtual DOM**
- Efficient diffing algorithm
- Automatic patching
- Component mounting/unmounting
- Lifecycle hooks
- Error boundaries

</td><td>

**Component API**
- `defineComponent()` - Component definition
- `h()` - Virtual node creation
- Props & emits
- Slots & attrs
- Provide/inject

</td></tr>
</table>

</details>

<details open>
<summary><h3>⚡ Advanced Features</h3></summary>

<table>
<tr><td width="33%">

**Async & Suspense**
- `defineAsyncComponent()` - Code splitting
- `Suspense` - Loading states
- `KeepAlive` - Component caching
- Error handling
- Timeout support

</td><td width="33%">

**Composition API**
- `useAttrs()` - Non-prop attributes
- `useSlots()` - Component slots
- `defineModel()` - Two-way binding
- `useTheme()` - Theme context
- `useStyles()` - Reactive styles

</td><td width="33%">

**Built-in Directives**
- `v-show` - Conditional visibility
- `v-focus` - Auto-focus
- `v-drag` - Draggable elements
- `v-memo` - Memoization
- `v-once` - Static content
- Custom directives API

</td></tr>
</table>

</details>

<details>
<summary><h3>🔧 Developer Tools & Optimization</h3></summary>

<table>
<tr><td>

**Performance**
- Job scheduler (micro/render/heartbeat)
- Object pooling
- Batched updates
- Lazy loading
- Tree shaking

</td><td>

**Roblox Integration**
- `attributeRef()` - Instance attributes
- `useTag()` - CollectionService
- `onRenderStepped()` - Frame hooks
- `onHeartbeat()` - Physics step
- `onStepped()` - Simulation step

</td><td>

**Utilities**
- `debounce()` / `throttle()`
- `nextTick()` / `nextFrame()`
- `iterArray()` - Reactive iteration
- Remote communication
- Debug helpers

</td></tr>
</table>

</details>

---

## Installation

<table>
<tr>
<th width="50%">📦 Using Wally (Recommended)</th>
<th width="50%">💾 Manual Installation</th>
</tr>
<tr>
<td>

**1. Add to `wally.toml`:**
```toml
[dependencies]
Rivue = "username/rivue@2.1.0"
```

**2. Install dependencies:**
```bash
wally install
```

**3. Require in your code:**
```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
```

✅ Automatic updates<br>
✅ Dependency management<br>
✅ Version control

</td>
<td>

**1. Download from [GitHub Releases](https://github.com/linhisreal/Rivue/releases)**

**2. Place in `ReplicatedStorage`:**
```
ReplicatedStorage
└── Rivue/
    ├── runtime/
    └── ...
```

**3. Require in your code:**
```lua
local Rivue = require(game.ReplicatedStorage.Rivue)
```

✅ No external tools<br>
✅ Direct integration<br>
✅ Full control

</td>
</tr>
</table>

---

<div align="center">

### 🚀 Quick Navigation

<table>
<tr>
<td align="center" width="25%">
<a href="#quick-start">
<img src="https://img.shields.io/badge/Quick_Start-4CAF50?style=for-the-badge&logo=rocket&logoColor=white" />
</a>
<br><sub>Get Started Fast</sub>
</td>
<td align="center" width="25%">
<a href="#documentation">
<img src="https://img.shields.io/badge/Docs-2196F3?style=for-the-badge&logo=book&logoColor=white" />
</a>
<br><sub>Full Documentation</sub>
</td>
<td align="center" width="25%">
<a href="#examples">
<img src="https://img.shields.io/badge/Examples-FF9800?style=for-the-badge&logo=code&logoColor=white" />
</a>
<br><sub>Code Examples</sub>
</td>
<td align="center" width="25%">
<a href="#faq">
<img src="https://img.shields.io/badge/FAQ-9C27B0?style=for-the-badge&logo=question&logoColor=white" />
</a>
<br><sub>Common Questions</sub>
</td>
</tr>
</table>

</div>

---

## Quick Start

### Hello World

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)

-- Create reactive state
local count = Rivue.ref(0)

-- Define a component
local App = Rivue.defineComponent({
    setup = function()
        local increment = function()
            count.value = count.value + 1
        end
        
        return {
            count = count,
            increment = increment
        }
    end,
    
    template = function(props, ctx)
        return Rivue.h("ScreenGui", {}, {
            Rivue.h("TextButton", {
                Size = UDim2.new(0, 200, 0, 50),
                Position = UDim2.new(0.5, -100, 0.5, -25),
                Text = "Count: " .. ctx.count.value,
                [Rivue.on.Activated] = ctx.increment
            })
        })
    end
})

-- Mount the app
Rivue.mount(App, game.Players.LocalPlayer.PlayerGui)
```

### Counter with Computed Values

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)

local App = Rivue.defineComponent({
    setup = function()
        local count = Rivue.ref(0)
        
        -- Computed property automatically updates
        local doubled = Rivue.computed(function()
            return count.value * 2
        end)
        
        local increment = function()
            count.value = count.value + 1
        end
        
        return { count = count, doubled = doubled, increment = increment }
    end,
    
    template = function(props, ctx)
        return Rivue.h("ScreenGui", {}, {
            Rivue.h("Frame", { Size = UDim2.new(1, 0, 1, 0) }, {
                Rivue.h("TextLabel", {
                    Text = string.format("Count: %d (Doubled: %d)", 
                        ctx.count.value, ctx.doubled.value),
                    Size = UDim2.new(0, 300, 0, 50)
                }),
                Rivue.h("TextButton", {
                    Text = "Increment",
                    Size = UDim2.new(0, 200, 0, 50),
                    Position = UDim2.new(0, 0, 0, 60),
                    [Rivue.on.Activated] = ctx.increment
                })
            })
        })
    end
})

Rivue.mount(App, game.Players.LocalPlayer.PlayerGui)
```

---

## Documentation

### Core API Reference

**📖 [Complete API Documentation](docs/API.md)** - Comprehensive guide covering all APIs

**🎓 [Runtime Reference](docs/RUNTIME_REFERENCE.md)** - Deep dive into internal architecture

### Key Concepts

#### Reactivity System

```lua
-- Refs: Reactive primitives
local count = Rivue.ref(0)
count.value = count.value + 1

-- Reactive objects
local state = Rivue.reactive({ user = "Alice", score = 100 })
state.score = state.score + 10

-- Computed values
local doubled = Rivue.computed(function()
    return count.value * 2
end)

-- Watchers
Rivue.watch(count, function(newVal, oldVal)
    print("Count changed from", oldVal, "to", newVal)
end)
```

#### Component Lifecycle

```lua
Rivue.defineComponent({
    setup = function()
        Rivue.onBeforeMount(function() print("Before mount") end)
        Rivue.onMounted(function() print("Mounted!") end)
        Rivue.onBeforeUpdate(function() print("Before update") end)
        Rivue.onUpdated(function() print("Updated!") end)
        Rivue.onBeforeUnmount(function() print("Before unmount") end)
        Rivue.onUnmounted(function() print("Unmounted!") end)
    end
})
```

#### Directives

```lua
-- Built-in directives
Rivue.h("TextBox", {
    ["v-focus"] = true,          -- Auto-focus on mount
    ["v-model"] = textRef,       -- Two-way binding
    ["v-show"] = isVisible,      -- Conditional visibility
    ["v-memo"] = { dep1, dep2 }, -- Memoize rendering
})

-- Custom directives
Rivue.directive("tooltip", {
    mounted = function(el, binding)
        -- Add tooltip logic
    end
})
```

---

## Examples

### Todo List Application

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)

local TodoApp = Rivue.defineComponent({
    setup = function()
        local todos = Rivue.ref({})
        local newTodoText = Rivue.ref("")
        
        local addTodo = function()
            if newTodoText.value ~= "" then
                table.insert(todos.value, {
                    id = #todos.value + 1,
                    text = newTodoText.value,
                    done = false
                })
                newTodoText.value = ""
            end
        end
        
        local toggleTodo = function(id)
            for _, todo in todos.value do
                if todo.id == id then
                    todo.done = not todo.done
                    break
                end
            end
        end
        
        return { todos = todos, newTodoText = newTodoText, addTodo = addTodo, toggleTodo = toggleTodo }
    end,
    
    template = function(props, ctx)
        return Rivue.h("ScreenGui", {}, {
            Rivue.h("Frame", { Size = UDim2.new(1, 0, 1, 0) }, {
                -- Input field
                Rivue.h("TextBox", {
                    PlaceholderText = "Enter todo...",
                    Text = ctx.newTodoText.value,
                    ["v-model"] = Rivue.vModelText(ctx.newTodoText)
                }),
                
                -- Add button
                Rivue.h("TextButton", {
                    Text = "Add",
                    [Rivue.on.Activated] = ctx.addTodo
                }),
                
                -- Todo list
                Rivue.hFor(ctx.todos.value, function(todo)
                    return Rivue.h("Frame", { key = todo.id }, {
                        Rivue.h("TextLabel", { 
                            Text = todo.text,
                            TextStrikethrough = todo.done
                        }),
                        Rivue.h("TextButton", {
                            Text = todo.done and "✓" or "○",
                            [Rivue.on.Activated] = function()
                                ctx.toggleTodo(todo.id)
                            end
                        })
                    })
                end)
            })
        })
    end
})

Rivue.mount(TodoApp, game.Players.LocalPlayer.PlayerGui)
```

### Async Data Fetching with Suspense

```lua
local Rivue = require(game.ReplicatedStorage.Rivue)

local AsyncUserProfile = Rivue.defineAsyncComponent({
    loader = function()
        -- Simulate API call
        task.wait(2)
        return Rivue.defineComponent({
            template = function()
                return Rivue.h("TextLabel", { Text = "User: Alice" })
            end
        })
    end,
    loadingComponent = Rivue.h("TextLabel", { Text = "Loading..." }),
    errorComponent = Rivue.h("TextLabel", { Text = "Error loading user" }),
    delay = 200,
    timeout = 5000
})

local App = Rivue.h(Rivue.Suspense, {
    fallback = Rivue.h("TextLabel", { Text = "Fetching data..." })
}, {
    Rivue.h(AsyncUserProfile)
})

Rivue.mount(App, game.Players.LocalPlayer.PlayerGui)
```

For more examples, check the [tests/](tests/) directory.

---

## Running Tests

Rivue uses Roblox's TestService for unit testing.

### Run All Tests

```lua
-- In Roblox Studio Command Bar or test script
local TestRunner = require(game.ReplicatedStorage.TestRunner)
TestRunner.runAll()
```

### Run Specific Test Suite

```lua
local TestRunner = require(game.ReplicatedStorage.TestRunner)
TestRunner.run("Reactivity")
```

### Run Without Studio

The suites also run with the standalone [Luau CLI](https://github.com/luau-lang/luau/releases) using small Roblox stand-ins (see `tests/offline/`). CI runs this on every push.

```bash
scripts/test-offline.sh                           # all suites
scripts/test-offline.sh tests/Reactivity.test.luau  # one suite
LUAU=/path/to/luau scripts/test-offline.sh        # if luau isn't on PATH
```

Needs `python3`. Engine behavior is simulated, so still check UI changes in Studio.

### Current Test Coverage

- ✅ **API Validation** (45 comprehensive API tests)
- ✅ **Reactivity System** (ref, reactive, computed, watch, etc.)
- ✅ **Component Lifecycle** (mount, update, unmount hooks)
- ✅ **Virtual DOM & Rendering** (h(), diffing, patching)
- ✅ **Directives** (focus, show, drag, memo, once, etc.)
- ✅ **Scheduler** (job queuing, prioritization)
- ✅ **Object Pooling** (instance reuse, memory optimization)
- ✅ **Composables** (useAttrs, useSlots, defineModel, etc.)
- ✅ **Roblox Integration** (attributeRef, useTag, RunService hooks)
- ✅ **Utilities** (debounce, throttle, nextTick, iterArray)
- ✅ **Remote Communication** (network utilities)
- ✅ **Debug Tools** (development mode, error handling)
- ✅ **Vue Features** (writable computed, watch sources, provide/inject, Fragment, nextTick, app plugins)

**Total: 17 test suites, plus an offline-only Remote server suite** ✅

---

## FAQ

<table>
<tr><td>

<details>
<summary>🚀 <b>Is Rivue production-ready?</b></summary>
<br>

Yes! Rivue is production-ready and stable:
- ✅ **16 comprehensive test suites** covering all features
- ✅ **45+ API validation tests** ensuring correctness
- ✅ **Battle-tested** in multiple Roblox projects
- ✅ **Semantic versioning** for predictable updates
- ✅ **Full documentation** with examples

</details>

</td></tr>
<tr><td>

<details>
<summary><b>How does Rivue compare to traditional Roblox UI development?</b></summary>
<br>

**Traditional Approach:**
```lua
-- Manual updates everywhere
label.Text = "Count: " .. count
count = count + 1
label.Text = "Count: " .. count  -- Must update manually
```

**Rivue Approach:**
```lua
-- Automatic reactivity
local count = Rivue.ref(0)
count.value = count.value + 1  -- UI updates automatically!
```

**Benefits:**
- 🎯 No manual UI updates
- 🔄 Automatic dependency tracking
- 🧩 Reusable components
- 🚀 Better performance with batched updates

</details>

</td></tr>
<tr><td>

<details>
<summary><b>Do I need to know Vue.js to use Rivue?</b></summary>
<br>

**No!** While Rivue is inspired by Vue.js, you don't need prior Vue experience:

- 📖 **Intuitive API** - Easy to learn from scratch
- 🎓 **Complete documentation** - Everything explained with examples
- 💡 **Familiar patterns** - Standard reactive programming concepts
- ✨ **Quick start guide** - Get running in minutes

However, Vue.js knowledge will help you get started even faster!

</details>

</td></tr>
<tr><td>

<details>
<summary><b>What's the performance impact?</b></summary>
<br>

Rivue is **highly optimized** and often **faster** than manual code:

**Optimizations:**
- 🎯 **Virtual DOM diffing** - Minimal actual DOM operations
- ♻️ **Object pooling** - Reduced garbage collection
- 📦 **Batched updates** - Multiple changes applied at once
- 🚀 **Job scheduler** - Prioritized rendering (micro/render/heartbeat)
- 🔄 **Lazy loading** - Load components only when needed
- 🌲 **Tree shaking** - Remove unused code

**Benchmarks:**
- Updates are batched and optimized
- Memory usage is minimized with pooling
- Frame rate stays smooth even with complex UIs

</details>

</td></tr>
<tr><td>

<details>
<summary><b>Can I use Rivue with existing Roblox projects?</b></summary>
<br>

**Absolutely!** Rivue supports **incremental adoption**:

**Migration Strategy:**
1. 🎯 **Start small** - Convert one UI component
2. 🔄 **Gradual migration** - Move features one at a time
3. 🤝 **Interoperability** - Works alongside existing code
4. 📦 **No rewrites** - Keep your current codebase

**Example:**
```lua
-- Existing code continues to work
local existingUI = script.Parent.OldUI

-- Add Rivue for new features
local newFeature = Rivue.createApp(MyComponent)
newFeature:mount(container)
```

</details>

</td></tr>
<tr><td>

<details>
<summary><b>Is TypeScript support planned?</b></summary>
<br>

**Yes!** TypeScript definitions are on the roadmap:

**Current State:**
- ✅ **Strict Luau typing** - Full type safety in Luau
- ✅ **IDE support** - IntelliSense and autocomplete
- ✅ **Type checking** - Catch errors at development time

**Planned for v2.2:**
- 📋 TypeScript `.d.ts` generation
- 📦 NPM package for roblox-ts users
- 🔧 Full roblox-ts integration

</details>

</td></tr>
<tr><td>

<details>
<summary><b>How do I report bugs or request features?</b></summary>
<br>

**We love feedback!** Here's how to contribute:

**Bug Reports:**
- 🐛 [Open a bug report](https://github.com/linhisreal/Rivue/issues/new?template=bug_report.md)
- Include code samples and error messages
- Describe expected vs actual behavior

**Feature Requests:**
- 💡 [Submit a feature request](https://github.com/linhisreal/Rivue/issues/new?template=feature_request.md)
- Explain your use case
- Describe the proposed API

**Community:**
- 💬 [Join discussions](https://github.com/linhisreal/Rivue/discussions)
- ⭐ Star the repo to show support
- 🤝 Contribute code via pull requests

</details>

</td></tr>
</table>

---

## Contributing

We welcome contributions from the community! Here's how you can help:

### Ways to Contribute

- **Report Bugs**: [Open an issue](https://github.com/linhisreal/Rivue/issues/new?template=bug_report.md)
- **Request Features**: [Submit a feature request](https://github.com/linhisreal/Rivue/issues/new?template=feature_request.md)
- **Improve Documentation**: Help make our docs clearer and more comprehensive
- **Submit Pull Requests**: Fix bugs or add features

### Development Setup

1. Clone the repository:

```bash
git clone https://github.com/linhisreal/Rivue.git
cd rivue
```

2. Install dependencies (if using Wally):

```bas
wally install
```

3. Open the project in Roblox Studio using Rojo:
   

```bash
rojo serve
```

1. Make your changes and test thoroughly

2. Submit a pull request with a clear description of your changes

### Code Style Guidelines

- Follow strict Luau typing
- Use descriptive variable and function names
- Add comments for complex logic
- Write tests for new features
- Keep functions focused and single-purpose
- Update documentation for API changes

---

## License

This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](LICENSE) file for details.

**Rivue** is free and open-source software under the **GPL-3.0 License**.

You are free to:

- ✅ Use the software for any purpose
- ✅ Study and modify the source code
- ✅ Distribute copies of the software
- ✅ Distribute modified versions

Under the conditions that you:

- 📋 **Disclose Source**: Make the complete source code available
- 📋 **Same License**: License derivative works under GPL-3.0
- 📋 **State Changes**: Document significant modifications
- 📋 **Include License**: Include the original GPL-3.0 license and copyright notices
- 📋 **No Additional Restrictions**: Don't impose further restrictions on recipients' rights

**Important**: This is a **copyleft license**. Any derivative work must also be distributed under the GPL-3.0 license and with source code available. For more details, see the [GNU GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html).

---

## Acknowledgments

- **Vue.js Team**: For the amazing reactive framework that inspired Rivue
- **Roblox**: For the Luau programming language and platform
- **Contributors**: Everyone who has contributed to making Rivue better

### Built With

- [Luau](https://luau-lang.org/) - The programming language
- [Rojo](https://rojo.space/) - Project management and sync
- [Aftman](https://github.com/LPGhatguy/aftman) - Toolchain manager

---

## Tech Stack

<div align="center">

<table>
<tr>
<td align="center" width="20%">
<img src="https://img.shields.io/badge/Luau-00A2FF?style=for-the-badge&logo=lua&logoColor=white" />
<br><b>Luau</b>
<br><sub>Language</sub>
</td>
<td align="center" width="20%">
<img src="https://img.shields.io/badge/Roblox-E03A3E?style=for-the-badge&logo=roblox&logoColor=white" />
<br><b>Roblox</b>
<br><sub>Platform</sub>
</td>
<td align="center" width="20%">
<img src="https://img.shields.io/badge/Rojo-E8274B?style=for-the-badge&logo=git&logoColor=white" />
<br><b>Rojo</b>
<br><sub>Build Tool</sub>
</td>
<td align="center" width="20%">
<img src="https://img.shields.io/badge/Aftman-1F1F1F?style=for-the-badge&logo=package&logoColor=white" />
<br><b>Aftman</b>
<br><sub>Toolchain</sub>
</td>
<td align="center" width="20%">
<img src="https://img.shields.io/badge/Vue.js-4FC08D?style=for-the-badge&logo=vue.js&logoColor=white" />
<br><b>Vue.js</b>
<br><sub>Inspiration</sub>
</td>
</tr>
</table>

</div>

---

## Support the Project

<div align="center">

If you find Rivue helpful, consider supporting its development:

[![Star on GitHub](https://img.shields.io/github/stars/linhisreal/Rivue?style=social)](https://github.com/linhisreal/Rivue)
[![Sponsor](https://img.shields.io/badge/Sponsor-red.svg?style=for-the-badge)](https://github.com/sponsors/linhisreal)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-yellow.svg?style=for-the-badge)](https://buymeacoffee.com/linhisreal)

</div>

### Ways to Support

- **Star the repository** to show your support
- **Report bugs** to help us improve
- **Improve documentation** for better developer experience
- **Contribute code** to add features or fix issues
- **Spread the word** on social media and developer communities
- **Sponsor the project** to fund continued development

---

## Links

- [Full Documentation](docs/API.md)
- [Issue Tracker](https://github.com/linhisreal/Rivue/issues)
- [Discussions](https://github.com/linhisreal/Rivue/discussions)
- [Releases](https://github.com/linhisreal/Rivue/releases)
- [Star History](https://star-history.com/#linhisreal/Rivue)

---

## Project Stats

<div align="center">

![GitHub stars](https://img.shields.io/github/stars/linhisreal/Rivue?style=for-the-badge&logo=github)
![GitHub forks](https://img.shields.io/github/forks/linhisreal/Rivue?style=for-the-badge&logo=github)
![GitHub watchers](https://img.shields.io/github/watchers/linhisreal/Rivue?style=for-the-badge&logo=github)

![GitHub issues](https://img.shields.io/github/issues/linhisreal/Rivue?style=for-the-badge)
![GitHub pull requests](https://img.shields.io/github/issues-pr/linhisreal/Rivue?style=for-the-badge)
![GitHub last commit](https://img.shields.io/github/last-commit/linhisreal/Rivue?style=for-the-badge)
![GitHub commit activity](https://img.shields.io/github/commit-activity/m/linhisreal/Rivue?style=for-the-badge)

</div>

### GitHub Activity

[![Star History Chart](https://api.star-history.com/svg?repos=linhisreal/Rivue&type=Date)](https://star-history.com/#linhisreal/Rivue&Date)

### Contributors

<div align="center">

<a href="https://github.com/linhisreal/Rivue/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=linhisreal/Rivue" />
</a>

*Made with [contrib.rocks](https://contrib.rocks)*

</div>

---

## Roadmap

### Version 2.2 (Planned)

- [ ] TypeScript definition file generation
- [ ] Developer tools integration
- [ ] Animation system improvements
- [ ] Performance profiler

### Version 3.0 (Future)

- [ ] Hot module replacement (HMR)
- [ ] Plugin system
- [ ] Official UI component library

---

<div align="center">

**Made with ❤️ by the Rivue community**

[⬆ Back to Top](#-rivue)

</div>
