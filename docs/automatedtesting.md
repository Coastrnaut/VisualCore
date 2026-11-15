# Automated testing in VisualCore

How VisualCore's code is tested automatically, how a test run becomes evidence for a gate, and what was learned while
building the experiences. This file is kept current: every gate that changes a test tool, a test rule or teaches a
new lesson updates it (CLAUDE.md, section 4). Older simulator-specific lessons from the first app campaign are in
[testing/simulator-test-lessons.md](testing/simulator-test-lessons.md); they still apply.

Last updated: 2026-11-15 (A14-P04 convergence: canvas overlay tests, documented-API check, injected clocks).

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

### Determinism and digests

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

## 6. Keeping this file current

Update this file whenever a gate adds or changes a test tool, a test rule, the per-gate sequence, or teaches a lesson
worth keeping; change the "Last updated" line and keep entries short and factual. Do not record progress here — the
ledgers carry it.
