# Data model: R02-G12-01

| Entity | Fields | Rules |
|---|---|---|
| `HarmonicBridgesIsland` | x 0 … 15, y 0 … 9 | drawing only; never decides a rule |
| `HarmonicBridgesString` | a, b (islands, a < b), length 1 … 6, peg 1 … 12, locked | no repeated pair; `mode(of: tone)` → n in 1 … 5 or nil (n · peg = F · length) |
| `HarmonicBridgesTone` | frequency 1 … 72, strength 1 … 3 | distinct frequencies within a step |
| `HarmonicBridgesResonance` | string, step, modes (tone → n), swing [5] (E(1 … 5)), bridge | swing table q(n, k) ∈ {0, 1, 3, 4}; bridge ⇔ min swing ≥ threshold |
| `HarmonicBridgesLevel` | id, seed, difficulty 1 … 5, islands (2 … 8), strings (1 … 12), start, goal, steps (1 … 4 of 1 … 3 tones), threshold 1 … 12, budget 1 … 60, tutorial, fingerprint | schema 1; sorted-key JSON; start ≠ goal |
| `HarmonicBridgesAction` | tune(string, peg), test | tune: unlocked string, peg 1 … 12, not the current peg; both spend 1 action |
| `HarmonicBridgesPlay` | stage, pegs, actions spent, last report, failure (`broken(step, string?)` or `budget(action)`), records, undo/redo stacks | records carry previous and next fingerprints |
| `HarmonicBridgesRecord` | schema, level seed, index, kind (tune, test, undo, redo), action, previous and next fingerprints | appended for every accepted action |
| `HarmonicBridgesRules.Position` | pegs, actions spent, outcome (playing, won, failed) | moves: every valid tuning (string, then peg order), then the test |
