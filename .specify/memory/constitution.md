# VisualCore Suite Constitution

Scope: the VisualCore monorepo — VisualCore framework packages, the Showcase, the ProjectM
reference adapter and 25 independent iOS/iPadOS apps. Canonical sources: root `CLAUDE.md` and
`README.md` chapters 1–18; archived manuals (README §20) are extracted to `.autonomy/context/`.

## Core Principles

### I. Proven Renderer Only (NON-NEGOTIABLE)

- All GPU imagery uses OpenGL ES 3.0 through EGL on the owner's ANGLE fork Metal backend
  (`Coastrnaut/angle`, `ios` branch, prebuilt in `External/projectm-ios/Build/ANGLEFrameworks`).
- No second renderer, no direct-Metal replacement, no invented public EGL bridge.
- GL entry points are resolved with `eglGetProcAddress`; `dlopen`/`dlsym` are forbidden.

Rationale: the ANGLE → Metal path is the only renderer with recorded device evidence.

### II. App-Neutral Public API

- VisualCore modules expose render host, frame lifecycle, resources, shaders, effects graph,
  scenes, input, timing, optional audio features, diagnostics and test support.
- ProjectM engine and preset types MUST NOT appear in VisualCore or any of the 25 apps; this is
  verified by package dependency graphs and linked-symbol scans of built products.
- `External/projectm-ios` is pinned and read-only; engine changes go upstream as logged patches.

### III. Explicit GPU Lifecycle and Thread Ownership

- Render hosts follow the state machine
  `uninitialized → surfaceReady → active → suspended → surfaceInvalid → reinitialized → destroyed`.
- GPU handles carry the generation of the context that created them; stale handles are rejected.
- Each EGL context has exactly one owning thread; a Swift actor is not an EGL-thread guarantee.
- Context loss, resize and background transitions MUST be recoverable without crashing.

### IV. Host-Testable Domain Logic, Test-First

- Models, simulations, parsers, graphs, DSP and math live in pure Swift modules tested with
  `swift test` on the Mac host; GPU code is verified on iOS simulators with pixel readback.
- Simulations are deterministic: fixed timestep, explicit seeds, NaN/Infinity guards, bounded
  iteration counts and reference fixtures from independent formulas.

### V. Implementation Before Devices (NON-NEGOTIABLE)

- Campaign I = F00–F09, 175 app gates, IMPLEMENTATION-LOCK. No physical-device install, launch or
  test happens before `python3 Tools/python/desktop_runbook.py guard-device` passes.
- Campaign II runs all 25 apps on D1, then D2, then D3 (75 rows). D3 stays on iPadOS 26.5.

### VI. Evidence Over Assertion

- A gate passes only with `run-check` attestations: real command, exit 0, hashed log.
- Tasks are ticked only with `— Verified YYYY-MM-DD: <command/result>`.
- Simulator results are never performance or compatibility evidence; agent reports are not
  evidence. No fabricated waivers; owner-only steps are recorded as `BLOCKED_OWNER_ACTION`.

### VII. Native, Accessible UI

- SwiftUI/UIKit own navigation, controls, help and permissions; the GPU owns imagery only.
- Every app supports VoiceOver labels, Dynamic Type, Reduce Motion, Reduce Flashing
  (photosensitivity limiter), non-color state cues and iPhone and iPad layouts.

### VIII. Public Apple APIs, Privacy and Truthful Capabilities

- No private APIs, ReplayKit capture workarounds, invented background modes or fake live
  wallpaper installation.
- Audio uses documented permissions only; realtime callbacks are lock-free and allocation-free;
  captured audio is not retained by default.
- Each app's `PrivacyInfo.xcprivacy` is audited against the built product. Networking is allowed
  only when the app's specification justifies it.

### IX. Bounded Untrusted Input

- Shader source, node graphs, imported files and effect DAGs are size-, time- and
  memory-limited and cycle-checked.
- Persisted formats are versioned with migrations; writes are atomic and never destroy prior user
  work.

### X. Licensing and Provenance

- Every shader, dataset and asset records its source and license. ANGLE notices ship with every
  app that embeds ANGLE. projectM (LGPL-2.1) linkage is analysed before any distribution.
- Scientific content cites sources, units and uncertainty.

## Technology Constraints

- iOS/iPadOS deployment target 26.0; Swift 6 language mode with strict concurrency.
- XcodeGen 2.46.0 `project.yml` is the project source of truth; generated `.xcodeproj` is
  gitignored. Reusable logic lives in SwiftPM packages under `Packages/`.
- Signing: committed `Configs/Signing.xcconfig` contains only
  `#include? "Signing.local.xcconfig"`; simulator and generic-iOS builds use
  `CODE_SIGNING_ALLOWED=NO`. Teams, certificates and profiles are owner-provisioned.
- Reference toolchain pins live in `Configs/toolchain.json` and are verified, never silently
  upgraded.

## Development Workflow

- Spec Kit skills (`.claude/skills/speckit-*`) run inside the Claude Desktop Code session; the
  Claude CLI is never invoked.
- Each feature uses unique ID namespaces (foundation `FR-F###`/`SC-F###`/`T-F###`; app NN
  `FR-ANN-###`/`SC-ANN-###`/`T-ANN-###`/`R-ANN-##`), validated by `scripts/validate_docs.py`.
- Commit locally after verified tasks, LF line endings, no co-author or generator trailers; no
  push to any remote without explicit owner authorization.
- One writer per repository file; at most 10 concurrent agents; one Xcode/test lane per Mac.

## Governance

- Precedence: real Apple/toolchain behavior → canonical README chapters 1–18 and `CLAUDE.md` →
  this constitution and ADRs → archived source documents → generated code.
- Amendments use semantic versioning (MAJOR: principle removal/redefinition; MINOR: new or
  materially expanded principle/section; PATCH: clarification) with a dated rationale in
  `docs/decisions/`.
- Owner-only decisions (signing, App Store Connect, purchases, remote publication, D3's OS) cannot
  be amended or waived by an agent.
- Every gate review checks compliance with Principles I–X; `scripts/check_compliance.py` enforces
  the mechanically checkable rules.

**Version**: 1.0.0 | **Ratified**: 2026-11-10 | **Last Amended**: 2026-11-10
