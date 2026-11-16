# Known limitations (feature 010 T-F910; FR-F904)

VisualCore 1.0.0-rc.1 is a **release candidate verified on iOS simulators only**. Read
[support-matrix.md](support-matrix.md) first.

## Evidence

1. **No physical-device evidence.** Device performance, compatibility, rendering correctness on real GPUs,
   thermal behavior and launch times are unmeasured until campaign II (D1 → D2 → D3).
2. **Performance baselines are host and simulator numbers** ([docs/performance](../performance/README.md)). They catch
   regressions; they are not targets and not device claims.

## Unsupported capabilities

| Capability | Status | Reason |
|---|---|---|
| System / other-app audio capture | Not offered | No public iOS API for arbitrary system audio capture is used; ReplayKit or entitlement workarounds are prohibited (CLAUDE.md §5). The iOS 27 System/App Capture evaluation belongs to the ProjectM-iOS product, not VisualCore, and must show as unavailable on iPadOS 26.5 (D3). |
| Home-screen live wallpaper | Not offered | iOS has no public API for third-party live home-screen wallpapers (CLAUDE.md §4). |
| Direct Metal rendering | Not offered by design | The only renderer is OpenGL ES through ANGLE's Metal backend; a second renderer is prohibited (CLAUDE.md §4). |
| Microphone / in-app playback audio | Not built yet | See ADR-0006; any source claim needs a ten-minute real-device diagnostic. |
| User-authored GLSL | Not offered | Shaders are bundled, versioned assets; a shader editor needs strict input and resource bounds (planned with A22 Shader Studio). |

## Modules planned in the README layout but not built yet (ADR-0006; updated after A01-P01)

Built since rc.1: `VisualCoreParameters` (new), `VisualCoreUI.RenderSurface`, `VisualCoreTestSupport` image comparison,
and `VisualCoreRendering` `ShaderBundle`, the `vc/*.glsl` library and `FullScreenShaderScene` (feature 012).
Feature 013 added `SceneClock`, `ParameterEditor` and `VisualCoreUI.ParameterPanel`. Feature 014 built
`VisualCorePersistence` (`DocumentStore`). Feature 015 added offscreen still export (`RenderHost.renderOffscreen`,
`StillImage`, `StillImageEncoder`) and `VisualCoreScenes.ExportGeometry`. Feature 016 added `AccessibilityPreferences`,
`VisualCoreUI.SystemAccessibilityObserver`, `AccessibilitySettingsSection`, `AccessibleColors` and
`EffectScene.bypassEffects`. The table
lists what remains.

| README entry | Missing part | Where it will be built |
|---|---|---|
| VisualCoreAudio | Microphone / in-app playback taps (`VisualCoreAudio`), FFT, bands, RMS and onset (`VisualCoreAudioDSP`). Both modules are placeholders. | With the first audio app phases (A06 VisualCore Music Lab, A07 Audio Odyssey, A08 Oscilloscope Studio), with ten-minute real-device diagnostics before any source-support claim (FR-031 lesson) |
| VisualCoreInput | Game-controller adapters. Touch, tap, drag and pinch exist. | With the first app manual that requires controllers (A10 Neon Arcade), if its manual calls for them |
| VisualCoreTestSupport | Fake clock and deterministic fixtures. `ImageComparison`/`ImageStatistics` were built in A01-P01. | When an app needs them |
| VisualCoreUI | Diagnostics overlay and accessibility settings model. `RenderSurface` was built in A01-P01. | A01-P02 (accessibility settings) and the first app that needs the overlay |
| VisualCoreDiagnostics | Asset metrics. Frame, memory, thermal and Low Power Mode are present. | With the first asset-heavy app |
| VisualCoreShaders | A shader "preset" format beyond defines. ProjectM presets stay out of the public API by rule. | Only if an app manual requires one (e.g. A22 Shader Studio) |

