# Automated testing in VisualCore

How VisualCore's code is tested automatically, how a test run becomes evidence for a gate, and what was learned while
building the experiences. This file is kept current: every gate that changes a test tool, a test rule or teaches a
new lesson updates it (CLAUDE.md, section 4). Older simulator-specific lessons from the first app campaign are in
[testing/simulator-test-lessons.md](testing/simulator-test-lessons.md); they still apply.

Last updated: 2026-11-23 (R02-G13-01: Acoustic Constellator playable rule kernel).

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
- **Relay a stream contract while the agents still run** (R02-G06-03, 2026-11-21). Chrono Constellator's shader agent
  chose uv = (age in ticks, glow) so the glow program computes the ribbon fade itself, where the data model said
  (alpha, glow); the lead forwarded the contract to the geometry agent before it finished and corrected the data model,
  so the two halves met without a rework round.
- **No `try` inside `&&`** (R02-G06-04, 2026-11-21). An agent's simulator test wrote
  `while a && (try f()) > 0`; `&&` takes an autoclosure, so the iOS build failed with "operator can throw but expression
  is not marked with 'try'" (the host build never compiles `#if os(iOS)` tests). Evaluate the throwing call into a local
  first; compile agents' simulator files once before the test run.
- **Gate a hint on what it leads to** (R02-G06-05, 2026-11-21). Chrono Constellator's clarified hint said "rewind" after
  tick 0 and "remove the first hold" at tick 0 unconditionally; the agent's 200 seeded states found 8 where that led to
  a state with no win, so following hints got stuck. A rewind or release is now offered only when the state after it
  has a plan, keeping "a plan exists exactly when following hints wins"; the spec records the change.
- **A fading mark needs its place remembered** (R02-G06-06, 2026-11-21). Chrono Constellator's collision cross is drawn
  at the failure's cell, but a rewind clears the failure, so a Reduce Flashing fade-out had nowhere to draw. The lights
  now keep the last collision cell until the mark is dark, and a geometry test checks the cross fading at that cell.
- **A new enum case breaks every exhaustive switch** (R02-G06-07, 2026-11-22). Adding `replay(level:)` to Chrono
  Constellator's mode broke `modeName` in the Core (caught by the agent's host build) and the presenter's `retryAction`
  and the panel's `modeName` (iOS-only, caught only by the lead's simulator build) — and the identity test's list of
  controls. Build the iOS target before the simulator run whenever a shared enum grows.
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
- **The ProjectM baseline compares against its own noise floor** (R02-G06-02, 2026-11-21). `projectm-reference-ios26`
  failed once by 0.0001 (square preset within8 0.9695 against a required floor − 0.01 = 0.9696) in a gate that touched
  only game logic; the rerun passed at 0.9752 against 0.9675. The threshold is measured from three engine runs in the same
  process, so a near-miss on the simulator is run-to-run variance: rerun the chunk under a new check name
  (`reference-2-2`), keep the failed attempt in the evidence, and investigate only a repeated or larger miss. A second,
  larger miss came at R02-G12-04 (`projectm-reference-ios27`, within8 0.9685 against a floor of 0.979) while an
  outside device test run was using xcodebuild; the rerun passed. Check `pgrep -fl xcodebuild` before the reference
  chunks and rerun once; two misses in a row would be investigated.
- **Certify by a lower bound, not by enumeration** (R02-G06-02, 2026-11-21). Chrono Constellator's timelines (phases
  and holds) are too many to enumerate, so the solver proves its count with an argument (each edit moves one star) and a
  collision-free witness; the tests check it with an independent brute force kept small enough for 10 s (phase-only
  timelines everywhere, one added hold on small levels). Witness files are generated in a separate write run: the
  byte-compare and decode tests run in parallel, so a first run with the write flag fails until the files exist.
- **Agents stacked on one merged copy** (R02-G07-07, 2026-11-22). Amethyst Escape's persistence was written by four
  agents in sequence on one scratchpad package: traces and reconciliation, then the adapter (schema 3, replay) on top,
  then the persistence tests and the presenter against the finished adapter. The repository stayed free for the
  previous gate's evidence chain; the lead copied each task's files in and ran its named check in the repository. The
  panel and replay simulator tests passed on their first compile.
- **A fade meets a still frame** (R02-G07-06, 2026-11-22). Once the failed wedge's amber eased in over 0.15 s, an
  earlier simulator test that took its still frame at time 0 right after the failure found no amber: no time had
  passed. The test now renders a still at 0 s and checks one at 1 s. Any check of a drawn state change must give the
  presentation time to reach it.
- **A count bound that shrinks with progress** (R02-G07-05, 2026-11-22). A script test required more than 700 open
  gates to check; recording R02-G07-04 left exactly 700, so every later run failed. The script-tests check exited 1 and
  was ticked and recorded without its exit code being read; the bound now only guards against an empty loop, the check
  was re-run with `--reverify` (exit 0) and the task's evidence note says what happened. Read `exit=` on every `CHECK`
  line before ticking, and never tie a test to a number that progress changes.
- **Hints proved by a second search** (R02-G07-05, 2026-11-22). Amethyst Escape's hint is the first action of the
  solver's shortest escape from the current crystal. Its tests compare the shortest escape length on 200 seeded states
  with an independent breadth-first search written in the test on whole crystal values (no packed states), so a state
  that gets the "no escape" hint is proved to have none in the moves left, and following hints is replayed to a win on
  every state that has one. The agent also removed an array allocation from the solver's inner loop (same order, same
  digest), which made debug hints about three times faster.
- **A quoted command in a zsh loop is one word** (R02-G07-04, 2026-11-22). A post-record loop `for c in
  "planning_index.py build" …; do python3 scripts/$c; done` ran `python3 "scripts/planning_index.py build"`, a missing
  file, and printed exit 2 for the index build and the catalog check; the other steps passed, so the failure looked
  like a flaky check. Write each pipeline command out (or use `${=c}`), and read every exit code before pushing.
