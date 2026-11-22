# Automated testing in VisualCore

How VisualCore's code is tested automatically, how a test run becomes evidence for a gate, and what was learned while
building the experiences. This file is kept current: every gate that changes a test tool, a test rule or teaches a
new lesson updates it (CLAUDE.md, section 4). Older simulator-specific lessons from the first app campaign are in
[testing/simulator-test-lessons.md](testing/simulator-test-lessons.md); they still apply.

Last updated: 2026-11-21 (R02-G04-05: hints that reason from the player's clues are tested by following them through every certified level).

## 1. What is tested, and where

| Layer | What it covers | Where the tests live | How they run |
|---|---|---|---|
| VisualCore host tests | Pure Swift framework code: math, simulation, scenes, persistence, the experience contract | `Packages/VisualCore/Tests` (Swift Testing) | `swift test --package-path Packages/VisualCore [--filter <Suite>]` on the Mac |
| Rendering and host tests | GPU code on the OpenGL ES → ANGLE → Metal path, the experience shell, session and host view (including the canvas overlay slot, `CanvasOverlayTests`) | `Packages/VisualCoreRendering/Tests` | `scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing <Target/Class …>` |
| Experience core tests | Each experience's GPU-free rules (state, codecs, catalogs, solvers, fixtures) | `Packages/Experiences*/<Experience>/CoreTests` (Swift Testing) | `xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing <Experience>CoreTests` |
| Experience tests | The adapter core, scenario manifest, presenter (real frames read back on the simulator), controls and session | `Packages/Experiences*/<Experience>/ExperienceTests` (XCTest and Swift Testing) | the same command with `<Experience>ExperienceTests` |
| App unit and UI tests | The one app: registry, catalog, store, launch, per-experience UI flows | `Apps/VisualCore/Tests/Unit`, `Apps/VisualCore/Tests/UI` | `scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 [app-ui-ios27-<chunk>]` (wraps `scripts/xcodebuild_app.py`) |
| Verification runner | Every experience's scenario manifest played in the real app: launch, input, completion, rejection, save/restore, reset, suspend/resume, teardown/re-entry, cancelled preparation, fixtures | `docs/verification/<id>/summary-<runtime>.json` (results) | `scripts/verify_experiences.py --only <id> --runtime 27 [26]` |
| Repository checks | Steering documents, docs, contracts, packages, public API, licences, privacy, release copy | `scripts/` | `validate_autocreator.py`, `validate_docs.py`, `check_app_contract.py`, `check_experience_packages.py`, `check_public_api.py`, `check_documented_api.py --sources <dir>`, `test_scripts.py` |
| ProjectM reference regression | The seven-step reference regression of the pinned submodule | `External/projectm-ios` (read-only) | in two chunks, only at X gates |

Simulators are chosen by runtime (`sim-27.2`, `sim-26.5`), never by an identifier from an old log. Simulator results
are never device evidence; device runs wait for `ImplementationLock-100`.

## 2. From a run to evidence

1. **Every evidence command runs through an attested check:**
   `python3 Tools/python/desktop_runbook.py run-check --stage <gate> --timeout 600 --name <check> -- <command>`
   (legacy gates) or `python3 scripts/migration_ledger.py run-check --gate <X-…> --name <check> --timeout 600 -- <command>`
   (unified-app gates). It writes the log to `.autonomy/logs/<gate>.<check>.log` and an attestation with the exit code
   to `.autonomy/checks/<gate>.<check>.json`.
2. **Read `exit=` before using a check.** A failed check is kept, never overwritten; the rerun gets a new name
   (`<check>-2`). A task is ticked only after its proof passed, with `scripts/tick_task.py`, which appends
   `— Verified <date>: <evidence>` and commits.
3. **Seal and record:** `desktop_runbook.py seal --stage <gate>` collects the passing attestations (failed attempts are
   listed as skipped) into `.autonomy/evidence/<gate>.json`; `record` verifies them and passes the gate.
4. **Push** only through `python3 scripts/prepush_scan.py --push`, which scans outgoing commits for device
   identifiers, team ids and secrets. CI (`.github/workflows`) then reruns the repository and package checks; it is
   checked with `gh run list --workflow ci --limit 2` and never waited on.

## 3. The rules every test follows

- **Short tests.** Each test well under 10 s (UI tests under 60 s); no soak, endurance or long replay runs. Measure a
  short run and bound the rest by arithmetic; long-duration measurements belong to the device campaign.
- **No wall-clock assertions.** CI runners are about three times slower than the reference Mac. Anything timed takes an
  injected clock (for example an announcement limiter) or is asserted only by count and arithmetic.
- **Game Cores run on the host.** `swift test --package-path Packages/ExperiencesRound02` runs the round-two games'
  pure Cores (rules, levels, solvers) on macOS in seconds, locally and on CI; their Experience targets (UIKit, GL) are
  tested on the simulator from each game's renderer feature on.
- **Hot loops read shared tables through one buffer.** Parallel test runs that index a shared global array per sample
  contend on its reference count (Lissajous Labyrinth's lap went from about 35 s of tests to 5 s once the sine table was
  read through `withUnsafeBufferPointer` once per lap).
- **Experience targets in a host-tested package.** `Packages/ExperiencesRound02` keeps its Cores host-testable: an
  `<Name>Experience` target's rendering dependencies carry `.when(platforms: [.iOS])` and its sources are wrapped in
  `#if os(iOS)`, so `swift test` builds them empty on macOS; their simulator tests run with `xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2`.
- **Regenerate the project after `project.yml` changes.** `xcodebuild_app.py` builds the generated
  `VisualCore.xcodeproj` as it is; after a new package or product in `project.yml`, run `xcodegen generate` first, or the
  app build fails with "Unable to resolve module dependency". The app links every module its registry imports (a game's
  adapter core lives in `<Name>Core`, so the app links `<Name>Core` and `<Name>Experience`).
- **Gestures are scripted on the host.** A game's gesture logic lives in its Core as a controller that takes
  `PointerEvent`s and a view size and returns moves (Aurora Loom: `AuroraLoomGestureController`); host tests script
  touches at the projected handle positions and compare with an independently computed result, and one simulator test
  drives the same touches through the presenter's `pointer(_:viewSize:port:)`. Cache fitted cameras per view size and
  orbit: a 60-step bisection per event made the suite ten times slower.
- **Content witnesses are files compared byte for byte.** A game's generated levels carry witness files (Aurora Loom:
  `docs/games/aurora-loom/levels/NNN.witness.json`); the catalog test regenerates every witness and compares bytes, and
  writes the files only when asked (`AURORA_LOOM_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02
  --filter AuroraLoomCatalogTests`). Review the diff and re-pin the catalog digest after an intended rule change.
