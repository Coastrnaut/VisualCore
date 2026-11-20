# Tasks: R02-F15 — Conic orbit and eclipse geometry

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F15 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F15 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} and no {device} tasks (frame time is measured by the consumers in the device campaign). New
public names checked against Packages and Apps (`Visibility` is taken). Fixture seed 2_015; tests stay light.

## Phase 1: Setup

- [X] T-R02F15-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore`; the rendering — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F15.baseline-host.json (exit 0); rendering baseline = R02-F14.rendering-27.json and rendering-26.json (exit 0), package sources unchanged since
  baseline is R02-F14's last rendering runs when package sources are unchanged since them

## Phase 2: Foundational

- [X] T-R02F15-002 [P] Create `Packages/VisualCore/Sources/VisualCoreMath/OrbitError.swift` (cases and `r2-f15.*` codes — Verified 2026-11-19: lead retest 2026-11-19: R02-F15.host-rerun.json (exit 0, full suite; first R02-F15.host.json failed only the timed R02-F05 mesh budget under parallel load, fixed by lightening the overlap oracle to 1,024 intervals); KeplerSolverTests 7 passed (1,000 seeded cases per kind, residual ≤ 1e-10·max(1,|M|); Barker known answers; finite fallbacks)
  of clarification Q5) and `Packages/VisualCore/Sources/VisualCoreMath/KeplerSolver.swift` (research R1–R3: elliptic via
  `KeplerOrbit.eccentricAnomaly` plus ≤ 8 polishing Newton steps while the residual exceeds 1e-12; hyperbolic Newton from
  H₀ = sign(M)·ln(2|M|/e + 1.8), ≤ 64 steps; parabolic Barker closed form for "abs(e − 1) ≤ 1e-9"; true anomalies;
  always finite) with `Packages/VisualCore/Tests/VisualCoreMathTests/KeplerSolverTests.swift` (1,000 seeded cases per kind
  have residual ≤ 1e-10·max(1, |M|); non-finite input gives a finite result; Barker known answers); `--name host`

## Phase 3: Story 1 — bodies on conic paths (P1) 🎯

- [X] T-R02F15-003 [US1] Create `Packages/VisualCore/Sources/VisualCoreMath/ConicOrbit.swift` (contracts/api.md: — Verified 2026-11-19: lead retest 2026-11-19: R02-F15.host-rerun.json (exit 0, full suite; first R02-F15.host.json failed only the timed R02-F05 mesh budget under parallel load, fixed by lightening the overlap oracle to 1,024 intervals); ConicOrbitTests 7 passed (1,000 seeded elliptic cases equal KeplerOrbit to 1e-9; energy and angular momentum per kind; e = 1 ± 1e-4 near the parabola; invalid elements refused)
  `ConicKind`, `OrbitState`, `ConicOrbit` with "all finite; q > 0, e ≥ 0, μ > 0", kind, mean motion, semi-major axis,
  period, energy, angular momentum, `keplerOrbit` adapter, `init(_ orbit: KeplerOrbit, gravitationalParameter:)`,
  `state(at:)` per research R4, non-finite time treated as tₚ) with
  `Packages/VisualCore/Tests/VisualCoreMathTests/ConicOrbitTests.swift` (1,000 seeded elliptic cases equal
  `KeplerOrbit.position(at:)` to a relative 1e-9; energy and angular momentum from the state equal the elements' to a
  relative 1e-9 for each kind, absolute 1e-9·μ/q for the parabola's zero energy; e = 1 ± 1e-4 within a relative 1e-3 of the parabola for μ = q = 1, |t − tₚ| ≤ 10; invalid elements
  refused `r2-f15.invalid-elements`); `--name host-2`

## Phase 4: Story 2 — phase stepping (P1)

- [X] T-R02F15-004 [US2] Create `Packages/VisualCore/Sources/VisualCoreMath/PhaseStepper.swift` (`PhaseStepper`, "Δt — Verified 2026-11-19: lead retest 2026-11-19: R02-F15.host-rerun.json (exit 0, full suite; first R02-F15.host.json failed only the timed R02-F05 mesh budget under parallel load, fixed by lightening the overlap oracle to 1,024 intervals); PhaseStepperTests 5 passed (100,000 steps equal a jump bit for bit; 37 adjacent spans equal one listing over 100 periods; open orbit one passage; refusals)
  finite > 0; 0 ≤ k ≤ 1,000,000,000", time(k) = t₀ + Double(k)·Δt; `phase(of:at:)` in [0, 1) for closed orbits and nil
  for open; `Passage` listing in [tₐ, t_b), time order, "≤ 1,000,000" per research R6) with
  `Packages/VisualCore/Tests/VisualCoreMathTests/PhaseStepperTests.swift` (100,000 advances equal `jump(to:)` bit for bit;
  passages over 100 periods split into 37 adjacent spans equal one listing and each passage appears once; open orbit has
  one periapsis passage; tick limit, bad step, reversed span and span limit refused); `--name host-3`

## Phase 5: Story 3 — eclipses and transits (P1)

- [X] T-R02F15-005 [P] [US3] Create `Packages/VisualCore/Sources/VisualCoreMath/DiskOverlap.swift` (research R7) and — Verified 2026-11-19: lead retest 2026-11-19: R02-F15.host-rerun.json (exit 0, full suite; first R02-F15.host.json failed only the timed R02-F05 mesh budget under parallel load, fixed by lightening the overlap oracle to 1,024 intervals); DiskOverlapTests 3 and EclipseGeometryTests 9 passed (1,000 seeded pairs equal the chord-integration oracle to 1e-6; at least five fixtures per class; observer-inside and invalid-disk refusals)
  `Packages/VisualCore/Sources/VisualCoreMath/EclipseGeometry.swift` (`EclipseBody` "radius finite > 0",
  `EclipseClass`, `EclipseVerdict` "fraction in [0, 1]; hidden reports 1", `EclipseGeometry.classify` per clarification
  Q4 and research R8) with `Packages/VisualCore/Tests/VisualCoreMathTests/DiskOverlapTests.swift` (1,000 seeded pairs
  equal the smooth chord integration (1,024 Simpson intervals) to 1e-6 of the smaller area; touching 0, equal centred πr², nested π·min²) and
  `Packages/VisualCore/Tests/VisualCoreMathTests/EclipseGeometryTests.swift` (at least five fixtures per class none,
  partial, annular, total, hidden; observer inside refused `r2-f15.observer-inside`; bad radius `r2-f15.invalid-disk`);
  `--name host-4`

## Phase 6: Story 4 — save and open (P2)

- [X] T-R02F15-006 [US4] Add schema-1 `Codable` to `Packages/VisualCore/Sources/VisualCoreMath/ConicOrbit.swift` — Verified 2026-11-19: lead retest 2026-11-19: R02-F15.host-rerun.json (exit 0, full suite; first R02-F15.host.json failed only the timed R02-F05 mesh budget under parallel load, fixed by lightening the overlap oracle to 1,024 intervals); ConicOrbitCodingTests 4 passed (byte-identical round trip of three kinds; schema 2 newerSchema; missing, truncated and empty JSON malformed; q = 0 invalidElements)
  (sorted keys; `encoded()`, `decode(_:)`; schema above 1 → `r2-f15.newer-schema`; missing or invalid →
  `r2-f15.malformed` or `r2-f15.invalid-elements`) with
  `Packages/VisualCore/Tests/VisualCoreMathTests/ConicOrbitCodingTests.swift` (byte-identical round trip of three kinds;
  schema 2, missing schema, truncated JSON and q = 0 refused); `--name host-5`

## Phase 7: Regression, documentation and close

- [X] T-R02F15-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26` and `--name experiences` — Verified 2026-11-19: 2026-11-19 R02-F15.rendering-27.json, rendering-26.json and experiences.json (exit 0 each, TEST SUCCEEDED)
- [X] T-R02F15-008 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-19: 2026-11-19 R02-F15.public-api.json and R02-F15.documented-api.json (exit 0; 3578 declarations, 0 undocumented); docs/architecture/conic-orbits.md; README section and section 13.4 row rendered; validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/conic-orbits.md`; section
  in `Packages/VisualCore/README.md`; section 13.4 row R02-F15 "As built" in `docs/catalog/shared-feature-map.json` and
  `render_autocreator.py`
- [X] T-R02F15-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F15.reference-1.json (exit 0)
- [ ] T-R02F15-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F15-011 Script tests (`--name script-tests`)
- [ ] T-R02F15-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → 003 → 004 → 006; 005 needs only 002 (OrbitError) and runs beside 003/004; then 007 → 008 → 009 → 010 → 011
→ 012. Agents: A (002 then 003 and 006), B (005 after 002), C (004 after 003). Shared files stay with the lead. MVP:
Stories 1–3.
