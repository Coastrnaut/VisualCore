# Data model: R02-G13-06

| Entity | Fields | Rules |
|---|---|---|
| `AcousticConstellatorFeedbackPlan` | text, kind, haptic | from the old and new core; a listen plans only its outcome; refusals in words |
| `AcousticConstellatorLights` | glow (0.7 playing, 1 won, 0.35 failed), won (1 won, else 0) | linear easing 0.15 s / 0.45 s under Reduce Flashing; a started fade finishes before turning back |
| Audition recipe (`AcousticConstellatorAudition`) | partials (`AcousticConstellatorPartial`: frequency, gain), 0.6 s decay | two tones 220 Hz × 2^(rate / 12), gain 0.04, the second detuned by 1.5 Hz per gap step |
| Ambient recipe | root step 0 … 3, partials, loop length | root by actions-left share; one partial per lit coherence quarter (≤ 4); octave when won, halved gains when failed |
