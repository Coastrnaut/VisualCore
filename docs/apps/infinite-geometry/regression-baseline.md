# Infinite Geometry — regression baseline (A05-P00, feature 039)

- **Phase start:** `427eea32` (the A05 `speckit-constitution` commit, before any A05 file). The no-change proof of
  Phase 00 is `git diff --exit-code --stat 427eea32..HEAD -- Packages External`.
- **Reference pin:** `External/projectm-ios` at `d93edd1`.

## ProjectM reference regression (7 steps, two chunks)

| Step | Command | Result |
|---|---|---|
| 1 `reference-engine-xcframework` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | pass (19.5 s) |
| 2 `reference-build-projectm-ios-sim` | same chunk | pass (3.4 s) |
| 3 `reference-clean` | same chunk | pass (4.7 s) — `.autonomy/checks/A05-P00.reference-1.json` |
| 4 `reference-test-anglerendering-ios27` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | pass (4.8 s) |
| 5 `reference-test-anglerendering-ios26` | same chunk | pass (4.4 s) |
| 6 `projectm-reference-ios27` | same chunk | pass (10.3 s) |
| 7 `projectm-reference-ios26` | same chunk | pass (6.1 s) — `.autonomy/checks/A05-P00.reference-2.json` |

Recorded 2026-11-13: 7 of 7 steps pass before any Infinite Geometry work.
