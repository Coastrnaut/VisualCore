# Contract: robustness (G-ROBUST)

- Context rebuild: `release` then `setup` rebuild programs, the intermediate format, the source (from kept bytes) and
  the result; the next render is byte-identical (10 rebuilds).
- Export interrupted: `beforeReadBack` calls `recreateContext`; the export fails as `a25.export-interrupted`, no file
  exists in the export folder, and the next export succeeds.
- Size change: presenting into two framebuffer sizes letterboxes the same result; the result read-back is unchanged.
- Memory warning: posting `UIApplication.didReceiveMemoryWarningNotification` on the presenter's centre trims idle
  pooled targets (`ResourceRegistry.stats` live count drops or stays) and the next preview is byte-identical.
- Device plan: `docs/apps/effects-composer/device-plan.md`, rows for D1, D2, D3 tagged {device}.