The README's ten separate packages are consolidated into two SwiftPM packages, `VisualCore` (pure, host-testable)
and `VisualCoreRendering` (iOS, GL). ADR-0003 and the package map record this. Resources live in
`VisualCoreRendering`'s `ResourceRegistry`, shader sources in `VisualCoreShaderSource`, and scenes/input in
`VisualCoreScenes`, `VisualCoreMath` and `VisualCoreSimulation`.

## Rendering

- OpenGL ES 3.0 through ANGLE's Metal backend only. There is no direct Metal renderer and no public EGL bridge, by design
  (CLAUDE.md §4).
- All GL work runs on the main thread (`@MainActor` RenderHost). A Swift actor is not an EGL-thread guarantee.
- The ProjectM engine path in `Harnesses/ProjectMReference` matches its reference within the engine's own
  noise floor (SC-F702 amended: noise floor − 1 pp, ≥ 95 %, mean ≤ 2), not bit-exactly.
- Effect graphs are limited to 32 passes and a 256 MiB render-target quota by default.

## Experiences

### Particle Universe (A04; feature 038 T-A04-617)

- Frame pacing, the drawn-detail steps under load, thermal behaviour and memory are unmeasured on devices; the only
  profile is a simulator signal. They wait for the device campaign ([device-campaign.md](../apps/particle-universe/device-campaign.md)).
- The system accessibility audits (default and largest text size) wait for the device campaign (owner ruling of
  2026-11-13).
- Drawn detail reacts to frame time, heat and Low Power Mode; the simulation itself is never thinned.
- One placed force at a time; saved scenes stay on the device (no sync, no sharing, no export).

### Infinite Geometry (A05; feature 045 T-A05-607)

- Frame time per quality tier for every preset kind, the tier the governor settles on, memory with the mesh cache
  full, the thermal state over a short session and the export time are unmeasured on devices. They wait for the device
  campaign ([device-campaign.md](../apps/infinite-geometry/device-campaign.md)).
- The system accessibility audits (default and largest text size) and the VoiceOver journeys wait for the device
  campaign (owner ruling of 2026-11-13).
- Drawn detail of the 3D composition follows the host's quality level (thermal state and Low Power Mode); the 2D
  presets draw the same at every level, and the composition and its digest never change.
- Compositions are static: nothing moves with time, so Reduce Motion has nothing to reduce.
- Saved compositions stay on the device (no sync); a picture leaves only through the share sheet, as a PNG without
  metadata. At most 64 files fit in the experience's storage.

### VisualCore Music Lab (A06; feature 052 T-A06-607)

- Frame time per scene and analysis level, the tier the governor settles on, memory and the thermal state over ten
  minutes are unmeasured on devices. They wait for the device campaign
  ([device-campaign.md](../apps/visualcore-music-lab/device-campaign.md)).
- Interruptions (call, alarm, Siri), route changes (headphones out) and media resets are tested only as simulated
  audio-session events; their behaviour on hardware, and that other apps' music keeps playing, wait for the device
  campaign.
- The microphone permission flows (first request, refusal, grant, revoke in Settings while running) are tested with an
  injected permission state only; the system prompt itself is answered by the owner on the devices.
- The system accessibility audits (default and largest text size), VoiceOver labels and values on hardware (including
  the sound metrics text), Dynamic Type at the largest size, Reduce Motion and the contrast of each palette wait for
  the device campaign (owner ruling of 2026-11-13).
- The sound metrics text is an approximate visual aid, not a measurement; no hearing, health or accuracy claim is made.
- Sound is analysed in memory only and never recorded; the sound of other apps cannot be captured. A picked file is
  read in place; a file that cannot be decoded keeps the previous source and shows a message.
- Presets stay on the device (no sync); at most 64 files fit in the experience's storage, and a save beyond the quota
  is refused with a message.

### Audio Odyssey (A07; feature 059 T-A07-607)

- Frame time per world and quality level, piece generation while flying fast, the level the governor settles on,
  memory and the thermal state over ten minutes are unmeasured on devices. They wait for the device campaign
  ([device-campaign.md](../apps/audio-odyssey/device-campaign.md)).
