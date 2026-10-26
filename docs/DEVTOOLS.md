[Docs](README.md) › **DevTools**

# Rivue DevTools

A Studio plugin that shows the Rivue components on screen while you playtest. Click one and you
get its props, its state, how many times it has rendered, how long the last render took and what
caused it, and its root selected in the Explorer.

![the DevTools window](images/devtools-window.svg)

## Install

Grab `RivueDevTools.rbxm` from the latest [release](https://github.com/linhisreal/Rivue/releases)
and drop it in your Plugins folder (**Plugins → Plugins Folder** in Studio). If you'd rather build
it yourself, run `rojo build packages/rivue-devtools -o RivueDevTools.rbxm`.

## Use

Your game has to opt in, before it mounts the app:

```lua
app.config.devtools = game:GetService("RunService"):IsStudio()
```

Then press Play and click **Rivue → DevTools** in the Plugins toolbar.

Every component shows up indented under its parent, with its render count next to it. A row
turns orange when that component rendered again since the last refresh, so a row that keeps
flashing is one re-rendering more than it should ([Guide 15](guide/15-performance-in-depth.md)
helps with that). A row turns red, with the time next to it, when its last render took 2 ms or
more. Big UI? Type in the filter box to narrow the list down by name. The header tells you how
many components are mounted, and which Rivue version the plugin was built with.

The details under the list say what caused the last render:

| It says | Meaning |
|---|---|
| `first render` | the component just mounted |
| `count changed` | a ref returned from `setup` as `count` |
| `bag.gems changed` | the `gems` key of a reactive table returned as `bag` |
| `props.title changed` | the parent passed a new `title` |
| `a computed or outside state changed` | a computed, or state from a store or module |
| `its parent updated it` | nothing it reads changed: new slots, or `forceUpdate` |

Writes in the same frame are batched into one render, so you can see up to three causes at once.
The time covers the render function and the patch, which includes any children mounted with it.

The buttons above the list:

- **Sort** cycles between the tree, most renders first, and slowest first.
- **Pause** freezes the list so you can read it while the UI keeps changing. **Resume** catches up.
- **Reset counts** starts every render count from zero. Reset, do one thing in the game, and you
  see exactly which components that one thing re-rendered.

## How it works

A plugin can't read a game script's modules, so the data has to travel some other way. With
`devtools` on, Rivue tags each component's root Instance `RivueComponent` and writes its name,
props, state, render count, render time and the cause of the render to attributes after every
render. The plugin just watches the tag and the attributes.

```mermaid
flowchart LR
    G["your game<br/>app.config.devtools = true"] -- "after every render" --> I["root Instance<br/>tag RivueComponent<br/>+ attributes"]
    I -- "tag and attribute signals" --> P["DevTools plugin"]
```

Values are summarised on the way. Strings, numbers, booleans and Instance names show as they are,
and anything else shows as its type (`table`, `UDim2`). When a component unmounts, Rivue removes
the tag and attributes again. The list only ever shows what's on screen, and pooled Instances
don't carry old data into their next life.

Writing those attributes costs an engine call per attribute per render, which is why it's off
unless you turn it on, and why the snippet above only turns it on in Studio.

The plugin's window is itself built with Rivue. It's tested offline in
`tests/offline/DevTools.test.luau`.
