# Effects Composer — device campaign plan (A25-P05, feature 184)

These measurements need real devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3, and D3 is not updated from iPadOS 26.5. Until then every row is pending, and no memory, timing, heat,
colour or accessibility number is claimed anywhere. Simulator results never stand in for these rows. Every row is a
{device} task (FR-A25-509) and closes the device part of gap G-ROBUST in
[visualcore-contract.json](visualcore-contract.json).

Effects Composer draws the chain at the picture's own size, at most 2,048 pixels on the longer edge (the smaller of
the context's maximum texture size and 2,048). A 2,048 × 2,048 picture holds a source and a result (16 MiB each,
8-bit), two intermediates (32 MiB each in half-float where the device can draw into it, 16 MiB each otherwise) and,
while exporting, one export result (16 MiB): 112 MiB of render targets at most, the bound to check. An export draws
the chain again into its own target, reads it back, encodes it as PNG, JPEG or HEIC tagged sRGB off the main thread
and leaves the app only through the system share sheet (`share`).

Owner actions: the devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, and
answering the add-only Photos prompt when Save Image is chosen in the share sheet are done by the owner. Each such
step is recorded as `BLOCKED_OWNER_ACTION` with its exact steps when the campaign reaches it, and the other rows
continue.

| Row | Measurement | Device | Procedure | Threshold | Status |
|---|---|---|---|---|---|
| EC-D1 | Peak memory | D1, D2, D3 | Import a picture of at least 4,000 × 3,000 pixels (decoded to 2,048 on its longer edge), build a chain of eight effects, edit for one minute and export once as PNG. Record the footprint before the import, its high-water mark while editing and while exporting, and after the export (Instruments, Allocations and VM Tracker). | no memory warning or termination; the rise is at most 200 MiB; the footprint after the export returns to its level before it | pending device campaign |
| EC-D2 | Preview frame time while editing | D1, D2, D3 | With the EC-D1 chain, drag a blur radius and an exposure value continuously for 30 s and record the frame times (Instruments, Animation Hitches). | 95% of frames within 33 ms; no hitch longer than 100 ms | pending device campaign |
| EC-D3 | Export time per format | D1, D2, D3 | With the EC-D1 picture and chain, export as PNG, JPEG and HEIC (where the device offers HEIC), three times each, timing from the tap to "Exported". | each export within 3 s; the status names a refused format instead of failing | pending device campaign |
| EC-D4 | Written file | D1, D2, D3 | Open one export of each format from Save to Files and read its pixel size and colour profile in the file's information; Save Image in the share sheet and read the same in Photos (owner answers the prompt). | the size equals the picture's; the profile is sRGB; the file looks the same as the preview | pending device campaign |
| EC-D5 | Recovery after backgrounding | D1, D2, D3 | During an export and, separately, while editing, send the app to the background for 30 s and return. | no crash; the preview returns unchanged; an export either completes or reports "The export was interrupted. Try again." and the next export succeeds | pending device campaign |
| EC-D6 | Heat during ten exports | D1, D2, D3 | Ten PNG exports of the EC-D1 picture back to back with the preview drawing between them; record `ProcessInfo.thermalState` every 5 s until one minute after the last. | thermal state never reaches `.critical`; every export ends written or with its stated reason | pending device campaign |
| EC-D7 | Accessibility audit | D1, D2, D3 | Run the system accessibility audits (`VC_RUN_AUDITS=1` only on devices, owner ruling of 2026-11-13) on the Effects Composer screen at the default and the largest text size. | no audit issue at either size | pending device campaign |
