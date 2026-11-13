# Contract: FrameBudgetMonitor (PU Core, internal to the experience package)

`init(budget: Double = 1.0/60, maxTier: Int = 3, tier: Int = 0)` · `var tier: Int { get }` ·
`mutating func record(frameTime: Double) -> Int` · `mutating func restart()`. Deterministic for a given sequence;
ignores non-finite and non-positive times. `tier` is clamped to `0...maxTier`; a monitor rebuilt for a new budget
passes the old tier (T-A04-516).

# Contract: FrameIntervalEstimate (PU Core; research D7)

`init()` · `var interval: Double? { get }` · `mutating func observe(index: Int, target: Double) -> Double?` ·
`mutating func reset()`. The interval is the smallest step between the target timestamps of consecutive frame
indices, accepting steps of 1/240 s to 0.1 s; nil until a step is accepted; non-finite targets are ignored.
`ParticlePresenter.noteFrameTarget(index:target:)` feeds it every drawn frame and rebuilds the monitor when the
estimate differs from its budget by more than 10%; setup and teardown reset it.
