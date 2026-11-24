# Data model: R02-G14-06

| Entity | Fields | Rules |
|---|---|---|
| `MoonlitMechanismFeedbackPlan` | text, kind, haptic | from the old and new core; a run plans only its outcome; refusals in words |
| `MoonlitMechanismLights` | glow (0.7 playing, 1 won, 0.35 failed), won (1 won, else 0) | linear easing 0.15 s / 0.45 s under Reduce Flashing; a started fade finishes before turning back |
| Audition recipe (`MoonlitMechanismAudition`) | partials (`MoonlitMechanismPartial`: frequency, gain), 0.6 s decay | a gear's tone 220 Hz × 2^((T − 12) / 12), gain 0.04; with its parent, detuned by 1.5 Hz per tooth of mesh error |
| Ambient recipe | root step 0 … 3, partials, loop length | root by actions-left share; one partial per covered quarter of the required target cells (≤ 4); octave when won, halved gains when failed |
