# Tasks: Aurora — Phase 04 Audio and low-power experience

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/loop.md](contracts/loop.md), [contracts/lowpower.md](contracts/lowpower.md), [quickstart.md](quickstart.md).
Gate A21-P04 (legacy). Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A21-P04 --timeout 595
--name <check> -- <command>`. Commit after every task (no trailers); read every check's exit before ticking, never in
the same command. iOS 27 only. This phase changes VisualCore (rule 13). Precedent: `specs/148-zg-p04-library-a11y`;
for the audio change, feature 077 (A10-P03). Rollback: revert the commits (the API baseline returns with them).

## Phase 1: Setup

- [X] T-A21-401 Baseline: cite the A21-P03 evidence (`.autonomy/checks/A21-P03.{au-ios27,app-unit,verify-27}.json`) on — Verified 2026-11-17: 2026-11-17: A21-P03 evidence cited: .autonomy/checks/A21-P03.au-ios27.json, A21-P03.app-unit.json and A21-P03.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A21-P03 record commit dc198171
  the tree recorded at A21-P03 (`dc198171`), whose Packages are unchanged since (owner ruling of 2026-11-14)

## Phase 2: Story 4 — a sound loop the whole app can use (P2, VisualCore first)

- [X] T-A21-402 [P] [US4] Create `Packages/VisualCore/Sources/VisualCoreAudioDSP/AmbientLoop.swift` per data-model.md: — Verified 2026-11-17: 2026-11-17: AmbientLoopPartial, AmbientLoopRecipe (4 to 16 whole seconds at 48 kHz, 1 to 6 partials of whole cycles per loop, a swell of whole cycles, gain at most 0.3, gentle default) and AmbientLoopSynth.render (exact integer phase steps, deterministic, finite, peak equal to the gain, seamless at the wrap; invalid recipes empty) in VisualCoreAudioDSP with /// docs; AmbientLoopSynthTests (7); .autonomy/checks/A21-P04.audio-dsp-host.json exit 0 (115 tests); written by an agent, retested
  `AmbientLoopRecipe` ("`seconds` 4…16 (whole, default 8), `sampleRate` 48,000, `partials` 1…6 of (cycles per loop ≥
  1, amplitude 0…1), `swellCycles` ≥ 1, `gain` 0…0.3"; invalid recipes render no samples) and `AmbientLoopSynth.render`
  (deterministic, finite, |x| ≤ gain, seamless at the wrap); `///` on every public declaration; and
  `Packages/VisualCore/Tests/VisualCoreAudioDSPTests/AmbientLoopSynthTests.swift` (FR-A21-405)
- [X] T-A21-403 [US4] Create `Packages/VisualCoreRendering/Sources/VisualCoreAudio/AmbientLoopPlayer.swift` after — Verified 2026-11-17: 2026-11-17: AmbientLoopPlayer in VisualCoreAudio (own engine and player node, .ambient, the buffer rendered once and scheduled looped, volume on the node clamped with non-finite ignored, isEnabled, isPlaying, play, stop; stopped on interruption, media-services reset and backgrounding through an injected center; no input) with /// docs; AmbientLoopPlayerTests (8); .autonomy/checks/A21-P04.audio-ios27.json exit 0 (84 audio tests on sim-27.2); written by an agent, retested
  `SoundEffectPlayer` (an engine and player node of its own, `.ambient`, the buffer scheduled looped, `volume` on the
  node "clamped to 0…1, non-finite ignored", `isEnabled`, `isPlaying`, `play()`, `stop()`, stopped on interruption,
  media-services reset and backgrounding, injected output and notification center) and
  `Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/AmbientLoopPlayerTests.swift` (FR-A21-405)
- [X] T-A21-404 [US4] Add both types to the module rows of `Packages/VisualCore/README.md` and — Verified 2026-11-17: 2026-11-17: feature 155 entries in the VisualCoreAudioDSP row of Packages/VisualCore/README.md and the VisualCoreAudio row of Packages/VisualCoreRendering/README.md; docs/api/visualcore-public-api.txt updated with check_public_api.py --update (23 added, 0 removed, 0 undocumented); .autonomy/checks/A21-P04.public-api.json, A21-P04.visualcore-host.json and A21-P04.audio-ios27.json exit 0
  `Packages/VisualCoreRendering/README.md`; update `docs/api/visualcore-public-api.txt` with `python3
  scripts/check_public_api.py --update` (additive only), then check it (`--name public-api`); VisualCore host tests
  (`--name visualcore-host -- swift test --package-path Packages/VisualCore`) and the audio tests (`--name
  audio-ios27`) (FR-A21-405)
- [X] T-A21-405 [US4] The seven-step reference regression in two chunks (`--name reference-1`, `--name reference-2`) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P04.reference-1.json and A21-P04.reference-2.json exit 0: the seven-step ProjectM reference regression passes after the VisualCore audio change
  after the VisualCore change (FR-A21-406; SC-A21-404)

## Phase 3: Story 1 — a still sky (P1) 🎯

