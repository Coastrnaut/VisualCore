// LissajousLabyrinthRenderTests — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-001 … 003, 006;
// SC-R02G0203-001, 002; clarifications Q1, Q3, Q4; R2-G02-INV-10). Through the one app's session host, drawn off screen
// at the frame-check size of `LissajousLabyrinthTest` (768 × 512, 8 × clarification Q3's 96 × 64; the adapted bound is
// documented in LissajousLabyrinthTestSupport.swift): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80) at
// each quality tier level-0, level-1 and level-2 match the Core's CPU reference of the presenter's last snapshot (path
// samples within 2 px of a pixel 0.15 brighter than night, checkpoint ring colours for unvisited, next and visited and
// obstacle colours, including the contact colour, within 0.12, background within 0.05 of night); `level.next` changes
// the digest and the next level's frame still matches. One test per level, each well under 10 s.
#if os(iOS)
import Foundation
import Testing
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct LissajousLabyrinthRenderTests {
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: seed)
        let level = LissajousLabyrinthExperienceCore.levelNumber(forSeed: seed)
        #expect(try #require(shell.engine.core).levelNumber == level)
        for tier in 0..<3 {
            LissajousLabyrinthTest.pin(session, shell, tier: tier)
            let rgba = try LissajousLabyrinthTest.still(session)
            let snapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.time == 0, "the still's frame time is 0")
            #expect(snapshot.headTick == 0)
            #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            LissajousLabyrinthTest.checkFrame(rgba, snapshot: snapshot, tier: tier, "level \(level) tier \(tier)")
            let obstacles = LissajousLabyrinthTest.obstacleMisses(rgba, snapshot: snapshot)
            let contact: String = snapshot.contactObstacle == nil ? "none" : "\(snapshot.contactObstacle!)"
            print("lissajous-labyrinth level \(level) tier \(tier): obstacles checked \(obstacles.checked), "
                  + "contact \(contact) checked \(obstacles.touchedChecked)")
        }
        session.qualityPin = 0
    }

    /// Gate X-R02-G02: the presenter's frame probes (two night corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 0)
        for tier in 0..<3 {
            LissajousLabyrinthTest.pin(session, shell, tier: tier)
            let still = try LissajousLabyrinthTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let row = LissajousLabyrinthTest.width * 4
            var rgba: [UInt8] = []
            for y in stride(from: LissajousLabyrinthTest.height - 1, through: 0, by: -1) {
                rgba.append(contentsOf: still[(y * row)..<((y + 1) * row)])
            }
            let probes = shell.presenter.probes(try #require(shell.engine.core))
            #expect(probes.map(\.name) == ["night-top-left", "night-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: LissajousLabyrinthTest.width,
                                              height: LissajousLabyrinthTest.height)
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(found?.rawValue ?? "none")")
            }
        }
        session.qualityPin = 0
    }

    @Test func theCheckedLevelsShowEveryRingState() async throws {
        // Across levels 1 … 81 the checkpoints are unvisited, next and visited, and some lap touches an obstacle, so
        // the colour checks above cover every state of FR-R02G0203-002.
        var states: Set<String> = []
        var contacts = 0
        for seed in LissajousLabyrinthTest.seeds {
            let core = try LissajousLabyrinthExperienceCore.opening(number: Int(seed) + 1)
            let snapshot = core.snapshot(time: 0)
            for index in 0..<snapshot.level.checkpoints.count {
                states.insert(LissajousLabyrinthTest.ringState(snapshot, index: index))
            }
            if snapshot.contactObstacle != nil { contacts += 1 }
        }
        #expect(states == ["unvisited", "next", "visited"], "\(states)")
        #expect(contacts >= 1)
    }

    @Test func nextLevelChangesTheDigestAndTheFrameStillMatches() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 0)
        // Feature 315: `level.next` moves to the next open level, so level 1 is won first (which opens level 2).
        for action in try LissajousLabyrinthExperienceCore.generated(number: 1).solution.actions {
            let dial = Double(LissajousLabyrinthExperienceCore.dialOrder.firstIndex(of: action.dial) ?? 0)
            #expect(shell.handle(control: "dial.set", values: [dial, Double(action.value)]) == .accepted)
        }
        let before = try LissajousLabyrinthTest.digest(shell)
        let result = shell.handle(control: "level.next")
        #expect(result == .accepted, "\(result.code)")
        #expect(try LissajousLabyrinthTest.digest(shell) != before)
        #expect(try #require(shell.engine.core).levelNumber == 2)
        let rgba = try LissajousLabyrinthTest.still(session)
        let snapshot = try #require(shell.presenter.lastSnapshot)
        let second: LissajousLabyrinthLevel = try LissajousLabyrinthExperienceCore.level(number: 2)
        #expect(snapshot.level == second)
        LissajousLabyrinthTest.checkFrame(rgba, snapshot: snapshot, tier: 0, "level 2 after level.next")
    }
}
#endif
