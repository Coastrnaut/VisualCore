# Visual Programming Lab — device campaign plan (A23-P05, feature 170)

These checks need real devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3, and D3 is not updated from iPadOS 26.5. Until then every row is pending, and no memory, frame time,
pacing, heat, battery or accessibility figure is claimed anywhere. Simulator results never stand in for these rows:
the simulator does not run the device's GPU driver, gives no thermal state and no Low Power Mode cadence on real
hardware, and does not show how a finger reaches a port on an iPhone screen. Every row is a device task (FR-A23-505,
SC-A23-505 in [the feature spec](../../../specs/170-vpl-p05-budget-usability/spec.md)) and closes the device part of
gap G-DEVICE in [visualcore-contract.json](visualcore-contract.json) ([.md](visualcore-contract.md)). Runs are short
(minutes at most, no soak); a longer session is bounded by arithmetic from the short run, never run (owner ruling of
2026-11-13). The pattern is Shader Studio's [device campaign](../shader-studio/device-campaign.md) and Aurora's
[device campaign](../aurora/device-campaign.md).

Visual Programming Lab (`a23.visual-programming-lab`) composes a picture from a typed node graph (Time, Constant,
Noise, Gradient, Mix, Blur and Output; at most 32 nodes and 64 connections) and previews it on the OpenGL ES →
ANGLE → Metal path. The compiler (`GraphCompiler`) turns an accepted graph into a pass schedule whose slots are
256 × 256 rgba8 render targets of 262,144 bytes each (`PassSchedule.bytesPerSlot`); a schedule needing more than
6 slots (`PassSchedule.slotLimit`), that is more than 6 × 262,144 = 1,572,864 bytes (1.5 MiB), is refused before any
target is allocated, with the sentence "This graph needs N textures; the preview allows 6." The three example graphs
are written in code (`LabExamples`): Clouds (`clouds`), Soft gradient (`soft-gradient`) and Mixed clouds
(`mixed-clouds`, the journey graph: noise, gradient, mix, blur-h, blur-v and output, 6 passes), the largest of them.
The canvas has port targets of 44 × 44 canvas points (44 screen points at the default zoom 1; `CanvasLayout`) and a
zoom of 0.5 to 2 (`CanvasView`); every canvas edit is also possible without dragging in the list form (`node-list`:
per input a picker of "None" and every output of every other node), with the status line (`status`) and the sentence
of the last refusal (`feedback`). The preview asks for at most 30 frames per second (`LabPresenter.maxFramesPerSecond`)
and can be hidden with the "Preview" switch. The resource level is the host registry's `ResourceRegistry.stats`:
`liveCount` for every kind, `totalBytes`, and `leaked`; the preview's state, slots and passes per frame are read
from the presenter's `pipeline` (`state`, `slots`, `runCount`) on the development build. The devices are D1 iPhone 15
(iOS 27), D2 iPad Pro 13-inch (M5) and D3 iPad (A16) on iPadOS 26.5.

Owner actions: the devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps,
installing the development build, charging and unplugging, Low Power Mode, and turning VoiceOver, the text size and
Reduce Motion on and off in Settings are done by the owner. Each such step is recorded as `BLOCKED_OWNER_ACTION` with
its exact steps when the campaign reaches it, and the other rows continue.

A note on VPL-D1: the slot bytes follow from the schedule by arithmetic (`slotCount` × 262,144), so the device row
checks that the registry reports the same bytes as the schedule on real hardware and that no example comes near the
budget unexpectedly; it does not measure a budget. The pacing seen is recorded as observed, with no figure claimed
beforehand.

