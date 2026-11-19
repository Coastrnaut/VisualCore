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

### Simulation Lab (A16; features 116–122)

- The frame pacing at ×4 for each family, the thermal state and the peak memory over a short run are unmeasured on
  devices; they wait for the device campaign ([device-campaign.md](../apps/simulation-lab/device-campaign.md), rows
  SL-D1 and SL-D2). No frame-time, thermal, power or memory figure is stated; the steps per second of the validation
  report are simulator figures, not device claims.
- VoiceOver on hardware (row SL-D3), Dynamic Type at the largest sizes and the system accessibility audits (row SL-D4)
  and the share sheet to Files on hardware (row SL-D6) wait for the device campaign; the labels and values, the Seed
  button for the paint gesture, the canvas description with the legend in words, the approximation label and the
  Reduce Motion and Reduce Flashing caps are proved by the experience's tests only. No automated test presents the
  share sheet.
- Every simulation is an educational approximation, labelled as one: the grid is 64 × 64 cells for every family and
  every saved experiment; the automaton's states are exact (0 or 1) with a wrap boundary; reaction-diffusion and the
  wave keep half-float values, reaction-diffusion with a wrap boundary and an explicit Euler step, the wave with a
  fixed zero boundary and a leapfrog step. The drawn field is compared with a CPU reference on a small grid within a
  stated tolerance ([validation-report.md](../apps/simulation-lab/validation-report.md)); no physical, chemical or
  numerical claim beyond that is made.
- The time step has a stability limit: Δt at most 1.5625 for reaction-diffusion and a Courant number at most 0.707 for
  the wave; a step beyond it is refused with its sentence and changes nothing. The automaton has no time step.
- Reaction-diffusion and the wave need floating-point render targets. Where the device does not offer them, the status
  says so ("Reaction-diffusion and the wave field need floating-point render targets, which this device does not
  offer.") and the field is drawn from the CPU; this path is tested on the simulator only (`FloatUnsupportedTests`)
  and waits for the device campaign on the oldest device (row SL-D5).
- Six bundled presets in version 0.1 (Life, HighLife, Seeds, Spots, Mazes and Pulse), one palette per family and no
  rule or palette editor. The library holds at most 24 saved experiments, kept on the device only (no sync, no
  export); a save beyond that is refused with "The library holds 24 experiments; delete one first." A damaged, newer
  or refused preset file is reported and skipped, never deleted or rewritten
  (`PresetStoreTests.testDamagedAndNewerFilesAreSkipped`).
- One picture at a time: a capture is a 1024 × 1024 PNG in the temporary folder `a16-captures`, replaced by the next
  capture and removed when the experience opens; it leaves the device only through the share sheet the person opens,
  and nothing is written to Photos.
- One drawing level (`level-0`): there is no lower level under Low Power Mode or a serious thermal state.

### Interactive Anatomy (A17; features 123–129)

- The frame pacing at both drawing levels, the thermal state over a loop of use and the memory high-water mark are
  unmeasured on devices; they wait for the device campaign
  ([device-campaign.md](../apps/interactive-anatomy/device-campaign.md), rows IA-D1 to IA-D3). No frame-time, thermal,
  power or memory figure is stated.
- VoiceOver on hardware with the list alone (row IA-D4), Dynamic Type at the largest size (row IA-D5), Reduce Motion
  on hardware (row IA-D6) and the system accessibility audits (row IA-D7) wait for the device campaign; selection from
  the list alone, the labels, values and hints, the layer signs, the canvas description, the rate-limited announcements
  and the native control for every gesture are proved by the experience's tests on the simulator only.
- Educational, not medical. One region in version 0.1, the right knee, with 14 parts in three layers (bones;
  cartilage and menisci; ligaments and tendons); no other region, no full-body atlas and no patient files.
- The model is schematic: every shape is procedural geometry made in code and simplified, and the experience says so
  ("Schematic model for learning; shapes are simplified."). Two drawing levels, `level-0` (6,444 triangles) and
  `level-1` (2,716 triangles), each in 20 draws.
- The text is not reviewed by a clinician: every part shows "Not reviewed by a clinician." The lead engineer checked
  the text against its cited sources (an editorial check, not a clinical review); a clinical review is an owner action
  ([review.md](../apps/interactive-anatomy/review.md)). The sources are Gray's Anatomy, 20th edition (1918, public
  domain), cited by section, and Terminologia Anatomica (1998) for the standard names; the descriptions are original
  ([content-sources.md](../apps/interactive-anatomy/content-sources.md)).
