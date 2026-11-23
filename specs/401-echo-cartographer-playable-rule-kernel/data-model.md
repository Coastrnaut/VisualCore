# Data model: R02-G11-01

| Entity | Fields | Rules |
|---|---|---|
| `EchoCartographerChamber` | width, height (5 … 16), walls (set of cells) | cell index y · W + x; `isWall`, `isInside`; `ray(from:direction:)` → (open cells crossed, struck wall cell or nil at the border, distance ≥ 1); `pathLengths(from:)` breadth-first over open cells (side steps); `echo(from:beacons:)` → rays and sorted beacon distances with delays 24 × distance |
| `EchoCartographerLevel` | id, seed, difficulty 1 … 5, chamber, entry, beacons (1 … 4 distinct sorted cells), tolerance 0 … 2, energy 1 … 60, miss cost 1 … 3, tutorial, fingerprint | schema 1; sorted-key JSON; entry open; beacons open, not the entry, reachable from the entry |
| `EchoCartographerKnowledge` | per cell: unknown, open, wall | starts with only the entry open; pulses only add |
| `EchoCartographerAction` | pulse(x, y), claim(x, y), mark(x, y) | inside the chamber; pulse from a known-open cell (1 energy); claim not on a known wall (free on a hit, miss cost on a miss); mark toggles, at most 8 markers |
| `EchoCartographerPlay` | stage, knowledge, markers, located (beacon → claim cell), energy, last echo, failure (`energy(action)`), records, undo/redo stacks | records carry previous and next fingerprints |
| `EchoCartographerRecord` | schema, level seed, index, kind (pulse, claim, mark, undo, redo), action, previous and next fingerprints | appended for every accepted action |
| `EchoCartographerRules.Position` | knowledge, located, energy, outcome (playing, won, failed) | moves: every valid pulse, then every valid claim, each in cell-index order (markers are not moves) |
