[Docs](README.md) › **Installation**

# Installation

RivueUI is a ModuleScript with a `runtime` folder inside. It goes in `ReplicatedStorage`, with the
optional packages next to it.

## Add the package

Pick one.

### Wally

Add the packages to `wally.toml`, then run `wally install`.

```toml [wally.toml]
[dependencies]
RivueUI = "linhisreal/rivue-ui@0.10.0-rc.2"
RivueRemote = "linhisreal/rivue-remote@0.8.0-beta.2" # optional, client/server calls
RivueRouter = "linhisreal/rivue-router@0.3.0-beta.2" # optional, screens and history
```

### pesde

```sh
pesde add linhisreal/rivue_ui
```

Add `linhisreal/rivue_remote` or `linhisreal/rivue_router` the same way if you want them.

### Rojo

Add this repo as a git submodule and point your project at the package:

```sh
git submodule add https://github.com/linhisreal/Rivue vendor/Rivue
```

```json [default.project.json]
"ReplicatedStorage": {
  "RivueUI": { "$path": "vendor/Rivue/packages/rivue-ui" }
}
```

### Studio

Download `RivueUI.rbxm` from the [latest release](https://github.com/linhisreal/Rivue/releases/latest)
and drag it into `ReplicatedStorage`. The release also has `RivueUI.min.rbxm` (no comments),
`RivueRemote.rbxm`, `RivueRouter.rbxm`, and the `RivueDevTools.rbxm` plugin.

## Check it loads

Add a LocalScript to `StarterPlayerScripts` and press Play. The Output window should show the
version you installed.

```lua [LocalScript]
local Rivue = require(game.ReplicatedStorage.RivueUI)
print(Rivue.version)
```

## Build something

[Chapter 1](guide/01-introduction.md) puts a first component on screen.