- In-scene labels are capped at 16 and never overlap: a label that would overlap another, leave the canvas or belong
  to a ghosted or hidden part is skipped, so the model may show fewer names than parts. The structure list always
  names every part, and every part can be selected from it.
- The camera turns in 15° steps, tilts in 10° steps within −6…6 and zooms in × 0.85 steps within −4…6; a step beyond a
  limit is refused with "The camera is at its limit." Nothing animates, with Reduce Motion or without.
- Ghosts need the additive translucent stage of the depth pass; if that draw fails, the ghosts are off for the rest of
  the session, the isolate is drawn as in the hide mode and the panel says "Ghosts are off."
- One saved view, `view.json`, kept on the device only (no sync, no export) and replaced on each view change. A
  damaged, newer, foreign or oversized file (more than 65,536 bytes) is refused and left as it is, and the opening
  view opens; view schema 1 opens migrated.

### Ambient Clock (A18; features 130–136)

- The overnight runs on power and on battery, the heat over 30 minutes, the memory high-water mark and the frame
  pacing are unmeasured on devices; they wait for the device campaign
  ([device-campaign.md](../apps/ambient-clock/device-campaign.md), rows AC-D1 to AC-D5). No frame-time, thermal,
  power, battery or memory figure is stated.
- The screen-care drift on OLED (row AC-D6), night readability in a dark room (row AC-D7), time changes made in the
  device's Settings (row AC-D8), VoiceOver and Dynamic Type on hardware (row AC-D9) and the system accessibility audits
  (row AC-D10) wait for the device campaign; the spoken time, the labels and values of the controls, the one-line time
  at the largest text size, the contrast of the text and the motion rules are proved by the experience's tests on the
  simulator only.
- The clock shows the device's system time, formatted with the system's calendar, time zone and locale; it is as
  correct as the system clock and reads no other time source. The text changes at each whole minute, or each whole
  second with seconds shown. No alarms, timers, weather or network content.
- Four themes in version 0.1 (Noise Gradient, Particle Drift, Wave Field and SDF Shapes), each with three fixed
  palettes and no palette editor; two drawing levels, `level-0` and `level-1`. A theme whose shader fails to compile
  keeps the previous theme; a failure of the noise gradient at setup fails the session with its message.
- Night mode dims and warms only the drawing and turns the text warm amber; it never changes the system brightness.
  The schedule is set in 15-minute steps.
- Screen care moves the time and the scene by at most 8 points on either axis and dims them to 0.6 after ten minutes
  without an action; under reduced motion there is no drift. It is not a guarantee against image retention.
- Keep-awake is off by default, turned on only by the person, and holds the screen on only while the clock is open and
  in the foreground; leaving the clock releases it.
- At most 12 favourites, kept in `favourites.json` on the device only (no sync, no export); a 13th is refused with its
  sentence. A damaged, newer, too large or invalid favourites file gives an empty list and is left as it is until the
  next save, which replaces it. The settings are kept in the snapshot (schema 3); schemas 1 and 2 open migrated.

### Living Wallpapers (A19; features 137–143)

- No wallpaper is set by the app. Living Wallpapers exports a still image; the person keeps it through the system
  share sheet and makes it the wallpaper in the Settings app (the help names the steps, which can differ between iOS
  versions). The app makes no system-wallpaper call, and an export is never a moving wallpaper.
- No short video in version 0.1: the Phase 01 decision is no-go
  ([video-decision.md](../apps/living-wallpapers/video-decision.md)). Exports are stills only: PNG, JPEG or HEIC
  (HEIC only where the device can encode it), tagged sRGB.
