# Data model: A09-P02

## VisualCore (`VisualCoreSimulation`)

| Type | Fields | Rules |
|---|---|---|
| `SteeringAgent` | `position: Vec2`, `velocity: Vec2`, `group: Int` | non-finite agents get zero force and are never neighbours |
| `SteeringBounds` | `minX`, `maxX`, `minY`, `maxY` | `isValid`: finite, min < max |
| `SteeringParameters` | `neighbourRadius`, `neighbourLimit`, `separationRadius`, `separationWeight`, `alignmentWeight`, `cohesionWeight`, `boundaryWeight`, `boundaryMargin`, `maxForce` | negative or non-finite values are treated as 0; `neighbourLimit` ≤ 0 → no neighbours |

## Experience core (`DigitalAquariumCore`)

| Type | Change | Rules |
|---|---|---|
| `DecorShape` | new: `rock`, `shell` | — |
| `DecorKind` | new: `id`, `name`, `shape`, `color: RGBA`, `size` (0.3…2.0), `author`, `license` | id unique; MIT; project author |
| `DecorSpot` | new: `decorId`, `position: Vec2`, `rotation`, `scale` | inside tank; scale 0.5…2.0 |
| `StarterHabitat` | + `decor: [DecorSpot]` (≤ 12) | kinds exist in catalog |
| `SpeciesCatalog` | + `decor: [DecorKind]` | audited like species and plants |
| `FishAgent` | + `turn: Double` (rad/s, finite) | decodes as 0 when missing |
| `DecorPlacement` | + `rotation` (−π…π), `scale` (0.5…2.0) | decode 0 and 1 when missing |
| `HabitatDocument` | `currentSchema = 2`; starter documents carry the habitat's decor | schema 1 accepted by `migrated(catalog:)` only; validation refuses unknown decor kinds (with catalog), positions outside the tank, scales outside 0.5…2.0, rotation outside −π…π |

## Snapshot (`AquariumState`)

Schema 2 adds a `schema` field; a payload without it is schema 1 and its document is migrated before validation.

## State transitions

schema-1 payload → decode (defaults) → `migrated` (starter decor if empty, schema 2) → validate → core. Every save
writes schema 2.
