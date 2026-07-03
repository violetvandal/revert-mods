# revert-mods — the open QOL mod layer for THUG2: Violet Vandal Edition

The curated **open** mod set (`.ns` NeverScript sources + manifests) for
[Revert](https://github.com/violetvandal/revert). Applied onto a clean base
reproducibly, in `mods.list` order. **Ships no game data** — every mod is
human-readable NeverScript that recompiles byte-perfect and injects into *your own*
THUG2 base archives.

Normally consumed as the `mods` submodule of the Revert installer (`./revert build`
orchestrates `thugkit build` over this directory). To apply this layer directly:

```bash
thugkit apply <install-dir> --mods <this-dir>                 # everything
thugkit apply <install-dir> --mods <this-dir> --only mod-options-menu,au-level
```

`apply-mods.sh` is the original bash applier, kept as a **legacy reference / fallback**
— `thugkit` is byte-equivalent and the day-to-day path:

```bash
./apply-mods.sh <install-dir> [--only mod-options-menu,au-level]
```
`<install-dir>` is a THUG2 install root (has `Data/pre/`).

## Mods (`src/`)

True NeverScript, compiled byte-perfect by the NeverScript compiler and injected into
your own base `.prx`. Every mod is default-off in-game — vanilla is one toggle away.

| Mod | What it edits |
|-----|---------------|
| `mod-options-menu` | the in-game MOD OPTIONS / pause-menu framework + GlobalFlags + ped logic, incl. the "Skip Goal" submenu — story + all classic levels (`qb_scripts.prx` ×6) |
| `mainmenu-mod` | front-end main-menu MOD OPTIONS entry (`mainmenu_scripts.prx`) |
| `au-level` | Australia level script (`AU_scripts.prx`) |
| `be-level` | Berlin: keep-soundtrack in area-music zones (`BE_scripts.prx`) |
| `no-level` | New Orleans: keep-soundtrack + balcony respawn + disable-traffic (`NO_scripts.prx`) |
| `st-level` | Skatopia: car/traffic toggle (`ST_scripts.prx`) |
| `tr-level` | Training level script (`TR_scripts.prx`) |
| `au-seagull` | AU seagull SFX edit (`AU_scripts.prx :: AU_sfx.qb`) |
| `boston-no-traffic` | Boston: disable-traffic toggle (`BO_scripts.prx`) |
| `silence-phone` | silence story pager texts toggle (`qb_scripts.prx`) |

All mods are `type=ns-inject`.

**Widescreen** (`apply-widescreen.sh`) is a runtime/exe-layer patch, not a script mod —
it installs a widescreen-fix ASI loader as `winmm.dll` (so the native controller still
enumerates). Supply your own WidescreenFix build:
```bash
./apply-widescreen.sh <install-dir> /path/to/TonyHawksUnderground2.WidescreenFix.zip
```

## How a source mod works

`type=ns-inject`. For each line in the mod's `inject.list`
(`<archive>  <internal-name>  <source/foo.ns>`), the applier compiles the `.ns` and
injects the resulting `.qb` into your own base archive via `lib/prx.py` (uncompressed,
which the game loader accepts). So the same mod rebuilds on any region's base.

## Authoring / editing a mod

1. Edit the `.ns` in `src/<mod>/source/` (human-readable NeverScript), or add a new file.
2. Add/adjust its line in `src/<mod>/inject.list`.
3. New mod: `mkdir src/<mod>/source`, write `mod.conf` (`type=ns-inject`, `layer=source`),
   add it to `mods.list`.
4. `./apply-mods.sh <test-install> --only <mod>` and verify in-game.

To re-derive the `.ns` from a built `.qb`: `ns -d file.qb -o file.ns`. The round-trip
(`ns -d` then `ns -c`) is byte-identical for all mods here.

## Tooling (`lib/`)
- `prx.py` / `lzss.py` — PRE-archive unpack/repack + LZSS (de)compress.
- `ns` — the patched NeverScript compiler. **Not committed** (platform binary); build it
  from [violetvandal/NeverScript](https://github.com/violetvandal/NeverScript) or set
  `NS=/path/to/ns`. `apply-mods.sh` defaults to `lib/ns`. (Revert builds it for you.)

## What this repo does / doesn't ship

These `.ns` files are decompiled-and-modified THUG2 scripts — derivative works you apply
to **your own** legally-owned copy of the game to rebuild your install. They contain **no
game data, textures, audio, or executables**. Licensed/derivative binary payloads (HD deck
art, guest models, HQ textures) are **not** part of this repo. Bring your own disc; Revert
rebuilds everything from it.

MIT — see [LICENSE](LICENSE).
