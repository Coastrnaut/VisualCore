# Contract: actions added in A12-P04

| Control | Values | Effect | Refusals |
|---|---|---|---|
| `world.pack` | [0…2] | replaces the world with pack i (also "reset to pack") | a12.invalid-choice; a12.* placement codes for a broken pack |

All earlier actions (A12-P01–P03) keep their contracts; view actions now clamp to the current preset's limits.
