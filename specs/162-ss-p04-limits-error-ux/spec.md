# Feature Specification: Shader Studio — Phase 04 Resource limits and error UX

**Feature Branch**: `162-ss-p04-limits-error-ux` (spec directory only; work stays on `main`)

**Created**: 2026-11-18

**Status**: Draft

**Ledger gate**: A22-P04 (legacy ledger) · ID namespace FR-A22-4##, SC-A22-4##, T-A22-4##

**Input**: User description: archived manual `apps/22-shader-studio.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):**
  - MVP: a parameter inspector for bounded uniforms. It was built in A22-P03 (`StudioInspector`, `InspectorTests`) and
    is proved again here after a project is opened from the library;
  - regression fixture: missing uniforms and incompatible GLES versions show specific guidance;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-LIBRARY and G-WATCHDOG of `docs/apps/shader-studio/visualcore-contract.json`:
  - named, versioned project files in the experience's own storage, after Digital Zen Garden's `GardenLibrary`;
  - a watchdog over drawn-frame intervals that stops a slow preview and offers a reset to the last good shader.
- **Error guidance:** every validator refusal and the common compiler errors carry a specific sentence telling the
  person what to change.
- **Still a candidate.** No VisualCore or ProjectM change. Follow `specs/161-ss-p03-editor-inspector`.

## Clarifications

### Session 2026-11-18

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Storage:** `ExperienceStorage` (VisualCoreExperience) has `write(_:to:)` (atomic), `read(_:)`, `exists(_:)`,
  `list()` and `remove(_:)`, with a quota of 16 MiB and 64 files and names up to 128 characters.
  `ShaderStudioExperience.make(id:storage:)` already receives it and leaves it unused until this phase.
- **Projects:** `ShaderProject` encodes as the versioned envelope `a22.shader-project` (schema 1, at most 65,536
  bytes), with the refusals `damaged`, `newer-version`, `too-large`, `not-finite` and `out-of-range`.
- **Frames:** the presenter's `draw(_:tier:context:frame:)` receives `FrameInfo.delta`, the interval since the frame
  before it. `setup`, `resize` and `teardown` mark a context rebuild and a resize. `PacingMeter` is held privately
  by the session, so the watchdog keeps its own short window of drawn-frame intervals.
- **Refusals:** the validator's codes are `source-too-large`, `too-many-lines`, `too-many-uniforms`,
  `too-many-texture-inputs`, `no-main`, `version-line`, `reserved-name`, `duplicate-name`, `undeclared-in-source` and
  `undeclared-in-project`.

- Q: How is guidance produced? → A: A pure `Guidance` in the core:
  - **Refusals:** one sentence per refusal code, naming the limit or the name and the line where known. For example,
    `version-line`: "Remove the #version line on line N: Shader Studio supplies GLSL ES 3.00 itself.";
    `undeclared-in-source` for `u_speed`: "Declare u_speed as `uniform float u_speed;` above main.".
  - **Compiler diagnostics:** matched case-insensitively on the compiler's words, checked by compiling real broken
    shaders on the simulator's ANGLE:
    - "undeclared identifier" → declare it (the name is taken from the quoted word);
    - "syntax error" → a missing semicolon or bracket;
    - "cannot convert", "wrong operand types" or "no matching overloaded function" → a type mismatch, such as `1`
      where `1.0` is needed.
  - **Anything else:** the raw message, with "Check this line for a typing mistake.".
  - **Display:** the guidance is shown under the status and with each entry of the diagnostics list.
- Q: What does the watchdog measure, and when does it stop the preview? → A: A pure `FrameWatchdog` in the core:
  - **Input:** it is fed `FrameInfo.delta` of each drawn frame.
  - **Limit and window:** the limit is 0.25 s and the window is 8 consecutive drawn frames. The preview draws at
    30 fps, about 0.033 s a frame, so a stop needs about 2 s of frames over seven times too slow.
  - **Skipped intervals:** the first interval after a setup, a resize, a Run or a Reset is skipped. A non-finite or
    non-positive interval is ignored.
  - **States:** `watching` and `stopped`.
  - **While stopped:** the presenter draws a flat dark frame (no frame of the slow shader). The status says
    "Stopped: frames took longer than 0.25 s" with a Reset button.
  - **Tests:** they feed intervals and draw no slow frame.
- Q: What does Reset restore? → A: The previous live shader that the watchdog had not stopped:
  - **Kept:** the pipeline keeps it built as the fallback.
  - **No fallback:** the current template's starter shader is queued.
  - **Action:** Reset is the core action `preview.reset [1…1]`. A `resets` counter is an optional snapshot field,
    default 0. The presenter applies it at the next draw, as it applies `shader.run`.
  - **No compile from the control:** a fallback that is already built is swapped back without a compile.
- Q: What is the project library? → A: `ProjectLibrary`, after `GardenLibrary`:
  - **Files:** `project-<n>.json`, the envelope `a22.saved-project` version 1, at most 131,072 bytes. Its body is
    `{name, order, project, values[16], textures[2]}`, where `project` is the `ShaderProject` encoding.
  - **Index:** `library.json` holds the counter and the names.
  - **Caps:** at most 24 projects, counting unreadable files. Names are trimmed to 1…40 characters, and names that
    differ only in case are the same.
  - **Refusals:** saving or renaming to an existing name is refused ("A project is already called <name>."). A 25th
    project is refused ("The library holds 24 projects.").
  - **Unreadable files:** damaged, newer and oversized files are listed as unreadable with their code and never
    deleted automatically.
  - **Open:** opening sets the document, the values and the texture choices, then queues a Run, so it never compiles
    from the control. The inspector then lists the opened project's uniforms.
  - **Kept out of the snapshot:** the library is separate from the session snapshot.
- Q: How are the interface tests organised? → A: A second class, `SSLibraryUITests`, joins the serial chunk `d3`.
  - **Guidance:** a `#version` line shows its guidance.
  - **Library:** saving "Waves", then opening it from the library, gives the same source.
  - **Identifiers:** `guidance`, `library`, `save`, `project-<k>`, `open`, `rename`, `remove`, `preview-reset`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Errors that say what to change (Priority: P1) 🎯

