# Contract: Aurora compositing and preferences (A21-P03)

- **Transition:** at progress 0, 0.1, …, 1 no pixel exceeds the limit + 1/255 and the mean absolute difference from
  the incoming sky never increases; a context loss or resize mid-change keeps the picture; a new choice restarts from
  the current mix; immediate under Reduce Motion.
- **Preferences:** a round trip through `prefs.v1` restores every field; damaged, newer and out-of-range samples open
  with the defaults and their code; a failed save is reported once and the choices stay in memory.
- **Sound choice:** unchanged after teardown, setup, `recreateContext`, resize, suspend and resume; nothing plays.
