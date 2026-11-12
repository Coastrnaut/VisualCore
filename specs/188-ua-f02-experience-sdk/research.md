# Research: UA-F02 — ExperienceKit

Date: 2026-11-12. Read-only audit of the sources named in the brief, then the decisions the plan rests on. Every
API named in plan.md, data-model.md and the contracts was read in the source at commit `0c7e3f1` or later; the
names the brief marked as proposals are confirmed or corrected in section 2.

## 1. Audit of the existing sources

| Surface | Where | What was verified |
|---|---|---|
| `RenderScene` | `Packages/VisualCoreRendering/Sources/VisualCoreRendering/RenderScene.swift` | `@MainActor` protocol, class-bound: `setup(_:) throws`, `resize(_:)`, `render(_:frame:) throws`, `teardown(_:)`. `RenderContext` carries `generation`, pixel size, `framebuffer`, `resources: ResourceRegistry`. `FrameInfo` carries `index`, `time`, `delta` (clamped to 0…0.1 s), `targetTimestamp`. |
| `RenderHost` | `…/VisualCoreRendering/RenderHost.swift` | `init(scene:maxFramesPerSecond:budget:) throws`; `view`, `state`, `generation`, `lastError`, `resources`; `replaceScene(_:)` tears the old scene down and sets the new one up; `recreateContext()` calls scene teardown, ends the context, starts a new generation and sets the scene up again; `renderOneFrame(present:)`, `readPixels()`; `destroy()` tears the scene down and ends the context. A scene error becomes `RenderHostError.scene` and a black frame. The host observes background and foreground itself. |
| `ResourceRegistry` | `…/VisualCoreRendering/ResourceRegistry.swift` | `stats: ResourceLedger.Snapshot` with `liveCount`, `liveBytes`, `totalBytes`, `leaked`; `makeTexture`, `makeBuffer`, `makeRenderTarget`, `program(…)`, `release(_:)`. The program cache stays live until the context ends, so "zero live objects" is true after `destroy()`, not after `replaceScene` when a scene used cached programs. |
| `RenderSurface` | `Packages/VisualCoreRendering/Sources/VisualCoreUI/RenderSurface.swift` | SwiftUI wrapper of a caller-owned host with an accessibility label and hint. Used by the session host later; this feature only supplies the text for the label. |
| `RenderLifecycle` | `Packages/VisualCore/Sources/VisualCoreDiagnostics/RenderLifecycle.swift` | Pure value: states, `isAllowed(from:to:)`, `transition(to:) -> Bool`, `rejectedTransitions`, bounded `history`. The experience lifecycle follows the same pattern one level above it. |
| `FixedStepClock`, `FixedStepRunner` | `Packages/VisualCore/Sources/VisualCoreSimulation/` | The clock turns frame deltas into 0…`maxSteps` steps (`maxSteps` clamped to 1…8), counts `droppedTime` and `invalidDeltas`, and `resetAccumulator()` discards time without catch-up. The runner is generic over `FixedStepSimulation` (`step(_ dt:)`, `checksum() -> UInt64`) and a control stream. |
| `PlaybackState` | `…/VisualCoreSimulation/PlaybackState.swift` | Play and pause intent with background suspension. It models a person's choice inside one experience; the lifecycle of this feature sits above it and does not replace it. |
| `DocumentStore`, `DocumentEnvelope`, `StoreProblem` | `Packages/VisualCore/Sources/VisualCorePersistence/` | `DocumentStore<Value: Codable & Sendable>` with `save(_:id:now:)`, `load(id:)`, `load()`, `delete(id:)`; it writes its own file envelope (kind, schema version, save time) and has a size limit (default 256 KiB, settable). |
| `MigrationChain` | `…/VisualCorePersistence/Migration.swift` | `init(currentVersion:steps:)`, `migrate(_:from:) throws` on `[String: Any]`; `MigrationError.missingStep`, `.newerVersion`. |
| `QualityPolicy` | `…/VisualCoreDiagnostics/QualityPolicy.swift` | Chooses a tier index (0 = best) from thermal state and Low Power Mode. This feature only carries the tier index. |
| `AutomationRunner` | `Packages/VisualCoreRendering/Sources/VisualCoreAutomation/` | The whole module is inside `#if DEBUG || VISUALCORE_AUTOMATION`. `scripts/check_release_symbols.py` proves its absence from an app binary. Not changed by this feature. |
| SHA-256 | `Packages/VisualCore/Sources/VisualCoreShaderSource/SHA256.swift` | A pure Swift FIPS 180-4 implementation, internal (`enum SHA256` with `digest(_:)` and `hex(of:)`), reached publicly only through `ShaderCacheKey`. |
| Rules for pure modules | `scripts/check_dependencies.py` | R2: pure sources import only `Foundation`, `Dispatch`, `os`, `Darwin`, `Glibc`, `Synchronization`, `simd`, `_Concurrency`, `Accelerate` and pure VisualCore modules. CryptoKit is therefore not available to a pure module. R5: `VisualCoreTestSupport` is a dependency of test targets only. |
| Package tests | `scripts/xcodebuild_package.py` | `--package`, `--scheme`, `--destination sim-<runtime>`, `--action build|test`, `--result-name`. There is no configuration option; tests run in Debug, where `DEBUG` is defined. |

