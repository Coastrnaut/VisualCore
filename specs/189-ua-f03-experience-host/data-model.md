# Data model: UA-F03

Signatures: [contracts/session-api.md](contracts/session-api.md).

## 1. Session states and transitions

| From | Legal targets |
|---|---|
| idle | preparing |
| preparing | running, suspended, failed, closing |
| running | suspended, failed, closing |
| suspended | running, failed, closing |
| failed | preparing (Retry), idle (Back) |
| message | idle (Back), preparing (another open) |
| closing | idle, message |

17 legal pairs of 49; every other pair, including a state with itself, is rejected and counted. A session starts
idle. `preparing → suspended` is a preparation that finished while the app was not active.

## 2. Order of a close

`stopClock`, `handOutSnapshot`, `beginDeactivation`, `destroyHost`, `readCounts`, `finishDeactivation`,
`becomeIdle`. The session appends each step it takes to a record; the tests compare the record with this list.
A close of a preparing experience takes only `cancelPreparation` and `becomeIdle`.

## 3. Order of an open

`closePrevious` (when something is open), `prepare`, `restoreSnapshot` (when one was given), `createHost`,
`activate` (or `suspend` when the phase is not active), `firstFrame`. Durations are kept for `prepare`,
`createHost`, `activate` and `firstFrame`, in seconds; a stage that did not happen has no duration.

## 4. Memory-pressure rule

After shedding: close with a message when `liveBytes > limit`, where `limit` is the request's limit or, without
one, half of the budget's total (at least 1).

## 5. Session failure

`code` and `message` (an `ExperienceFailure`) and the `stage`: `prepare`, `restore`, `createHost`, `setup`,
`draw`, `context`, `close`. Codes added by the session: `session.host-failed` (the render host could not be
created), `session.context-lost` (the context could not be recreated), `session.sink-failed` (the snapshot sink
threw; recorded, not shown as a failure view). Codes of the experience contract are passed through unchanged.

## 6. Session diagnostics (encoded with sorted keys)

`state`, `experience` (id, absent when idle), `experienceDiagnostics` (absent without an experience), `timings`,
`lastCloseCounts` (GPU counts after the last close), `opens`, `closes`, `failures`, `cancelledPreparations`,
`supersededOpens`, `memoryClosures`, `contextRecreations`, `sinkFailures`, `rejectedTransitions`, `lastFailure`,
`lastCloseSteps`.

## 7. Isolation tool output

`PASS|FAIL: <path> — <n> Swift files, <m> isolation problems` (the existing line for `--app`, now also per
`--experiences` folder), `  FAIL <file>:<line>: <match>` per problem, and
`PASS: <path> — nothing checked (no Swift sources yet)` for a missing or empty folder.
