# Physics Playground — regression baseline (A11-P00, feature 081)

- **Phase start:** `d3797d7c` (the `speckit-specify: A11-P00` commit, after the A11 constitution commit `35c24d86`).
  The no-change proof of Phase 00 is `git diff --exit-code --stat d3797d7c..HEAD -- Packages External`.
- **Reference pin:** `External/projectm-ios` at `d93edd1`.

## ProjectM reference regression (7 steps, two chunks)

| Step | Command | Result |
|---|---|---|
| 1 `reference-engine-xcframework` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | pass (2026-11-15) |
| 2 `reference-build-projectm-ios-sim` | same chunk | pass (2026-11-15) |
| 3 `reference-clean` | same chunk | pass (2026-11-15) — `.autonomy/checks/A11-P00.reference-1.json` |
| 4 `reference-test-anglerendering-ios27` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | pass (2026-11-15) |
| 5 `reference-test-anglerendering-ios26` | same chunk | pass (2026-11-15) |
| 6 `projectm-reference-ios27` | same chunk | pass (2026-11-15) |
| 7 `projectm-reference-ios26` | same chunk | pass (2026-11-15) — `.autonomy/checks/A11-P00.reference-2.json` |

Results are pass (2026-11-15) (`.autonomy/checks/A11-P00.reference-1.json` and `reference-2.json`) before any Physics
Playground work.
