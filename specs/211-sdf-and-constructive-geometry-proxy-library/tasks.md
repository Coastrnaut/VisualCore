# Tasks: R02-F11 — SDF and constructive geometry proxy library

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F11 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F11 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks. All new public names start with `SDF` (checked against Packages and Apps). Fixture
seed 2_011.

## Phase 1: Setup

- [X] T-R02F11-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore`; the rendering — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F11.baseline-host.json (exit 0); rendering baseline = R02-F10.rendering-27-2.json and rendering-26-2.json (exit 0) at 71b90e4f, package sources unchanged since
  baseline is R02-F10's last rendering run when package sources are unchanged since it (no rerun on an unchanged commit)

## Phase 2: Foundational — the description (P1) 🎯

- [X] T-R02F11-002 [US1] Create `Packages/VisualCore/Sources/VisualCoreScenes/SDFError.swift` (`nonFinite(String)`, — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F11.host.json (exit 0; swift test --filter SDFShapeTests: 7 tests passed — closed forms at 1,000 points within 1e-12, set operations, transforms, normals, refusals, node and depth limits, finite at |p| ≤ 1e6)
  `nonPositive(String)`, `zeroDirection(String)`, `notUnitRotation`, `tooManyNodes(Int)`, `tooDeep(Int)`,
  `unknownKind(String)`, `newerSchema(Int)`, `malformed(String)`; `reasonCode` `r2-f11.*` as in the spec) and
  `SDFShape.swift` (the indirect enum of data-model.md; validating makers that throw `SDFError` — sizes and radii
  "finite and > 0", plane normal "non-zero length, normalised", rounded-box radius ≤ min half extent, torus minor <
  major, rotation "|q| = 1 within 1e-9", scale > 0, smoothing radius "finite and ≥ 0", union/intersection "1…32
  children", "at most 256 nodes and depth 32"; `nodeCount`, `depth`, `distance(at:)` exact per research R2,
  `normal(at:)` per R3, `contains(_:)`) with `Packages/VisualCore/Tests/VisualCoreScenesTests/SDFShapeTests.swift`
  (1,000 seeded points per primitive against closed forms within 1e-12; union/intersection/subtraction definitions;
  smooth union ≤ hard union and equal at k = 0; transforms: translated sphere, rotated box, scaled sphere distance
  scaling; normals of a sphere and a plane within 1e-6; every refusal with its reason code; |p| ≤ 1e6 and sizes ≥ 1e-6
  give finite results; the fallback normal at a zero gradient); `--name host`
- [ ] T-R02F11-003 [P] [US4] Create `Packages/VisualCore/Sources/VisualCoreScenes/SDFCoding.swift` (`SDFDocument`,
  schema 1 JSON `{"schema":1,"shape":{…}}` with `kind` tags; decode re-validates through the makers; refusals
  `unknownKind`, `newerSchema`, `malformed`) with `SDFCodingTests.swift` (at least five fixtures: a valid nested shape
  round-trips byte for byte; schema 2 refused; unknown kind refused; negative radius in the data refused with
  `nonPositive`; truncated JSON refused with `malformed`; 257 nodes refused); `--name host`

## Phase 3: Story 2 — the march (P1)

- [ ] T-R02F11-004 [P] [US2] Create `Packages/VisualCore/Sources/VisualCoreScenes/SDFMarch.swift` (`SDFMarchOptions`
  "maxSteps 1…4,096 (128), maxDistance > 0 (100), tolerance > 0 (1e-7)" and `static let standard` (the defaults), `mode` conservative ω = 1 or fast ω = 1.6
  with the Keinert overlap fallback; hit when d < tolerance·max(1, t); origin inside → hit at 0 with `startedInside`;
  outcomes hit, miss, budgetExhausted) with `SDFMarchTests.swift` (1,000 seeded rays against a sphere and a box equal
  `Ray3.intersect` within 1e-6, normals within 1e-4, both modes; a 1e-3 shell hit by both modes on 100 seeded rays while
  a test-only ω = 1.6 march without fallback skips it at least once; a too-small budget reports `budgetExhausted`; a ray
  pointing away reports `miss`; the fast mode takes fewer steps on average than the conservative); `--name host`

## Phase 4: Story 3 — volume (P2)

- [ ] T-R02F11-005 [P] [US3] Create `Packages/VisualCore/Sources/VisualCoreScenes/SDFVolume.swift` (`SDFVolumeSample`;
  `sample(_:boundsMin:boundsMax:resolution:)` with "1 ≤ n ≤ 256" and min < max per axis, cell centres, volume = count ×
  cell volume, FNV-1a 64 digest of the packed inside bits in x, y, z order) with `SDFVolumeTests.swift` (sphere and box
  within 2% at 64³; error at 64³ at most half the error at 32³; same digest twice; resolution 0 and 257 and inverted
  bounds refused); `--name host`

## Phase 5: Story 1 — the shader (P1)

- [ ] T-R02F11-006 [US1] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/sdfshape.glsl`
  (`vc_sdPlane`, `vc_sdRoundBox`, `vc_sdCapsule`, `vc_opUnion`, `vc_opIntersect`, `vc_opSubtract`, `vc_opSmoothUnion`,
  include guard) and `Packages/VisualCore/Sources/VisualCoreScenes/SDFShaderSource.swift` (`glslFunction(name:)` per
  research R7) with `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SDFShaderParityTests.swift` (a slice
  image of three descriptions encoded 0.5 + d/8 equals the CPU within 2/255 at every pixel; a marched view's hit mask
  equals `SDFMarch` at every pixel whose 3 × 3 CPU neighbourhood is uniform; the generated source compiles through
  `ResourceRegistry.program` on the real context; zero leaks after destroy); the lead adds `vc/sdfshape.glsl` to the
  include list of `ShaderBundleTests.swift`
- [ ] T-R02F11-007 Simulator runs: `--name rendering-27` and `--name rendering-26`

## Phase 6: Regression, documentation and close

- [ ] T-R02F11-008 No Stage One breakage: `--name experiences --` ExperiencesCreative on sim-27.2
- [ ] T-R02F11-009 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/sdf-proxies.md`
  (formulas and sources with licences, the distance-bound rule, march constants, volume sampling, stored form, reason
  codes); sections in `Packages/VisualCore/README.md` and `Packages/VisualCoreRendering/README.md`; section 13.4 row
  R02-F11 "As built" (home: VisualCoreScenes and the shader library, not a new VisualCoreGeometry) in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [ ] T-R02F11-010 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F11-011 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F11-012 Script tests (`--name script-tests`)
- [ ] T-R02F11-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F11-014 {device} Measure the march cost of the largest shape (256 nodes, 128 steps) at full screen on D1–D3
  and record it in the device campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → 002 → (003 ∥ 004 ∥ 005) → 006 → 007 → 008 → 009 → 010 → 011 → 012 → 013. Agents: A (002 then 003), B (004, 005
after 002), G (006 after 002). Shared files (READMEs, API baseline, `ShaderBundleTests.swift`, feature map) stay with the
lead. MVP: Stories 1 and 2 (002, 004, 006).