- **Timing values are asserted only in the isolated timing run.** The full suite prints the package timings (the
  R02-F05 mesh-budget bound, the audio analysis mean, the UA-F02 conformance run and the experience engine's timeout and
  cancellation); `VC_TIMING_ASSERTS=1 swift test --package-path
  Packages/VisualCore --filter "aMeshAtTheBudgetBuildsAndValidates|analysisTimingLevelZeroMeanBelowBudget|wholeRunForTheSampleTakesLessThanTenSeconds|aPreparationOverItsLimitTimesOut|aCancelledPreparationEndsWithinOneSecond"` asserts
  them, using thread CPU time at user-interactive quality of service, and skips with a printed reason when the
  one-minute load average exceeds the core count. CI never sets the variable.
- **No open-ended waits.** App test runs stop after `--max-seconds` (default 540) and name the test they were on; a run
  that would not fit is split into chunks of whole test classes (`--only-testing`). A command that goes silent for
  minutes is examined (log tail, `pgrep -fl xcodebuild`) before anything else starts.
- **Build once, test many.** An app pass builds with `app-build-for-testing-ios27`, then runs `test-without-building`
  chunks; parallel simulator clones are allowed (`--parallel N`).
- **Scoped runs.** Interim runs test only the changed experience; a phase gate runs iOS 27 only; iOS 26 and the
  reference regression run only at X gates; no baseline rerun on an unchanged tree (the last evidence is cited).
- **Accessibility audits wait for devices** (`VC_RUN_AUDITS=1` only in the device campaign).
- **Determinism.** Experience state is driven only by host steps and actions; a scenario played twice gives the same
  digest. Anything from the outside world (the current date, storage, the system clock) enters as an action or an
  injected dependency, so replays never read it.
- **Test data style.** Explicit types and plain loops instead of large nested closure literals (CI's type checker times
  out on them); synthetic UUIDs of the form `00000000-0000-4000-8000-…`; no scratchpad or session paths in evidence.

## 4. The per-gate test sequence (an experience phase)

1. Cite the last evidence on the unchanged tree (baseline task).
2. VisualCore addition, if the phase has one: host tests, `check_public_api.py --update` then `check_public_api.py`,
   `///` on every symbol, a README section; the reference regression waits for the X gate.
3. Experience core tests, then experience tests on `sim-27.2`. Regenerate generated files in the same run when their
   inputs changed: `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1` (scenario manifest),
   `UPDATE_DATA_SOURCES=1 TEST_RUNNER_UPDATE_DATA_SOURCES=1` (data-sources document), then rerun to prove the committed
   files match.
4. `xcodegen generate --spec project.yml`, app build-for-testing and app unit on iOS 27; the verification runner on
   iOS 27.
5. `check_experience_packages.py`, `test_scripts.py`, `check_app_contract.py --app <app> --render`.
6. `/speckit-converge` and implement until nothing is appended; seal, record, update README.md, run the post-record
   pipeline (planning index, traceability, catalog, distinctiveness, metadata inputs, Auto-Creator render and
   validation, docs validation), commit and push.

At an X gate add: the full package test, the VisualCore host suites, the runner on iOS 27 and iOS 26 (one after the
other: the runner holds a lock), the experience's UI chunk and the reference regression in two chunks.

## 5. Lessons learned

### Rendering and GPU objects

