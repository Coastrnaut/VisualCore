---

description: "Task list for feature 005 — Phase 4 effects graph (ledger gate F04)"
---

# Tasks: Phase 4 — Reusable Effects and Render Pipelines

**Input**: `/specs/005-effects-graph/` · **Tests**: required (fixtures, cycle rejection, per-effect pixel tests); written first.
IDs `T-F4##`. One commit + push per task. Effects implemented one at a time (archive instruction).

## Phase 1: Setup

- [X] T-F401 Add test targets `VisualCoreEffectsGraphTests` (pure) and `VisualCoreEffectsTests` (sim) to the two Package.swift files — Verified 2026-11-10: both test targets declared (first sources land in T-F402/T-F406; compiled there)

## Phase 2: Foundational (pure)

- [X] T-F402 (FR-F401–F404, SC-F401) Tests + JSON fixtures `Packages/VisualCore/Tests/VisualCoreEffectsGraphTests/ValidationTests.swift`: valid chain order, tie-break, every rejection case, memory estimate incl. feedback, Codable round-trip, parameter clamping to schema ranges, unknown parameter keys warned — Verified 2026-11-10: 9 tests + 3 JSON fixtures pass in F04.t403-validation-a2
- [X] T-F403 Implement `EffectGraph.swift`, `PassSchemas.swift`, `EffectGraphValidation.swift` in `VisualCoreEffectsGraph` — Verified 2026-11-10: F04.t403-validation-a2 exit 0: 9 validation tests pass (a1 = test helper label mismatch, kept)
- [X] T-F404 (FR-F409, SC-F403) Tests `FlashLimiterModelTests.swift`: 30 Hz strobe over 1 s changes displayed mean ≤ 0.3; steady input converges; gain bounded — Verified 2026-11-10: 4 tests pass in F04.t405-flashlimiter: per-frame change ≤ 0.3/30, 1 s range ≤ 0.3
- [X] T-F405 Implement `FlashLimiterModel.swift` — Verified 2026-11-10: F04.t405-flashlimiter exit 0: 4 model tests pass (13 in module)

## Phase 3: US1 + US2 — GPU passes one at a time (P1) 🎯

- [X] T-F406 [US2] Renderer core + `copy`: `EffectRenderer` (validated order, pooled targets, recycle, full-screen triangle), `EffectShaders.swift`; pixel test copy == input — Verified 2026-11-10: F04.t406-copy-ios27-a2 exit 0: copy pixel test + pre-GPU cycle rejection pass (2 effects tests; 31 rendering tests still pass; a1 = registry.warn access, made public)
- [X] T-F407 [US2] `colorMatrix` pass + pixel test (red→blue swap; offset) — Verified 2026-11-10: F04.t407-colormatrix-ios27 exit 0: red→blue swap + 0.2 green offset within 1/255
- [X] T-F408 [US2] `blur` pass (separable, radius clamp 1–32) + pixel test (single bright pixel spreads, peak drops, energy ≈ conserved ±5%) — Verified 2026-11-10: F04.t408-blur-ios27 exit 0: peak drops, spreads 2 texels, far stays 0, energy within 5%
- [X] T-F409 [US2] `bloom` pass (threshold, intensity, radius, hdr) + pixel test (near bright area brightens; far dark stays dark) — Verified 2026-11-10: F04.t409-bloom-ios27 exit 0: near pixel +>10, far dark within 2, block stays white
- [X] T-F410 [US2] `distort` pass (strength, frequency, time) + pixel test (strength 0 = identity; strength > 0 moves a stripe) — Verified 2026-11-10: F04.t410-distort-ios27 exit 0: strength 0 max diff 0; strength 0.1 moves stripe on >4 rows
- [X] T-F411 [US2] `composite` pass (two inputs, alpha over/add) + pixel test — Verified 2026-11-10: F04.t411-composite-ios27 exit 0: over@0.5 → (128,0,128)±2; add → (≥254,0,≥254)
- [X] T-F412 [US2] `feedback` pass with history target (FR-F412) + test (decay 0.5 converges; cleared on resize/recreation) — Verified 2026-11-10: F04.t412-feedback-ios27 exit 0: 0 → 128±2 → 191±3, resize clears to 255, no leaks
- [X] T-F413 [US2] (FR-F408, SC-F404) Fault injection: forced pass compile failure → pass-through, graph output present, reported once — Verified 2026-11-10: F04.t413-fault-ios27 exit 0: injected failure on B → red passed through 3 frames, failedPasses={B}, 1 warning

