# Data model: R02-G21-06

| Entity | Fields | Rules |
|---|---|---|
| `BinaryGardensFeedbackPlan` | text, kind, haptic, trigger | from the old and new core; a run plans only its outcome |
| `BinaryGardensLights` | glow, won, bloom per world | linear easing 0.15 s / 0.45 s under Reduce Flashing |
| `BinaryGardensAudition` | partials (`BinaryGardensPartial`: frequency, gain) | 0.6 s linear decay; gain 0.04 each |
| Ambient recipe | root step 0 … 3, partials, loop length | a valid `AmbientLoopRecipe` of the shared player |
| Feedback log entry | the routed plan | appended per routed plan, oldest first; never saved or sent |

- **Feedback plan**: refusals in words (clarification Q1, the engine's `action.rule.` prefix read as the bare code);
  equal inputs give equal plans; the trigger is the control, the bare refusal code, "hint" or "level".
- **Lights**: glow 0.7 playing, 1 won, 0.35 failed (only once the run failed); won 1 once won, else 0; bloom 1 when the
  world is comfortable at the drawn shown tick or the level is won, else 0; a started fade finishes before turning
  back under Reduce Flashing; the first frame settles; a level with another world count carries blooms by index and
  starts new worlds at 0.
- **Audition**: tone 220 Hz × 2^(n / 12), n = 2 × (7 − ring index clamped to 0 … 7); with the tone × 3/2 when the star
  can change, with a partial 3 Hz above the tone when it cannot.
- **Ambient recipe**: root 110 Hz × (1, 9/8, 5/4, 4/3) by the actions-left share; one partial per quarter of the worlds
  keeping their light (≤ 4, at root × 5/4, 3/2, 2, 5/2); a brightness partial at root × 3 with the base amplitude ×
  (i₁ + i₂) / (2 × (m − 1)); the octave (merged) and two swells per loop when won, halved amplitudes and gain when
  failed; ≤ 6 partials, gain ≤ 0.3, 4 … 16 s, a whole number of cycles per partial.
- **Feedback log**: kept beside the tier log and 504's refusal log; a tier change or memory warning keeps it.