- **Eased presentation state and off-screen stills** (R02-G02-06, 2026-11-21). Lissajous Labyrinth's lights ease
  toward their targets by frame time. The pixel checks draw an off-screen still at time 0 after live frames, so the
  elapsed time was negative, the fade froze and the checkpoint colours lagged one change behind. A frame time that does
  not move forward (back, or the same time as the last frame: the golden hero frame of R02-G02-08 caught the second
  case), or a new level, now settles the lights at once; only changes within a live play fade.

- **Scale a sub-pixel frame check with the framing** (R02-G02-04, 2026-11-21). Lissajous Labyrinth's thread is about a
  quarter pixel wide at 96 × 64, so its checks run at a multiple of that still. Framing the dial rings beside the figure
  shrank the figure by about a third and left a few samples without a lit pixel; the fix scales the check size and
  every pixel radius by the same factor (8 × → 12 ×, colour search 1.5 → 2.25 px), which keeps the world distances the
  checks were written for, instead of loosening a tolerance.

- **Releasing one `MeshRenderer` releases the shared program for all.** Every mesh renderer shares one
  registry-cached shader program; releasing any renderer deletes it for every other renderer, and the remaining bodies
  then draw wrongly (A14-P01: every body drew at the selection). Create all renderers together, rebuild them all after
  a context recreation, and release them all together only in teardown.
