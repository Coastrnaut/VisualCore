# Data model: UA-F10

## `Configs/app-targets.json` (schema 1)

```json
{"schema": 1, "targets": [
  {"name": "VisualCore", "bundle": "dev.visualcore.VisualCore", "ships": true},
  {"name": "Showcase", "bundle": "dev.visualcore.Showcase", "ships": false, "reason": "framework showcase harness"},
  {"name": "ParticleUniverse", "bundle": "dev.visualcore.ParticleUniverse", "ships": false,
   "reason": "standalone target kept for A04-P04 to A04-P06", "until_gate": "X-A04"}]}
```

Rules: exactly one `ships: true`; names unique; bundles unique; every application target of `project.yml` listed
and nothing else; `until_gate` pass in the migration ledger → failure. Schema other than 1 → refusal.

## `docs/performance/build-measurements.json` (schema 1)

```json
{"schema": 1, "records": [{"commit": "<40 hex>", "date": "YYYY-MM-DD", "xcode_build": "27B52",
  "clean_build_s": 0.0, "incremental_build_s": 0.0, "release_app_bytes": 0, "milestone": "UA-F10"}]}
```

Append only; one record per commit; damaged or newer schema → refusal and no write.

## Experience package expectations (derived, not stored)

For each registered id: package from the code prefix, name from the catalog, four targets
`<Name>Core`, `<Name>CoreTests`, `<Name>Experience`, `<Name>ExperienceTests`, and a product `<Name>Experience`
linked by the `VisualCore` app target.