- Interruptions (call, alarm, Siri), route changes (headphones out) and media resets are tested only as simulated
  audio-session events of the shared microphone source; their behaviour on hardware, and that other apps' music keeps
  playing, wait for the device campaign.
- The microphone permission flows (first request, refusal, grant, revoke in Settings while running) are tested with an
  injected permission state only; the system prompt itself is answered by the owner on the devices.
- The system accessibility audits (default and largest text size), VoiceOver labels and values on hardware (including
  the canvas description and the announcements), Dynamic Type at the largest size, Reduce Motion and calm motion, the
  contrast of each world and the comfort review of the flight's motion wait for the device campaign (owner ruling of
  2026-11-13). No comfort, motion-sickness or health claim is made.
- Drawn detail (pieces ahead and behind, draw distance, stars per piece) follows the host's quality level; the journey
  and its digest never change with it.
- Sound is analysed in memory only and never recorded; the sound of other apps cannot be captured. A picked file is
  read in place and not remembered across a restore: the person chooses it again. A file that cannot be decoded keeps
  the previous source and shows a message.
- Journeys stay on the device (no sync); at most 64 files fit in the experience's storage, and a save beyond the quota
  is refused with a message.

### Oscilloscope Studio (A08; features 065–066)

- Real two-channel routes, route changes, input latency, 44.1 kHz routes, frame time per view and quality level and the
  thermal state over ten minutes are unmeasured on devices; they wait for the device campaign
  ([device-campaign.md](../apps/oscilloscope-studio/device-campaign.md)). The two-channel microphone is tested only
  with a capture double.
- No latency figure is stated. Readouts are relative to full scale; no calibrated, certified, laboratory or medical
  accuracy is claimed. The accuracy audit checks the readouts against the built-in test signal only.
- VoiceOver on hardware, the announcements and the system accessibility audits wait for the device campaign.
- Drawn columns and the spectrum analysis rate follow the host's quality level; the scope state and its digest never
  change with it. Sound is analysed in memory only and never recorded.
- Saved presets stay on the device (no sync, no sharing, no export). The experience's folder holds at most 64 files
  and 16 MiB together (`StorageQuota`); a save beyond that is refused with a message saying the storage is full and
  changes nothing (`ScopePresetStore`; `ScopePresetStoreTests.testASaveBeyondTheStorageLimitIsRefusedAndChangesNothing`).
- A picked file is read in place and not remembered by its contents or address; after a restore the person chooses it
  again ("The audio file is no longer available. Choose it again, or use the test signal.").
- Persistence, the container's contents, memory, CPU and GPU frame time per view, Dynamic Type, Reduce Motion and
  Reduce Flashing and trace contrast are unchecked on devices; they wait for the device campaign.

### Digital Aquarium (A09; features 067–073)

- CPU and GPU frame time per quality level, the level the governor settles on, the thermal state over ten minutes of
  ambient mode and memory across feeds, saved aquariums and reopenings are unmeasured on devices; they wait for the
  device campaign ([device-campaign.md](../apps/digital-aquarium/device-campaign.md)). No frame-time, battery or
  memory figure is stated.
- The ambient dimming timing (fade after a minute without a touch, restore on a tap), Low Power Mode on hardware and
  the gestures on hardware (tap to feed, long press to place, drag a piece, two-finger touches) are tested on the
  simulator and with gesture doubles only; they wait for the device campaign. The system screen brightness and the
  idle timer are never changed (`AquariumRenderTests.testNoSourceSetsTheSystemBrightnessOrTheIdleTimer`).
- VoiceOver on hardware, the announcements, Dynamic Type at the largest sizes, Reduce Motion and Increase Contrast on
  hardware and the system accessibility audits wait for the device campaign.
- The saved-aquarium library holds at most 12 aquariums (`AquariumLibrary.maxEntries`); a thirteenth save is refused
  with a message and writes no file (`AquariumLibraryTests.testTheThirteenthSaveIsRefusedWithNoNewFile`). The
  experience's folder holds at most 64 files and 16 MiB together (`StorageQuota`); a save the storage refuses is
  refused with a message and changes nothing (`AquariumLibraryTests.testASaveTheStorageRefusesChangesNoFile`). Saved
  aquariums stay on the device (no sync, no export).
