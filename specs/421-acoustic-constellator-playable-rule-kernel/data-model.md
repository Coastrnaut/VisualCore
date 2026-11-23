# Data model: R02-G13-01

| Entity | Fields | Rules |
|---|---|---|
| `AcousticConstellatorStar` | x, y, z 0 … 11, rate 0 … 11, phase 0 … 11 | position drawing only; never decides a rule |
| `AcousticConstellatorLink` | a, b (stars, a < b) | no self pair; no repeated pair |
| `AcousticConstellatorLevel` | id, seed, difficulty 1 … 5, stars (3 … 8), fixed links (0 … 6), symbol (2 … 10 pairs, connected), coupling K 1 … 8, degree limit 2 … 4, link limit (symbol size … 16), snap limit 2 … 5, threshold 1 … n², hold 2 … 12, window hold … 48, budget 1 … 40, tutorial, fingerprint | schema 1; sorted-key JSON; fixed links within the limits |
| `AcousticConstellatorListen` | phases [tick][star] (tick 0 … W), snapped [tick][link index], order [tick] (A, B), coherent [tick], longest run, outcome (won at tick, missing pair, disconnected at tick with link, incoherent with longest run) | computed from the level, links and starting phases; exact |
| `AcousticConstellatorAction` | link(a, b), unlink(a, b), nudge(star, ±1), listen | each spends 1 action |
| `AcousticConstellatorPlay` | stage, links (fixed then placed, in index order), phases (starting), actions spent, last listen report, label and match, failure (`missing(pair)`, `disconnected(tick, link)`, `incoherent(run)` or `budget(action)`), records, undo/redo stacks | records carry previous and next fingerprints |
| `AcousticConstellatorRecord` | schema, level seed, index, kind (link, unlink, nudge, listen, undo, redo), action, previous and next fingerprints | appended for every accepted action |
| `AcousticConstellatorRules.Position` | links, phases, actions spent, outcome (playing, won, failed) | moves: every valid link (pair order), every valid unlink (pair order), every nudge (star, then −1, +1), then the listen |
