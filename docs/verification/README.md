# Verification records

This folder holds the tracked results of verification runs. Raw material stays out of Git.

## Experience scenarios (UA-F09)

`python3 scripts/verify_experiences.py --only <id> --runtime 27 26` runs an experience's scenarios on the iOS 27.x
and iOS 26.5 simulators (Auto-Creator.md section 22). For each experience and runtime it writes one summary:

`docs/verification/<id>/summary-<runtime>.json`

```json
{
  "schema": 1,
  "experience": "<id>",
  "runtime": "27.2",
  "runtime_build": "<build>",
  "device_type": "com.apple.CoreSimulator.SimDeviceType.<type>",
  "commit": "<commit the summary was written at>",
  "results": [{"scenario": "<name>", "result": "pass|fail|not-run", "record_sha256": "<hex>", "commit": "<hex>"}],
  "bundle": {"result": "Passed", "total": 9, "passed": 9, "failed": 0}
}
```

A summary names no simulator identifier and no device name. Each `record_sha256` is the hash of the full
evidence record (schema 1, section 22.3). That hash is computed with `artifacts.record_sha256` set to null,
because a file cannot hold its own hash.

The records themselves, the frames, the logs and the exported result-bundle attachments go to
`.autonomy/verify/<run>/`. That folder is ignored by Git and checked by `python3 scripts/check_evidence.py`. Result
bundles go to `.autonomy/xcresults/`.

## Other files

`devices-observed.json`, `environment-F00.json`, `projectm-baseline.md` and `source-hashes.json` are records of
earlier features; they are kept as they are.
