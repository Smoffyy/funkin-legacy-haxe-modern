# Changelog
All notable changes will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.1] - 2026-03-14 (Haxe Modern Edition)
### Added
- **Opponent strum hold delay** — opponent arrows stay lit on confirm for 120ms before returning to static, making hits feel more impactful (`OPPONENT_STRUM_HOLD` constant for easy tuning)
- **Hold-to-scroll in Freeplay** — holding UP or DOWN scrolls through songs continuously with a 200ms initial delay and 80ms repeat interval

### Changed
- Framerate saved preference now applies correctly on boot — `applyFramerate` deferred to first frame of `TitleState` so `FlxGame` is fully initialized before the framerate is set
- Opponent strum confirm animation now counts down a hold timer before transitioning to static, instead of snapping back immediately on animation finish

### Fixed
- Fixed framerate preference not applying on game launch (applied too early, before `FlxGame` existed)
- Fixed slow asset loading at startup caused by `applyFramerate` running during the preloader at the saved FPS
- Fixed FNFC songs causing a freeze on "Go!" — `Sound.fromFile` for the instrumental is now pre-loaded during `generateSong()` instead of being called inside `startSong()` on the beat
- Fixed all lerps (health bar, icon size, icon position, camera zoom) being frame-rate dependent — all now use `Math.pow`-based `elapsed` scaling for consistent feel at any FPS
- Fixed `PreferencesMenu.getPref()` being called 5–6 times per frame during gameplay — all hot prefs cached as booleans at `startCountdown()`
- Fixed `scoreTxt.text` being reassigned every frame even when unchanged — now only updates when the string value actually changes
- Fixed ghost tap misses not counting toward accuracy, inflating accuracy compared to late-miss path
- Fixed `getInterpolatedPosition()` being called once per alive note per frame — replaced with `Conductor.framePosition` already computed at frame start
- Fixed `getMidpoint()` allocating temporary `FlxPoint` objects multiple times per frame in `cameraMovement()`
- Fixed `SONG.notes` array being re-indexed inside `forEachAlive` closure — cached as `curSection` before the loop

## [2.0.0] - 2026-03-08 (Haxe Modern Edition)
### Added
- Note wobble (toggle)
- Bot play for debug
- .fnfc support as well as keeping original legacy support ⭐
- Song Credits Display for .fnfc files (toggleable in Quality of Life Prefs)
- Framerate selector in Quality of Life Prefs — choose from 30, 60, 75, 120, 144, 180, 240, 300, 360 FPS, or Unlimited ⭐
- High framerate audio interpolation — note scroll position is extrapolated from the OS clock between audio buffer ticks for smooth, accurate note movement at any framerate
- `Conductor.framePosition` — interpolated position computed once per frame and shared across all note logic, ensuring every note is evaluated against the same timestamp each frame
- `Conductor.refreshInterpolationPref()` — cached preference flag so framerate mode is not looked up every frame
- BPM map caching in `Conductor` — song BPM change maps are computed once and reused on replay
- Framerate changes now apply instantly in settings without restarting the game
- Directional miss animations now play when a note is missed without being attempted
- Note state snapshots — `canBeHit` and `tooLate` are captured before `super.update()` so `keyShit()` always reads stable pre-update note state while inputs are current-frame fresh
- First-visit tip banner on the main menu pointing new players to Quality of Life Prefs
- **Changelog viewer** in the Options menu — reads `changelog.txt` (or `.md`) from the game folder and displays it in-game with UP/DOWN scrolling; gracefully falls back to a message on non-desktop builds