- The export size is the device template's pixel size, capped by the device: a template fits only when both edges are
  at most the device's export limit (the context's maximum texture size), the long edge at most 8192 and the pixel
  count at most 64,000,000. A template that does not fit is refused with a notice that offers the largest size that
  fits at the template's shape. Nine templates in version 0.1 (five iPhone, four iPad); no custom size.
- The safe-area guides are approximate design fractions of the canvas (a top band of 0.22, a bottom band of 0.10, side
  margins of 0.04), not system measurements; the system may place the time or widgets differently.
- Four scenes in version 0.1 (Aurora Bands, Ink Flow, Soft Cells and Ripple Dunes), each with three colour presets
  whose four colours can be edited; two drawing levels, `level-0` and `level-1`.
- The export history keeps at most 20 entries in `history.json` on the device only (no sync), newest first, and the
  controls list the newest five; "Clear history" removes the file. A damaged, newer or too large history file gives an
  empty history and is left as it is until the next written export. The temporary export folder holds at most one
  file. The settings are kept in the snapshot (schema 2); schema 1 opens migrated.
- The size limit and the largest templates per device, the written file's size and profile in Files and Photos, the
  heat and memory during the largest exports, the add-only Photos prompt and the declined path, and the system
  accessibility audits wait for the device campaign
  ([device-campaign.md](../apps/living-wallpapers/device-campaign.md), rows LW-D1 to LW-D8). No size-limit, thermal,
  memory or timing figure is stated; the simulator's limit is larger than every template, so no template is refused
  there.

### Digital Zen Garden (A20; features 144–150)

- No granular material physics. The sand is a height field changed by each rake stroke and drawn as a lit relief in
  code; grains do not pile, flow or slide, and stones do not push sand. With the sand drift on, only the grain pattern
  moves; Reduce Motion keeps the picture still.
- No online gallery, sign-in or multiplayer. Gardens are saved on the device only (no sync); the picture leaves the
  app only when the person hands it to the system share sheet.
- One picture size in version 0.1: Make picture writes one PNG of 1600 by 1200 pixels, tagged sRGB, into the temporary
  folder `DigitalZenGarden-Still`, which holds at most one file. No other size, format or crop.
- The library holds at most 12 named gardens (unreadable files count until the person deletes them); a name is 1 to 40
  characters. A damaged, newer or too large garden file is listed as unreadable and is never opened or deleted
  automatically; an index of a newer version makes the library read only.
- The undo history keeps the newest 100 commands; older ones fold into a checkpoint and cannot be undone. The history
  restarts after a restore or when a saved garden is opened. A garden holds at most 24 stones and 400 strokes, and a
  stroke at most 512 points.
- The calm switches (sound, sand drift, haptics) are off by default and kept as the experience value `calm.v1`; the
  tones are made in code and follow the silent switch.
- Touch-to-groove latency, fast drags, idle drawing, heat, energy use during a long session, precision on the smallest
  phone, the quiet defaults with the silent switch and the system accessibility audits wait for the device campaign
  ([device-campaign.md](../apps/digital-zen-garden/device-campaign.md), rows ZG-D1 to ZG-D8). No latency, thermal,
  energy or timing figure is stated.

### Aurora (A21; features 151–157)

- Stylized skies, not a depiction of the real sky. The three skies (Polar night, Violet veil, Dawn haze) are one
  fragment shader of ribbons, stars and clouds over noise, drawn in code and looping seamlessly every 600 s. Aurora
  reads no live or measured aurora data, no weather and no position, and predicts nothing.
- The brightness limit caps the drawn sky only (a soft knee on each pixel's Rec. 709 luminance, from 0.2 to 0.72,
  0.6 by default). Aurora never changes the screen brightness and never keeps the screen awake; the system's
  auto-lock applies as usual.
