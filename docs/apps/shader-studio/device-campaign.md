# Shader Studio — device campaign plan (A22-P05, feature 163)

These checks need real devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3, and D3 is not updated from iPadOS 26.5. Until then every row is pending, and no frame time, stop time,
heat, battery or capability value is claimed anywhere. Simulator results never stand in for these rows: the
simulator does not run the device's GPU driver, so it cannot show how a slow shader behaves on it, what the device's
ANGLE context reports, or how a hardware keyboard reaches the editor on an iPhone. Every row is a device task
(FR-A22-505, SC-A22-504 in [the feature spec](../../../specs/163-ss-p05-stress-recovery/spec.md)) and closes the
device part of gap G-DEVICE in [visualcore-contract.json](visualcore-contract.json) ([.md](visualcore-contract.md)).
Runs are short (minutes at most, no soak); a longer session is bounded by arithmetic from the short run, never run
(owner ruling of 2026-11-13). The pattern is Aurora's [device campaign](../aurora/device-campaign.md).

Shader Studio (`a22.shader-studio`) edits and runs a GLSL ES fragment shader on the OpenGL ES → ANGLE → Metal path.
It offers four templates written in code: Gradient (`gradient`), Noise flow (`noise-flow`), Rings (`rings`) and
Texture mix (`texture-mix`, two texture inputs). A project is capped at 16,384 bytes of source, 400 lines, 16 uniforms
and 2 texture inputs (`ShaderLimits.standard`), and the expanded shader at 64 KiB. Run (⌘R on a hardware keyboard)
compiles the editor's source; a compile error is listed as "Line N: message" against the line the person wrote, and
Next error (⌘') moves the cursor to the next line with a diagnostic. The watchdog (`FrameWatchdog`) stops the preview
after 8 consecutive frame intervals each above 0.25 s; one interval after a Run or a Reset is skipped, because it
spans the rebuild. The preview then draws a flat dark frame, the status reads "Stopped: frames took longer than
0.25 s", and "Reset preview" brings back the last good program. The library (`ProjectLibrary`) keeps up to 24
projects with names of 1 to 40 characters, each saved file at most 131,072 bytes, with the source, the uniform values
and the textures. The resource level is the host registry's `ResourceRegistry.stats`: `liveCount` for every kind,
`totalBytes`, and `leaked`. The compatibility profile is read from `RenderHost.capabilities` (`RenderCapabilities`:
`glVersion`, `glslVersion`, `fragmentHighp`, `maxTextureSize`). The devices are D1 iPhone 15 (iOS 27), D2 iPad Pro
13-inch (M5) and D3 iPad (A16) on iPadOS 26.5.

Owner actions: the devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps,
installing the development build, and connecting a hardware keyboard are done by the owner. Each such step is recorded
as `BLOCKED_OWNER_ACTION` with its exact steps when the campaign reaches it, and the other rows continue.

A note on SS-D1: the stop needs the skipped interval and then 8 counted intervals, so 9 intervals each above 0.25 s
follow the Run. A stop within 3 s therefore needs frames slower than 0.25 s but under about 0.33 s
(9 × 0.33 s ≈ 3 s); a slower shader stops later by the same arithmetic. The frame interval of the slow template is
recorded with each run, so that a late stop can be told apart from a watchdog fault.

| Row | Device | Steps | Expected result | Owner actions | State |
|---|---|---|---|---|---|
| SS-D1-D1 | D1 | Open Shader Studio, choose a template and edit it into a slow shader (more work per pixel, within the source caps) whose frames take a little over 0.25 s. Run it and time from Run to the status "Stopped: frames took longer than 0.25 s" from a screen recording; record the frame interval. Tap "Reset preview". | The preview stops within 3 s of Run (for intervals under about 0.33 s), shows the flat dark frame and "Reset preview"; Reset brings back the last good program and the app stays responsive throughout | device in hand, unlock, trust, developer mode, signing, install | pending |
| SS-D1-D2 | D2 | As SS-D1-D1 on D2, with the slow shader adjusted so its frames take a little over 0.25 s on this device. | As SS-D1-D1 | device in hand, unlock, trust, developer mode, signing, install | pending |
| SS-D1-D3 | D3 | As SS-D1-D1 on D3, with the slow shader adjusted so its frames take a little over 0.25 s on this device. | As SS-D1-D1 | device in hand, unlock, trust, developer mode, signing, install | pending |
| SS-D2-D1 | D1 | Open Gradient, write a line with an error (for example an undeclared name) in the middle of the source and Run. Repeat with the error on the first and on the last line. | The status reads "Failed: N errors"; the diagnostics list "Line N: message" with N the line the person wrote, the gutter marks that line, and tapping the diagnostic moves the cursor there; the preview keeps the last good program | as SS-D1-D1 | pending |
| SS-D2-D2 | D2 | As SS-D2-D1 on D2. | As SS-D2-D1 | as SS-D1-D2 | pending |
| SS-D2-D3 | D3 | As SS-D2-D1 on D3. | As SS-D2-D1 | as SS-D1-D3 | pending |
| SS-D3-D1 | D1 | With a hardware keyboard connected, type a change into the editor, press ⌘R, then add two errors, press ⌘R and press ⌘' twice. | Typing reaches the editor with no autocorrection or capitalisation; ⌘R runs the shader as the Run button does; ⌘' moves the cursor to each line with a diagnostic in turn; the editor and the preview stay usable at the iPhone size | the owner connects a hardware keyboard to the iPhone (Bluetooth or USB-C); as SS-D1-D1 | pending |
| SS-D3-D2 | D2 | As SS-D3-D1 on D2. | As SS-D3-D1, with the editor beside the inspector in the regular width at the default text size | the owner connects a hardware keyboard; as SS-D1-D2 | pending |
| SS-D3-D3 | D3 | As SS-D3-D1 on D3. | As SS-D3-D1, with the editor beside the inspector in the regular width at the default text size | the owner connects a hardware keyboard; as SS-D1-D3 | pending |
| SS-D4-D1 | D1 | Edit a template, change a uniform value (and, in Texture mix, a texture), open the library and save it as "Waves". Close the app from the app switcher and open it again; open the library and open "Waves". | "Waves" is listed after the relaunch and opens with the saved source, uniform values and textures, and runs | as SS-D1-D1 | pending |
| SS-D4-D2 | D2 | As SS-D4-D1 on D2. | As SS-D4-D1 | as SS-D1-D2 | pending |
| SS-D4-D3 | D3 | As SS-D4-D1 on D3. | As SS-D4-D1 | as SS-D1-D3 | pending |
| SS-D5-D1 | D1 | Open Shader Studio on the development build and record `RenderHost.capabilities` (through the session's renderer record or the debugger): `glVersion`, `glslVersion`, `fragmentHighp`, `maxTextureSize`. Run each of the four templates. | The GLES and GLSL ES versions, fragment `highp` support and the maximum texture size are recorded as read; every template compiles and draws; nothing is claimed that the context does not report | as SS-D1-D1 | pending |
| SS-D5-D2 | D2 | As SS-D5-D1 on D2. | As SS-D5-D1 | as SS-D1-D2 | pending |
| SS-D5-D3 | D3 | As SS-D5-D1 on D3. | As SS-D5-D1 | as SS-D1-D3 | pending |
| SS-D6-D1 | D1 | Run Texture mix and read `ResourceRegistry.stats` on the development build. Send the app to the background, wait a few seconds, bring it back, and read the stats again; repeat three times, once with the preview stopped by the watchdog. | The picture comes back as it was (the same shader and values, or the stopped frame with "Reset preview"); `liveCount` for every kind and `totalBytes` are the same before and after, and `leaked` stays 0 | as SS-D1-D1 | pending |
| SS-D6-D2 | D2 | As SS-D6-D1 on D2. | As SS-D6-D1 | as SS-D1-D2 | pending |
| SS-D6-D3 | D3 | As SS-D6-D1 on D3. | As SS-D6-D1 | as SS-D1-D3 | pending |

## Record

Results are entered here only from a run on the named device after `ImplementationLock-100`, with the date, the build
(commit) and the evidence reference. A failed expectation is recorded as a follow-up task, not a pass.

| Row | Date | Build | Result | Evidence |
|---|---|---|---|---|
