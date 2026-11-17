# Living Wallpapers — device campaign plan (A19-P05, feature 142)

These measurements need real devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3, and D3 is not updated from iPadOS 26.5. Until then every row is pending, and no size limit, colour,
heat, memory or accessibility number is claimed anywhere. Simulator results never stand in for these rows: the
simulator's size limit is larger than every template, so no template is refused there. Every row is a {device} task
(FR-A19-503, FR-A19-504) and closes the device part of gap G-DEVICE in
[visualcore-contract.json](visualcore-contract.json).

Living Wallpapers plans every export before anything is allocated (`ExportPlanner`, A19-P01). A template fits when
both edges are at most the presenter's export limit (the context's maximum texture size,
`context.resources.maxTextureSize`), the long edge is at most `ExportGeometry.hardMaxEdge` (8192) and the pixel count
is at most `ExportGeometry.defaultMaxPixels` (64,000,000). A template that does not fit is refused, and the notice
beside the template picker (`export-notice`) offers the largest size that fits at the template's aspect, exported
with `export-offered`. Every file is encoded tagged sRGB (PNG, JPEG or HEIC), read back and checked against the
plan's size and profile before it is written (`StillExport`, A19-P02), and it leaves the app only through the system
share sheet (`share`). The app makes no Photos or system-wallpaper call; Save Image in the share sheet uses the app's
add-only usage string "Saves exported artwork to your photo library when you choose Save Image."

The nine templates (`CanvasTemplates`) run from iPhone SE (3rd generation), 750 × 1334, to iPad Pro 13-inch (M4),
2064 × 2752 portrait, the largest by pixel count. The longest single edge is iPhone 16 Pro Max's 2868, so LW-D1 and
LW-D2 check that template's fit too.

Owner actions: the devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps,
answering the Photos prompt, and changing or resetting the Photos permission in Settings are done by the owner. Each
such step is recorded as `BLOCKED_OWNER_ACTION` with its exact steps when the campaign reaches it, and the other rows
continue.

| Row | Measurement | Device | Procedure | Threshold | Status |
|---|---|---|---|---|---|
| LW-D1 | Size limit | D1 reference iPhone (iOS 27), D2, D3 | Open Living Wallpapers and record the context's maximum texture size (the presenter's export limit, kept as `maxTextureSize` in the session's renderer record) and `RenderHost.maxRenderSize` (the least of the maximum texture size, renderbuffer size and viewport edges, which the offscreen render checks). Then pick each of the nine templates in both orientations and note whether `export-notice` appears. | the limit is recorded per device and is at least the OpenGL ES 3.0 floor of 2048; the notice appears exactly for the templates with an edge above the recorded limit, and for no other | pending device campaign |
| LW-D2 | Largest template | D1, D2, D3 | Pick iPad Pro 13-inch (M4) in landscape (2752 × 2064) and export as PNG; repeat with iPhone 16 Pro Max in portrait (1320 × 2868). Where `export-notice` appears, export with `export-offered`. | no crash; a template that fits exports at exactly its size; one that does not shows the notice naming the template's size, the device limit and the offered size, and the offered export is written at the offered size | pending device campaign |
| LW-D3 | Written file's size and colour profile | D1, D2, D3 | For the LW-D2 exports and one each in JPEG and HEIC (where the device offers HEIC), read the result line (format, size, sRGB). Open the file from Save to Files and read its pixel size and colour profile in the file's information; then Save Image in the share sheet and read the same in Photos' information panel. | the pixel size equals the planned size and the profile is sRGB in the result line, in Files and in Photos; the image looks the same in Photos as in the app's preview | pending device campaign |
| LW-D4 | Heat during ten largest exports | D1, D2, D3 | Ten exports of the LW-D2 iPad Pro 13-inch landscape size (or its offered size) back to back, with the scene drawing between them. Record `ProcessInfo.thermalState` every 5 s (Instruments, thermal state) from the first export to one minute after the last. | thermal state never reaches `.critical`; every export ends written or with its stated reason, with no crash; any time at `.serious` is recorded | pending device campaign |
| LW-D5 | Memory during the largest export | D1, D2, D3 | During LW-D4, record the footprint before the first export, its high-water mark during each export and after the last (Instruments, Allocations and VM Tracker). | no memory warning or termination; the peak rise during one export is at most four RGBA buffers of the exported size (2752 × 2064 × 4 bytes is about 22.7 MB each, so about 91 MB), the bound to check; the footprint after the tenth export returns to its level after the first (the render target is released on every path) | pending device campaign |
| LW-D6 | Add-only Photos prompt | D1, D2, D3 | On a fresh install, export, open `share` and choose Save Image. The owner answers the prompt and allows adding (owner action). | the prompt asks only to add photos and shows the app's usage string word for word; the image appears in Photos; the app never asks for full library access | pending device campaign |
| LW-D7 | Declined path | D1, D2, D3 | With adding to Photos declined (the owner declines the first prompt, or turns the permission off in Settings; owner action), export, choose Save Image, then Save to Files. | declining shows no app error and no crash; Save to Files writes the file, which LW-D3's check reads at its planned size and sRGB; the history still lists the export | pending device campaign |
| LW-D8 | Accessibility audit | D1, D2, D3 | Run the system accessibility audits (`VC_RUN_AUDITS=1` only on devices, owner ruling of 2026-11-13) on the Living Wallpapers screen, its notice and result rows and its help sheet, at the default and the largest text size. | no audit issue in the Living Wallpapers screens or the help sheet at either size | pending device campaign |
