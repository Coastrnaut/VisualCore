# Light Maze — regression baseline (A13-P00, feature 095)

- **Phase start:** `57a587f9` (the `speckit-specify: A13-P00` commit, after the A13 constitution commit `d5d232b6`).
  The no-change proof of Phase 00 is `git diff --exit-code --stat 57a587f9..HEAD -- Packages External`.
- **Reference pin:** `External/projectm-ios` at `d93edd1`.

## ProjectM reference regression (7 steps, two chunks)

| Step | Command | Result |
|---|---|---|
| 1 `reference-engine-xcframework` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | pass (2026-11-15) |
| 2 `reference-build-projectm-ios-sim` | same chunk | pass (2026-11-15) |
| 3 `reference-clean` | same chunk | pass (2026-11-15) — `.autonomy/checks/A13-P00.reference-1.json` |
| 4 `reference-test-anglerendering-ios27` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | pass (2026-11-15) |
| 5 `reference-test-anglerendering-ios26` | same chunk | pass (2026-11-15) |
| 6 `projectm-reference-ios27` | same chunk | pass (2026-11-15) |
| 7 `projectm-reference-ios26` | same chunk | pass (2026-11-15) — `.autonomy/checks/A13-P00.reference-2.json` |

Results are pass (2026-11-15) (`.autonomy/checks/A13-P00.reference-1.json` and `reference-2.json`) before any Light
Maze work.
