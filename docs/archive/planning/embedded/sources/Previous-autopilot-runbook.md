# VisualCore — Autonomous iOS Graphics Suite

**Single-file, lossless master specification and unattended implementation runbook**  
**Edition:** 2026-11-10 · **Target:** new `VisualCore` Git repository · **Agent:** Claude Code + GitHub Spec Kit · **Primary build host:** macOS with full Xcode · **Scripts:** Python 3  
**Scope:** VisualCore framework, the existing `projectm-ios` reference application, independent VisualCore Showcase, **all 25 applications** in the original brainstorm, automated simulator testing, and automated *real-device* testing.

> **Start here.** This README is the sole authoritative **input**. The first part is an updated implementation policy, operational playbook, and an executable Python supervisor. The remainder includes the **complete, unabridged original README, original AppsBrainstorm, 25 application manuals, and their indexes**. These historical blocks are preserved byte-for-byte; they remain binding as product/algorithm/test requirements unless a canonical decision in Sections 1–17 explicitly updates an older engineering recommendation. The supervisor automatically extracts archived blocks into ignored working files, so Claude can read only the relevant documentation per stage instead of overwhelming its context with a ~1.5 MB prompt.

**No-interaction guarantee, correctly scoped:** after the operator has provisioned the Mac, installed/configured Claude and Xcode, and paired/trusted/provisioned at least one iOS test device, *routine implementation, testing, diagnosis, retries, checkpointing and reports require no responses from a human*. Apple signing, first device trust/Developer Mode, external account authentication, purchasing hardware, legal approval, and App Store publication are **not** silently bypassable. When a prerequisite cannot be satisfied programmatically, the agent must mark a blocking dependency and continue independent work where possible; it must never invent a green result.

## Navigation

