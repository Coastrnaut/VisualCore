# Interactive Anatomy — device campaign plan (A17-P05, feature 128)

These measurements need real devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3. Until then every row is pending, and no pacing, thermal, memory or accessibility number is claimed
anywhere. Simulator results never stand in for these rows. Every row is a {device} task (FR-A17-507).

Interactive Anatomy has two drawing levels, `level-0` and `level-1` (`Catalog/registrations.json`):

| Level | Triangles | Draws |
|---|---|---|
| `level-0` | 6,444 | 20 |
| `level-1` | 2,716 | 20 |

Labels are capped at 16, and ghosts use the additive translucent stage of the depth pass.

| Row | Measurement | Device | Procedure | Threshold | Status |
|---|---|---|---|---|---|
| IA-D1 | Frame pacing at both levels | D1 reference iPhone (iOS 27), D2 and D3 reference iPads | Pin each level in turn. Orbit by drag for 30 s, pinch zoom for 15 s, then isolate the bones in the ghost mode and orbit for 30 s. Record frame intervals (Instruments, Animation Hitches). | 95th-percentile frame time at most 16.7 ms at `level-0` on D1; no hitch on a selection, a layer change, an isolate or Show all | pending device campaign |
| IA-D2 | Thermal state over 10 minutes | D1, D2, D3 | Repeat this loop for 10 minutes: orbit, select from the list and by tap, search, isolate, Show all. Log `ProcessInfo.thermalState` every 30 s. | thermal state stays `.nominal` or `.fair`; the quality governor may drop to `level-1` and recovers | pending device campaign |
| IA-D3 | Memory | D1, D2, D3 | During IA-D2, record the footprint high-water mark (Instruments, Allocations and VM Tracker). Leave and reopen the experience five times. | peak at most 200 MB; no growth across the five reopens; the view is restored from `view.json` each time | pending device campaign |
| IA-D4 | VoiceOver with the list alone | D1 reference iPhone | With VoiceOver on and without touching the canvas: find each of the 14 parts in the list and select it, read the panel (names, layer, description, citations, review lines, the model statement), search "ACL", "Kneecap" and "Shin bone", isolate a layer, Show all | every part is reachable and announced "<name> selected."; each row is spoken "<name>, <layer words>"; the panel is read in order; announcements are never closer than 0.5 s apart | pending device campaign |
| IA-D5 | Dynamic Type at the largest size | D1, D2, D3 | Set the largest accessibility text size. Visit the list, search, panel, isolate controls, camera buttons and the About row. | every control readable and operable, text wraps, no hit area below 44 points; in-scene labels may be skipped, and the list still names every part | pending device campaign |
| IA-D6 | Reduce Motion | D1 reference iPhone | With Reduce Motion on, select parts from the list and by tap, reset the view, step the camera | nothing animates; framing and every camera change are immediate | pending device campaign |
| IA-D7 | Accessibility audit | D1, D2, D3 | Run the system accessibility audits (`VC_RUN_AUDITS=1`, owner ruling of 2026-11-13) on the Interactive Anatomy screens at the default and the largest text size | no audit issue in the Interactive Anatomy screens | pending device campaign |
