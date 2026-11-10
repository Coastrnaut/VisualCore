# Data model: Phase 0 audit outputs

## ReferencePinSet (`docs/architecture/projectm-reference-audit.json`, existing)
`reference.commit`, `reference.superproject_pin`, `reference.clean`, `submodules{path: {url, branch, commit}}`.
Validation: projectM/angle URL contains `Coastrnaut/`, branch `ios`; `superproject_pin == commit`.

## InventoryRow (`docs/architecture/reference-inventory.json` → `rows[]`)
| Field | Type | Rule |
|---|---|---|
| path | string | exists in reference at pinned commit |
| kind | enum package/app/xcodegen-spec/script/test-target/ci-workflow/dependency/license | required |
| role | enum projectm-specific/reusable-candidate/tooling/content | required |
| detail | string | targets, products, deps or test count |

## TraceCitation (parsed from `current-rendering-pipeline.md`)
`path`, `symbol`, `resolved: bool`. Every citation must resolve (SC-F002).

## BaselineRecord (`docs/verification/projectm-baseline.md` table + `.autonomy/checks/F00.*.json`)
`step`, `command`, `exit_code`, `log`, `log_sha256`, `result` ∈ {pass, fail, blocked}.

State: the reference tree goes `clean → (generated ignored outputs only) → clean`; any tracked
change is a failure.