- The shared `GestureArbiter` reports a drag's changed phase once; Digital Aquarium sends a move for every later finger
  movement itself (app-local, A09-P03), so VisualCore is unchanged. Long-press-then-drag in one touch is not supported
  by the arbiter's one-owner rule; a piece is placed by a long press and moved by a separate drag.
- Ambient mode scales the fish's cruise speed and its floor by 0.6; with the steering forces the measured mean speed
  in ambient runs is about 0.5 to 0.6 of the species' cruise (simulator runs, feature 072), not exactly 0.6.
- Fish, food and the school are a bounded visual simulation, not an ecosystem: fish do not age, grow or need feeding,
  and food is only a visual effect.

### Neon Arcade (A10; features 074–080)

- CPU and GPU time per frame at each quality level, the thermal state over a ten-minute session and the readability of
  the glow on a real screen in bright light are unmeasured on devices; they wait for the device campaign
  ([device-campaign.md](../apps/neon-arcade/device-campaign.md)). No frame-time, battery or memory figure is stated.
- Audio routes (speaker, wired and Bluetooth headphones, the silent switch, interruptions on hardware) are tested with
  the ambient session on the simulator only (`SoundEffectPlayerTests`); they wait for the device campaign. Sound is
  synthesized, plays with the ambient session and opens no input.
- The VoiceOver pass on hardware, Dynamic Type at the largest sizes on hardware and the system accessibility audits
  wait for the device campaign; the labels, announcements, Reduce Motion and reduced flashing are proved by the
  experience's tests only.
- High-score survival after a force-quit on hardware waits for the device campaign; on the simulator an interrupted
  save leaves the last complete table (`HighScoreStoreTests.testAnInterruptedSaveLeavesTheLastCompleteTable`).
- The high-score table keeps the ten best runs with score, wave and run number only (no name or date); it stays on the
  device (no sync, no export, no online table). A damaged, half-written or newer table is reported, left in place and
  replaced by the next finished run's valid table
  (`HighScoreStoreTests.testANewerOrInvalidFileIsReportedAndThenReplaced`).
- The core's run number restarts at 1 after a reset or a refused saved state; a run the presenter saw end whose number
  the table has already processed is entered under the next number after the table's last run
  (`HighScoreStoreTests.testAWatchedEndingAfterARestartedCountIsEnteredAndMarked`), so a reset never loses a new run.
- Version 0.1 is one game, Neon Dodge; reaching game over through the interface takes minutes of play, so the
  game-over screen and its table are proved by the session and render tests, not by an interface test.

### Physics Playground (A11; features 081–087)

- Frame pacing at each quality level (stacked objects and free play at 48 bodies), the thermal state over a
  ten-minute session and the touch latency of a grab are unmeasured on devices; they wait for the device campaign
  ([device-campaign.md](../apps/physics-playground/device-campaign.md), rows PP-D1 to PP-D3). No frame-time, latency,
  battery or memory figure is stated.
- The VoiceOver pass on hardware (row PP-D4), Dynamic Type at the largest sizes on hardware and the system
  accessibility audits (row PP-D5) wait for the device campaign; the labels and values, the native alternative to
  every gesture, the spoken description with the tutorial steps and the absence of decorative motion are proved by the
  experience's tests only.
- The numbers of the playground — the material constants, the gravity, drag and stiffness levels, the arrows and the
  energy, momentum and speed of the state panel — are an educational approximation of a 2D rigid-body world at a fixed
  step, not engineering data or a physical measurement; the panel and the controls say so. Arrows show velocity,
  weight and the net spring force only; contact and drag forces are not drawn.
- The world is 2D with circles and boxes only (no polygons, soft bodies or fluids), at most 48 bodies; springs come
  with the starting scene and the presets and cannot be drawn by hand in version 0.1.