A person's shader is refused or fails to compile. Beside the error, Shader Studio says in one plain sentence what to
change: declare a uniform the shader uses, remove a `#version` line, add a `main` function, shorten the source.

**Why this priority**: it is the manual's regression fixture for this phase, and the error is the moment a beginner
gives up.

**Independent Test**: run each refused sample and each broken sample; every one shows its own guidance.

**Acceptance Scenarios**:

1. **Given** a source with a `#version` line, **When** Run is pressed, **Then** the refusal says Shader Studio
   supplies the GLSL ES 3.00 version itself and the line must be removed, and names its line.
2. **Given** a source that uses `u_speed` without declaring it, **When** Run is pressed, **Then** the guidance tells
   the person to declare it as `uniform float u_speed;`.
3. **Given** a project uniform the source never declares, **Then** the guidance names it and says to declare it or
   remove it from the inspector.
4. **Given** each refusal code, **Then** its guidance is specific (no two codes share one sentence) and the preview
   is unchanged.

---

### User Story 2 - A slow shader never locks the studio (Priority: P1)

A person writes a shader so heavy that frames take far longer than they should. Shader Studio stops the preview,
says it was too slow, and offers to go back to the last shader that ran well. The person keeps editing without
relaunching.

**Why this priority**: manual risk 1 (user GLSL triggers expensive driver behaviour); a release blocker.

**Independent Test**: feed drawn-frame intervals into the watchdog; slow frames for the declared window stop the
preview, normal frames never do, and Reset restores the last good shader.

**Acceptance Scenarios**:

1. **Given** drawn frames slower than the limit for the whole window, **Then** the preview stops and the status says
   so with a Reset action.
2. **Given** Reset, **Then** the last good shader draws again and editing continues; no relaunch.
3. **Given** normal frames, or one slow frame inside a normal run, **Then** the watchdog never stops the preview.
4. **Given** a stopped preview, **Then** no further frame of the slow shader is drawn until Run or Reset.

---

### User Story 3 - Keep projects between visits (Priority: P2)

A person saves the current shader as a named project, sees it in a library, opens it later, renames it or removes it.
A damaged file, or one from a newer version of the app, is listed as unreadable and never deleted by itself.

**Why this priority**: version 0.1 feature 05; persistence of the edited source was left to this phase by A22-P03.

**Independent Test**: save, open, rename and remove round-trip in the experience's storage; the caps refuse with a
message; damaged and newer files are refused and still present afterwards.

**Acceptance Scenarios**:

1. **Given** a source and its uniform values and texture choices, **When** it is saved as "Waves" and opened later,
   **Then** the source, the values and the texture choices are the same, and the inspector shows its uniforms.
2. **Given** the library holds its maximum, **When** another is saved, **Then** it is refused with a message and
   nothing on disk changes.
3. **Given** a damaged file and a newer-version file, **Then** both are listed as unreadable with their reason, cannot
   be opened, and remain on disk.
4. **Given** a rename to a name another project has, **Then** it is refused with a message.

