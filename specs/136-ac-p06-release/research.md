# Research: A18-P06 (feature 136)

- **D1 Statuses (clarification Q1):** the release checker's own statuses, as in A17-P06.
- **D2 Refused words (Q2):** precision, always-on and weather wording is refused, because the clock is exact only to the
  system clock, the screen may sleep, and there is no weather. The shared denylist already refuses measured numbers,
  battery and frame rates; the copy writes "24-hour" with a hyphen.
- **D3 Source scan (Q3):** as A17's, except that the idle timer is required in exactly one file rather than refused
  everywhere.
- **D4 Recovery and samples (Q4):** as A17's, applied to the favourites file and the snapshot schemas 1–3.
- **D5 Interface (Q5):** one more test class in chunk `z2`.
