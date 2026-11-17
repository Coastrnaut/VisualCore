// LimitRenderTests — feature 153 (A21-P02) T-A21-205 (FR-A21-203, FR-A21-204; SC-A21-202; clarifications Q2, Q3;
// contracts/experience.md "Limit"). The regression fixture of the brightness limit, drawn through the one app's session
// host at 64 × 48 off screen: every preset at the limits 0.2, 0.4 and 0.72, and the start, middle and end of every
// change between the three presets (all six ordered pairs) at each of those limits, have no pixel whose Rec. 709
// luminance (of the sRGB-decoded pixel) is above the limit + 1/255, and each drawing matches `SkyReference` of the
// drawn uniforms within the A21-P01 tolerances (mean ≤ 2/255, largest ≤ 8/255); during a change (feature 154, the
// 2.0 s crossfade) the reference is both skies' references mixed at the mix drawn. One test per limit for the changes, so
// each stays well under 10 s (frames of 1/60 s at 32 × 24 points).
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct LimitRenderTests {
    /// The limits drawn.
    static let limits: [Double] = [0.2, 0.4, 0.72]
    /// Every ordered change between the three presets, each starting where the previous ended (from preset 0).
    static let changes: [(from: Int, to: Int)] = [(0, 1), (1, 2), (2, 0), (0, 2), (2, 1), (1, 0)]

    /// Draws `shell`'s sky off screen and checks the limit and the reference; returns the largest luminance.
    @discardableResult
    private func check(_ session: ExperienceSession, _ shell: ExperienceShell<AuroraPresenter>, limit: Double,
                       _ what: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> Float {
        let still = try AuroraTest.still(session)
        let uniforms = try #require(shell.presenter.lastUniforms)
        #expect(abs(Double(uniforms.limit) - limit) < 1e-6, "\(what): the drawn limit", sourceLocation: sourceLocation)
        let lum = AuroraTest.luminance(still)
        #expect(lum.max <= Float(limit) + 1 / 255, "\(what): brightest \(lum.max)", sourceLocation: sourceLocation)
        let diff = AuroraTest.difference(still, try AuroraTest.reference(shell))
        #expect(diff.mean <= 2 && diff.max <= 8, "\(what): \(diff)", sourceLocation: sourceLocation)
        return lum.max
    }

    @Test func everyPresetStaysUnderEveryLimit() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, reduceMotion: true)
        for limit in Self.limits {
            AuroraTest.accept(shell, "light.limit", [limit])
            var largest: Float = 0
            for index in SkyPresets.all.indices {
                AuroraTest.accept(shell, "preset.select", [Double(index)])
                for level in [0, 1] {
                    session.qualityPin = level
                    #expect(try #require(shell.engine.core).qualityTier == level)
                    largest = max(largest, try check(session, shell, limit: limit,
                                                     "\(SkyPresets.all[index].id) level \(level) limit \(limit)"))
                }
            }
            session.qualityPin = 0
            print("aurora-limit presets limit \(limit): max luminance \(largest)")
        }
    }

    /// Runs every change of ``changes`` at `limit`, checking its start, middle and end; returns the largest luminance.
    private func changes(at limit: Double) async throws -> Float {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        AuroraTest.accept(shell, "light.limit", [limit])
        var largest: Float = 0
        for change in Self.changes {
            #expect(presenter.lastCore.presetIndex == change.from)
            #expect(!presenter.transition.isChanging)
            AuroraTest.accept(shell, "preset.select", [Double(change.to)])
            let name = "\(change.from)→\(change.to) limit \(limit)"
            largest = max(largest, try check(session, shell, limit: limit, name + " start"))
            #expect(presenter.transition.isChanging && presenter.transition.progress == 0)
            try AuroraTest.draw(session, frames: 60)
            #expect(abs(presenter.transition.progress - 0.5) < 1e-9)
            largest = max(largest, try check(session, shell, limit: limit, name + " middle"))
            try AuroraTest.draw(session, frames: 60)
            #expect(!presenter.transition.isChanging)
            largest = max(largest, try check(session, shell, limit: limit, name + " end"))
        }
        print("aurora-limit changes limit \(limit): max luminance \(largest)")
        return largest
    }

    @Test func everyChangeStaysUnderTheLowLimit() async throws {
        let largest = try await changes(at: 0.2)
        #expect(largest <= 0.2 + 1 / 255)
    }

    @Test func everyChangeStaysUnderTheMiddleLimit() async throws {
        let largest = try await changes(at: 0.4)
        #expect(largest <= 0.4 + 1 / 255)
    }

    @Test func everyChangeStaysUnderTheHighestLimit() async throws {
        let largest = try await changes(at: 0.72)
        #expect(largest <= 0.72 + 1 / 255)
    }
}
