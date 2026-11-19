// PreviewPipeline — feature 168 (A23-P03) T-A23-303 (FR-A23-301, FR-A23-303, FR-A23-304, FR-A23-306, FR-A23-307;
// SC-A23-301–303, SC-A23-305; clarifications Q2, Q4, Q5; data-model.md "PreviewState", "PreviewPipeline";
// contracts/preview.md "Presenter"). The preview of the graph, drawn through VisualCore inside the host's context:
//
//   - Compile (`compile(_:context:)`, called by the presenter at a draw only): the graph goes through
//     `GraphCompiler.compile` first. A refused graph (`invalid`, or `overBudget` for the budget) allocates nothing and
//     frees nothing: the state becomes `invalid(message)` or `refused(message)` and no pass is drawn. An accepted
//     schedule then gets the operator programs it does not yet hold (one `FieldPass` per program of `Operators`,
//     built once per context, Blur's two passes sharing one) and exactly its slots: `slotCount` render targets of
//     256 × 256 `.rgba8` from `ResourceRegistry.makeRenderTarget` (charged to the host's budget), kept when the
//     count is the same, added or released when it changed. A program that does not build gives `failed(message)`.
//     Every call counts in ``compileCount``.
//   - Draw (`draw(_:time:)`): in `ready` only, each pass of the schedule in order, its inputs the slots it names,
//     its uniforms from `PreviewValues` at the frame time (floats `u_<name>`, colours `vec4` with alpha 1, only those
//     the program keeps), into its slot; the `output` pass into the context's framebuffer at (0, 0) with a square
//     side of ``insetSide(width:height:)`` (a third of the drawable's shorter side, the bottom-left inset, because a
//     field pass sets its viewport from the origin). A run that throws gives `failed(message)`; nothing is thrown, so
//     the canvas keeps drawing.
//   - Context: `release(_:)` (teardown) releases every program and slot and keeps the schedule and the state;
//     `restore(_:)` (setup after a context loss) builds them again from the same schedule without a compile.
//     Feature 170 (A23-P05) T-A23-504 (SC-A23-503): a rebuild leaves the level as it was in every state, so
//     `release(_:)` also notes which programs and how many slots were held and `restore(_:)` makes those again: the
//     programs of earlier schedules (kept, as built once per context) and, in `invalid` or `refused`, the slots the
//     refusal kept (a refusal frees nothing). In `failed` only the schedule's own rebuild is tried, as before.
//   - Test seams: ``fragmentOverrides`` (an operator text replaced, for a failing build), ``runCount`` (passes run),
//     ``slots``, ``schedule`` and ``programs``.
//
// No GL call: programs, targets and draws are VisualCore's (`FieldPass`, `RenderTarget`, `ResourceRegistry`).
import Foundation
import VisualCoreRendering
import VisualProgrammingLabCore

/// What the preview shows.
enum PreviewState: Equatable, Sendable {
    /// The graph's picture is drawn.
    case ready
    /// The checker refused the graph; the message is its status line ("Output not connected").
    case invalid(String)
    /// The schedule needs more textures than the budget allows; the message says how many.
    case refused(String)
    /// A program did not build or a pass did not run on the graphics driver; the message is the first diagnostic.
    case failed(String)
    /// The preview is switched off (view state).
    case hidden

    /// The text the inset shows instead of a picture; nil in `ready`.
    var message: String? {
        switch self {
        case .ready: return nil
        case .invalid(let text), .refused(let text): return text
        case .failed(let text): return "The preview could not be drawn: " + text
        case .hidden: return "Preview hidden"
        }
    }
}

/// The preview's programs, slots and passes (see the file header).
@MainActor
final class PreviewPipeline {
    /// The side of a slot, pixels (256).
    static let slotSide = PassSchedule.previewSize

    /// The side of the bottom-left inset of a `width` × `height` drawable: a third of the shorter side, pixels.
    nonisolated static func insetSide(width: Int, height: Int) -> Int {
        max(0, min(width, height) / 3)
    }

    /// Replacement fragment texts by program name of `Operators.program(of:)` (a test seam; empty by default).
    var fragmentOverrides: [String: String] = [:]
    /// The programs built in this context, by program name.
    private(set) var programs: [String: FieldPass] = [:]
    /// The slots of the schedule, in slot order.
    private(set) var slots: [RenderTarget] = []
    /// The schedule drawn; nil before the first accepted compile and after a refused one.
    private(set) var schedule: PassSchedule?
    /// What the preview shows.
    private(set) var state = PreviewState.ready
    /// How many compiles ran.
    private(set) var compileCount = 0
    /// How many passes ran, over every draw (a test seam).
    private(set) var runCount = 0
    /// The operators whose programs and the number of slots held when the context was last released; made again by
    /// ``restore(_:)`` (feature 170).
    private var held: (operators: [PassOperator], slots: Int) = ([], 0)

    /// Compiles `graph` into a schedule and makes what it needs (see the file header).
    func compile(_ graph: VisualGraph, context: RenderContext) {
        compileCount += 1
        switch GraphCompiler.compile(graph) {
        case .failure(let refusal):
            schedule = nil
            switch refusal {
            case .invalid: state = .invalid(refusal.message)
            case .overBudget: state = .refused(refusal.message)
            }
        case .success(let next):
            schedule = next
            state = prepare(next, context: context)
        }
    }

