# Data model: Phase 9

- **API baseline line**: `<module> | <kind> | <declaration text normalized>`; sorted, unique.
- **AutomationReport** (JSON, schema 1): `schema`, `mode`, `bundleID`, `deviceModel`, `osVersion`, `startedAt`, `frames`,
  `frameTimeMs {min, median, p95, max}`, `timeToFirstFrameMs`, `cycles`, `leaked`, `result` (`pass|fail|error`), `message`.
- **License entry**: component, version/pin, license, where used, shipped? (yes/no), obligations.
- **Release check step**: name, command, exit, log path, duration.
- **Support matrix row**: platform, OS (build), kind (simulator/device), evidence, status (`verified (simulator)` | `pending campaign II` | `unsupported`).
