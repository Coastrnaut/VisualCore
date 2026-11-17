# Ambient Clock (`a18.ambient-clock`)

A calm, readable clock over slow procedural visuals (archived manual `apps/18-ambient-clock.md` §1–§2), for people
who want a bedside, desk or kiosk clock that is pleasant to look at and easy to read. Version 0.1 covers:
- locale-aware time and date from the system calendar and time zone;
- four procedural visual themes with quality and motion controls;
- readable 12/24-hour typography with optional seconds;
- a theme editor with saveable favourites;
- a brightness-friendly night mode and a motion-reduction option;
- updates on foreground return, time-zone and daylight-saving changes.

Non-goals: weather, location, alarms, network content and any claim beyond the system clock's accuracy.

Ambient Clock is an experience of the one VisualCore app (ADR-0009). From Phase 01 on it is built in
`Packages/ExperiencesCreative/AmbientClock`, and it never has a standalone target. Every theme is a shader, field,
particle or SDF drawing made in code; the time is drawn with system fonts by the host's canvas overlay. It needs no
permission. Night mode dims and warms the drawing itself and never sets the system brightness; keeping the screen on
is an opt-in setting. Its rules are the A18 subsection of the constitution (2.14.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
