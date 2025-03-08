[Docs](README.md) › **DevTools**

# Rivue DevTools

A Studio plugin that lists the Rivue components on screen during a playtest. Click one to see its
props, its state and how many times it has rendered, and to select its root in the Explorer.

## Install

Download `RivueDevTools.rbxm` from the latest [release](https://github.com/linhisreal/Rivue/releases)
and put it in your Plugins folder (**Plugins → Plugins Folder** in Studio). Or build it with
`rojo build packages/rivue-devtools -o RivueDevTools.rbxm`.

## Use

1. Turn it on for your app, before mounting:

   ```lua
   app.config.devtools = game:GetService("RunService"):IsStudio()
   ```

2. Press Play, then click **Rivue → DevTools** in the Plugins toolbar.

The list shows each component indented under its parent, with its render count:

- **Orange** rows rendered again since the last refresh. A row that keeps flashing is a component
  re-rendering more than it should (see [Guide 15](guide/15-performance-in-depth.md)).
- **Filter by name** narrows the list, for big UIs.
- **Click** a row to see its props and state, and to select its root in the Explorer.
- The header shows how many components are mounted and the Rivue version the plugin was built
  with.

## How it works

A plugin can't read a game script's modules. So with `devtools` on, Rivue tags each component's
root Instance `RivueComponent` and writes its name, props and state to attributes after every
render. The plugin watches that tag and those attributes. Values are summarised: strings,
numbers, booleans and Instance names are shown, other values by their type.

When a component unmounts, Rivue removes its tag and attributes again, so the list only shows
what's on screen and pooled Instances don't carry old data.

The plugin's own window is built with Rivue, and is tested offline in
`tests/offline/DevTools.test.luau`.