- **Two games, one tilt direction** (R02-G07-04, 2026-11-22). Amethyst Escape's gesture agent followed its brief
  (`pitch += dy`), the opposite of Chrono Constellator's orbit; the lead chose Chrono's direction so a two-finger drag
  tilts every round-two crystal and sky the same way, and the orbit test's expected values moved with it.
- **A score that counts undone work needs an inequality** (R02-G08-07, 2026-11-22). Faceted Forge's cuts made count
  undone cuts, but a replayable trace holds only the effective cuts, so reconciliation checks that the trace is no
  longer than the cuts made (and the stars match the cuts made) instead of equality; equality would drop every honest
  win with an undo. Old tests that compared whole results failed once results carried traces; compare the new fields
  explicitly. Spec edits were committed with `git commit -a` while the previous gate's code was uncommitted, which
  swept that code into a spec commit: add explicit paths while another gate's work is open.
- **Measure a light over its whole range** (R02-G08-06, 2026-11-22). Faceted Forge's glow plays at 0.7, wins at 1 and
  fails at 0.35; normalised to 0.35 … 1, the playing level sits just above the midpoint, so a sliver failure undone
  every frame crossed the midpoint in close pairs and the flicker measure counted 4 crossings a second although every
  fade lasted 0.45 s. The glow is a gain from 0, so its test samples it over 0 … 1, where crossings are at least
  0.386 s apart.
- **A bounded search is a hint budget** (R02-G08-05, 2026-11-22). Faceted Forge's hints rerun the certifying search
  from the current pieces; at a level's opening that can cost the whole 20,000-evaluation bound (about 2 s in a debug
  build, more when tests share cores), so the follow-the-hints test runs in 20 groups of 5 levels and the presenter
  computes a hint only when asked. Where a state has no plan, the test confirms it independently only when one or two
  cuts are missing (an exhaustive search of its own); larger gaps rely on the bound, and the text says "was found".
- **A redo is not a new step** (R02-G08-05, 2026-11-22). The adapter first advanced the tutorial on a redo, so cut,
  undo, redo moved it on without a second real cut; the progress agent's tests caught the mismatch with the step's
  rule, and only a new accepted cut advances it now.
- **Round with a snap on rational points** (R02-G08-04, 2026-11-22). Faceted Forge's rim tilt rounds n·c for the
  preview centre c, a rational point; in 112 of 500 seeded tilts the product was exactly x.5, so the Double rounding
  flipped with the last bit. The picker snaps to 1e-6 before rounding half away from zero, and the test counts halves.
- **An edge-on default hides a gesture** (R02-G08-04, 2026-11-22). The gesture agent found that the default preview
  plane (direction x) is seen edge-on from the authored camera, so a tap could only ever hit its rim; the seeded test
  produced 8 cuts in 500 scripts. The default became direction z, facing the camera.
- **Certify the known candidate, not the whole search** (R02-G08-03, 2026-11-22). Faceted Forge's scenario manifest
  opens 83 levels; generating them reran every rejected candidate's solver search (up to 20,000 cut evaluations each)
  and took about 12 s per test. The adapter now keeps each level's certified candidate index (the witness files'
  `skipped`) and certifies only that candidate, with the generator as fallback; a catalog test in 10 parallel groups
  pins the table against the witnesses. The manifest tests dropped to about 7 s.
- **A kernel scan meets presentation code** (R02-G08-03, 2026-11-22). Faceted Forge's invariant test forbids `Double`
  in every Core source; the renderer's snapshot, geometry, shaders, adapter and scenarios live in the Core too, so the
  first baseline run (with the uncommitted snapshot present) failed. The scan now lists the presentation sources it
  skips, and baselines run on the committed tree.
- **Agents in isolated copies, one merged retest** (R02-G07-03, 2026-11-22). Amethyst Escape's shader, geometry and
  adapter agents each worked in their own scratchpad package (only the Core and its tests, separate scratch paths), so
  the repository stayed free for the previous gate's evidence chain; the lead merged the three into one copy and ran all
  Amethyst tests together (120 tests) before copying the files in and running each named check in the repository. The
  scene's depth testing is off, so the geometry emits wedges back to front, and a test checks that order.
- **Search on packed integers** (R02-G07-02, 2026-11-22). Amethyst Escape's breadth-first solver first built a crystal
  value for every state it visited; in a debug build the catalog's witness check took 18.5 s over its five bands. The
  search now works on the packed integer state with the shell lists as bit masks (same rules, same digest and byte-equal
  witnesses), and the check takes 6.9 s. Measure a content test in the debug build before adding catalog cases.
- **Kernel files built in an isolated copy while an X gate runs** (R02-G07-01, 2026-11-22). Amethyst Escape's kernel
  and its four agent test files were written and tested in a scratchpad package that holds only the new Core, so the
  repository stayed unchanged under X-R02-G06's runs; the files were copied in after the record and retested by name.
  The crystal tests compare every move with an independent pocket-graph reference rebuilt from the offsets.
- **Closed form checked against a step-by-step reference** (R02-G06-01, 2026-11-21). Chrono Constellator computes a
  star's cell at any tick from one formula (start phase plus tick minus held ticks, modulo the loop length), so its
  timeline tests compare every tick of 500 seeded levels with a reference written in the test that moves each star one
  step per tick unless a hold covers it. The baselines of a new game's first feature run with the new files set aside
  (moved to the scratchpad and the committed `Package.swift` restored), so they measure the tree before the feature.
