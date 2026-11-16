# Data model: A15-P01 (feature 110)

| Entity | Fields | Rules |
|---|---|---|
| `Element` | symbol, name, atomicNumber, covalentRadius (Å), vanDerWaalsRadius (Å), colorHex (6 hex digits) | symbols and numbers unique; radii finite, 0.1…3.0 Å; ten elements |
| `SourceRecord` | key (element symbol or molecule id), quantity, title, publisher, link, units, license | every stored value has exactly one record; license ∈ {`public-domain`, `CC0-1.0`, `factual-data`} |
| `Atom` | element symbol, position (x, y, z in Å) | finite; magnitude ≤ 1,000 Å |
| `BondOrigin` | recorded, inferred | inferred bonds are single |
| `Bond` | a, b (atom indices, a < b), order (1…3), origin | indices in range; no self or duplicate bonds |
| `Molecule` | id, title, formula (derived), atoms (1…500), bonds (0…2,000), source | no two atoms closer than 0.4 Å |
| `XYZRefusal` | reason (`empty`, `too-large`, `not-text`, `bad-count`, `too-many-atoms`, `count-mismatch`, `line-too-long`, `malformed-line`, `unknown-element`, `non-finite`, `out-of-range`, `overlapping-atoms`), line? | one per refused input |
| `MoleculeLibrary` | molecules [5]: water, methane, ethanol, benzene, caffeine | every molecule parses and validates; sources PubChem public domain |
| `MoleculeState` (schema 1) | molecule index 0…4 | damaged or newer refused |
