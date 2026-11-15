# Contract: A11-P03 actions (`a11.physics-playground`, schema 3)

Schema-2 actions plus:

| Action | Values | Refusals |
|---|---|---|
| `edit.add` | x 0…10, y 0…8, kind 0…1 | `a11.body-cap`, `a11.no-room`, `a11.invalid-choice` (fractional kind) |
| `edit.select` | id −1…10000 | `a11.unknown-body`, `a11.invalid-choice` (fractional) |
| `edit.grab` | id, x, y | `a11.unknown-body`, `a11.not-grabbable` |
| `edit.move` | x, y | `a11.no-grab` |
| `edit.release` | — | `a11.no-grab` |
| `edit.pin` | id | `a11.unknown-body`, `a11.static-body` |
| `edit.delete` | id | `a11.unknown-body` |
| `edit.nudge` | dx −1…1, dy −1…1 | `a11.no-selection`, `a11.not-grabbable` (static or pinned) |
| `overlay.velocity`, `overlay.forces` | 0…1 | `a11.invalid-choice` |

Gesture identifiers (the presenter's `gestureActions`): `edit.add`, `edit.select`, `edit.grab`, `edit.move`,
`edit.release`, `edit.pin`, `edit.delete`; every one also reachable by a native control.
