# Tasks: R02-F14 — Deterministic timeline and reversible history

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F14 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F14 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks. New public names checked against Packages and Apps (`RunDocument` was taken, so the
document is `TimelineRunDocument`). Fixture seed 2_014; tests stay light.

## Phase 1: Setup

- [X] T-R02F14-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore`; the rendering — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F14.baseline-host.json (exit 0); rendering baseline = R02-F13.rendering-27.json and rendering-26.json (exit 0) at 83d7b5ff, package sources unchanged since
  baseline is R02-F13's last rendering runs when package sources are unchanged since them

## Phase 2: Foundational

- [X] T-R02F14-002 [P] Create `Packages/VisualCore/Sources/VisualCoreSimulation/TimelineError.swift` (cases and `r2-f14.*` codes of clarification Q5), `Packages/VisualCore/Sources/VisualCoreSimulation/EventLog.swift` — Verified 2026-11-19: lead retest 2026-11-19: R02-F14.host.json (exit 0, 0 failures; VisualCoreSimulation 216 tests incl. EventLog 5, SnapshotRing 4, ReplayHash 3 with a pinned known-answer)
  ("steps 0 … 10,000,000", "at most 1,048,576" commands; insert appends at its step; remove/replace by (step, index);
  stable order), `Packages/VisualCore/Sources/VisualCoreSimulation/SnapshotRing.swift` ("capacity 1…1,024, default 32", "interval 1…65,536, default 64", oldest
  dropped first, `latest(atOrBefore:)`, `drop(after:)`) and `Packages/VisualCore/Sources/VisualCoreSimulation/ReplayHash.swift` (research R3: SHA-256 of
  "vc.replay.v1" ‖ checksum₀ LE, then of hₙ₋₁ ‖ n LE ‖ checksumₙ LE; `hex`, `init?(hex:)`, Codable) with
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/EventLogTests.swift`, `SnapshotRingTests.swift` and `ReplayHashTests.swift` (ordering, limits and refusals;
  ring drop order; hash known-answer for a fixed sequence, chaining, sensitivity to one changed checksum);
  `--name host`

## Phase 3: Stories 1–3 — rewind, edit, prove (P1) 🎯

- [X] T-R02F14-003 [US1] [US2] [US3] Create `Packages/VisualCore/Sources/VisualCoreSimulation/ReversibleTimeline.swift` (contracts/api.md; commands at step s applied in — Verified 2026-11-19: lead retest 2026-11-19: R02-F14.host.json (exit 0; ReversibleTimelineTests 9 passed: 200 seeks = fresh run, 50 edits = fresh edited run, 100/100 command changes alter the hash, ring of 4 exact with ≤ 63 replayed steps, non-determinism caught; research R6)
  insertion order before s → s + 1; snapshot every `interval` steps with its hash; `seek(to:)` per clarification Q3;
  edits per research R4; refusals) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/ReversibleTimelineTests.swift` (a small value-type test simulation (a
  seeded particle-like state with a deterministic checksum) run to 1,000 steps with 100 seeded commands: 200 seeded
  seeks equal fresh runs, seeking back to 1,000 gives the original checksum and hash; 50 seeded edits: every later step
  equals a fresh run of the edited log and earlier steps unchanged; identical runs equal hashes, each of 100 single
  command changes changes the hash; rewind-and-replay hash equals straight-run hash; ring of 4 snapshots still exact and
  each seek replays at most interval − 1 steps from a kept snapshot (count the replayed steps through an internal
  counter); negative and too-large steps refused; a deliberately non-deterministic test simulation is reported as
  `hashMismatch` on seek and the timeline unchanged); `--name host-2`

## Phase 4: Story 4 — save and migrate (P2)

- [X] T-R02F14-004 [US4] Create `Packages/VisualCore/Sources/VisualCoreExperience/TimelineRunDocument.swift` (schema 1 JSON, — Verified 2026-11-19: lead retest 2026-11-19: R02-F14.host-2.json (exit 0, 0 failures; TimelineRunDocumentTests 8 passed: byte-identical round trip, schema 0 migrates to the same hash, schema 2, tampered command hashMismatch, truncated, missing schema, log over limit, step beyond limit)
  sorted keys; `MigrationChain` step from schema 0 (log as [step, command] pairs); decode replays and verifies the hash;
  refusals) with `Packages/VisualCore/Tests/VisualCoreExperienceTests/TimelineRunDocumentTests.swift` (at least five
  fixtures: round trip byte for byte; a schema-0 example migrates to the same hash; schema 2 refused; a tampered command
  refused `hashMismatch`; truncated JSON refused `malformed`; a log over its limit refused); `--name host-3`

## Phase 5: Regression, documentation and close

- [X] T-R02F14-005 No Stage One breakage: `--name rendering-27`, `--name rendering-26` and `--name experiences` — Verified 2026-11-19: 2026-11-19 R02-F14.rendering-27.json, rendering-26.json and experiences.json (exit 0 each)
- [X] T-R02F14-006 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-19: 2026-11-19 R02-F14.public-api.json and R02-F14.documented-api.json (exit 0; 3513 declarations, 0 undocumented); docs/architecture/reversible-timeline.md and determinism.md §11; README section and section 13.4 note rendered; validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/reversible-timeline.md`;
  section in `Packages/VisualCore/README.md`; section 13.4 row R02-F14 "As built" in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`; `docs/architecture/determinism.md` note
- [X] T-R02F14-007 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F14.reference-1.json (exit 0)
- [X] T-R02F14-008 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F14.reference-2.json (exit 0)
- [X] T-R02F14-009 Script tests (`--name script-tests`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F14.script-tests.json (exit 0)
- [X] T-R02F14-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-19: converged in 1 round (no task appended); sealed .autonomy/migration/evidence/R02-F14.json (11 passing); recorded pass 2026-11-19; T-R02F14-011 {device} waits for the device campaign

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F14-011 {device} Measure the seek time of a 100,000-step run on D1–D3 and record it in the device campaign;
  never before `guard-device` passes

## Dependencies and parallel work

001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010. Agents: A (002), B (003 after 002), C (004 after 003). Shared
files stay with the lead. MVP: Stories 1–3.
