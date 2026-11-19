// NodeLibrary — feature 166 (A23-P01) T-A23-103 (FR-A23-103; clarification Q1; data-model.md "NodeKind"). The seven
// node kinds of the Visual Programming Lab and, for each, its input ports, output ports and parameters exactly as the
// spec's clarification table:
//
//   time      no inputs                                   → time (time)            rate 0…4, 1
//   constant  no inputs                                   → value (scalar),        value −8…8, 1; red, green, blue
//                                                           colour (colour)        0…1, 1
//   noise     time (time, optional), scale (scalar, opt.) → image (texture)        scale 0.5…32, 4; octaves 1…6, 4;
//                                                                                  speed 0…4, 0.5
//   gradient  start (colour, opt.), end (colour, opt.)    → image (texture)        angle 0…360 degrees, 90
//   mix       a, b (texture, required), amount (scalar)   → image (texture)        amount 0…1, 0.5
//   blur      image (texture, required), radius (scalar)  → image (texture)        radius 0…16 pixels, 4
//   output    image (texture, required)                   → none                   none
//
// Choices recorded here: the parameters are `ParameterDefinition`s built once with `try?`; a definition that failed
// to build would be left out (the documented fallback, never a crash), and LibraryTests proves every one of them is
// present with its range and default. Blur has an input and an output both named `image`, so ports are looked up by
// direction (`input(_:)`, `output(_:)`). An empty optional scalar input uses the parameter of the same name; an empty
// gradient colour input uses black (`start`) or white (`end`); the drawing of each kind comes in A23-P03.
import Foundation
import VisualCoreParameters

/// A kind of node in a visual graph. Each kind declares its input ports, output ports and parameters (at most 6).
public enum NodeKind: String, Codable, Sendable, CaseIterable {
    /// Gives the running time, scaled by `rate`.
    case time
    /// Gives a constant number (`value`) and a constant colour (`red`, `green`, `blue`).
    case constant
    /// Gives a noise image of `scale`, `octaves` and `speed`, driven by an optional time input.
    case noise
    /// Gives a linear gradient image between two colours at `angle` degrees.
    case gradient
    /// Gives the blend of images `a` and `b` by `amount`.
    case mix
    /// Gives `image` blurred by `radius` pixels.
    case blur
    /// Takes the final image of the graph; it has no outputs and no parameters.
    case output

    /// The kind's input ports, in declaration order.
    public var inputs: [PortDeclaration] {
        switch self {
        case .time, .constant: return []
        case .noise: return [.input("time", .time, required: false), .input("scale", .scalar, required: false)]
        case .gradient: return [.input("start", .colour, required: false), .input("end", .colour, required: false)]
        case .mix:
            return [.input("a", .texture, required: true), .input("b", .texture, required: true),
                    .input("amount", .scalar, required: false)]
        case .blur: return [.input("image", .texture, required: true), .input("radius", .scalar, required: false)]
        case .output: return [.input("image", .texture, required: true)]
        }
    }

    /// The kind's output ports, in declaration order (never required).
    public var outputs: [PortDeclaration] {
        switch self {
        case .time: return [.output("time", .time)]
        case .constant: return [.output("value", .scalar), .output("colour", .colour)]
        case .noise, .gradient, .mix, .blur: return [.output("image", .texture)]
        case .output: return []
        }
    }

    /// The kind's parameters, in declaration order (at most 6).
    public var parameters: [ParameterDefinition] {
        Self.library[self] ?? []
    }

    /// The input port named `name`, or nil when the kind declares no such input.
    public func input(_ name: String) -> PortDeclaration? {
        inputs.first { $0.name == name }
    }

    /// The output port named `name`, or nil when the kind declares no such output.
    public func output(_ name: String) -> PortDeclaration? {
        outputs.first { $0.name == name }
    }

    /// The parameter named `name`, or nil when the kind declares no such parameter.
    public func parameter(_ name: String) -> ParameterDefinition? {
        parameters.first { $0.name == name }
    }

    /// The parameters of every kind, built once.
    private static let library: [NodeKind: [ParameterDefinition]] = [
        .time: definitions([("rate", "Rate", "", 0...4, 1)]),
        .constant: definitions([("value", "Value", "", -8...8, 1), ("red", "Red", "", 0...1, 1),
                                ("green", "Green", "", 0...1, 1), ("blue", "Blue", "", 0...1, 1)]),
        .noise: definitions([("scale", "Scale", "", 0.5...32, 4), ("octaves", "Octaves", "", 1...6, 4),
                             ("speed", "Speed", "", 0...4, 0.5)]),
        .gradient: definitions([("angle", "Angle", "degrees", 0...360, 90)]),
        .mix: definitions([("amount", "Amount", "", 0...1, 0.5)]),
        .blur: definitions([("radius", "Radius", "pixels", 0...16, 4)]),
        .output: [],
    ]

    /// One row of the parameter table: name, title, unit, range and default.
    private typealias Row = (name: String, title: String, unit: String, range: ClosedRange<Double>, value: Double)

    /// The definitions of `rows`; a row that is not a valid definition is left out (LibraryTests proves none is).
    private static func definitions(_ rows: [Row]) -> [ParameterDefinition] {
        rows.compactMap { row in
            try? ParameterDefinition(name: row.name, title: row.title, unit: row.unit, range: row.range,
                                     defaultValue: row.value)
        }
    }
}
