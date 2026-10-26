Pre-release public test.

## What's new since pre-v2.56

- **Monorepo:** Rivue, RivueRemote and DevTools are separate packages in `packages/`, with Wally and pesde manifests. Rojo submodule users now point `$path` at `vendor/Rivue/packages/rivue`.
- **Style classes:** `hover`, `pressed`, `selected` and `disabled` variants, and `phone`/`tablet`/`desktop`/`console` variants with `Rivue.useDevice()`.
- **New props:** `gradient`, `scale`, `sizeLimit`, `textSizeLimit`, `disabled`, `vOnce`, and `modelModifiers` (`trim`, `number`, `lazy`).
- **VirtualList:** grids (`columns`), `gap`, and rows of different heights.
- **Composables:** `useKeybind`, `useLocale`, `useTranslator`, `useScroll`, `useModel`, and the `ViewportModel` component.
- **Tooling:** `Rivue.story()` for UI Labs and Hoarcekat, the DevTools plugin (`RivueDevTools.rbxm`, with filtering and re-render highlighting), and `Rivue.version`.
- **Fixed:** loops over reactive tables now re-run when a value changes, and `readonly()` of a reactive table can be iterated.
- **Breaking:** `Remote` moved to the separate `RivueRemote` package, and `hForParallel` is removed.

## Install

Drag `Rivue.rbxm` into `ReplicatedStorage`. `RivueRemote.rbxm` is optional, and `RivueDevTools.rbxm` goes in your Plugins folder.
