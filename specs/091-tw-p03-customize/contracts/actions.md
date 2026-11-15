# Contract: Tiny Worlds actions after A12-P03

| Control | Values | Refusals |
|---|---|---|
| `world.preset` | [0…2] | a12.invalid-choice (clears props) |
| `world.seed` | [] | (clears props) |
| `view.orbit`, `view.zoom`, `view.reset` | as in A12-P02 | as in A12-P02 |
| `prop.place` | [kind 0…3, x, z] | a12.prop-cap, a12.outside, a12.under-water, a12.too-close, a12.invalid-choice |
| `prop.select` | [index or −1] | a12.invalid-choice |
| `prop.move` | [dx −1…1, dz −1…1] | a12.no-selection, a12.outside, a12.under-water, a12.too-close |
| `prop.rotate` | [degrees −180…180] | a12.no-selection |
| `prop.delete` | [] | a12.no-selection |
| `light.azimuth`, `light.elevation`, `light.ambient` | [value] | out of range |

Slot actions (save, open, clear) are presenter actions through `WorldStore`; opening restores a snapshot through
`ExperienceShell.restore`; every action above has a native control.