- Four saved experiment slots, kept on the device only (no sync, no export). A damaged, half-written or newer
  experiment file is refused with its reason and left in place until the person saves over it
  (`ExperimentStoreTests.testRefusedFilesAreReportedAndLeftUntouched`).

### Tiny Worlds (A12; features 088–094)

- Frame pacing at each detail tier (each pack with 24 props), the thermal state over a ten-minute session, the memory
  high-water mark across pack switches and the touch latency of orbit and place are unmeasured on devices; they wait
  for the device campaign ([device-campaign.md](../apps/tiny-worlds/device-campaign.md), rows TW-D1 to TW-D4). No
  frame-time, latency, battery or memory figure is stated.
- The system accessibility audits, Dynamic Type at the largest sizes on hardware and the VoiceOver pass on hardware
  (row TW-D5) wait for the device campaign; the labels and values, the native control for every gesture, the spoken
  view and pick descriptions and the Reduce Motion behaviour are proved by the experience's tests only.
- The worlds are stylised dioramas generated from a seed, not maps of any place: the island, the asteroid garden and
  the miniature city stand for no real location, and their heights, colours and light are artistic, not measured.
- Three presets, four prop kinds and three packs in version 0.1; at most 24 props per world, a fixed world size and no
  open-ended terrain or streaming; props can be moved, turned and deleted but not resized.
- Four saved world slots with their thumbnails, kept on the device only (no sync, no export). A damaged, half-written,
  too-large or newer world file is refused with its reason and left in place until the person saves over it
  (`WorldStoreTests.testRefusedFilesAreReportedAndLeftUntouched`).

### Light Maze (A13; features 095–101)

- Frame pacing on the largest boards (levels 15 and 20), the thermal state over a ten-minute session, the memory
  high-water mark across level switches, the touch latency of tap-to-turn, drag and two-finger rotation, and the feel
  of the success haptic and sweep are unmeasured on devices; they wait for the device campaign
  ([device-campaign.md](../apps/light-maze/device-campaign.md), rows LM-D1 to LM-D5). No frame-time, latency, power or
  memory figure is stated.
- The system accessibility audits, Dynamic Type at the largest sizes on hardware and the VoiceOver pass on hardware
  (row LM-D6) wait for the device campaign; the labels and values, the native alternative to every gesture, the spoken
  board and hints, colour plus sign with at least 3:1 contrast and the Reduce Motion and Reduce Flashing behaviour are
  proved by the experience's tests only.
- The beams follow the game's grid rules, not real light: a beam travels along the grid, a mirror turns it at equal
  angles on one of two diagonals, a prism splits it into two branches, and a beam ends after a set number of bounces;
  there is no refraction, colour mixing, intensity falloff or curved surface.
- Twenty handcrafted levels in version 0.1 and no level editor: levels cannot be made, imported or exchanged, and no
  levels are generated. Tiles turn between two diagonals only; they cannot be moved.
- The level progress is kept on the device only (no sync, no export). A damaged, half-written, too-large or newer
  progress file is refused with its reason, play starts from fresh progress, and the file is left in place until the
  next solve replaces it (`ProgressStoreTests.testRefusedFilesAreReportedAndLeftUntouched`).

### Solar System Explorer (A14; features 102–108)

- The frame time at both drawing levels, the drop to level 1 under Low Power Mode or a serious thermal state and the
  peak memory over tours, scale switches and reopenings are unmeasured on devices; they wait for the device campaign
  ([device-campaign.md](../apps/solar-system-explorer/device-campaign.md), rows SSE-D1 to SSE-D3). No frame-time,
  thermal, power or memory figure is stated.
- The system accessibility audits (row SSE-D4), the VoiceOver pass on hardware (row SSE-D5) and Dynamic Type at the
  largest sizes and Reduce Motion on hardware (row SSE-D6) wait for the device campaign; the labels and values, the
  native control for every action, the canvas description with date, distance and scale, the model statement, the
  Reduce Motion cut and the rate-limited announcements are proved by the experience's tests only.
