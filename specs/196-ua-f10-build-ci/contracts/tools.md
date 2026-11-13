# Tool contracts: UA-F10

Every tool: Python 3 standard library, exit 0 pass, 1 finding (one line per finding: rule, location, detail),
2 usage or input error; never a traceback for bad input; `--root` for tests.

| Tool | Input | Checks / output |
|---|---|---|
| `check_app_targets.py` | `project.yml`, `Configs/app-targets.json`, `.autonomy/migration/ledger.json` | FR-U10-010/011 |
| `check_experience_packages.py` | `docs/catalog/experience-catalog.json`, `Catalog/registrations.json`, `Packages/Experiences*/Package.swift`, `project.yml` | FR-U10-020/021/022 |
| `check_dependencies.py` | sources and manifests | adds R6–R8 (FR-U10-030) |
| `make_ci_angle_standins.py --out DIR` | `CVisualCoreEGL.h` | writes `libEGL.xcframework`, `libGLESv2.xcframework` with marker `vc_ci_angle_standin`; refuses a DIR holding frameworks without the marker (FR-U10-002) |
| `measure_build.py [--check] [--milestone M]` | the project | appends one record; `--check` validates the file only (FR-U10-050) |
| `release_check.py --only <unified steps>` | the project | each step limited below 600 s (FR-U10-040/041/042) |
| `xcodebuild_app.py --parallel N` | as today | adds parallel testing flags; N ≥ 1 |