### Changed
- Optimized entire PlayState.hx, note logic, and more!
- Revamped a lot of scripts, ensuring compatibility between both legacy and new versions
- Legacy UI is default (changeable in settings)
- Separated new settings under **Quality Of Life Prefs** ⭐
- Renamed "Interpolation" setting to **Framerate** — now a left/right selector instead of a toggle
- Framerate is now applied at all three layers: `FlxG.updateFramerate`, `FlxG.drawFramerate`, and `lime` window frame rate, preventing FPS fluctuation
- `applyFramerate()` sets update before draw when going up, and draw before update when going down — eliminates the Flixel draw framerate warning
- Interpolation state resets cleanly when switching to 60 FPS or starting a new song
- `applyFramerate()` now caps menus to 360 FPS regardless of user setting; `applyGameplayFramerate()` lifts the cap during a song
- Note hit window now uses `Conductor.framePosition` (interpolated) instead of raw `Conductor.songPosition` — `canBeHit` now matches where notes are visually positioned at high framerates
- Framerate selector left/right input now respects the player's control bindings instead of hardcoded arrow keys
- Options menu input no longer blocked during the intro transition
- `keyShit()` now runs after `super.update()` so `FlxActionManager` has refreshed all inputs before note hit detection reads them
- Note hit logic restored to legacy `willMiss` one-frame buffer pattern — `tooLate` is deferred by one frame so edge-frame inputs are never lost
- `FNFCLoader` fully guarded with `#if sys` — game now compiles for all platforms including HTML5, Web, and any non-sys target; FNFC features gracefully unavailable on unsupported platforms

### Fixed
- Fixed low framerate NoteSplash effect
- Freeplay cache loading
- Sustain note gap
- Fixed framerate selector showing `##F FPS` instead of the number (wrong atlas font for digit glyphs)
- Fixed checkbox indices being offset for all items after the Framerate row
- Fixed arrow keys not working on the Framerate selector after returning from a song (Controls system consuming keys before the selector could read them)
- Fixed Flixel warning "draw framerate should not be smaller than update framerate" when toggling framerate in settings
- Fixed game crash on launch caused by `applyFramerate` being called before `FlxGame` was initialized
- Fixed note inputs randomly not registering or triggering a miss when the note was hit on time — caused by `keyShit()` running after `Note.update()` had already invalidated `canBeHit` that frame
- Fixed ghost miss being triggered when pressing a key on the exact frame a note expires (`tooLateDirections` guard)
- Fixed different notes on the same frame being evaluated against different interpolated positions due to repeated `Lib.getTimer()` calls
- Fixed Unlimited FPS mode rendering at 1 FPS in gameplay due to `window.frameRate = 0` breaking lime's render present loop on Windows native
- Fixed gameplay framerate cap not lifting to Unlimited because Flixel resets `updateFramerate`/`drawFramerate` to constructor values during state transitions — `applyGameplayFramerate()` now runs after `super.create()`
- Fixed framerate selector cycling through only 4 options when going left due to stale compiled binary with old `FPS_OPTIONS` array
- Fixed framerate selector losing track of position when navigating left — caused by `fireInstantly=true` silently advancing the index on every navigation, and input being read before `FlxActionManager` refreshed controls
- Fixed `sys.FileSystem` and `sys.io.File` bare imports in `FNFCLoader` causing compile failure on HTML5 and other non-sys targets

## [1.0.1] - 2026-02-13 (Haxe Modern Edition)
### Added
- Screenshake on miss
- Healthbar blink on low health

## [1.0.0] - 2026-02-11 (Haxe Modern Edition)
### Added
- Recompiled for Haxe 4.3.7 (latest version) ⭐
- High FPS Support
- Opponent Note Strum (Aesthetic)
- Opponent health drain mechanics
- Dynamic sync for charting
- Additional options menu improvements
- Psych Charting Compatibility
- F1 key to hide HUD (except notes)
- New Expert Difficulty (Configurable)

### Changed
- Updated all outdated files for Haxe 4.3.7 compatibility
- Title bar color (now black)
- Centered grey notes
- Improved health color and score display, healthbar movement

## [Unreleased]
### Added
- TANKMAN! 3 NEW SONGS BY KAWAISPRITE (UGH, GUNS, STRESS)! Charting help by MtH!
- Monster added into week 2, FINALLY (Charting help by MtH and ChaoticGamer!)
- Can now change song difficulty mid-game.
- Shows some song info on pause screen.
- Cute little icons onto freeplay menu
### Changed
- ASSET LOADING OVERHAUL, WAY FASTER LOAD TIMES ON WEB!!! (THANKS TO GEOKURELI WOKE KING)
- Made difficulty selector on freeplay menu more apparent
### Fixed
- That one random note on Bopeebo

