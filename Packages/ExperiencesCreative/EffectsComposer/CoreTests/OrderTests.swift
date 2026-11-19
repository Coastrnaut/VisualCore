// OrderTests — feature 180 (A25-P01) T-A25-108 (FR-A25-103, FR-A25-105; SC-A25-103; clarification Q4; the manual
// Phase 01 regression fixture "effect order changes output and can be undone precisely"). A chain built with
// `EditHistory` (add grade, add posterize, contrast 2, levels 4) is drawn on the GPU as grade → posterize; moving
// posterize first draws a different picture; undoing the move restores the chain exactly and draws the first picture
// byte for byte. The CPU references differ the same way and agree after the undo.
import Testing
import EffectsComposerCore

@MainActor
@Suite(.serialized) struct OrderTests {
    /// The fixture's chains: grade (contrast 2) → posterize (4), the chain after the move, the chain after the undo.
    static func chains() throws -> (first: EffectChain, moved: EffectChain, undone: EffectChain) {
        var history = EditHistory()
        var chain = EffectChain()
        for edit: ChainEdit in [.add(.grade, at: 0), .add(.posterize, at: 1),
                                .setValue(at: 0, name: "contrast", value: 2),
                                .setValue(at: 1, name: "levels", value: 4)] {
            chain = try history.apply(edit, to: chain).get()
        }
        let first = chain
        let moved = try history.apply(.move(from: 1, to: 0), to: first).get()
        let undone = try history.undo(moved).get()
        return (first, moved, undone)
    }

    @Test func theOrderChangesThePictureAndUndoingRestoresItByteForByte() throws {
        let (first, moved, undone) = try Self.chains()
        #expect(first.nodes.map(\.effect) == [.grade, .posterize])
        #expect(moved.nodes.map(\.effect) == [.posterize, .grade])
        #expect(undone == first, "the undo restores the chain exactly")
        #expect(undone.fingerprint() == first.fingerprint())

        let image = TestImage.make()
        let (a, b, c) = try EffectHost.run { context -> (RGBAImage, RGBAImage, RGBAImage) in
            let drawer = try EffectDrawer(registry: context.resources)
            defer { drawer.release() }
            return (try drawer.draw(first.nodes, on: image), try drawer.draw(moved.nodes, on: image),
                    try drawer.draw(undone.nodes, on: image))
        }
        let swapped = PictureCompare.maxDifference(a, b)
        print("a25-order: grade→posterize vs posterize→grade max channel difference \(swapped.max)/255")
        #expect(a != b, "grade → posterize and posterize → grade draw different pictures")
        #expect(c == a, "after the undo the picture is byte-identical to the first")
        #expect(a != image && b != image)

        let cpuFirst = EffectReference.apply(first, to: image)
        let cpuMoved = EffectReference.apply(moved, to: image)
        #expect(cpuFirst != cpuMoved, "the references differ the same way")
        #expect(EffectReference.apply(undone, to: image) == cpuFirst)
    }
}
