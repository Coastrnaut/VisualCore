// OdysseySourcePickerTests — feature 057 (A07-P04) T-A07-403 (FR-A07-410; SC-A07-405; story 2, scenarios 1 and 2). What
// the segmented sound picker and its status line show for every source and permission state, inside the one app's
// session host with the permission and source doubles of Music Lab's tests (the microphone is never started), short
// runs only (each test well under 10 s, frames of 1/60 s): the demo signal first ("Demo signal", no message); File asks
// for the importer and changes nothing; a picked file is named and playing; an undecodable file keeps the source and
// says why; the microphone granted plays as "Microphone"; denied or restricted refuses it with no request, keeps the
// demo and shows the Settings message and link; not determined asks once and then plays or falls back to the demo
// with the message; switching back to the demo keeps the flight.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// A microphone permission double: a fixed state and the answer the one request gives.
@MainActor
private final class PickerPermission: MicrophonePermission {
    var state: MicrophonePermissionState
    let answer: MicrophonePermissionState
    private(set) var requests = 0

    init(_ state: MicrophonePermissionState, answer: MicrophonePermissionState? = nil) {
        self.state = state
        self.answer = answer ?? state
    }

    func request() async -> MicrophonePermissionState {
        requests += 1
        state = answer
        return answer
    }
}

/// A silent source double.
@MainActor
private final class QuietSource: AudioSource {
    let label: String
    var sampleRate: Double { 48_000 }
    private(set) var state: AudioSourceState = .idle

    init(_ label: String) { self.label = label }

    func start(into buffer: SampleRingBuffer) throws { state = .running }
    func stop() { state = .idle }
}

/// A file that cannot be decoded (the factory throws for it).
private struct Undecodable: Error {}

/// Every source double the factory made, in order; file URLs whose last component is `broken.wav` do not decode.
@MainActor
private final class PickerLog {
    var made: [QuietSource] = []

    var factory: OdysseySourceFactory {
        OdysseySourceFactory(demo: { [unowned self] _ in record("demo") },
                             file: { [unowned self] url in
                                 if url.lastPathComponent == "broken.wav" { throw Undecodable() }
                                 return record("file")
                             },
                             microphone: { [unowned self] _ in record("microphone") })
    }

    private func record(_ label: String) -> QuietSource {
        let source = QuietSource(label)
        made.append(source)
        return source
    }
}

@MainActor
final class OdysseySourcePickerTests: XCTestCase {
    private var id: ExperienceID { AudioOdysseyExperience.id ?? ExperienceID(rawValue: "a07.unknown")! }

    private func open(_ session: ExperienceSession, permission: any MicrophonePermission,
                      factory: OdysseySourceFactory) async throws -> ExperienceShell<OdysseyPresenter> {
        let id = self.id
        var made: ExperienceShell<OdysseyPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = AudioOdysseyExperience.make(id: id, permission: permission, factory: factory)
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

    /// The status line, message and Settings link the controls show.
    private func shown(_ presenter: OdysseyPresenter) -> (status: String, message: String?, settings: Bool) {
        (presenter.mirror.sourceName, presenter.mirror.message, presenter.mirror.showsSettingsLink)
    }

    func testTheDemoFirstThenAFileIsNamedAndTheDemoAgain() async throws {
        let session = ExperienceSession()
        let log = PickerLog()
        let shell = try await open(session, permission: PickerPermission(.granted), factory: log.factory)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.mirror.source, .demo)
        XCTAssertEqual(shown(presenter).status, "Demo signal")
        XCTAssertNil(shown(presenter).message)
        XCTAssertFalse(shown(presenter).settings)

        // File first asks the controls to open the importer; nothing changes until a file is picked.
        let fileResult = await presenter.pickSource(.file)
        XCTAssertNil(fileResult)
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.source, .demo)
        XCTAssertEqual(log.made.map(\.label), ["demo"])

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Evening walk.m4a")
        XCTAssertTrue(presenter.chooseFile(url: url))
        XCTAssertEqual(presenter.mirror.source, .file)
        XCTAssertEqual(shown(presenter).status, "Evening walk.m4a", "the file is named")
        XCTAssertNil(shown(presenter).message)
        XCTAssertEqual(log.made.last?.label, "file")
        XCTAssertEqual(log.made.last?.state, .running)
        try frames(session, 5)
        let distance = try XCTUnwrap(shell.engine.core).state.distance

