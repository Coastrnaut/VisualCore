# Simulation Lab — regression baseline (A16-P00, feature 116)

- **Phase start:** `1006181f` (the `speckit-specify: A16-P00` commit, after the A16 constitution commit `f2d45f77`).
  The no-change proof of Phase 00 is `git diff --exit-code --stat 1006181f..HEAD -- Packages External`.
- **Reference pin:** `External/projectm-ios` at `d93edd1`.

## ProjectM reference regression (7 steps, two chunks)

| Step | Command | Result |
|---|---|---|
| 1 `reference-engine-xcframework` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | pass (2026-11-16) |
| 2 `reference-build-projectm-ios-sim` | same chunk | pass (2026-11-16) |
| 3 `reference-clean` | same chunk | pass (2026-11-16) — `.autonomy/checks/A16-P00.reference-1.json` |
| 4 `reference-test-anglerendering-ios27` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | pass (2026-11-16) |
| 5 `reference-test-anglerendering-ios26` | same chunk | pass (2026-11-16) |
| 6 `projectm-reference-ios27` | same chunk | pass (2026-11-16) |
| 7 `projectm-reference-ios26` | same chunk | pass (2026-11-16) — `.autonomy/checks/A16-P00.reference-2.json` |

Results are pass (2026-11-16) (`.autonomy/checks/A16-P00.reference-1.json` and `reference-2.json`) before any Simulation
Lab work.
