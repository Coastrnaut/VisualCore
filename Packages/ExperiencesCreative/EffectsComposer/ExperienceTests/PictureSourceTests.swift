// PictureSourceTests — feature 183 (A25-P04) T-A25-406 (clarification Q4; User Stories 1 and 4; contracts/import.md).
// The picture source through the one app's session host: an imported picture (generated in code with ImageIO, never
// bundled) becomes the source at its own size and the chain is applied to it (the result within 2/255 of
// `EffectReference.apply(chain:)` on the decoded picture, 4/255 with an enabled distort); a refused import (damaged
// data) leaves the source and shows the refusal's sentence; "use the test picture" returns the built-in picture; after
// `recreateContext` the source is byte-identical; a restored session shows the test picture; of two overlapping
// imports the latest wins and an earlier one finishing later is dropped (the decoder seam holds the first back). Short
// runs; no clock, no sleep.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct PictureSourceTests {
    /// A 96 × 64 sRGB picture with horizontal, vertical and patterned channels, as PNG data; `shift` changes it.
    static func gradient(shift: Int = 0) -> Data {
        let width = 96, height = 64
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                bytes[i] = UInt8((x * 255 / (width - 1) + shift) % 256)
                bytes[i + 1] = UInt8(y * 255 / (height - 1))
                bytes[i + 2] = UInt8(((x ^ y) * 4 + shift) % 256)
            }
        }
        let image = ImportFixtures.cgImage(width: width, height: height, bytes: bytes,
                                           space: CGColorSpace(name: CGColorSpace.sRGB)!)
        return ImportFixtures.png(image, properties: [:])
    }

    /// The picture `data` decodes to, as the import decodes it.
    static func decoded(_ data: Data) throws -> ImportedPicture {
        try ImageImport.decode(data, limit: ImageImport.maximumEdge).get()
    }

    /// The largest channel difference between the last result and the CPU reference of `chain` on `picture`.
    private func difference(_ shell: ExperienceShell<ComposerPresenter>, _ chain: EffectChain,
                            on picture: RGBAImage) throws -> Int {
        let result = try #require(shell.presenter.lastResult)
        #expect(result.width == picture.width && result.height == picture.height)
        return result.maxChannelDifference(EffectReference.apply(chain, to: picture))
    }

    @Test func anImportedPictureBecomesTheSourceAndTheChainAppliesToIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session, size: CGSize(width: 200, height: 150))
        let data = Self.gradient()
        let picture = try Self.decoded(data)
        #expect(picture.width == 96 && picture.height == 64)

        await shell.presenter.importPicture(data: data)
        #expect(shell.presenter.mirror.status == ComposerPresenter.yourPictureWord)
        try ComposerTest.draw(session)
        #expect(shell.presenter.renderer.pictureSource == .imported(picture))
        #expect(shell.presenter.lastResult == picture, "the empty chain shows the picture unchanged")
        #expect(shell.presenter.renderer.readSource() == picture)
        #expect(shell.presenter.probes(try ComposerTest.core(shell)).isEmpty, "the probe is the test picture's")

        var largest = 0
        let edits: [(String, [Double])] = [("chain.add", [0, 0]), ("chain.set", [0, 1, 0.8]), ("chain.add", [1, 1]),
                                           ("chain.add", [3, 2])]
        for (control, values) in edits {
            ComposerTest.accept(shell, control, values)
            try ComposerTest.draw(session)
            let chain = try ComposerTest.core(shell).chain
            let d = try difference(shell, chain, on: picture)
            #expect(d <= ComposerTest.tolerance(chain), "\(control) \(values): \(d)/255")
            largest = max(largest, d)
        }
        print("PictureSourceTests imported chain: largest difference \(largest)/255")
    }

    @Test func aRefusedImportLeavesTheSourceAndShowsTheMessage() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        let picture = try Self.decoded(Self.gradient())
        await shell.presenter.importPicture(data: Self.gradient())
        try ComposerTest.draw(session)
        #expect(shell.presenter.lastResult == picture)

        var damaged = Self.gradient()
        damaged.replaceSubrange(0..<16, with: [UInt8](repeating: 0x5A, count: 16))
        let start = shell.presenter.startImport(data: damaged)
        #expect(shell.presenter.mirror.status == ComposerPresenter.readingWord)
        await start.value
        #expect(shell.presenter.mirror.status == ImportRefusal.imageDamaged.message)
        try ComposerTest.draw(session)
        #expect(shell.presenter.renderer.pictureSource == .imported(picture))
        #expect(shell.presenter.renderer.readSource() == picture)
    }

    @Test func useTestPictureReturnsTheBuiltInPicture() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        ComposerTest.accept(shell, "chain.add", [4, 0])
        await shell.presenter.importPicture(data: Self.gradient())
        try ComposerTest.draw(session)
        #expect(shell.presenter.lastResult?.width == 96)

        shell.presenter.useTestPicture()
        #expect(shell.presenter.mirror.status == ComposerPresenter.readyWord)
        try ComposerTest.draw(session)
        #expect(shell.presenter.renderer.pictureSource == .testPicture)
        #expect(shell.presenter.renderer.readSource() == ComposerTest.image)
        let chain = try ComposerTest.core(shell).chain
        #expect(try ComposerTest.difference(shell, chain) <= ComposerTest.tolerance(chain))
    }

    @Test func theSourceIsByteIdenticalAfterAContextLoss() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        let picture = try Self.decoded(Self.gradient())
        await shell.presenter.importPicture(data: Self.gradient())
        ComposerTest.accept(shell, "chain.add", [1, 0])
        try ComposerTest.draw(session)
        let before = try #require(shell.presenter.lastResult)
        let host = try #require(session.renderHost)
        host.recreateContext()
        try ComposerTest.draw(session)
        #expect(shell.presenter.renderer.readSource() == picture, "the kept bytes are uploaded again")
        #expect(shell.presenter.lastResult == before)
    }

    @Test func aRestoredSessionShowsTheTestPicture() async throws {
        let first = ExperienceSession()
        let shell = try await ComposerTest.open(first)
        ComposerTest.accept(shell, "chain.add", [0, 0])
        await shell.presenter.importPicture(data: Self.gradient())
        try ComposerTest.draw(first)
        #expect(shell.presenter.lastResult?.width == 96)
        let snapshot = try shell.snapshot()
        first.close()

        let second = ExperienceSession()
        defer { second.close() }
        second.qualityPin = 0
        var made: ExperienceShell<ComposerPresenter>?
        let id = ComposerTest.id
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: snapshot, refusedSnapshotFails: true) {
            let restored = EffectsComposerExperience.make(id: id)
            restored.presenter.captureResult = true
            made = restored
            return restored
        }
        #expect(await second.open(request) == .running)
        let restored = try #require(made)
        let view = try #require(second.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 64, height: 48)
        view.layoutIfNeeded()
        try ComposerTest.draw(second)
        let chain = try ComposerTest.core(restored).chain
        #expect(chain.nodes.map(\.effect) == [.grade])
        #expect(restored.presenter.renderer.pictureSource == .testPicture)
        #expect(try ComposerTest.difference(restored, chain) <= ComposerTest.tolerance(chain))
    }

    @Test func aStaleImportFinishingLaterIsDropped() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        let early = Self.gradient(shift: 0)
        let late = Self.gradient(shift: 100)
        let latePicture = try Self.decoded(late)
        let (gate, open) = AsyncStream<Void>.makeStream()
        shell.presenter.decoder = { data, limit in
            if data == early {
                for await _ in gate { break }
            }
            return ImageImport.decode(data, limit: limit)
        }
        let first = shell.presenter.startImport(data: early)
        await shell.presenter.importPicture(data: late)
        #expect(shell.presenter.mirror.status == ComposerPresenter.yourPictureWord)
        open.yield()
        open.finish()
        await first.value
        try ComposerTest.draw(session)
        #expect(shell.presenter.renderer.pictureSource == .imported(latePicture))
        #expect(shell.presenter.lastResult == latePicture)
        let stale = shell.presenter.apply(.failure(.imageDamaged), request: shell.presenter.importRequest - 1)
        #expect(stale == false)
        #expect(shell.presenter.mirror.status == ComposerPresenter.yourPictureWord)
    }
}
