# Implementation Plan: Phase 9 — Stabilization, Documentation and Release

**Branch**: `010-stabilization-release` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

Make VisualCore release-candidate ready (`1.0.0-rc.1`): a public-API review with a committed baseline and doc-comment
enforcement; the AutomationRunner for the device campaign (debug/measurement builds only, verified absent from a
Release build); shader validation and a resource-cleanup sweep; host and simulator performance baselines (non-device);
a license/notice inventory with an LGPL analysis; documentation (index, getting started, module overview, support
matrix, known limitations); CI on GitHub Actions for everything that does not need the local ANGLE build; a
`scripts/release_check.py` that runs every step and summarizes; version bump and release notes.

## Technical Context

**Language/Version**: Swift 6.4.2, Python 3, GitHub Actions YAML · **Primary Dependencies**: existing packages and
scripts · **Testing**: script tests (`test_scripts.py`), host `swift test`, simulator XCTest (shader validation,
cleanup), Showcase automation runs on simulators, `nm` on a Release build · **Target Platform**: iOS/iPadOS 26.0+ ·
**Constraints**: no device claims (constitution V), no signing in CI, reference read-only · **Scale/Scope**: ~4 scripts,
1 module filled (VisualCoreAutomation), 1 executable target, ~8 docs, 1 workflow.

## Constitution Check

I PASS · II PASS (API review keeps engine types out) · II-a PASS · III PASS (cleanup sweep) · IV PASS · V PASS (matrix
marks devices pending) · VI PASS (release check records every step) · VII PASS (docs cover accessibility) · VIII PASS
(automation has no remote trigger; zero symbols in Release) · IX PASS · X PASS (license inventory + LGPL analysis).
Post-design: PASS.

## Project Structure

```text
scripts/{check_public_api,check_licenses,release_check,run_automation_sim}.py   (+ tests in test_scripts.py)
docs/api/visualcore-public-api.txt
docs/{index.md,getting-started.md}, docs/release/{support-matrix,known-limitations,release-notes-1.0.0-rc.1}.md
docs/legal/{THIRD_PARTY_NOTICES.md,lgpl-analysis.md}, docs/performance/{baselines-host.json,baselines-simulator.json,README.md}
Packages/VisualCore/Sources/VisualCoreBaselines/main.swift (executable)
Packages/VisualCoreRendering/Sources/VisualCoreAutomation/{AutomationRunner,AutomationReport}.swift
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/{ShaderValidationTests,CleanupSweepTests}.swift (+ effects)
Showcase/App/ShowcaseApp.swift (automation hook), Showcase/Tests/Unit/ShaderValidationTests.swift (bundled shaders)
.github/workflows/ci.yml
```

## Complexity Tracking

None.
