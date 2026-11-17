

- **As built (A21-P03):**
  - the second sky is compiled with `#define AURORA_SKY_SLOT 1` appended, so the two skies never share one cached
    program (tearing one down cannot delete the other's);
  - a fade whose captured still was drawn under a higher limit ends at once when the limit is lowered;
  - a fresh open seeds the saved preferences through the port at the first draw, and a refused send is retried at the
    next draw;
  - `SkyCore.isRestored` (presentation only, outside the digest, the snapshot and equality) tells a restore from a
    fresh open;
  - a failed save is forced in tests by filling the 64-value quota;
  - the A21-P02 blend, limit and chrome tests now expect the crossfade and the two sound controls.
