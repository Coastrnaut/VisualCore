# Data Model: A08-P03

- **ScopeDisplay**: {waveform 0, xy 1, spectrum 2}; spoken "spectrum".
- **SpectrumReadout** (OscilloscopeStudioCore): `enum Validity { case valid, noSignal, clipping, filling }`;
  `frequency: Double?` (Hz, rounded to 1), `levelDB: Double?` (rounded to 0.1), `binWidth: Double`; built from the
  magnitudes, the analysed samples, the sample rate, the frame size 4,096 and the written-frame count. Value present only
  when `valid`.
- **SpectrumView** (OscilloscopeStudioCore): `static func columns(magnitudesDB:sampleRate:size:width:) -> [(column: Int, levelDB: Double)]`
  (strongest bin per column on a log axis from 20 Hz to Nyquist), `static func points(… in rect:) -> [TracePoint]`
  (0 dBFS top, ≤ −100 dBFS bottom), `static func decadeMarks(sampleRate:width:) -> [(frequency: Double, x: Double)]`
  (100, 1,000, 10,000 Hz below Nyquist), `static let levelMarks = [0, −20, −40, −60, −80, −100]`.
- **ScopeState**: schema 2; `display` 0…2.
