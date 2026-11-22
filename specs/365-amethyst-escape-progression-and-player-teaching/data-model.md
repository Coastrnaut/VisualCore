# Data model: R02-G07-05

| Entity | Fields | Rules |
|---|---|---|
| `AmethystEscapePlan` | the actions of the shortest escape from the current crystal (first one shown) | nil when no escape fits in the moves left |
| `AmethystEscapeHint` | level 1 … 3, kind (turn, advance, stuck), shell, step, text | read only; reset after any play change; none when won |
| `AmethystEscapeFailureExplanation` | failure (wedge, budget), shell, sector, move, pearl, text | only when the play failed |
| `AmethystEscapeTutorialStep` | turn, advance, escape, done | levels 1 … 3; turn → advance on any accepted move (turn or advance); advance → escape on an accepted advance; escape → done when the level ends (a level ended before its step is reached goes straight to done); dismissible |
| `AmethystEscapeProgress` | per level best moves and stars; frontier | stars 3/2/1 by smallest / smallest + 2; campaign wins open the next |
| `AmethystEscapeMode` | campaign, practice, daily(level) | practice budget 60, no stars, no unlocks; daily opens nothing |
| Snapshot | schema 2 `{level, records, progress, mode, tutorial}` | migration from schema 1 |
