# VisualCore

[![CI](https://github.com/Coastrnaut/VisualCore/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Coastrnaut/VisualCore/actions/workflows/ci.yml)
[![Push scan](https://github.com/Coastrnaut/VisualCore/actions/workflows/push-scan.yml/badge.svg?branch=main)](https://github.com/Coastrnaut/VisualCore/actions/workflows/push-scan.yml)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20iPadOS%2026%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.4-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**One iOS and iPadOS app of code-drawn visual experiences, built on a reusable OpenGL ES → ANGLE → Metal rendering
framework.**

VisualCore is two things in one repository:

- **The VisualCore framework** — Swift packages that draw with OpenGL ES 3.0 through EGL and the owner's fork of ANGLE
  on its Metal backend, plus pure-Swift modules for math, simulation, scenes, audio analysis, persistence and the
  experience contract.
- **The VisualCore app** — a single App Store app (one target, one bundle identifier) in which every creative app and
  every game is a registered *experience* opened from one launcher
  ([ADR-0009](docs/decisions/ADR-0009-unified-app.md)).

This README states only what is true in the repository today and labels everything else as planned. It is updated
with every gate that changes what it says (see [Keeping this README current](#keeping-this-readme-current)).

## Contents

- [Status](#status)
- [Features](#features)
- [The app and its experiences](#the-app-and-its-experiences)
- [How it renders](#how-it-renders)
- [Getting started](#getting-started)
- [Testing and continuous integration](#testing-and-continuous-integration)
- [Repository structure](#repository-structure)
- [Framework modules](#framework-modules)
- [Development workflow](#development-workflow)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Keeping this README current](#keeping-this-readme-current)
- [License](#license)

## Status

State on **2026-11-17**. Progress lives in two ledgers, never in prose; the commands below print the live state. A
gate is "pass" when its host and simulator checks passed and its evidence is recorded. **Pass is never device
evidence**: no physical-device test of the unified app has been run.

| Component | State today | Evidence |
|---|---|---|
| Framework packages (version 1.0.0-rc.1) | simulator-verified: host tests and iOS Simulator tests | `.autonomy/evidence/F00.json` … `F09.json`; [release notes](docs/release/release-notes-1.0.0-rc.1.md) |
| Unified VisualCore app (`Apps/VisualCore`) | exists: launcher, routes, settings, about, onboarding, session host, persistence, quality profiles, verification runner (UA-F00 … UA-F07, UA-F09 … UA-F11 pass) | `python3 scripts/migration_ledger.py status` |
| Audio modules `VisualCoreAudioDSP` and `VisualCoreAudio` | implemented: FFT, bands, RMS, onsets, test signals, min/max decimation, synthesized sound effects; demo, file, microphone, test-signal and two-channel sources with interruption and route handling; a sound-effect player (ambient, no permission) | A06–A08 and A10-P03 phases; [known limitations](docs/release/known-limitations.md) |
| A01 Generative Art Studio | experience in the app; X-A01 pass | `.autonomy/migration/checks/X-A01.*.json` |
| A02 Fluid Art Playground | experience in the app; X-A02 pass | `.autonomy/migration/checks/X-A02.*.json` |
| A03 Fractal Explorer | experience in the app; X-A03 pass | `.autonomy/migration/checks/X-A03.*.json` |
| A04 Particle Universe | experience in the app; X-A04 pass | `.autonomy/migration/checks/X-A04.*.json` |
| A05 Infinite Geometry | experience in the app; X-A05 pass | `.autonomy/migration/checks/X-A05.*.json` |
| A06 VisualCore Music Lab | experience in the app; X-A06 pass | `.autonomy/migration/checks/X-A06.*.json` |
| A07 Audio Odyssey | experience in the app; X-A07 pass | `.autonomy/migration/checks/X-A07.*.json` |
| A08 Oscilloscope Studio | experience in the app; X-A08 pass | `.autonomy/migration/checks/X-A08.*.json` |
| A09 Digital Aquarium | experience in the app; X-A09 pass | `.autonomy/migration/checks/X-A09.*.json` |
| A10 Neon Arcade | experience in the app; X-A10 pass — Neon Dodge: five lanes and four wave patterns, swept collision, title, pause and game-over screens, a local high-score table, synthesized sounds and haptics, five steering sensitivities, three quality levels ([contract](docs/apps/neon-arcade/visualcore-contract.md)) | `.autonomy/migration/checks/X-A10.*.json` |
| A11 Physics Playground | experience in the app; X-A11 pass — circles and boxes that collide, stack and settle on a 10 × 8 m stage; springs with bounded stiffness; gravity off, Moon or Earth and three drag levels; touch editing (tap to add or select, drag to grab, hold to pin, double-tap to delete, each with a native control); velocity and force arrows and a measured energy panel; presets (pendulum, spring chain, stacked objects), four saved experiment slots and two guided tutorials; pause, single step, time scale and reset to the opened experiment; resting bodies sleep; three drawing quality levels; VisualCore gains 2D contacts, an impulse solver with warm starting, springs and a broad phase ([contract](docs/apps/physics-playground/visualcore-contract.md)) | `.autonomy/migration/checks/X-A11.*.json` |
| A12 Tiny Worlds | experience in the app; X-A12 pass — three ready-made world packs (an island with palms and huts, an asteroid garden with boulders and lanterns, a miniature city with houses and street lights) built on seeded terrain coloured by height and drawn lit with depth; drag to orbit and pinch to zoom (each with a button) within each pack's limits, the eye kept above terrain and props; place, move, turn and delete props; set the sun and ambient light; four saved worlds with pictures; three detail tiers that lighten under memory warnings, heat and Low Power Mode without changing the world, and 20 load and unload cycles that leave no stale graphics objects; VisualCore gains seeded gradient noise, a seam-free height-field terrain, ray intersection and per-vertex mesh colours ([contract](docs/apps/tiny-worlds/visualcore-contract.md)) | `.autonomy/migration/checks/X-A12.*.json` |
| A13 Light Maze | integrated (X-A13 pass) — a grid light-reflection puzzle: 20 handcrafted levels with emitters, walls, mirrors, targets and prisms; the beam traced on the CPU with equal-angle reflection, bounce, segment and branch caps and loop detection, drawn from the exact path with a soft capped glow, rings on lit targets and an outline on the selected tile; tap to select and turn, drag along a diagonal or twist with two fingers to snap a mirror (each with a native control: choose a level, select, turn, undo, restart, hint, describe); levels open one by one as each is solved, with best move counts and an undo list saved in the experience's own storage; beam changes spoken and the whole board described on request; a hint points at one tile to turn; solving plays a short code-made sweep, a haptic tap and a border with a tick (never flashing, static under Reduce Motion and Reduce Flashing); every state has a shape sign as well as a colour with at least 3 : 1 contrast; a bounded solver proves all 20 levels solvable in the fewest turns and a content QA table ([content-qa.md](docs/apps/light-maze/content-qa.md)) checks every level; release documents: [privacy and credits](docs/apps/light-maze/privacy-and-credits.md), [store text](docs/apps/light-maze/store-listing.md), [release checklist](docs/apps/light-maze/release-checklist.md) (owner and device rows open); VisualCore gains a 2D ray cast against segments with reflection ([contract](docs/apps/light-maze/visualcore-contract.md)) | `.autonomy/migration/checks/X-A13.*.json` |
| A14 Solar System Explorer | integrated (X-A14 pass) — a reviewed educational solar system viewer drawn entirely in code: the Sun and eight planets as 3D worlds with seam-free procedural surfaces, Saturn's rings from NASA's ring fact sheet and a seeded starfield, at their positions from approximate Kepler orbits (VisualCoreMath `KeplerOrbit`, J2000.0 mean elements by Standish, JPL); play, pause and four rates (a day to a year per second) with the UTC date and time, "Now", date steps over 1950–2050; two captioned guided tours (inner and giant planets) with pause, skip and stop; body labels on the canvas (through the host's canvas overlay) and a saved view; planet focus with an eased flight (cut by Reduce Motion), stepped orbit, tilt and zoom; visibility-enhanced (labelled not to scale) and true-relative scale modes; fact cards with units and sources; two detail levels; the model checked against Mars oppositions and Earth perihelia within ±3 days and its limits stated in the app ([data sources](docs/apps/solar-system-explorer/data-sources.md), [scientific review](docs/apps/solar-system-explorer/scientific-review.md), [privacy and credits](docs/apps/solar-system-explorer/privacy-and-credits.md), [release checklist](docs/apps/solar-system-explorer/release-checklist.md), [contract](docs/apps/solar-system-explorer/visualcore-contract.md)) | `.autonomy/migration/checks/X-A14.*.json` |
| A15 Molecular Explorer | integrated (X-A15 pass) — a library of five curated small molecules (water, methane, ethanol, benzene, caffeine) from public-domain PubChem 3D records drawn in ball-and-stick (double and triple bonds as parallel sticks, inferred bonds thin) or space-filling style with element colours; drag, pinch and two-finger pan or buttons to turn, tilt, zoom and pan; tap to pick an atom (nearest along the line of sight) with element labels, a selection ring and a metadata panel, with formulas, counts and sources; a recent-molecules list (at most 8) and a label setting (all, selected, none) kept in the experience's own storage, damaged or newer files refused and left untouched; import of a small XYZ file from Files through the system document picker (no permission; size checked before reading; each refusal named in one sentence; a 2,000-file seeded fuzz corpus never crashes); a generated [data review](docs/apps/molecular-explorer/data-review.md) of every shown value with its source, units and license, and no safety, toxicity or medical claim; a strict, bounded XYZ parser with twelve typed refusals; distance-based bond inference marked as estimated; ten elements with sourced radii and colours ([data sources](docs/apps/molecular-explorer/data-sources.md), [contract](docs/apps/molecular-explorer/visualcore-contract.md)) | `.autonomy/migration/checks/X-A15.*.json` |
| A16 Simulation Lab | integrated (X-A16 pass) — three seeded simulations on a 64 × 64 grid, all stepped on the GPU through the one renderer and checked against a GPU-free CPU reference: a cellular automaton (Life, HighLife, Seeds) equal cell for cell, Gray-Scott reaction-diffusion (Spots, Mazes) and a 2D wave field with a fixed zero border on half-float targets, equal to the float16 reference; without floating-point targets the two float families are refused with a sentence; run, pause, an exact single step, reset, speed and a time step whose values beyond the stability limit are refused with a sentence naming it; touch or the Seed row paints cells; an inspector with every value and range, an approximation label, a legend with a 16-bin histogram; six bundled presets with their sources and up to 24 saved experiments; a 1024 × 1024 picture to share; Reduce Motion and Reduce Flashing cap the speed — a generated [validation report](docs/apps/simulation-lab/validation-report.md) from short simulator runs (every family within its tolerance, the stability limits finite, at most 16 GPU steps per frame, 180,224 bytes of targets) — release documents ([privacy and credits](docs/apps/simulation-lab/privacy-and-credits.md), [release checklist](docs/apps/simulation-lab/release-checklist.md); device rows SL-D1 … SL-D6 wait for the device campaign) and four interface journeys on the iPhone simulator ([contract](docs/apps/simulation-lab/visualcore-contract.md), every gap closed) | `.autonomy/checks/A16-P0{0,1,2,3,4,5,6}.*.json` |
| A17 Interactive Anatomy | integrated (X-A17 pass) — a labelled, layer-controlled 3D reference of the right knee joint, procedural schematic geometry with cited plain-language text, educational and not medical; 20 procedural meshes at two quality levels drawn through the host's depth pass with translucent ghosts; drag to orbit and pinch to zoom; in-scene labels without overlaps from VisualCoreMath's new AnchoredLabelLayout; tap, list or search selection; layer signs not relying on colour and rate-limited announcements; isolate, the saved view and a versioned offline content pack with provenance; text checked against its sources by the lead engineer, not reviewed by a clinician (owner action), the device campaign planned — privacy, credits, store text, release checklist and interface tests in place ([contract](docs/apps/interactive-anatomy/visualcore-contract.md), every gap closed, [sources](docs/apps/interactive-anatomy/content-sources.md)) | `.autonomy/checks/A17-P0{0,1,2,3,4,5,6}.*.json` |
| A18 Ambient Clock | integrated (X-A18 pass) — a calm, readable clock over four procedural themes (noise gradient, particle drift, wave field, SDF shapes), each a full-screen shader over VisualCore's GLSL library with three curated dark palettes on which white text reaches at least 13.5 : 1, two quality levels, motion and speed controls; theme changes crossfade through VisualCoreRendering's new CrossfadeScene (a cut under Reduce Motion); up to 12 named favourites in the experience's own storage; night mode (off, on or scheduled) that dims and warms the drawing with amber text and never touches the screen brightness; an in-app motion reduction; a 30 frames-per-second cap through VisualCore's new experience frame cap; slow pixel drift and idle dimming for screen care; opt-in keep-awake while the clock is visible; a still picture drawn once and reused through VisualCore's new CachedScene; interface tests and a device campaign plan (overnight, heat, memory, pacing, drift, night readability, time changes; all pending until devices); release documents (privacy and credits, store text with a proving test for every claim, a 39-row release checklist), a source scan (no network, sensor or brightness use; the idle timer in one named file), a claims scan, crash recovery that keeps the favourites, and committed snapshot and favourites samples; the time and date as native system text sized to Dynamic Type and spoken for VoiceOver, read only from the injected clock source and re-read on time-zone, locale, day, significant time and foreground changes ([contract](docs/apps/ambient-clock/visualcore-contract.md), [licenses](docs/apps/ambient-clock/licenses.md), [privacy](docs/apps/ambient-clock/privacy-and-credits.md)) | `.autonomy/checks/A18-P0{0,1,2,3,4,5,6}.*.json` |
| A19 Living Wallpapers | integrated (X-A19 pass) — a creator of procedural backgrounds exported as correctly sized stills through the system share sheet and applied by the person through the system's own controls; boundary audit with a go decision: VisualCore's tested offscreen render and read-back are reused, and 14 gaps are owned, among them JPEG and HEIC encoding (VisualCoreRendering) and a still at a chosen time (VisualCoreExperienceHost); the pure core holds four curated procedural scenes with three colour presets each, nine iPhone and iPad templates with a provenance record, a versioned project file with typed refusals, and export planning that refuses a size the device cannot render before any allocation and offers the largest that fits; a fixture writes every template through the sRGB still encoder and reads the file back at the planned size and profile; short looping exports are decided out of version 0.1 and guarded by a source scan; the four scenes are drawn as fragment shaders at two quality levels with the device's crop frame and approximate safe areas as a native overlay, and a still exports at the template's exact size and chosen moment as PNG, JPEG or HEIC through VisualCore's new format encoder and timed still, with cancelled, failed and retried exports leaving no GPU resource or temporary file; each preset's four colours are editable (snapshot schema 2 with its stored schema-1 example), a device size that does not fit shows a plain notice with the size that will be used, the result names the format, the exact pixel size and the sRGB profile read back from the file, help explains how the person sets the wallpaper in Settings, and every control carries a spoken label with its value; the written file goes to the system share sheet (Save Image uses the app's add-only Photos string and the experience never reads the library), the export runs as a job with progress, cancel and retry, and a local history keeps the newest 20 exports; four interface tests on the iPhone simulator prove the export journey, the fallback notice at a capped limit and that no screen or help text claims the app sets the wallpaper, and a device campaign plan (size limit, largest template, file size and profile, heat, memory, the Photos prompt and its declined path, audits; rows LW-D1 … LW-D8, all pending until devices) is in place; release documents (privacy and credits naming the snapshot, the export history and the one temporary export file, store text with a proving test for every claim, a 38-row release checklist), a source scan (no network, tracking, sensor, Photos library, idle-timer or brightness use), a claims scan (no wallpaper-setting, live-wallpaper, video or unmeasured-size claim), crash recovery that keeps the history, committed snapshot and history samples, and a history interface test ([contract](docs/apps/living-wallpapers/visualcore-contract.md), [decision](docs/apps/living-wallpapers/video-decision.md), [licenses](docs/apps/living-wallpapers/licenses.md), [device campaign](docs/apps/living-wallpapers/device-campaign.md), [privacy](docs/apps/living-wallpapers/privacy-and-credits.md); every gap closed) | `.autonomy/checks/A19-P0{0,1,2,3,4,5,6}.*.json` |
| A20 Digital Zen Garden | integrated (X-A20 pass) — a calm, tactile sand-raking and stone-arrangement experience whose gardens persist, offline, with only the add-only Photos prompt when a still is saved; boundary audit with a go decision: VisualCore's touch path with uniform resampling, persistent half-float render targets with an 8-bit fallback, field passes, procedural meshes with hit testing by depth, snapshots and experience storage are reused, and 14 app-local gaps are owned (the command log, undo and redo by command replay, the sand height target, relief, stones, shadows, selection, named gardens, accessibility, quiet defaults, device tests, release); no VisualCore change is planned; the pure core holds the garden document in normalized tray coordinates with caps and nine refusals, two rake styles and five stone kinds, strokes resampled every 0.004 tray widths with a 512-point cap, a 160 × 120 reference sand field rebuilt from the strokes without the GPU, and a command history with exact undo and redo of strokes and stone edits, bounded to 100 commands with a checkpoint; the experience rakes the sand with one finger — a drag reaches the core as small actions and is resampled without gaps — into a 480 × 360 height field stamped on the CPU, uploaded to one render target and drawn as lit relief with grain at the full quality level inside a fitted 4:3 tray, rebuilt by replay after undo, redo, restore, resize and a lost context and reused as a still frame at most 30 times a second; a native overlay previews the rake under the finger, and pattern buttons (rows, circle, wave, spiral) rake through the same actions as touch; five stone kinds are placed, moved, turned and removed as undoable commands, drawn as procedural superellipse domes in depth order with soft shadows on the sand, selected topmost-first by a tap or by previous and next controls with a dashed outline and a spoken label, and turning the device keeps every stone and stroke in its tray position; up to 12 named gardens are saved, opened, renamed and deleted in the experience's own storage, with damaged or newer files listed and kept, every control has a spoken label and value, undo, redo and the library are announced, the controls stack at the largest text sizes, 10,000 commands leave a history of at most 100 commands under 2.5 MB, a 1600 × 1200 picture of the garden goes to the system share sheet; sound, a slow sand-grain drift and haptics are off by default as native switches kept between visits, Reduce Motion keeps the picture still, nothing flashes, the garden, stone and named-garden journeys pass in the app's interface tests, and the device campaign plan holds rows ZG-D1 to ZG-D8, all pending; the release documents (privacy and credits, store text whose every claim names a test, a 36-row checklist), the source and claims scans, drawing-failure recovery with the library unchanged and nine committed stored-file samples close every gap of the contract ([contract](docs/apps/digital-zen-garden/visualcore-contract.md), [licenses](docs/apps/digital-zen-garden/licenses.md), [privacy](docs/apps/digital-zen-garden/privacy-and-credits.md), [release checklist](docs/apps/digital-zen-garden/release-checklist.md)) | `.autonomy/checks/A20-P0{0,1,2,3,4,5,6}.*.json` |
| A21 Aurora | Phases 00–03 done (A21-P03), a candidate (not yet available) — a full-screen ambient aurora experience with procedural skies, gentle stars and optional sound synthesised in code, stylized and never a forecast, offline and with no permission; boundary audit with a go decision: VisualCore's full-screen shader scenes and GLSL noise library, particles, blend modes and render targets, the crossfade scene, the frame-delta clock, frame pacing, the cached still frame, precision probes and experience storage are reused, 12 app-local gaps are owned (scene model, sky shaders, rendered clock, controls, luminance cap, hide-and-restore controls, compositing, preferences, low-power and fallback views, sound control, device tests, release) and one upstream gap, an ambient loop player in VisualCoreAudio, is planned for A21-P04; the pending core holds the sky scene (schema 1 with seven refusal codes and clamping setters) and three presets (polar night, violet veil, dawn haze), a sky shader of hashed stars, noise clouds and up to four additive ribbons on a seamless 600-second loop with a soft luminance ceiling of 0.72, a bit-exact CPU port of VisualCore's noise as its reference, two quality levels, and a frame-delta clock that never jumps after the background and holds still under Reduce Motion; drawn off screen, every preset matches its reference exactly; the experience draws the sky in the app as one full-screen shader whose time comes from the clock, with a preset picker and bounded colour, motion and intensity controls, a brightness limit (0.2 to 0.72) that no frame exceeds, including the middle of an eased 1.5-second change between skies (immediate under Reduce Motion), controls that hide and return with a tap or an accessibility action, and a scenario manifest; changing skies dissolves one moving sky into the next over two seconds through VisualCore's crossfade scene, every step under the limit and monotonic towards the new sky, and the person's choices (sky, colours, motion, limit, and a sound on/off and volume that nothing plays yet) are kept as one versioned experience value, defaulted with a message when damaged or newer and untouched by any drawing lifecycle event ([contract](docs/apps/aurora/visualcore-contract.md), [licenses](docs/apps/aurora/licenses.md)) | `.autonomy/checks/A21-P0{0,1,2,3}.*.json` |
| A22–A25 | not started | `python3 Tools/python/desktop_runbook.py next` |
| Shared round features (R02-F02 … F05, F26) | pass | `python3 scripts/migration_ledger.py status` |
| Games of Rounds 2–12 | planned; none exists in source | [catalog](docs/catalog/experience-catalog.json) |
| Physical-device testing | none run; waits for `ImplementationLock-100` | [support matrix](docs/release/support-matrix.md) |
| App Store | no submission and nothing for sale; a one-time name and bundle reservation is prepared and waits for the owner (signing, App Store Connect and agreements are owner actions) | [build and archive](docs/release/build-and-archive.md), [name reservation](docs/release/name-reservation.md) |

Ledger totals today: the legacy ledger records **154 of 263** gates as passed (F00–F09 and the app phases
A01-P00 … A19-P06, A20-P00 … A20-P06, A21-P00 … A21-P03); the unified-app ledger has 1,233 gates, with 20 experience gates (X-A01 … X-A20), 11 unified-app features,
5 shared round features and both governance milestones passed.

```bash
python3 Tools/python/desktop_runbook.py status   # legacy gates: framework and app phases
python3 scripts/migration_ledger.py status        # unified-app gates and the next action
```

## Features

- **One renderer.** OpenGL ES 3.0 through EGL on ANGLE's Metal backend; `scripts/check_compliance.py` rejects any
  second renderer.
- **Visuals are code.** GLSL shaders, procedural meshes, signed-distance fields, particles and deterministic
  animation — no purchased, generated or hand-made art.
- **Deterministic simulation.** A seeded random generator and a fixed-step clock (`VisualCoreSimulation`) make every
  scene repeatable in automated tests; each experience proves this with a scenario manifest and state digests. Bounded
  steering (separation, alignment, cohesion, boundary) over a capped neighbour search moves schools of agents;
  circle and capsule overlap tests and a swept circle test (`Collision2D`) keep fast objects from passing through
  each other between steps; circle and box contact manifolds (`Contacts2D`) and a sequential impulse solver with
  restitution, friction and warm starting (`ImpulseSolver2D`), springs (`Springs2D`) and a broad phase
  (`BroadPhase2D`) let rigid bodies collide, hang on springs and come to rest.
- **Experience contract.** Every experience implements one contract (core state, actions, snapshots with migrations,
  quality tiers, accessibility description) and is opened, suspended, restored and torn down by one host.
- **Audio without recording.** Live analysis of microphone, file and test-signal input in memory only; nothing is
  recorded, stored or sent.
- **Private by design.** No network requests, no accounts, no tracking and no advertising of any kind.
- **Accessible.** Every control has a label, value and identifier; each canvas has a spoken description; Reduce Motion
  and Reduce Flashing are honoured.

## The app and its experiences

Planned scope, decided in [ADR-0009](docs/decisions/ADR-0009-unified-app.md). The first release contains exactly
**100 experiences**:

| Tier | Experiences | Count |
|---|---|---|
| Free forever | the 25 original creative apps (A01–A25) and the 25 Round 2 games (R02-G01 … R02-G25) | 50 |
| Premium | the games of Rounds 3 and 4 (R03-G01 … R04-G25) | 50 |

- **Price:** free download plus one non-consumable in-app purchase of USD 1.99 (StoreKit 2) that unlocks every
  premium experience, present and future. No subscriptions, consumables or external payment paths.
- **No advertising of any kind.** No ad or tracking SDKs, no ad identifiers, no required account.
- **Order of work:** all 100 experiences are implemented and verified on the iOS Simulator before any
  physical-device campaign begins (gate `ImplementationLock-100`), then devices D1 → D2 → D3.
- **Catalog:** [docs/catalog/experience-catalog.json](docs/catalog/experience-catalog.json) lists all 300 planned
  experiences: the 100 above and a backlog of 200 from Rounds 5–12. It is a plan, not evidence of implementation.
- **Plan and gates:** [docs/migration/migration-plan.md](docs/migration/migration-plan.md) and the gate ledger
  `.autonomy/migration/ledger.json`.

The name "VisualCore" has not been checked for App Store availability, and the bundle identifier is a placeholder.

## How it renders

```text
RenderScene (OpenGL ES 3.0 calls) -> EGL -> ANGLE (libEGL, libGLESv2) -> Metal -> GPU
```

A scene implements `RenderScene` and issues OpenGL ES 3.0 calls. `RenderHost` owns the EGL context and a window
surface on the view's `CAMetalLayer`, runs frames from a `CADisplayLink` on the main thread and presents them with
`eglSwapBuffers`. EGL and OpenGL ES come from prebuilt `libEGL` and `libGLESv2` frameworks of the ANGLE fork (Metal
backend); they are built with the scripts of the pinned submodule `External/projectm-ios` and are not committed.
Experiences draw only through the host's context (`VisualCoreExperienceHost`); none owns a context of its own.

More: [architecture](docs/architecture/visualcore-architecture.md) and the
[reference pipeline](docs/architecture/current-rendering-pipeline.md) that `RenderHost` re-implements.

## Getting started

### Requirements

Toolchain as recorded in [Configs/toolchain.json](Configs/toolchain.json) (never silently upgraded):

| Tool | Version |
|---|---|
| Xcode | 27.2 (build 27B52), iOS SDK 27.2 |
| Swift | 6.4.2 |
| XcodeGen | 2.46.0 |
| CMake | 4.4.5 |
| Python | 3.10 or later |
| Simulator runtimes | iOS 26.5 and iOS 27.2 |

### Setup

```bash
git clone https://github.com/Coastrnaut/VisualCore.git
cd VisualCore
git submodule update --init External/projectm-ios
python3 scripts/verify_environment.py
```

Fetch only the reference submodule (do not use `--recursive` at the top level), then compare the installed tools with
`Configs/toolchain.json`. Rendering tests, the app, the Showcase and the harnesses also need the ANGLE frameworks
built from the submodule and Xcode projects generated with XcodeGen; [setup.md](setup.md) is the full guide.

### Build and run the app

```bash
xcodegen generate --spec project.yml
python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone --action build-for-testing
```

`project.yml` is the XcodeGen specification of the VisualCore app, its unit and interface tests, and the Showcase.
Xcode projects and build output are generated locally and are not committed. Debug builds show experiences that are
still candidates (A14 Solar System Explorer today) with the launch argument `-vcCandidates`.

## Testing and continuous integration

```bash
swift test --package-path Packages/VisualCore                                   # pure modules on the macOS host
python3 scripts/release_check.py --list                                          # every release check and its command
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/verify_experiences.py --runtime 27                              # scenario manifests of every experience
python3 scripts/release_check.py --only docs app-contracts compliance dependencies public-api licenses script-tests
```

- App tests build once (`build-for-testing`) and run in `test-without-building` chunks under a time limit
  (`scripts/xcodebuild_app.py --max-seconds`, default 540 s); interface tests are grouped in chunks (`UI_CHUNKS` in
  `scripts/release_check.py`), each test under 60 seconds; package tests run in under 10 seconds each.
- Simulators are chosen by runtime (`sim-27.2`, `sim-26.5`), never by a copied identifier.
- System accessibility audits run only in the device campaign (`VC_RUN_AUDITS=1`).
- Simulator results are development evidence, not device evidence.

**CI** ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs on pushes to `main` and on pull requests, on macOS
runners: the ledger, documentation, steering-document, planning-archive, planning-index, migration-ledger,
compliance, dependency, public-API, documented-API, license and script checks; `swift test` for
`Packages/VisualCore` and the harness package `GardenKit`; and an iOS Simulator build of the pure package. It runs no
rendering tests, because those need the locally built ANGLE frameworks. A second workflow
([.github/workflows/push-scan.yml](.github/workflows/push-scan.yml)) repeats the pre-push scan (device identifiers,
team ids, secrets) over the commits of every push and pull request; it is never cancelled by a newer push.

## Repository structure

| Path | Contents |
|---|---|
| `Apps/VisualCore/` | the single shippable app: launcher, routes, settings, about, onboarding, the experience registry (`App/ExperienceRegistry.swift`), unit tests (`Tests/Unit`) and interface tests per experience (`Tests/UI/<Experience>`) |
| `Apps/GenerativeArtStudio/`, `Apps/FluidArtPlayground/`, `Apps/FractalExplorer/` | resources kept from the former standalone apps; their sources now live in `Packages/ExperiencesCreative` |
| `Packages/VisualCore/` | pure Swift modules without GPU or UIKit code; tested on the macOS host |
| `Packages/VisualCoreRendering/` | iOS modules over ANGLE: render host, experience host, resources, shaders, effects, UI, audio, automation |
| `Packages/ExperiencesCreative/` | the creative experiences, one folder each with `Core`, `CoreTests`, `Experience`, `ExperienceTests` and a `scenario-manifest.json`: `GenerativeArtStudio`, `FluidArtPlayground`, `FractalExplorer`, `ParticleUniverse`, `InfiniteGeometry`, `VisualCoreMusicLab`, `AudioOdyssey`, `OscilloscopeStudio`, `DigitalAquarium` |
| `Packages/ExperiencesRound02` … `Round04` | **planned** packages for the games (ADR-0009, D-06); none exists yet |
| `Showcase/` | developer Showcase app; not an App Store product |
| `Harnesses/` | non-shipping test hosts: `InteractiveDemo/`, `SecondConsumer/` (Lumen Garden, a small sample game), `ProjectMReference/` |
| `External/projectm-ios/` | pinned, read-only Git submodule: reference app, reference regression and source of the ANGLE build |
| `Catalog/` | runtime catalog generated by `scripts/build_catalog.py`: `experiences.json` (the 100 launch experiences), `categories.json`, `registrations.json`, `path-map.json` and the golden list of all 300 experience ids |
| `Configs/` | pinned tool versions (`toolchain.json`), the signing include (`Signing.xcconfig`), the copy-claim denylist, the permission vocabulary and the hashes of this Mac's simulator identifiers for the pre-push scan |
| `Tools/python/` | `desktop_runbook.py`, the legacy ledger tool |
| `scripts/` | deterministic Python checks and tools: release check, build and test runners, validators, ledgers, planning index, copy and release-document checks |
| `specs/` | 82 feature dossiers produced with Spec Kit (spec, plan, research, data model, contracts, checklists, tasks) |
| `docs/` | architecture, API baseline, decisions, catalog, migration, per-experience documents (`docs/apps/<slug>/`), release notes and limitations, legal notices, planning archive |
| `.autonomy/` | evidence ledgers: `state.json`, `evidence/` and `checks/` (legacy), `migration/` (unified app) |
| `.specify/`, `.claude/skills/` | Spec Kit configuration and constitution; the committed Spec Kit skills |
| `.github/workflows/` | `ci.yml` (checks, host tests, simulator build), `push-scan.yml` (scan of every pushed range) |

## Framework modules

From [Packages/VisualCore/Package.swift](Packages/VisualCore/Package.swift) and
[Packages/VisualCoreRendering/Package.swift](Packages/VisualCoreRendering/Package.swift):

- **`Packages/VisualCore`** (pure Swift): `VisualCoreMath`, `VisualCoreSimulation`, `VisualCoreScenes`,
  `VisualCoreShaderSource`, `VisualCoreEffectsGraph`, `VisualCoreDiagnostics`, `VisualCorePersistence`,
  `VisualCoreParameters`, `VisualCoreAudioDSP`, `VisualCoreExperience` (the experience contract, catalog identity,
  storage), `VisualCoreTestSupport` (for tests) and the executable `VisualCoreBaselines`.
- **`Packages/VisualCoreRendering`** (iOS): `CVisualCoreEGL`, `CVisualCoreGL`, `VisualCoreRendering`,
  `VisualCoreEffects`, `VisualCoreUI`, `VisualCoreAutomation`, `VisualCoreAudio` and `VisualCoreExperienceHost`.

Every public declaration is listed in the [public API baseline](docs/api/visualcore-public-api.txt) and documented
with `///`; `scripts/check_public_api.py` fails on any undocumented or unrecorded change.

## Development workflow

- The project is developed with **Claude Code in the Claude Desktop app** and **GitHub Spec Kit**. Every phase of every
  experience runs the full Spec Kit loop — specify, clarify, plan, checklist, tasks, analyze, implement and converge
  (repeated until nothing is appended) — before its gate is sealed and recorded.
- [CLAUDE.md](CLAUDE.md) is the bootstrap every session reads first; the continuation prompt is the last section of
  [Auto-Creator.md](Auto-Creator.md).
- Work happens on `main`; every task, skill and gate is committed and pushed after `python3 scripts/prepush_scan.py`
  passes. History is never rewritten.
- Shared, pure logic belongs in `Packages/VisualCore`; GPU and UIKit code in `Packages/VisualCoreRendering`; each
  experience's own logic in its folder under `Packages/ExperiencesCreative`.

## Documentation

| Document | Purpose |
|---|---|
| [Auto-Creator.md](Auto-Creator.md) | forward-looking design and steering document for the unified app |
| [setup.md](setup.md) | machine and contributor setup |
| [CLAUDE.md](CLAUDE.md) | bootstrap for Claude sessions: reading order, live-state commands, fixed rules |
| [docs/decisions/ADR-0009-unified-app.md](docs/decisions/ADR-0009-unified-app.md) | decision record for the single app; ADR-0001 to ADR-0008 and ADR-0010 (constitution 2.0.0) are in `docs/decisions/` |
| [docs/migration/migration-plan.md](docs/migration/migration-plan.md) | migration plan: path map, milestones, rollback |
| [docs/migration/pre-fable-baseline.md](docs/migration/pre-fable-baseline.md) | state of the repository before the consolidation |
| `docs/apps/<slug>/` | per experience: README, VisualCore contract, regression baseline and, after its release phase, privacy and credits, store-text input, release checklist and device-campaign plan |
| [docs/release/known-limitations.md](docs/release/known-limitations.md) | what is unmeasured or device-only, per experience |
| [docs/release/build-and-archive.md](docs/release/build-and-archive.md) | build and archive steps, with the owner-only steps |
| [docs/archive/planning/README.md](docs/archive/planning/README.md) | index of the original planning documents, archived unchanged |
| [docs/index.md](docs/index.md) | framework documentation index |
| [docs/getting-started.md](docs/getting-started.md) | using the framework: modules, a first scene, samples |
| [docs/api/visualcore-public-api.txt](docs/api/visualcore-public-api.txt) | public API baseline: every public declaration of both packages |

The former root README, the full specification of the earlier 25-app plan, is archived unchanged at
[docs/archive/planning/root/README-2026-11-10-full-specification.md](docs/archive/planning/root/README-2026-11-10-full-specification.md).

## Contributing

Issues and pull requests are welcome. Before opening a pull request:

1. Read [setup.md](setup.md) and run `python3 scripts/verify_environment.py`.
2. Follow the rules in [CLAUDE.md](CLAUDE.md) §3 (one app, visuals as code, no advertising, no network, public Apple
   APIs only, `External/projectm-ios` read-only).
3. Run the fast checks: `python3 scripts/release_check.py --only docs app-contracts compliance dependencies public-api
   licenses script-tests` and `swift test --package-path Packages/VisualCore`.
4. Use LF line endings and never commit `Configs/Signing.local.xcconfig`, `.autonomy/private`, logs or result bundles.

## Keeping this README current

This README is a living document. It is updated in the same commit as any change it describes — at the latest when a
gate is recorded that changes the Status table (an experience's X gate, a unified-app feature, a milestone), when a
package, module, top-level folder, workflow or tool version is added or removed, or when a documented command
changes. The status date at the top of [Status](#status) names the day of the last update; the ledgers remain the
source of truth.

## License

MIT License. The full text and the copyright notice are in [LICENSE](LICENSE).

Third-party components and their licenses are listed in
[docs/legal/THIRD_PARTY_NOTICES.md](docs/legal/THIRD_PARTY_NOTICES.md) and, in machine-readable form, in
[docs/legal/third-party.json](docs/legal/third-party.json). The notices list libprojectM (LGPL-2.1) as harness-only:
it is used by `Harnesses/ProjectMReference`, a tester tool that is not distributed; see
[docs/legal/lgpl-analysis.md](docs/legal/lgpl-analysis.md).
