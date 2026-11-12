// ShellPortTests — feature 188 (UA-F02) T-U02-037 (US5; contract
// specs/188-ua-f02-experience-sdk/contracts/experience-host-api.md, section "Port"). The action port between the
// native controls and the experience: results, revision, summary, pointer input, identifiers, the controls view
// and, under DEBUG, the scenario run. No render host is needed: the port works without a graphics context.
import XCTest
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreTestSupport

@MainActor
final class ShellPortTests: XCTestCase {
    private func makeActiveShell(seed: UInt64 = 42) async throws
        -> (presenter: SamplePresenter<NoFault>, shell: SampleShell) {
        let made = try await makeReadySampleShell(seed: seed)
        try made.shell.activate()
        return made
    }

    // MARK: Results

    func testSendReachesTheEngineAndReturnsItsResult() async throws {
        let (_, shell) = try await makeReadySampleShell()
        let port = shell.port
        XCTAssertEqual(port.send("tone", [0.5]), .rejected(.notActive(.ready)), "actions need the state active")
        XCTAssertEqual(shell.engine.rejectedActions, 1)

        try shell.activate()
        XCTAssertEqual(port.send("tone", [0.5]), .accepted)
        XCTAssertEqual(shell.engine.core?.tone, 0.5)
        XCTAssertEqual(shell.engine.acceptedActions, 1)
        XCTAssertEqual(port.send("ping"), .accepted)
        XCTAssertEqual(shell.engine.acceptedActions, 2)

        XCTAssertEqual(port.send("move", [0, 0]), .rejected(.rule(code: "sample.no-move")))
        XCTAssertEqual(port.send("tone", [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(port.send("tone"), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(port.send("nope", [1]), .rejected(.unknownControl("nope")))
        XCTAssertEqual(shell.engine.rejectedActions, 5)
        XCTAssertEqual(shell.engine.core?.tone, 0.5)

        // The port and the shell's own `handle` give the answer a pure engine gives.
        var mirror = shell.engine
        let expected = mirror.handle(control: "tone", values: [0.25])
        XCTAssertEqual(port.send("tone", [0.25]), expected)
        XCTAssertEqual(try shell.engine.digest(), try mirror.digest())
        let second = mirror.handle(control: "tone", values: [0.75])
        XCTAssertEqual(shell.handle(control: "tone", values: [0.75]), second)
        XCTAssertEqual(try shell.engine.digest(), try mirror.digest())
    }

    // MARK: Revision

    func testRevisionGrowsAfterAnAcceptedActionARestoreAndAResetAndNotAfterARejectedAction() async throws {
        let (_, shell) = try await makeActiveShell()
        let port = shell.port
        let snapshot = try shell.snapshot()

        var revision = port.revision
        XCTAssertEqual(port.send("tone", [0.5]), .accepted)
        XCTAssertGreaterThan(port.revision, revision, "an accepted action")

        revision = port.revision
        XCTAssertEqual(shell.handle(control: "tone", values: [0.75]), .accepted)
        XCTAssertGreaterThan(port.revision, revision, "an accepted action through the shell")

        revision = port.revision
        XCTAssertEqual(port.send("move", [0, 0]), .rejected(.rule(code: "sample.no-move")))
        XCTAssertEqual(port.send("tone", [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(port.send("nope"), .rejected(.unknownControl("nope")))
        XCTAssertEqual(shell.handle(control: "tone", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(port.revision, revision, "a rejected action")

        try shell.restore(snapshot)
        XCTAssertGreaterThan(port.revision, revision, "a restore")
        XCTAssertEqual(shell.engine.core?.tone, 0)

        XCTAssertEqual(port.send("tone", [0.5]), .accepted)
        revision = port.revision
        try shell.reset()
        XCTAssertGreaterThan(port.revision, revision, "a reset")
        XCTAssertEqual(shell.engine.core?.tone, 0)

        // A refused restore or reset is no change of the state.
        try shell.beginDeactivation()
        revision = port.revision
        XCTAssertNotNil(refusal { try shell.restore(snapshot) })
        XCTAssertNotNil(refusal { try shell.reset() })
        XCTAssertEqual(port.send("ping"), .rejected(.notActive(.deactivating)))
        XCTAssertEqual(port.revision, revision)
    }

    // MARK: Summary

    func testSummaryEqualsThePresentersDescriptionOfTheCurrentState() async throws {
        let (presenter, shell) = makeSampleShell(NoFault.self)
        let port = shell.port
        XCTAssertEqual(port.summary, "", "no state yet")
        XCTAssertEqual(shell.accessibilitySummary, "")

        try await shell.prepare(seed: 42, timeLimit: nil)
        XCTAssertEqual(shell.accessibilitySummary, presenter.describe(try XCTUnwrap(shell.engine.core)))
        try shell.activate()
        let snapshot = try shell.snapshot()

        XCTAssertEqual(port.send("tone", [0.5]), .accepted)
        var core = try XCTUnwrap(shell.engine.core)
        XCTAssertEqual(port.summary, presenter.describe(core))
        XCTAssertEqual(shell.accessibilitySummary, presenter.describe(core))
        XCTAssertTrue(port.summary.contains("tone 0.50"), port.summary)

        let direction: Double = core.x < 15 ? 1 : -1
        XCTAssertEqual(port.send("move", [direction, 0]), .accepted)
        core = try XCTUnwrap(shell.engine.core)
        XCTAssertEqual(port.summary, presenter.describe(core))
        XCTAssertTrue(port.summary.contains("marker at \(core.x), \(core.y)"), port.summary)

        let accepted = port.summary
        XCTAssertEqual(port.send("tone", [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(port.summary, accepted, "a rejected action changes nothing")

        try shell.restore(snapshot)
        core = try XCTUnwrap(shell.engine.core)
        XCTAssertEqual(port.summary, presenter.describe(core))
        XCTAssertTrue(port.summary.contains("tone 0.00"), port.summary)

        XCTAssertEqual(port.send("tone", [0.25]), .accepted)
        try shell.reset()
        core = try XCTUnwrap(shell.engine.core)
        XCTAssertEqual(port.summary, presenter.describe(core))
        XCTAssertEqual(shell.accessibilitySummary, port.summary)

        try shell.beginDeactivation()
        try shell.finishDeactivation()
        XCTAssertEqual(shell.accessibilitySummary, "", "no core after the leave")
    }

    // MARK: Pointer input

    func testSendAtAPointSendsNormalizedCoordinates() async throws {
        let (_, shell) = try await makeActiveShell()
        let port = shell.port
        let size = CGSize(width: 64, height: 64)

        // (48, 16) in 64 × 64 is (0.75, 0.25): the sample rounds that to one cell to the right.
        var mirror = shell.engine
        let expected = mirror.handle(control: "move", values: [0.75, 0.25])
        XCTAssertEqual(port.send("move", at: CGPoint(x: 48, y: 16), in: size), expected)
        XCTAssertEqual(try shell.engine.digest(), try mirror.digest())
        XCTAssertEqual(shell.engine.core?.x, mirror.core?.x)

        // A point always carries two values, so a control with one value answers with the typed rejection.
        XCTAssertEqual(port.send("tone", at: CGPoint(x: 16, y: 32), in: size),
                       .rejected(.wrongValueCount(expected: 1, found: 2)), "a point carries two values")

        // The corners of the view are inside it.
        for point in [CGPoint(x: 0, y: 0), CGPoint(x: 64, y: 64)] {
            let answer = mirror.handle(control: "move", values: [point.x / 64, point.y / 64])
            XCTAssertEqual(port.send("move", at: point, in: size), answer, "\(point)")
            XCTAssertEqual(try shell.engine.digest(), try mirror.digest(), "\(point)")
        }
    }

    func testSendAtAPointOutsideTheViewIsRejectedWithoutReachingTheEngine() async throws {
        let (_, shell) = try await makeActiveShell()
        let port = shell.port
        let size = CGSize(width: 64, height: 64)
        let before = shell.engine
        let digest = try shell.engine.digest()
        let revision = port.revision, summary = port.summary

        let outside = [CGPoint(x: 80, y: 10), CGPoint(x: -1, y: 10), CGPoint(x: 10, y: 64.5), CGPoint(x: 10, y: -0.5),
                       CGPoint(x: CGFloat.nan, y: 10), CGPoint(x: 10, y: CGFloat.infinity)]
        for point in outside {
            XCTAssertEqual(port.send("move", at: point, in: size), .rejected(.outOfRange(index: 0)), "\(point)")
        }
        XCTAssertEqual(port.send("move", at: CGPoint(x: 1, y: 1), in: .zero), .rejected(.outOfRange(index: 0)),
                       "a view without a size has no inside")

        XCTAssertEqual(shell.engine.acceptedActions, before.acceptedActions)
        XCTAssertEqual(shell.engine.rejectedActions, before.rejectedActions, "the engine saw no action")
        XCTAssertEqual(shell.engine.lifecycle.rejectedOperations, before.lifecycle.rejectedOperations)
        XCTAssertEqual(shell.engine.core?.applyCalls, before.core?.applyCalls)
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertEqual(port.revision, revision)
        XCTAssertEqual(port.summary, summary)
    }

    // MARK: Identifiers and controls

    func testIdentifiersCarryThePrefixOfTheExperience() async throws {
        let (_, shell) = makeSampleShell(NoFault.self)
        XCTAssertEqual(shell.port.accessibilityPrefix, "experience.a99.contract-sample")
        XCTAssertEqual(shell.port.accessibilityPrefix, SampleExperience.id.accessibilityPrefix)
        XCTAssertEqual(shell.port.identifier("canvas"), "experience.a99.contract-sample.canvas")
        XCTAssertEqual(shell.port.identifier("ping"), "experience.a99.contract-sample.ping")
    }

    func testControlsIsThePresentersViewBuiltWithTheShellsPort() async throws {
        let (presenter, shell) = try await makeActiveShell()
        XCTAssertTrue(shell.port === shell.port, "one port for the life of the shell")
        let controls: AnyView = shell.controls
        _ = controls
        XCTAssertGreaterThanOrEqual(presenter.controlsCalls, 1)
        XCTAssertTrue(presenter.lastControlsPort === shell.port)

        // What the presenter's button does, done directly: the port it was given reaches this experience.
        let port = try XCTUnwrap(presenter.lastControlsPort)
        let accepted = shell.engine.acceptedActions
        XCTAssertEqual(port.send("ping"), .accepted)
        XCTAssertEqual(shell.engine.acceptedActions, accepted + 1)
        XCTAssertEqual(port.identifier("ping"), "experience.a99.contract-sample.ping")
    }

    // MARK: Automation

    #if DEBUG
    func testRunGivesTheResultOfTheEnginesScenarioRun() async throws {
        let (_, shell) = try await makeActiveShell()
        let scenario = ExperienceScenario(seed: 42, entries: [
            ExperienceScenario.Entry(steps: 30, action: ScriptedAction("tone", [0.5])),
            ExperienceScenario.Entry(steps: 30, action: ScriptedAction("move", [0, 0])),
            ExperienceScenario.Entry(steps: 10),
        ])
        var mirror = shell.engine
        let expected = mirror.run(scenario)

        let result = shell.run(scenario)

        XCTAssertEqual(result, expected)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.results, ["accepted", "action.rule.sample.no-move"])
        XCTAssertEqual(result.stepIndex, shell.engine.stepIndex)
        XCTAssertEqual(result.digest, try shell.engine.digest())
        XCTAssertEqual(try shell.engine.digest(), try mirror.digest(), "the shell's engine ran the scenario itself")
        XCTAssertEqual(shell.engine.core?.tone, 0.5)
    }
    #endif
}
