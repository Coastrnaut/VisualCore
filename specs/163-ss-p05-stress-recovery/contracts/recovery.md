# Contract: Shader Studio stress, recovery and shape (A22-P05)

- **Stress:** after 50 mixed cycles, 20 template changes and 10 stop-and-reset cycles, the resource level equals the
  level after the first cycle.
- **Recovery:** in each of the states running, failed, refused, stopped and textured, 10 `recreateContext` calls give
  a byte-identical picture, an unchanged resource level and `leaked` 0.
- **Shape:** `document.shape` bounds `uniform.set` and `texture.set`. A project with uniforms beyond its template
  keeps and changes every value. A snapshot without `shape` reads the template's counts.
- **Relaunch (`d3`, `SSRecoveryUITests`):** save "Waves", terminate, launch without `-vcResetData`, then `project-0`
  is "Waves" and opens with the saved source.
- **Device plan:** 18 rows (SS-D1 to SS-D6 × D1 to D3), all pending.
