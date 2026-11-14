# Research: A06-P04

- **D1 Event mapping.** Decision: `AudioSessionEvent.init?(name:userInfo:)` maps interruption type began → `.interruptionBegan`,
  ended → `.interruptionEnded(shouldResume: options contains .shouldResume)`; route change with reason
  `.oldDeviceUnavailable` → `.routeLost`; media services reset → `.mediaServicesReset`; anything else → nil. Rationale:
  pure and table-testable without a device.
- **D2 Monitor.** Decision: `AudioSessionEventMonitor(center:handler:)` registers three observers on the given center
  (object nil) and removes them in `deinit`/`stop()`; handler is `@MainActor`. Tests post synthetic notifications on a
  private `NotificationCenter`.
- **D3 Capture seam.** Decision: internal `protocol MicrophoneCapture { func start(into: SampleRingBuffer) throws ->
  Double; func stop() }`; `SystemMicrophoneCapture` holds the session/engine code moved from `MicrophoneAudioSource`;
  the public init uses it and a monitor on `.default`; an internal init takes `makeCapture: () -> MicrophoneCapture` and
  an optional center. `engineStartCount` counts captures started; a `runningCaptures` counter proves ≤ 1.
- **D4 Reactions.** began → capture.stop(), state `.interrupted` (keep the buffer); ended(true) → restart into the kept
  buffer (state `.running` or `.failed`); ended(false) → stay `.interrupted` until `resume()`; routeLost/mediaReset →
  stop + restart when running or interrupted-with-resume; restart failure → `.failed(reason)`; events while idle/failed
  are ignored.
- **D5 Presets.** Decision: Core `MusicPreset` (id UUID, name ≤ 60 chars cleaned, scene, choices count = scene's parameter
  count, saved Date; format 1 file coding) and three built-ins with fixed UUIDs `00000000-0000-4000-8000-0000000006a{1,2,3}`
  (synthetic, pre-push safe); experience `MusicLabPresetLibrary` follows `GeometryLibrary` (entries, unreadable, newer,
  lastMessage; unique names ignoring case with " 2", " 3"…).
- **D6 Apply action.** `preset.apply [0…2, 0…6, 0…4, 0…6, 0…4, 0…6, 0…4]`; for a 2-parameter scene slot 3 values must be 0
  (else refused as rule `a06.no-such-parameter`).
- **D7 Status.** Presenter maps (source kind, state) → status text and recovery button per clarification 5.
- **D8 Contract.** G-INTERRUPTION closed in A06-P04; row M15 available with evidence (`AudioSessionEvent`,
  `AudioSessionEventMonitor`, `MicrophoneAudioSource`).
