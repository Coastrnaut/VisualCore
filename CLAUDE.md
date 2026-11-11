# VisualCore Suite — Claude Code Desktop repository instructions

**Applies to the new VisualCore monorepo, not the existing `Coastrnaut/projectm-ios` repository.**
**Primary operator:** Claude Code in the **Code tab of Claude Desktop**, using a **local session on the project Mac**. Do not use Claude Code CLI, `claude -p`, the Claude Agent SDK, or a Python subprocess that invokes Claude. This file is the concise mandatory agent contract; **`README.md` is the full product and engineering specification**, including unchanged archived versions of the original VisualCore README, AppsBrainstorm, all 25 app implementation manuals, the owner's original ProjectM-iOS `CLAUDE.md`, and `devices.md`.

## 1. Mission and order of operations

Implement VisualCore, the standalone Showcase, the pinned ProjectM reference adapter, and **all 25 real, independently buildable iOS/iPadOS apps** in the comprehensive README. Execute two strict campaigns:

1. **IMPLEMENTATION campaign:** fully build the reusable infrastructure and all 25 apps, with Spec Kit specifications, reviews, code, assets, genuine features, host unit tests, compile validation, and automated simulator/integration tests. Do not run a physical-device test during this campaign. The last step is a machine-verifiable **implementation lock** proving the entire suite is present and simulator-verifiable.
2. **PHYSICAL-DEVICE campaign:** only after the implementation lock, run the entire suite across **D1, then D2, then D3**, sequentially and without interleaving routine new-app implementation. Perform per-app functional, rendering, audio/privacy, lifecycle, performance and accessibility checks as applicable. Record real per-device evidence. Fix campaign failures with targeted changes, rerun affected tests and shared regressions, but preserve the audit trail.

App implementation is **not** the same as passing device tests; neither is the same as App Store approval. No simulated or fabricated evidence; a blocked gate stays blocked.

## 2. Operating Claude Desktop

- Start from Claude Desktop > **Code** > local project folder. Use **Auto** permission mode if available and authorized, never bypass permissions by default. Desktop's Auto mode runs routine actions through its safety classifier and may still ask. One-time trust, signing, authentication and physical-device actions cannot be promised as zero-touch.
- For resilience, optionally create **one local scheduled task** in Claude Desktop Code, named `visualcore-continue`, targeting this repo with Auto mode and a continuation prompt that reads `.autonomy/state.json`, obtains `.autonomy/desktop.lock`, runs the next pending gate, verifies it, writes evidence, and repeats until time/context limits. The Mac must remain awake and the Desktop app must remain open. Schedule through the Desktop UI, **not** by spawning a Claude CLI process.
- A scheduled or manually resumed session always begins by reading this file, then canonical README chapters, `python3 Tools/python/desktop_runbook.py status`, then the relevant extracted archived guides. When changing sessions, rely on on-disk evidence and commits, never claimed memory.
- One writing session at a time for integration and shared build files. Other Desktop sessions may analyze separate features in git worktrees, but cap all agents/subagents at **10** concurrently. Only one writer per repo file and at most one Xcode/device-test lane per Mac. Make changes in the canonical integration worktree; merge reviewed changes only.
- Do not recursively create schedules, spawn self-replicating agents or automate UI clicks against the Desktop app. The Desktop Code session is the agent; Python scripts are deterministic tools, **not** hidden Claude API/CLI drivers.
- Do not stop at an app stub, prototype screen, incomplete pass/fail audit, or partial set. Only an actual external blocker or host/session limit justifies pause; preserve state and resume when a new Desktop session starts. No repeated routine questions: choose within existing policy and log the decision.
- **Owner standing approval (2026-11-10): work completely autonomously. Do not prompt the owner for anything; continue through every question and gate.** Decide every routine and clarify question yourself (recommended option), record it in the spec/ADR, and keep going without pausing for confirmation or ending turns with questions. This does **not** extend to the owner-only boundaries in §5/§6 (signing, App Store/purchases, remote push, D3 OS, physical unlock/trust/permission prompts). Record those as `BLOCKED_OWNER_ACTION` and continue with unblocked work instead of asking.
- **Owner instruction (2026-11-10, reaffirmed): use best judgement and operate completely autonomously; never wait for the owner's approval for anything and never stop for a decision under any circumstances.** For every choice (design, naming, scope, tooling, test strategy, placeholder branding, fix vs. defer), evaluate the options, pick the best one, record the choice and rationale in the spec/ADR, and continue. Placeholder identities are owner-approved (2026-11-10): Showcase bundle id `dev.visualcore.Showcase`, name "VisualCore Showcase", harness ids `dev.visualcore.harness.*`; follow the same `dev.visualcore.<Name>` pattern for new targets. Hard limits that no approval can lift (Anthropic safety rules and §5/§6): never enter credentials, sign in, purchase, submit to App Store Connect, change signing teams/certificates/profiles, touch device OS versions or answer physical-device trust/permission prompts — record these as `BLOCKED_OWNER_ACTION` without pausing and continue with all other work.
- **Owner instruction (2026-11-10): never stop working.** Completing a task, a Spec Kit command, a feature, a sealed gate, a batch of gates or any other milestone is **never** a reason to end the turn or pause. After each seal, immediately start the next gate (`python3 Tools/python/desktop_runbook.py status` → next pending) and keep going through all 10 foundation gates, all 175 app gates, the implementation lock and the device campaign. Do not end a turn with a summary while unblocked work remains; give progress updates in passing and continue. Only an actual host/runtime limit (the session or context is forcibly ended) interrupts work, and the next session resumes from on-disk state without waiting to be asked.
- **Owner instruction (2026-11-10, after a second stop): never end a turn while waiting.** Root cause of the second stop: a long check was started with `run_in_background`, then the turn was closed with a summary while it ran.
  - Run long builds and tests in the foreground with explicit timeouts, splitting them into steps of 10 minutes or less (`release_check.py --only/--skip`) when needed.
  - If something must run in the background, continue other unblocked work in the same turn and collect the result in the foreground.
  - Never call the Desktop `wrap_up` tool, end a turn or write a closing summary while unblocked work remains. Answer owner questions in passing without stopping.