## 2. Names of the brief, confirmed or corrected

| Name in the brief or in section 11.3 | Result |
|---|---|
| `VisualCoreExperience` (pure) | exists since UA-F01; extended here |
| `VisualCoreExperienceHost` in `Packages/VisualCoreRendering` | new target and library product |
| `ExperienceConformance` | new, in `VisualCoreExperience`; it does not import a test framework |
| `Experience` as one main-actor protocol (sketch of section 11.3) | corrected by clarification 1: a pure `ExperienceCore` plus a main-actor `ExperiencePresenter`; the framework's `ExperienceShell` joins them and offers the type-erased protocol `Experience` to the session host |
| `ExperienceAction`, `ActionResult`, `ExperienceSnapshot`, `ExperienceDiagnostics` | new, as value types in `VisualCoreExperience` |
| `DocumentEnvelope` as the snapshot envelope | corrected: `DocumentEnvelope` is the metadata of a stored file (kind, version, time). The snapshot is a `Codable` value that `DocumentStore` stores as its payload; the store's envelope stays the only file envelope |
| `FixedStepRunner` | adapted through its clock: the engine owns a `FixedStepClock`. The runner itself needs a `FixedStepSimulation` with a 64-bit checksum and a prepared control stream; an experience takes live actions and has a 256-bit digest, so wrapping the runner would duplicate the step loop instead of reusing it |
| `prepare(seed:)` "compiles shaders through the session" | the session is UA-F03. Here the core's preparation is pure CPU work and the presenter creates GPU objects in `setup`, which the render host calls with its context current |

## 3. Decisions

### R1. Two parts: a pure core and a main-actor presenter

- **Decision**: an author writes a value type conforming to `ExperienceCore` (pure, `Sendable`) and a class
  conforming to `ExperiencePresenter` (`@MainActor`: GPU objects, drawing, controls, state description). The
  framework supplies `ExperienceEngine<Core>` (pure driver) and `ExperienceShell<Presenter>` (main actor).
- **Rationale**: the conformance helper must run on the Mac host; preparation may run off the main actor;
  `draw(_ core: Core, …)` receives the core as an immutable value, so "drawing reads immutable state" is enforced
  by the type system.
- **Alternatives**: one main-actor protocol as in the sketch (cannot be tested on the host, forces preparation onto
  the main actor); a class-based core (shared mutable state between threads).

### R2. The engine is a value type and preparation uses a ticket

- **Decision**: `ExperienceEngine` is a struct. Preparation is split into `beginPreparation(seed:)`, which returns
  a ticket with a generation number, the static asynchronous `prepare(seed:timeLimit:)`, which runs anywhere, and
  `completePreparation(_:with:)`, which discards a result whose ticket is stale.
- **Rationale**: a mutating asynchronous method cannot be called on a property of a main-actor class; the ticket
  makes "a late result is discarded" (FR-U02-016) a comparison of two integers. Value semantics let the
  conformance helper copy an engine to compare two runs from the same prepared state.
- **Alternatives**: an actor (every read becomes asynchronous, including diagnostics); a class with locks.

### R3. Digest: SHA-256 over a typed, length-marked encoding, with the existing implementation

- **Decision**: `DigestBuilder` writes one tag byte per field, a 64-bit length for text and bytes, and big-endian
  values; floating-point numbers are written as their bit pattern after turning negative zero into zero, and a
  number that is not finite is refused. The hash is the repository's pure Swift SHA-256, moved from
  `VisualCoreShaderSource` to `VisualCoreMath` and made public as `StableHash`; `VisualCoreShaderSource` then
  depends on `VisualCoreMath` and keeps `ShaderCacheKey` unchanged.
- **Rationale**: rule R2 forbids CryptoKit in pure modules; a second copy of SHA-256 would duplicate code; the
  name `StableHash` avoids a clash with CryptoKit's `SHA256` in apps that import both.
- **Alternatives**: 64-bit FNV-1a as in `ParameterHash` (too small for ten thousand levels compared across
  platforms); making `VisualCoreExperience` depend on `VisualCoreShaderSource` (a dependency with no meaning).

### R4. Snapshot envelope and payload

- **Decision**: `ExperienceSnapshot` is `Codable`: format number, experience id, schema version, seed (as text),
  step index, digest, payload and checksum. The payload is the UTF-8 text of a JSON object, held as one string
  field; the checksum is SHA-256 of that text. `encoded()` uses sorted keys, so encoding is deterministic and a
  snapshot decoded from its own encoding encodes to the same bytes.
- **Rationale**: holding the payload as text keeps its bytes exact (no second parse and print of numbers), keeps
  the checksum meaningful, and lets `DocumentStore<ExperienceSnapshot>` store it without any change. Migration
  parses the text into `[String: Any]`, runs the existing `MigrationChain` and prints it with sorted keys.
