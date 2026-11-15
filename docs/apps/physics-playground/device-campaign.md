# Physics Playground — device campaign plan (A11-P05, feature 086)

These measurements need real devices and run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3. Until then every row is pending; no performance, thermal or latency number is claimed anywhere.
Simulator results never stand in for these rows.

| Row | Measurement | Device | Procedure | Threshold | Status |
|---|---|---|---|---|---|
| PP-D1 | Frame pacing per quality level | reference iPhone, reference iPad | Open the stacked-objects preset and free play filled to 48 bodies by drops; record frame intervals for 60 s at each of levels 0, 1 and 2 (Instruments, Animation Hitches) | ≥ 95 % of frames on time at level 0 on the phone; level 2 never worse than level 0 | pending device campaign |
| PP-D2 | Thermal state over 10 minutes | reference iPhone | Free play at 48 bodies with 16 springs at the highest stiffness, force arrows on, 10 minutes; log `ProcessInfo.thermalState` each 30 s | never `.serious` or above; the session's quality governor steps down before `.serious` | pending device campaign |
| PP-D3 | Touch latency for grab | reference iPhone | Drag a box across the stage with a high-speed camera at 240 fps; measure finger-to-body lag | median ≤ 50 ms | pending device campaign |
| PP-D4 | VoiceOver pass | reference iPhone | Every control (presets, slots, tutorials, editing, overlays, time) reachable and labelled; the spoken description and tutorial steps announced | 100 % of controls labelled and operable | pending device campaign |
