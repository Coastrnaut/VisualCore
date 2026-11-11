---

description: "Task list for feature 009 — Phase 8 second consumer (ledger gate F08)"
---

# Tasks: Phase 8 — Reuse Validation with a Second Consumer

**Input**: `/specs/009-second-consumer/` · **Tests**: required (GardenKit host tests, check fixtures, smoke UI test). IDs `T-F8##`.
One commit + push per task.

## Phase 1: Setup

- [X] T-F801 `Harnesses/SecondConsumer/GardenKit/Package.swift` (depends on local VisualCore: Math, Simulation) and `Harnesses/SecondConsumer/SecondConsumer.yml` (app + UI test targets, packages GardenKit, VisualCore, VisualCoreRendering; bundle id `dev.visualcore.harness.SecondConsumer`); shell app builds unsigned for the simulator — Verified 2026-11-10: F08.t801-gardenkit-host exit 0 (swift test on the Mac, GardenKit links VisualCore pure modules); F08.t801-shell-test TEST SUCCEEDED (iOS 27.2): SecondConsumer.yml app + UI test target build unsigned and the shell launches

## Phase 2: Foundational — checks (US2, P1)

- [X] T-F802 [US2] `scripts/audit_showcase_dependencies.py`: resolve `packages:` paths relative to the spec file's directory; test in `scripts/test_scripts.py` (harness-style spec with `../../` paths); audit run on `Harnesses/SecondConsumer/SecondConsumer.yml` with target `SecondConsumer` — Verified 2026-11-10: F08.t802-audit-tests: 29 script tests OK incl. new harness-spec case; F08.t802-audit-secondconsumer: spec 4, packages 3 (GardenKit, VisualCore, VisualCoreRendering), imports 12, binary 5 Mach-O — 0 findings; F08.t802-audit-showcase still exit 0 (root spec unaffected)
- [X] T-F803 [US2] `scripts/check_documented_api.py` (public VisualCore types/free functions referenced by the consumer must be named in package READMEs or `specs/*/contracts/*.md`; exit 0/1/2) with fixtures `scripts/fixtures/documented_api/{documented,undocumented}/` and tests in `scripts/test_scripts.py` — Verified 2026-11-10: F08.t803-docapi-tests: 32 script tests OK (documented use passes ignoring comments/strings; undocumented 'Hidden' fails by name; usage errors exit 2). First real run found the Showcase using undocumented 'Emitter' (F08.t803-docapi-showcase exit 1) — README now names Emitter/ParticleForce/ParticleInstance; F08.t803-docapi-showcase-a2 PASS 33/33; InteractiveDemo 20/20, ProjectMReference 9/9 documented

## Phase 3: US1 — game (P1) 🎯

- [X] T-F804 [US1] GardenKit tests first `Tests/GardenKitTests/GardenTests.swift` (plant, spacing 40 → `.tooClose`, capacity 24 → `.full` and harvested slot reuse, growth 4 s → bloom, tap within 30 of a bloom harvests (+1), tap on a growing seed → `.notReady`, breeze decay, deterministic replay), then `Sources/GardenKit/Garden.swift` — Verified 2026-11-10: F08.t804-gardenkit exit 0 (swift test on the Mac): 7 tests — plant/spacing 40 (39 tooClose, 40 ok), seed→growing→bloom at 4 s, harvest within 30 scores only blooms (+1) and growing seeds return notReady, interact plants/harvests/replants, capacity 24 → full then oldest harvested slot reused, breeze follows drag with 1 s decay and 300 cap, seeded deterministic replay
- [X] T-F805 [US1] `Sources/GardenScene.swift` + `Shaders/field.vert/.frag`: background shader via `ResourceRegistry.program(…library:)`, flowers via `PrimitiveRenderer` (scaled by growth), particles via `ParticleSystem` + `ParticleRenderer` (shedding, harvest burst, breeze force), all inside `EffectScene` with bloom; fixed-step `FixedStepClock`; tap/drag through `TapRecognizer`/`DragRecognizer` and `ViewMetrics.toWorld`; Reduce Motion lowers rates and drops bursts; accumulator reset on foreground — Verified 2026-11-10: F08.t805-scene-build BUILD SUCCEEDED; F08.t805-docapi PASS — the game uses 21 VisualCore APIs, all documented (RenderScene, ShaderLibrary/ShaderProgram via ResourceRegistry.program, PrimitiveRenderer, ParticleSystem/Emitter/ParticleRenderer, FixedStepClock, PointerTracker/TapRecognizer/DragRecognizer, ViewMetrics/Camera2D, …); gameplay behavior is verified by the launch check (T-F806) and smoke test (T-F807)
- [X] T-F806 [US1] `Sources/SecondConsumerApp.swift`: SwiftUI shell, `garden.canvas` (VoiceOver label/hint, direct interaction), `garden.diagnostics` label `planted=… blooming=… score=… particles=…`, Reset button; post-build dependency-audit phase in `SecondConsumer.yml`; simulator launch screenshot — Verified 2026-11-10: F08.t806-app-build BUILD SUCCEEDED with the post-build phase printing 'PASS: no ProjectM engine/preset/bridge dependency' and 'PASS: every VisualCore API the consumer uses is documented'; simulator launch (iOS 27.2) screenshot: aurora field shader through the EffectScene glow, hint and diagnostics 'planted=0 blooming=0 score=0 particles=0', Reset button; canvas/diagnostics/reset accessibility identifiers and VoiceOver label/hint present

