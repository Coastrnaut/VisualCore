// RobustnessTests — feature 184 (A25-P05) T-A25-506 (FR-A25-506, FR-A25-507; research R8, R9; contracts/robustness.md;
// analyze C4). Nothing breaks when the system interrupts, through the one app's session host:
//
//   - 10 context rebuilds (`RenderHost.recreateContext`) with an imported picture and a three-effect chain give a
//     byte-identical result and source each time;
//   - an export whose `beforeReadBack` seam calls `recreateContext` (a context lost between the draw and the
//     read-back; it stands for a move to the background during an export) fails as `a25.export-interrupted`, leaves no
//     file in the export folder, and the next export succeeds;
//   - presenting into two framebuffer sizes letterboxes the same result (the presented picture equals the result, the
//     corner is the background) and the result read-back is unchanged, with no new render;
//   - posting `UIApplication.didReceiveMemoryWarningNotification` on the presenter's centre (a private
//     `NotificationCenter`) does not raise the registry's live count, and the next preview is byte-identical.
// Short runs; no clock, no sleep.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct RobustnessTests {
    @Test func tenContextRebuildsGiveAByteIdenticalResult() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        let picture = try PictureSourceTests.decoded(PictureSourceTests.gradient())
        await shell.presenter.importPicture(data: PictureSourceTests.gradient())
        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.set", [0, 0, 0.6])
        ComposerTest.accept(shell, "chain.add", [1, 1])
        ComposerTest.accept(shell, "chain.add", [3, 2])
        try ComposerTest.draw(session)
        let before = try #require(shell.presenter.lastResult)
        let renders = shell.presenter.renderer.renderCount
        let host = try #require(session.renderHost)
        for rebuild in 1...10 {
            host.recreateContext()
            try ComposerTest.draw(session)
            #expect(shell.presenter.renderer.renderCount == renders + rebuild, "rebuild \(rebuild) draws anew")
            #expect(shell.presenter.lastResult == before, "rebuild \(rebuild)")
            #expect(shell.presenter.renderer.readSource() == picture, "rebuild \(rebuild)")
        }
    }

    @Test func anExportInterruptedByAContextLossLeavesNoFileAndTheNextSucceeds() async throws {
        let session = ExperienceSession()
        var shell: ExperienceShell<ComposerPresenter>?
        defer { ComposerExport.close(session, shell) }
        let opened = try await ComposerExport.open(session, test: "interrupted")
        shell = opened
        _ = try await ComposerExport.regressionFixture(opened, session)
        let host = try #require(session.renderHost)
        var armed = true
        opened.presenter.renderer.beforeReadBack = { [weak host] in
            guard armed else { return }
            armed = false
            host?.recreateContext()
        }
        try await ComposerExport.run(opened, session, .png)
        #expect(!armed, "the seam ran")
        #expect(opened.presenter.mirror.status == ExportRefusal.interrupted.message)
        #expect(ExportRefusal.interrupted.code == "a25.export-interrupted")
        #expect(opened.presenter.exportFile == nil)
        #expect(ComposerExport.files(opened).isEmpty, "no file in the export folder")
        #expect(!opened.presenter.mirror.isExporting)

        try ComposerTest.draw(session)
        try await ComposerExport.run(opened, session, .png)
        #expect(opened.presenter.mirror.status == ComposerPresenter.exportedWord)
        #expect(ComposerExport.files(opened) == ["Look 96x64.png"])
        let preview = try #require(opened.presenter.lastResult)
        #expect(try ComposerExport.decoded(opened).maxChannelDifference(ComposerTest.opaque(preview)) <= 1)
    }

    @Test func twoFramebufferSizesLetterboxTheSameResult() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session, size: CGSize(width: 200, height: 150))
        ComposerTest.accept(shell, "chain.add", [3, 0])
        try ComposerTest.draw(session)
        let renderer = shell.presenter.renderer
        let result = try #require(renderer.readResult())
        #expect(result == shell.presenter.lastResult)
        let renders = renderer.renderCount
        let host = try #require(session.renderHost)
        var sizes: [Int] = []
        for size in [CGSize(width: 200, height: 150), CGSize(width: 400, height: 300)] {
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.layoutIfNeeded()
            try ComposerTest.draw(session)
            let drawn = try #require(renderer.lastPresentSize)
            sizes.append(drawn.width)
            let presented = try #require(ComposerTest.presented(session, renderer: renderer), "\(size)")
            #expect(presented == ComposerTest.opaque(result), "\(size)")
            let frame = host.readPixels()
            let corner = Array(frame.prefix(3)).map(Int.init)
            let background = [PreviewRenderer.background.x, PreviewRenderer.background.y, PreviewRenderer.background.z]
                .map { Int(($0 * 255).rounded()) }
            #expect(zip(corner, background).allSatisfy { abs($0.0 - $0.1) <= 1 }, "letterbox \(corner) at \(size)")
            #expect(renderer.readResult() == result, "\(size)")
        }
        #expect(sizes[0] < sizes[1], "two framebuffer sizes: \(sizes)")
        #expect(renderer.renderCount == renders, "a size change does not render the chain again")
    }

    @Test func aMemoryWarningKeepsThePreviewAndDoesNotRaiseTheLiveCount() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let center = NotificationCenter()
        let shell = try await ComposerTest.open(session) { presenter in
            presenter.observeMemoryWarnings(on: center)
        }
        await shell.presenter.importPicture(data: PictureSourceTests.gradient())
        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.add", [1, 1])
        ComposerTest.accept(shell, "chain.add", [3, 2])
        try ComposerTest.draw(session)
        let before = try #require(shell.presenter.lastResult)
        let host = try #require(session.renderHost)
        let live = host.resources.stats.liveTotal

        center.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        let trimmed = host.resources.stats.liveTotal
        #expect(trimmed <= live, "\(trimmed) live after the warning, \(live) before")
        #expect(trimmed < live, "the two idle slots are freed")
        #expect(shell.presenter.renderer.readResult() == before)

        ComposerTest.accept(shell, "chain.enable", [1, 0])
        try ComposerTest.draw(session)
        ComposerTest.accept(shell, "chain.enable", [1, 1])
        try ComposerTest.draw(session)
        #expect(shell.presenter.lastResult == before, "the next preview is byte-identical")
        #expect(host.resources.stats.leaked == 0)
        print("RobustnessTests memory warning: live \(live) → \(trimmed)")
    }
}
