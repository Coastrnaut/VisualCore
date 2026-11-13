# Contract: FrameBudgetMonitor (PU Core, internal to the experience package)

`init(budget: Double = 1.0/60, maxTier: Int = 3)` · `var tier: Int { get }` · `mutating func record(frameTime: Double) -> Int`
· `mutating func restart()`. Deterministic for a given sequence; ignores non-finite and non-positive times.