## Phase 4: US3 — smoke test (P2)

- [X] T-F807 [US3] `UITests/GardenSmokeUITests.swift`: plant 3 (planted=3), too-close tap ignored, wait for bloom (blooming ≥ 1), harvest one (score=1, particles rise), drag breeze, tap growing seed does not score; after rotating to landscape a tap still plants (planted +1); with `-uitestReduceMotion YES` a harvest produces no burst (particles stay below the burst size) — on iOS 27.2 and 26.5 — Verified 2026-11-10: F08.t807-smoke-ios27 and -ios26 TEST SUCCEEDED (3/3 each): plant 3 (planted=3); taps 35 pt from / on a growing seed change nothing; all 3 bloom and shed particles; harvest → score=1, planted=2, particles rise (burst); drag does not score; landscape rotation keeps tap mapping; Reduce Motion harvest has no burst (<60 particles)

## Phase 5: Polish

- [X] T-F808 `Harnesses/SecondConsumer/README.md` (what it proves, capability map to documented APIs, how to run checks and smoke test) — Verified 2026-11-10: F08.t808-readme exit 0 (validate_docs): README covers the game, the capability→documented-API map, GardenKit host tests, both checks (also post-build) and the smoke test
- [X] T-F809 Full verification: GardenKit host tests, documented-API check, audit (spec + built app), smoke test both runtimes, host + rendering regression, R1–R5, compliance, scripts, docs — Verified 2026-11-10: F08.t809-* all exit 0: GardenKit 7 host tests; documented-API PASS (21/21); dependency audit on spec + built app 0 findings; generic-iOS build (post-build checks PASS); VisualCore host 130 tests; VisualCoreRendering sim iOS 27.2; R1-R5, compliance, 32 script tests, docs, reference clean; smoke 3/3 on iOS 27.2 and 26.5 (T-F807)
- [ ] T-F810 {device} Lumen Garden frame pacing on D1/D2/D3 — **deferred to campaign II** (constitution V)

## Dependencies

T-F801 → T-F802/T-F803 → T-F804 → T-F805 → T-F806 → T-F807 → T-F808 → T-F809.

## Phase 6: Convergence

- [X] T-F811 Add a smoke case to `Harnesses/SecondConsumer/UITests/GardenSmokeUITests.swift`: plant, send the app to the background for 6 s, return → no bloom within the first second back (growth did not jump by the background time), bloom later; on iOS 27.2 and 26.5 per spec Edge Cases: background/foreground (partial) — Verified 2026-11-10: F08.t811-background-ios27 and -ios26 TEST SUCCEEDED (4/4 each): plant, 6 s in the background (longer than growth), back → blooming=0 after 0.6 s, then blooms once active time passes
- [ ] T-F812 Sync `specs/009-second-consumer/contracts/second-consumer.md` with the code (Garden.interact/InteractionResult, Flower.hue, Garden.time/maxBreeze, garden.title/garden.hint identifiers), verified by a symbol check per plan: contracts (partial)
