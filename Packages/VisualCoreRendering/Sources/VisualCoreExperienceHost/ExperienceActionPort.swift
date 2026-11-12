// ExperienceActionPort — feature 188 T-U02-038 (FR-U02-050 to FR-U02-053, FR-U02-056, FR-U02-062, FR-U02-080;
// research R11; contract specs/188-ua-f02-experience-sdk/contracts/experience-host-api.md). The way from native
// controls to the experience: controls call `send`, and SwiftUI redraws from `revision` and `summary`.
import CoreGraphics
import Observation
import VisualCoreExperience

/// The port the controls of an experience use: it sends actions and tells observers when the state changed.
///
/// A port is created by the shell of its experience; a presenter receives it in `makeControls`.
@MainActor @Observable
public final class ExperienceActionPort {
    /// What carries out an action: the shell's `handle(control:values:)`.
    typealias Handler = @MainActor (String, [Double]) -> ActionResult

    /// Grows after every change of the state.
    public private(set) var revision: Int = 0
    /// The presenter's description of the current state; empty while there is no state.
    public private(set) var summary: String = ""
    /// The prefix of the accessibility identifiers of the experience (`ExperienceID.accessibilityPrefix`).
    public let accessibilityPrefix: String

    /// Carries out an action; the shell that owns the port sets it.
    @ObservationIgnored var handler: Handler

    /// Creates a port with the prefix of its experience and the closure that carries out an action.
    init(accessibilityPrefix: String, handler: @escaping Handler) {
        self.accessibilityPrefix = accessibilityPrefix
        self.handler = handler
    }

    /// Sends an action made now with the control `control` and returns the experience's answer.
    @discardableResult
    public func send(_ control: String, _ values: [Double] = []) -> ActionResult {
        handler(control, values)
    }

    /// Sends the position `point` inside a view of the size `size` as two fractions, 0…1 on both axes.
    ///
    /// A point outside the view (or a size that is not positive) is answered with
    /// `.rejected(.outOfRange(index: 0))` and nothing reaches the experience.
    @discardableResult
    public func send(_ control: String, at point: CGPoint, in size: CGSize) -> ActionResult {
        guard let position = ExperienceInput.normalized(x: Double(point.x), y: Double(point.y),
                                                        width: Double(size.width), height: Double(size.height)) else {
            return .rejected(.outOfRange(index: 0))
        }
        return handler(control, [position.x, position.y])
    }

    /// The accessibility identifier of the element `name`: `"<prefix>.<name>"`.
    public func identifier(_ name: String) -> String {
        accessibilityPrefix + "." + name
    }

    /// Records a change of the state: `revision` grows by one and `summary` becomes `summary`.
    func noteChange(summary: String) {
        revision += 1
        setSummary(summary)
    }

    /// Sets `summary` without a new revision (the state itself did not change, or it is gone).
    func setSummary(_ summary: String) {
        if self.summary != summary { self.summary = summary }
    }
}
