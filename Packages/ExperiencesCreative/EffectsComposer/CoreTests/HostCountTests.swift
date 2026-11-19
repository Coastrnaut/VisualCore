// HostCountTests — feature 180 (A25-P01) T-A25-110 (FR-A25-107; SC-A25-106; clarification Q5). A `RenderScene` on
// `RenderHost(scene:)` does the core's work in `setup` and in `render`, with the host's context current: it validates
// every `EffectLibrary` definition at its defaults, applies and undoes a sequence of chain edits, encodes and decodes
// the chain with `ChainDocument` and runs `EffectReference` on the test image. The host's resource level
// (`ResourceRegistry.stats`: `liveCount` for every kind and `totalBytes`) is the same before and after each pass,
// right after the host is up and after rendered frames, and each result inside the host equals the result outside
// it. The scene draws nothing and issues no GL call; the host only clears the frame (as the A24-P01 host-count test).
import Foundation
import Testing
import UIKit
import VisualCoreRendering
import EffectsComposerCore

/// A host's resource level: live objects per resource kind (keyed by the kind's name, every kind present) and live
/// bytes across all kinds.
struct ComposerHostLevel: Equatable, CustomStringConvertible {
    /// Live objects per resource kind, keyed by the kind's name.
    var liveCount: [String: Int]
    /// Live bytes across all kinds.
    var totalBytes: Int

    /// The level of `registry` now.
    @MainActor
    init(_ registry: ResourceRegistry) {
        let stats = registry.stats
        var counts: [String: Int] = [:]
        for (kind, count) in stats.liveCount { counts[String(describing: kind)] = count }
        liveCount = counts
        totalBytes = stats.totalBytes
    }

    /// "kind=n …, bytes=n", in kind-name order.
    var description: String {
        liveCount.keys.sorted().map { "\($0)=\(liveCount[$0, default: 0])" }.joined(separator: " ")
            + " bytes=\(totalBytes)"
    }
}

/// The core work of one pass.
struct ComposerCoreWork: Equatable {
    /// How many definitions validated at their defaults.
    let validatedDefinitions: Int
    /// The chain after every edit applied.
    let edited: EffectChain
    /// The chain after every edit undone.
    let undone: EffectChain
    /// The encoded edited chain.
    let encoded: Data
    /// The decoded file equals the edited chain.
    let decodedMatches: Bool
    /// The reference picture of the edited chain on the test image.
    let picture: RGBAImage

    /// The edits applied, in order.
    static let edits: [ChainEdit] = [
        .add(.grade, at: 0), .add(.blur, at: 1), .add(.posterize, at: 2), .add(.vignette, at: 0),
        .setValue(at: 1, name: "contrast", value: 1.5), .setValue(at: 2, name: "radius", value: 1),
        .setEnabled(at: 0, false), .move(from: 3, to: 1), .remove(at: 2),
    ]

    /// Does the work.
    static func perform() throws -> ComposerCoreWork {
        var validated = 0
        for definition in EffectLibrary.all {
            try definition.validate(values: definition.defaults)
            validated += 1
        }
        var history = EditHistory()
        var chain = EffectChain()
        for edit in edits { chain = try history.apply(edit, to: chain).get() }
        let edited = chain
        while history.canUndo { chain = try history.undo(chain).get() }
        let encoded = ChainDocument.encode(edited)
        let decoded = try ChainDocument.decode(encoded).get()
        return ComposerCoreWork(validatedDefinitions: validated, edited: edited, undone: chain, encoded: encoded,
                                decodedMatches: decoded == edited,
                                picture: EffectReference.apply(edited, to: TestImage.make()))
    }
}

/// A render scene that does the core work in `setup` and in every `render`, recording the results and the resource
/// level around each pass. It creates no resource and draws nothing.
@MainActor
final class ComposerCoreScene: RenderScene {
    /// One pass inside a host callback: the level before, the work, the level after.
    struct Pass {
        /// "setup" or "render <frame index>".
        let callback: String
        /// The level when the callback began.
        let before: ComposerHostLevel
        /// The work done in the callback.
        let work: ComposerCoreWork
        /// The level after the work.
        let after: ComposerHostLevel
    }

    /// Every pass, in callback order.
    private(set) var passes: [Pass] = []

    /// Does the work once and records the levels around it.
    private func workAll(_ context: RenderContext, callback: String) throws {
        let before = ComposerHostLevel(context.resources)
        let work = try ComposerCoreWork.perform()
        passes.append(Pass(callback: callback, before: before, work: work, after: ComposerHostLevel(context.resources)))
    }

    /// Does the core work.
    func setup(_ context: RenderContext) throws { try workAll(context, callback: "setup") }

    /// Nothing depends on the size.
    func resize(_ context: RenderContext) {}

    /// Does the core work again and draws nothing (the host clears the frame).
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        try workAll(context, callback: "render \(frame.index)")
    }

    /// Nothing to release.
    func teardown(_ context: RenderContext) {}
}

@MainActor
@Suite(.serialized) struct HostCountTests {
    @Test func theCoreWorkInsideTheHostCreatesNoGraphicsResource() throws {
        let outside = try ComposerCoreWork.perform()
        #expect(outside.validatedDefinitions == EffectID.allCases.count)
        #expect(outside.edited.nodes.count == 3)
        #expect(outside.undone == EffectChain(), "undoing every edit returns the empty chain")
        #expect(outside.decodedMatches && !outside.encoded.isEmpty)

        let scene = ComposerCoreScene()
        let host = try RenderHost(scene: scene)
        defer { host.destroy() }
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 12)
        host.view.layoutIfNeeded()
        let up = ComposerHostLevel(host.resources)
        #expect(!up.liveCount.isEmpty, "the level lists every resource kind (\(up))")

        let first = host.renderOneFrame(present: false)
        let afterFirst = ComposerHostLevel(host.resources)
        let second = host.renderOneFrame(present: false)
        let afterSecond = ComposerHostLevel(host.resources)
        #expect(first && second, "the host rendered two frames")
        #expect(afterFirst == up, "after the first frame: \(afterFirst) (up: \(up))")
        #expect(afterSecond == up, "after the second frame: \(afterSecond) (up: \(up))")

        let callbacks = scene.passes.map(\.callback)
        #expect(callbacks.first == "setup")
        #expect(callbacks.filter { $0.hasPrefix("render") }.count == 2, "two rendered frames: \(callbacks)")
        for pass in scene.passes {
            #expect(pass.after == pass.before, "\(pass.callback): \(pass.after) (before: \(pass.before))")
            #expect(pass.after == up, "\(pass.callback): \(pass.after) (up: \(up))")
            #expect(pass.work == outside, "\(pass.callback): the work inside the host equals the work outside")
        }
    }
}
