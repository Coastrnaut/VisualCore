// PoolTests — feature 181 (A25-P02) T-A25-208 (FR-A25-206; SC-A25-205; clarification Q2; data-model.md "Pool cap").
// Intermediate pictures stay bounded: after the first draw of a three-effect chain, 50 edit-and-draw cycles, 10 context
// rebuilds (`RenderHost.recreateContext`) and a resize leave `ResourceRegistry.stats` live counts and bytes equal to
// those after the first draw, with nothing leaked; the preview holds at most four targets (two between frames); and a
// request above the cap (a fifth target, or a side above 2,048) is refused with `a25.pool-cap` before anything is made.
//
// Feature 184 (A25-P05) T-A25-505: the cap is now five targets (an export target besides the source, the result and
// two slots), so the refused count is `PreviewPool.maxTargets` (5) instead of 4.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import UIKit
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct PoolTests {
    @Test func editsRebuildsAndAResizeLeaveTheLiveCountsAndBytesUnchanged() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        let host = try #require(session.renderHost)
        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.add", [1, 1])
        ComposerTest.accept(shell, "chain.add", [3, 2])
        try ComposerTest.draw(session)
        let first = host.resources.stats
        #expect(shell.presenter.renderer.pool?.held == 2, "the source and the result are held between frames")
        // The 50th cycle (k = 49) enables the third node again, so the last plan has as many slots as the first.
        for k in 0..<50 {
            switch k % 4 {
            case 0: ComposerTest.accept(shell, "chain.enable", [2, 0])
            case 1: ComposerTest.accept(shell, "chain.enable", [2, 1])
            case 2: ComposerTest.accept(shell, "chain.set", [0, 0, Double(k % 10) / 10])
            default: ComposerTest.accept(shell, "chain.move", [0, 2])
            }
            try ComposerTest.draw(session)
            #expect(shell.presenter.renderer.pool?.held == 2)
        }
        let renders = shell.presenter.renderer.renderCount
        #expect(renders >= 30, "most cycles change the chain: \(renders)")
        for _ in 0..<10 {
            host.recreateContext()
            try ComposerTest.draw(session)
        }
        #expect(shell.presenter.renderer.renderCount == renders + 10, "each rebuild draws the chain anew")
        let chain = try ComposerTest.core(shell).chain
        #expect(try ComposerTest.difference(shell, chain) <= ComposerTest.tolerance(chain))
        let view = host.view
        view.frame = CGRect(x: 0, y: 0, width: 96, height: 80)
        view.layoutIfNeeded()
        try ComposerTest.draw(session)
        let last = host.resources.stats
        #expect(last.liveCount == first.liveCount, "\(last.liveCount) after, \(first.liveCount) first")
        #expect(last.liveBytes == first.liveBytes)
        #expect(last.totalBytes == first.totalBytes)
        #expect(last.leaked == 0)
        print("PoolTests: live \(last.liveTotal) objects, \(last.totalBytes) bytes, as after the first draw")
    }

    @Test func aRequestAboveTheCapIsRefusedBeforeAnythingIsMade() async throws {
        #expect(PreviewPool.check(width: 256, height: 256, held: 0) == nil)
        #expect(PreviewPool.check(width: 2_048, height: 2_048, held: 3) == nil)
        #expect(PreviewPool.maxTargets == 5)
        #expect(PreviewPool.check(width: 256, height: 256, held: 4) == nil)
        #expect(PreviewPool.check(width: 256, height: 256, held: 5) == .poolCap)
        #expect(PreviewPool.check(width: 2_049, height: 256, held: 0) == .poolCap)
        #expect(PreviewPool.check(width: 256, height: 4_096, held: 0) == .poolCap)
        #expect(PreviewRefusal.poolCap.ruleID == "a25.pool-cap")
        #expect(PreviewRefusal.poolCap.message == "The picture is larger than the preview allows.")

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        let host = try #require(session.renderHost)
        let pool = try #require(shell.presenter.renderer.pool)
        let before = host.resources.stats
        #expect(throws: PreviewRefusal.poolCap) { _ = try pool.acquire(width: 4_096, height: 4_096) }
        #expect(throws: PreviewRefusal.poolCap) { _ = try pool.acquire(width: 2_049, height: 2_049) }
        #expect(pool.held == 2)
        let after = host.resources.stats
        #expect(after.liveCount == before.liveCount && after.totalBytes == before.totalBytes)
    }
}
