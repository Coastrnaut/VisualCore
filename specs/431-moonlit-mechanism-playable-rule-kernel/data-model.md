# Data model: R02-G14-01

| Entity | Fields | Rules |
|---|---|---|
| `MoonlitMechanismGear` | teeth 6 … 20, phase 0 … teeth − 1, blades (teeth bits, at least one solid and one open), depth 1 … 3, centre (column, row), parent (nil for gear 0, else a lower index), alignment 0 … g − 1, slots (teeth lists of offsets (dc, dr), each within ±8, each list non-empty) | g = gcd(teeth, parent's teeth) ≥ 2 |
| `MoonlitMechanismKeyFrame` | turns (strictly increasing, the first ≥ 0), target cells (non-empty, sorted), required | at least one required |
| `MoonlitMechanismLevel` | id, seed, difficulty 1 … 5, gears (2 … 5), wall W 8 … 24 × H 6 … 16, lamp heights L 2 … 5, starting height, key frames (2 … 6), forbidden cells (0 … 12, disjoint from every target), allowance 0 … 4, budget 1 … 40, tutorial, fingerprint | schema 1; sorted-key JSON |
| `MoonlitMechanismFrameReport` | phases, cast cells (sorted), covered, missing, stray, forbidden hits (sorted) | exact |
| `MoonlitMechanismRunReport` | alignment errors per pair, frames, outcome (won, jammed(pair), forbidden(frame, cell), missing(frame, count), stray(frame, count)) | computed from the level, phases and lamp height |
| `MoonlitMechanismAction` | turn(±1), reseat(gear, ±1), lamp(±1), run | each spends 1 action |
| `MoonlitMechanismPlay` | stage, phases, lamp height, actions spent, report, failure (`jammed`, `forbidden`, `missing`, `stray`, `budget`), records, undo/redo stacks | records carry previous and next fingerprints |
| `MoonlitMechanismRecord` | schema, level seed, index, kind (turn, reseat, lamp, run, undo, redo), action, previous and next fingerprints | appended for every accepted action |
| `MoonlitMechanismRules.Position` | phases, lamp height, actions spent, outcome (playing, won, failed) | moves: turn −1, +1; every re-seat (gear, then −1, +1); lamp −1, +1 when in range; then the run |