### Edge Cases

- **A guidance for a compiler error Shader Studio does not recognise:** the raw message is shown with a general
  sentence ("Check the line above for a typing mistake").
- **The watchdog during a context rebuild or a resize:** the frames around it do not count as slow.
- **A slow template after Reset:** the watchdog starts again on the restored shader.
- **Saving a project that is currently refused:** it is saved as text (the person's work is kept); opening it
  shows its refusal again.
- **Opening a project whose source is now refused:** it opens in the editor with its refusal and guidance; the
  preview keeps the last good shader.
- **A full storage quota:** the save is refused with a message and the previous file is unchanged.
- **Large text size and a hardware keyboard:** the library, the guidance and the Reset action stay usable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A22-401**: Every validator refusal code MUST have its own guidance sentence naming what to change; a
  `#version` line and a uniform used but not declared MUST each have a specific guidance, with the line where known.
- **FR-A22-402**: Common compiler diagnostics (an undeclared identifier, a type mismatch, a missing semicolon) MUST
  map to a guidance sentence; any other diagnostic MUST keep its raw message with a general sentence.
- **FR-A22-403**: A watchdog MUST stop the preview when every drawn frame of a window of 8 is slower than 0.25 s,
  MUST ignore the first interval after a setup, resize, Run or Reset, and MUST NOT stop a preview of normal frames.
- **FR-A22-404**: A stopped preview MUST draw nothing of the slow shader, MUST say why, and MUST offer Reset, which
  restores the previous shader the watchdog had not stopped (or the template's starter) without a relaunch and
  without a compile from the control.
- **FR-A22-405**: Named projects MUST be saved, listed, opened, renamed and removed in the experience's own storage,
  as versioned files holding the source, uniforms, uniform values and texture choices; the caps (24 projects, names of
  1 to 40 characters, 131,072 bytes a file) MUST refuse with a message and change nothing.
- **FR-A22-406**: Damaged, oversized and newer-version project files MUST be listed as unreadable with their reason,
  MUST NOT open, and MUST NOT be deleted except by the person.
- **FR-A22-407**: Every new control MUST carry a spoken label and value, work at large text sizes, and be usable with a
  hardware keyboard; interface tests MUST cover a guidance after a broken run and saving then opening a project, in
  the one app on the iOS 27 phone.

### Key Entities

- **Guidance**: a refusal or diagnostic, with the sentence that tells the person what to change and the line, if any.
- **Watchdog**: the frame-time limit, the window, the recent drawn-frame intervals, and the state (watching,
  stopped).
- **Saved project**: a name, an order, the project (source, uniforms, texture inputs), the uniform values and the
  texture choices; versioned.
- **Library**: the saved projects, readable and unreadable, with the caps.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A22-401**: 100% of refusal codes and of the listed compiler errors show their own guidance; 0 refusals show
  only a code.
- **SC-A22-402**: A slow window stops the preview in 100% of injected runs and a normal run in 0%; after Reset the
  last good shader draws again with no relaunch.
- **SC-A22-403**: A saved project opens with an identical source, values and texture choices; 100% of damaged and
  newer files remain on disk after listing and opening attempts.
- **SC-A22-404**: The interface tests each finish in under 60 seconds and unit tests in under 10 seconds.

## Assumptions

- The A22-P01 validator, the A22-P02 preview pipeline and the A22-P03 editor and inspector are reused.
- Digital Zen Garden's `GardenLibrary` is the pattern for the library (one file per project, a counter, an index).
- The watchdog's limit (0.25 s) and window (8 frames) are declared constants; the device campaign (A22-P05) measures
  them on devices.
- Watchdog tests inject frame intervals; no test waits for real slow frames.

## Traceability

| Source | Requirement |
|---|---|
| MVP: parameter inspector for bounded uniforms (A22-P03, proved again after opening) | FR-A22-405, US3/AC1 |
| Regression fixture: missing uniforms and incompatible GLES versions show specific guidance | FR-A22-401, 402, SC-A22-401 |
| Version 0.1 features 05, 06 | FR-A22-405, 406, 403, 404 |
| Risk 1 (expensive driver behaviour: watchdog, stop and reset) | FR-A22-403, 404 |
| Contract G-LIBRARY, G-WATCHDOG | FR-A22-403–406 |

## Negative Requirements

- No VisualCore or ProjectM change; no GL call outside VisualCore's scenes; no compile from a control's action.
- No sandbox claim: the watchdog stops drawing, it does not make GPU code safe.
- No network, no account, no file outside the experience's storage, no automatic deletion.
- Not available before X-A22.