- [X] T-A21-406 [P] [US1] The still view in `Packages/ExperiencesCreative/Aurora/Experience/{AuroraPresenter,AuroraControls}.swift` — Verified 2026-11-17: 2026-11-17: Still sky (identifier still, presentation only): SkyPicture in a CachedScene keyed by the digest, size and the drawn inputs; drawn once over 100 frames, once more after a change, a change between skies completes then holds, Reduce Motion as well holds; StillViewTests (3); .autonomy/checks/A21-P04.au-ios27.json exit 0; written by an agent, retested
  ("Still sky", identifier `still`, presentation only; `CachedScene` keyed by the digest and the size; the clock
  holds) and `ExperienceTests/StillViewTests.swift` (drawn once over 100 frames; once more after a change; a change
  between skies completes then holds; with Reduce Motion on as well, the still view wins and holds) (FR-A21-401; SC-A21-401)

## Phase 4: Story 2 — nothing flashes (P1)

- [X] T-A21-407 [US2] The reduced-flash mode (control `reduced-flash`, and the system's Reduce Flashing: twinkle 0, — Verified 2026-11-17: 2026-11-17: Reduced flashing (identifier reduced-flash) and the system's Reduce Flashing: twinkle off through u_twinkleOff (default output unchanged, 0/255) and 4.0 s changes; ReducedFlashTests: largest mean-luminance step 0.00079 at 30 frames per second, under 0.02, also during a change; .autonomy/checks/A21-P04.au-ios27.json exit 0; written by an agent, retested
  changes 4.0 s) and `ExperienceTests/ReducedFlashTests.swift` (every consecutive frame's mean-luminance step < 0.02
  at 30 frames per second, also during a change) (FR-A21-402; SC-A21-402)

## Phase 5: Story 3 — fallback and released targets (P1)

- [X] T-A21-408 [US3] `SkyShader.fallbackSource` in `Packages/ExperiencesCreative/Aurora/Core/SkyShader.swift` and the — Verified 2026-11-17: 2026-11-17: SkyShader.fallbackSource (mediump gradient of the sky colour to 0.6 at the horizon, under the limit) shown on a compile failure or a missing highp with the message This device shows a simpler sky., the clear colour if it fails too; FallbackTests (5); TargetReleaseTests (2): live bytes 0 after the first frame, 55,296 at the peak of a change, 0 after ten changes, none leaked; .autonomy/checks/A21-P04.au-ios27.json exit 0; written by an agent, retested
  fallback path in the presenter (a compile failure or `fragmentHighp` false → the gradient sky under the limit and
  the message "This device shows a simpler sky."; a test seam forces each path), with
  `ExperienceTests/FallbackTests.swift` and `ExperienceTests/TargetReleaseTests.swift` (render-target, texture and
  buffer bytes after ten finished preset changes equal the baseline) (FR-A21-403, 404; SC-A21-403)

## Phase 6: Records and evidence

- [X] T-A21-409 Aurora tests on sim-27.2 (`--name au-ios27`), documented API, isolation, core purity (review checkpoint) — Verified 2026-11-17: 2026-11-17: review checkpoint: .autonomy/checks/A21-P04.au-ios27.json (53 Swift Testing and 21 XCTest tests, each under 10 s), A21-P04.documented-api.json, A21-P04.isolation.json, A21-P04.core-purity.json and A21-P04.audio-hot-path.json, all exit 0
- [X] T-A21-410 Contract: G-LOOP and G-LOWPOWER closed by "A21-P04"; rows whose gaps are all closed become available — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P04.contract.json exit 0; G-LOOP and G-LOWPOWER closed by A21-P04 (the missing-highp path proven through a seam, recorded in the notes); M22 and M23 available; M09 and M10 stay open for G-DEVICE and G-SOUND
  with evidence (`--name contract`)
- [X] T-A21-411 Manifest (unchanged unless an engine action changed), catalog, app build and unit (`--name app-unit`), — Verified 2026-11-17: 2026-11-17: scenario-manifest.json unchanged (AuroraManifestTests pass in A21-P04.au-ios27.json; no engine action changed); .autonomy/checks/A21-P04.catalog.json, A21-P04.app-unit.json (build for testing and unit on iOS 27.2), A21-P04.verify-27.json, A21-P04.experience-packages.json and A21-P04.script-tests.json, all exit 0
  runner (`--name verify-27`), packages and script tests
- [ ] T-A21-412 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A21-P04; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

401 → {402 → 403 → 404 → 405} ∥ {406 → 407 → 408} → 409 → 410 → 411 → 412. The VisualCore files (402–404) and the
experience files (406–408) are separate; 406–408 share the presenter and run in one agent.

## Parallel examples

Agent A: T-A21-402, 403 and the README rows of 404. Agent L: T-A21-406–408. Lead: the API baseline, the runs (404,
405, 409–411), the contract and commits.

## Implementation strategy

MVP: the still view (406). Reduced flash (407) and the fallback and release (408) close G-LOWPOWER; the loop (402–405)
closes G-LOOP. Review checkpoint at 409. One commit per task.