- The optional sound is one loop synthesised in code (`AmbientLoopRecipe.gentle`) on the ambient session category,
  so the silent switch silences it and other playback continues. It is off by default and plays only while Aurora is
  open in the active app with the sound on; it does not play in the background and does not restart by itself after
  an interruption. No other sound, no sound file and no recording.
- "Still sky" draws the sky once and repeats the cached picture until a control changes; "Reduced flashing" turns the
  star twinkle off and makes a change between skies take 4.0 s instead of 2.0 s. Under Reduce Motion the sky holds
  and every change is immediate. Under Low Power Mode the host draws at most 30 frames per second; the sky time is the
  same at either cadence.
- When the sky shader fails to compile or the device reports no fragment `highp`, Aurora shows a simpler still sky
  under the same limit with the line "This device shows a simpler sky."; if that fails too, the frame is the sky
  colour.
- The saved choices (`prefs.v1`: the sky preset, the colour shift, the motion and sky values, the brightness limit,
  the sound on or off and the volume) are kept on the device only (no sync). A damaged, newer or out-of-range value
  opens the defaults with a message and is left as it is until the next accepted change. Aurora writes no temporary
  file and exports no picture.
- Heat and frame rate per sky, battery use over a session, the low-power cadence, the comfort of the brightness limit
  and reduced flashing on a real screen, the still view's idle drawing, the loop on the speaker with the silent switch,
  shader compilation at both refresh rates and the system accessibility audits wait for the device campaign
  ([device-campaign.md](../apps/aurora/device-campaign.md), rows AU-D1 to AU-D8). No thermal, battery, frame or timing
  figure from a device is stated.

### Shader Studio (A22; features 158–164)

- No sandbox. A person's shader runs on the device's graphics processor through the app's renderer (OpenGL ES over
  ANGLE on Metal); GPU code is not a sandbox, and Shader Studio makes no claim that a shader is harmless to run. What
  it does: the source validator refuses a source past the limits before any compile, a failed compile keeps drawing
  the last good program, and a frame watchdog stops the preview after 8 consecutive frame intervals each above
  0.25 s (one interval after a Run or a Reset is skipped) and draws a flat dark frame until "Reset preview" brings
  back the last good program. A shader can still keep the graphics processor busy until the watchdog stops it.
- GLSL ES 3.00 fragment shaders only. The person writes one fragment shader over the template prelude (the version
  line, precision, `u_time`, `u_resolution` and the output come from the prelude); there are no vertex, geometry or
  compute stages, and only float uniforms (at most 16) and texture inputs (at most 2) bound to the
  three textures made in code (Checker, Ramp, Noise). Other shader languages and dialects are not accepted.
- Values beyond the limits are refused, never truncated: a source above 16,384 bytes or 400 lines, more than 16
  uniforms or 2 texture inputs, a `#version` line, a reserved or undeclared name and a source without `void main` are
  refused with their reason before any compile; the expanded shader stays under 64 KiB. The library holds at most 24
  projects, names of 1 to 40 characters (names differing only in case are the same) and files of at most 131,072
  bytes; a 25th save, a used name or a full storage quota is refused with its message and changes nothing.
- No sharing or export. Projects stay in the experience's own storage on the device (no sync, no file export, no
  share sheet, no import from other apps). The snapshot keeps the template, the uniform values, the texture choices
  and the document's shape, not the edited source: unsaved edits are kept only by saving a project.
- A damaged, newer, too-large or out-of-range project file is listed as unreadable with its code and never opened,
  renamed or removed automatically; an index of a newer version makes the library read only; a damaged index is
  rebuilt by the next change.
- The stop of a slow shader, the line mapping of compile errors, the hardware keyboard, a project kept across a
  relaunch, the compatibility profile of each device's context, background and return, and the system accessibility
  audits wait for the device campaign ([device-campaign.md](../apps/shader-studio/device-campaign.md), rows SS-D1 to
  SS-D6). No frame, stop, heat, battery or capability figure from a device is stated.

### Visual Programming Lab (A23; features 165–171)

