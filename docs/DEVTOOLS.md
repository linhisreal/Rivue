[Docs](README.md) › **DevTools**

# Rivue DevTools

A Studio plugin that lists the Rivue components on screen during a playtest. Click one to see its
props, its state and how many times it has rendered, and to select its root in the Explorer.

## Install

Download `RivueDevTools.rbxm` from the latest [release](https://github.com/linhisreal/Rivue/releases)
and put it in your Plugins folder (**Plugins → Plugins Folder** in Studio). Or build it with
`rojo build plugin.project.json -o RivueDevTools.rbxm`.

## Use

1. Turn it on for your app, before mounting:

   ```lua
   app.config.devtools = game:GetService("RunService"):IsStudio()
   ```

2. Press Play, then click **Rivue → DevTools** in the Plugins toolbar.

The list shows each component indented under its parent, with its render count. A count that
keeps climbing is a component re-rendering more than it should (see
[Guide 15](guide/15-performance-in-depth.md)).

## How it works

A plugin can't read a game script's modules. So with `devtools` on, Rivue tags each component's
root Instance `RivueComponent` and writes its name, props and state to attributes after every
render. The plugin watches that tag and those attributes. Values are summarised: strings,
numbers, booleans and Instance names are shown, other values by their type.

The plugin's own window is built with Rivue.
