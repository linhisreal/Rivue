[Docs](README.md) › **DevTools**

# Rivue DevTools

A Studio plugin that shows the Rivue components on screen while you playtest: what rendered, how
long it took and why, with props and state you can edit live.

![The DevTools window: the component tree, the Timeline tab and the Router tab](assets/diagrams/devtools-window.webp)

## Install

Grab `RivueDevTools.rbxm` from the latest release on the repo's Releases page and drop it in
your Plugins folder (**Plugins → Plugins Folder** in Studio). If you'd rather build
it yourself, run `rojo build packages/rivue-devtools -o RivueDevTools.rbxm`.

## Use

Your game has to opt in, before it mounts the app:

```lua
app.config.devtools = game:GetService("RunService"):IsStudio()
```

Then press Play and click **Rivue → DevTools** in the Plugins toolbar.

Components show up as a tree with their render counts. Click an arrow to fold a branch away.
Hover a row and the component is outlined on the game screen. Row colours:

- **orange**: rendered again since the last refresh. One that keeps flashing re-renders too
  often ([Guide 15](guide/15-performance-in-depth.md)).
- **red**: the last render took 2 ms or more.

Click a row and it's selected in the Explorer. Below the list you get:

- how long its last render took, and what caused it: `count changed`, `props.title changed`,
  `first render` or `parent update` (new slots or `forceUpdate`). A computed or a store shows as
  `a computed or outside state`.
- **Open source**, which opens the script that defined the component at the `defineComponent`
  line.
- its props, and its state. Numbers, strings and booleans in state are editable: type a new
  value, press Enter, and the game updates.
- the keys it provides, and the keys it injects.

Type in the filter box to show only components whose name matches. Their parents stay in the
list, so you can still see where each match sits.

The buttons:

- **Sort**: tree, most renders, or slowest first.
- **Pause**: freeze the list while the UI keeps changing.
- **Reset counts**: count from zero, do one thing in the game, and see what it re-rendered.

The **Events** tab lists every `emit` as it happens, newest first, with its arguments. Click one
to select the component that sent it.

The **Timeline** tab puts renders, emits, router navigations and RivueRemote requests in one list,
newest first, with the time and how long each took. It's the place to look when one click causes
more work than you expected.

The **Router** tab shows RivueRouter's current route: its name, params, query and meta, and the
history, with the current entry in brackets.

The window follows Studio's light or dark theme.

## How it works

A plugin can't read a game script's modules, so the data has to travel some other way. With
`devtools` on, Rivue tags each component's root Instance `RivueComponent` and writes its name,
props, state, render count, render time and the cause of the render to attributes after every
render, plus the latest `emit`. Each app also gets a `RivueDevTools` Configuration that holds the
timeline and the current route, which is how RivueRouter and RivueRemote reach the plugin. The
plugin watches the tags and the attributes. Edits go
the other way: the plugin sets a `RivueEdit` attribute, and Rivue applies it to the ref and
clears it.

```mermaid
flowchart LR
    G["your game<br/>app.config.devtools = true"] -- "after every render" --> I["root Instance<br/>tag RivueComponent<br/>+ attributes"]
    I -- "tag and attribute signals" --> P["DevTools plugin"]
    P -- "RivueEdit" --> I
```

Values are summarised on the way. Strings, numbers, booleans and Instance names show as they are,
and anything else shows as its type (`table`, `UDim2`). When a component unmounts, Rivue removes
the tag and attributes again. The list only ever shows what's on screen, and pooled Instances
don't carry old data into their next life.

Writing those attributes costs an engine call per attribute per render, which is why it's off
unless you turn it on, and why the snippet above only turns it on in Studio.

The plugin's window is itself built with Rivue. It's tested offline in
`tests/offline/DevTools.test.luau`.