- Positions come from an approximate model, not an ephemeris: Kepler orbits from the planets' mean elements at epoch
  J2000.0 (E. M. Standish, JPL), held fixed with no secular rates and no perturbations between planets; the model's
  Earth is the Earth–Moon barycentre. It is checked only against seven published events (four Mars oppositions, three
  Earth perihelia), each within ±3 days ([scientific-review.md](../apps/solar-system-explorer/scientific-review.md)).
- Dates run only from 1950-01-01 to 2051-01-01; a step or a playing clock stops at a range end with the reason. Times
  are UTC; there is no time zone, no sky as seen from a place on Earth and no rise or set times.
- The Sun and the eight planets only: no moons, dwarf planets, asteroids, comets or spacecraft, and the stars are a
  seeded decorative backdrop, not a star catalog. Surfaces are procedural colourings, not maps of the planets.
- In the enhanced view sizes and distances are enlarged and not to scale, which the legend and the canvas description
  say; the true-relative view is to one scale and marks bodies too small to see.
- Two tours and one saved view in version 0.1, kept on the device only (no sync, no export). A damaged, newer,
  oversized or out-of-range `view.json` is refused with its reason and left in place until the next Save view replaces
  it (`ViewStoreTests.testDamagedNewerAndOversizedFilesAreRefusedAndLeftUntouched`).

### Molecular Explorer (A15; features 109–115)

- The frame pacing with caffeine in both display modes, touch orbit and picking on hardware, the thermal state and the
  peak memory over a short session are unmeasured on devices; they wait for the device campaign
  ([device-campaign.md](../apps/molecular-explorer/device-campaign.md), rows ME-D1, ME-D2 and ME-D6). No frame-time,
  thermal, power or memory figure is stated.
- The VoiceOver journey on hardware (row ME-D3), Dynamic Type at the largest sizes and the system accessibility audits
  (row ME-D4) and the import through the system document picker from Files (row ME-D5) wait for the device campaign;
  the labels and values, the native control for every gesture, the canvas description with molecule, mode and selected
  atom, the announcements and the import's refusals are proved by the experience's tests only. No automated test
  presents the document picker.
- The library holds five molecules only: water, methane, ethanol, benzene and caffeine, each from its PubChem 3D
  conformer (CIDs 962, 297, 702, 241 and 2519). The structures are illustrative models; the radii and colours are
  display conventions ("Display radii, not measured sizes."), and the experience states no chemical safety, toxicity
  or medical fact.
- The bonds of an imported file are inferred, not read from the file: two atoms are bonded when their distance is at
  most the sum of their covalent radii plus 0.4 Å (and not below the 0.4 Å overlap limit); every inferred bond is
  single and marked inferred, so double, triple and aromatic bonds of an import are not shown as such. Only the
  library molecules carry recorded bond orders.
- The import is a small XYZ file only: at most 64 KB (65,536 bytes, checked before the file is read), at most 500 atoms,
  lines of at most 256 bytes, coordinates within 1,000 Å and only the ten elements the explorer knows (H, C, N, O, F,
  P, S, Cl, Br and I); no PDB, SDF, CIF or other format. A file outside these limits is refused with its reason and
  changes nothing.
- One import at a time: a new import replaces the stored copy (`import.xyz` and its title); there is no list of
  imports, no export and no sync. The recent list keeps at most eight molecules, kept on the device only. A damaged,
  newer, oversized or out-of-range `recent.json` or `settings.json` is refused with its reason and left in place until
  the next change replaces it (`RecentStoreTests.testRefusedFilesStayByteIdenticalWithTheirMessages`,
  `SettingsStoreTests.testRefusedFilesStayByteIdenticalWithTheirMessages`).
- One drawing level (`level-0`): there is no lower level under Low Power Mode or a serious thermal state.

## Distribution

- No App Store submission, signing or purchase setup is part of this release; those are owner actions.
- LGPL-licensed projectM appears only in a harness that is not distributed
  ([lgpl-analysis](../legal/lgpl-analysis.md)).
