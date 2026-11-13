# Data Model: A04-P04

## SceneDocument (version 2), file `scene-<uuid>.json` in the experience storage

| Field | Rule |
|---|---|
| `version` | 2 (1 = bare `ParticleScene`, migrated; > 2 refused) |
| `name` | 1…64 characters after trimming |
| `scene` | `ParticleScene` with its existing validation (1…8 emitters, finite values, ranges) |
| `force` | optional `SavedForce { kind: PlacedForceKind raw value, x, y ∈ [−500, 500], strength ∈ PlacedForce.strengthRange }` |
| `trailsOn` | Bool (v1 default false) |
| `trailStrength` | 0…1 (v1 default the core's default) |
| `additive` | Bool (v1 default the core's default) |

## Open sequence (logged actions)

`scene.begin [count 1…8]` → `emitter.define [family index, x, y, size, lifetime, gradient index]` × count →
`force.define [kind index (0 = none), x, y, strength]` → `look.define [trails 0/1, trail strength, blend 0/1]`.
A define outside a begun open, a wrong count or an invalid value rejects the open (`a04.invalid-open`); the scene is
unchanged until `look.define` commits.

## emitter.move

`[x, y]` scene coordinates, clamped to ±500; selected emitter only.

## Library entry

`{ id: UUID, name, saved: Date }`; problems: count of unreadable files.