- **Chrono Constellator device rows** (R02-G06-10, 2026-11-22). `ChronoConstellatorDeviceRowsCheckTests` runs the same
  generic check on `docs/apps/chrono-constellator/device-rows.json` and on copies with a scenario removed, CR-D1's
  `pass` removed and T-R02G0609-011 uncovered; the release step is `device-rows-r02-g06` (specs 351–359 found from the
  game number).
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
- **Chrono Constellator in the app** (R02-G06-09, 2026-11-22). Serial chunk `o3` holds `CRPlayUITests` and
  `CRReplayUITests` (54.7, 73.4 and 44.1 s on the iOS 27.2 phone); the key was checked unique before use. The level-1
  journey needs one Phase + press and Run, and its pinned values are checked against the Core by an app unit test.
- **Whole-catalog tests that do not re-solve** (R02-G08-02, 2026-11-22). Faceted Forge's witness decode re-runs the
  solver (about 0.5 s a level on a debug build), so the catalog tests read the stored files with the plain decoder
  (the level re-checked, the proof not re-run), fully re-verify one level per band, and compare the regenerated
  witnesses byte for byte in 20 groups of 5 levels (about 15 s in all, run in parallel).
- **Exact geometry checked against an independent reference** (R02-G08-01, 2026-11-22). Faceted Forge's piece tests
  rebuild every piece's corners by brute force over all plane triples and its volume by an origin-based fan, a
  different decomposition from the kernel's apex fan, after every cut of 500 fixtures; the kernel was again written in
  an isolated copy while an X gate ran and copied in after its record.
- **Amethyst Escape device rows** (R02-G07-10, 2026-11-22). `python3 scripts/check_device_rows.py --experience
  r02-g07.amethyst-escape` (release step `device-rows-r02-g07`) checks the definition against the scenario manifest,
  the ledger's DEV rows and the open {device} tasks of features 361 … 369; `AmethystEscapeDeviceRowsCheckTests` in
  `test_scripts.py` proves it fails by name on a removed scenario, a missing field and an uncovered task.
- **Amethyst Escape in the app** (R02-G07-09, 2026-11-22). Serial chunk `p3` holds `AEPlayUITests` and
  `AEReplayUITests` (54.9, 75.2 and 58.3 s on the iOS 27.2 phone); the key was checked unique before use. New UI test
  files reach the test target only after `xcodegen generate`: the first run without it built and ran 0 tests, which the
  enumeration guard caught (0/3 declared tests). The level-1 journey is one Turn − and two Advances, and its pinned
  values are checked against the Core by an app unit test.
- **New presentation sources join the kernel scan's skip list** (R02-G10-04, 2026-11-23). A round-two game's invariant
  test scans every Core file not in its `presentationSources` set for kernel purity (no Double, only kernel imports).
  Backwards Aurora's picker and gesture controller use Doubles and pointer events, so both parallel agents found INV-01
  and INV-10 failing in their copies; the shared test file is the lead's, so the lead added the picker, the freeze
  preview and the controller to the set in one edit before retesting. Name every new presentation file in the task that
  creates it.
- **A new Core enum case can break only the iOS build** (R02-G11-07, 2026-11-23). Adding `replay(level:)` to Echo
  Cartographer's mode passed every host test, but the experience target's panel switches over the mode for its button
  values, and the host run never compiles the iOS-only experience targets. Land the experience's switch in the same task
  or run the simulator suite before ticking the Core task, so a host-green commit cannot leave the app unbuildable.
- **Eased lights need moving frame times in stills** (R02-G11-06, 2026-11-23). Once Echo Cartographer's won brightening
  eased in over presentation time, an earlier render test that took two stills at the default time 0 saw no change:
  the lights step by the frame time, so the fade never advanced. Take the "after" still at a later time (10 s, past every
  ring, flare and fade), and compare refusal messages with the feedback plan's words (`refusalText(code:)`) rather than
  the raw code once the panel speaks refusals in words.
- **Agents can start before the gate's baselines** (R02-G11-05, 2026-11-23). Echo Cartographer's hint and progress
  agents worked in isolated package copies while the previous gate's evidence chain ran, and the lead built the adapter
  in a third copy that combined their files; the baselines were then taken on the untouched tree, and each result was
  copied in and retested one task at a time. Name the copies per gate and agent (`iso405B`, `iso405C`, `iso405L`) so
  no two writers share one.
- **A cancelled CI run can be a job limit, not a push** (R02-G11-04, 2026-11-23). Five `ci` runs in a row ended
  "cancelled" with no later push: `host-tests` reached its 30-minute limit while the round-two package's tests were
  still running (build about 6 minutes, tests past 17 minutes on a runner; Swift Testing's output arrives in late chunks,
  so the step looked silent for minutes). The round-two host tests and their regressions moved to their own job,
  `round02-host-tests`, with 60 minutes. When a run is cancelled, read `gh run view <id> --json jobs` for the job that
  hit its limit before assuming a push cancelled it.
- **Overloads on enums that share case names can recurse** (R02-G11-04, 2026-11-23). Echo Cartographer's gesture
  action and kernel action both have `.claim(x, y)`; a test helper `adapterAction(_:)` overloaded on both resolved
  `adapterAction(.claim(x, y))` to the gesture overload, which called itself, and the run crashed with a stack overflow
  (signal 10) instead of failing. Name the enum explicitly (`EchoCartographerAction.claim(x, y)`) whenever two enums in
  scope share case names. The same feature's wiring test expected a marker press to start as a marker drag; the
  controller starts every press as a cell press and decides the drag after 16 points, so the agent's assumption was
  checked on the first simulator run and the expectation moved to after the movement.
- **CI's Xcode 26.6 type-checks some panel expressions much more slowly** (R02-G10-09, 2026-11-23). The R02-G10-07
  record's CI app build failed on `NocturneGardenControls.swift` (the Plant button's seven-part `+` concatenation and
  its four-element `Double(…)` array inside the view builder: "unable to type-check this expression in reasonable
  time"), although the local Xcode 27 build reports nothing above 60 ms with `-warn-long-expression-type-checking`.
  Keep string joins and action arrays of a panel in small `static func` helpers, never inline in a SwiftUI body.
