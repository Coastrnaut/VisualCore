// LissajousLabyrinthPending — feature 314 (R02-G02-04) T-R02G0204-003 (FR-R02G0204-006; SC-R02G0204-004; research R7).
// The panel's pending dial values: the steppers set or step a value per dial without sending an action, and Apply turns
// them into one action per changed dial. Only dials that differ from the current dials are held. The actions come in the
// order frequencyA, frequencyB, phaseA, phaseC, with the two frequencies swapped when only that order keeps every
// intermediate frequency pair coprime; when neither order does, the default order is returned so the kernel refuses its
// first action and Apply stops with the reason.

/// Pending dial values set from the panel and committed by Apply as one action per changed dial.
public struct LissajousLabyrinthPending: Sendable, Equatable {
    /// The pending value of each dial that differs from the current dials (a dial equal to its current value is absent).
    public private(set) var values: [LissajousLabyrinthDial: Int]

    /// No pending values.
    public init() {
        values = [:]
    }

    /// Whether nothing is pending.
    public var isEmpty: Bool { values.isEmpty }

    /// Sets the pending value of `dial` to `value`. A frequency outside 1 … 9 is clamped into it; a phase outside 0 … 15
    /// wraps into it (modulo 16). A value equal to the dial's current value removes the dial from ``values``.
    public mutating func set(_ dial: LissajousLabyrinthDial, _ value: Int, current: LissajousLabyrinthDials) {
        let range: ClosedRange<Int> = dial.range
        let fitted: Int
        switch dial {
        case .frequencyA, .frequencyB:
            fitted = min(max(value, range.lowerBound), range.upperBound)
        case .phaseA, .phaseC:
            fitted = Self.wrap(value, in: range)
        }
        if fitted == current[dial] {
            values[dial] = nil
        } else {
            values[dial] = fitted
        }
    }

    /// Steps `dial` by `delta` from its pending value, or from its current value when none is pending, wrapping within the
    /// dial's range as the steppers do (frequencies 9 + 1 → 1 and 1 − 1 → 9; phases 15 + 1 → 0 and 0 − 1 → 15). A result
    /// equal to the current value removes the dial from ``values``.
    public mutating func step(_ dial: LissajousLabyrinthDial, by delta: Int, current: LissajousLabyrinthDials) {
        let base: Int = values[dial] ?? current[dial]
        set(dial, Self.wrap(base + delta, in: dial.range), current: current)
    }

    /// Drops every pending value.
    public mutating func clear() {
        values = [:]
    }

    /// One action per pending dial that differs from `current`, in the order frequencyA, frequencyB, phaseA, phaseC.
    ///
    /// When both frequencies change from (a, b) to (a′, b′) and the intermediate pair (a′, b) is not coprime but (a, b′)
    /// is, frequencyB comes first so every intermediate pair is coprime. When neither (a′, b) nor (a, b′) is coprime, the
    /// default order is returned: the kernel then refuses its first action (`.move("not-coprime")`), so Apply stops with
    /// that reason. A pending value equal to `current` (the dials changed since it was set) yields no action.
    public func actions(from current: LissajousLabyrinthDials) -> [LissajousLabyrinthAction] {
        var result: [LissajousLabyrinthAction] = []
        for dial in LissajousLabyrinthDial.allCases {
            if let value = values[dial], value != current[dial] {
                result.append(LissajousLabyrinthAction(dial: dial, value: value))
            }
        }
        if result.count >= 2, result[0].dial == .frequencyA, result[1].dial == .frequencyB {
            let newA: Int = result[0].value
            let newB: Int = result[1].value
            let aFirst: Bool = LissajousLabyrinthDials.gcd(newA, current.frequencyB) == 1
            let bFirst: Bool = LissajousLabyrinthDials.gcd(current.frequencyA, newB) == 1
            if !aFirst && bFirst { result.swapAt(0, 1) }
        }
        return result
    }

    /// `value` wrapped into `range` (modulo the range's width).
    private static func wrap(_ value: Int, in range: ClosedRange<Int>) -> Int {
        let width: Int = range.count
        let offset: Int = ((value - range.lowerBound) % width + width) % width
        return range.lowerBound + offset
    }
}
