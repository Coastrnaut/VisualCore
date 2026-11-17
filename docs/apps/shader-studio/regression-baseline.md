# Shader Studio — regression baseline (A22-P00, feature 158)

- **Phase start:** `6218b9a1` (the `speckit-specify: A22-P00` commit, after the A22 constitution commit `27d7d83e`; amended to 2.18.1 in `0577dcb0`).
  The no-change proof of Phase 00 is `git diff --exit-code --stat 6218b9a1..HEAD -- Packages External`.
- **Reference pin:** `External/projectm-ios` at `d93edd1`.

## ProjectM reference regression (7 steps, two chunks)

| Step | Command | Result |
|---|---|---|
| 1 `reference-engine-xcframework` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | pass (2026-11-17) |
| 2 `reference-build-projectm-ios-sim` | same chunk | pass (2026-11-17) |
| 3 `reference-clean` | same chunk | pass (2026-11-17) — `.autonomy/checks/A22-P00.reference-1.json` |
| 4 `reference-test-anglerendering-ios27` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | pass (2026-11-17) |
| 5 `reference-test-anglerendering-ios26` | same chunk | pass (2026-11-17) |
| 6 `projectm-reference-ios27` | same chunk | pass (2026-11-17) |
| 7 `projectm-reference-ios26` | same chunk | pass (2026-11-17) — `.autonomy/checks/A22-P00.reference-2.json` |

All 7 steps pass (2026-11-17) before any Shader Studio work.