- **Backwards Aurora interface journeys** (R02-G10-09, 2026-11-23). `BAPlayUITests` and `BAReplayUITests` run as the
  serial chunk `s3` (`python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-s3`, about 260 s
  with the build); they play level 1's certified reversals (samples 3 to 4, then 8 to 11) with the start and end
  steppers. The pinned literals in `BA` are checked against the Core by `testBackwardsAuroraLevelOneEqualsTheCore` in
  the app unit tests, and the chunk key was checked unused in `scripts/release_check.py` before it was named.
- **Backwards Aurora regression net** (R02-G10-08, 2026-11-23). `python3 scripts/backwards_aurora_regression.py` runs
  the solver regression and golden digests on the host, then the golden-frame and memory classes on sim-27.2 with
  `TEST_RUNNER_BACKWARDS_AURORA_MEMORY_ISOLATED=1`; regenerate the pinned frames only on purpose with
  `BACKWARDS_AURORA_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 --filter
  BackwardsAuroraRegressionGoldenTests`. Agents that write files while an evidence chain runs write them to a scratch
  folder for the lead to copy in, so the chain tests the tree it started with.
- **Script test classes go above the `__main__` block** (R02-G11-09, 2026-11-23). `scripts/test_scripts.py` ends
  with `if __name__ == "__main__":`; a class appended after it (feature 408's `EchoCartographerRegressionTests`) is
  found by `python3 -m unittest` but never run by `python3 scripts/test_scripts.py`, the `script-tests` check (669
  instead of 674 tests). Insert new classes before that block and compare the "Ran N tests" count with the last run.
- **A new UI test folder needs `xcodegen generate` first** (R02-G11-09, 2026-11-23). `VisualCore.xcodeproj` is
  generated and not tracked; `release_check.py` regenerates it only when it is missing, so after adding
  `Apps/VisualCore/Tests/UI/EchoCartographer/` the first `app-ui-ios27-t3` run built the old project and executed 0
  tests ("NOT RUN or not passed", the enumeration guard failed). Run `xcodegen generate --spec project.yml` after adding
  or removing app source or test files, then the check.
- **Harmonic Bridges interface journeys** (R02-G12-09, 2026-11-23). `HBPlayUITests` and `HBReplayUITests` run as
  the serial chunk `u3` (`python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-u3`); they
  play level 1's certified actions (string 0 from peg 11 to peg 12, Tune, Test) with the peg stepper, counting a press
  only when the value moves. The pinned literals in `HB` are checked against the Core by
  `testHarmonicBridgesLevelOnePinsInHBEqualTheCore`. The release-check summary log does not list the app's unit test
  names: read the per-step log under `.autonomy/logs/app-tests/` for "Test Case … passed".
- **Echo Cartographer interface journeys** (R02-G11-09, 2026-11-23). `ECGPlayUITests` and `ECGReplayUITests` run as
  the serial chunk `t3` (`python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-t3`); they
  play level 1's certified actions (pulses from column 0, row 3 and column 0, row 2, then a claim at column 1, row 2)
  with the column and row steppers. The pinned literals in `ECG` are checked against the Core by
  `testEchoCartographerLevelOnePinsInECGEqualTheCore` in the app unit tests; `EC` was taken (Effects Composer), and the
  chunk key was checked unused in `scripts/release_check.py` before it was named.
- **Harmonic Bridges regression net** (R02-G12-08, 2026-11-23). `python3 scripts/harmonic_bridges_regression.py` runs
  the solver regression and golden digests on the host, then the golden-frame and memory classes on sim-27.2 with
  `TEST_RUNNER_HARMONIC_BRIDGES_MEMORY_ISOLATED=1` (measured growth 0.55 MB over 12 cycles); regenerate the pinned
  frames only on purpose with `HARMONIC_BRIDGES_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02
  --filter HarmonicBridgesRegressionGoldenTests`. Baselines run before any new package file lands: park a new test
  file outside the tree while `baseline-round02` runs, so the baseline is the committed tree.
- **Echo Cartographer regression net** (R02-G11-08, 2026-11-23). `python3 scripts/echo_cartographer_regression.py` runs
  the solver regression and golden digests on the host, then the golden-frame and memory classes on sim-27.2 with
  `TEST_RUNNER_ECHO_CARTOGRAPHER_MEMORY_ISOLATED=1` (measured growth 0.86 MB over 12 cycles); regenerate the pinned
  frames only on purpose with `ECHO_CARTOGRAPHER_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02
  --filter EchoCartographerRegressionGoldenTests`. A host suite's build is cached after the first filtered run, so a
  check of a few seconds still ran its tests: read "Test run with N tests" in the log, not the time.
- **No `+` inside an `#expect` comment** (R02-G10-08, 2026-11-23). A message built as `"…" + "…"` in the second
  argument of `#expect` does not compile (the macro wants a `Comment`, and the concatenation is inferred as `String`);
  build the text in a `let` first and pass `"\(note)"`. The simulator build caught it on the first run (sim-27 exit 65).
- **Stage a shared file with the task it belongs to** (R02-G10-07, 2026-11-23). Agent A's new replay mode made the
  feedback plan's `modeName` switch non-exhaustive, so its copy carried a one-line fix in a lead-owned file, and its
  regenerated scenario manifest already held the new digests. The lead committed that line and a manifest regenerated
  for the T-002 tree with T-002, and the adapter's own feedback and manifest changes with T-003, so each commit builds
  and passes on its own; the iOS panel's and presenter's mode switches gained the new case in the same commit as the
  adapter.
- **Fade lights through uniforms when the mesh has no free channel** (R02-G10-06, 2026-11-23). Backwards Aurora's tear
  cross and preview ribbon carry their material code and timeline coordinate in the uv stream, leaving nothing for a
  shade, so their eased lights became two aurora uniforms (`u_tearLight`, `u_previewLight`) instead of geometry; a fade
  then rebuilds no mesh. The shader-source test's uniform list and vec4 slot count (9 → 11) changed with it. Frame
  checks that compare a state change (the won lift) now draw the later frame 1 s on, after the 0.15 s fade.
- **A bounded hint search can say "stuck" on a winnable state** (R02-G10-05, 2026-11-23). Backwards Aurora's hints use
  the certification's search with its 20,000-reversal bound; 24 of 200 seeded mid-play states found no plan within it,
  and a diagnostic run with a 2,000,000 bound found wins for 18 of them. The spec defines "can still win" as "a plan is
  found", so the hint test asserts the stuck text for those states and counts them instead of treating them as failures.
  Sample failures across the difficulty bands, not consecutive levels: random reversals almost never tear the easy
  levels' breaking limits, so a 500-failure sample drawn from levels 1 … 40 had no tears at all.
- **Keep frame-check points clear of additive glow** (R02-G10-03, 2026-11-22). Backwards Aurora's frame checks look
  for the lilac ghost trail at target points whose height differs from the wave's; at a gap of 8 units (0.075 world)
  the tier-0 glow shells, which reach 0.07 from the ribbon and are added over everything, tinted one ghost pixel on
  level 81 (green above red). Raising the gap to 12 units (0.1125) cleared it. Sum every additive layer's reach, the
  marker's half height and the pixel search radius before choosing such a gap.
- **Simulate a generator's filters before writing them down** (R02-G10-02, 2026-11-22). Backwards Aurora's first
  generator (one placement of k sections per candidate) certified only 59 of the 100 levels: in bands 3 … 5 nearly every
  candidate failed to fit its sections or broke a seam filter. A ten-line statistical simulation of the draws showed
  which filter dominated and how often each band passed (band 5: 0.4 % per candidate); drawing section lengths within
  what still fits, a gentler target and up to 16 placements per candidate raised band 5 to about 5 % per candidate (all
  256 failing ≈ 2·10⁻⁶), and all 100 levels now generate in under half a second. The seam-count proof (β = 4k) was kept
  unchanged.
- **Seam bends against a whole-wave recomputation** (R02-G10-01, 2026-11-22). Backwards Aurora's tear rule looks only
  at the bends at a reversal's seam positions; the wave tests compare every bend before and after 1 500 seeded
  reversals (three on each of 500 waves) and prove that the others are unchanged or carried along in reverse order. The
  first draft asserted that bends inside the section keep their positions, which is false (they move): state such
  locality claims as "only these can take new values" and test exactly that.
- **Exact cells against an independent ray cast** (R02-G09-01, 2026-11-22). Nocturne Garden's shadow cells are decided by
  an integer winding number on doubled coordinates with boundary centres counted inside; the bloom tests check every
  cell of the whole bed (not only the bounding box) against a separate even-odd ray cast on exact rationals with its own
  on-segment test, and the boundary deviation against an all-pairs brute force. A timing baseline taken right after the
  round-two suite failed under a load average of 13 and passed when rerun: run timing baselines on a quiet machine.
- **A schema change re-pins every winning scenario** (R02-G09-07, 2026-11-22). Nocturne Garden's results gained traces,
  so the digest of every scenario that wins changed and `scenario-manifest.json` was regenerated with
  `UPDATE_SCENARIO_MANIFEST=1`; equality checks on stored results became field checks (moves made, stars, verified,
  a non-empty trace), and the newer-schema refusal test moved to schema 4.
- **A frame test waits for a fade** (R02-G09-06, 2026-11-22). Once Nocturne Garden's leak crosses fade in over 0.15 s,
  a still drawn at the same presentation time as the failure showed no crosses, and the render test failed. Draw the
  still at a later time (1 s) and assert the eased level reached its target before checking pixels. A test with a
  literal array of fractions (`[1, 9.0 / 8, 5.0 / 4, 4.0 / 3]`) inside `#expect` did not type-check in reasonable time;
  bind typed constants first.
- **Hints are tested from the opening and from seeded states** (R02-G09-05, 2026-11-22). Nocturne Garden's hint search
  starts at the current blooms and sun; the host tests follow exact hints from the opening of all 100 levels (they must
  reproduce the certified move count) and from 200 seeded reachable states, and explain 500 seeded failures. The
  presenter computes the three hint levels off the main actor and caches them per play, so a simulator test awaits the
  search task before reading the panel.
- **A panel win test should also count the moves** (R02-G09-04, 2026-11-22). Nocturne Garden's first panel had
  single-step Sun − and +: the panel still won all 100 levels, but certified solutions that move the sun by two or three
  elevations cost up to two extra moves on 35 levels, so a player without gestures could not reach the smallest move
  count. The panel win test now also asserts that each level is won in exactly its certified move count, and the panel
  gained a sun picker with "Set sun". Gesture baselines were again taken with the feature's work held aside.
- **Frame checks skip what stands in front** (R02-G09-03, 2026-11-22). Nocturne Garden's blooms stand in front of the
  mist bed, so a bloom's head and stem can hide shadow, target or forbidden cells behind it. The CPU reference gives each
  bloom's pixel box (`NocturneGardenSceneGeometry.bloomPixelBox`), and the simulator frame checks sample only cell
  centres outside every box. The shadow drawn is the kernel's own mask (one quad per cell), never a GPU shadow, so the
  frame checks and the verdict name the same cells. The scenario manifest's neutral moves (a plant that keeps the play
  going, sun moves on an empty bed for the budget-out fixture) are derived by playing them on a core, as Faceted Forge's
  neutral cuts are.
