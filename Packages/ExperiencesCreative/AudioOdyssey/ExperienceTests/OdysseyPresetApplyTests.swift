// OdysseyPresetApplyTests — feature 057 (A07-P04) T-A07-403 (FR-A07-401–403; SC-A07-401; story 1, scenarios 1–4).
// Applying journeys, short runs only (simulated steps and 1/60 s frames, no wall clock, each test well under 10 s).
// Core: `preset.apply` sets the world, the three mappings, the speed target, the easing and calm motion at once and
// keeps distance, current speed, seed, source and pause; the speed then eases to the new target within the active
// limits; every invalid value (not a whole number naming a case, a speed target outside 0.5…7, a calm other than 0 or
// 1, a wrong count) is refused whole with nothing changed; through the engine, values outside the declared ranges are
// refused and an accepted journey changes the digest. Presenter: a built-in applied through the presenter keeps the
// flight and the host and becomes the selected journey; without storage only the built-ins are offered; with storage
// the current journey is saved, renamed and deleted, built-ins are refused with plain messages, and a journey file
// written while away is listed when the experience is opened again.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreAudio
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// A microphone permission double that is never asked.
@MainActor
private final class GrantedPermission: MicrophonePermission {
    var state: MicrophonePermissionState { .granted }
    func request() async -> MicrophonePermissionState { .granted }
}

