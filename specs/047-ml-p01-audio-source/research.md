# Research: A06-P01

- **D1 Ring buffer**: SPSC with power-of-two capacity, `Atomic<Int>` write/read indices (acquire/release), preallocated
  `UnsafeMutableBufferPointer<Float>`; writer overwrites on overflow (reader skips ahead); reader copies latest N.
  Alternatives: locks (blocks the audio thread — rejected), AVAudioPCMBuffer queues (allocate — rejected).
- **D2 Spectrum**: `vDSP.FFT` real forward on a Hann-windowed frame; magnitude dB = 20·log10(|X|/(N/2)); peak bin = argmax
  over bins 1…N/2−1. Expected bin = round(f·N/fs).
- **D3 Permission**: `AVAudioApplication.shared.recordPermission` / `AVAudioApplication.requestRecordPermission()` behind
  the `MicrophonePermission` protocol; `restricted` is reported when the session reports undetermined but recording is
  unavailable is not modelled — mapped from the system values (undetermined/denied/granted); `restricted` reserved for
  parental controls via `AVAudioApplication` when exposed, else never produced (documented).
- **D4 File source**: `AVAudioFile(forReading:)` with a processing format mono Float; read 4,096-frame chunks on a
  utility task into the ring buffer at real-time pace (timer driven by the sample rate); loop at end; security-scoped
  URL access held while running.
- **D5 Microphone**: `AVAudioEngine.inputNode.installTap(bufferSize: 1024, format:)` → mono mixdown into the ring buffer
  (no allocation in the tap: preallocated scratch); session category `.playAndRecord`? No — `.record` is not needed for
  visualisation only; use `.playAndRecord` with `.mixWithOthers` so the person's music keeps playing.
- **D6 Fixtures**: five planning fixtures map to manifest scenarios: sine (demo tone mode, FFT peak checked by the core's
  analysed peak), silence (silence mode → zero level), allocation (host test: ring-buffer write path makes no
  allocation, measured with a malloc counter in a short loop), permission denied → demo, interruption (source stop/start
  across suspend/resume and teardown/re-entry).
