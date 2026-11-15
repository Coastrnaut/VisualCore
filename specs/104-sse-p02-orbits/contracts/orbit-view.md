# Contract: orbit view and actions (feature 104)

Actions (adapter `SolarCore`): `body.select [0…8]`, `body.next`, `body.previous`, `date.step [±1 | ±30 | ±365]`
(others `a14.invalid-step`, beyond the range `a14.out-of-range`), `camera.orbit [±1]`, `camera.tilt [±1]` (beyond
5…85 refused `a14.out-of-range`), `camera.zoom [±1]` (zoom steps beyond −1…12 refused `a14.out-of-range`), `view.reset`.
Outcome `viewing-<id>`. Manifest: state schema 2; fixtures keep the five bodies plus `earth-2025` (date step) digests.

View: Sun and planets at `OrbitLayout.scenePosition` (4·√r mapping), eight orbit tubes, rings for the selection;
canvas description names the date, the focused body, its distance in AU and km, and "Distances and sizes not to
scale". Controls: date stepper buttons (−365, −30, −1, +1, +30, +365), body picker, orbit/tilt/zoom buttons, reset;
each with an accessibility label and value.
