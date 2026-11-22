# Data model: R02-G08-05

| Entity | Fields | Rules |
|---|---|---|
| `FacetedForgePlan` | the cuts of a winning continuation from the current pieces (first one shown) | nil when none is found within the cuts left and the work bound |
| `FacetedForgeHint` | level 1 … 3, kind (cut, stuck), piece, direction, depth, text | read only; reset after any play change; none when won |
| `FacetedForgeFailureExplanation` | failure (sliver, budget), cut, piece, share, pieces, target, text | only when the play failed |
| `FacetedForgeTutorialStep` | aim, match, finish, done | levels 1 … 3; aim → match on an accepted cut; match → finish on a second accepted cut; finish → done when the level ends (a level ended earlier goes straight to done); dismissible |
| `FacetedForgeProgress` | per level best cuts made and stars; frontier | stars 3/2/1 by smallest / smallest + 2; campaign wins open the next |
| `FacetedForgeMode` | campaign, practice, daily(level) | practice budget 20, no stars, no unlocks; daily opens nothing |
| Snapshot | schema 2 `{level, records, progress, mode, tutorial}` | migration from schema 1 |
