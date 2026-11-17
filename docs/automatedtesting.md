# Automated testing in VisualCore

How VisualCore's code is tested automatically, how a test run becomes evidence for a gate, and what was learned while
building the experiences. This file is kept current: every gate that changes a test tool, a test rule or teaches a
new lesson updates it (CLAUDE.md, section 4). Older simulator-specific lessons from the first app campaign are in
[testing/simulator-test-lessons.md](testing/simulator-test-lessons.md); they still apply.

Last updated: 2026-11-16 (A18-P01: a fixed time zone is checked with TimeZone(identifier:), because the known-identifier list omits current names such as Asia/Kolkata; the VisualCoreExperience purity test names its clock files as it names its storage files; A18-P00: a contract view needs its generated-block markers before the first render, and in zsh a command stored in a variable does not word-split; X-A17: a snapshot schema above 1 needs a stored example before integration; A17-P06: interface chunk y2, the copy check allows camera for an orbit camera; A17-P05: a review record beside the content, a list-only accessibility fixture; A17-P04: every VisualCore name used must be named in a README or a feature contract, never tick in the command that runs the checks; A17-P03: an edited snapshot fails the host's digest check, test storages removed by an observer; A17-P02: probe rays for picking tests, a snapshot envelope refuses non-JSON; A17-P01: a core before its experience passes the package check; A17-P00: an audit corrects the clarification; A16-P06: interface chunk x2, a scan that allows a named format; A16-P05: a generated validation report; mirrors reload after an edit; A16-P04: no mutating call inside #expect; A16-P03: round to half in the shader, test the mirror while it runs; A16-P02: GPU parity against both half roundings; A16-P01: fixture count from the catalog).

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
- **Quantise before hashing floats** for digests that must match across platforms (surface colours are hashed as
  16-bit values).

### Swift and test-tool pitfalls

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

### Process

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
- **A snapshot schema above 1 needs a stored example before integration.** `AppModelTests`
  `testEveryRegistrationHasAnExampleOfEveryEarlierSchemaVersion` checks only integrated registrations, so a candidate
  whose snapshot schema rose (A17's view state reached schema 2 in A17-P03) passes every phase gate. It then fails at
  its X gate's follow-through. When a phase raises the snapshot schema, add `schemaExample(version:)` for each earlier
  version (Molecular Explorer's pattern) and register it with `examples:` in that same phase.

## 6. Keeping this file current

Update this file whenever a gate adds or changes a test tool, a test rule, the per-gate sequence, or teaches a lesson
worth keeping; change the "Last updated" line and keep entries short and factual. Do not record progress here — the
ledgers carry it.
