# Data model: R02-G21-10

| Entity | Fields | Rules |
|---|---|---|
| Definition | schema, experience, devices, scenarios, rows | sorted keys; schema 1 only; `r02-g21.binary-gardens` |
| Device | name (D1, D2, D3), ledger (DEV1-R02-G21 …) | equal to the ledger's DEV rows of R02-G21, in order |
| Scenario | name | in the manifest; unique; 12 names |
| Row | see below | see below |
| Covered item | {device} task id or UA-F13 name | each covered by at least one row |

- **Row fields**: id (BG-D1 … BG-D8), title, devices, procedure, measurements, pass, gating, covers, owner_steps,
  status. Every field present and non-empty; status "pending device campaign"; no result field (`result`, `results`,
  `value`, `measured`, `measurement_values`); gating a boolean, false only for BG-D6.
- **Covered items**: T-R02G2103-012, T-R02G2104-011, T-R02G2106-011, T-R02G2107-012, T-R02G2108-012,
  T-R02G2109-011; UA-F13 names launch, first-frame, frame-pacing, memory, thermal, stress.