- **Back faces are always culled.** `MeshRenderer` enables `GL_CULL_FACE` with `GL_BACK` on every draw; a flat shape seen
  from both sides (Saturn's rings) needs a second copy with reversed winding and flipped normals.
- **Read real frames, but choose probes that are robust.** Presenter tests read pixels back on the simulator; a probe
  is declared only where the expected colour class holds over a brightness range, and a background probe must miss
  every drawn object (A14-P03 tries up to eight positions).
- **Depth ranges must hold for every camera distance.** A backdrop drawn at 0.9 × far came nearer than the farthest
  planets once the camera zoomed out in the true-relative mode; a test now proves the star sphere lies beyond every
  body for every focus, zoom step and date (A14-P03, `StarDepthTests`).
- **A GPU mirror must reload after any edit, not only after a spec change.** Simulation Lab's mirror reasoned that the
  field depended only on the spec and the step count, so it stepped the GPU field whenever iterations ran. A paint
  (A16-P04) followed by a step in the same frame was then stepped from the unpainted field; only a test that paints
  and steps without a frame between found it (A16-P05, `BoundaryRuleTests`). Any action that changes state outside the
  step counts as an edit (`SimulationCore.paintCount`), and a test runs edit-then-step with no frame between.
- **Let the contract audit correct the clarification.** A17-P00's clarification assumed no lathe or sweep generator
  and one `LabelLayout` consumer. The code audit found `Mesh.revolution` and `tube` (tested), two consumers already,
  and a blend-free depth pass; converge then corrected the spec and research (T-A17-012). Grep the framework products
  before writing a gap, and treat the audit's file and symbol checks as the truth (A17-P00).
- **A claims scan may allow one named phrase, never a word.** Simulation Lab's label says "half-precision values";
  the scan removes that exact phrase before refusing "precision", so the word stays refused everywhere else (A16-P06,
  `specs/122-sl-p06-release/scan-claims-release.sh`). Interface journeys for A16 run in the serial chunk `x2`, and for A17 in `y2`.
- **Generate a report from the tests and check it is current.** `SimulationValidationTests` writes
  `docs/apps/simulation-lab/validation-report.md` under `UPDATE_VALIDATION_REPORT=1` and otherwise compares its
  deterministic lines with the committed file. Timing lines are excluded and labelled a simulator figure (A16-P05).
- **Round to half in the shader; test the mirror while it runs.** A one-shot fixture (10 steps on 16 × 16) passed
  against the toward-zero reference, yet the running 64 × 64 reaction-diffusion mirror drifted 0.03–0.07 from the
  nearest-rounded CPU truth within a few frames: the simulator truncates half-float colour writes, and a sensitive
  rule amplifies the difference. Rounding each value to the nearest half in GLSL before the write (`floatBitsToInt`
  exponent, `roundEven`) makes the store exact on any driver; the GPU then equals the float16 reference (0.0). Keep a
  test that compares the GPU field with the CPU field after every frame of a short run, not only a fixture (A16-P03,
  `FloatMirrorTests`).

### Determinism and digests

- **Generated documents are tests too.** `data-sources.md` and `scientific-review.md` are produced by core functions
  and compared with the committed files (`UPDATE_DATA_SOURCES=1`, `UPDATE_SCIENTIFIC_REVIEW=1` and their
  `TEST_RUNNER_` forms rewrite them), so a data change cannot leave the documents stale.
- **Quality levels change drawing only.** Two-level tests compare the state digest, the recorded body centres and the
  camera at each level, and switch levels mid-flight and mid-tour (A14-P05).
- **Pinned digests change with every state schema.** A scenario fixture's digest covers the state's JSON; adding a
  field re-pins every fixture. Pin from the first run's "derived" values, then rerun the manifest tests to prove them.
- **The scenario-manifest validator wants an outcome for the completion scenario,** so every experience defines one
  (for Solar System Explorer `viewing-<body id>`).
- **Keep presentation out of the state.** The eased camera flight of A14-P03 lives in the presenter only, so digests do
  not depend on frame timing or Reduce Motion; the clock of A14-P04 advances only on host steps, so suspension (no
  steps) never fast-forwards time.

### Numbers and units

- **Check arithmetic written into specifications.** Two spec values were wrong and caught only by tests: the range end
  18,627.5 days after J2000.0 is 2051-01-01 00:00 UTC, not 2050-12-31, and 60 × 1.25^−12 is 4.12, not 4.03.
- **Make seams exact.** A noise sampled at a unit direction still differs at the date line (sin 2π ≈ −2.4e-16); rounding
  directions to a 2^−30 grid made seam and pole vertices identical.
- **Count combinations before writing them down.** A spec said 72 sampled states for 9 × 2 × 3 × 2 × 2 (216); the
  test that counted them caught it (A14-P05). Let tests count enumerations instead of hard-coding a number first.
- **Decide angles with constant integer tables, test with floats away from the edges.** Hue Compass's sector of a
  direction comes from 96 boundary vectors rounded once and stored as constants, tested by cross products (R02-G04-01);
  a floating `atan2` reference agrees everywhere except within rounding of a boundary, so the comparison skips
  directions whose reference angle is within 10⁻⁶ rad of one, and the boundary vectors themselves are checked to fall
  in exactly one sector.
- **Conserve exactly by sharing whole units** (R02-G05-01, 2026-11-21). Colorfall Canyons moves fluid in whole units
  and shares an outflow between colours by largest remainder, so its flow tests assert zero drift per colour on every
  tick of 500 seeded levels and compare each tick with an independent brute-force step written in the test, instead
  of a tolerance.
- **Measure a solver on the debug build before fixing its depth** (R02-G05-02, 2026-11-21). Colorfall Canyons's
  edit-set search at depth 4 took about 30 s per band of 20 levels on the debug host build; an exact early stop of each
  simulated run once nothing can move cut it fourfold, and depth 3 (with bands 4 and 5 differing by springs and grid
  instead) brought every band to 3 … 15 s, so the catalog tests run in halves under 10 s each. The spec records the
  correction.
- **Fit encodings to the renderer's streams** (R02-G05-03, 2026-11-21). `ShaderMeshRenderer` binds only position,
  normal and uv, so Colorfall Canyons's fluid program reads its three colour weights from the normal slot and its
  brightness and flow code from uv; the geometry and shader agents agreed on the encoding before the scene was written,
  and a host test pins each code's range.
- **Compare picks with an independent ray test** (R02-G05-04, 2026-11-21). Colorfall Canyons's picker and gesture tests
  compute the expected cell or spring in the test with their own plane and box intersections (only the ray is shared)
  over seeded points, sizes and orbits, and each was shown to fail by changing one threshold; a panel test wins all 100
  certified levels through panel actions, in eight groups so each stays short.
- **Keep shared generation out of per-test time** (R02-G05-05, 2026-11-21). A progress test generated all 100 Colorfall
  Canyons levels only to read their smallest edit counts and took 8 s; the rules it checks do not depend on the levels,
  so it uses synthetic counts and takes a millisecond. Hint tests over 200 seeded states run in eight groups of 25, since
  each hint search can take up to about 0.5 s on the debug build.
- **Fade by time, not by rate, when targets vary** (R02-G05-06, 2026-11-21). Colorfall Canyons's sheet brightness
  targets lie anywhere in 0.35 … 1, so easing at a fixed rate per unit of range let short changes finish in under
  0.4 s; each fade now takes the full 0.45 s under Reduce Flashing, and the lights tests caught the rate-based rule by
  sabotage.
- **A guard that only bounds work needs its own test** (R02-G05-07, 2026-11-21). Colorfall Canyons's trace bound (30
  edits, 3,600 steps) never changes a verdict, because a longer trace cannot win within the budget and tick limit, so
  removing it fails no behaviour test; the bound's edges are tested directly.
- **Quantise before hashing floats** for digests that must match across platforms (surface colours are hashed as
  16-bit values).

### Swift and test-tool pitfalls

- **Validate a device definition in a scratch root first** (R02-G03-10, 2026-11-21). `check_device_rows.py --root`
  reads only the ledger, the game's scenario manifest, its device definition and the tasks of its nine earlier
  features, so a new definition was checked against a scratch copy of those while the regression chain ran on the real
  tree, then copied in and checked again (`device-rows-r02-g03`).
- **Pin constants from the witness, check them against the Core** (R02-G03-09, 2026-11-21). The agent writing Wave
  Knot Keeper's interface tests could not run code, so it read level 1's point count, allowance and solution from
  `docs/games/wave-knot-keeper/levels/001.witness.json`; an app unit test asserts the pinned values equal
  `WaveKnotKeeperExperienceCore.generated(number: 1)`, so a stale pin fails by name. The tests run as chunk `l3`
  (`release_check.py --only app-build-for-testing-ios27 app-ui-ios27-l3`).
