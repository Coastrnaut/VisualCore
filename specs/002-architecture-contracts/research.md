# Research: Phase 1 architecture contracts

## R-F101 Binary targets outside the package root
- **Decision**: `VisualCoreRendering` declares `.binaryTarget(path: "../../External/projectm-ios/Build/ANGLEFrameworks/…")`.
- **Rationale**: The reference's own `ANGLERendering` uses `../../Build/ANGLEFrameworks/…` relative
  paths and builds and tests (baseline 13/13). There's no copy and no second build system (ADR-0002).
- **Alternatives**: copying the XCFrameworks into the repo (rejected: binary size and provenance);
  rebuilding (rejected: identical commit already built).

## R-F102 Pure package compiles on the macOS host
- **Decision**: `Packages/VisualCore` declares `platforms: [.iOS("26.0"), .macOS("15.0")]` with
  Foundation-only imports.
- **Rationale**: `swift test` on the host is the fastest gate (Constitution IV); the binary-target
  package cannot build for macOS because the XCFrameworks have no macOS slice (audit).

## R-F103 Enforcing dependency rules
- **Decision**: a stdlib Python checker that parses `Package.swift` dependencies and target names,
  `project.yml`/`*.yml` package references and `import`/`#include` lines, and builds a product graph
  for cycle detection (DFS).
- **Alternatives**: `swift package show-dependencies` (only external packages, no import scan).

## R-F104 Lifecycle observation model
- **Decision**: synchronous main-thread observer plus history (clarification 4).
- **Rationale**: EGL work must stay on the owning thread, and async streams would hop executors.
