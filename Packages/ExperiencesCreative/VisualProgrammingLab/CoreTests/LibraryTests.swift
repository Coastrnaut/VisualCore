// LibraryTests — feature 166 (A23-P01) T-A23-105 (FR-A23-103; SC-A23-101; clarification Q1; US2 scenario 3). Every
// node kind declares its input ports, output ports and parameters exactly as the clarification table; every default
// lies in its range; port names are lowercase letters, 1…16; outputs are never required; at most 6 parameters; an
// optional scalar input has the parameter of the same name. Synthetic data only.
import Foundation
import Testing
import VisualCoreParameters
@testable import VisualProgrammingLabCore

@Suite struct LibraryTests {
    /// An expected port: name, type and whether it is required.
    private struct Port: Equatable {
        let name: String
        let type: ValueType
        let required: Bool
    }

    /// An expected parameter: name, range, default and unit.
    private struct Parameter: Equatable {
        let name: String
        let minimum: Double
        let maximum: Double
        let defaultValue: Double
        let unit: String
    }

    /// The expected declaration of one kind.
    private struct Expected {
        let inputs: [Port]
        let outputs: [Port]
        let parameters: [Parameter]
    }

    /// The clarification Q1 table.
    private static func expected(_ kind: NodeKind) -> Expected {
        switch kind {
        case .time:
            return Expected(inputs: [], outputs: [Port(name: "time", type: .time, required: false)],
                            parameters: [Parameter(name: "rate", minimum: 0, maximum: 4, defaultValue: 1, unit: "")])
        case .constant:
            let outputs: [Port] = [Port(name: "value", type: .scalar, required: false),
                                   Port(name: "colour", type: .colour, required: false)]
            var parameters: [Parameter] = [Parameter(name: "value", minimum: -8, maximum: 8, defaultValue: 1,
                                                     unit: "")]
            for name in ["red", "green", "blue"] {
                parameters.append(Parameter(name: name, minimum: 0, maximum: 1, defaultValue: 1, unit: ""))
            }
            return Expected(inputs: [], outputs: outputs, parameters: parameters)
        case .noise:
            let inputs: [Port] = [Port(name: "time", type: .time, required: false),
                                  Port(name: "scale", type: .scalar, required: false)]
            let parameters: [Parameter] = [
                Parameter(name: "scale", minimum: 0.5, maximum: 32, defaultValue: 4, unit: ""),
                Parameter(name: "octaves", minimum: 1, maximum: 6, defaultValue: 4, unit: ""),
                Parameter(name: "speed", minimum: 0, maximum: 4, defaultValue: 0.5, unit: "")]
            return Expected(inputs: inputs, outputs: [Port(name: "image", type: .texture, required: false)],
                            parameters: parameters)
        case .gradient:
            let inputs: [Port] = [Port(name: "start", type: .colour, required: false),
                                  Port(name: "end", type: .colour, required: false)]
            return Expected(inputs: inputs, outputs: [Port(name: "image", type: .texture, required: false)],
                            parameters: [Parameter(name: "angle", minimum: 0, maximum: 360, defaultValue: 90,
                                                   unit: "degrees")])
        case .mix:
            let inputs: [Port] = [Port(name: "a", type: .texture, required: true),
                                  Port(name: "b", type: .texture, required: true),
                                  Port(name: "amount", type: .scalar, required: false)]
            return Expected(inputs: inputs, outputs: [Port(name: "image", type: .texture, required: false)],
                            parameters: [Parameter(name: "amount", minimum: 0, maximum: 1, defaultValue: 0.5,
                                                   unit: "")])
        case .blur:
            let inputs: [Port] = [Port(name: "image", type: .texture, required: true),
                                  Port(name: "radius", type: .scalar, required: false)]
            return Expected(inputs: inputs, outputs: [Port(name: "image", type: .texture, required: false)],
                            parameters: [Parameter(name: "radius", minimum: 0, maximum: 16, defaultValue: 4,
                                                   unit: "pixels")])
        case .output:
            return Expected(inputs: [Port(name: "image", type: .texture, required: true)], outputs: [],
                            parameters: [])
        }
    }

