# Data Model: A24-P05 (feature 177)

- **Qualification:** `class` (valid, qualified, invalid), `reasons` (codes of clarification Q1, in a fixed order) and
  their sentences.
- **RepeatabilitySummary:** `comparable` (order, interval p50, p95, GPU p50?), `notComparable` (order, reason),
  `spreadP50Ms?`, `spreadP95Ms?`, `spreadGPUp50Ms?`.
- **CSV version 2:** key rows `qualification` and `qualification_reasons` after `state`.
- **Device plan row:** `GBL-Dn`, device (D1, D2, D3), steps, expected result, owner actions, state `pending`.