- **Count a spec's list, do not trust its number** (R02-G03-08, 2026-11-21). The Wave Knot Keeper regression spec said
  "twelve kinds" of alteration but listed thirteen (a solution move's point and direction are two); the agent writing
  the test covered all thirteen and reported the mismatch, and the spec, plan, checklist and tasks were corrected before
  the gate. `python3 scripts/wave_knot_keeper_regression.py` runs the game's host and simulator regression in one go.
- **Edit saves so the expectation is independent** (R02-G03-07, 2026-11-21). Wave Knot Keeper's persistence tests
  edit a trace step by replacing it with a move the kernel itself refuses at that point (asserted in the test), so the
  expected drop is known without asking the reconciliation code under test; a random walk that happens to win a level
  opens the next one, so the tests do not cap the frontier.
- **Closed form checked against a step-by-step reference** (R02-G06-01, 2026-11-21). Chrono Constellator computes a
  star's cell at any tick from one formula (start phase plus tick minus held ticks, modulo the loop length), so its
  timeline tests compare every tick of 500 seeded levels with a reference written in the test that moves each star one
  step per tick unless a hold covers it. The baselines of a new game's first feature run with the new files set aside
  (moved to the scratchpad and the committed `Package.swift` restored), so they measure the tree before the feature.
- **Colorfall Canyons device rows** (R02-G05-10, 2026-11-21). `ColorfallCanyonsDeviceRowsCheckTests` runs the same
  generic check on `docs/apps/colorfall-canyons/device-rows.json` and on copies with a scenario removed, CC-D1's `pass`
  removed and T-R02G0509-011 uncovered; the release step is `device-rows-r02-g05` (specs 341–349 found from the game
  number). Two slips of this gate: a run-check command kept in a zsh variable ran nothing (zsh does not word-split), so
  confirm the `CHECK … exit=0` line before ticking; and `tick_task.py` commits the whole tree, so drafts of the next gate
  must be excluded or kept out of the repository while a gate records.
- **Hue Compass device rows** (R02-G04-10, 2026-11-21). `HueCompassDeviceRowsCheckTests` runs the generic device-row
  check on the real definition and on copies with a scenario removed, a row field removed and T-R02G0409-011 uncovered;
  the release step is `device-rows-r02-g04`. The check finds the earlier features from the game number alone
  (R02-G04 → specs 331–339), so a new game needs no change to it.
- **Interface tests: tap a stepper's buttons, not its centre** (R02-G05-09, 2026-11-21). The first two runs of the
  Colorfall Canyons interface tests failed with "not reached by scrolling the controls" on the cell and level pickers:
  a SwiftUI `Stepper` element can report itself not hittable while it is on screen, so the reveal loop dragged the
  controls 24 times without moving them. The helpers now skip scrolling when the stepper's Increment and Decrement
  buttons are already hittable, and the reveal loop stops once a drag no longer moves its target. The tests then took
  62, 76 and 47 s (chunk `n3`, key checked unique).
- **Interface tests: count the teardown, skip waits for present elements** (R02-G04-09, 2026-11-21). The Hue Compass
  interface tests first took 71, 93 and 97 s against the 90 s bound. The per-test time xcodebuild reports includes about
  24 s of app teardown after the last step, and every `waitFor` costs at least a second even for an element already on
  screen. Revealing the replay's Step button once and tapping the same element, and skipping the bounded wait when the
  element already exists, brought them to 64, 72 and 60 s. The chunk key `m3` was checked unique before use.
- **Colorfall Canyons regression** (R02-G05-08, 2026-11-21). `python3 scripts/colorfall_canyons_regression.py` runs the
  host filter `ColorfallCanyonsRegression` (solver regression over 100 witnesses in tests of 10, twelve named
  alterations, golden descriptions) and then the simulator golden-frame and memory classes with
  `TEST_RUNNER_COLORFALL_CANYONS_MEMORY_ISOLATED=1`; CI runs the host part as a named step. Golden frames show the
  certified edits and 12 ticks so fluid sheets are part of every level baseline.
- **Hue Compass regression** (R02-G04-08, 2026-11-21). `python3 scripts/hue_compass_regression.py` runs the host
  filter `HueCompassRegression` (solver regression over 100 witnesses, golden descriptions) and then the simulator
  golden-frame and memory classes with `TEST_RUNNER_HUE_COMPASS_MEMORY_ISOLATED=1`; CI runs the host part as a named
  step. Golden frames show the witness probes (not a fresh play) so the probe marks are part of every level baseline.
- **A trace of net actions needs no undo** (R02-G04-07, 2026-11-21). Hue Compass can undo only turns, so a winning
  trace is the play's records with each undone turn removed and each redone one put back (`netActions`); the
  persistence tests edit saves only in ways whose outcome is known without the code under test (a selection band
  shifted by 12, which misses because band tolerances are at most 2; a step replaced by `turn(0)`, which the kernel
  always refuses).
- **A still at a repeated time settles its lights** (R02-G04-06, 2026-11-21). Hue Compass's render and tier tests draw
  every still at time 0; the eased lights first stepped by the 0 s between two such stills, so marks added by a probe
  stayed at size 0 and the mark checks missed them. A frame time that does not advance now counts as a separate picture
  and settles the lights; live frames always advance, so fades are unchanged. The simulator accessibility tests also
  run the presenter at 1/60 s steps under Reduce Flashing and measure the drawn levels.
- **Agents work in an isolated package copy during a long chain** (R02-G03-06, 2026-11-21). While the lead's
  Stage One and reference chain ran on the real tree, the agents built and tested their new files in a scratchpad copy
  of `Packages/ExperiencesRound02` (its sibling packages, `External` and the game's witness files linked in), so no
  half-written file could reach the chain's builds. The lead then copied the files in and reran every test before
  ticking. A scripted test that needs a particular kind of move (here, one that changes the crossing marks without
  winning) searches the certified levels for one rather than assuming the opening level has it.
- **Keep shared files compiling while agents test** (R02-G03-05, 2026-11-21). While agents ran `swift test` with their
  own scratch paths, the lead's in-progress adapter edit broke the package's compile for them for a few minutes. Each
  agent's build covers the whole package, so the lead saves shared files only in compiling states while agents run, and
  an agent that meets another file's error waits and retries; the hint tests also share one search across the three
  hint levels so 2,000 states stay at a few seconds per case.
- **Build a hot search on a dense table** (R02-G02-05, 2026-11-21). The Lissajous hint tests run thousands of
  breadth-first searches; calling the rules' `moves` and `apply` per edge took up to 1.15 s per search in a debug build.
  A successor table over dense state indices, itself checked once against the rules for every state, brought each
  search under 1 ms with the same order and results.

- **Mutating calls inside `#expect`** do not compile ("cannot use mutating member on immutable value"); assign to a
  `let` first.
- **`pow(2.0, -24)` can be ambiguous** in a test target that imports several math modules; write the constant.
- **A test target needs every module whose types it names** (for example `VisualCoreRendering` for `RenderContext`).
- **zsh does not word-split `$VAR`**: `--exclude $X` passes one argument; write paths literally.
- **`check_documented_api.py` needs `--sources <dir>`**; a run without it fails with exit 2 (kept as a failed check).
- **Python `str.replace` fails silently.** When editing documents with scripts, assert the anchor exists first; an
  unmatched replacement once left a stale file header.
- **"App animations complete notification not received" after a menu tap** means the app never settles. The shell
  adds a port revision on every frame in which a simulation step ran, so the host rebuilds the controls every frame;
  a controls view that stores closures never compares equal, SwiftUI rebuilds its Menu and Picker each frame, the
  menu closes again, picker taps are lost and canvas-overlay labels may not show. Controls store references only (port,
  mirror, presenter), as Light Maze's do; `SolarControlsIdentityTests` guards this for A14 (A14-P06). To find such a
  loop, add `let _ = Self._printChanges()` to the view bodies temporarily and read the app's console
  (`xcrun simctl launch --console-pty`).
- **A system menu over a live canvas stalls XCTest** (A23-P05): with a SwiftUI Menu or Picker open over a canvas
  presenting 30 frames a second, XCTest never saw the app idle ("App animations complete notification not received")
  and each tap waited 60 s. Inline expanding button lists (`add-node-<kind>`, `example-<id>`,
  `input-<id>-<index>-option-<tag>`) replaced them, and the tests passed in 29 to 45 s.
- **Contract evidence names library products, not modules.** `check_app_contract.py` accepts only products declared
  in a `Package.swift` (`MolecularExplorerExperience`), so citing an experience's core file with its module name
  (`MolecularExplorerCore`) fails with "unknown product" (A15-P01).
- **The runner plays the nine standard scenarios only.** `verify_experiences.py` reports nine PASS lines per runtime;
  the fixtures of a scenario manifest are proven by the experience's manifest tests. Evidence counts what the log
  shows (A15-P01).
- **Suspension drops touch cancellation.** The shell drops pointer events while an experience is suspended, so the
  system's cancellation of a held touch never arrived and gesture state outlived the suspension (a later one-finger
  drag read as two fingers). `ExperienceShell.suspend()` now calls `ExperiencePresenter.cancelPointers()`; test
  gestures through a real session suspend, not only by calling `reset()` (A15-P03).
- **Test small documents over a real temporary folder.** Store tests give `ExperienceStorage` a fresh temporary
  folder, write a refused fixture byte for byte, open a session and compare the bytes afterwards; a failed write is a
  read-only folder (0o555), and the app's data reset is removing the folder. Two sessions over the same folder prove
  survival without relaunching anything (A15-P04).
- **A user file enters the engine as actions.** An imported document is parsed outside the engine and sent as ordinary
  actions (`import.begin`, `import.atom` × n, `import.end`), so replays, snapshots and digests cover it; tests feed the
  importer temporary file URLs and never present the document picker. A schema bump changes every digest: regenerate
  the manifest and re-pin the Swift-pinned fixture digests from the "derived" lines (A15-P05).
- **Fuzz with a seeded corpus, not time.** 2,000 mutated files (seeds 1…2,000, SplitMix64) run in about 0.1 s through
  the same rule the engine uses; a 200-file slice goes through the engine itself (A15-P05).
- **Scan source literals for domain words.** Inline accessibility labels are not reachable as statics; a test reads the
  experience's Swift sources from `#filePath` and checks every string literal (A15-P05).
- **Prove "a setting changes nothing" with two sessions.** A checklist row saying Reduce Motion changes nothing needs a
  test: two sessions with the setting on and off play the same actions and compare digests, drawn counts and pixels
  (A15-P06, found by convergence).
- **Interface tests never open the document picker.** The import is proved by package tests with file URLs; the `w2`
  chunk drives the library, display mode, atom, recent list and labels only (A15-P06).
- **CI cache keys are computed before the build.** The cache action's post step re-evaluates `hashFiles`; over
  `Packages/**` after a build it exceeded 120 s on a slow runner, so the key now comes from an earlier step (A15-P06).
- **Create the contract view before rendering it.** `check_app_contract.py --render` fills the block between
  `<!-- BEGIN GENERATED -->` and `<!-- END GENERATED -->` of an existing `visualcore-contract.md` and fails without
  them; write the introduction and the two markers first, and link the view from the README only after it exists
  (the docs check refuses broken links) (A16-P00).
- **The planning catalog sets the fixture count.** The content-counts audit in `test_scripts.py` compares a new
  experience's manifest fixtures with the catalog's content requirement (five for a creative experience); write that
  many fixtures in Phase 01, or the script tests fail after the package tests pass (A16-P01).
- **Compare a GPU field with both half-float roundings.** GLES leaves float-to-half rounding implementation-defined;
  on the iOS 27.2 simulator the Gray-Scott fixture matched the `float16TowardZero` CPU reference exactly (0.0) and the
  round-to-nearest one within 0.0032, so a tolerance test compares against both and never assumes one (A16-P02).
- **Keep the CPU as truth and mirror it on the GPU.** Snapshots and digests stay on the CPU model; the GPU field is
  loaded from it on any non-step change and stepped by the engine's iteration delta, and parity tests read it back
  (A16-P02).
- **No mutating call inside `#expect`.** `#expect(model.paint(x: 1, y: 1, mode: .tap))` does not compile: the macro
  passes the receiver as an immutable `$0`. Assign the result first (`let painted = model.paint(…)`, then
  `#expect(painted)`), as with `await` in `XCTAssertEqual` (A16-P04, `SimulationBrushTests`).

- **Run the writing pass of a file-pinning test on its own.** Hue Compass's catalog tests read the 100 witness files
  in some tests and write them in others (with `HUE_COMPASS_WRITE_WITNESSES=1`); Swift Testing runs them in parallel, so
  the readers fail on the first writing run (R02-G04-02). Write once, then run the suite again without the flag; only
  the second run is evidence.
- **Measure a generator's band profile before writing it.** A 20-level Python prototype per setting showed that one
  probe settles almost every Hue Compass level unless the tolerances are (1, 0) on fog with 30 … 40 % clear bearings,
  and that more clear fog makes levels undeducible within two probes; the band profiles were set from those counts and
  all 100 levels then generated on the first try (R02-G04-02).

- **Registering a candidate extends a pinned list.** `RealCatalogTests.categoriesAndFamilyTags` pins every
  experience that has a registration in `Catalog/registrations.json`; Hue Compass's candidate registration failed the
  catalog-search check until the list named `r02-g04.hue-compass` (R02-G04-03). Extend it in the same change as the
  registration.
- **A renderer without a colour stream.** `ShaderMeshRenderer` binds position, normal and texture coordinates only;
  Hue Compass's unlit meshes carry their colour in the normal slot and the fallback `MeshRenderer` gets explicit
  colours and (0, 0, 1) normals, so its light term stays finite (R02-G04-03).

- **atan2 and negative zero.** `atan2(-dy, dx)` with dy = 0 passes −0.0 and returns −π for a point straight left of
  the centre, so the same touch could read +π or −π; Hue Compass's dial computes `atan2(0 - dy, dx)` and keeps its
  angles in (−π, π] (R02-G04-04).

- **Test a hint by following it.** Hue Compass's hints reason only from the clues the player has seen; the strongest
  test plays every certified level by following the exact hint from the start and expects a win within the allowance,
  and 2,000 seeded mid-play states check that the consistent set always holds the true target (R02-G04-05).

### Process

- **A new enum case reaches files the agent does not own** (R02-G02-07, 2026-11-21). Adding
  `LissajousLabyrinthMode.replay` broke exhaustive switches in the adapter and the feedback plan, so the agent's
  filtered build could not compile. The lead names in advance the minimal switch edits the agent may make outside its
  files (and keeps the iOS-only ones), so the agent can verify its own work without touching shared logic.

- **A round-two game needs frame probes before its X gate** (X-R02-G01, 2026-11-21). The runner's launch-first-frame
  scenario records `frame: no probe declared` when `probes(_:)` is empty (and, until 36c8906c, the evidence validator
  rejected every record of a round-two id such as `r02-g01.aurora-loom`). Declare probes on background points outside the fitted 5 % margin (real scene only, not the fallback)
  and pin them with a render test that samples the drawn frame bottom-up, as `RenderHost.readPixels` gives it.

- **An agent's report is not evidence.** Agents write files; the lead builds, runs and ticks. Several agent-written
  files compiled first time, but others needed fixes (imports, ambiguous calls, a spec-violating depth range found by
  the agent's own doubt list) — always read an agent's doubts.
- **Commit boundaries follow tasks.** When one task's files must ship with another (controls that read a presenter's
  mirror), the evidence says so.
- **Pushes cancel queued CI runs.** Batch pushes; check `gh run list` between gates and fix a failure before the next.
- **Run the documented-API check every phase.** `check_documented_api.py --sources <experience>` caught
  `RecordingAnnouncementSink` one phase after an agent first used it in a test helper (A14-P03 → A14-P04); every
  phase that touches an experience runs it.
- **Drive time with steps and injected clocks.** The simulated clock advances only on host steps, "Now" enters as an
  action computed from an injected clock, and the announcement limiter takes an injected clock, so tests of playback,
  rate limits and suspension assert exact values without waiting (A14-P04).
- **Validate before committing a steering document.** `validate_autocreator.py` also limits CLAUDE.md to 12,000 bytes;
  a CLAUDE.md edit was once committed before its failure was read, and the next commit fixed it.
- **A core can come before its experience.** `check_experience_packages.py` refused a feature's first phase,
  whose clarification adds only `<Name>Core` and `<Name>CoreTests`, as `EXTRA_TARGET`. Since A17-P01 it allows exactly
  that pair for an unregistered launch-scope catalog experience of the same package, as long as no `<Name>Experience`
  or `<Name>ExperienceTests` target exists. Run the package check before ticking the first core task, not at the end
  of the phase.
- **Test picking with probe rays, not one ray through the centre.** A thin part (cartilage, a meniscus, a cruciate
  ligament) can be covered from every single direction by its neighbours, so "a ray through its centre picks it" may
  be false for correct geometry. A17-P02's picker tests aim 26 rays (axes and diagonals) at each part's centre. At
  least one must pick it with all layers shown, and none may pick it while its layer is hidden. Experience tap tests
  compare the selection with what the picker returns for the same ray.
- **A snapshot envelope refuses a non-JSON payload by itself.** `ExperienceSnapshot(...)` throws for a payload that is
  not one JSON object, so a restore test for damaged payloads builds the envelope with `try?`. It tests the core's
  own `restore(payload:seed:)` for every case.
- **The host refuses an edited snapshot as a whole.** A session restore checks that the restored state's digest equals
  the one the snapshot recorded. A test that edits a snapshot payload, for example to an unknown id, therefore sees the
  snapshot refused and the opening state, not a partial restore. Test the dropping of unknown ids on the core's own
  `restore(payload:seed:)` and on experience files that carry no digest (A17-P03, the view file).
- **Remove test storages with an observer.** XCTest has no public "current test" for teardown blocks from a static
  helper. A17-P03's `AnatomyTemporaryRoot` keeps every default storage under one folder, which an
  `XCTestObservation` removes in `testBundleDidFinish`. It clears the folder first, in case an earlier run was
  interrupted.
- **The documented-API check reads READMEs and feature contracts.** `check_documented_api.py` fails when a consumer
  uses a public VisualCore name, even an enum such as `AnnouncementKind`, that no package README and no
  `specs/*/contracts/*.md` names. Name every VisualCore type the experience uses in the feature's contract.
- **Never tick in the command that runs the checks.** In A17-P04 a loop ran three checks and the tick in the same
  command cited all three as passing, though one had exited 1. The evidence line had to be corrected in a new commit.
  Run the checks, read each `exit=`, then tick in a separate step.
- **The verification runner runs one at a time.** Each `verify_experiences.py` run regenerates the project with
  xcodegen before it builds, so an iOS 26 run started beside an iOS 27 run failed with "the app did not build" (X-A18).
  Run the two runtimes one after the other; the package and app test runs on separate simulators may still overlap
  with nothing that regenerates the project.
- **A snapshot schema above 1 needs a stored example before integration.** `AppModelTests`
  `testEveryRegistrationHasAnExampleOfEveryEarlierSchemaVersion` checks only integrated registrations, so a candidate
  whose snapshot schema rose (A17's view state reached schema 2 in A17-P03) passes every phase gate. It then fails at
  its X gate's follow-through. When a phase raises the snapshot schema, add `schemaExample(version:)` for each earlier
  version (Molecular Explorer's pattern) and register it with `examples:` in that same phase.
- **Swift Testing's per-test time includes queueing.** Suites run in parallel, and tests on the main actor wait for
  each other, so a model test can report 18 s while its own work takes milliseconds (A18-P05: the heaviest frame test,
  120 frames, takes 4.5 s). Judge the 10-second bound by the frame tests' own times; keep frame loops short.

## 6. Keeping this file current

Update this file whenever a gate adds or changes a test tool, a test rule, the per-gate sequence, or teaches a lesson
worth keeping; change the "Last updated" line and keep entries short and factual. Do not record progress here — the
ledgers carry it.