@MainActor
final class OdysseyPresetApplyTests: XCTestCase {
    private var id: ExperienceID { AudioOdysseyExperience.id ?? ExperienceID(rawValue: "a07.unknown")! }
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a07-p04.apply.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: id, root: root, defaults: defaults)
    }

    private func send(_ core: inout OdysseyCore, _ control: String, _ values: [Double] = []) -> ActionResult {
        core.apply(ExperienceAction(control: control, values: values, step: 0))
    }

    /// A core prepared with seed 7 that has flown `steps` steps toward the medium speed.
    private func flyingCore(steps: Int = 240) -> OdysseyCore {
        var core = OdysseyCore(seed: 7)
        for step in 0..<steps { core.update(step: step) }
        return core
    }

    // MARK: Core

    func testPresetApplySetsEveryJourneyFieldAtOnceAndKeepsTheFlight() throws {
        var core = flyingCore()
        XCTAssertTrue(send(&core, "source.file").isAccepted)
        let before = core.state
        XCTAssertGreaterThan(before.distance, 0)
        XCTAssertGreaterThan(before.speed, 0)
        for preset in JourneyPreset.builtIns {
            let result = send(&core, "preset.apply", preset.actionValues)
            XCTAssertEqual(result, .accepted, preset.name)
            XCTAssertEqual(core.state.world, preset.world, preset.name)
            XCTAssertEqual(core.state.mappings, preset.mappings, preset.name)
            XCTAssertEqual(core.state.speedTarget, preset.speedTarget, preset.name)
            XCTAssertEqual(core.state.easing, preset.easing, preset.name)
            XCTAssertEqual(core.state.calmMotion, preset.calmMotion, preset.name)
            XCTAssertEqual(core.state.distance, before.distance, "\(preset.name): no jump along the rail")
            XCTAssertEqual(core.state.speed, before.speed, "\(preset.name): the current speed is kept")
            XCTAssertEqual(core.state.seed, before.seed)
            XCTAssertEqual(core.state.source, .file)
            XCTAssertFalse(core.state.paused)
        }
    }

    func testTheSpeedEasesToTheAppliedTargetWithinTheLimits() throws {
        var core = flyingCore(steps: 720)
        XCTAssertEqual(core.state.speed, 4, accuracy: 1e-9, "medium reached")
        let deep = JourneyPreset.builtIns[0]                 // 3.5 units/s, gentle
        XCTAssertEqual(send(&core, "preset.apply", deep.actionValues), .accepted)
        var previous = core.state.speed
        var steps = 0
        while abs(core.state.speed - deep.speedTarget) > 1e-9, steps < 2_400 {
            let limits = core.limits
            core.update(step: steps)
            XCTAssertLessThanOrEqual(abs(core.state.speed - previous), limits.maxAcceleration * OdysseyCore.stepDuration
                                         + 1e-12)
            XCTAssertLessThanOrEqual(core.state.speed, limits.maxSpeed + 1e-12)
            previous = core.state.speed
            steps += 1
        }
        XCTAssertEqual(core.state.speed, deep.speedTarget, accuracy: 1e-9, "settled on the new target")
        XCTAssertGreaterThan(steps, 1, "eased over several steps, not a jump")
    }

    func testApplyingWhilePausedChangesTheSetupAndStaysPaused() throws {
        var core = flyingCore()
        XCTAssertTrue(send(&core, "flight.pause").isAccepted)
        let hills = JourneyPreset.builtIns[1]
        XCTAssertEqual(send(&core, "preset.apply", hills.actionValues), .accepted)
        XCTAssertTrue(core.state.paused)
        XCTAssertEqual(core.state.world, .landscape)
    }

    func testInvalidValuesAreRefusedWholeAndChangeNothing() throws {
        var core = flyingCore()
        XCTAssertTrue(send(&core, "mapping.set", [1, 2, 2]).isAccepted)
        XCTAssertTrue(send(&core, "easing.select", [2]).isAccepted)
        let before = core
        let valid = JourneyPreset.builtIns[2].actionValues
        let invalid = OdysseyRule.invalidPreset
        for index in valid.indices {
            var values = valid
            values[index] = index == 13 ? 7.5 : values[index] + 0.5    // not whole; the speed out of 0.5…7
            XCTAssertEqual(send(&core, "preset.apply", values), .rejected(.rule(code: invalid)), "index \(index)")
            XCTAssertEqual(core, before, "index \(index): nothing changed")
        }
        for bad in [Double.nan, .infinity, -1, 3, 5] {
            var values = valid
            values[0] = bad
            XCTAssertEqual(send(&core, "preset.apply", values), .rejected(.rule(code: invalid)), "world \(bad)")
            values = valid
            values[15] = bad
            XCTAssertEqual(send(&core, "preset.apply", values), .rejected(.rule(code: invalid)), "calm \(bad)")
        }
        XCTAssertEqual(send(&core, "preset.apply", Array(valid.dropLast())),
                       .rejected(.wrongValueCount(expected: 16, found: 15)))
        XCTAssertEqual(core, before)
    }

    func testThroughTheEngineRangesAreCheckedAndAnAcceptedJourneyChangesTheDigest() async throws {
        var engine = ExperienceEngine<OdysseyCore>(id: id)
        try await engine.prepare(seed: 7)
        try engine.activate()
        try engine.run(steps: 60)
        let digest = try engine.digest().hex
        var outside = JourneyPreset.builtIns[1].actionValues
        outside[0] = 3                                       // no fourth world
        XCTAssertFalse(engine.handle(control: "preset.apply", values: outside).isAccepted)
        var half = JourneyPreset.builtIns[1].actionValues
        half[14] = 0.5                                       // inside the easing range but no easing
        XCTAssertEqual(engine.handle(control: "preset.apply", values: half).code,
                       "action.rule." + OdysseyRule.invalidPreset)
        XCTAssertEqual(try engine.digest().hex, digest, "refusals change nothing")
        XCTAssertTrue(engine.handle(control: "preset.apply", values: JourneyPreset.builtIns[1].actionValues).isAccepted)
        XCTAssertNotEqual(try engine.digest().hex, digest)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.world, .landscape)
    }

    // MARK: Presenter

    private func open(_ session: ExperienceSession, storage: ExperienceStorage?) async throws
        -> ExperienceShell<OdysseyPresenter> {
        let id = self.id
        var made: ExperienceShell<OdysseyPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = AudioOdysseyExperience.make(id: id, permission: GrantedPermission(), storage: storage)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        return shell
    }

    private func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    func testABuiltInAppliedThroughThePresenterKeepsTheFlight() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, storage: nil)
        let presenter = shell.presenter
        XCTAssertNil(presenter.presets)
        XCTAssertEqual(presenter.presetEntries, JourneyPreset.builtIns, "without storage: the built-ins only")
        XCTAssertNil(presenter.selectedPresetID)
        try frames(session, 60)
        let host = try XCTUnwrap(session.renderHost)
        let before = try XCTUnwrap(shell.engine.core).state
        XCTAssertGreaterThan(before.distance, 0)
        let hills = JourneyPreset.builtIns[1]
        XCTAssertEqual(presenter.apply(hills), .accepted)
        let after = try XCTUnwrap(shell.engine.core).state
        XCTAssertEqual(after.world, .landscape)
        XCTAssertEqual(after.mappings, hills.mappings)
        XCTAssertEqual(after.speedTarget, hills.speedTarget)
        XCTAssertEqual(after.distance, before.distance)
        XCTAssertEqual(after.speed, before.speed)
        XCTAssertEqual(presenter.selectedPresetID, hills.id)
        XCTAssertNil(presenter.selectedUserPreset, "a built-in offers no rename or delete")
        XCTAssertEqual(presenter.mirror.world, .landscape, "the controls follow")
        XCTAssertNil(presenter.saveCurrentPreset(named: "Nowhere"), "nothing is saved without storage")
        try frames(session, 10)
        XCTAssertGreaterThan(try XCTUnwrap(shell.engine.core).state.distance, before.distance, "the flight goes on")
        XCTAssertEqual(presenter.lastWorld, .landscape)
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertTrue(session.renderHost === host, "the same drawing context")
        session.close()
    }

    func testWithStorageThePresenterSavesRenamesAndDeletesTheSelectedJourney() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, storage: storage)
        let presenter = shell.presenter
        let store = try XCTUnwrap(presenter.presets)
        XCTAssertEqual(presenter.presetEntries.map(\.id), JourneyPreset.builtIns.map(\.id))
        XCTAssertTrue(shell.handle(control: "world.select", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "speed.set", values: [5]).isAccepted)
        XCTAssertTrue(shell.handle(control: "comfort.calm", values: [1]).isAccepted)
        let saved = try XCTUnwrap(presenter.saveCurrentPreset(named: "My trip"))
        XCTAssertEqual(saved.world, .starCorridor)
        XCTAssertEqual(saved.speedTarget, 5)
        XCTAssertTrue(saved.calmMotion)
        XCTAssertEqual(presenter.selectedPresetID, saved.id)
        XCTAssertEqual(presenter.selectedUserPreset?.id, saved.id)
        XCTAssertEqual(presenter.presetEntries.last?.name, "My trip")
        XCTAssertEqual(presenter.saveCurrentPreset(named: "my trip")?.name, "my trip 2")

        // A built-in, then the saved journey again: everything comes back.
        XCTAssertEqual(presenter.apply(JourneyPreset.builtIns[0]), .accepted)
        XCTAssertFalse(presenter.renameSelectedPreset(to: "Mine"))
        XCTAssertEqual(store.lastMessage, "Built-in journeys can't be renamed.")
        XCTAssertFalse(presenter.deleteSelectedPreset())
        XCTAssertEqual(store.lastMessage, "Built-in journeys can't be deleted.")
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.world, .tunnel)
        XCTAssertEqual(presenter.apply(try XCTUnwrap(store.preset(saved.id))), .accepted)
        let state = try XCTUnwrap(shell.engine.core).state
        XCTAssertEqual(state.world, .starCorridor)
        XCTAssertEqual(state.speedTarget, 5)
        XCTAssertTrue(state.calmMotion)

        XCTAssertTrue(presenter.renameSelectedPreset(to: "Evening"))
        XCTAssertEqual(store.preset(saved.id)?.name, "Evening")
        XCTAssertNil(store.lastMessage)
        XCTAssertTrue(presenter.deleteSelectedPreset())
        XCTAssertNil(presenter.selectedPresetID)
        XCTAssertNil(store.preset(saved.id))
        XCTAssertEqual(presenter.presetEntries.map(\.name).suffix(1), ["my trip 2"])

        // A journey file written while away appears when the experience is opened again.
        let lateID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000c01"))
        let late = JourneyPreset(from: JourneyState(seed: 1), id: lateID, name: "Late",
                                 saved: Date(timeIntervalSinceReferenceDate: 0))
        try storage.write(try late.fileData(), to: JourneyPreset.fileName(for: late.id))
        XCTAssertNil(store.preset(late.id))
        session.close()
        let again = ExperienceSession()
        let reopened = try await open(again, storage: storage)
        XCTAssertNotNil(reopened.presenter.presets?.preset(late.id))
        again.close()
    }
}