- **Alternatives**: a nested JSON object (re-encoding may print numbers differently, so bytes and checksum drift);
  base64 (opaque to the migration chain and to a person reading the file).

### R5. Reset and restore are written by the experience and checked by the helper

- **Decision**: `ExperienceCore` requires `reset()`, `snapshotPayload()` and `restore(payload:seed:)`; `Codable`
  cores get the last two for free. The engine compares the restored digest with the digest in the envelope when
  the schema version is current.
- **Rationale**: an experience knows which seed-derived data it can keep and what it must rebuild. The helper
  proves that reset equals a fresh preparation, which is the reason the helper exists.
- **Alternatives**: reset by re-running preparation (asynchronous and slow for generated levels); reset from a
  remembered first snapshot (hides a wrong `reset()` and keeps up to 1 MiB per experience).

### R6. A rejected action is rolled back by the engine and still checked at the core

- **Decision**: the engine validates control, value count, finiteness and ranges before the core sees an action,
  keeps a copy of the core, and puts the copy back when the core answers rejected. The helper calls the core
  directly for its rejection check, so a core that changes state while rejecting is still reported.
- **Rationale**: copy-on-write makes the copy cheap; the guarantee of FR-U02-033 then holds for every experience
  even before its author runs the helper.

### R7. Frames, steps and lifecycle in the shell

- **Decision**: the shell's scene (a `RenderScene`) asks the engine for steps only while the lifecycle is active,
  then calls `presenter.draw` with the core value. In ready and suspended it draws without stepping; before
  preparation and after deactivation began it draws nothing. Errors of `setup` and `draw` move the lifecycle to
  failed and are rethrown to the render host.
- **Rationale**: the first frame can be drawn before activation (section 11.4 order), and no callback reaches the
  presenter after deactivation began except `teardown` (FR-U02-007).

### R8. Deactivation is two calls and the GPU counts are read from the registry

- **Decision**: `beginDeactivation()` moves to deactivating; the owner of the render host then destroys the host
  (or replaces the scene); `finishDeactivation()` reads the registry counts and moves to inactive, or to failed
  with the code `experience.gpu-leak` when a live or leaked object remains.
- **Rationale**: the shell does not own the render host (that is the session, UA-F03), yet the contract must be
  able to state that nothing is left (FR-U02-052).

### R9. Automation hooks and the proof of their absence

- **Decision**: `ExperienceScenario`, `ExperienceScenarioResult` and the `run` methods of the engine and the shell
  are inside `#if DEBUG || VISUALCORE_AUTOMATION`. A new tool, `scripts/check_experience_symbols.py`, builds each
  module for release without and with the flag and counts the demangled symbols that contain `ExperienceScenario`
  in the object files: 0 without the flag, more than 0 with it.
- **Rationale**: no app links the new modules yet, so the existing app-binary check cannot see them. Object files
  of the modules themselves are the most direct evidence; the run with the flag proves that the check can see the
  symbols.
- **Alternatives**: extending `check_release_symbols.py` (it is built around an app bundle and is sealed evidence
  of earlier gates); waiting for the app target (leaves acceptance item 7 unproven in this gate).

### R10. The sample experience lives in VisualCoreTestSupport

- **Decision**: `SampleExperienceCore<Fault>` and its seven fault markers go into `VisualCoreTestSupport`, which
  gains a dependency on `VisualCoreExperience`. The sample presenter, which needs GL, lives in the new test target
  `VisualCoreExperienceHostTests`.
- **Rationale**: both packages' tests need the same sample; rule R5 already guarantees that no shipped target
  depends on `VisualCoreTestSupport`.

### R11. Observation for controls

- **Decision**: `ExperienceActionPort` is an `@Observable` main-actor class with `send`, a `revision` counter and
  the current state description. Controls built by the presenter call `send`; SwiftUI redraws from `revision`.
- **Rationale**: Observation is a public Apple framework available on the deployment target (iOS 26); it avoids a
  Combine dependency and a hand-written observer list.

### R12. Limits

| Limit | Value | Reason |
|---|---|---|
| Step length | 1/240 s … 1/30 s, default 1/120 s; a declared value outside is clamped | sections 6.6 and FR-U02-020 |
| Steps per frame | at most 8 (the clock's own clamp) | FR-U02-022 |
| Values per action | at most 8 | FR-U02-030 |
| Control id, error code | 1…64 characters of `a-z`, `0-9`, `.`, `-` | stable codes |
| Encoded snapshot | at most 1,048,576 bytes | FR-U02-043; above the default limit of `DocumentStore`, whose limit the persistence feature sets |
| Lifecycle history | 64 events | bounded memory |
| Conformance plan | at most 64 seeds, 10,000 steps per segment, 1,000 actions | FR-U02-071 |
| Scenario | at most 10,000 entries and 1,000,000 steps | bounded automation |
| Error message | at most 500 characters | evidence files stay small |

## 4. What could not be verified here

- Behavior on physical devices: none is claimed. All timings are host or simulator measurements.
- The session host's use of the two-call deactivation: UA-F03 builds it; this feature tests the calls with a
  render host created by the test.
