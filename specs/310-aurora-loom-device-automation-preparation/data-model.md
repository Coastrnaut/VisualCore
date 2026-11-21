# Data model: R02-G01-10

| Entity | Fields | Rules |
|---|---|---|
| Definition | schema 1, experience, devices, scenarios, rows | sorted keys; schema 1 only |
| Device | name (D1, D2, D3), ledger (DEV1-R02-G01 …) | equal to the ledger's DEV rows of the experience, in order |
| Scenario | name | in the manifest; unique |
| Row | id AL-D1 … AL-D8, title, devices, procedure, measurements, pass, gating, covers, owner_steps, status | every field present and non-empty; status "pending device campaign"; no result field |
| Covered item | task id (T-R02G01…), `R02-G01-06:sound|haptics|voiceover`, UA-F13 name (launch, first-frame, frame-pacing, memory, thermal, stress) | each required item covered by at least one row |
