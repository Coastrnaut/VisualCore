# Ambient Clock — device campaign plan (A18-P05, feature 135)

These measurements need real devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3, and D3 is not updated from iPadOS 26.5. Until then every row is pending, and no pacing, heat, battery,
memory or accessibility number is claimed anywhere. Simulator results never stand in for these rows. Every row is a
{device} task (FR-A18-504).

Ambient Clock draws at most 30 frames per second (`maxFramesPerSecond`, A18-P04). It has two quality levels
(`level-0`, `level-1`) and four themes. A still picture (motion off or reduced, seconds off) is drawn once and reused
(`CachedScene`, A18-P05).

| Row | Measurement | Device | Procedure | Threshold | Status |
|---|---|---|---|---|---|
| AC-D1 | Overnight run on power | D1 reference iPhone (iOS 27), on a stand, charging | Keep-awake on, night mode scheduled 22:00–07:00, each theme for 2 hours (8 hours). Every 15 minutes, log the shown time against the system clock, `ProcessInfo.thermalState` and the frame cap. | the shown time never differs from the system clock by more than its shown precision; thermal state stays `.nominal` or `.fair`; the app is still open in the morning | pending device campaign |
| AC-D2 | Overnight run on battery | D1 | As AC-D1 on battery from 100 %, keep-awake on. Log the battery level every 30 minutes. | battery use is recorded, and no claim is made from it; the clock never shows a stale time after the screen dims | pending device campaign |
| AC-D3 | Heat over 30 minutes | D1, D2, D3 | Motion on at speed 2 with the particle-drift theme at `level-0` for 30 minutes. Log the thermal state every 30 s. | thermal state stays `.nominal` or `.fair`; the quality governor may drop to `level-1` and recovers | pending device campaign |
| AC-D4 | Memory | D1, D2, D3 | During AC-D3, record the footprint high-water mark (Instruments, Allocations and VM Tracker). Change theme 20 times, then leave and reopen the clock five times. | peak at most 150 MB; no growth across the reopens | pending device campaign |
| AC-D5 | Frame pacing | D1 reference iPhone | Instruments, Animation Hitches, for 2 minutes with motion on and 2 minutes still. | intervals at the 30 per second cap with motion on; with a still picture the theme shader is not run between changes (Metal System Trace shows only copies) | pending device campaign |
| AC-D6 | Screen-care drift on OLED | D1 | Leave the clock still for 60 minutes and photograph the time's position every 10 minutes. | the text moves within 8 points and returns, with no edge visible at any moment | pending device campaign |
| AC-D7 | Night readability | D1, D2 | In a dark room, night mode on, each theme and palette, at dim 0.3 and 1. | the time reads clearly from 2 metres at every setting, and the system brightness is unchanged | pending device campaign |
| AC-D8 | Time changes on the device | D1 | Change the time zone, the region format (12/24 hours) and the language in Settings with the clock open; set the date to the evening before a daylight-saving change and let it pass. | the shown time is correct at once after each change, and no hour is skipped or repeated wrongly | pending device campaign |
| AC-D9 | VoiceOver and Dynamic Type | D1, D2, D3 | With VoiceOver on, find the clock, the controls and every setting; with the largest text size, check every control. | the time is spoken in full; every control is reachable and labelled; the time fits on one line | pending device campaign |
| AC-D10 | Accessibility audit | D1, D2, D3 | Run the system accessibility audits (`VC_RUN_AUDITS=1`, owner ruling of 2026-11-13) on the Ambient Clock screens at the default and the largest text size. | no audit issue in the Ambient Clock screens | pending device campaign |
