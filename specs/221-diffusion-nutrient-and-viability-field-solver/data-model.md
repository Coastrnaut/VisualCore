# Data model: R02-F21

| Entity | Fields | Rules |
|---|---|---|
| NutrientField | width, height, channels, diffusion [D], decay [λ], amounts (Int64 quanta), sources, bands, network, ledger | sides 2 … 512; ≤ 262,144 cells; channels 1 … 4; D finite 0 … 1,000; λ finite 0 … 100; cell and grid total ≤ 2⁴⁰ quanta; JSON schema 1; decode re-validates and checks the ledger |
| NutrientSource | cell, channel, kind (source, sink), rate, carry | rate finite, 0 < rate ≤ 1,000 units/s; ≤ 256 per field; cell and channel in range |
| ViabilityBand | low, high, ramp (units) | finite; low ≤ high; ramp ≥ 0 |
| GrowthNetwork | cells, parents, limit, perFrame, threshold, foodChannel, cost | limit 1 … 65,536; perFrame 1 … 1,024; threshold finite, 0 < t ≤ 1; cost 0 … 2⁴⁰ quanta; foodChannel in range |
| NutrientAccount | added, removed, faded, eaten | net = added − removed − faded − eaten |
| NutrientLedger | accounts per channel | the field is balanced when each channel's total equals its account's net |
| NutrientStepReport | substeps, simulated, dropped, added, removed, faded, eaten (per channel), capped, short, grown | |
| NutrientError | gridSize, channel(Int), cellRange(Int), amountLimit, parameter(String), time, sourceLimit, growth(String), newerSchema(Int), malformed(String) | `reasonCode` `r2-f21.*` |