        let demo = await presenter.pickSource(.demo)
        XCTAssertEqual(demo, .accepted)
        XCTAssertEqual(shown(presenter).status, "Demo signal")
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.distance, distance, "switching keeps the flight")
        try frames(session, 5)
        XCTAssertEqual(log.made.last?.label, "demo")
        XCTAssertEqual(log.made.filter { $0.state == .running }.count, 1)
        session.close()
    }

    func testAnUndecodableFileKeepsTheSourceAndSaysWhy() async throws {
        let session = ExperienceSession()
        let log = PickerLog()
        let shell = try await open(session, permission: PickerPermission(.granted), factory: log.factory)
        let presenter = shell.presenter
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("broken.wav")
        XCTAssertFalse(presenter.chooseFile(url: url))
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.source, .demo)
        XCTAssertEqual(shown(presenter).status, "Demo signal")
        XCTAssertEqual(shown(presenter).message, OdysseyPresenter.undecodableMessage)
        XCTAssertFalse(shown(presenter).settings)
        session.close()
    }

    func testTheMicrophoneGrantedPlaysAsMicrophone() async throws {
        let session = ExperienceSession()
        let log = PickerLog()
        let permission = PickerPermission(.granted)
        let shell = try await open(session, permission: permission, factory: log.factory)
        let presenter = shell.presenter
        let result = await presenter.pickSource(.microphone)
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(permission.requests, 0)
        XCTAssertEqual(presenter.mirror.source, .microphone)
        XCTAssertEqual(shown(presenter).status, "Microphone")
        XCTAssertNil(shown(presenter).message)
        XCTAssertFalse(shown(presenter).settings)
        try frames(session, 2)
        XCTAssertEqual(log.made.last?.label, "microphone")
        session.close()
    }

    func testDeniedOrRestrictedShowsTheWayToSettingsAndKeepsTheDemo() async throws {
        for access in [MicrophonePermissionState.denied, .restricted] {
            let session = ExperienceSession()
            let log = PickerLog()
            let permission = PickerPermission(access)
            let shell = try await open(session, permission: permission, factory: log.factory)
            let presenter = shell.presenter
            let result = await presenter.pickSource(.microphone)
            XCTAssertEqual(result, .rejected(.rule(code: OdysseyRule.permissionDenied)), "\(access)")
            XCTAssertEqual(permission.requests, 0, "\(access): no request")
            XCTAssertEqual(presenter.mirror.source, .demo, "\(access)")
            XCTAssertEqual(shown(presenter).status, "Demo signal", "\(access)")
            XCTAssertEqual(shown(presenter).message, OdysseyPresenter.deniedMessage, "\(access)")
            XCTAssertTrue(shown(presenter).settings, "\(access): the Settings link")
            XCTAssertEqual(log.made.map(\.label), ["demo"], "\(access): the demo keeps playing")
            XCTAssertEqual(log.made.first?.state, .running)
            session.close()
        }
    }

    func testNotDeterminedAsksOnceThenPlaysOrFallsBackToTheDemo() async throws {
        // Allowed when asked: the microphone plays, no message.
        do {
            let session = ExperienceSession()
            let log = PickerLog()
            let permission = PickerPermission(.notDetermined, answer: .granted)
            let shell = try await open(session, permission: permission, factory: log.factory)
            let presenter = shell.presenter
            let result = await presenter.pickSource(.microphone)
            XCTAssertEqual(result, .accepted)
            XCTAssertEqual(permission.requests, 1)
            XCTAssertFalse(presenter.mirror.isRequestingPermission)
            try frames(session, 2)
            XCTAssertEqual(shown(presenter).status, "Microphone")
            XCTAssertNil(shown(presenter).message)
            XCTAssertFalse(shown(presenter).settings)
            XCTAssertEqual(log.made.last?.label, "microphone")
            session.close()
        }
        // Refused when asked: back to the demo with the Settings message.
        do {
            let session = ExperienceSession()
            let log = PickerLog()
            let permission = PickerPermission(.notDetermined, answer: .denied)
            let shell = try await open(session, permission: permission, factory: log.factory)
            let presenter = shell.presenter
            let result = await presenter.pickSource(.microphone)
            XCTAssertEqual(result, .accepted, "accepted while asking")
            XCTAssertEqual(permission.requests, 1)
            try frames(session, 2)
            XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.source, .demo)
            XCTAssertEqual(shown(presenter).status, "Demo signal")
            XCTAssertEqual(shown(presenter).message, OdysseyPresenter.deniedMessage)
            XCTAssertTrue(shown(presenter).settings)
            XCTAssertEqual(log.made.map(\.label), ["demo"], "no microphone source was made")
            session.close()
        }
    }
}
