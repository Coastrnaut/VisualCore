# Audio Odyssey — regression baseline (A07-P00, feature 053)

- **Phase start:** `b5c919b4` (the `A07-P00 specify` commit, after the A07 constitution commit `fcf6ad46`; found with
  `git log --format=%h -1 --grep="A07-P00 specify"`). The no-change proof of Phase 00 is
  `git diff --exit-code --stat b5c919b4..HEAD -- Packages External`.
- **Reference pin:** `External/projectm-ios` at `d93edd1`.

## ProjectM reference regression (7 steps, two chunks)

| Step | Command | Result |
|---|---|---|
| 1 `reference-engine-xcframework` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | pass (2026-11-14) |
| 2 `reference-build-projectm-ios-sim` | same chunk | pass (2026-11-14) |
| 3 `reference-clean` | same chunk | pass (2026-11-14) — `.autonomy/checks/A07-P00.reference-1.json` |
| 4 `reference-test-anglerendering-ios27` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | pass (2026-11-14) |
| 5 `reference-test-anglerendering-ios26` | same chunk | pass (2026-11-14) |
| 6 `projectm-reference-ios27` | same chunk | pass (2026-11-14) |
| 7 `projectm-reference-ios26` | same chunk | pass (2026-11-14) — `.autonomy/checks/A07-P00.reference-2.json` |

Results are pass (2026-11-14) (`.autonomy/checks/A07-P00.reference-1.json` and
`reference-2.json`) before any Audio Odyssey work.
