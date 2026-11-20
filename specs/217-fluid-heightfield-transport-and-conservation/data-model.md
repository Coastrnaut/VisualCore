# Data model: R02-F17

| Entity | Fields | Rules |
|---|---|---|
| Heightfield | width, height, edges, dyeChannels, parameters, terrain, water, sediment, dye[channel] (Int64 quanta), flux (4 × cells, Double), ledger | sides 4 … 1,024, ≤ 262,144 cells; 0 … 4 dye channels; amounts 0 … 2⁴⁰; flux 0 … 1,000,000 |
| HeightfieldEdges | walled, open | open edges drain |
| HeightfieldParameters | gravity, pipeArea, damping, maxSubstep, maxSubsteps, erosion, capacity, dissolving, depositing | gravity 0 < g ≤ 100; pipeArea 0 < A ≤ 10; damping 0 … 1; maxSubstep 0 < h ≤ 0.1; maxSubsteps 1 … 64; rates 0 … 10; all finite |
| HeightfieldLedger | water, rock, dye[channel] accounts of (added, removed, drained) | total = added − removed − drained, exactly |
| HeightfieldStepReport | substeps, substepDuration, droppedTime, fluxClamped | droppedTime > 0 only past maxSubsteps |
| HeightfieldError | gridSize, cellRange, amountLimit, invalidTime, invalidParameter, dyeChannel, newerSchema, malformed | `reasonCode` `r2-f17.*` |
