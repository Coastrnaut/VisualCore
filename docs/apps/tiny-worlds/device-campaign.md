# Tiny Worlds — device campaign plan (A12-P05, feature 093)

These measurements need real devices and run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3. Until then every row is pending; no performance, thermal, memory or latency number is claimed anywhere.
Simulator results never stand in for these rows. Every row is a {device} task (T-A12-509).

| Row | Measurement | Device | Procedure | Threshold | Status |
|---|---|---|---|---|---|
| TW-D1 | Frame pacing per detail tier | reference iPhone, reference iPad | Open each of the three world packs with 24 placed props; hold the tier at level-0, level-1 and level-2 in turn and orbit continuously for 60 s at each; record frame intervals (Instruments, Animation Hitches) | ≥ 95 % of frames on time at level-0 on the phone; a lower tier never paces worse than a higher one | pending device campaign |
| TW-D2 | Thermal state over 10 minutes | reference iPhone | The miniature city pack with 24 props, continuous orbit and zoom for 10 minutes; log `ProcessInfo.thermalState` and the drawn tier each 30 s | never `.critical`; the session's quality governor lowers the tier before `.serious` is held | pending device campaign |
| TW-D3 | Memory high-water mark across pack switches | reference iPhone, reference iPad | Cycle the three packs 20 times, saving and reopening a slot each cycle; record the physical footprint high-water mark (Instruments, Allocations and VM Tracker) and send one simulated memory warning mid-run | the footprint after cycle 20 within 5 % of cycle 1; the memory warning draws level-2 on the next frame and the terrain rebuilds once | pending device campaign |
| TW-D4 | Touch latency of orbit and place | reference iPhone | Drag to orbit and tap to place a prop, filmed with a high-speed camera; measure finger-to-view lag and tap-to-prop lag | median orbit lag ≤ 50 ms; the prop appears within 3 frames of the tap | pending device campaign |
| TW-D5 | Accessibility system audits and Dynamic Type | reference iPhone, reference iPad | The system accessibility audits at the default and the largest text size with `VC_RUN_AUDITS=1` (owner ruling of 2026-11-13), over each pack, the prop editor, the light controls and the saved-world slots; a VoiceOver pass over every control | no audit issue in the Tiny Worlds screens; every control labelled, operable and readable at the largest size | pending device campaign |
