# Data Model: A23-P05 (feature 170)

- **LabLevel** (tests): `liveCount` by kind name and `totalBytes` of `ResourceRegistry.stats`; equality and a change
  description.
- **Device plan row:** `VPL-Dn`, devices (D1, D2, D3), steps, expected result, owner actions, state `pending`.
- No stored data changes.
- **As built (A23-P05):**
  - the stress comparison: the three examples hold 1, 2 and 3 slots, so each cycle's level is compared with the first
    cycle showing the same example (cycle 49 with cycle 1, cycle 50 with cycle 2), with `leaked` 0 after every cycle;
    `LabLevel` is declared in `StressCycleTests.swift`;
  - `PreviewPipeline` notes the programs and slots it holds on release (`held`) and rebuilds them on restore in every
    state but failed, so a rebuild keeps the level in the invalid and refused states too.
