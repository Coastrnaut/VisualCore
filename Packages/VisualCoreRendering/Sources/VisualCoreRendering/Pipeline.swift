// Pipeline.swift — immutable description of a draw's pipeline: a program plus its fixed-function state
// (feature 204 R02-F04 T-R02F04-009; FR-R02F04-020, -022; research D3). Applied as one unit by
// `GLState.apply(_:resources:)`.
import VisualCoreShaderSource

/// A draw's program and render state, applied together by `GLState.apply(_:resources:)`.
///
/// Two pipelines are equal when they name the same program object (identity, not GL name, so a program from an ended
/// context never equals its recompiled successor) and equal render states; equal pipelines hash equally, so a
/// pipeline can key a cache.
public struct Pipeline: Hashable {
    /// The program the draw uses; compared by object identity.
    public let program: ShaderProgram
    /// Blending, depth, culling and colour mask of the draw.
    public let state: RenderState

    /// A pipeline drawing with `program` under `state`.
    public init(program: ShaderProgram, state: RenderState) {
        self.program = program
        self.state = state
    }

    /// True when both pipelines use the same program object and equal render states.
    public static func == (lhs: Pipeline, rhs: Pipeline) -> Bool {
        lhs.program === rhs.program && lhs.state == rhs.state
    }

    /// Hashes the program's object identity and the render state.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(program))
        hasher.combine(state)
    }
}
