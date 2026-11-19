# Tasks: R02-F07 — Linear-colour HDR-look emissive pass and mobile-safe bloom

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F07 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks; frame cost on D1–D3 is a {device} item of the campaign.

## Phase 1: Setup

- [X] T-R02F07-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F07.{baseline-host,baseline-rendering}.json (exit 0)
  `--name baseline-rendering --` the VisualCoreRendering scheme on sim-27.2

## Phase 2: Foundational (pure)

- [X] T-R02F07-002 [P] Create `Packages/VisualCore/Sources/VisualCoreEffectsGraph/EmissiveReference.swift` — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F07.host.json (swift test exit 0; EmissiveReferenceTests 8)
  (`ToneMapOperator`; `EmissiveReference` functions of contracts/api.md: exact piecewise sRGB, decode not clamped
  above 1; Rec. 709 luminance; quadratic soft-knee prefilter; none/Reinhard/filmic tone maps clamped to 0…1;
  composite; premultiplied over) with
  `Packages/VisualCore/Tests/VisualCoreEffectsGraphTests/EmissiveReferenceTests.swift` (round trip of 256 values;
  prefilter zero below `threshold − knee·threshold`, continuous at both knee ends; tone maps monotonic and below 1 for
  0…64; premultiplied over formula)
- [X] T-R02F07-003 [P] Modify `Packages/VisualCore/Sources/VisualCoreEffectsGraph/PassSchemas.swift` (`emissive` with — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F07.host.json (exit 0; EmissiveSchemaTests 7; RenderStateTests premultipliedBlended; as built: NaN refused on every pass, out-of-range refused for emissive only, composite mode 3 clamps)
  `threshold` 0…16 default 1, `knee` 0…1 0.5, `intensity` 0…4 1, `radius` 1…16 4, `quality` 0…1 0, `exposure` −4…4 0,
  `tonemap` 0…2 0; `composite.mode` 0…2; `flashLimit.linear` 0…1 default 0; memory estimate counting the output and
  two blur targets) and `Packages/VisualCore/Sources/VisualCoreShaderSource/RenderState.swift`
  (`premultipliedBlended`), with `Packages/VisualCore/Tests/VisualCoreEffectsGraphTests/EmissiveSchemaTests.swift`
  (defaults, ranges, out-of-range and non-finite refused by the validator, estimate, existing schemas unchanged)
- [ ] T-R02F07-004 Host checkpoint: `--name host -- swift test --package-path Packages/VisualCore`

## Phase 3: Stories 1, 2 and 4 — the pass (P1) 🎯

- [ ] T-R02F07-005 [US1] [US2] [US4] Modify `Packages/VisualCoreRendering/Sources/VisualCoreEffects/EffectShaders.swift`
  (emissive prefilter, blur and composite programs with a local unclamped decode; composite mode 2; limiter linear
  luma), `EffectPasses.swift` (`EmissivePass`: blur targets `max(1, side/2)` or `max(1, side/4)` from the pool, half
  float via `FloatRenderSupport` else rgba8 with one `ResourceRegistry.warn`, internal `forceStandardPrecision`;
  composite mode 2; limiter `linear`), `EffectRenderer.swift` (`emissive` case) and `EffectScene.swift` (limiter
  `linear` = 1 only when the graph contains an emissive pass); tests in
  `Packages/VisualCoreRendering/Tests/VisualCoreEffectsTests/EmissivePassTests.swift`: below threshold equals input
  within 1/255 (tonemap 0, exposure 0; analyze U1); bright point glow vs reference within 2/255 (high precision) and 4/255 (forced standard); tone-mapped
  values above 1 on the high path below 1 and matching each operator within 2/255; blur target sizes for 512² (256²,
  128²) and 3 × 1 (1 × 1); 100 frames keep the pool count constant; premultiplied composite equals the formula within
  1/255 and the preset draws the same; 30 Hz strobe through a graph with the pass bounded by the limiter when reduced,
  following the input when not; a context rebuild gives the same output; existing bloom, composite and limiter tests
  unchanged
- [ ] T-R02F07-006 Simulator runs: `--name rendering-27` and `--name rendering-26` (the VisualCoreRendering scheme on
  sim-27.2 and sim-26.5)

## Phase 4: Regression, documentation and close

- [ ] T-R02F07-007 No Stage One breakage: `--name experiences --` ExperiencesCreative on sim-27.2
- [ ] T-R02F07-008 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; sections in `Packages/VisualCore/README.md`,
  `Packages/VisualCoreRendering/README.md`, `docs/architecture/shaders.md` (emissive section); section 13.4 row R02-F07
  "As built" in `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [ ] T-R02F07-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F07-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F07-011 Script tests (`--name script-tests`)
- [ ] T-R02F07-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  R02-F07; README.md and `docs/automatedtesting.md`

## Dependencies

001 → {002, 003} → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011 → 012.

## Parallel examples

- **Agent R:** 002, 003 (pure). **Agent G:** 005 after 004. **Lead:** 001, 004, 006–012.
