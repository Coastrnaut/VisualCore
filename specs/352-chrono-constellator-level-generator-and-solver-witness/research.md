# Research: R02-G06-02

- **R1 Integer-tick phase search with a lower bound.** Decision: for every tick T compute m(T), the stars whose default
  timeline is off target at T; m* = min m(T) is a lower bound because each edit acts on one star; a collision-free
  phase-only timeline for a window with m(T) = m* proves the bound tight. Rationale: the source asks for "integer-tick
  phase search for replay windows and time offsets"; the bound turns an infinite timeline space (phases × holds) into an
  exact, cheap certificate. Alternatives: enumerating edit sets of phases and holds (5 stars × 32 × 32 holds: infeasible
  beyond size 2), a tick-level search through `ChronoConstellatorRules` (state space grows with every tick).
- **R2 Blocked windows as difficulty.** Decision: count the windows (m(T) = m*) whose phase-only timeline collides.
  Rationale: a first prototype counted only windows before the first free one and found none (the earliest window is a
  few ticks long); counting all windows to the tick limit measures how many tempting alignments the player must avoid.
  Loops are travelled in a drawn direction, because same-direction loops on a shared edge almost never meet.
- **R3 Band profiles.** Decision: grids 6 × 5, 6 × 5, 7 × 6, 7 × 6, 8 × 7 with 2, 3, 3, 4, 5 stars; smallest edits 1, 2, 2,
  3, 3 … 4; blocked windows at least 0, 1, 2, 2, 3. Rationale: the prototype certified 100 of 100 with these, band means
  non-decreasing and within R02-F24's progression rule.
- **R4 Witness digests.** Decision: 16 hex characters of the SHA-256 of the star cells after every tick up to the win.
  Rationale: the source asks for per-tick state digests ("tick-accurate replay hash"); 16 characters keep 100 files small.
