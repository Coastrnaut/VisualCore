# Data Model: A24-P05 (feature 177)

- **Qualification:** `class` (valid, qualified, invalid), `reasons` (codes of clarification Q1, in a fixed order) and
  their sentences.
- **RepeatabilitySummary:** `comparable` (order, interval p50, p95, GPU p50?), `notComparable` (order, reason),
  `spreadP50Ms?`, `spreadP95Ms?`, `spreadGPUp50Ms?`.
- **CSV version 2:** key rows `qualification` and `qualification_reasons` after `state`.
- **Device plan row:** `GBL-Dn`, device (D1, D2, D3), steps, expected result, owner actions, state `pending`.
- **As built (A24-P05):**
  - a running run reads the device conditions every frame through the presenter's `conditionsSource`; a serious or
    critical thermal state ends it as interrupted ("Interrupted: the device is hot"), so it is invalid (T-A24-513,
    contract risk 3). The edge case "serious already at the start → qualified" stays the rule of `RunQualification`
    for a stored report; a live run can no longer finish while the device is hot;
  - the repeatability block's button is `repeatability-explain`, the opened result's `explain` (T-A24-514);
  - the interface journeys are timed from the Start run tap, and the background is awaited with `app.wait(for:)`.