1. [Mission and non-negotiable constraints](#1-mission-and-non-negotiable-constraints)
2. [Updated architecture and critical decisions](#2-updated-architecture-and-critical-decisions)
3. [The 25-app suite and dependency-aware execution order](#3-the-25-app-suite-and-dependency-aware-execution-order)
4. [Repository ownership, layout and dependency rules](#4-repository-ownership-layout-and-dependency-rules)
5. [Environment, bootstrap and one-command launch](#5-environment-bootstrap-and-one-command-launch)
6. [Copy-ready one-shot autonomous Claude prompt](#6-copy-ready-one-shot-autonomous-claude-prompt)
7. [Spec Kit: actual initialization and execution semantics](#7-spec-kit-actual-initialization-and-execution-semantics)
8. [Supervisor design and restart policy](#8-supervisor-design-and-restart-policy)
9. [VisualCore foundation: ten executable phases](#9-visualcore-foundation-ten-executable-phases)
10. [App implementation: 175 executable phase gates](#10-app-implementation-175-executable-phase-gates)
11. [Automated simulator and physical-device test strategy](#11-automated-simulator-and-physical-device-test-strategy)
12. [App-specific mandatory test and acceptance matrix](#12-app-specific-mandatory-test-and-acceptance-matrix)
13. [Quality/security/privacy/licensing policy](#13-qualitysecurityprivacylicensing-policy)
14. [Artifacts, telemetry, evidence and completion checks](#14-artifacts-telemetry-evidence-and-completion-checks)
15. [Failure handling, decision defaults and no-prompt policy](#15-failure-handling-decision-defaults-and-no-prompt-policy)
16. [Claude repository instructions to generate](#16-claude-repository-instructions-to-generate)
17. [Reference sources and source-fidelity contract](#17-reference-sources-and-source-fidelity-contract)
18. [Runnable Python supervisor (embedded)](#18-runnable-python-supervisor-embedded)
19. [Losslessly preserved source manuals](#19-losslessly-preserved-source-manuals)

---

## 1. Mission and non-negotiable constraints

Create a cohesive reusable graphics foundation, **not** 25 unrelated copies of a renderer and **not** 25 variants of ProjectM. Ship a reusable core and 25 real, separately buildable iOS/iPadOS products, with deterministic tests, defensible GPU behavior, tested lifecycle recovery, and auditable evidence for every feature. The suite includes VisualCore Showcase as an additional reference target; ProjectM remains a separately owned, pinned submodule.

The known starting point is the [`Coastrnaut/projectm-ios`](https://github.com/Coastrnaut/projectm-ios) source repository, in which the existing app uses **OpenGL ES through ANGLE's Metal backend**. **Audit this actual checkout first**; do not infer APIs or file names from a conceptual diagram. The project must not:

- reimplement or independently vendor ANGLE, EGL or the existing integration;
- switch the renderer to a speculative direct-Metal backend;
- pull MilkDrop / ProjectM engine or preset semantics into VisualCore;
- expose ProjectM as a required link dependency of unrelated apps;
- modify the submodule commit, upstream remotes, licenses or ProjectM source without a separate recorded change and reproducible regression evidence;
- assume broad iOS system-audio capture, arbitrary animated-home-screen wallpapers, or unapproved App Store capabilities;
- claim that a successful simulator build proves real-device ANGLE/Metal correctness;
- fabricate an Xcode project/scheme, device identifier, test run, benchmark, App Store credential, entitlement, scientific dataset or screenshot;
- replace passing tests with a statement that tests "should pass" or mark a blocked test as skipped/passed.

**Source of truth order on conflicts:** (1) Apple platform/security facts and repository/build evidence, (2) these canonical Sections 1–17, (3) versioned Spec Kit artifacts and reviewed ADRs, (4) preserved original VisualCore README, (5) preserved AppsBrainstorm, (6) individual detailed app manuals (for app-level product/algorithm particulars), (7) generated code. An app manual's **specific feature contract** should ordinarily override a vague portfolio summary; a canonical cross-app safety/platform decision wins over an older command or speculative API. Record every substantive change of interpretation in `docs/decisions/` and `docs/verification/requirements-trace.json`.

**Release and truthfulness:** “Implemented” means source and target exist; “Build verified” means Xcode exited successfully; “Simulator tested” means XCUITest/unit/integration evidence exists; “Device tested” means a named real iOS device executed signed code and saved an actual `.xcresult`; “Release-ready” means all mandatory gates are green. These terms are not interchangeable.

## 2. Updated architecture and critical decisions

### 2.1 Target dependency graph

```text
                           ┌──────────────────────────────────┐
                           │ 25 independent iOS/iPadOS apps   │
                           │ + VisualCore Showcase            │
                           └────────────────┬─────────────────┘
                                            │ app adapters, versioned models
            ┌───────────────────────────────▼───────────────────────────────┐
            │ VisualCore public, app-neutral Swift/native APIs             │
            │ Host, frame lifecycle, resources, shaders, effects, input,   │
            │ timing, scenes, audio features, diagnostics, test support     │
            └───────────────────────────────┬───────────────────────────────┘
                                            │ *shared integration*, not a new renderer
            ┌───────────────────────────────▼───────────────────────────────┐
            │ Existing ProjectM-derived ANGLE/EGL/OpenGL ES host boundary   │
            │ Context/surface ownership, GL command queue, presentation    │
            └───────────────────────────────┬───────────────────────────────┘
                                            ▼
                                ANGLE Metal backend → Apple GPU

  Separate reference consumer: External/projectm-ios (Git submodule)
  Separate ProjectM engine/preset logic; no graph edge from new apps to engine.
```

**Interpretation correction to the original README:** It is not established that existing ProjectM ANGLE/EGL host objects can be moved verbatim into a Swift package or shared across independent app processes. Phase 0 must audit build ownership, static/dynamic linkage, public symbols, Objective-C++ boundaries, EGL threading, binary size, deployment-target compatibility and licenses. If reusable packaging is initially blocked, implement a **thin, source-audited host integration** that consumes existing sources as configured; do not clone a second EGL lifecycle. When necessary, create a tracked ProjectM upstream patch/PR proposal, but do not silently edit the pinned reference checkout.

### 2.2 Decision log for unattended implementation

| ID | Architectural decision | Why this replaces or clarifies older material |
|---|---|---|
| ADR-001 | One **development monorepo** containing VisualCore and 25 independently shippable app targets. | The separate-repo suggestions in individual manuals remain documented options for future extraction; monorepo builds allow atomic shared-API migrations, tests and unattended dependency ordering. |
| ADR-002 | `External/projectm-ios` is a pinned Git submodule, initially treated as read-only. | Prevent source copying, attribution loss and accidental upstream ref changes. |
| ADR-003 | Existing ANGLE → Metal path is canonical for v1. | No competing Metal renderer or experimental graphics abstraction until a measured need is established. |
| ADR-004 | App domain logic and test fixtures are Swift/native CPU-first, independent of GPU. | Enables deterministic low-cost unit tests before graphics/device work. |
| ADR-005 | Dynamic graphics resources live on the renderer's documented owning context/queue. | A Swift `actor` or GCD queue does **not** by itself guarantee EGL context affinity; assert and test this explicitly. |
| ADR-006 | Simulation fixed timestep is independent of presentation cadence; validate units, precision and bounds. | Prevents numerical instability and hardware-dependent behavior. |
| ADR-007 | UI, text, settings and accessibility are native SwiftUI/UIKit; GPU presents scene imagery. | Keeps hit testing, VoiceOver, Dynamic Type and accessible navigation genuine. |
| ADR-008 | Asset, project and preset formats are versioned, validated and migration-tested. | Shader/scene reloads must not reinterpret stale data or persist GPU handles. |
| ADR-009 | App-specific shaders remain app-owned until a second consumer and tests justify extraction. | Avoids premature VisualCore bloat. |
| ADR-010 | Automated gates replace manual review checkpoints **without removing them from the traceability log**. | An unattended run needs measurable exit criteria, not unconditional approval by its own agent. |
| ADR-011 | Full-Xcode build host is macOS; Windows can edit specs/source, not replace native iOS testing. | Xcode command line, Simulator and signing are macOS requirements. |
| ADR-012 | Physical-device tests must be performed on previously trusted/developer-enabled devices and attached to real `.xcresult` artifacts. | Simulators and provider websites are not proof of device execution. |
| ADR-013 | Spec Kit uses **current Claude skills** under `.claude/skills/speckit-*/SKILL.md`, installed with `--integration claude --script py`. | Hyphenated Claude skills supersede the dotted examples in older source files. |
| ADR-014 | No automatic App Store publication, destructive Git cleanup, token rotation, unsafe network privilege escalation or license assumption. | Unattended coding does not authorize irreversible external actions. |
| ADR-015 | Product concepts are all implemented, but Store release remains per-app and evidence-gated. | Building 25 apps is not equivalent to shipping 25 approved listings. |
| ADR-016 | Results have four states: `pass`, `fail`, `blocked`, `not_run`; **never** silently turn failed required tests into optional ones. | Makes partial builds honest and resumable. |
| ADR-017 | Performance thresholds are measured against a pinned hardware baseline, not invented 60/120-fps promises. | Actual GPU and thermal constraints differ across supported devices. |
| ADR-018 | Audio capture is strictly opt-in with explicit source support and permission denial behavior. | iOS does not grant general-purpose capture of every other app's audio output by default. |
| ADR-019 | Wallpaper-related exports use genuinely available iOS share/save surfaces; never claim arbitrary system live-wallpaper replacement. | Avoids impossible features and App Review risk. |
| ADR-020 | Any code-generation, shader compilation, graph or file parser is bounded, recoverable and fuzz-tested. | The developer-tool apps accept untrusted user input and can exhaust GPU/CPU resources. |

### 2.3 Architectural APIs to validate, not invent

Audit and establish real interfaces for:

- `VisualCore` runtime: configuration, capabilities, renderer lifecycle errors, frame context, component/version compatibility;
- rendering host: EGL display/context/surface ownership, make-current contract, GL state isolation, touch/resize/background recovery and frame scheduling;
- `VisualCoreResources`: shader/program/texture/buffer/framebuffer ownership, allocation limits and context-loss rebuilds;
- `VisualCoreShaders`: GLSL packaging, compile/link diagnostics, uniform schema, cache keys and immutable shader variants;
- `VisualCoreEffects`: explicit DAG/pass graph, input/output texture and color-space declarations, cycle rejection, resource pooling;
- `VisualCoreInput`, animation, physics and scenes: event translation, camera/coordinate conventions, deterministic fixed-step update;
- `VisualCoreAudio`: consent-based source, FFT/envelope features and buffer-overrun/route-change handling **only when needed**;
- `VisualCoreDiagnostics` and test-support: CPU/GPU frame counters, memory, error injection, deterministic render snapshots, XCTest attachments;
- native bridges: Objective-C++/C++ ABI, Swift package/module boundaries, build-time linking and symbol ownership;
- platform: iOS/iPadOS supported deployment targets discovered from ProjectM and current SDK, with no speculative drop of working devices.

Avoid creating every proposed package on day one. Start with the smallest framework and one independently rendering scene, then split modules when ownership and dependency tests justify it. The earlier package lists are *candidate* names and must not be mistaken for discovered APIs.

### 2.4 Shared quality architecture

A validated app snapshot is a pure, versioned value model; the render frame consumes this snapshot and optionally a simulation tick; GPU resources are recreatable cache state. Use atomic persistence and migrations. Avoid GL object sharing across arbitrary threads; protect context creation/destroy from scene backgrounding and resize races. Use explicit color space, premultiplied alpha convention and orientation/scale units; record them in API docs. Use adaptive quality policies tied to evidence, accessibility policies (Reduce Motion, high contrast, scalable native text), and performance telemetry that is private by default.

## 3. The 25-app suite and dependency-aware execution order

All 25 apps from the original brainstorm are **required**. The suggested wave system is an implementation dependency order, **not** permission to omit the later apps. App manuals, including their original 7 unique phases, are fully embedded below.

| # | App target / product | Wave | Primary VisualCore pressure-test |
|---:|---|---:|---|
| 01 | Generative Art Studio | A | shaders, uniform controls, reproducible export |
| 02 | Fluid Art Playground | B | ping-pong FBO, stable fluid solver |
| 03 | Fractal Explorer | B | precision and zoom, shader performance |
| 04 | Particle Universe | B | instancing/buffering, deterministic particles |
| 05 | Infinite Geometry | C | geometry, camera, color pipeline |
| 06 | VisualCore Music Lab | C | permitted audio sources, FFT, beat features |
| 07 | Audio Odyssey | C | audio-to-camera dynamics, comfort controls |
| 08 | Oscilloscope Studio | C | audio acquisition, timebase and trigger accuracy |
| 09 | Digital Aquarium | A | animated agents, assets, long-running battery behavior |
| 10 | Neon Arcade | B | fixed-step game logic, input and scoring |
| 11 | Physics Playground | B | solver and contacts, deterministic replay |
| 12 | Tiny Worlds | C | procedural 3D scenes and streaming assets |
| 13 | Light Maze | B | deterministic ray/path puzzle solver |
| 14 | Solar System Explorer | C | scientific units, time, camera and catalog |
| 15 | Molecular Explorer | C | validated molecule parsing, 3D selection |
| 16 | Simulation Lab | A | CPU/GPU parity, cellular automata, numerical stability |
| 17 | Interactive Anatomy | D | licensed scientific asset hierarchy, selection, accessibility |
| 18 | Ambient Clock | A | native clock UX, background lifecycle, low-power motion |
| 19 | Living Wallpapers | B | available iOS export APIs, aspect and color fidelity |
| 20 | Digital Zen Garden | A | deterministic touch paths, undo, export |
| 21 | Aurora | A | layered shaders, long-running thermal controls |
| 22 | Shader Studio | D | bounded user GLSL, compile/error resilience |
| 23 | Visual Programming Lab | D | typed graph validation, cycle/resource protection |
| 24 | Graphics Benchmark Lab | D | reproducible physical-device benchmark methods |
| 25 | Effects Composer | D | render graph, effect chaining and cache correctness |

**Default unattended build order:** foundation F00–F09 → Apps 01, 09, 16, 18, 20, 21 → 02, 03, 04, 10, 11, 13, 19 → 05, 06, 07, 08, 12, 14, 15 → 17, 22, 23, 24, 25 → final suite validation. The embedded supervisor currently uses **numeric app-guide order** as a deterministic, dependency-safe conservative fallback because the foundation is built first and each app creates its own isolated targets. A future scheduler can use the above wave priority once dependency edges are verified, but may not skip any app or proceed past a failed dependency gate.

**Portfolio strategy:** VisualCore Studio (a later integrated creative toolbox), Digital Aquarium, and Simulation Lab are potential commercial focus products. The **Generative Art Studio** manual is the earliest independent shader consumer and its tests serve as the second-framework-consumer gate. The portfolio priorities and ranking criteria from AppsBrainstorm remain preserved; the autonomous implementer must not silently conflate product-market uncertainty with engineering acceptance criteria.

## 4. Repository ownership, layout and dependency rules

Create one Git repository, then build **25 different Xcode app targets and product-specific modules** in it. Keep ProjectM as an independently owned submodule, **not** an app library used by all 25. The app-specific repository layouts from the appended manuals map to per-app directories; e.g. standalone `GenerativeArtStudio/Packages/` becomes monorepo `Apps/GenerativeArtStudio/Packages/` or `Packages/Apps/GenerativeArtStudio/`, per an ADR. Their individual file names, models, shaders and fixtures are **not discarded**.

```text
VisualCore/
├── README.md                        # THIS file: sole original input, do not mutate mid-run
├── CLAUDE.md                        # generated short non-interactive policy
├── .gitignore / .gitattributes / .gitmodules
├── .claude/skills/speckit-*/SKILL.md # Spec Kit installed Claude skills
├── .specify/                         # Python Spec Kit scripts, constitution, templates
├── .github/workflows/              # macOS simulator builds, scheduled physical device runner
├── .autopilot/                       # ignored: context, logs, checkpoints, xcresults, evidence
├── External/projectm-ios/           # pinned git submodule (NOT copied/vendored)
├── Packages/
│   ├── VisualCore/                  # public API and integration
│   ├── VisualCoreRendering/         # existing ANGLE/EGL host reuse
│   ├── VisualCoreResources/
│   ├── VisualCoreShaders/
│   ├── VisualCoreEffects/
│   ├── VisualCoreInput/
│   ├── VisualCoreDiagnostics/
│   ├── VisualCoreTestSupport/
│   ├── VisualCoreScenes/            # only when justified
│   ├── VisualCoreAudio/             # opt-in only
│   └── ...                          # audited additional products, not empty scaffolds
├── Apps/
│   ├── VisualCoreShowcase/
│   ├── GenerativeArtStudio/
│   │   ├── App/ Features/ Views/ ViewModels/ Resources/
│   │   ├── Packages/               # app-local domain + rendering where appropriate
│   │   └── Tests/                  # unit, renderer, UI, device/fixtures
│   ├── FluidArtPlayground/
│   ├── FractalExplorer/
│   ├── ParticleUniverse/
│   ├── InfiniteGeometry/
│   ├── VisualCoreMusicLab/
│   ├── AudioOdyssey/
│   ├── OscilloscopeStudio/
│   ├── DigitalAquarium/
│   ├── NeonArcade/
│   ├── PhysicsPlayground/
│   ├── TinyWorlds/
│   ├── LightMaze/
│   ├── SolarSystemExplorer/
│   ├── MolecularExplorer/
│   ├── SimulationLab/
│   ├── InteractiveAnatomy/
│   ├── AmbientClock/
│   ├── LivingWallpapers/
│   ├── DigitalZenGarden/
│   ├── Aurora/
│   ├── ShaderStudio/
│   ├── VisualProgrammingLab/
│   ├── GraphicsBenchmarkLab/
│   └── EffectsComposer/
├── Tests/                    # shared contract and cross-consumer tests
├── TestAssets/               # deterministic audio, simulation and image fixtures
├── Tools/python/autopilot.py # EXTRACTED from Section 18 below
├── docs/
│   ├── architecture/         # real audited source and ABI/contracts
│   ├── decisions/            # ADRs, especially deviations from original manuals
│   ├── verification/         # traceability, suite-matrix.json, source paths, real evidence
│   ├── testing/              # device farm, runbooks, baselines
│   ├── product/              # portfolio and MVPs
│   └── release/              # privacy, licensing, signing, export compliance
├── specs/                    # one feature per bounded phase, generated by Spec Kit
├── scripts/                  # deterministic project generation/build/test helpers (Python)
└── VisualCore.xcworkspace    # only if project audit/generator establishes this as real
```

**Do not pre-create dummy Xcode files.** Discover and pick one consistent reproducible project format: an checked-in `.xcodeproj`/workspace or reviewed XcodeGen/Tuist configuration (not both opportunistically). Prefer one scheme per app and Xcode test plan(s) per supported configuration. All app schemes must be shared and scriptable; each app's bundle ID, entitlements and asset ownership must be isolated. Where VisualCore uses Swift Package Manager, audit linker/ObjC++/ANGLE compatibility instead of assuming all native code is pure SwiftPM-compatible.

**Dependency rule:** `AppUI → AppDomain / AppRenderingAdapter → VisualCorePublic → reusable rendering integration → existing ANGLE/Metal path`; `AppDomain` must build without importing ProjectM and preferably without VisualCore. Reusable modules must form an acyclic graph. Tests must assert **no** app target links ProjectM engine/preset symbols; ProjectM integration adapters live in a separate reference target. Favor public package boundaries and dependency inversion over cross-app direct imports.

**Git discipline:** stage task changes on feature branches, make small commits when identity is configured and checks pass, keep `main` releasable. Never reset or overwrite user changes; never alter credentials, remotes or PR settings without authorization. ProjectM patches are tracked proposals, not local silent submodule modifications. PR creation/pushing is optional and should happen only when an existing reviewed remote workflow permits; unattended local progress must not depend on an external approval step.

## 5. Environment, bootstrap and one-command launch

### 5.1 Pre-provision the host once

A continuously powered macOS builder is required for iOS implementation and test execution. For full physical-device validation, provide one or more **dedicated** iOS devices, USB or supported trusted network connection, signed developer credentials/test team, Developer Mode enabled, initial pairing/trust completed, adequate disk, and a supported Xcode/iOS runtime. These are external security boundaries; the autonomous agent cannot legitimately acknowledge the device's physical passcode/dialog on your behalf. A Mac mini with attached, auto-lock-managed dedicated test iPhone/iPad is a reasonable self-hosted device farm; simulator CI may run on a separate hosted Mac.

**Preflight terminal checks on the macOS builder:**

```bash
xcode-select -p                       # must point into a full Xcode app developer directory
xcodebuild -version
xcrun simctl list -j devices available
xcrun devicectl list devices
xcrun xcresulttool help get test-results summary
python3 --version
git --version
uv --version
claude --version
specify version
specify init --help
```

Full Xcode is required: Apple's standalone Command Line Tools package alone does **not** provide the Xcode tools or simulator/device environment. Use `xcodebuild -downloadPlatform iOS` when runtime provisioning is permitted and appropriate, after selecting Xcode. Set `DEVELOPER_DIR`/`xcode-select` explicitly for pinned CI builders. Do not auto-install a completely different Xcode version mid-run.

Install Spec Kit once if missing:

```bash
uv tool install specify-cli          # production: pin a reviewed release, record `specify version`
specify version
specify check
```

Install Claude Code according to its **current official** instructions. Authenticate before unattended use; test that its non-interactive mode can read and write an isolated throwaway repository. Choose an account/API budget, disk limits and watchdog policy suitable for a suite that may entail hundreds of bounded agent invocations; no cloud billing or rate limits are magically bypassed. Avoid enabling auto-update of build tools during a reproduction run.

### 5.2 Put this file in an empty/new repository root and extract the supervisor

**Only this README is needed as the specification input.** The command below extracts executable Python literally from Section 18 (the code lives in this document) and launches a deterministic, restartable controller. It generates temporary copies of all preserved source manuals inside `.autopilot/context/`, never requiring extra manually supplied files.

```bash
mkdir -p VisualCore
cd VisualCore
# Place this downloaded file at ./README.md, then run:
python3 - <<'PY'
from pathlib import Path
import re
source = Path('README.md').read_text(encoding='utf-8')
m = re.search(r'<!-- BEGIN AUTOPILOT PYTHON -->\n```python\n(.*?)\n```\n<!-- END AUTOPILOT PYTHON -->', source, re.S)
if not m:
    raise SystemExit('No embedded supervisor script found in README.md')
target = Path('Tools/python/autopilot.py')
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(m.group(1) + '\n', encoding='utf-8')
print('Created', target)
PY
python3 Tools/python/autopilot.py validate
python3 Tools/python/autopilot.py run --device-policy required-at-release
```

`run` initializes git if needed, installs missing Spec Kit through an already installed `uv`, initializes only missing Spec Kit Claude integration, validates all 27 original source blocks, pins/checks the ProjectM submodule, emits state/logs and drives bounded `claude -p` invocations. It **does not** automatically install Xcode, log into Claude, or fake Apple device pairing. Use `--device-policy optional` only for a clearly labeled prototype run; it cannot be represented as a fully device-verified release.

**Resume after interruption:**

```bash
python3 Tools/python/autopilot.py status
python3 Tools/python/autopilot.py run --device-policy required-at-release --max-attempts 5
# Increase --max-attempts only after diagnosing persistent failures; no stages are reset silently.
```

The supervisor supports `list`, `validate`, `status`, `run`, and `--only <stage-id>` for a carefully scoped smoke test. Every stage is enumerated from the **embedded manuals** rather than guessed. It records 10 foundation phases, seven phases for each of the 25 apps, and a suite-wide final audit: **186 tracked stages**.

### 5.3 If developing from Windows 11

Windows can edit this README and prepare files, but launch the controller **on a real Mac** via SSH or a checked-out Git remote. Example after provisioning SSH, macOS credentials and repository files:

```bash
ssh mac-builder 'cd ~/src/VisualCore && python3 Tools/python/autopilot.py run --device-policy required-at-release'
```

Do not present WSL, Docker-on-Windows, Hyper-V macOS guests or simulator emulation as equivalent to an Apple-supported Xcode physical-device test environment. An isolated macOS CI machine/VM with permitted Xcode installation and attached devices is the supported operational path.

### 5.4 Permission model for an unattended Claude Code process

The embedded controller defaults to Claude's **non-interactive `dontAsk` mode** and explicitly grants routine file/code/test tools (`Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash`, `Skill`). Verify the flags against `claude --help` and maintain a dedicated **least-privilege macOS runner**, preferably with disposable build directories and no production credentials. Allowing arbitrary shell execution is inherently high trust even if approval dialogs are disabled. Use Claude's sandbox/enterprise policy and system restrictions wherever available. The more permissive `--dangerously-skip-permissions` option exists but is **not a default or prerequisite**; consider it only for an isolated disposable worker with explicit organizational approval and no sensitive credentials. Never sacrifice credential safety to claim "zero prompts."

## 6. Copy-ready one-shot autonomous Claude prompt

This is the requested **single prompt** for starting the entire suite if Claude is being invoked directly. It instructs the agent to instantiate/run the supervisor and then continue automatically. **Recommended launch is the Python command in Section 5**, which survives context resets and carries truthful machine evidence across sessions. An interactive Claude session might terminate before 186 phases complete; the external supervisor is the reliable long-running driver.

**One-shot prompt text (copy into Claude Code while the shell working directory is the repository root):**

> You are the autonomous lead engineer and release-validation controller for the entire VisualCore iOS graphics suite. Treat `README.md` as the authoritative input. **Do not ask me any questions and do not stop for routine decisions.** Read canonical Sections 1–17 first, then read the relevant complete preserved source manuals from Section 19, or have the included Python supervisor extract them. Build the existing ProjectM-based VisualCore foundation, VisualCore Showcase, and **all 25 distinct apps** to their respective Phase 06 acceptance criteria. Preserve the existing ProjectM ANGLE/OpenGL ES → Metal path; keep `External/projectm-ios` pinned, independently owned and read-only unless a documented change is expressly authorized. Use installed Python-script Spec Kit (`--integration claude --script py`), the real `/speckit-*` Claude skills, plans/tasks/convergence gates, and testable code—not fabricated specs or stub demos. First extract the Python script embedded between `BEGIN AUTOPILOT PYTHON` and `END AUTOPILOT PYTHON` into `Tools/python/autopilot.py` exactly as directed in Section 5, check it with `python3 -m py_compile`, validate source SHA-256s, and start `python3 Tools/python/autopilot.py run --device-policy required-at-release`. Do **not** recursively launch the same controller from each of its child sessions. The controller owns the phase loop; its children own only their assigned phase. Repair bounded failures automatically; checkpoint after every stage; rerun real build/test commands; require actual `.xcresult` and physical-device evidence for release status. Respect account authentication, developer signing and first-device trust as non-bypassable gates. Do not mark skipped tests as passed or publish to the App Store. Use `docs/verification/suite-matrix.json`, `.autopilot/evidence`, versioned Spec Kit artifacts, per-stage logs and `.autopilot/final-report.json` to prove completion. If a true external prerequisite remains blocked, write its exact cause and continue other independent stages when safe, then exit with truthful incomplete status. Complete the whole suite without further human dialogue.

**Suggested non-interactive single launch on a preconfigured Mac** (this starts a Claude session to bootstrap the controller; prefer running the supervisor directly once extracted):

```bash
claude -p 'Read the canonical first 17 sections of README.md, then execute its Section 5 bootstrap exactly: extract the embedded Python supervisor, validate all preserved sources, and invoke its unattended run command once. Do not run another Claude child agent unless through the supervisor; do not modify the master README; never claim device tests passed without signed device XCTest .xcresult evidence. No questions. Report only verified final outcome or blockers.' \
  --permission-mode dontAsk \
  --allowedTools Read Write Edit Glob Grep Bash Skill \
  --max-turns 40
```

**Do not paste the entire ~1.5 MB README into `claude -p`.** Each stage's prompt points to generated `.autopilot/context/...` files, and the supervisor starts a fresh bounded process. Long implementation runs can span many process lifetimes and require steady storage/network/account access; there is no guarantee of 100% completion if physical resources or external services fail.

## 7. Spec Kit: actual initialization and execution semantics

The official modern CLI uses **`--integration claude`**, **`--script py`**, and **`--non-interactive`**. In an **already nonempty** new repository it is valid to use:

```bash
specify init --here --force --non-interactive --integration claude --script py
specify version
specify check
ls .claude/skills/speckit-*/SKILL.md
```

If a Spec Kit project already exists, **do not re-run forced init**; use `specify integration install claude --script py` only if the integration is missing, then inspect `specify integration status`. Modern Claude skill names are **hyphenated** and installed under `.claude/skills/`; older preserved `/speckit.specify` commands describe the same conceptual steps, not authoritative contemporary skill file names. `<PROJECT>` and `project.yml` in old docs are examples, never assertions about actual checkout state.

For every bounded feature, use these actual Claude Code skill invocations in sequence; root constitution once, later only when a documented ADR requires it:

```text
/speckit-constitution Define the existing ANGLE→Metal and submodule ownership rules, app independence, iOS device evidence and unattended non-fabrication gates.
/speckit-specify Specify exactly this stage and its functional and nonfunctional acceptance criteria from README's embedded manual.
/speckit-clarify Resolve ambiguities autonomously using the decision table and audited source, recording any unavoidable blocker; do not ask the user.
/speckit-plan Create an implementation plan grounded in discovered code and real SDK/VisualCore APIs.
/speckit-checklist Validate correctness, device tests, licensing, security, accessibility, and product-specific criteria.
/speckit-tasks Generate small dependent implementation tasks and their deterministic tests.
/speckit-analyze Check traceability and contradictions across spec, plan, checklist and tasks; fix discrepancies before code.
/speckit-implement Implement the bounded phase, write real code and tests, collect evidence.
/speckit-converge Cross-check implementation against every task and criterion and add/complete any gaps.
```

**Critical difference between setup and skills:** `specify init` is a **shell CLI command**; `/speckit-...` skills run **inside Claude**, not as standalone shell executables. Claude's actual installed `SKILL.md` files are the runtime authority. Do not suppress model invocation for an autonomous orchestrator (`--integration-options="--no-model-invocation"` would prevent a model-initiated skill call); the default Claude integration permits the `Skill` tool to invoke installed Spec Kit skills. If a skill is genuinely unavailable, treat the stage as blocked or use a documented compatible Spec Kit workflow—not a fake success message.

**Feature isolation:** `specs/` has a separate ID per foundation phase and per app phase. Ensure the active Spec Kit feature is the intended one; after each stage record the spec path and task/commit IDs. Avoid parallel `specify` feature operations within the same working tree to prevent conflicting active branches. Use a deterministic serial controller for correctness first; parallelize after explicit branch/worktree isolation and test-runner resource locks exist.

## 8. Supervisor design and restart policy

**Why this is necessary:** A single Claude chat trying to implement 25 full apps in one enormous prompt will hit context, cost, time or tool limits; a single `claude -p` call is not a persistent background daemon. The external Python supervisor is the process owner. It is deterministic, reconstructs its task list from preserved manuals, starts fresh bounded Claude child invocations, writes atomic JSON checkpoints, independently reruns proposed tests, and can resume.

State machine:

```text
PREPARED → PREFLIGHT → FOUNDATION F00..F09
                         ↓
                25 app groups × 7 phases
                         ↓
                  SUITE-FINAL GATE
                         ↓
              COMPLETE | INCOMPLETE

Each stage: pending → running → test_verified → passed
                                 ↘ failed/blocked → bounded retry → blocked
```

**Actual controller artifacts** are `.autopilot/state.json`, `host-inventory.json`, `source-index.json`, `context/`, `logs/`, `evidence/<stage>.json`, `final-report.json`. The 27 original manuals are SHA-256 verified before execution; generated context views are refreshed from this file on resume. The controller does not accept an LLM's `"pass"` declaration alone: it checks the referenced Spec Kit spec path, reruns all evidence commands with `subprocess.run(..., shell=False)`, verifies the exit statuses, and for release device tests checks the destination is a real iOS `id=` (not `iOS Simulator`), the physical-device `.xcresult` path exists, and `xcresulttool` can inspect it. The final suite stage additionally checks that all **25 unique app schemes/targets** are inventoried.

The controller currently uses a **conservative allowed executable list** for rerun commands. Do not relax that list to `sh -c` or `bash -c` just to make a failing feature pass. Prefer committed small `scripts/*.py` validators and real `xcodebuild test` invocations. Treat phase exit reports as control-plane input and re-execute the commands yourself.

**Checkpoint policy:** changes are kept on disk even after a failed stage; the stage is not marked passed. The next attempt receives its prior error and can repair the same files. Verified stages are never rerun unnecessarily on restart. Failed foundations stop dependent work; a failed app can be left blocked while independent app families continue; the final suite always reports incomplete if anything is missing. Increase `--max-attempts` intentionally when more retries are warranted. For crash recovery, inspect `status` then invoke `run` again. In a versioned implementation, add a content-hash invalidation DAG so that a later VisualCore public-API edit automatically re-verifies all affected apps; until that is implemented, the final suite regression run is mandatory after upstream shared-code changes.

**Finite resource policy:** bound child-agent turns, per-invocation execution time, retry count, test timeouts, Xcode parallelism, disk cache and API cost. On rate-limit/service outage, classify as transient, sleep/back off or exit with a resumable blocker—do not treat as an implementation defect. Never initiate an uncontrolled recursive set of Claude sessions. The supervisor's per-stage prompt explicitly forbids launching itself recursively.

**Supervisor hardening backlog, required before claiming unattended production reliability:** implement a PID/file lock, signals/watchdog and cleanup for killed child processes, stale-lock recovery, cost/usage cap, optional exponential backoff, file integrity checks for changing requirements, optional `--resume-id`, branch/commit capture, and a proper artifact retention policy. The embedded controller is a **reference implementation** and is intended to be extended and verified at F00–F01; it is not a pre-existing, production-qualified CI service. A project must not declare its own automation infrastructure flawless solely because this README contains executable Python.

## 9. VisualCore foundation: ten executable phases

Follow the **complete original nine-phase architecture plan** in the archived README and brainstorm; the task mapping here is intentionally expanded into 10 machine-executable stages, not a replacement of its technical details.

| Stage | Required result | Unattended quality gate |
|---|---|---|
| F00 | Repo/submodule pin; actual source inventory, Xcode project/schemes, source/license/ANGLE/EGL/Metal trace; baseline build/test diagnostics | Real build and reproducible inventory, documented failures; no production edit and no submodule bump |
| F01 | Constitution, ADRs, public API boundaries, dependency graph, GLESL/ObjC++/Swift bridge strategy | Contract reviewed against real code; package dependency checker; independent app stub feasible |
| F02 | Shared lifecycle host reuse: context/current thread, resize, surface, teardown, background/foreground, errors | EGL ownership assertions, lifecycle stress, device render smoke where available |
| F03 | Shader/texture/FBO/buffer/program services, caching, parameter schema, diagnostics | Resource leak/failure injection; compile/link/format checks; deterministic fixtures |
| F04 | Effects/pipeline graph, pass contracts, color model, render targets and caching | Multi-pass rendering, transparent/color correctness, bounded allocations |
| F05 | Input, scene transforms, animation, fixed-step simulations, camera and interaction | Deterministic simulation fixtures, cross-device state parity and input coordinate fixtures |
| F06 | Independent VisualCore Showcase target | Renders a scene **without ProjectM engine** and survives app lifecycle/device tests |
| F07 | ProjectM reference verification, compatibility baseline and authorized integration handoff | ProjectM still builds, renders, honors preset behaviors; Git submodule unchanged unless deliberate separate review |
| F08 | Second framework consumer (Generative Art Studio minimal independently useful vertical slice) | No ProjectM symbols; reproducible shader/preset interactions and export fixture |
| F09 | Framework hardening, API version, docs, CI, licenses and support matrix | ABI/dependency audit, stable device smoke and performance-baseline report |

Use a **strict source-backed exit**: if F00 cannot build the existing checkout, determine why and repair or document tool-chain blockers before claiming preservation of baseline. The key no-regression invariant is: ProjectM observable behavior does not change merely because framework code is shared. Compare the same pinned ProjectM commit, same configuration, same device/OS, same supported audio fixture/preset, and actual frames where permitted. No invented performance targets.

## 10. App implementation: 175 executable phase gates

Every app has **Phase 00–06**, totaling **175** app stages. Unlike generic phase templates, the **titles, algorithms, product scope, source layout, data model, shader assets, user journeys, risks, fixtures, and acceptance criteria** for each are read directly from its full preserved guide. The embedded supervisor extracts and checks those per-app phase titles automatically; it does not hallucinate filenames.

| Phase | Contract | Evidence needed before advancing |
|---|---|---|
| 00 — Boundary audit | Inspect actual VisualCore public packages, list `available`, `requires adaptation`, `upstream gap`; map the manual's standalone layout to monorepo without losing files | Per-app contract and tested VisualCore target boundary |
| 01 — Pure domain vertical slice | Implement manual's actual first domain/algorithm feature, strict schemas, errors, seed and fixtures | CPU unit tests, golden inputs, edge cases and initial native UX |
| 02 — Rendering vertical slice | Connect the first real ANGLE-backed scene/algorithm, threading and resource contracts | Real shader compile/link tests, render lifecycle and simulator smoke |
| 03 — Core full experience | Complete manual's third-phase interactions, state management and feature UX | App-specific integration/UI tests, save/restore when specified |
| 04 — Content, export and resilience | Add prescribed presets, assets, effects or sharing with privacy/licensing constraints | Deterministic export, migration, file round-trip, permission denial |
| 05 — Hardening and performance | Device-specific numerical/performance/accessibility/lifecycle checks prescribed by the manual | Real device tests when available, baselines and recovery stress |
| 06 — App release gate | Complete source manual's final verification/privacy/packaging/release requirements | Clean build, XCUITest, entitlement/credit audit, **real-device xcresult** |

**Important:** The above phases are *not* substitutions for the manuals' exact phase descriptions. Example: Fractal Explorer Phase 01 is complex-plane mathematics; Fluid Art Playground Phase 01 is ping-pong feedback validation; Shader Studio Phase 01 is compiler diagnostics/editor; Digital Aquarium Phase 01 is the habitat/content licensing contract. The supervisor passes the exact source manual and phase to each Claude invocation.

**Per-stage implementation discipline:** derive a spec from the original manual rather than blindly replaying its old shell commands; execute the current installed skill flow; verify actual VisualCore APIs before writing a bridge; implement small code + test slices; record `requirements-trace.json`, shader/program logs, golden fixtures and result bundle; do not hide risk by dropping work into later phases. The group ends only when the manual's Phase 06 criteria pass.

**Integration final stage (`suite-final`):** independently enumerate all 25 schemes and bundle IDs, build/test all, compare repeated common-resource usage, re-run ProjectM reference smoke and VisualCore Showcase, enforce one physical-device test per app (when device-policy required), check privacy licensing/size/accessibility, record cross-app perf data, produce `docs/verification/suite-matrix.json`, and write a complete/blocked final report. App Store publishing, marketing copy and paid accounts are excluded from unattended release.

## 11. Automated simulator and physical-device test strategy

### 11.1 Discovery before commands (no invented schemes, UDIDs or SDK)

The agent must determine the project's actual workspace/project, shared schemes, test targets, device destinations, signing team and OS range. Obtain a machine-readable test matrix from `xcodebuild -list -json`, `xcodebuild -showdestinations`, `xcrun simctl list -j devices available`, `xcrun devicectl list devices`, and any supported device-hub JSON commands (`xcrun devicectl help`). Store in `docs/verification/suite-matrix.json` and `.autopilot/host-inventory.json`. Do not insert a guessed `iPhone 16`/`iOS 18` device into an automated test run. Resolve installed Simulator runtime by availability, not string matching a user-facing current-phone brand.

Example discovery commands **after** the actual project exists:

```bash
xcodebuild -list -json -workspace VisualCore.xcworkspace        # only if workspace genuinely exists
xcodebuild -showdestinations -workspace VisualCore.xcworkspace -scheme ActualDiscoveredScheme
xcrun simctl list -j devices available
xcrun devicectl list devices
xcrun xcresulttool help get test-results summary
```

**Required test layers:** Python repository/license/pin checks → pure Swift/C/C++ unit tests → shader/GL integration tests → XCUITest simulator navigation and lifecycle → physical-device XCTest render and instrumented runs → cross-app regression/energy/thermal baselines → full archive/profile signing. Use a real Xcode project and reproducible `.xcresult` bundles, not mere `swift test` output from a host target.

### 11.2 Simulator automation

- Select a **real installed** iOS simulator runtime and device ID (e.g. parse `xcrun simctl list -j devices available`). Create/clone a simulator only after checking runtime availability and capacity.
- Boot and wait via `xcrun simctl boot <DISCOVERED_SIMULATOR_UDID>` then `xcrun simctl bootstatus <DISCOVERED_SIMULATOR_UDID> -b`; use isolated destinations to avoid parallel test conflicts.
- Execute actual discovered scheme:

```bash
xcodebuild test \
  -workspace <DISCOVERED_WORKSPACE>.xcworkspace \
  -scheme <DISCOVERED_SHARED_SCHEME> \
  -destination 'platform=iOS Simulator,id=<DISCOVERED_SIMULATOR_UDID>' \
  -derivedDataPath .autopilot/DerivedData/<APP> \
  -resultBundlePath .autopilot/xcresults/<APP>-sim-<RUN_ID>.xcresult

xcrun xcresulttool get test-results summary \
  --path .autopilot/xcresults/<APP>-sim-<RUN_ID>.xcresult
```

The `<...>` values are **deliberate placeholders**, never runnable as written; the supervisor/agent fills them using discovered data. If the app uses `.xcodeproj`, use `-project` instead of `-workspace`; use `build-for-testing` then `test-without-building` to amortize device-matrix execution. Collect failures/screenshots/activities with the current `xcresulttool` supported subcommands, and use XCTest attachments where image evidence is needed.

- Run unit and UI cases covering initial load, first scene, settings, navigation, persistence/export, state migration, orientation/size, accessibility IDs, permission denial, background/foreground, memory warning, shader failure and teardown.
- Compare deterministic renderer snapshots with explicit tolerances for OS/GPU differences; do not use brittle exact-pixel cross-device comparisons. Capture screenshot and app logs to `.autopilot/` when allowed. Simulator tests are **not** thermal, Metal-device performance, or device-signing certification.

### 11.3 Physical-device automation (pre-paired Mac farm)

Before the first test, an operator must provision a development team/certificates, trust/pair each test device, enable Developer Mode and supply device passcode/trust as Apple's UX requires. The test runner must **not** try to defeat these prompts. Once provisioned, it can select a discovered, reachable connected iOS device and run signed XCTest. Use USB for stable unattended operation where possible; use supported local Wi-Fi pairing only when the actual Xcode/iOS pair supports it.

```bash
xcrun devicectl list devices
xcodebuild -showdestinations -project <DISCOVERED_PROJECT>.xcodeproj -scheme <DISCOVERED_SCHEME>

# Use an actual reachable real-device destination from -showdestinations:
xcodebuild test \
  -project <DISCOVERED_PROJECT>.xcodeproj \
  -scheme <DISCOVERED_SCHEME> \
  -destination 'platform=iOS,id=<DISCOVERED_DEVICE_UDID>' \
  -derivedDataPath .autopilot/DerivedData/<APP>-device \
  -resultBundlePath .autopilot/xcresults/<APP>-device-<RUN_ID>.xcresult

xcrun xcresulttool get test-results summary \
  --path .autopilot/xcresults/<APP>-device-<RUN_ID>.xcresult
```

**Signing:** pin `DEVELOPMENT_TEAM`, tested signing style/identities and per-app bundle identifiers in secure CI configuration. Prefer separate test/development entitlements and deterministic signing checks. Never auto-accept a provisioning-device enrollment or modify another developer's account. Physical signing failures block **device** certification even if simulator builds are green.

**Real-device required scenarios:** cold/warm startup; EGL initialization with ANGLE Metal path verified by render/capability logs; repeated scene/preset transitions; orientation/size, app background/foreground and interruptions; context-loss simulation; memory pressure; long-session/energy/thermal drift; shader compile failures and malformed import; touches and native UI overlay response; audio route/permission changes where relevant; capture/export; GPU/CPU frame pacing distributions; iPhone + iPad when available; at least a supported older/lower-power device where available. Baselines must label real device model, OS, Xcode, ANGLE submodule commit, run timestamp, workload seed, test suite and pass/fail count.

**Important operational limitation:** a single device can become locked, disconnected or disabled by iOS updates; a perfectly unattended release pipeline needs a **pre-provisioned self-hosted macOS runner/device farm** with device-health checks, USB power management and an externally maintained trust/signing setup. Hosted macOS CI runners usually give simulators, **not** your physical iPhone. If no real device is present, the controller may build/test the rest of the suite and label `device_blocked`, but must not declare suite completion under `required-at-release`.

### 11.4 Test farm scheduling and capacity

Use one Xcode destination per test worker/device at a time; serialize GPU/performance runs and cool down devices between them to avoid measuring the previous app's heat. Split repeated smoke tests and long soak tests into different queues. Auto-detect device disconnection, low battery, disk exhaustion, signer expiration and OS/Xcode incompatibilities and requeue with a finite retry budget. Avoid simultaneous test plans that fight for the same simulator or physical device. Run a smoke subset on each change, nightly full simulator matrix, and regular/scheduled physical-device suite; **all** must be green for final release status.

### 11.5 Objective image and numerical validation

Use both quantitative and visual checks: shader compile/link and framebuffer completeness, image histogram/structural/perceptual metrics with documented tolerances, reproducible seed/time/palette, golden simulation arrays or scientific fixtures, accessible screen text assertions and screenshots attached to XCTest result bundles. For output whose appearance legitimately varies by GPU, record tolerance windows and compare domain invariants, not impossible bitwise-perfect frames. When benchmarking, keep repeated paired runs on same hardware and separate thermal throttling/recovery from steady state.

### 11.6 CI division

- **GitHub-hosted macOS CI**: checkout `submodules: recursive`, pin Xcode, install reviewed tools, validate SHA/pins/dependencies, run Swift/Python/unit/shader tests, build all 26 own app targets, simulator XCUITest, archive logs and `.xcresult`. Use locked/reviewed action versions, minimal permissions and security-scanned third-party steps.
- **Self-hosted Mac/device farm**: same immutable commit and tools, developer credentials, physical devices, XCTest, energy/thermal/long-run tests, private performance baseline artifacts, explicit success/failure back to CI.
- **Release aggregator**: fail closed unless both lanes completed for the same commit/target configs and all 25 apps have valid evidence. If optional device-policy was chosen, label the artifact *simulator-validated prototype*, not a device-certified suite.

## 12. App-specific mandatory test and acceptance matrix

This short matrix supplements, **never replaces**, the detailed unique testing sections in the 25 manuals. The agent must implement every per-app test fixture and risk mitigation from those manuals.

| # | Mandatory checks beyond common lifecycle/UI/build tests |
|---:|---|
| 01 | Same seed+time produces same image, invalid uniforms rejected, export dimensions/color fidelity, gallery migration. |
| 02 | Solver stability across frame rates/resolution, ping-pong nonaliasing, divergence/pressure reduction and splat bounds. |
| 03 | Complex-plane coordinate mapping, pan/zoom reversibility, precision-limit UI, bookmark restoration and tiled export. |
| 04 | Seeded emitters, spawn/death invariants, buffer capacity, frame drops under heavy load and device adaptive counts. |
| 05 | Mesh/index bounds, normals and winding, 2D kaleidoscope parity, camera transforms, cached geometry and export. |
| 06 | Mic/local-file audio with permission denial, FFT fixed-tone peak location, route changes and no unsupported cross-app capture. |
| 07 | Tunnel camera comfort, speed bounds, deterministic path, audio envelope response, Reduce Motion and long soak. |
| 08 | Timebase/trigger calibration, FFT/sine fixtures, cursor units/rounding, buffer drop behavior and route-loss UX. |
| 09 | Fish behaviors do not explode across fixed-step changes, habitat serialization, licensed assets, overnight idle power. |
| 10 | Fixed-step collision and scoring, touch latency, pause/restart, deterministic level fixtures, haptics-off behavior. |
| 11 | Contact/spring numerical energy bounds, collisions, drag and undo, extreme mass/NaN guards and replay. |
| 12 | Deterministic seed/mesh, bounds/LOD, camera traversal, scene-memory eviction, content pack licenses and persistence. |
| 13 | Optics/ray reflection fixtures and level solvability, controlled hint generation, selection and color accessibility. |
| 14 | Units/date/ephemeris approximate accuracy stated, clock/time jumps, camera scales, scientific sources and attribution. |
| 15 | XYZ/parser malformed input/fuzzing, atom-bond constraints, model picking/selection, scientific vocabulary and asset license. |
| 16 | CPU/GPU parity/tolerances, automata fixtures, reaction-diffusion/wave timestep stability and parameter guards. |
| 17 | Anatomy asset rights, region/layer attribution and anatomical correctness, accessibility, educational-not-diagnostic framing. |
| 18 | DST/time zone correctness, display/24h clock, long foreground idle energy, Reduce Motion and OLED/color safety. |
| 19 | Actual supported wallpaper-export/save/share workflow, orientation crop, color fidelity and **no impossible live-wallpaper API claim**. |
| 20 | Stroke geometry/undo deterministic behavior, save/migration/restore, touch pressure or drag range, export and idle power. |
| 21 | Noise/ribbon determinism, overdraw, multi-layer blend, motion comfort and long-run heat/battery impact. |
| 22 | GLSL compile errors and safe last-good fallback, memory/time caps, invalid shader sandboxing and diagnostics UX. |
| 23 | Typed node graph and cycle rejection, deterministic topological compile, resource budgets, malformed graph recovery and export. |
| 24 | Device ID, workload and clock normalization, cold/warm repeatability, thermal metadata, confidence intervals and real device only for GPU performance claims. |
| 25 | Effect DAG/chain correctness, ping-pong FBO safety, color/alpha consistency, cache invalidation and reversible edits. |

## 13. Quality/security/privacy/licensing policy

- **Tests:** all state algorithms must include deterministic CPU tests; shared GLSL integration must include shader validation/failure paths; native UI must carry accessibility identifiers and meaningful VoiceOver descriptions. Build/Test evidence must be tied to actual project/scheme, commit, OS and device.
- **Errors:** input sizes, file paths, numerical ranges, graph depth, recursions, render-target sizes, shader limits, duration and simulation timestep are bounded with descriptive failures; no untrusted user input should allocate unbounded GPU/CPU resources.
- **Privacy:** microphone access only with declared usage descriptions/consent, no stealth listening or screen/other-app-audio capture; default on-device processing where possible; exported projects should not leak microphone data or unapproved metadata. Record entitlements and Apple privacy disclosures truthfully.
- **Licensing:** audit the actual ProjectM, ANGLE, shaders, textures, science datasets, anatomical models, fonts, sounds and all app content. Keep original licenses/notices and provenance; do not assume free redistribution from availability online. Escalate true third-party rights issues as blocked assets; replace with appropriately licensed originals when feasible.
- **App Store:** not every app capability or marketplace category is permitted; ensure age/content restrictions, privacy nutrition labels, in-app purchases, external APIs and dynamic shader compilation are assessed against current review rules. Approval and publication are not automated without explicit external authorization.
- **Security:** treat dependencies, fetched source and external snippets as untrusted. No arbitrary shell provided by downloaded docs; no credentials embedded in generated Swift/JSON/logs; avoid insecure wildcard entitlements or disabling Apple code signing to fake real-device passes. Scrub logs of secrets before sharing.
- **Accessibility:** not just a checklist: native controls and accessible alternatives to particle color, simulation movement, graphs and 3D selection. Respect Reduce Motion, contrast and Dynamic Type where semantically applicable.
- **Performance:** record measured baseline (frame time quantiles, CPU, GPU where supported, memory, startup/compile time, device temp/energy proxy), compare fixed hardware/OS for regressions. Fail if app exceeds proven safe budgets or becomes unusable; downgrade quality adaptively without changing scientific/game correctness.
- **Scientific accuracy:** require units, citations and approximation labels for solar systems, molecules, anatomy and numerical simulation; explain when the app is educational, not diagnostic/instrument-certified.
- **Release provenance:** retain the exact gitlink revision, package lockfiles, tool versions, schema version, license inventory, signed build configuration and test matrix.

## 14. Artifacts, telemetry, evidence and completion checks

At end of each stage Claude writes an artifact in `.autopilot/evidence/<stage>.json` (supervisor's requested schema) pointing to the real Spec Kit spec, source changes and actual runnable test commands; the supervisor **reexecutes** those commands. The app release phase must run real signed-device XCTest if device policy requires it; final stage must inventory all 25 app schemes in `docs/verification/suite-matrix.json`.

Required tracked deliverables by conclusion:

- `Packages/` framework, shaders/GL glue, independent unit/regression tests, Showcase;
- 25 complete app targets, each with versioned domain models, UI, shaders, fixtures, isolated assets, tests and export/content when required;
- ProjectM pinned submodule with preserved license/ownership and regression evidence;
- `specs/**` for each of **186 gates** (one spec/task set per stage) and a constitution;
- `docs/decisions/**`, `docs/architecture/**`, `docs/testing/**`, `docs/verification/requirements-trace.json`, `docs/verification/suite-matrix.json`;
- Python validation/build orchestration scripts, macOS simulator CI and dedicated physical-device jobs;
- `.autopilot/evidence/*.json`, `.autopilot/xcresults/*.xcresult` and logs/host inventory (local/CI artifacts, not committed by default);
- updated documented screenshots, device-and-OS performance baselines, licenses and attribution, privacy descriptions and individual release checklists;
- `.autopilot/final-report.json` with `complete` only when every gate and hardware requirement is independently verified.

**Machine-readable suite matrix template** (the agent must replace placeholders with real discovered values; this is a schema example, not evidence):

```json
{
  "visualcore": {"revision": "ACTUAL_COMMIT", "angle_revision": "ACTUAL_PIN"},
  "projectm": {"submodule_revision": "ACTUAL_COMMIT", "build": "PASS_OR_FAIL"},
  "apps": [
    {
      "slug": "01-generative-art-studio",
      "scheme": "ACTUAL_DISCOVERED_SCHEME",
      "project_or_workspace": "ACTUAL_RELATIVE_PATH",
      "bundle_id": "ACTUAL_BUNDLE_ID",
      "unit_result": "ARTIFACT_PATH",
      "simulator_xcresult": "ARTIFACT_PATH",
      "device_xcresult": "ARTIFACT_PATH_OR_BLOCKED",
      "device_id": "DISCOVERED_REAL_DEVICE_ID"
    }
  ],
  "note": "Final generated matrix must contain exactly 25 unique entries."
}
```

**Acceptance:** the code compiles on a pinned Xcode toolchain, every app implements its **actual manual's MVP and Phase 06 definition of done**, all required deterministic fixtures and XCUITests pass, the ProjectM reference regression holds, tests run on at least one physical Apple iOS device with inspectable result bundles, licensing/privacy/accessibility checks pass, and all 186 independently verified gates are recorded. Any unmet mandatory condition leaves the report **incomplete**. Simulator builds are still useful progress and must be recorded accurately, but not sold as final device validation.

## 15. Failure handling, decision defaults and no-prompt policy

When Claude encounters ambiguity and no external trust/account barrier, it should **decide autonomously** within these constraints and record its decision:

1. **Unknown real API** → inspect actual header/source/build scheme and create a minimal executable test; never implement against a fictional API.
2. **Ambiguous scope** → implement the full MVP contract from the specific app manual; avoid expanding optional post-MVP ideas before release gates are satisfied.
3. **Performance choice** → choose simple robust GLES/ANGLE-compatible implementation, measure first, add adaptive tiering rather than speculative hardware features.
4. **Undocumented scientific asset** → use a correctly licensed, attributed and validated fixture; otherwise label the content subset incomplete instead of inventing facts.
5. **Dependency/tooling discrepancy** → use pinned existing tools if functional; if migration needed, write an ADR and regression check, never upgrade ANGLE/Xcode on a whim.
6. **Spec Kit ambiguity** → inspect `.claude/skills` and `specify --help`; invoke real installed names, not an older guide's slash syntax.
7. **Failed build/test** → isolate, reproduce, fix, re-run exact command, record evidence; bounded retries and truthful block state.
8. **Unavailable simulator runtime** → install approved runtime if permitted, or stop simulator certification and log prerequisite; do not relabel a host Swift test as XCTest.
9. **Unavailable signed device** → continue simulator implementation, mark release device gate blocked, do not bypass trust/Developer Mode.
10. **Unexpected input repo modifications or dirty submodule** → preserve user work; report inconsistency; do not run destructive `git reset --hard`/`clean -fdx`.
11. **User interaction requested by CLI** → switch to documented non-interactive flags if safe; otherwise report external prerequisite, **not** await stdin forever.
12. **App Store/legal/paid credential approval** → never guess approval or accept binding terms on user's behalf; leave that launch action gated.
13. **Source detail not represented by current canonical plan** → retain and trace it into app specs, implementation tasks and acceptance fixtures; do not silently omit it.
14. **No independent pass evidence** → stage stays unverified; do not change tests to always pass or silently mock the renderer.

**Unattended does not mean unbounded or unsafe.** It means no unnecessary questions and real progress with audited decisions until a technical/externally imposed boundary is reached.

## 16. Claude repository instructions to generate

Create/maintain `CLAUDE.md` early in F00 (separate from this immutable master README) containing the following concise policy, with actual discovered paths substituted:

```markdown
# VisualCore Claude Code Policy

Mission: autonomously implement and independently test the full VisualCore framework and 25 app suite from README.md. The root README's canonical Sections 1–17 prevail over archived historical commands; archived app manuals provide unique full product requirements.

Architecture: preserve projectm-ios's existing ANGLE/EGL/OpenGL ES → Metal integration; never invent or duplicate a renderer; ProjectM engine/presets never become required dependencies of apps. The ProjectM git submodule stays pinned/read-only unless a separately approved migration is actually recorded.

Workflow: operate as a bounded child of Tools/python/autopilot.py. Implement only the assigned stage. Invoke installed /speckit-* skills and write specs, tasks and real tests. Do not launch the parent supervisor recursively. Never modify root README.md or source archive. No routine human questions.

Accuracy: identify actual Xcode schemes, devices and VisualCore APIs from source/tool output. No invented pass/fps/performance/signing/entitlements or generic system audio capture/wallpaper features. Preserve each app manual's algorithms, schemas, fixtures, risks and definition of done.

Verification: run and document deterministic unit/integration/XCUITests, plus physical-device tests at release gate. Write stage evidence to .autopilot/evidence/<stage>.json with safely rerunnable argv test commands and the actual Spec Kit spec path. Parent supervisor reruns tests and owns pass/fail decisions. Explicitly report external blockers.

Security: do not exfiltrate credentials, publish to app stores, modify third-party submodule ownership, delete user work or bypass Apple trust/Developer Mode. Use minimum required permissions and reproducible dependency/toolchain pins.
```

## 17. Reference sources and source-fidelity contract

The canonical decisions above update the original attached architecture, but **all original detail remains visible below**: the full original VisualCore README (57 KB), original brainstorm (51 KB), all 25 app manuals (~1.35 MB), and the original navigation/index and source manifest. For fidelity, each source block is surrounded by `SOURCE-BEGIN` / `SOURCE-END` markers containing its SHA-256. The executable supervisor refuses to run if source hashes do not match or if any one of the 25 source manuals is missing. Preserve original block contents verbatim if editing the updated canonical runbook.

- GitHub Spec Kit: [official installation](https://github.com/github/spec-kit/blob/main/docs/installation.md), [quickstart](https://github.com/github/spec-kit/blob/main/docs/quickstart.md), [Claude Code integration](https://github.github.com/spec-kit/integrations/claude.html).
- Claude Code: [CLI reference](https://code.claude.com/docs/en/cli-reference) / `claude --help` (local installed version is authoritative).
- Apple: [Xcode command-line tools](https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference), [Xcode testing](https://developer.apple.com/documentation/xcode/testing), [real versus simulated devices](https://developer.apple.com/documentation/xcode/building-and-running-an-app), [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
- ProjectM reference: [Coastrnaut/projectm-ios](https://github.com/Coastrnaut/projectm-ios); inspect pinned checkout to verify actual integration and licensing.

**Reproducibility detail:** Source appendices below are **not** a second set of commands to execute indiscriminately. They preserve original reasoning, research, algorithms, per-app file lists, detailed Spec Kit prompts, UX, test matrices, product rankings and release requirements. Their older shell flags, repository split proposals, manual approval checkpoints and speculative project/target names are superseded by the canonical decision table when they conflict.

---

## 18. Runnable Python supervisor (embedded)

The following is the exact script extracted by the Section 5 bootstrap. It is stdlib-only and intended to live at `Tools/python/autopilot.py` once extracted. Do not execute the Markdown code block directly. For production use, review/extend its isolation, SIGTERM handling, rate-limit backoff, locks, artifact retention and budget controls as described in Section 8.

<!-- BEGIN AUTOPILOT PYTHON -->
```python
#!/usr/bin/env python3
"""Unattended VisualCore suite supervisor, embedded verbatim in README.md.

This script is intentionally stdlib-only. It does not fake build or device results.
Run on a pre-provisioned macOS host with Xcode and Claude Code configured.
"""
from __future__ import annotations
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
README = ROOT / 'README.md'
STATE_DIR = ROOT / '.autopilot'
LOG_DIR = STATE_DIR / 'logs'
EVIDENCE_DIR = STATE_DIR / 'evidence'
CONTEXT_DIR = STATE_DIR / 'context'
FOUNDATION = [
    'Repository bootstrap, pinned ProjectM submodule, baseline source, build, license and rendering audit',
    'Spec Kit constitution, public contracts, dependency constraints, architecture decision records',
    'Proven ANGLE/EGL rendering-lifecycle reuse and context ownership',
    'GPU resources, GLSL shader services, deterministic fixtures and diagnostic services',
    'Reusable, testable effect passes and frame-graph contracts',
    'Input, animation, scene primitives and simulation fixed-step services',
    'Standalone VisualCore Showcase, independent of ProjectM engine semantics',
    'ProjectM reference build and behavioral regression verification without unauthorized submodule edits',
    'Second independent consumer validation using Generative Art Studio thin vertical slice',
    'Public API review, CI, support matrix, compliance, documentation and VisualCore release gate',
]
SAFE_TEST_BINS = {'python3', 'python', 'xcodebuild', 'xcrun', 'swift', 'git', 'ctest', 'cmake'}
MANDATORY_SKILLS = ('constitution', 'specify', 'clarify', 'plan', 'checklist', 'tasks', 'analyze', 'implement', 'converge')


def stamp():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def atomic_json(path: Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    tmp.replace(path)


def command(argv, *, cwd=ROOT, timeout=1800, log=None, check=False):
    p = subprocess.run(argv, cwd=str(cwd), text=True, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout, env=os.environ.copy())
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(f'$ {argv!r}\nEXIT: {p.returncode}\n\n{p.stdout}', encoding='utf-8')
    if check and p.returncode:
        raise RuntimeError(f'Command failed ({p.returncode}): {argv!r}\n{p.stdout[-3000:]}')
    return p


def extract_sources():
    if not README.exists():
        raise RuntimeError('Place this exact README.md at the repository root before running.')
    s = README.read_text(encoding='utf-8')
    rx = re.compile(r'^<!-- SOURCE-BEGIN: (\S+) SHA256=([a-f0-9]{64}) -->\n(.*?)<!-- SOURCE-END: \1 -->', re.M | re.S)
    sources = {}
    for m in rx.finditer(s):
        name, digest, body = m.groups()
        if hashlib.sha256(body.encode('utf-8')).hexdigest() != digest:
            raise RuntimeError(f'Archived source integrity check failed: {name}')
        if name in sources:
            raise RuntimeError(f'Duplicate archived source marker: {name}')
        sources[name] = body
    apps = [k for k in sources if re.fullmatch(r'apps/\d\d-[a-z0-9-]+\.md', k)]
    if len(apps) != 25 or 'sources/README.md' not in sources or 'sources/AppsBrainstorm.md' not in sources:
        raise RuntimeError(f'Incomplete archive: {len(apps)} apps; missing source files?')
    return sources


def prepare_context(sources):
    CONTEXT_DIR.mkdir(parents=True, exist_ok=True)
    for key, content in sources.items():
        path = CONTEXT_DIR / key
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists() or path.read_text(encoding='utf-8') != content:
            path.write_text(content, encoding='utf-8')
    # These documents are generated views; README remains the only authoritative source.
    (STATE_DIR / 'source-index.json').write_text(json.dumps({
        key: hashlib.sha256(val.encode()).hexdigest() for key, val in sources.items()
    }, indent=2) + '\n', encoding='utf-8')


def app_jobs(sources):
    jobs = []
    for name in sorted(k for k in sources if re.fullmatch(r'apps/\d\d-[a-z0-9-]+\.md', k)):
        doc = sources[name]
        label = doc.splitlines()[0].removeprefix('# ').strip()
        phases = re.findall(r'^### Phase\s+(0[0-6])\s+[—–-]\s+(.+)$', doc, flags=re.M)
        if [x for x, _ in phases] != [f'{j:02d}' for j in range(7)]:
            raise RuntimeError(f'Invalid phase inventory in {name}: {phases}')
        slug = Path(name).stem
        for n, title in phases:
            jobs.append(dict(id=f'{slug}-p{n}', family='app', app=label, source=name,
                             phase=n, title=title.strip()))
    return jobs


def all_jobs(sources):
    foundation = [dict(id=f'visualcore-f{i:02d}', family='foundation', phase=f'{i:02d}',
                       title=t, source='sources/README.md') for i, t in enumerate(FOUNDATION)]
    suite = [dict(id='suite-final', family='suite', phase='final',
                  title='Integrate, build and physically test all 25 independent app targets and ProjectM',
                  source='sources/AppsBrainstorm.md')]
    return foundation + app_jobs(sources) + suite


def preflight(strict=True):
    requirements = ['git', 'python3', 'claude', 'xcodebuild', 'xcrun']
    missing = [v for v in requirements if not shutil.which(v)]
    if platform.system() != 'Darwin':
        missing.insert(0, 'macOS host (required for all iOS build/device gates)')
    if missing:
        raise RuntimeError('Missing host prerequisites: ' + ', '.join(missing))
    xcode = command(['xcodebuild', '-version'], timeout=60, check=True)
    if 'Xcode' not in xcode.stdout:
        raise RuntimeError('Full Xcode is not active (Xcode Command Line Tools alone are insufficient).')
    info = {'time': stamp(), 'host': platform.platform(),
            'xcode': xcode.stdout.strip(), 'claude': command(['claude', '--version'], timeout=60).stdout.strip(),
            'git': command(['git', '--version'], timeout=60).stdout.strip()}
    # Apple may require physical interaction to pair/trust/developer-enable the device.
    info['devices_raw'] = command(['xcrun', 'devicectl', 'list', 'devices'], timeout=60).stdout[-10000:]
    info['simulators_json'] = command(['xcrun', 'simctl', 'list', '-j', 'devices', 'available'], timeout=60).stdout[-25000:]
    atomic_json(STATE_DIR / 'host-inventory.json', info)
    return info


def bootstrap():
    if not (ROOT / '.git').exists():
        command(['git', 'init', '-b', 'main'], check=True, timeout=120)
    if not (ROOT / '.gitmodules').exists() and not (ROOT / 'External/projectm-ios').exists():
        command(['git', 'submodule', 'add', 'https://github.com/Coastrnaut/projectm-ios.git',
                 'External/projectm-ios'], timeout=2400, check=True)
    if (ROOT / '.gitmodules').exists():
        command(['git', 'submodule', 'update', '--init', '--recursive'], timeout=3600, check=True)
    if not shutil.which('specify'):
        if not shutil.which('uv'):
            raise RuntimeError('Install uv and specify-cli before starting; missing uv.')
        command(['uv', 'tool', 'install', 'specify-cli'], timeout=600, check=True)
    command(['specify', 'version'], timeout=60, check=True)
    if not (ROOT / '.specify').exists():
        # --force only acknowledges existing README/repository; never run on already initialized Spec Kit.
        before = hashlib.sha256(README.read_bytes()).hexdigest()
        command(['specify', 'init', '--here', '--force', '--non-interactive',
                 '--integration', 'claude', '--script', 'py'], timeout=900, check=True)
        if hashlib.sha256(README.read_bytes()).hexdigest() != before:
            raise RuntimeError('Spec Kit initialization modified README.md; restore authoritative copy.')
    else:
        # Initialize only missing Claude integration, preserving existing Spec Kit project.
        if not (ROOT / '.claude/skills/speckit-specify/SKILL.md').exists():
            command(['specify', 'integration', 'install', 'claude', '--script', 'py'],
                    timeout=600, check=True)
    missing_skills = [v for v in MANDATORY_SKILLS
                      if not (ROOT / f'.claude/skills/speckit-{v}/SKILL.md').exists()]
    if missing_skills:
        raise RuntimeError('Missing Spec Kit/Claude skills: ' + ', '.join(missing_skills))
    command(['specify', 'check'], timeout=120, log=LOG_DIR / 'specify-check.log')
    # Build outputs and generated reference views must not become source-of-truth commits.
    gitignore = ROOT / '.gitignore'
    additions = ['.autopilot/', '.build/', 'DerivedData/', '*.xcresult/']
    existing = gitignore.read_text(encoding='utf-8') if gitignore.exists() else ''
    updated = existing.rstrip('\n') + '\n' + '\n'.join(x for x in additions if x not in existing.splitlines()) + '\n'
    if updated != existing:
        gitignore.write_text(updated, encoding='utf-8')


def initial_state(jobs):
    path = STATE_DIR / 'state.json'
    readme_sha256 = hashlib.sha256(README.read_bytes()).hexdigest()
    if path.exists():
        data = json.loads(path.read_text(encoding='utf-8'))
        if data.get('readme_sha256') != readme_sha256:
            raise RuntimeError('Master README changed since checkpoint creation; reconcile run before resuming')
        old = [j['id'] for j in data['jobs']]
        new = [j['id'] for j in jobs]
        if old != new:
            raise RuntimeError('Job graph changed. Preserve/reconcile checkpoints before resuming.')
        return data
    data = {'created_at': stamp(), 'updated_at': stamp(), 'readme_sha256': readme_sha256,
            'jobs': [dict(j, status='pending', attempts=0)
                                                                  for j in jobs]}
    atomic_json(path, data)
    return data


def job_prompt(job, attempt, prior):
    source = f'.autopilot/context/{job["source"]}'
    skill_chain = ', '.join('/speckit-' + s for s in MANDATORY_SKILLS)
    return f'''You are an autonomous, non-interactive senior iOS and systems-engineering agent.
You are executing stage {job['id']}: {job['title']} (attempt {attempt}).
Read README.md canonical sections 1-17, and read this stage's full preserved source:
  {source}
For app stages, read the corresponding Phase {job['phase']} AND entire product contract,
algorithm, UX, tests, risks and acceptance criteria in that app's source manual.
For foundation stages, also read .autopilot/context/sources/AppsBrainstorm.md and
.autopilot/context/sources/README.md selectively; the canonical preamble prevails on conflict.
Use the REAL installed Spec Kit skills in order as appropriate: {skill_chain}.
Invoke the skills via the Skill tool (they are model-invocable in this integration); if a skill
cannot be invoked, explicitly record the blocker. Never just pretend that a skill was used.
Create/reuse exactly one active feature spec for this stage, with one constitution per repo.
Do not call any user-facing question tool. Resolve routine choices using README's decision policy.
No unauthorized ProjectM submodule edits; no alternate renderer; no fabricated measurements.
Implement only this stage and its required prerequisites; do not skip incomplete tasks.
Run relevant deterministic checks. Before reporting success, write JSON evidence at:
  .autopilot/evidence/{job['id']}.json
Evidence schema: {{"stage_id":"{job['id']}","status":"pass", "summary":"...",
"spec_path":"specs/.../spec.md", "tests":[{{"name":"...", "argv":["python3","..."],"cwd":"."}}],
"device_tests":"passed|pending|not_applicable", "notes":["..."]}}.
For every real code-change stage include test commands that can be rerun by the supervisor.
Tests argv must be actual executable argument arrays (NO shell pipes, redirections or placeholders).
The supervisor will independently rerun ALL listed tests; JSON alone is not proof.
If you cannot meet criteria, write status="blocked" with truthful reasons and do not disguise gaps.
Physical device tests cannot be claimed passed unless xcodebuild produced real .xcresult evidence.
Prior failure output (if any): {prior[-3500:]}
Finish with a short summary and stop; the supervisor will schedule the next stage.'''


def run_agent(job, attempt, previous, max_turns, permission_mode):
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    prompt = job_prompt(job, attempt, previous)
    (LOG_DIR / f'{job["id"]}-attempt{attempt}.prompt.txt').write_text(prompt, encoding='utf-8')
    argv = ['claude', '-p', prompt, '--output-format', 'json', '--max-turns', str(max_turns),
            '--permission-mode', permission_mode,
            '--allowedTools', 'Read', 'Write', 'Edit', 'Glob', 'Grep', 'Bash', 'Skill']
    proc = command(argv, timeout=10800, log=LOG_DIR / f'{job["id"]}-attempt{attempt}.log')
    return proc


def validate_evidence(job, device_policy):
    p = EVIDENCE_DIR / (job['id'] + '.json')
    if not p.exists():
        raise RuntimeError(f'No evidence written to {p}')
    data = json.loads(p.read_text(encoding='utf-8'))
    if data.get('stage_id') != job['id'] or data.get('status') != 'pass':
        raise RuntimeError(f'Stage did not declare passing evidence: {data.get("status")}')
    spec = data.get('spec_path', '')
    if not isinstance(spec, str) or not spec.startswith('specs/'):
        raise RuntimeError('Evidence missing valid Spec Kit spec_path')
    specpath = (ROOT / spec).resolve()
    if not specpath.is_relative_to(ROOT.resolve()) or not specpath.is_file():
        raise RuntimeError(f'Spec Kit specification missing: {spec}')
    tests = data.get('tests', [])
    if not isinstance(tests, list) or not tests:
        raise RuntimeError('Stage evidence must provide at least one independently rerunnable test')
    device_test_runs = []
    app_build_tests = 0
    for i, test in enumerate(tests):
        argv = test.get('argv')
        cwd = (ROOT / test.get('cwd', '.')).resolve()
        if not cwd.is_relative_to(ROOT.resolve()):
            raise RuntimeError('Test working directory escapes repository')
        if not isinstance(argv, list) or not argv or not all(isinstance(v, str) and v for v in argv):
            raise RuntimeError('Tests must use nonempty argv arrays')
        if Path(argv[0]).name not in SAFE_TEST_BINS or argv[0] != Path(argv[0]).name:
            raise RuntimeError(f'Unexpected test executable: {argv[0]}')
        if any(x in argv for x in ('-c', '-e', '--eval')) and Path(argv[0]).name in ('python', 'python3'):
            raise RuntimeError('Python inline scripts are not accepted as evidence; use a committed test file')
        verified_argv = list(argv)
        if verified_argv[0] == 'xcodebuild':
            app_build_tests += 1
            if '-resultBundlePath' in verified_argv:
                # Xcode refuses an already-existing bundle path. Our independent rerun
                # MUST create its own brand-new bundle, never reuse the agent's artifact.
                bundle_index = verified_argv.index('-resultBundlePath') + 1
                if bundle_index >= len(verified_argv):
                    raise RuntimeError('xcodebuild -resultBundlePath has no value')
                fresh_bundle = STATE_DIR / 'xcresults' / (
                    f'supervisor-{job["id"]}-{i:02d}-{time.time_ns()}.xcresult')
                fresh_bundle.parent.mkdir(parents=True, exist_ok=True)
                verified_argv[bundle_index] = str(fresh_bundle)
        result = command(verified_argv, cwd=cwd, timeout=2400,
                         log=LOG_DIR / f'{job["id"]}-verified-test{i:02d}.log')
        if result.returncode != 0:
            raise RuntimeError(f'Independent test #{i} failed: {argv!r}\n{result.stdout[-2200:]}')
        if verified_argv[0] == 'xcodebuild' and 'test' in verified_argv and any(
                v.startswith('platform=iOS,id=') for v in verified_argv):
            if '-resultBundlePath' not in verified_argv:
                raise RuntimeError('Device XCTest command requires a stored .xcresult bundle')
            idx = verified_argv.index('-resultBundlePath')
            if idx + 1 >= len(verified_argv):
                raise RuntimeError('Missing .xcresult path')
            bundle = (cwd / verified_argv[idx + 1]).resolve()
            if not bundle.exists():
                raise RuntimeError(f'Physical device result bundle was not written: {bundle}')
            summary = command(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary',
                               '--path', str(bundle)], timeout=120,
                              log=LOG_DIR / f'{job["id"]}-xcresult{i:02d}.log')
            if summary.returncode or not summary.stdout.strip():
                raise RuntimeError('Cannot inspect physical device XCTest result bundle')
            try:
                test_summary = json.loads(summary.stdout)
            except json.JSONDecodeError as e:
                raise RuntimeError(f'Physical device test summary is not valid JSON: {e}')
            if int(test_summary.get('totalTestCount') or 0) < 1:
                raise RuntimeError('Device XCTest bundle contains zero executed tests')
            if int(test_summary.get('failedTests') or 0) != 0:
                raise RuntimeError('Device XCTest result contains failures')
            device_test_runs.append(str(bundle))
    if job['family'] == 'app' and int(job['phase']) >= 2 and not app_build_tests:
        raise RuntimeError('Renderer/release app stage lacks an independently rerun Xcode build/test command')
    release_gate = (job['family'] == 'app' and job['phase'] == '06') or job['family'] == 'suite'
    if device_policy == 'required-at-release' and release_gate and not device_test_runs:
        raise RuntimeError('Release gate has no independently verified physical-device XCTest evidence')
    if data.get('device_tests') == 'passed' and not device_test_runs:
        raise RuntimeError('Evidence claims device pass but does not contain a real device test')
    if device_test_runs:
        data['device_tests'] = 'passed'
        data['device_xcresults'] = device_test_runs
    if job['family'] == 'suite':
        matrix_path = ROOT / 'docs/verification/suite-matrix.json'
        if not matrix_path.exists():
            raise RuntimeError('Missing suite-wide machine-readable app matrix')
        matrix = json.loads(matrix_path.read_text(encoding='utf-8'))
        apps = matrix.get('apps', [])
        if len(apps) != 25 or len({a.get('slug') for a in apps}) != 25:
            raise RuntimeError('Suite matrix must inventory 25 unique app targets')
        for app in apps:
            if not app.get('scheme') or not app.get('project_or_workspace'):
                raise RuntimeError(f'Suite matrix entry lacks build target: {app!r}')
            target = (ROOT / app['project_or_workspace']).resolve()
            if not target.is_relative_to(ROOT.resolve()) or not target.exists():
                raise RuntimeError(f'Suite matrix target is missing: {target}')
    data['verified_at'] = stamp()
    data['verified_by_supervisor'] = True
    atomic_json(p, data)
    return data


def status_summary(state):
    counts = {}
    for job in state['jobs']:
        counts[job['status']] = counts.get(job['status'], 0) + 1
    return counts


def write_report(state, device_policy):
    counts = status_summary(state)
    pending_device = []
    if device_policy == 'required-at-release':
        for job in state['jobs']:
            if (job['family'] == 'app' and job['phase'] == '06') or job['family'] == 'suite':
                e = EVIDENCE_DIR / (job['id'] + '.json')
                try:
                    obj = json.loads(e.read_text(encoding='utf-8'))
                    if obj.get('device_tests') != 'passed' or not obj.get('verified_by_supervisor'):
                        pending_device.append(job['id'])
                except Exception:
                    pending_device.append(job['id'])
    complete = counts.get('passed', 0) == len(state['jobs']) and not counts.get('blocked', 0)
    if device_policy == 'required-at-release' and pending_device:
        complete = False
    report_status = ('complete' if device_policy == 'required-at-release' else 'prototype_complete') if complete else 'incomplete'
    report = {'generated_at': stamp(), 'status': report_status,
              'counts': counts, 'jobs_total': len(state['jobs']),
              'device_tests_pending': pending_device, 'device_policy': device_policy,
              'source': 'README.md', 'definition': 'Only verified evidence can mark a stage passed.'}
    atomic_json(STATE_DIR / 'final-report.json', report)
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action', choices=('validate', 'list', 'status', 'run'))
    ap.add_argument('--max-attempts', type=int, default=3)
    ap.add_argument('--max-turns', type=int, default=100)
    ap.add_argument('--permission-mode', default='dontAsk')
    ap.add_argument('--device-policy', choices=('required-at-release', 'optional'),
                    default='required-at-release')
    ap.add_argument('--only', help='Optional stage id for a controlled test run')
    args = ap.parse_args()
    sources = extract_sources()
    jobs = all_jobs(sources)
    if args.action == 'validate':
        print(f'Archive intact: {len(sources)} embedded sources, 25 app manuals, {len(jobs)} phases')
        return 0
    if args.action == 'list':
        for j in jobs:
            print(f'{j["id"]:34} {j["title"]}')
        return 0
    state = initial_state(jobs)
    if args.action == 'status':
        print(json.dumps(write_report(state, args.device_policy), indent=2))
        return 0
    if args.max_attempts < 1 or args.max_turns < 5:
        raise RuntimeError('Invalid attempt/turn bounds')
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    # A process-held advisory lock prevents concurrent state/spec/Xcode mutations.
    lock_file = (STATE_DIR / 'autopilot.lock').open('a+')
    try:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise RuntimeError('Another autopilot controller is running in this checkout')
    preflight()
    prepare_context(sources)
    bootstrap()
    readme_hash = hashlib.sha256(README.read_bytes()).hexdigest()
    blocked_apps = set()
    foundation_failed = False
    for job in state['jobs']:
        if args.only and job['id'] != args.only:
            continue
        if job['status'] == 'passed':
            continue
        if foundation_failed:
            break
        if job['family'] == 'app' and job['app'] in blocked_apps:
            continue
        prior = ''
        for attempt in range(job.get('attempts', 0) + 1, args.max_attempts + 1):
            job['attempts'] = attempt
            job['status'] = 'running'
            job['updated_at'] = stamp()
            atomic_json(STATE_DIR / 'state.json', state)
            p = EVIDENCE_DIR / (job['id'] + '.json')
            if p.exists():
                p.unlink()  # evidence must be fresh for this attempt
            try:
                proc = run_agent(job, attempt, prior, args.max_turns, args.permission_mode)
                if proc.returncode:
                    raise RuntimeError(f'Claude exit={proc.returncode}; log: {proc.stdout[-3000:]}')
                if hashlib.sha256(README.read_bytes()).hexdigest() != readme_hash:
                    raise RuntimeError('README changed during run: authoritative input must remain immutable')
                validate_evidence(job, args.device_policy)
                job['status'] = 'passed'
                job.pop('error', None)
                break
            except (RuntimeError, subprocess.TimeoutExpired, ValueError) as e:
                prior = str(e)
                job['status'] = 'blocked'
                job['error'] = prior[-4000:]
                print(f'[{job["id"]}] attempt {attempt}/{args.max_attempts} blocked: {prior[-400:]}', flush=True)
            finally:
                job['updated_at'] = stamp()
                state['updated_at'] = stamp()
                atomic_json(STATE_DIR / 'state.json', state)
        print(f'[{job["id"]}] {job["status"]} ({job["attempts"]} attempt(s))', flush=True)
        if job['status'] != 'passed':
            if job['family'] == 'foundation':
                foundation_failed = True
            else:
                blocked_apps.add(job['app'])
    report = write_report(state, args.device_policy)
    print(json.dumps(report, indent=2))
    return 0 if report['status'] in ('complete', 'prototype_complete') else 2


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as err:
        print(f'AUTOPILOT BLOCKED: {err}', file=sys.stderr)
        raise SystemExit(2)
```
<!-- END AUTOPILOT PYTHON -->

