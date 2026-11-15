# Contract: A11-P05 stability, budgets and levels

- Sleep thresholds: 0.05 m/s, 0.05 rad/s, 60 ticks. Bodies that touch (overlapping bounds) or share a spring between two
  dynamic bodies sleep together, only when every member has 60 rest ticks and none is grabbed; static and pinned bodies
  and walls never join a group. A body joined by a spring to a world point or to a static or pinned body never sleeps
  (T-A11-512; research D1 "As built"). Wake triggers: overlap with an awake dynamic body, a spring to an
  awake dynamic body, an edit naming the body, any level change. Presets, reset and opened slots start awake.
- Work budget per tick at 48 bodies and 16 springs: narrow-phase tests ≤ 1,320; contact points ≤ 2 per contact; solver
  point updates ≤ iterations × contact points.
- Quality: `qualityTiers` 3, profile `level-0`, `level-1`, `level-2`; host tier 0 is the fullest drawing; Low Power Mode
  draws level 2; the digest never depends on the level.
- Registration: summary "A sandbox of circles, boxes and springs under gravity and drag, with presets, saved
  experiments and tutorials."; `quality_tiers` ["level-0", "level-1", "level-2"].
- Claims scan refuses: accurate, accuracy, precise, precision, engineering-grade, safety, predict, prediction, teaches,
  learning outcome, improves understanding (catalog entry and README).
