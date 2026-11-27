# Data model: R02-G21-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | `{level: 1, records}`: star 2's ring to index 1, playing, not won; seed 2_509 | 1 → 3; ring kept |
| Schema-2 example | `{level, mode, progress, records, tutorial}`: campaign, tutorial done, frontier 2 | 2 → 3 |
| Schema-2 result | level 1: 2 actions spent (certified 1 + 1), 2 stars, no trace | kept, unverified |
| Control identifier | `experience.r02-g21.binary-gardens.<name>` in `BinaryGardensControls.identifierNames` | unique |
| Identifier count | 37 today (features 503, 504) plus the names features 505 … 507 build | read as built |
| Interface chunk `d4` | `BGPlayUITests` (2 tests), `BGReplayUITests` (1 test) | serial; < 90 s + setup |
| Level 1 constants | star index 1 to luminosity index 0, run; budget 9; 2 levels; start index 1 | = Core |
