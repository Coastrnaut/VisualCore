# Data model: Phase 1 contracts

## Package (contracts/package-map.md)
`name`, `platform ∈ {host+iOS, iOS}`, `owns`, `publicSurface`, `allowedDependencies[]`, `auditTrace`,
`version` (semver, 0.x until F09). Rule: `allowedDependencies` graph acyclic (R3).

## DependencyViolation (output of scripts/check_dependencies.py)
`rule ∈ {R1..R5}`, `path`, `line?`, `detail`. Any violation → exit 1.

## LifecycleState / LifecycleEvent (contracts/render-lifecycle.md)
States: `uninitialized, surfaceReady, active, suspended, surfaceInvalid, reinitialized, destroyed`.
Event: `from, to, generation, accepted`.

## GPUHandle / ResourceBudget / ShaderDiagnostic / ErrorCategory / DiagnosticsSnapshot
As defined in contracts/resources-shaders-errors.md (fields and units listed there).

## RegressionCheck (contracts/tests-adapter-submodule-regression.md)
`trigger`, `commands[]`, `expected: exit 0 / xcresult Passed`.
