# Visual Programming Lab — regression baseline (A23-P00, feature 165)

- **Phase start:** `7b64fedf` (the `speckit-specify: A23-P00` commit, after the A23 constitution commit `0a9405b5`,
  version 2.19.0). The no-change proof of Phase 00 is `git diff --exit-code --stat 7b64fedf..HEAD -- Packages External`.
- **Reference pin:** `External/projectm-ios` at `d93edd1`.

## ProjectM reference regression (7 steps, two chunks)

| Step | Command | Result |
|---|---|---|
| 1 `reference-engine-xcframework` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | pass (2026-11-18) |
| 2 `reference-build-projectm-ios-sim` | same chunk | pass (2026-11-18) |
| 3 `reference-clean` | same chunk | pass (2026-11-18) — `.autonomy/checks/A23-P00.reference-1.json` |
| 4 `reference-test-anglerendering-ios27` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | pass (2026-11-18) |
| 5 `reference-test-anglerendering-ios26` | same chunk | pass (2026-11-18) |
| 6 `projectm-reference-ios27` | same chunk | pass (2026-11-18) |
| 7 `projectm-reference-ios26` | same chunk | pass (2026-11-18) — `.autonomy/checks/A23-P00.reference-2.json` |

All 7 steps pass (2026-11-18) before any Visual Programming Lab work.
