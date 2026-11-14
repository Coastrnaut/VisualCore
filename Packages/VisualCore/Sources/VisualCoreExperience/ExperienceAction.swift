// ExperienceAction — feature 188 T-U02-009 (FR-U02-030, FR-U02-031, FR-U02-034, FR-U02-035; contract
// specs/188-ua-f02-experience-sdk/contracts/experience-core-api.md, section "Actions"). The controls an experience
// declares, the actions made with them, and the pure checks that decide whether an action is well formed before a
// core ever sees it. Nothing here knows a view, a touch or a clock: positions arrive as numbers.
import Foundation

/// A control an experience declares: an id and the legal range of each value an action for it carries.
public struct ExperienceControl: Sendable, Equatable {
    /// The largest number of values one action can carry: 24 since feature 043 (A05-P04 T-A05-416), so that one atomic
    /// action can restore a whole saved document (Infinite Geometry's `composition.open` carries 18); 8 before.
    public static let maxValues = 24

    /// The id actions name the control by.
    public let id: String
    /// The legal range of each value, one per value; at most `maxValues` entries.
    public let ranges: [ClosedRange<Double>]

    /// Creates a control. Ranges beyond `maxValues` are dropped; a control without ranges takes no values.
    public init(id: String, ranges: [ClosedRange<Double>] = []) {
        self.id = id
        self.ranges = Array(ranges.prefix(Self.maxValues))
    }
}

/// One action of a player or a script: a control, its values and the step it was made for.
public struct ExperienceAction: Sendable, Equatable, Codable {
    /// The id of the control the action uses.
    public let control: String
    /// The values of the action, one per range of the control.
    public let values: [Double]
    /// The index of the fixed step the action was made for.
    public let step: Int

    /// Creates an action for a control at a step.
    public init(control: String, values: [Double] = [], step: Int) {
        self.control = control
        self.values = values
        self.step = step
    }
}

/// An action without its step, for plans and scenarios; the step is given when the action is played.
public struct ScriptedAction: Sendable, Equatable, Codable {
    /// The id of the control the action uses.
    public let control: String
    /// The values of the action, one per range of the control.
    public let values: [Double]

    /// Creates a scripted action for a control.
    public init(_ control: String, _ values: [Double] = []) {
        self.control = control
        self.values = values
    }
}

/// The pure checks on input: whether an action is well formed, and where a point lies in a view.
public enum ExperienceInput {
    /// Checks an action against the declared controls and returns why it is refused, or nil when it is well formed.
    ///
    /// The checks run in this order: the control is declared, the number of values equals the number of ranges,
    /// every value is finite (the first index that is not is reported), every value lies in its range (the first
    /// index that does not is reported). When two declared controls share an id, the first one counts.
    public static func validate(control: String, values: [Double], controls: [ExperienceControl]) -> ActionRejection? {
        guard let declared = controls.first(where: { $0.id == control }) else { return .unknownControl(control) }
        let ranges = declared.ranges
        guard values.count == ranges.count else {
            return .wrongValueCount(expected: ranges.count, found: values.count)
        }
        if let index = values.firstIndex(where: { !$0.isFinite }) { return .nonFinite(index: index) }
        for (index, pair) in zip(values, ranges).enumerated() where !pair.1.contains(pair.0) {
            return .outOfRange(index: index)
        }
        return nil
    }

    /// The position as fractions of the view, 0…1 on both axes.
    ///
    /// Returns nil when a value is not finite, when the width or the height is 0 or below, and when the point lies
    /// outside the view (the edges belong to the view).
    public static func normalized(x: Double, y: Double, width: Double, height: Double) -> (x: Double, y: Double)? {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite else { return nil }
        guard width > 0, height > 0 else { return nil }
        guard x >= 0, x <= width, y >= 0, y <= height else { return nil }
        return (x: x / width, y: y / height)
    }
}