- **Baselines on the committed tree; tokens the scans match** (R02-G09-02, 2026-11-22). The feature's first code was
  written while the previous gate's chain ran, so its baselines were taken with that work held aside (`git stash push -u
  -- <paths>`, then `git stash pop`), keeping the baseline a measure of the tree before the feature. A kernel test's list
  of forbidden imports spelled out `import MetalKit`, which the compliance scan (`check_compliance.py`, run by the script
  tests' audit) reads as a direct Metal renderer: a test that names forbidden tokens must not contain the scan's own
  patterns (`import Metal` alone covers the kit by prefix). Nocturne Garden's catalog check recomputes the lower bound
  of two levels per band by brute force over every plant with the kernel's bloom cells, independent of the solver's
  shifted stamps.
- **Split the X-gate round-two package run** (X-R02-G08, 2026-11-22). The X gate's `host` check (the whole
  `ExperiencesRound02-Package` on the iOS 27.2 simulator) took 368, 390, 417 and then 553 s at X-R02-G05 … G08: past
  the 540 s per-command rule, and `xcodebuild_package.py` has no timeout of its own, so a hang there would not be cut
  off. Nothing hung, but from X-R02-G09 on the run is split into chunks of whole test bundles with `--only-testing`
  (`host-1`, `host-2`), and every attestation's `elapsed_seconds` is read after a check: anything above about 450 s is
  split before the next gate. The one failed attempt of that gate (sim26) came from an outside
  `simctl shutdown all && simctl erase all`, not from the code.
- **Harmonic Bridges persistence and replay** (R02-G12-07, 2026-11-23). Host: all 100 witnesses verify as traces and
  every kind of edit is dropped and counted (`HarmonicBridgesReconciliationTests`); 500 seeded round trips, 100 schema-1
  and schema-2 migrations and 200 seeded edited saves (`HarmonicBridgesPersistenceTests`); simulator:
  `HarmonicBridgesReplayTests`. The persistence tests were written against the adapter's mirrored API while the adapter
  was drafted in parallel, and compiled first time once both met in one copy.
- **Harmonic Bridges polish and accessibility** (R02-G12-06, 2026-11-23). Host: feedback plans through the real adapter
  (every refusal code bare and with the engine's prefix), the lights' fades and flicker measure over seven adversarial
  patterns, and the audition and ambient recipes (`swift test --package-path Packages/ExperiencesRound02 --filter
  HarmonicBridges`); simulator: `HarmonicBridgesAccessibilityTests`. The won lift reached the bridges through a
  per-vertex flag, which a fade cannot reach; a uniform scales it instead.
- **Harmonic Bridges teaching and progression** (R02-G12-05, 2026-11-23). Host: exact hints from every opening win all
  100 levels in the witness's action count, 200 seeded states' hints are accepted and win, 500 seeded failures are
  explained with independently computed numbers, and the progress, daily (× 83, 2026–2036) and schema 1 → 2 rules
  (`swift test --package-path Packages/ExperiencesRound02 --filter HarmonicBridges`); simulator:
  `HarmonicBridgesTeachingTests`. Once `level.next` needs an open level, scenario and identity tests that called it on
  a fresh level must win first; the digest then includes progress, so expected digests move with it. The gate's
  first script-tests run failed only because a convergence run-check and its tick wrote `.autonomy/migration/` while
  the script tests ran (their ledger-tree guard, FR-U00-038); nothing writes there during script-tests.
- **Harmonic Bridges gestures** (R02-G12-04, 2026-11-23). Host: the picker against an independent projection (500
  seeded points × 3 sizes × 3 orbits), 500 seeded gesture scripts applied through the adapter, and all 100 levels won
  through the panel model (`swift test --package-path Packages/ExperiencesRound02 --filter HarmonicBridges`);
  simulator: `HarmonicBridgesGestureWiringTests`. Strings that overlap on one row of islands are exactly equidistant
  from a touch, and floating-point rounding then picked either one; the picker and its independent oracle both keep the
  lower index within 1e-6 points. The recorded checks of a gate cannot start before the previous gate is recorded
  (`run-check` refuses: "not ready"), so a gate's baselines wait for that record even when its agents start earlier. The
  wiring test also found that the panel had shown every kernel refusal as "not available": the engine reports a core's
  refusal as `action.rule.<code>`, and the words table matched only bare codes; assert the refusal's words, not only
  its code.
- **Harmonic Bridges renderer** (R02-G12-03, 2026-11-23). Host: the shader-source, geometry, adapter, purity and
  scenario tests (`swift test --package-path Packages/ExperiencesRound02 --filter HarmonicBridges`); simulator:
  `HarmonicBridgesExperienceTests` (frames against the CPU reference at three tiers on five levels, fallback, resize,
  Reduce Motion, a broken crossing, a won level). The shader and geometry agents first wrote two incompatible vertex
  streams (a uniform array of waves against per-vertex packed modes); the lead kept one contract and had the other agent
  rewrite to it. Fix the stream contract (attribute by attribute) in the brief before shaders and geometry are written in
  parallel.
- **Echo Cartographer renderer** (R02-G11-03, 2026-11-23). Host: the shader-source, geometry, adapter, purity and
  scenario tests (`swift test --package-path Packages/ExperiencesRound02 --filter EchoCartographer`); simulator:
  `EchoCartographerExperienceTests` (frames against the CPU reference at three tiers, fallback, resize, Reduce Motion,
  an energy failure). The shared `ShaderMeshRenderer` allows depth testing only with a depth buffer, which the offscreen
  and host framebuffers may lack, so a 3D chamber is drawn depth-off in painter's order (flat layers, then solids back to
  front, each row from the outside in) and the geometry tests check the order and the outward winding. glslangValidator
  is not installed here; GLSL compiles are proven by the simulator run.
- **Echo Cartographer content pipeline** (R02-G11-02, 2026-11-23). `swift test --package-path Packages/ExperiencesRound02
  --filter EchoCartographer` (86 tests, about 7 s): all 100 levels generated and certified, witness files compared byte
  for byte in 20 groups (regenerate only with `ECHO_CARTOGRAPHER_WRITE_WITNESSES=1`), the pinned digest, and a brute
  force over every beacon subset on the two smallest regions of each band. The band filters (pulse ranges, sizes,
  beacons) were measured with a short Python prototype of the greedy solver before the clarification was written, as
  R02-G10-02 taught; every entry then generated on the first Swift run.
- **Harmonic Bridges content pipeline** (R02-G12-02, 2026-11-23). `swift test --package-path Packages/ExperiencesRound02
  --filter HarmonicBridges`: the solver's minimum against an independent brute force over every peg (no pattern pruning)
  on 120 fixtures and band 1–3 candidates; an independent re-draw of 200 generator candidates; the 100 witness files
  byte for byte (regenerate only with `HARMONIC_BRIDGES_WRITE_WITNESSES=1`). A random generator left most candidates
  unsolvable in a Python prototype; the constructive one (a path whose strings can be bridges, k of them scrambled)
  reached each band's range in 37 … 60 of 60, so prototype the generator before writing ranges into the spec.
- **Acoustic Constellator rule kernel** (R02-G13-01, 2026-11-23). `swift test --package-path
  Packages/ExperiencesRound02 --filter AcousticConstellator` (46 tests, a few seconds): the coupling table against the
  rounded sine; the exact comparison A + B√3 ≥ θ exhaustively over 1.27 million triples against rational bounds of √3;
  ticks, order parameter, connectivity, listens and labels against an independent reference on 500 seeded levels; the
  play on 200 fixtures and 520 seeded traces; the rules on 200 walks (10 fully applied, the rest validated). The
  graph-isomorphism label is a brute force over all orderings (about 0.1 s for 8 stars in a debug build), so the play
  computes it when read and tests keep 8-star labels to a few cases.
- **Harmonic Bridges rule kernel** (R02-G12-01, 2026-11-23). `swift test --package-path Packages/ExperiencesRound02
  --filter HarmonicBridges` (40 tests, about 2 s): the swing table against exact quarter values of sin² at multiples of
  30°; resonance, swing, bridges and reachability against an independent reference (enumerated modes, explicit sums,
  fixed-point relaxation) on 1,502 seeded cases; the play on 500 fixtures and 500 seeded traces; the rules' legal moves
  against the real play on 200 walks (the first 20 through the real apply for every candidate, the rest through its
  validation plus 8 real applies per step: all-real took 7.1 s in a debug build, too close to 10 s with CI 3× slower).
- **Echo Cartographer rule kernel** (R02-G11-01, 2026-11-23). `swift test --package-path Packages/ExperiencesRound02
  --filter EchoCartographer` (45 tests, about 2 s): rays against explicit coordinate stepping and path lengths against
  fixed-point relaxation (no queue) on 500 seeded chambers; the play on 500 fixtures and 500 seeded traces; the rules'
  legal moves against the real play on 200 walks. Checking every pulse and claim cell at every step of all 200 walks took
  23 s because each attempt hashes a fingerprint, so 8 walks are exhaustive and 192 sample 24 cells per step. Write
  fixtures' comments from the drawn ranges: energy 1 + 0 … 3 lets the known pulse end the level, which all four agents
  found; the tests now rely on both kinds of fixture.
- **Harmonic Bridges device rows** (R02-G12-10, 2026-11-23). `python3 scripts/check_device_rows.py --experience
  r02-g12.harmonic-bridges` (release step `device-rows-r02-g12`, tests `HarmonicBridgesDeviceRowsCheckTests`) checks the
  definition (rows HB-D1 … HB-D8, 12 device scenarios) against the scenario manifest, the ledger's DEV1/2/3-R02-G12 rows
  and the open {device} tasks of features 411 … 419; nothing contacts a device. The written plan is generated from the
  checked JSON (procedure, pass and owner steps copied row by row), so the prose cannot drift from the definition.
- **Echo Cartographer device rows** (R02-G11-10, 2026-11-23). `python3 scripts/check_device_rows.py --experience
  r02-g11.echo-cartographer` (release step `device-rows-r02-g11`, tests `EchoCartographerDeviceRowsCheckTests`) checks
  the definition (rows EC-D1 … EC-D8, 12 device scenarios) against the scenario manifest, the ledger's DEV1/2/3-R02-G11
  rows and the open {device} tasks of features 401 … 409 (T-R02G1104-011 is an 011, not an 012); nothing contacts a
  device. Ported from Backwards Aurora's definition with rows EC-D3 … EC-D8 and EC-D4's owner step rewritten for the
  cell, marker and claim controls (and the journey chunk named `t3`); a case-insensitive scan for the model game's
  words (band, reversal, section, swipe) found nothing left.
- **Backwards Aurora device rows** (R02-G10-10, 2026-11-23). `python3 scripts/check_device_rows.py --experience
  r02-g10.backwards-aurora` (release step `device-rows-r02-g10`, tests `BackwardsAuroraDeviceRowsCheckTests`) checks
  the definition (rows BA-D1 … BA-D8, 12 device scenarios) against the scenario manifest, the ledger's DEV1/2/3-R02-G10
  rows and the open {device} tasks of features 391 … 399; nothing contacts a device. Ported from Nocturne Garden's
  definition with rows BA-D3 … BA-D8 rewritten for the reversal controls (and the journey chunk named `s3`).
  Re-read the owner steps too: BA-D4's touch step (and Nocturne Garden's NG-D4) still named Faceted Forge's controls;
  the plan's agent found it and both definitions were corrected.
- **Nocturne Garden device rows** (R02-G09-10, 2026-11-22). `python3 scripts/check_device_rows.py --experience
  r02-g09.nocturne-garden` (release step `device-rows-r02-g09`) checks the definition (rows NG-D1 … NG-D8, 12 device
  scenarios) against the scenario manifest, the ledger's DEV1/2/3-R02-G09 rows and the open {device} tasks of features
  381 … 389; nothing contacts a device. When porting a model definition, re-read every row's procedure and pass text:
  six texts still described the model game's controls after the identifiers were renamed.
- **Faceted Forge device rows** (R02-G08-10, 2026-11-22). `python3 scripts/check_device_rows.py --experience
  r02-g08.faceted-forge` (release step `device-rows-r02-g08`) checks the definition against the scenario manifest, the
  ledger's DEV rows and the open {device} tasks of features 371 … 379; `FacetedForgeDeviceRowsCheckTests` in
  `test_scripts.py` proves it fails by name on a removed scenario, a missing field and an uncovered task.
- **PosterBoard crashes on the UI-test phone** (R02-G08-09, 2026-11-22). "PosterBoard quit unexpectedly" dialogs came
  from one simulator, the iOS 27.2 iPhone that `xcodebuild_app.py --kind phone` picks: its poster database was
  corrupt (`PRPosterDescriptor _initWithPath` in the StandBy role), and every Home press of a relaunch test crashed
  PosterBoard again. The crash report's `coalitionName` names the simulator; moving that device's
  `PRBPosterExtensionDataStore` and `com.apple.PosterKit` aside (simulator shut down) ended the crashes. The same
  relaunch test could not tap the restored level picker: right after a relaunch a visible stepper inside the nested
  scroll views reported not hittable, so `FF` waits up to 5 s and then taps a control whose frame lies inside the
  visible list by coordinate; an unchanged value still fails the test.
- **Faceted Forge in the app** (R02-G08-09, 2026-11-22). Serial chunk `q3` holds `FFPlayUITests` and `FFReplayUITests`
  (the key was checked unique before use). Each cut is set by stepping the piece, direction and depth pickers from
  their current values (read from the steppers), never from an assumed choice, because the panel keeps the player's
  choice across cuts; `xcodegen generate` ran first so the new UI test files reach the target.
- **Each app launch now costs about 30 s of automation-session setup** (R02-G09-09, 2026-11-22). XCTest's "Setting up
  automation session" step took 30 to 33 s per launch on the iOS 27.2 UI-test phone, in Faceted Forge's chunk `q3`
  and Nocturne Garden's `r3` alike, so a relaunch journey (two launches) cannot stay under 90 s in all: Nocturne
  Garden's took 114 s, 54 s without the two setups (Faceted Forge's 105 s). The interface-test bound is measured without
  the per-launch setup, inside the 180 s allowance. Read the `t =` step times before optimizing a slow UI test. The
  `dtdeviceinfod` and `chronod` reports written at the same time are kills at simulator shutdown (SIGTERM timeout),
  not crashes of the app. New UI test files reach the test bundle only after `xcodegen generate`; the first `r3` run
  built none and executed 0 tests (the enumeration guard failed it).
- **Nocturne Garden regression** (R02-G09-08, 2026-11-22). `python3 scripts/nocturne_garden_regression.py` runs the
  host filter `NocturneGardenRegression` (solver regression over 100 witnesses in tests of 10, ten named alterations,
  golden descriptions) and then the simulator golden-frame and memory classes with
  `TEST_RUNNER_NOCTURNE_GARDEN_MEMORY_ISOLATED=1`; CI runs the host part as a named step. Golden frames are taken at
  time 0 (the mist drift and the sway are shader uniforms, so no position depends on time), but the simulator still is
  drawn 1 s later so the eased lights of feature 386 have settled. A golden source in the Core must be listed among the
  invariant scan's presentation sources, or the kernel scan fails on its Doubles.
- **Faceted Forge regression** (R02-G08-08, 2026-11-22). `python3 scripts/faceted_forge_regression.py` runs the host
  filter `FacetedForgeRegression` (solver regression over 100 witnesses in tests of 10, ten named alterations, golden
  descriptions) and then the simulator golden-frame and memory classes with
  `TEST_RUNNER_FACETED_FORGE_MEMORY_ISOLATED=1`; CI runs the host part as a named step. Golden frames stop at most two
  cuts in and one cut short of the win, fully opened, so pieces, the preview and the cut bars show in every baseline;
  the level alterations reuse the unaltered certified solution so no altered level is re-solved. The golden frame test
  pins the initial preview choice after its cuts, because the presenter keeps the player's choice across cuts.
- **Amethyst Escape regression** (R02-G07-08, 2026-11-22). `python3 scripts/amethyst_escape_regression.py` runs the
  host filter `AmethystEscapeRegression` (solver regression over 100 witnesses in tests of 10, twelve named alterations,
  golden descriptions) and then the simulator golden-frame and memory classes with
  `TEST_RUNNER_AMETHYST_ESCAPE_MEMORY_ISOLATED=1`; CI runs the host part as a named step. Golden frames stop one move
  short of the escape (at most 3 moves) so the pearl and the move bar are inside every level baseline; the simulator
  frames reuse the feature-363 frame-check helpers unchanged.
- **Chrono Constellator regression** (R02-G06-08, 2026-11-22). `python3 scripts/chrono_constellator_regression.py`
  runs the host filter `ChronoConstellatorRegression` (solver regression over 100 witnesses in tests of 10, twelve named
  alterations, golden descriptions) and then the simulator golden-frame and memory classes with
  `TEST_RUNNER_CHRONO_CONSTELLATOR_MEMORY_ISOLATED=1`; CI runs the host part as a named step. Golden frames show the
  certified phase changes and 6 ticks so ribbons are part of every level baseline; the simulator frames reuse the
  feature-353 frame-check helpers unchanged.
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