- No typed code. A picture is composed only from a graph of the seven node kinds written in code (Time, Constant,
  Noise, Gradient, Mix, Blur and Output) and their parameters within their ranges; the person types no code, script or
  shader, and only the preview operators written in this repository are compiled. There are no loops, feedback nodes
  or custom nodes.
- Values beyond the limits are refused, never truncated: a graph holds at most 32 nodes and 64 connections; a 33rd
  node, a second Output, a 65th connection, a connection of the wrong type, into an input already fed or closing a
  loop is refused with its sentence and changes nothing. The preview uses at most six 256 × 256 textures (1.5 MiB);
  a graph needing more is refused with "This graph needs N textures; the preview allows 6." before any texture is
  allocated. The library holds at most 24 graphs, names of 1 to 40 characters (names differing only in case are the
  same) and files of at most 81,920 bytes; a 25th save, a used name or a full storage quota is refused with its
  message and changes nothing.
- No sharing or export. Graphs stay in the experience's own storage on the device (no sync, no file export, no share
  sheet, no import from other apps). The snapshot keeps the open graph and the selection; named graphs are kept only
  by saving them in the library.
- A damaged, newer, too-large or out-of-range graph file is listed as unreadable with its code and never opened,
  renamed or removed automatically; an older graph file is migrated when a migration step exists; an index of a newer
  version makes the library read only; a damaged index is rebuilt by the next change.
- The largest example's texture memory and pacing, the refusal of a 7-texture graph, touch wiring and the list form by
  a finger, pacing under heat and Low Power Mode, background and return, and the system accessibility audits wait for
  the device campaign ([device-campaign.md](../apps/visual-programming-lab/device-campaign.md), rows VPL-D1 to
  VPL-D6). No frame, memory, heat, battery or capability figure from a device is stated.

### Graphics Benchmark Lab (A24; features 172–178)

- Three built-in cases only: Textured quads (8 layers over a 256 × 256 texture made in code), Shader ALU (64
  iterations per fragment) and Particles (5,000 particles), each version 1 at resolution 1.0. There is no custom case,
  no other workload and no setting the person changes.
- A run lasts exactly its plan: a warm-up of 3 s, a measurement of 10 s and a cool-down of 5 s
  (`BenchmarkCase.builtInPlan`); only the measured frames count. Stopping it, choosing another case, closing the
  session, a context rebuild, a size change or leaving the app ends it early (stopped or interrupted), and such a run
  is invalid. A serious or critical thermal state ends a run at once as "Interrupted: the device is hot".
- The library holds at most 12 saved results of at most 2,162,688 bytes each; a 13th save or a full storage quota is
  refused with its message and changes nothing. A damaged, newer, too-large or refused result file is listed as
  unreadable with its code and never opened or removed automatically; an index of a newer version makes the library
  read only.
- GPU time only where the renderer offers `GL_EXT_disjoint_timer_query`; otherwise the result says "GPU time not
  available on this device." and no other time is shown as GPU time. The presenter draws at most 60 frames per second.
- Runs are qualified as Valid, Qualified or Invalid with their reasons; the repeatability view compares only trials
  of the same case fingerprint, device model, OS version, app build and quality tier. There is no ranking, no overall
  figure and no comparison with other devices' results or with other tools.
- A result leaves the device only as a JSON run file or a CSV exported on the person's tap and handed to the system
  share sheet; the export files are temporary and removed when the session closes and when the experience opens
  again. Nothing is sent automatically.
- Simulator numbers are not device evidence: they come from the computer that runs the simulator. Repeatability,
  thermal behaviour, Low Power Mode, pacing and dropped frames, GPU timing on hardware, and the system accessibility
  audits wait for the device campaign ([device-campaign.md](../apps/graphics-benchmark-lab/device-campaign.md), rows
  GBL-D1 to GBL-D6). No frame interval, CPU or GPU time, spread, heat, battery or capability figure from a device is
  stated.

## Distribution

- No App Store submission, signing or purchase setup is part of this release; those are owner actions.
- LGPL-licensed projectM appears only in a harness that is not distributed
  ([lgpl-analysis](../legal/lgpl-analysis.md)).
