[Docs](README.md) › **Releasing**

# Releasing

For maintainers.

## A GitHub release

1. Write the notes in `.github/release-notes/<tag>.md`, for example `pre-v2.57.md`, and push them.
2. Open **Actions → Release → Run workflow** and enter the tag. Tags starting with `pre-` become
   pre-releases.

The workflow runs the tests, builds `Rivue.rbxm`, `Rivue.min.rbxm` and `RivueRemote.rbxm`, creates
the tag on the current `main`, and attaches the files.

## Wally

`wally.toml` describes the package: the library in `src/shared/Rivue` and `default.project.json`,
which Wally users' Rojo projects build into the `Rivue` ModuleScript. Everything else is excluded.

1. Set `version` in `wally.toml` to the release's version (Wally needs plain SemVer, so
   `pre-v2.57` is published as `2.57.0`).
2. Install Wally (`rokit add UpliftGames/wally`) and log in once with `wally login`.
3. Check what will be uploaded with `wally package --list`, then run `wally publish`.

After the first publish, add the Wally install to the README:

```toml
[dependencies]
Rivue = "linhisreal/rivue@2.57.0"
```

`RivueRemote` isn't on Wally: a package needs its own `wally.toml` at the root of a repository.
