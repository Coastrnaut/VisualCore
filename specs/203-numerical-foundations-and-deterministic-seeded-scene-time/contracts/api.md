# Public API contract: R02-F03 (all additions; nothing existing changes)

```swift
// VisualCoreSimulation
public enum SeedDerivation {
    public static func mix(_ z: UInt64) -> UInt64
    public static func fnv1a64(_ label: String) -> UInt64
    public static func derive(_ seed: UInt64, label: String) -> UInt64
    public static func derive(_ seed: UInt64, index: UInt64) -> UInt64
}
extension SeededRandom {
    public init(seed: UInt64, label: String)
    public init(seed: UInt64, index: UInt64)
    public mutating func index(below n: Int) -> Int                       // one draw
    public mutating func shuffle<T>(_ items: inout [T])                   // n − 1 draws
    public mutating func shuffled<T>(_ items: [T]) -> [T]
    public mutating func pick<T>(_ items: [T]) throws(RandomChoiceError) -> T
    public mutating func weightedIndex(_ weights: [Double]) throws(RandomChoiceError) -> Int
    public struct State: Codable, Sendable, Equatable {
        public let version: Int; public let seed: String; public let words: [String]
        public init(version: Int, seed: String, words: [String])   // added in implement: lets callers and tests build states
    }
    public var state: State { get }
    public init(restoring state: State) throws(RandomStateError)
}
public enum RandomChoiceError: Error, Equatable, Sendable { case empty, negativeWeight(Int), nonFiniteWeight(Int), zeroTotal }
public enum RandomStateError: Error, Equatable, Sendable { case unsupportedVersion(Int), wrongWordCount, malformedWord(String), allZero }

// VisualCoreMath
public enum ShaderHash {
    public static func pcg(_ v: UInt32) -> UInt32
    public static func hash11(_ p: Float) -> Float
    public static func hash21(_ x: Float, _ y: Float) -> Float
    public static func hash22(_ x: Float, _ y: Float) -> (Float, Float)
}
public enum NumericHygiene {
    public static func finite(_ x: Double, or fallback: Double) -> Double
    public static func normalizedAngle(_ radians: Double) -> Double          // [−π, π)
    public static func wrapped(_ x: Double, modulus: Double) throws(NumericError) -> Double
    public static func quantized(_ x: Double, step: Double) throws(NumericError) -> Int64
}
public enum NumericError: Error, Equatable, Sendable { case nonFinite, nonPositiveModulus, nonPositiveStep, outOfRange }
```
