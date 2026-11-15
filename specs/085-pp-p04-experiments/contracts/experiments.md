# Contract: A11-P04 actions and files (`a11.physics-playground`, schema 4)

| Action | Values | Effect |
|---|---|---|
| `experiment.preset` | 0…3 | opens free play, pendulum, spring chain or stacked objects; it becomes the starting world |
| `tutorial.start` | 0…1 | starts "Controlling time" or "Springs and energy" at step 0 |
| `tutorial.stop` | — | ends the tutorial; refused `a11.no-tutorial` when none runs |
| `world.reset` | — | restores the starting world (running, normal speed, no grab, no selection) |

Fractional choices → `a11.invalid-choice`.

Files in the experience's storage: `experiment-0.json` … `experiment-3.json`, each an `ExperimentDocument` (schema 1,
sorted keys). Store results: saved; opened; refused `empty-slot`, `damaged`, `newer-version`, `invalid-world`; storage
error codes passed through. Opening a slot restores a snapshot through the shell (not an action).
