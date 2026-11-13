# Contract: Particle Universe logged actions added in Phase 04

| Action id | Values | Effect |
|---|---|---|
| `scene.begin` | 1: emitter count 1…8 | starts an open; discards any pending open |
| `emitter.define` | 6: family index, x, y, size, lifetime, gradient index | adds one emitter to the pending open |
| `force.define` | 4: kind index (0 none), x, y, strength | sets the pending placed force |
| `look.define` | 3: trails, trail strength, blend | commits the pending open (validated) |
| `emitter.move` | 2: x, y | moves the selected emitter (clamped ±500) |

UI identifiers: `pu.library` (sheet), `pu.library.save`, `pu.library.name`, `pu.library.entry.<index>`,
`pu.library.open.<index>`, `pu.library.rename.<index>`, `pu.library.delete.<index>`, `pu.library.problems`,
`pu.move.left|right|up|down`.
