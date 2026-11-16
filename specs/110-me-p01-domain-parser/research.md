# Research: A15-P01 (feature 110)

## D1 — Element data and licenses
- **Decision**: ten elements; name, atomic number, van der Waals radius and display colour from the PubChem periodic
  table (public domain); single-bond covalent radii from Cordero et al. 2008 recorded as `factual-data`; allowed
  licenses `public-domain`, `CC0-1.0`, `factual-data` (clarification Q1). PubChem's van der Waals values for F (135 pm)
  and Br (183 pm) differ from Bondi's 1964 table (147, 185); the bundled values follow the fetched PubChem table, the
  single cited source.
- **Alternatives**: Bondi 1964 radii (rejected: a second source for the same quantity); CRC Handbook (rejected:
  licensed compilation).

## D2 — Library
- **Decision**: five PubChem 3D conformers (CIDs 962, 297, 702, 241, 2519) bundled unchanged as XYZ text plus recorded
  bonds with orders; parsed by the app's parser at load (clarification Q2). A generator script turns the kept raw
  records into the bundled Swift data once; a test checks counts against each record's counts line.
- **Alternatives**: idealised geometry computed from bond lengths (rejected: more derived numbers to source).

## D3 — Parser placement
- **Decision**: app-local `XYZParser` (pure, Foundation only) with the limits and reasons of clarification Q3. A
  VisualCore line reader was assessed (constitution A15, contract G-PARSER): the only consumer is this experience, so
  it stays app-local; the contract records the outcome.

## D4 — Bond inference
- **Decision**: all-pairs distance test with covalent radii plus 0.4 Å (clarification Q4); validated on the five
  curated molecules (inferred connectivity equals recorded connectivity).
- **Alternatives**: spatial grid (rejected for 500 atoms: 124,750 pairs is bounded and fast).

## D5 — Drawing, state and actions
- **Decision**: atoms as lit UV spheres at 0.35 × the van der Waals radius in element colours through `DepthMeshPass`
  and an `OrbitCamera` framed on the bounding sphere; state schema 1 molecule index; actions `molecule.select`,
  `molecule.next`, `molecule.previous`; refusal `a15.invalid-choice`; five fixtures (clarification Q5). Bonds are drawn
  from A15-P02.
