# Data model: R02-G06-05

| Entity | Fields | Rules |
|---|---|---|
| `ChronoConstellatorPlan` | run(ticks), rewind, release(star, start), phases([(star, phase)]) | from the current state; nil when no win is reachable |
| `ChronoConstellatorHint` | level 1 … 3, kind (phase, release, rewind, run, stuck), star, cell, phase, start, ticks, text | read only; reset after any play change; none when won |
| `ChronoConstellatorFailureExplanation` | failure (collision, time), stars, cell, tick, off-target list, text | only when the play failed |
| `ChronoConstellatorTutorialStep` | shift, replay, align, done | levels 1 … 3; shift → replay when a phase change was accepted and the plan is a run; replay → align on an accepted step; align → done when the level ends; dismissible |
| `ChronoConstellatorProgress` | per level best edits and stars; frontier | stars 3/2/1 by smallest / smallest + 2; campaign wins open the next |
| `ChronoConstellatorMode` | campaign, practice, daily(level) | practice budget 20, no stars, no unlocks; daily opens nothing |
| Snapshot | schema 2 `{level, records, progress, mode, tutorial}` | migration from schema 1 |