## Phase 4: US3 — Reduce Flashing (P2)

- [X] T-F414 [US3] `flashLimit` pass (16×16 luma readback → FlashLimiterModel gain) + sim test with alternating black/white input over 30 frames at Δt=1/30 — Verified 2026-11-10: F04.t414-flashlimit-ios27 exit 0: 30-frame 30 Hz strobe, per-frame change ≤ 0.3/30·255+2, range ≤ 0.3·255+2

## Phase 5: Integration & Polish

- [X] T-F415 (FR-F410, FR-F411, SC-F405) `EffectScene` wrapping a content scene; sim test scene+3-pass graph renders; resize and recreation rebuild; `reduceFlashing` appends the limiter — Verified 2026-11-10: F04.t415-effectscene-ios27 exit 0: 3-pass graph swaps gradient colors on screen; resize + recreation keep rendering, leaked 0 after destroy; reduceFlashing appends __flashLimit
- [X] T-F416 Document pass schemas in `Packages/VisualCoreRendering/README.md` — Verified 2026-11-10: README effects table covers all 8 types; script cross-check found every PassSchemas parameter documented
- [X] T-F417 Full verification: host tests, sim 27.2 + 26.5, generic iOS, dependencies, compliance, docs, reference regression — Verified 2026-11-10: F04 run-checks all exit 0: host 51 tests; sim 31 rendering + 15 effects on iOS 27.2 and 26.5; generic-iOS BUILD SUCCEEDED; R1-R5, compliance, scripts, docs; reference ANGLERendering 13/13 both runtimes, tree clean
- [ ] T-F418 {device} Per-effect GPU cost on D1/D2/D3 — **deferred to campaign II** (constitution V; not a gap for F04); automation mode to be added with the AutomationRunner (F09)

## Dependencies

Setup → T-F402/T-F403 → T-F404/T-F405 → T-F406 → T-F407…T-F412 (one at a time) → T-F413 → T-F414 → T-F415 → Polish.

## Implementation Strategy

MVP = validation + copy/colorMatrix/blur. Each effect lands with its own test and commit.

## Phase 6: Convergence

- [ ] T-F419 Recycle each intermediate target to the pool right after its last consumer runs within the frame (keep the scene and graph output), with a sim test that a 4-pass chain holds fewer live targets than passes, in `Packages/VisualCoreRendering/Sources/VisualCoreEffects/EffectRenderer.swift` per FR-F407 (partial)
- [X] T-F420 Make `EffectGraphError.cycle` name only the passes on the cycle (not downstream dependents), with a host test, in `Packages/VisualCore/Sources/VisualCoreEffectsGraph/EffectGraphValidation.swift` per US1/AC2 (partial) — Verified 2026-11-10: F04.t420-cycle-names exit 0: cycle with a downstream dependent names only [B, C]; existing cycle fixture still [B, C]
- [ ] T-F421 Rebuild the effect graph when `EffectScene.flashLimitPerSecond` changes, with a sim test, in `Packages/VisualCoreRendering/Sources/VisualCoreEffects/EffectScene.swift` per FR-F409 (contradicts)
- [ ] T-F422 Update `specs/005-effects-graph/contracts/effects-api.md` and `data-model.md` to match the public API (render signature, EffectScene.reduceFlashing/effectiveGraph/flashLimitPassID, FlashLimiterModel bias, lastOrder/lastWarnings, ResourceRegistry.warn) per plan: contracts (partial)
- [X] T-F423 Warn (once per pass and slot) about input slots a pass declares that its schema does not define, with a host test, in `EffectGraphValidation.swift` per FR-F406 (partial) — Verified 2026-11-10: F04.t423-unknown-slots exit 0: undeclared slot 'extra' warned once, adds no ordering edge (order A,B)