    /// The ports of `declarations` in the shape of ``Port``.
    private static func ports(_ declarations: [PortDeclaration]) -> [Port] {
        declarations.map { Port(name: $0.name, type: $0.type, required: $0.required) }
    }

    /// The parameters of `definitions` in the shape of ``Parameter``.
    private static func parameters(_ definitions: [ParameterDefinition]) -> [Parameter] {
        definitions.map {
            Parameter(name: $0.name, minimum: $0.minimum, maximum: $0.maximum, defaultValue: $0.defaultValue,
                      unit: $0.unit)
        }
    }

    @Test func valueTypesAndKinds() {
        #expect(ValueType.allCases.map(\.rawValue) == ["scalar", "colour", "texture", "time"])
        #expect(PortDirection.input.rawValue == "input")
        #expect(PortDirection.output.rawValue == "output")
        #expect(NodeKind.allCases.map(\.rawValue) == ["time", "constant", "noise", "gradient", "mix", "blur", "output"])
    }

    @Test(arguments: NodeKind.allCases)
    func kindMatchesTable(_ kind: NodeKind) {
        let expected = Self.expected(kind)
        #expect(Self.ports(kind.inputs) == expected.inputs)
        #expect(Self.ports(kind.outputs) == expected.outputs)
        #expect(Self.parameters(kind.parameters) == expected.parameters)
    }

    @Test(arguments: NodeKind.allCases)
    func portsAreWellFormed(_ kind: NodeKind) {
        for port in kind.inputs {
            #expect(port.direction == .input)
            #expect(port.name.range(of: "^[a-z]{1,16}$", options: .regularExpression) != nil, "\(kind) \(port.name)")
            #expect(kind.input(port.name) == port)
        }
        for port in kind.outputs {
            #expect(port.direction == .output)
            #expect(port.required == false)
            #expect(port.name.range(of: "^[a-z]{1,16}$", options: .regularExpression) != nil, "\(kind) \(port.name)")
            #expect(kind.output(port.name) == port)
        }
        #expect(Set(kind.inputs.map(\.name)).count == kind.inputs.count)
        #expect(Set(kind.outputs.map(\.name)).count == kind.outputs.count)
        #expect(kind.input("nothing") == nil)
        #expect(kind.output("nothing") == nil)
    }

    @Test(arguments: NodeKind.allCases)
    func parametersAreWellFormed(_ kind: NodeKind) {
        #expect(kind.parameters.count <= 6)
        #expect(Set(kind.parameters.map(\.name)).count == kind.parameters.count)
        for definition in kind.parameters {
            #expect(definition.range.contains(definition.defaultValue), "\(kind) \(definition.name)")
            #expect(definition.minimum < definition.maximum)
            #expect(definition.transform == .linear)
            #expect(kind.parameter(definition.name) == definition)
        }
        #expect(kind.parameter("nothing") == nil)
    }

    @Test(arguments: NodeKind.allCases)
    func optionalScalarInputsHaveTheirParameter(_ kind: NodeKind) {
        for port in kind.inputs where port.type == .scalar {
            #expect(port.required == false)
            #expect(kind.parameter(port.name) != nil, "\(kind) \(port.name)")
        }
    }

    @Test func blurHasAnInputAndAnOutputNamedImage() throws {
        let input = try #require(NodeKind.blur.input("image"))
        let output = try #require(NodeKind.blur.output("image"))
        #expect(input.direction == .input)
        #expect(input.required)
        #expect(output.direction == .output)
        #expect(NodeKind.blur.input("radius")?.type == .scalar)
        #expect(NodeKind.blur.output("radius") == nil)
        #expect(NodeKind.output.outputs.isEmpty)
        #expect(NodeKind.output.parameters.isEmpty)
        #expect(NodeKind.time.inputs.isEmpty)
        #expect(NodeKind.constant.inputs.isEmpty)
    }
}