## [0.2.7.1] - 2021-02-14
### Added
- Easter eggs
- readme's in desktop versions of the game
### Changed

- New icons, old one was placeholder since October woops!
- Made the transitions between the story mode levels more seamless.
- Offset of the Newgrounds logo on boot screen.
- Made the changelog txt so it can be opened easier by normal people who don't have a markdown reader (most normal people);
### Fixed
- Fixed crashes on Week 6 story mode dialogue if spam too fast ([Thanks to Lotusotho for the Pull Request!](https://github.com/ninjamuffin99/Funkin/pull/357))
- Should show intro credits on desktop versions of the game more consistently
- Layering on Week 4 songs with GF and the LIMO LOL HOW TF I MISS THIS
- Chart's and chart editor now support changeBPM, GOD BLESS MTH FOR THIS ONE I BEEN STRUGGLIN WIT THAT SINCE OCTOBER LMAO ([GOD BLESS MTH](https://github.com/ninjamuffin99/Funkin/pull/382))
- Fixed sustain note trails ALSO THANKS TO MTH U A REAL ONE ([MTH VERY POWERFUL](https://github.com/ninjamuffin99/Funkin/pull/415))
- Antialiasing on the skyscraper lights

## [0.2.7] - 2021-02-02
### Added
- PIXEL DAY UPDATE LOL 1 WEEK LATER
- 3 New songs by Kawaisprite!
- COOL CUTSCENES
- WEEK 6 YOYOYOYOY
- Swaggy pixel art by Moawling!
### Changed
- Made it so you lose sliiiightly more health when you miss a note.
- Removed the default HaxeFlixel pause screen when the game window loses focus, can get screenshots of the game easier hehehe
### Fixed
- Idle animation bug with BF christmas and BF hair blow sprites ([Thanks to Injourn for the Pull Request!](https://github.com/ninjamuffin99/Funkin/pull/237))

## [0.2.6] - 2021-01-20
### Added
- 3 NEW CHRISTMAS SONGS. 2 BY KAWAISPRITE, 1 BY BASSETFILMS!!!!! BF WITH DRIP! SANTA HANGIN OUT!
- Enemy icons change when they you are winning a lot ([Thanks to pahaze for the Pull Request!](https://github.com/ninjamuffin99/Funkin/pull/138))
- Holding CTRL in charting editor places notes on both sides
- Q and E changes sustain lengths in note editor
- Other charting editor workflow improvements
- More hair physics
- Heads appear at top of chart editor to help show which side ur charting for
### Changed
- Tweaked code relating to inputs, hopefully making notes that are close together more fair to hit
### Removed
- Removed APE
### Fixed
- Maybe fixed double notes / jump notes. Need to tweak it for balance, but should open things up for cooler charts in the future.
- Old Verison popup screen weirdness ([Thanks to gedehari for the Pull Request!](https://github.com/ninjamuffin99/Funkin/pull/155))
- Song no longer loops when finishing the song. ([Thanks Injourn for the Pull Request!](https://github.com/ninjamuffin99/Funkin/pull/132))
- Screen wipe being cut off in the limo/mom stage. Should fill the whole screen now.
- Boyfriend animations on hold notes, and pressing on repeating notes should behave differently

## [0.2.5] - 2020-12-27
### Added
- MOMMY GF, 3 NEW ASS SONGS BY KAWAISPRITE, NEW ART BY PHANTOMARCADE,WOOOOOOAH!!!!
- Different icons depending on which character you are against, art by EVILSK8R!!
- Autosave to chart editor
- Clear section button to note editor
- Swap button in note editor
- a new boot text or two
- automatic check for when you're on an old version of the game! 
### Changed
- Made Spookeez on Normal easier.
- Mouse is now visible in note editor
### Fixed
- Crash when playing Week 3 and then playing a non-week 3 song
- When pausing music at the start, it doesn't continue the song anyways. ([shoutouts gedehari for the Pull Request!](https://github.com/ninjamuffin99/Funkin/pull/48))
- IDK i think backing out of song menu should play main menu songs again hehe ([shoutouts gedehari for the Pull Request!](https://github.com/ninjamuffin99/Funkin/pull/48))

## [0.2.4] - 2020-12-11
### Added
- 3 NEW SONGS BY KAWAISPRITE. Pico, Philly, and Blammed.
- NEW CHARACTER, PICO. Based off the classic Flash game "Pico's School" by Tom Fulp
- NEW LEVEL WOW! PHILLY BABEEEE
### Changed
- Made it less punishing to ATTEMPT to hit a note and miss, rather than let it pass you
### Fixed
- Song desync of you paused and unpaused frequently ([shoutouts SonicBlam](https://github.com/ninjamuffin99/Funkin/issues/37))
- Animation offsets when GF is scared

## [0.2.3] - 2020-12-04
### Added
- More intro texts
### Fixed
- Exploit where you could potentially give yourself a high score via the debug menu
- Issue/bug where you could spam the confirm button on the story menu ([shoutouts lotusotho for the CODE contribution/pull request!](https://github.com/ninjamuffin99/Funkin/pull/19))
- Glitch where if you never would lose health if you missed a note on a fast song (shoutouts [MrDulfin](https://github.com/ninjamuffin99/Funkin/issues/10), [HotSauceBurritos](https://github.com/ninjamuffin99/Funkin/issues/13) and [LobsterMango](https://lobstermango.newgrounds.com))
- Fixed tiny note bleed over thingies (shoutouts [lotusotho](https://github.com/ninjamuffin99/Funkin/pull/24))

## [0.2.2] - 2020-11-20
### Added
- Music playing on the freeplay menu.
- UI sounds on freeplay menu
- Score now shows mid-song.
- Menu on pause screen! Can resume, and restart song, or go back to main menu.
- New music made for pause menu!

### Changed
- Moved all the intro texts to its own txt file instead of being hardcoded, this allows for much easier customization. File is in the data folder, called "introText.txt", follow the format in there and you're probably good to go!
### Fixed
- Fixed soft lock when pausing on song finish ([shoutouts gedehari](https://github.com/ninjamuffin99/Funkin/issues/15))
- Think I fixed issue that led to in-game scores being off by 2 ([shoutouts Mike](https://github.com/ninjamuffin99/Funkin/issues/4))
- Should have fixed the 1 frame note appearance thing. ([shoutouts Mike](https://github.com/ninjamuffin99/Funkin/issues/6))
- Cleaned up some charting on South on hard mode
- Fixed some animation timings, should feel both better to play, and watch. (shoutouts Dave/Ivan lol)
- Animation issue where GF would freak out on the title screen if you returned to it([shoutouts MultiXIII](https://github.com/ninjamuffin99/Funkin/issues/12)).

## [0.2.1.2] - 2020-11-06
### Fixed
- Story mode scores not properly resetting, leading to VERY inflated highscores on the leaderboards. This also requires me to clear the scores that are on the leaderboard right now, sorry!
- Difficulty on storymode and in freeplay scores
- Hard mode difficulty on campaign levels have been fixed

## [0.2.1.1] - 2020-11-06
### Fixed
- Week 2 not unlocking properly

## [0.2.1] - 2020-11-06
### Added
- Scores to the freeplay menu
- A few new intro boot messages.
- Lightning effect in Spooky stages
- Campaign scores, can now compete on scoreboards for campaign!
- Can now change difficulties in Freeplay mode

### Changed
- Balanced out Normal mode for the harder songs(Dadbattle and Spookeez, not South yet). Should be much easier all around.
- Put tutorial in it's own 'week', so that if you want to play week 1, you don't have to play the tutorial.

### Fixed
- One of the charting bits on South and Spookeez during the intro.

## [0.2.0] - 2020-11-01
### Added
- Uhh Newgrounds release lolol I always lose track of shit.

## [0.1.0] - 2020-10-05
### Added
- Uh, everything. This the game's initial gamejam release. We put it out
