[Docs](README.md) › **Releasing**

# Releasing

For maintainers.

## A GitHub release

1. Write the notes in `.github/release-notes/<tag>.md`, for example `pre-v2.57.md`, and push them.
2. Open **Actions → Release → Run workflow** and enter the tag. Tags starting with `pre-` become
   pre-releases.

The workflow runs the tests, builds the files in the table below, creates
the tag on the current `main`, and attaches the files.

## Packages

The repo is a monorepo. Each folder in `packages/` is published on its own, all with the same
version:

| Folder | Wally | pesde | Release file |
|---|---|---|---|
| `packages/rivue` | `linhisreal/rivue` | `linhisreal/rivue` | `Rivue.rbxm`, `Rivue.min.rbxm` |
| `packages/rivue-remote` | `linhisreal/rivue-remote` | `linhisreal/rivue_remote` | `RivueRemote.rbxm` |
| `packages/rivue-devtools` | — | — | `RivueDevTools.rbxm` (a Studio plugin) |

Each package has its own `default.project.json`, `wally.toml`, `pesde.toml`, `README.md` and
`LICENSE.md` (a copy of the root one). The root `pesde.toml` makes them a pesde workspace. Wally
has no workspaces, so each package is published from its own folder.

1. Set the version everywhere: `lune run version 2.57.0`, then commit.
2. Install the tools once: `rokit add UpliftGames/wally` and `rokit add pesde-pkg/pesde`, then log
   in with `wally login` and `pesde auth login`.
3. Publish each package:

   ```sh
   wally publish --project-path packages/rivue
   wally publish --project-path packages/rivue-remote
   cd packages/rivue && pesde publish && cd ../..
   cd packages/rivue-remote && pesde publish && cd ../..
   ```

The **Packages** workflow checks both registries' packages on every change, without publishing.

## Docs site

The `docs/` folder is also a [VitePress](https://vitepress.dev) site, published to GitHub Pages
by the **Docs site** workflow on every push that changes `docs/`. Turn it on once under
**Settings → Pages → Source: GitHub Actions**. To preview locally:

```sh
npm install --no-save vitepress@1.6.4 vitepress-plugin-mermaid@2.0.17 mermaid@11
npx vitepress dev docs
```

## Tests in Roblox

The **Tests in Roblox** workflow runs every suite in a real Roblox server, through Open Cloud's
Luau Execution API, after `lune run test` has run them offline. Set it up once:

1. Publish an empty, private experience (for example "Rivue CI") and note its universe and place
   ids from the Creator Dashboard.
2. Create an Open Cloud API key with **Luau Execution Session** (write) and **Universe Places**
   (write), limited to that experience, with `0.0.0.0/0` as the allowed IP range and an expiry
   date.
3. In the repo's **Settings → Secrets and variables → Actions**, add the secret `ROBLOX_API_KEY`
   and the variables `ROBLOX_UNIVERSE_ID` and `ROBLOX_PLACE_ID`. Never paste the key anywhere else.

Until the variables exist, the workflow is skipped. To run it locally:
`ROBLOX_API_KEY=... ROBLOX_UNIVERSE_ID=... ROBLOX_PLACE_ID=... lune run cloud-test`.

The tests run on the server, without a `LocalPlayer`, and suites can check the `__CLOUD` global
to skip what needs one.
