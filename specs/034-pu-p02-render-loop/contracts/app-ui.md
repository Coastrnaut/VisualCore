# Contract: Sandbox UI for A04-P02

Existing identifiers from Phase 01 stay (`pu.sandbox.family`, `.description`, `.canvas`, `.live`, `.dropped`,
`.play`, `.step`, `.reseed`).

| Identifier | Element | Text / behavior |
|---|---|---|
| `pu.sandbox.canvas` | stage (GPU surface or CPU preview) + gesture overlay | tap places the force, drag moves it; label includes force and renderer |
| `pu.sandbox.forceKind` | menu picker | None, Attractor, Repulsor, Gravity well, Wind, Vortex |
| `pu.sandbox.force` | text | "Force: none" or "Force: Attractor at (x, y), strength ×1.0" (integers for x, y) |
| `pu.sandbox.center` | button "Center" | places the current kind at (0, 0) (Attractor when the kind is None) |
| `pu.sandbox.nudgeLeft/Right/Up/Down` | buttons | move the force 50 units, clamped to the world square |
| `pu.sandbox.strength` | slider 0.1…2 | accessibility value "×1.0" |
| `pu.sandbox.effective` | text | "Effective limit: 4,000 of 4,000 (quality tier 1 of 4)"; the tier shown is `QualityPolicy.tier + 1` |
| `pu.sandbox.renderer` | text | "Renderer: GPU" or "Renderer: CPU preview (<reason>)" |

Launch arguments (DEBUG builds only): `-uitestThermal nominal|fair|serious|critical`, `-uitestLowPower YES`.
