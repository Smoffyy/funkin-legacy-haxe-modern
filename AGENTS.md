# AGENTS.md

Friday Night Funkin' 0.2.x (legacy) engine, updated to build on current Haxe/HaxeFlixel and
extended to play modern (0.3+) `.fnfc` song bundles.

## Toolchain

| Tool | Version |
| --- | --- |
| Haxe | 4.3.7 |
| lime | 8.3.1 |
| openfl | 9.5.1 |
| flixel | 6.1.2 |
| flixel-addons | 4.0.1 |
| flixel-ui | 2.6.4 |
| hxcpp | 4.3.2 |

Primary target is Windows desktop (`cpp`). Anything under `#if sys` is desktop-only; the
web target falls back to legacy behaviour.

## Commands

```sh
haxelib run lime build windows        # compile
haxelib run lime test windows         # compile and run
haxelib run lime display windows      # print the hxml
```

Type-check without a full C++ build (fast, use this while iterating):

```sh
haxelib run lime display windows | tail -n +2 > check.hxml && haxe check.hxml
```

The first line of `lime display` output is a warning, not an argument, hence `tail -n +2`.

## Layout

```
source/                 legacy engine, flat package (PlayState, FreeplayState, Note, ...)
source/ui/              menu pages (OptionsState, PreferencesMenu, ControlsMenu, ...)
source/funkin/audio/    AudioCache, VocalGroup, MusicPreview
source/funkin/data/     SongCache
source/funkin/modern/   `.fnfc` support
assets/preload/         shared assets and legacy charts (assets/preload/data/<song>/)
assets/songs/           legacy Inst/Voices, `songs` library
assets/week1..week7/    per-week stage art, one asset library each
assets/modern-data/     `.fnfc` bundles, one folder per song
```

New code goes under `source/funkin/`. The flat `source/` files are the original engine and
are only edited in place.

## Song loading

`funkin.data.SongCache` is the only thing that should load a chart. It takes a song id and a
difficulty index and returns a `SwagSong`:

- If `assets/modern-data/<song>/` holds a `.fnfc`, the chart comes from that bundle.
- Otherwise it falls back to `assets/preload/data/<song>/<song>[-easy|-hard].json`.
- It returns `null` when neither exists; callers must handle that rather than assume.

Every chart it parses is kept for the session. `queuePreload` / `stepPreload` warm the whole
library a few milliseconds at a time from `FreeplayState.update`.

`SwagSong` carries optional fields (`modernId`, `stage`, `events`, `instPath`, `vocalPaths`,
`gfVersion`, `variation`, `difficultyId`) that are only set for modern songs. `Song.isModern`
and `Song.idOf` are the accessors to use.

## `.fnfc` bundles

A `.fnfc` is a zip holding, per variation:

```
manifest.json                      { version, songId }
<song>-metadata[-<variation>].json songName, playData (characters, stage, difficulties), timeChanges
<song>-chart[-<variation>].json    scrollSpeed per difficulty, notes per difficulty, events
Inst[-<instrumental>].ogg
Voices-<character>[-<variation>].ogg
```

`ModernSongRegistry` unpacks each bundle once into
`<applicationStorageDirectory>/modern-cache/<folder>/`, stamped with the archive's size and
mtime so it re-extracts only when the bundle changes. Charts are read from there and audio is
streamed off disk instead of being decoded into memory.

Conversion rules (`ModernChartConverter`):

- Modern charts are a flat note list with absolute strumline indices (`d` 0-3 player, 4-7
  opponent). The playfield still indexes sections by `curStep / 16`, so sections are rebuilt
  from `timeChanges` (one section = 4 beats) and each note's data is re-encoded relative to
  its section's `mustHitSection`.
- `mustHitSection` comes from the `FocusCamera` event in effect at the section's start.
- A variation contributes one entry per difficulty to the song's difficulty list, default
  variation first, so indices 0/1/2 stay EASY/NORMAL/HARD and saved highscores keep meaning.

Supported chart events (`PlayState.handleSongEvent`): `FocusCamera`, `ZoomCamera`,
`SetCameraBop`, `PlayAnimation`, `ScrollSpeed`. Durations in events are in steps, not seconds.
Note kind `noanim` suppresses the sing animation.

## Fallbacks

`ModernCompat` maps modern ids onto what this build actually ships, and every lookup ends at
something that exists:

- Stage: `spookyMansionErect` -> `spookyMansion` -> `spooky`; unknown -> `stage`.
- Character: `spooky-dark` -> `spooky`; unknown -> the slot default (`bf`/`dad`/`gf`).
- Icon: unknown -> `face`.
- Stage art lives in week libraries, so `libraryForStage` decides what `Paths.setCurrentLevel`
  is pointed at for a modern song.

A modern song must never crash on missing content. When adding a lookup, add the fallback.

## Conventions

- Tabs for indentation, Allman braces, `hxformat.json` holds the formatter config.
- Keep the original engine's naming even where it is odd; do not rename existing symbols.
- Comments explain why, not what, and only where the reason is not obvious.
- Guard legacy per-song hardcodes (`curSong == 'Bopeebo'`, `'milf'` zooms, week cutscenes)
  with `!isModern`, since modern charts drive that behaviour with events instead.
- Menus must never open a track on the main thread. `AudioCache.loadAsync` does it on a
  worker; `AudioCache.resolve` blocks and is only for when the player is already waiting.
- There is no Newgrounds integration. Do not reintroduce medals, logins or online scores.
- Update `CHANGELOG.md` (x.y.z) for user-visible changes.