## 3. Governing documents and conflicts

Use the following precedence: real Apple/toolchain behavior and successful observed tests; these new canonical README chapters and this repository contract; newly created Spec Kit constitution/spec/contracts/ADRs; archived source documents (whose full text remains preserved); generated code. An app manual's specific requirements supersede generic portfolio descriptions unless an updated canonical safety/platform rule explicitly says otherwise. Never delete an original requirement merely because it is difficult: label it implemented, deferred post-MVP, inapplicable with documented reason, or blocked. Maintain source-to-implementation traceability.

The **original ProjectM-iOS CLAUDE.md** is a historical reference: it describes decisions, approvals, test results, and milestones *in that repository*. Those are not proof that VisualCore or its 25 new apps work. Its permission to push `origin/main`, waiver decisions, project-specific app ID, pricing and signing arrangements do **not** automatically transfer to this new repository.

## 4. Hard architecture boundaries

- The only established renderer baseline is **OpenGL ES/EGL through the owner's ANGLE fork's Metal backend**, already integrated in [`Coastrnaut/projectm-ios`](https://github.com/Coastrnaut/projectm-ios). Audit actual sources and build commands. **Do not build a second renderer, replace ANGLE with direct Metal, invent a public EGL bridge or duplicate its lifecycle.**
- Treat `External/projectm-ios` as a **pinned, initially read-only submodule**. Its internal `Vendor/projectM` points at `Coastrnaut/projectm`, `ios` branch; its `Vendor/angle` points at `Coastrnaut/angle`, `ios` branch. The original guide recorded ProjectM commit `c88894e` for a particular milestone; inspect the **actual** pin and never blindly reset it. A genuinely necessary engine change belongs as an upstream-ready patch with a patch log and clean provenance, not an untracked rewrite.
- `gclient sync` can place **~12 GB** in the ANGLE dependency tree. Do not move, delete, rename or run destructive cleanup inside `Vendor/angle`. Only write generated ANGLE framework artifacts to the owning project's documented `Build/ANGLEFrameworks` (mind case-insensitive macOS filesystems). Run the existing `scripts/build_projectm_xcframework.py` and `scripts/build_angle_xcframework.py` **within the actual ProjectM checkout**, if present and compatible, before assuming a usable framework.
- ProjectM engine/preset interfaces stay out of the app-neutral VisualCore public API. Its ~12,847 usable preset library (after previously documented exclusions) is reference-app content, not automatically a dependency or licensed asset bundle for all 25 apps. Third-party packs remain pinned shallow submodules and generated indexes are build artifacts.
- App-neutral modules contain render host, frame lifecycle, resources, shaders, effects, scenes, input, timing, optional audio-feature adapters, diagnostics and test support. Native SwiftUI/UIKit owns application UI, accessibility and permissions. Validate EGL thread/context ownership and context loss explicitly; a Swift `actor` is not itself an EGL-thread guarantee.
- Each new app lives under `Apps/<AppName>/` with its own target, domain models, settings, scenes/shaders, tests, icons/privacy data and product definition. Share only proven reusable components. Keep SwiftPM package logic host-testable or Linux-testable when possible.
- **Owner instruction (2026-11-10): maximize reuse in VisualCore.** When building the apps, put as many reusable components as possible into the VisualCore library and build most of the logic there, generalized so other apps can reuse it. Examples: simulation, physics, audio DSP and acquisition, input and controllers, procedural generation, color and palettes, scene and camera helpers, UI surfaces and overlays, settings and persistence, diagnostics, test fixtures. The app target keeps only app-specific product composition, content, copy, branding and genuinely one-off domain rules.
  - New shared code follows the package map and rules R1–R5: pure logic goes in `Packages/VisualCore` (host-testable); GPU and UIKit code goes in `Packages/VisualCoreRendering`.
  - It gets public `///` docs, a public-API baseline update and its own package tests.
  - ProjectM interfaces stay out of the public API (§4).
  - Before writing app-local logic, check whether an existing or new VisualCore module should own it. Record the choice in the app phase's plan.
- No speculative arbitrary system audio capture and no fake home-screen live wallpaper replacement. Audio acquisition must use public Apple APIs and documented user-visible permissions; acceptance claims require physical-device diagnostics. Scientific content, precision, units and attribution must be testable. Shader editors and user-controlled graphs require strict resource and input bounds.

## 5. Public API, privacy, licensing and safety rules

- **Public Apple APIs only**. Do not introduce private frameworks, `dlopen`, `dlsym`, ReplayKit-based capture workarounds, unsupported Screen Recording entitlements, invented background modes or platform permission bypasses. The original ProjectM repository's `scripts/check_compliance.py` enforced a narrower project policy; port its *applicable* checks to this repository, without imposing irrelevant constraints on apps with justified networking needs.
- No generalized source-compatibility claims. In the original ProjectM project, FR-031 required a **10-minute non-silent real-device CaptureLab diagnostic export** before claiming an audio source works. A prior 20.8-second or 22.4-second sample is not sufficient. Simulator results and screenshots are never compatibility evidence.
- D1/D2 support the iOS 27 System/App Capture evaluation path when the documented system capability is truly available; D3 on iPadOS 26.5 must correctly show System/App Capture as unavailable and cover permitted Microphone/In-App Playback behavior. Distinguish the original ProjectM capture product from apps that do not implement that feature.
- **Signing is an owner-provisioned boundary.** Do not edit teams, certificates, profiles, App Store Connect credentials or paid agreements; do not commit `Configs/Signing.local.xcconfig`. Use committed `Configs/Signing.xcconfig` containing only `#include? "Signing.local.xcconfig"` and a gitignored owner-created local file when this pattern is applicable. Simulators and CI can be unsigned (`CODE_SIGNING_ALLOWED=NO`). Device signing uses already provisioned credentials and approved Xcode settings.
- No purchase, App Store submission, binding legal agreement, system picker interaction or account sign-in in the name of "autonomy." Do not promise the system can unlock an iOS device, authorize its first trust dialog, toggle Developer Mode, make an Ask to Buy purchase, or adjust Airplane Mode.
- License obligations for ProjectM, ANGLE and all assets are recorded before distributing anything. Keep README, copyright notices, third-party attribution and shader licenses accurate; conduct an LGPL analysis of actual linkage/distribution rather than assuming it.
- Audit privacy manifests based on the **built app**, including required reason APIs and all dependencies. Keep sensitive diagnostics local, avoid collecting private audio, and never put credentials, UDIDs, personally identifying diagnostics or app-container exports into a public Git commit.

## 6. Exact three-device acceptance matrix

**Inventory from the owner's `devices.md` (2026-11-08). Verify with `xcrun devicectl list devices --json-output <file>` before tests; update an evidence inventory if an OS version changes, but NEVER update D3's OS automatically.**

| ID | Device | Local device name | Part number | OS and build | Model identifier | Purpose |
|---|---|---|---|---|---|---|
| **D1** | iPhone 15 | `iPhone77` | `MTLV3LL/A` | iOS **27.0.1** (`24A446`) | `iPhone15,4` | Reference iPhone; audio modes; FPS/startup/scenes/lifecycle |
| **D2** | iPad Pro 13-inch (M5) | `iPad77` | `MDYJ4LL/A` | iPadOS **27.2** (`24B119`) | `iPad17,3` | High-tier iPad; audio modes; layout, multiwindow, high resolution |
| **D3** | iPad (A16) | `iPadC` | `MD4A4LL/A` | iPadOS **26.5** (`23F77`) | `iPad15,7` | **Sole iOS 26 fallback**, lower-tier reference; no System/App Capture |

**DO NOT UPDATE D3 FROM iPadOS 26.5.** The device roster is final; do not demand another iPhone or newly purchased hardware. Compatibility claims name these exact devices and OS versions. At inventory creation they were all paired with Developer Mode on; that historical fact is not proof they are currently connected, unlocked or signable.

When the implementation lock is green, execute a strict device campaign: **all 25 apps on D1, then all 25 on D2, then all 25 on D3**, recording the device-specific result of each app before advancing. Do not substitute a simulator or report a device as tested if the app could not install/launch. UI automation and in-app instrumentation may cover authorized scenarios; permissions or external UI requiring a human remain blocked with exact instructions and a failed release gate unless explicitly and legitimately out of scope.

## 7. Spec Kit in the Desktop Code session

- Install/verify `specify` **as a tool**, and initialize once with `specify init --here --force --non-interactive --integration claude --script py --ignore-agent-tools --integration-options="--events false"` **only after auditing the existing repo and guarding user files**. Do not casually overwrite an existing `.specify/` or `CLAUDE.md`. `--ignore-agent-tools` is appropriate when the CLI executable is intentionally not installed. `--events false` avoids Spec Kit's CLI-based runtime dispatch; invoke the installed **model-invocable** `.claude/skills/speckit-*/SKILL.md` skills inside the **Desktop Code conversation**.
- For each foundation phase and app feature, use installed skills equivalent to `/speckit-constitution` (once), `/speckit-specify`, `/speckit-clarify`, `/speckit-plan`, `/speckit-checklist`, `/speckit-tasks`, `/speckit-analyze`, `/speckit-implement`, `/speckit-converge` *if installed*. Inspect actual installed skill names; a missing skill is not a reason to invent the slash command.
- **Owner instruction (2026-11-10, repeated): for ALL features in the README — all 10 foundation phases (F00–F09) and all 175 app phases (A01-P00 … A25-P06) — execute every Spec Kit command, every time, with the supplied prompt.** Invoke each installed skill: `specify`, `clarify`, `plan`, `checklist`, `tasks`, `analyze`, `implement`, `converge`, and `constitution` where a prompt is given. Pass the archive's prompt text **verbatim**: foundation Phases 0–9 from `.autonomy/context/sources/README.md` §10.1–10.11; app *NN* Phase *P* from `.autonomy/context/apps/NN-*.md` §9, plus that manual's own `/speckit-constitution` prompt. Add canonical rules only as a labelled `Canonical override:` note after the quoted prompt. Never hand-write spec/plan/checklist/tasks as a substitute, never skip a command, and never seal a gate before its full sequence has run. **One Spec Kit feature per ledger gate** (ADR-0004): `specs/001`–`010` = F00–F09; app *NN* Phase *P* = `specs/<10 + (NN−1)·7 + P + 1>`; IDs `FR-Fk##` (foundation phase *k*) and `FR-ANN-P##` (app), checked by `scripts/validate_docs.py`.
- **Owner instruction (2026-11-10): every feature ends with `/speckit-converge`, and its fixes are implemented.** The authoritative per-feature command list is `docs/process/speckit-prompt-manifest.json` (summary `.md`), generated from the hash-verified archive by `python3 scripts/speckit_prompts.py`. Print one feature with `--feature NNN`. Order: specify → clarify → plan → checklist → tasks → analyze → implement → **converge** → implement (every converge-appended task and required fix, with real builds/tests) → converge again, repeating until converge appends nothing. Only then is the gate sealed. Commands the archive omits (foundation Phases 4–9, including converge for Phases 8–9) are filled as labelled `supplement:` entries; never skip one.
- Derive **specific** FR/SC/task identifiers per feature; avoid ID collisions. `specs/<feature-slug>/` contains `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`, `tasks.md`, acceptance and verification. Do not mark any task `[X]` without an actual command/device/export in its annotation. Use "automation ready", "blocked", "not required" (with precise source and rationale) where appropriate; a new agent may not invent owner waivers.
- Answer routine clarification questions under this user's delegated implementation intent, log the chosen option and rationale. Respect owner-only decisions and never forge an Apple entitlement decision or legal approval.

## 8. Implementation campaign: development checks allowed, device tests not allowed

- Order: F00–F09 shared foundation → 25 app manuals' seven phases (175 stage gates), dependency-aware app order → full suite workspace build/simulator/unit/integration/accessibility/asset/compliance audit → **implementation lock**. The locked state verifies *all* app targets and product functions exist before any on-device action. Do not unlock just because file counts are correct.
- During this campaign, use host Swift tests, package tests, shader compilation, headless CPU fixtures, simulator screenshots/XCUITests and generic device SDK compile checks. No signed physical device installs or tests; hardware testing is saved for the contiguous final campaign per user instruction.
- Before each Mac coding session, run the new `scripts/verify_environment.py` and compare to the reference host recorded in original ProjectM: Xcode **27.2 (27B52)**, iOS SDK 27.2, Swift **6.4.2**, XcodeGen **2.46.0**, CMake **4.4.5**. These are reference pins from 2026-11-08, not a license to silently install or upgrade them. The original repo has iOS 27.2 and **26.5 (23F77)** simulators; discover currently installed runtimes.
- XcodeGen `project.yml` generates gitignored `.xcodeproj` files; use separate harness configurations if helpful. Explicit module names for hyphenated product names and one stable bundle ID per app. The owner must approve actual App Store branding and provisioning before publishing.
- Commit after verified tasks/skills with clear subjects, LF line endings, no co-author or "Generated with Claude" trailers. The owner's old permission to **push original `projectm-ios` `origin/main`** does not grant permission to push this new repo's remote. Prefer local commits until explicit remote publication authorization exists; do not reset, clean or overwrite uncommitted user changes.
- **Owner instruction (2026-11-10, commit/push cadence): commit after EVERY task, EVERY Spec Kit skill and EVERY complete fileset change, then push right after.** Never batch several tasks or skills into one commit, and never leave verified work uncommitted or unpushed. Push to GitHub (`origin` = `Coastrnaut/VisualCore`, branch `main`) after each such commit, or at the latest after each small group of consecutive commits within the same skill run. Before each push, scan for UDIDs, ECIDs, serials, signing teams and credentials, and never push `.autonomy/private`, logs or xcresults (gitignored). Never force-push or rewrite published history. This authorization covers pushing this repository only, not App Store submission, releases or other remotes.

## 9. Batched physical-device campaign: automation details

- Use one Python orchestrator (written within project `scripts/run_device_campaign.py`) which reads the entire app build/UDID matrix, verifies the implementation lock, discovers device IDs, queues 75 app/device jobs, serializes Xcode operations, sets retry/time budgets and records JSON + actual `.xcresult` artifacts. **It must refuse to run when implementation is incomplete.** It invokes only Apple tools; it does not invoke the Claude CLI.
- Device discovery: `xcrun devicectl list devices --json-output <path>`; match `hardwareProperties.productType` to D1=`iPhone15,4`, D2=`iPad17,3`, D3=`iPad15,7`. For physical Xcode destinations use `hardwareProperties.udid`, **not** a devicectl-only device identifier. Never assume the device name is unique.
- `xcodebuild test -destination 'platform=iOS,id=<REAL_HARDWARE_UDID>' -resultBundlePath <unique>.xcresult` executes real XCTest; attach summaries and failure logs. `xcrun devicectl device install app`, `device process launch --terminate-existing --environment-variables <JSON>`, `device info files --domain-type appDataContainer --domain-identifier <bundle>`, `device copy from`, and process termination can drive deterministic in-app test modes; inspect current installed `devicectl --help` before use.
- A dedicated in-app `AutomationRunner` is compiled only in `DEBUG || VISUALCORE_AUTOMATION` (use the original ProjectM implementation as the reference) with a Release **measurement** configuration containing the explicit automation condition; it exports JSON and exits. Verify shipping Release `nm -U` contains **zero** automation symbols and that automation features cannot be triggered by public URL/remote input.
- At least **200 independently identifiable samples** for percentage-based launch/latency gates, not 50; isolate first launch after installation (onboarding) from warm launches; measure scene or preset loading separately from first rendered frame. Keep shader compilation spikes visible, particularly the D1 preset-switch problem previously measured as **96%** against a **95%** target (an earlier run was **92%**, so borderline results need repeat measurement).
- For continuous-frame UI tests, instrument `CADisplayLink` on-time/missed-refresh counts and let an actual UI test interact for 10 seconds or longer; report thermal state, sample IDs, app hash, device model, OS, battery/charging, screen brightness if measured, FPS/frame-time distribution and memory. Cool devices between long tests and distinguish warm- and cold-cache paths.
- For privacy claims, inspect each application's own UserDefaults keys and entire container. Ignore known third-party-created StoreKit `SKTransactionUpdatesLastChecked` and Metal shader `.pcm` caches *after verifying provenance*; `.pcm` does not mean microphone audio. Never suppress unknown files.
- StoreKit: `SKTestSession` with a local `.storekit` fixture, no synced `_applicationInternalID`. Unit-test host apps use a fake store when `XCTestConfigurationFilePath` is set. Nonpurchase UI tests run with fake entitlements (e.g. `-uitestUnlocked NO`). Do not make a real Ask to Buy purchase; exercise pending-result logic and deliver test approval through `session.buyProduct`.
- UI tests: lazy SwiftUI lists must be scrolled before locating offscreen rows; `XCUIElement.label` is the correct exposed value and can include formatted numbers; check toolbar scope. Clear simulator permissions and isolate simulator workers during pre-device tests.
- Scripts are **noninteractive**: `--dry-run` shows planned commands; blocked device trust/unlock/signing/system permission results produce `BLOCKED_OWNER_ACTION` with exact steps and an incomplete report rather than waiting at `input()`.

## 10. Evidence, checkpoints, and finish conditions

- The project uses `Tools/python/desktop_runbook.py`, extracted from the canonical README, for **deterministic bookkeeping and command verification only**: `bootstrap`, `validate`, `status`, `next`, `run-check` (executes and hashes real test/build commands), `seal`, `record`, `block`, `guard-device`, `audit`. Claude Desktop provides the decisions and edits; Python never calls a model.
- Repository-local state: `.autonomy/state.json` (tracked or otherwise durable as chosen at setup), `.autonomy/desktop.lock`, `.autonomy/evidence/`, `.autonomy/xcresults/` and `.autonomy/logs/`. Each successful gate uses `run-check` and `seal` to store actual command execution, exit status, log path with SHA-256, revision/dirty-state and requirements; only then `record` advances it. Do not use an agent summary as evidence. Never mark pass for a nonexistent log or `.xcresult`.
- Build commands write logs **directly to files** and have explicit timeouts; do not filter Xcode output through `sort`, `tail` or an unreliable pipe before process exit. Simulator XCTest uses `-test-timeouts-enabled YES -default-test-execution-time-allowance 180`, and snapshots inspect scene output, not just a launched screen. Determine available `xcodebuild`/`xcresulttool` flags on installed Xcode.
- The original repo uses `scripts/test_scripts.py`, `scripts/validate_docs.py`, `scripts/check_compliance.py`, `scripts/verify_environment.py` and `scripts/run_device_tests.py`. Reuse lessons and applicable checks; do not import a path that does not exist in the new repository without first implementing it.
- Failures: fix the smallest cause, rerun exact tests, append new attempt. Do not weaken acceptance criteria or call owner waivers automatically. If blocked, record exact dependency and continue unrelated stages only if data/dependency safety permits. Any failed mandatory device row makes release incomplete.
- Final report must cover the VisualCore framework, Showcase, ProjectM reference adapter, **all 25 apps**, host/unit/simulator checks, **75 individual device/app rows** on D1/D2/D3, runtime/OS details, real performance and privacy artifacts, license review, incomplete and external-only actions. "Complete" requires every required evidence gate; App Store approvals and user-side purchases remain separate.

## 11. App portfolio (all required; detailed instructions in the preserved README appendices)

1. Generative Art Studio; 2. Fluid Art Playground; 3. Fractal Explorer; 4. Particle Universe; 5. Infinite Geometry; 6. VisualCore Music Lab; 7. Audio Odyssey; 8. Oscilloscope Studio; 9. Digital Aquarium; 10. Neon Arcade; 11. Physics Playground; 12. Tiny Worlds; 13. Light Maze; 14. Solar System Explorer; 15. Molecular Explorer; 16. Simulation Lab; 17. Interactive Anatomy; 18. Ambient Clock; 19. Living Wallpapers; 20. Digital Zen Garden; 21. Aurora; 22. Shader Studio; 23. Visual Programming Lab; 24. Graphics Benchmark Lab; 25. Effects Composer.

All 25 manuals remain embedded **verbatim** in README's source archive. Read the relevant detailed manual before implementing each app; create real code/fixtures matching its features, file layout, phase deliverables, algorithm choices, tests and risks. Never extrapolate generic boilerplate as a substitute for the individual manual.

## 12. Reference evidence and historical context — do not launder into new test results

The original ProjectM-iOS `CLAUDE.md` recorded, around 2026-11-08 to 2026-11-10, a Stage 1 go ruling, Plan phases B–E, ANGLE's Metal backend Gate 3, `projectM-iOS` 1.0 uploaded but not yet submitted to App Review, and a 1.1 preset-library feature with pending owner/device tasks. It recorded ANGLE RendererLab device sweeps, an audio callback test on D1 (7.4% CPU over a 3-minute run), original host/CI test counts, an iOS 26.5 weak-link compatibility path, and D1/D2 short non-silent capture tests **not yet meeting the ten-minute source claim gate**. These are valuable upstream baseline observations but are not VisualCore results. Consult the fully preserved original CLAUDE.md and devices.md inside README for exact task IDs, exemptions, reports and historical scope.

## 13. Copyable continuation instruction for Desktop Code

> Continue the complete VisualCore suite from `README.md` and `CLAUDE.md` in this local repository. Use Desktop Code tools and installed model-invocable Spec Kit skills, **never the Claude CLI**. Read `.autonomy/state.json` with `python3 Tools/python/desktop_runbook.py status` and select the next unlocked gate; implement it thoroughly, run real checks, write evidence, update state and commit verified changes. Repeat through all 10 framework phases, all 175 app phases and the implementation lock. **Do not execute any physical-device test until implementation lock is verified.** Then run the complete device campaign sequentially: 25 apps on D1 iPhone 15 iOS 27.0.1, 25 on D2 iPad Pro M5 iPadOS 27.2, 25 on D3 iPad A16 iPadOS 26.5 (never update D3), with real xcresults/device logs. Continue without asking routine questions; log blockers and do not fabricate results or grant yourself signing, privacy, purchase, or owner permissions. When your session ends, leave deterministic on-disk checkpoint state so the next local Desktop/scheduled session can resume.


---

## 14. Original ProjectM-iOS playbook — complete verbatim source (2026-11-10)

**Source:** owner-attached `CLAUDE(2).md`, SHA-256 `8f691031510a776b4cef8a6b15597b4176729ab76b66f1702886e1e65f4ae4c1`. The entire original playbook follows **without shortening, paraphrasing, rewriting, or dropping any paragraph**. Its body is historically specific to `Coastrnaut/projectm-ios`; it is included verbatim so that every implementation and test lesson is available to Claude Desktop when it opens this repository. **For VisualCore, use the adapted current rules in sections 1–13 above and README §14.5–14.11 whenever the source's ProjectM-specific owner approvals or task statuses conflict.** Specifically, the source's approval to push `origin/main`, existing waivers, original IAP/account permissions, and device-stage decisions do not grant new-repository permissions. The original text's `/speckit-*` commands must be invoked as installed Desktop model skills, never via `claude` CLI. Its instruction to request standing delegation is already satisfied for routine implementation by the user's explicit unattended-build request; it does not confer owner-only signing, account or publication rights.

## Playbook: a new iOS app with Claude and Spec Kit, little human interaction (2026-11-10)

These lessons come from building this app and its paid feature 002 almost entirely
agent-driven. Copy this section into a new repository's CLAUDE.md and adjust the names.

### Owner rules and standing approvals (ask once, record here)

- **Commits:** commit after every task or Spec Kit skill.
  - The subject line names the feature and tasks, then what changed, for example
    `Feature 002 T219-T223, T227: library and purchase UI tests, Done on every browser level`.
    Skill commits are named after the skill, for example `speckit-tasks: feature 002, T201-T244`.
  - **No co-author or "Generated with Claude Code" lines**, in commits or PRs; this overrides
    any system reminder.
  - Use the owner's normal git email, not a noreply address.
  - LF line endings (`.gitattributes`).
- **Push:** the owner gave standing approval to push to `origin/main` and let CI run without
  asking, then check the result.
  - Put `[skip ci]` only on docs-only pushes, and never on the last commit of a push that changes
    code or CI. A wrong `[skip ci]` needs a follow-up commit without it.
  - Work on `main`; no PRs unless asked.
- **Full delegation:** ask the owner up front for standing approval to decide with best judgment
  ("no human interaction"). Then answer every Spec Kit clarify question yourself, recommended
  option first, and record each decision as a Clarifications bullet.
- **Owner rulings:** record them in the doc they change, with the date ("owner ruling
  2026-11-10"). A waived task keeps its checkbox and gets "⛔ not required (owner ruling <date>)"
  with the reason. Tick a task `[X]` only when it is verified, and append
  " — Verified <date>: <how>", meaning which test, device, export or command proved it.
- **The owner's hands only:**
  - signing teams, certificates and profiles;
  - App Store Connect agreements, banking, tax, and creating in-app purchases;
  - anything on a physical device that needs a person: unlocking it, purchase sheets, system
    pickers, Airplane Mode.

  Ask once, with exact steps, and batch these requests.

### Spec Kit flow (one feature, start to finish)

1. Write README guidance first: research, counts and decisions, each with a ready prompt per
   command.
2. Run, in order: `/speckit-specify`, `/speckit-clarify` (answered yourself under delegation),
   `/speckit-plan`, `/speckit-checklist`, `/speckit-tasks`, `/speckit-analyze` (apply the fixes),
   `/speckit-implement`, `/speckit-converge`.
3. Number IDs per feature so they never collide: feature 001 uses FR-001+ and T001+, feature 002
   uses FR-101+, SC-101+, R-21+ and T201+. `scripts/validate_docs.py` checks references across
   all features.
4. Tag tasks `{device}` or `{owner}` when the Mac cannot finish them. Close them honestly as
   "automation ready", "blocked on T242" or "not required".
5. An agent's report is not evidence. Rebuild, rerun the tests or read the diff before ticking.

### Project setup that keeps humans out

- **Project files:**
  - Use XcodeGen (`project.yml`, pinned version); the generated `.xcodeproj` is gitignored.
    Separate specs for harness apps (`RendererLab.yml`).
  - Logic lives in SwiftPM packages under `Packages/`, testable on Linux where possible. App
    targets live under `Apps/<Name>/`.
- **Signing without committing it:** commit `Configs/Signing.xcconfig` containing only
  `#include? "Signing.local.xcconfig"`, and point `configFiles:` in `project.yml` at it for
  Debug and Release.
  - The owner creates the gitignored `Configs/Signing.local.xcconfig` with
    `DEVELOPMENT_TEAM = <team ID>`. The team ID is the OU field of their
    "Apple Development" certificate.
  - CI and simulators build unsigned (`CODE_SIGNING_ALLOWED=NO`).
  - Device builds and on-device UI tests use `-allowProvisioningUpdates`.
- **Names:**
  - Settle the App Store name before the bundle ID. The **bundle ID is permanent** once uploaded:
    App Store Connect and in-app purchase IDs hang off it.
  - Renaming later changes only the target, scheme and `PRODUCT_NAME`. Set
    `PRODUCT_MODULE_NAME` explicitly when the name has a hyphen (`projectM-iOS` →
    `projectM_iOS`).
  - Keep the home-screen name in `CFBundleDisplayName`.
- **Versions:** `CFBundleShortVersionString` and `CFBundleVersion` live in `project.yml` and the
  app's Info.plist. Raise them before every upload. Prebuilt frameworks need their own
  `CFBundleShortVersionString` and `MinimumOSVersion`, or App Store Connect validation rejects
  the upload.
- **Repository size:**
  - Third-party content (preset packs) goes in shallow, pinned git submodules; never copy it.
  - Generate bundles at build time (an index plus a compressed archive from a build phase) and
    never commit generated output.
  - Keep screenshots at their final upload size and keep videos out of git. Removing big files
    later means rewriting history (`rebase --autosquash`, `reflog expire`, `gc`).
  - Submodules: `git submodule update --init --depth 1 <paths>`. Set `ignore = untracked` in
    `.gitmodules` so Finder's `.DS_Store` files do not dirty them.
- **Compliance as code:** `scripts/check_compliance.py` enforces the constitution: public APIs
  only, no `dlopen`/`dlsym`, no networking APIs in the app (even `NWPathMonitor` trips it). Run
  it in CI and before every commit.

### CI (GitHub Actions, `.github/workflows/ios-ci.yml`)

- **Runners:** a public repository gets free standard runners. Use `concurrency` with
  `cancel-in-progress` and `timeout-minutes` on every job.
- **Jobs:**
  1. Docs and compliance on Linux (fast gate).
  2. Linux package tests.
  3. Engine and ANGLE xcframework builds on macOS, cached by Xcode build and pin, passed on as
     artifacts.
  4. The main macOS job: package tests on the host and a simulator, generic-iOS builds of every
     app.
  5. A job on the newest-Xcode preview image (`xcode-27`) for the newest SDK path.
- **XcodeGen:** install it from the GitHub release with a pinned SHA-256.
- **Picking a simulator:** choose by runtime in a small Python step; never hard-code a device
  name.
- **Fetch only what each job needs:** for example the preset submodules in the job that builds
  the app, plus an index-builds check.
- **After pushing:** run `gh run list` for the run, then `gh run watch <id> --exit-status` in the
  background. A cancelled upstream job skips its dependents, so check why before blaming the
  code.

### Testing on the Mac (simulators)

- **xcodebuild output:** write it to a log file and grep that. Never pipe it through `sort` or
  `tail` to watch progress: the output buffers until the end and a hang looks like silence.
- **Time limits:** always pass `-test-timeouts-enabled YES -default-test-execution-time-allowance
  180`.
- **Checking for a hang:**
  1. How old is the app process (`ps -o etime`)? UI tests relaunch the app for every test.
  2. Take a screenshot: `xcrun simctl io <udid> screenshot x.png`.
  3. Which test started last (grep "Test Case .* started")?
- **StoreKit:**
  - `SKTestSession` with a local `.storekit` file. The file must not carry a synced
    `_applicationInternalID`.
  - The **host app must not touch StoreKit while hosting unit tests**: detect
    `XCTestConfigurationFilePath` and use a fake store. Otherwise its launch-time product request
    runs before the test's session exists, and every product request returns nothing.
  - **UI tests that don't test purchases** launch with a fixed fake entitlement
    (`-uitestUnlocked NO`). Otherwise the real store shows a "Sign in to Apple Account" alert
    and the run hangs forever.
  - **Never make a real Ask to Buy purchase in a test**: it also asks for a sign-in. Instead,
    split purchase-result handling out (`handle(.pending)`) and deliver the approval with
    `session.buyProduct`.
- **Simulator state:**
  - Reset permissions between runs (`simctl privacy <udid> reset microphone <bundle>`).
  - When a simulator's state looks wrong, `simctl erase` it.
  - Run tests on a different simulator from one a background job is using.
- **XCUITest details:**
  - Lazy lists build rows only near the screen, so scroll until a row exists.
  - Accessibility labels show formatted numbers ("9,728").
  - Toolbar items exist only on the view that declares them.
  - Read `XCUIElement.label` for values.
- **Simulator results are never evidence** for performance or compatibility. Keep simulator
  exports gitignored.

### Automated device testing (devicectl, no Xcode UI)

- **In-app runner:** an `AutomationRunner` compiled only under `DEBUG || PROJECTM_AUTOMATION`,
  started by the environment variable `PROJECTM_AUTORUN=<mode>`.
  - The measurement build is Release with
    `SWIFT_ACTIVE_COMPILATION_CONDITIONS=PROJECTM_AUTOMATION`.
  - Confirm with `nm -U` that the shipping Release build has zero automation symbols.
  - Each mode writes a JSON report to Documents, then **exits**. A mode that keeps running
    leaves the device busy.
  - Launch-timing modes append one sample per launch and are run repeatedly. The first launch
    after install only dismisses onboarding.
- **devicectl commands** (`scripts/run_device_tests.py` wraps them all; `--dry-run` prints them,
  `--simulator <udid>` rehearses on a simulator):
  - `xcrun devicectl list devices --json-output f`: map `hardwareProperties.productType` to
    D1/D2/D3.
  - `devicectl device install app --device <id> <app>`; uninstall the same way for a fresh
    container.
  - `devicectl device process launch --device <id> --terminate-existing --environment-variables
    '{"PROJECTM_AUTORUN":"sc101"}' <bundle>`.
  - `devicectl device info files --domain-type appDataContainer --domain-identifier <bundle>
    [--subdirectory Documents] --json-output f`, then `devicectl device copy from --source
    Documents/x.json --destination ...`.
  - `devicectl device info processes` plus `device process terminate --pid` to stop the app.
  - On-device UI tests: `xcodebuild test -destination 'platform=iOS,id=<hardware UDID>'`. The
    UDID is `hardwareProperties.udid`, not the devicectl identifier.
- **Devices:** a launch fails with "Locked" when the device is locked. Ask the owner to unlock
  each device and set Auto-Lock to Never for the session.
- **Measurements:**
  - Percentage criteria need at least 200 samples; 50 picks swung by 4 points between runs.
  - Record per-sample IDs and a timing breakdown so failures can be traced.
  - Scrolling: an in-app `CADisplayLink` frame meter (on-time frames and missed refresh slots),
    shown with a launch flag and read by a UI test that swipes for 10 s.
  - Installed size: export the old and new archives with
    `thinning = <thin-for-all-variants>` and compare the "App Thinning Size Report.txt" files
    per device model.
  - Privacy: list the whole app container and compare the app's own UserDefaults domain keys
    with the allowed list. StoreKit itself writes `SKTransactionUpdatesLastChecked`, and Metal
    caches contain `.pcm` files that are not audio.
- **What cannot be automated:** purchase sheets, system pickers, Airplane Mode and the first
  microphone permission. The script stops at each with exact instructions and waits for Return.

### App Store Connect and release

- Check name availability early: "projectM" and "projectM Visualizer" were taken.
- **Before the first upload:**
  - an app icon (asset catalog);
  - `ITSAppUsesNonExemptEncryption`;
  - a privacy manifest backed by a scan of the built app (`check_privacy_manifest.py`);
  - a privacy policy URL;
  - an EULA;
  - review notes.
- **Screenshots and previews:** take screenshots from simulators at the exact sizes required.
  Previews must be silent if they have no audio, and Apple processes them slowly.
- **In-app purchases:**
  - Need the Paid Apps agreement and banking first (owner).
  - Use StoreKit 2: `Transaction.currentEntitlements` and `Transaction.updates`. Store no
    unlock flag.
  - Keep the network product request out of any launch-time critical path.
- **Driving App Store Connect:** the owner must authorize it (computer use or the browser), and
  the owner signs in. Never type credentials.

### Performance lessons from feature 002

- Readiness means what the user needs: browsing needed the local entitlement, not the price. The
  network product request moved off the path.
- Run independent startup work in parallel (`async let`).
- Write build-time data already in display order: Swift's sort is a timsort, so already-sorted
  input costs about one comparison per item. Index load on D1 went from 157 ms to 106 ms.
- Engine-heavy work (shader compiles on a preset's first frame) dominates preset switch times.
  Measure the load and the first frame separately.