    /// Builds the programs and slots of the current schedule again after a context loss (no compile), then the rest of
    /// what ``release(_:)`` noted (feature 170): the programs of earlier schedules and, in `invalid` or `refused`, the
    /// slots the refusal kept. Nothing more is made in `failed`; a cached program that does not build is skipped (a
    /// later compile that needs it reports it).
    func restore(_ context: RenderContext) {
        let noted = held
        held = ([], 0)
        switch state {
        case .ready:
            if let schedule { state = prepare(schedule, context: context) }
        case .invalid, .refused:
            break
        case .failed, .hidden:
            return
        }
        if case .failed = state { return }
        for op in noted.operators where programs[Operators.program(of: op)] == nil {
            _ = build(op, context: context)
        }
        while slots.count < noted.slots {
            guard let slot = makeSlot(context) else { return }
            slots.append(slot)
        }
    }

    /// The programs and slots of `schedule` made; `ready`, or `failed` with the first diagnostic.
    private func prepare(_ schedule: PassSchedule, context: RenderContext) -> PreviewState {
        for pass in schedule.passes {
            let name = Operators.program(of: pass.operator)
            if let existing = programs[name], existing.program.generation == context.resources.generation { continue }
            if let failure = build(pass.operator, context: context) { return .failed(failure) }
        }
        while slots.count > schedule.slotCount {
            context.resources.release(slots.removeLast())
        }
        while slots.count < schedule.slotCount {
            do {
                slots.append(try newSlot(context))
            } catch {
                return .failed("\(error)")
            }
        }
        return .ready
    }

    /// Builds the program of `op` in `context` (releasing one of an earlier context); nil, or the first diagnostic.
    private func build(_ op: PassOperator, context: RenderContext) -> String? {
        let name = Operators.program(of: op)
        programs[name]?.release()
        programs[name] = nil
        let fragment = fragmentOverrides[name] ?? Operators.fragment(of: op)
        do {
            programs[name] = try FieldPass(registry: context.resources, fragment: fragment,
                                           inputs: Operators.inputs(of: op), label: Operators.label(of: op))
            return nil
        } catch {
            if case .compile(let message) = error { return message }
            return "\(error)"
        }
    }

    /// A new 256 × 256 rgba8 slot charged to `context`'s registry, labelled by its index.
    private func newSlot(_ context: RenderContext) throws -> RenderTarget {
        try context.resources.makeRenderTarget(width: Self.slotSide, height: Self.slotSide, format: .rgba8,
                                               label: "vpl-preview-slot-\(slots.count)")
    }

    /// ``newSlot(_:)``, or nil when it cannot be made.
    private func makeSlot(_ context: RenderContext) -> RenderTarget? {
        try? newSlot(context)
    }

    /// Draws the schedule's passes into the slots and the inset (in `ready` only; see the file header).
    func draw(_ context: RenderContext, time: Double) {
        guard state == .ready, let schedule else { return }
        let side = Self.insetSide(width: context.pixelWidth, height: context.pixelHeight)
        for pass in schedule.passes {
            guard let program = programs[Operators.program(of: pass.operator)] else {
                state = .failed(Operators.label(of: pass.operator) + ": not built")
                return
            }
            var inputs: [String: RenderTarget] = [:]
            for (name, slot) in pass.inputs {
                guard slots.indices.contains(slot) else {
                    state = .failed("slot \(slot) missing")
                    return
                }
                inputs[name] = slots[slot]
            }
            let output: FieldPass.Output
            switch pass.target {
            case .slot(let slot):
                guard slots.indices.contains(slot) else {
                    state = .failed("slot \(slot) missing")
                    return
                }
                output = .target(slots[slot])
            case .framebuffer:
                guard side > 0 else { continue }
                output = .framebuffer(name: context.framebuffer, width: side, height: side)
            }
            do {
                try program.run(output: output, inputs: inputs, uniforms: Self.uniforms(pass, program.program,
                                                                                         time: time))
                runCount += 1
            } catch {
                state = .failed(Operators.label(of: pass.operator) + ": \(error)")
                return
            }
        }
    }

    /// The uniforms of `pass` at `time` that `program` keeps: floats `u_<name>` and colours `u_<name>` as vec4.
    static func uniforms(_ pass: Pass, _ program: ShaderProgram, time: Double) -> [String: FieldUniform] {
        var uniforms: [String: FieldUniform] = [:]
        for (name, value) in PreviewValues.floats(for: pass, time: time) where program.uniforms["u_" + name] != nil {
            uniforms["u_" + name] = .float(Float(value))
        }
        for (name, colour) in PreviewValues.colours(for: pass) where program.uniforms["u_" + name] != nil {
            uniforms["u_" + name] = .vec4(SIMD4(Float(colour.r), Float(colour.g), Float(colour.b), 1))
        }
        return uniforms
    }

    /// Releases every program and slot (teardown); the schedule and the state are kept for ``restore(_:)``.
    func release(_ context: RenderContext) {
        var seen: Set<String> = []
        held = (PassOperator.allCases.filter { op in
            let name = Operators.program(of: op)
            return programs[name] != nil && seen.insert(name).inserted
        }, slots.count)
        for pass in programs.values { pass.release() }
        programs = [:]
        for slot in slots { context.resources.release(slot) }
        slots = []
    }
}
