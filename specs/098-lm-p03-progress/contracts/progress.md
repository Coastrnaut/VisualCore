# Contract: A13-P03 progress, moves and undo

- `progress.json` (schema 1, sorted keys, ≤ 16 KB): `{"levels":[{"best":n|null,"id":"lm-01","open":true,
  "solved":false},…],"schema":1}`; exactly the 20 catalog ids in order; level 1 open; solved ⇒ open and best 1…999;
  unsolved ⇒ best null. Refusals: `damaged` (anything else, truncated, unknown ids, wrong count, > 16 KB as
  `too-large`), `newer-version`; storage errors by code. Reading never writes.
- State schema 2: schema 1 + `moves` [{tile, before, after}] ≤ 64 (oldest dropped). `tile.turn` appends; `move.undo`
  restores `before` and removes the last move (`a13.no-moves` when empty); `level.reset` restores the start and empties
  moves; `level.select` empties moves. Migration 1 → 2: no moves.
- Solve recording: unsolved → solved on the current level between two drawn frames ⇒ solved, best = min(best,
  max(1, moves)), next level open, one save.
- Locks: the Level menu disables locked levels ("locked"); Next level is disabled when the next level is locked; a
  refused choice: "Level N is locked; solve level N−1 first." The engine's `level.select` is not gated.
