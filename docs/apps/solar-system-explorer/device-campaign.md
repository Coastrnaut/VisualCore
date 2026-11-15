# Solar System Explorer — device campaign plan (A14-P05, feature 107)

These measurements need real devices and run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3. Until then every row is pending; no pacing, thermal, memory or accessibility number is claimed anywhere.
Simulator results never stand in for these rows. Every row is a {device} task (T-A14-505; FR-A14-511). Solar System
Explorer has two drawing levels: `level-0` (spheres 48 × 24, 400 stars, orbits of 128 samples) and `level-1` (24 × 12,
200 stars, 64 samples).

| Row | Measurement | Device | Procedure | Threshold | Status |
|---|---|---|---|---|---|
| SSE-D1 | Frame time at level 0 | D1 reference iPhone (iOS 27) | Overview, then the Giant planets tour, then playing at 1 year/s with orbit and zoom steps, 60 s in all, in each scale mode; record frame intervals (Instruments, Animation Hitches) | 95th-percentile frame time at most 16.7 ms; no hitch on a focus flight or a scale switch | pending device campaign |
| SSE-D2 | The drop to level 1 | D1 reference iPhone | Repeat SSE-D1 with Low Power Mode on, then until `ProcessInfo.thermalState` reaches `.serious` (logged every 30 s, at most 10 minutes) | the experience reports `level-1` within one quality check of Low Power Mode or `.serious`; positions, labels and state unchanged across the switch | pending device campaign |
| SSE-D3 | Peak memory | D1 reference iPhone, D2 and D3 reference iPads | Open the experience, run both tours, switch scale modes and levels, save and restore the view, leave and reopen five times; record the footprint high-water mark (Instruments, Allocations and VM Tracker) and send one simulated memory warning | peak at most 300 MB; the footprint after cycle 5 within 5 out of every 100 parts of cycle 1 | pending device campaign |
| SSE-D4 | System accessibility audits | D1 reference iPhone, D2 and D3 reference iPads | The system accessibility audits with `VC_RUN_AUDITS=1` (owner ruling of 2026-11-13) at the default and the largest text size, with a tour running and paused | no audit issue in the Solar System Explorer screens | pending device campaign |
| SSE-D5 | VoiceOver reading | D1 reference iPhone | A VoiceOver pass over every control, the model statement ("About this model"), the canvas description with the date, time, distance and scale label, the tour captions and the stop at a range end | every control labelled with a value; the model statement, captions and the not-to-scale label heard in words; date announcements while playing no more often than every 10 s | pending device campaign |
| SSE-D6 | Dynamic Type and Reduce Motion | D1 reference iPhone, D2 reference iPad | The largest accessibility text size over all controls; Reduce Motion on and off while focusing bodies and during both tours | every control readable and operable at the largest size; with Reduce Motion each focus and tour stop cuts in one frame; without it flights last 30 frames | pending device campaign |
