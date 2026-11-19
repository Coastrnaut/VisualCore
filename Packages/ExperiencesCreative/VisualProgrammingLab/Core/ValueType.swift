// ValueType — feature 166 (A23-P01) T-A23-103 (FR-A23-101, FR-A23-103; clarification Q1; data-model.md "ValueType",
// "PortDirection", "PortDeclaration"). The four value types a connection carries (scalar, colour, texture, time), the
// two port directions, and one declared port of a node kind. A connection needs the same type on both ends; there is
// no implicit conversion (time does not feed a scalar input). Pure Foundation; no UI, GPU or clock.
import Foundation

/// The type of value that flows along a connection. Two ports connect only when their types are equal.
public enum ValueType: String, Codable, Sendable, CaseIterable {
    /// One number.
    case scalar
    /// A red, green and blue colour.
    case colour
    /// An image.
    case texture
    /// The running time of the graph.
    case time
}

/// Whether a port takes a value into its node or gives one out of it.
public enum PortDirection: String, Codable, Sendable {
    /// The port takes a value from a connection.
    case input
    /// The port gives a value to connections.
    case output
}

/// One port a node kind declares: its name (lowercase letters, 1…16), direction, value type and whether an input
/// must be fed. Outputs are never required.
public struct PortDeclaration: Equatable, Sendable {
    /// The port's name: lowercase letters, 1…16 characters, unique among the kind's ports of the same direction.
    public let name: String
    /// Whether the port is an input or an output.
    public let direction: PortDirection
    /// The type of value the port takes or gives.
    public let type: ValueType
    /// Whether an input must be fed for the graph to be accepted; always false for an output.
    public let required: Bool

    /// An input port named `name` of type `type`; `required` says whether it must be fed.
    static func input(_ name: String, _ type: ValueType, required: Bool) -> PortDeclaration {
        PortDeclaration(name: name, direction: .input, type: type, required: required)
    }

    /// An output port named `name` of type `type` (never required).
    static func output(_ name: String, _ type: ValueType) -> PortDeclaration {
        PortDeclaration(name: name, direction: .output, type: type, required: false)
    }
}
