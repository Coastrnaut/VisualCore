# Effects Composer — regression baseline (A25-P00, feature 179)

- **Phase start:** `a2d68e21` (the `speckit-specify: A25-P00` commit, after the A25 constitution commit `eec911ea`,
  version 2.21.0). The no-change proof of Phase 00 is `git diff --exit-code --stat a2d68e21..HEAD -- Packages External`.
- **Reference pin:** `External/projectm-ios` at `d93edd1`.

## ProjectM reference regression (7 steps, two chunks)

| Step | Command | Result |
|---|---|---|
| 1 `reference-engine-xcframework` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | pass (2026-11-19) |
| 2 `reference-build-projectm-ios-sim` | same chunk | pass (2026-11-19) |
| 3 `reference-clean` | same chunk | pass (2026-11-19) — `.autonomy/checks/A25-P00.reference-1.json` |
| 4 `reference-test-anglerendering-ios27` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | pass (2026-11-19) |
| 5 `reference-test-anglerendering-ios26` | same chunk | pass (2026-11-19) |
| 6 `projectm-reference-ios27` | same chunk | pass (2026-11-19) |
| 7 `projectm-reference-ios26` | same chunk | pass (2026-11-19) — `.autonomy/checks/A25-P00.reference-2.json` |

All 7 steps pass (2026-11-19) before any Effects Composer work.