| Row | Device | Steps | Expected result | Owner actions | State |
|---|---|---|---|---|---|
| VPL-D1-D1 | D1 | Open Visual Programming Lab on the development build and open the example Mixed clouds from "Examples". Read the pipeline's `slots` count and `runCount` over one frame and `ResourceRegistry.stats` (through the debugger); watch the preview for a minute from a screen recording and note the frame pacing the system reports. | The schedule draws 6 passes per frame; the registry's render-target bytes equal `slotCount` × 262,144 and are at most 1,572,864 bytes (1.5 MiB, the 6-slot static budget); `leaked` stays 0; the preview animates without a visible stall; the pacing is recorded as read, no figure claimed beforehand | device in hand, unlock, trust, developer mode, signing, install | pending |
| VPL-D1-D2 | D2 | As VPL-D1-D1 on D2. | As VPL-D1-D1 | device in hand, unlock, trust, developer mode, signing, install | pending |
| VPL-D1-D3 | D3 | As VPL-D1-D1 on D3. | As VPL-D1-D1 | device in hand, unlock, trust, developer mode, signing, install | pending |
| VPL-D2-D1 | D1 | On the development build, read `ResourceRegistry.stats`, then draw a graph needing 7 slots through the presenter's `graphOverride` seam (the graph the stress test uses), read the stats again, then clear the override and return to the example. | The preview shows "This graph needs 7 textures; the preview allows 6." and draws no pass of that graph; `liveCount` for every kind and `totalBytes` are the same before and after the refusal (nothing allocated) and `leaked` stays 0; the example draws again after the override is cleared | as VPL-D1-D1 | pending |
| VPL-D2-D2 | D2 | As VPL-D2-D1 on D2. | As VPL-D2-D1 | as VPL-D1-D2 | pending |
| VPL-D2-D3 | D3 | As VPL-D2-D1 on D3. | As VPL-D2-D1 | as VPL-D1-D3 | pending |
| VPL-D3-D1 | D1 | On the iPhone, build the journey graph by hand (Time into Noise, Noise and Gradient into Mix, Mix into Blur, Blur into Output) by dragging wires on the canvas at zoom 1, then pinch to the smallest and the largest zoom and connect a port at each; drag a colour output onto a scalar input. Then build the same graph again only through the list form (`add-node` and the input pickers), without dragging. | Every port is reached by a finger with its 44-point target at the default zoom and the target scales with the zoom; the mismatched wire is refused with its sentence in `feedback`; the list form reaches every input and output without dragging, the status reads "Ready" and both graphs draw the same picture | as VPL-D1-D1 | pending |
| VPL-D3-D2 | D2 | As VPL-D3-D1 on D2. | As VPL-D3-D1, at the iPad size in the regular width | as VPL-D1-D2 | pending |
| VPL-D3-D3 | D3 | As VPL-D3-D1 on D3. | As VPL-D3-D1, at the iPad size in the regular width | as VPL-D1-D3 | pending |
| VPL-D4-D1 | D1 | Open Mixed clouds and run the preview for a few minutes on battery until the device reports a raised thermal state, if it does, and once with Low Power Mode on; note the thermal state and the frame pacing the system reports for each short run. | The preview stays at or under 30 frames per second, keeps animating and stays responsive to edits; a lower cadence under heat or Low Power Mode changes the pacing only; the pacing and thermal state are recorded as read, with no figure claimed, and a longer session is bounded by arithmetic from the short run | charging and unplugging, Low Power Mode on and off; as VPL-D1-D1 | pending |
| VPL-D4-D2 | D2 | As VPL-D4-D1 on D2. | As VPL-D4-D1 | charging and unplugging, Low Power Mode on and off; as VPL-D1-D2 | pending |
| VPL-D4-D3 | D3 | As VPL-D4-D1 on D3. | As VPL-D4-D1 | charging and unplugging, Low Power Mode on and off; as VPL-D1-D3 | pending |
| VPL-D5-D1 | D1 | Open Mixed clouds and read `ResourceRegistry.stats` on the development build. Send the app to the background, wait a few seconds, bring it back, and read the stats again; repeat three times, once with the preview hidden by the "Preview" switch and once with Output disconnected (status "Output not connected"). | The preview is rebuilt the same: the same graph, picture and state (drawing, hidden or invalid) as before; `liveCount` for every kind and `totalBytes` are the same before and after, and `leaked` stays 0 | as VPL-D1-D1 | pending |
| VPL-D5-D2 | D2 | As VPL-D5-D1 on D2. | As VPL-D5-D1 | as VPL-D1-D2 | pending |
| VPL-D5-D3 | D3 | As VPL-D5-D1 on D3. | As VPL-D5-D1 | as VPL-D1-D3 | pending |
| VPL-D6-D1 | D1 | The deferred accessibility audits (`VC_RUN_AUDITS=1`, run only on devices). With VoiceOver on, build Clouds through the list form only (add Time, Noise and Output, choose each input's source) and hear the status and a refusal's sentence; set the largest accessibility text size and repeat with the list form and the library; turn Reduce Motion on and open each example. | VoiceOver reaches every control of the list form with its spoken label ("Noise 2", "Noise 1 image → Output 2 image") and reads the status and the refusal sentence; at the largest text size every control stays reachable and no text is cut off; the behaviour under Reduce Motion is recorded as observed; the system audits report no issue, and any issue found is recorded as a follow-up task | VoiceOver, the text size and Reduce Motion on and off in Settings; as VPL-D1-D1 | pending |
| VPL-D6-D2 | D2 | As VPL-D6-D1 on D2. | As VPL-D6-D1 | VoiceOver, the text size and Reduce Motion on and off in Settings; as VPL-D1-D2 | pending |
| VPL-D6-D3 | D3 | As VPL-D6-D1 on D3. | As VPL-D6-D1 | VoiceOver, the text size and Reduce Motion on and off in Settings; as VPL-D1-D3 | pending |

## Record

Results are entered here only from a run on the named device after `ImplementationLock-100`, with the date, the build
(commit) and the evidence reference. A failed expectation is recorded as a follow-up task, not a pass.

| Row | Date | Build | Result | Evidence |
|---|---|---|---|---|
