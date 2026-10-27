<p align="center">
  <img src="./assets/guide-icon.webp" width="128" height="128" alt="Rivue Guide logo">
</p>

<h1 align="center">Rivue Guide</h1>

<p align="center">
  Guide, API reference and examples for Rivue.
</p>

| | |
|---|---|
| [Guide](GUIDE.md) | Chapters 1–11 cover the framework, 12–16 the advanced topics |
| [Examples](../examples) | Todo list, inventory, modal, tabs, shop, HUD and a routed game menu, all tested |
| [API reference](API.md) | Every function, prop and component, with an example each |
| [Coming from Vue](VUE.md) | Template-to-Luau cheat sheet |
| [Coming from React-lua or Fusion](COMING-FROM-REACT.md) | API map and what works differently |
| [DevTools](DEVTOOLS.md) | A Studio plugin that shows the live component tree |
| [Architecture](ARCHITECTURE.md) | Renderer and reactivity internals, for contributors |

## I want to…

| I want to… | Learn it | Look it up | See it working |
|---|---|---|---|
| put a first component on screen | [Guide 1](guide/01-introduction.md) | [defineComponent()](api/component.md#definecomponent) | [Counter](../examples/components/Counter.luau) |
| keep state and update the UI | [Guide 2](guide/02-state.md) | [ref()](api/reactivity-core.md#ref), [computed()](api/reactivity-core.md#computed) | [Counter](../examples/components/Counter.luau) |
| add and remove items in a list | [Guide 2](guide/02-state.md#changing-lists), [3](guide/03-describing-ui.md#lists-and-keys) | [Array helpers](api/array.md), [hFor()](api/render-function.md#hfor) | [TodoList](../examples/components/TodoList.luau) |
| split a screen into components | [Guide 4](guide/04-components.md) | [props](api/component.md#props), [emits](api/component.md#emits) | [TodoList](../examples/components/TodoList.luau) |
| make a panel, card or modal that takes content | [Guide 4](guide/04-components.md#slots-passing-ui-into-a-component) | [Slots](api/component.md#slots) | [Modal](../examples/components/Modal.luau) |
| read text the player types | [Guide 5](guide/05-forms-and-input.md) | [Element props: model](api/render-function.md#element-props) | [TodoList](../examples/components/TodoList.luau) |
| style things consistently | [Guide 6](guide/06-styling-and-layout.md#style-classes) | [app:styles()](api/application.md#appstyles) | [Demo app](../dev/Demo) |
| lay out rows, columns and grids | [Guide 6](guide/06-styling-and-layout.md#layout-without-positions) | [Element props: layout](api/render-function.md#element-props) | [Tabs](../examples/components/Tabs.luau) |
| support phones and controllers | [Guide 6](guide/06-styling-and-layout.md#input-type-screen-size-and-safe-area) | [Roblox composables](api/roblox.md) | [Hud](../examples/components/Hud.luau) |
| run code when something changes | [Guide 7](guide/07-effects-and-animation.md) | [watch()](api/reactivity-core.md#watch) | [Hud](../examples/components/Hud.luau) |
| animate things in and out | [Guide 7](guide/07-effects-and-animation.md#animation) | [Transition](api/builtins.md#transition) | [Modal](../examples/components/Modal.luau) |
| share state across the game | [Guide 8](guide/08-state-and-server.md), [14](guide/14-state-architecture.md) | [provide()](api/component.md#provide), [readonly()](api/reactivity-core.md#readonly) | |
| load data from the server | [Guide 8](guide/08-state-and-server.md#talking-to-the-server) | [Remote](api/remote.md) | [Shop](../examples/components/Shop.luau) |
| show a long list fast | [Guide 9](guide/09-performance-and-debugging.md), [15](guide/15-performance-in-depth.md) | [VirtualList](api/builtins.md#virtuallist) | [Inventory](../examples/components/Inventory.luau) |
| organise files once there are many screens | [Guide 10](guide/10-organising-a-project.md) | [components](api/component.md#components) | [Demo app](../dev/Demo) |
| close a menu with Escape or the B button | [Guide 5](guide/05-forms-and-input.md#keyboard-and-gamepad-shortcuts) | [useKeybind()](api/roblox.md#usekeybind) | |
| translate text into the player's language | | [useTranslator()](api/roblox.md#usetranslator) | |
| load more when the player scrolls to the end | | [useScroll()](api/roblox.md#usescroll) | |
| show a 3D item in a shop or inventory | | [ViewportModel](api/builtins.md#viewportmodel) | |
| check my code follows the conventions | [Guide 11](guide/11-style-rules.md) | | |
| reuse logic between components | [Guide 12](guide/12-writing-composables.md) | [toValue()](api/reactivity-utilities.md#tovalue), [onScopeDispose()](api/reactivity-advanced.md#onscopedispose) | |
| build tabs, menus or modals that fit together | [Guide 13](guide/13-advanced-components.md) | [provide()](api/component.md#provide), [Teleport](api/builtins.md#teleport) | [Tabs](../examples/components/Tabs.luau) |
| move between screens with a back button | [Guide 17](guide/17-screens-and-navigation.md) | [RivueRouter](api/router.md) | [GameMenu](../examples/components/GameMenu.luau) |
| test my UI | [Guide 16](guide/16-testing-ui.md) | [testing.trigger()](api/utilities.md#testingtrigger) | |
| find out why something broke | [Guide 9](guide/09-performance-and-debugging.md#debugging) | [Utilities and debugging](api/utilities.md) | |
