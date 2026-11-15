// SolarTimeTourSessionTests — feature 106 (A14-P04) T-A14-408 (FR-A14-401–403, FR-A14-411, FR-A14-420, FR-A14-421;
// SC-A14-404, SC-A14-405; clarifications Q1–Q5). The time, tour, label and saved-view behaviour of Solar System
// Explorer inside the one app's session host on the simulator, short runs only (each test well under 10 s, no
// wall-clock assertion; the announcement limit and "Now" run on clocks the test drives): playing at 1 year/s for 120
// host steps moves Earth's drawn position and advances the date by a year, with the play, rate and periodic date
// announcements; a tour visits its stops in order with its caption in the overlay mirror, and holds, skips and stops;
// with Reduce Motion the camera cuts to each stop; Save view, a change and Restore view return the view, and refused
// files change nothing and say why; Now sets the date from the injected clock; while the experience is suspended and
// frames are drawn the date does not move; the labels follow the drawn camera on the overlay's canvas.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreUI

@MainActor
final class SolarTimeTourSessionTests: XCTestCase {
    private let size = CGSize(width: 240, height: 160)

    /// Opens Solar System Explorer in `session` with the given presenter options (as `SolarTest.open`), lays the view
    /// out at 240 × 160 points, tells the presenter the overlay's size in points and draws one frame.
    private func open(_ session: ExperienceSession, reduceMotion: Bool = false,
                      sink: (any AnnouncementSink)? = nil, storage: ExperienceStorage? = nil,
                      now: @escaping () -> Date = { Date(timeIntervalSince1970: SimulatedDate.j2000UnixSeconds) },
                      announcementClock: (() -> Date)? = nil) async throws -> ExperienceShell<SolarPresenter> {
        let id = SolarTest.id
        var made: ExperienceShell<SolarPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = SolarSystemExplorerExperience.make(id: id, reduceMotion: reduceMotion, announcementSink: sink,
                                                           storage: storage, now: now,
                                                           announcementClock: announcementClock)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        shell.presenter.mirror.overlaySize = Vec2(Double(size.width), Double(size.height))
        try SolarTest.frames(session, 1)
        return shell
    }

    /// The drawn scene position of body `index` in the last frame.
    private func drawn(_ presenter: SolarPresenter, _ index: Int) throws -> Vec3 {
        XCTAssertEqual(presenter.lastCenters.count, SolarCore.bodyCount)
        guard presenter.lastCenters.indices.contains(index) else { throw XCTSkip("no drawn position") }
        return presenter.lastCenters[index]
    }

    func testPlayingAtOneYearPerSecondMovesEarthAndAdvancesTheDateByAYear() async throws {
        let session = ExperienceSession()
        let sink = RecordingAnnouncementSink()
        let clock = ManualClock()
        let shell = try await open(session, sink: sink, announcementClock: { clock.time })
        let presenter = shell.presenter
        let earthStart = try drawn(presenter, 3)
        XCTAssertEqual(presenter.mirror.dateTimeLabel, "2000-01-01 12:00 UTC")
        XCTAssertFalse(presenter.mirror.playing)
        XCTAssertEqual(sink.announced, [], "nothing announced before a change")

        XCTAssertTrue(shell.handle(control: "time.rate", values: [3]).isAccepted)
        XCTAssertEqual(presenter.mirror.rateLabel, "1 year/s")
        XCTAssertEqual(sink.announced.last, "Rate 1 year/s, time paused. Date 2000-01-01 12:00 UTC.")
        XCTAssertTrue(shell.handle(control: "time.play", values: [1]).isAccepted)
        XCTAssertTrue(presenter.mirror.playing)
        XCTAssertEqual(SolarPresenter.playWords(playing: presenter.mirror.playing, rateIndex: presenter.mirror.rateIndex),
                       "Playing at 1 year/s")
        XCTAssertEqual(sink.announced.last, "Time playing at 1 year/s. Date 2000-01-01 12:00 UTC.")
        let eventCount = sink.announced.count

        let startStep = shell.engine.stepIndex
        var frames = 0
        var midway: Vec3?
        while shell.engine.stepIndex - startStep < 120, frames < 200 {
            try SolarTest.frames(session, 1)
            frames += 1
            if midway == nil, shell.engine.stepIndex - startStep >= 60 { midway = try drawn(presenter, 3) }
        }
        let steps = shell.engine.stepIndex - startStep
        XCTAssertGreaterThanOrEqual(steps, 120)
        let state = try SolarTest.core(shell).state
        XCTAssertEqual(state.dayOffset, 365 * Double(steps) / 120, accuracy: 1e-6, "rate × steps / 120 days")
        XCTAssertGreaterThanOrEqual(state.dayOffset, 365 - 1e-9, "a year passed")
        XCTAssertEqual(presenter.mirror.dayOffset, state.dayOffset)
        XCTAssertEqual(presenter.lastDayOffset, state.dayOffset, "the last frame drew the new date")
        XCTAssertEqual(presenter.mirror.dateTimeLabel, state.date.labelWithTime)
        if steps == 120 { XCTAssertEqual(presenter.mirror.dateTimeLabel, "2000-12-31 12:00 UTC") }
        let half = try XCTUnwrap(midway)
        XCTAssertGreaterThan((half - earthStart).length, 1, "half a year moves Earth's drawn position across its orbit")
        XCTAssertEqual(try drawn(presenter, 3), OrbitLayout.scenePosition(index: 3, day: state.dayOffset, mode: .enhanced))
        XCTAssertEqual(sink.announced.count, eventCount, "no periodic date before 10 s of wall time")

        clock.advance(10)
        try SolarTest.frames(session, 1)
        XCTAssertEqual(sink.announced.count, eventCount + 1)
        XCTAssertTrue(sink.announced.last?.hasPrefix("Date ") ?? false, "\(sink.announced)")
        try SolarTest.frames(session, 5)
        XCTAssertEqual(sink.announced.count, eventCount + 1, "at most once every 10 s")

        XCTAssertTrue(shell.handle(control: "time.play", values: [0]).isAccepted)
        XCTAssertTrue(sink.announced.last?.hasPrefix("Time paused. Date ") ?? false, "\(sink.announced)")
        XCTAssertEqual(SolarPresenter.playWords(playing: false, rateIndex: 3), "Paused")
        session.close()
    }

    func testATourVisitsItsStopsInOrderWithTheCaptionAndHoldsSkipsAndStops() async throws {
        let session = ExperienceSession()
        let sink = RecordingAnnouncementSink()
        let shell = try await open(session, sink: sink)
        let presenter = shell.presenter
        XCTAssertNotNil(shell.canvasOverlay, "the overlay reaches the host")
        XCTAssertEqual(presenter.mirror.tourCaption, "")
        let tour = Tour.bundled[0]

        XCTAssertTrue(shell.handle(control: "tour.start", values: [0]).isAccepted)
        XCTAssertEqual(presenter.mirror.tourTitle, "Inner planets")
        XCTAssertEqual(presenter.mirror.tourStopCount, 5)
        XCTAssertEqual(presenter.mirror.tourStop, 0)
        XCTAssertEqual(presenter.mirror.tourCaption, tour.stops[0].caption)
        XCTAssertEqual(SolarControls.tourValue(title: presenter.mirror.tourTitle, stop: presenter.mirror.tourStop,
                                               count: presenter.mirror.tourStopCount,
                                               paused: presenter.mirror.tourPaused), "Inner planets, stop 1 of 5")
        XCTAssertEqual(sink.announced.last, SolarCore.tourWords(state: try SolarTest.core(shell).state))

        // The first stop ends by itself after 600 host steps.
        var frames = 0
        while try SolarTest.core(shell).state.tourStop == 0, frames < 400 {
            try SolarTest.frames(session, 1)
            frames += 1
        }
        var state = try SolarTest.core(shell).state
        XCTAssertEqual(state.tourStop, 1)
        XCTAssertEqual(state.selection, tour.stops[1].bodyIndex)
        XCTAssertEqual(presenter.mirror.tourCaption, tour.stops[1].caption)
        XCTAssertEqual(presenter.mirror.bodyName, "Mercury")

        // Hold: steps do not count.
        XCTAssertTrue(shell.handle(control: "tour.pause", values: [1]).isAccepted)
        XCTAssertTrue(presenter.mirror.tourPaused)
        let held = try SolarTest.core(shell).state.tourStep
        try SolarTest.frames(session, 10)
        XCTAssertEqual(try SolarTest.core(shell).state.tourStep, held, "a held tour does not move")
        XCTAssertTrue(shell.handle(control: "tour.pause", values: [0]).isAccepted)
        XCTAssertFalse(presenter.mirror.tourPaused)

        // Skip through the remaining stops in order; the flight brings each body to the centre, labelled first.
        for stop in 2..<tour.stops.count {
            XCTAssertTrue(shell.handle(control: "tour.next").isAccepted)
            state = try SolarTest.core(shell).state
            XCTAssertEqual(state.tourStop, stop)
            XCTAssertEqual(state.selection, tour.stops[stop].bodyIndex)
            XCTAssertEqual(presenter.mirror.tourCaption, tour.stops[stop].caption)
            XCTAssertEqual(sink.announced.last, SolarCore.tourWords(state: state))
            try SolarTest.frames(session, FocusFlight.frameCount)
            XCTAssertEqual(presenter.lastSelection, tour.stops[stop].bodyIndex)
            XCTAssertEqual(presenter.lastLabels.first?.index, tour.stops[stop].bodyIndex, "\(presenter.lastLabels)")
        }
        // Next after the last stop ends the tour.
        XCTAssertTrue(shell.handle(control: "tour.next").isAccepted)
        state = try SolarTest.core(shell).state
        XCTAssertEqual(state.tourIndex, -1)
        XCTAssertEqual(presenter.mirror.tourCaption, "")
        XCTAssertEqual(presenter.mirror.tourIndex, -1)
        XCTAssertEqual(sink.announced.last, SolarPresenter.tourEndedWords)
        XCTAssertFalse(shell.handle(control: "tour.stop").isAccepted, "no tour to stop")
        XCTAssertEqual(SolarPresenter.answerWords(control: "tour.stop", result: shell.handle(control: "tour.stop")),
                       "There is no tour running.")

        // Stop: the tour ends and the body stays.
        XCTAssertTrue(shell.handle(control: "tour.start", values: [1]).isAccepted)
        XCTAssertEqual(presenter.mirror.tourCaption, Tour.bundled[1].stops[0].caption)
        XCTAssertTrue(shell.handle(control: "tour.stop").isAccepted)
        state = try SolarTest.core(shell).state
        XCTAssertEqual(state.tourIndex, -1)
        XCTAssertEqual(state.selection, 5, "Jupiter stays in focus")
        XCTAssertEqual(presenter.mirror.tourCaption, "")
        session.close()
    }

    func testWithReduceMotionTheCameraCutsToEachTourStop() async throws {
        let cutSession = ExperienceSession()
        let cut = try await open(cutSession, reduceMotion: true)
        XCTAssertTrue(cut.handle(control: "tour.start", values: [1]).isAccepted)
        for stop in 0..<Tour.bundled[1].stops.count {
            if stop > 0 { XCTAssertTrue(cut.handle(control: "tour.next").isAccepted) }
            try SolarTest.frames(cutSession, 1)
            let state = try SolarTest.core(cut).state
            let body = Tour.bundled[1].stops[stop].bodyIndex
            XCTAssertEqual(state.selection, body)
            let expected = OrbitLayout.scenePosition(index: body, day: state.dayOffset, mode: state.scaleMode)
            let target = try XCTUnwrap(cut.presenter.lastCamera?.target)
            XCTAssertLessThan((target - expected).length, 1e-9, "stop \(stop): the first frame shows the body")
        }
        cutSession.close()

        let flySession = ExperienceSession()
        let fly = try await open(flySession)
        XCTAssertTrue(fly.handle(control: "tour.start", values: [1]).isAccepted)
        try SolarTest.frames(flySession, 1)
        let state = try SolarTest.core(fly).state
        let jupiter = OrbitLayout.scenePosition(index: 5, day: state.dayOffset, mode: state.scaleMode)
        let target = try XCTUnwrap(fly.presenter.lastCamera?.target)
        XCTAssertGreaterThan((target - jupiter).length, 1e-3, "without Reduce Motion the camera flies")
        flySession.close()
    }

    func testSaveChangeAndRestoreReturnTheViewAndRefusedFilesChangeNothing() async throws {
        let temporary = TemporarySolarStorage()
        defer { temporary.remove() }
        let session = ExperienceSession()
        let shell = try await open(session, storage: temporary.storage)
        let presenter = shell.presenter
        XCTAssertNil(presenter.restoreView(shell.port), "nothing saved yet")
        XCTAssertEqual(presenter.mirror.viewMessage, "No view has been saved yet.")

        let setup: [(control: String, values: [Double])] = [
            ("body.select", [4]), ("camera.orbit", [1]), ("camera.orbit", [1]), ("camera.zoom", [1]),
            ("camera.tilt", [1]), ("date.step", [30]), ("scale.mode", [1]), ("time.rate", [2]),
        ]
        for action in setup { XCTAssertTrue(shell.handle(control: action.control, values: action.values).isAccepted) }
        let saved = try XCTUnwrap(try SolarTest.core(shell).state.savedView)
        XCTAssertTrue(presenter.saveView())
        XCTAssertEqual(presenter.mirror.viewMessage, "View saved.")
        XCTAssertEqual(try temporary.storage.read(SavedView.fileName), saved.encoded())

        let change: [(control: String, values: [Double])] = [
            ("body.select", [7]), ("view.reset", []), ("scale.mode", [0]), ("time.rate", [0]),
            ("date.step", [365]), ("tour.start", [0]),
        ]
        for action in change { XCTAssertTrue(shell.handle(control: action.control, values: action.values).isAccepted) }
        XCTAssertNotEqual(try SolarTest.core(shell).state.savedView, saved)
        let result = try XCTUnwrap(presenter.restoreView(shell.port))
        XCTAssertTrue(result.isAccepted)
        let restored = try SolarTest.core(shell).state
        XCTAssertEqual(restored.savedView, saved, "the view is back")
        XCTAssertEqual(restored.tourIndex, -1, "restoring a view stops the tour")
        XCTAssertFalse(restored.playing)
        XCTAssertEqual(presenter.mirror.viewMessage, "View restored.")
        XCTAssertEqual(presenter.mirror.bodyName, "Mars")
        try SolarTest.frames(session, FocusFlight.frameCount)
        XCTAssertEqual(presenter.lastSelection, 4)

        // Refused files: nothing changes and the reason is shown.
        XCTAssertTrue(shell.handle(control: "body.select", values: [2]).isAccepted)
        let before = try SolarTest.core(shell).state
        let newer = String(decoding: saved.encoded(), as: UTF8.self)
            .replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        let files: [(bytes: Data, words: String)] = [
            (Data("{\"schema\":".utf8), "The saved view could not be read (damaged)."),
            (Data(newer.utf8), "The saved view could not be read (newer-version)."),
            (Data(repeating: 0x20, count: SavedView.maxBytes + 1), "The saved view could not be read (oversized)."),
        ]
        for file in files {
            try temporary.storage.write(file.bytes, to: SavedView.fileName)
            XCTAssertNil(presenter.restoreView(shell.port))
            XCTAssertEqual(presenter.mirror.viewMessage, file.words)
            XCTAssertEqual(try SolarTest.core(shell).state, before, "a refused file changes nothing")
        }
        session.close()
    }

    func testNowSetsTheDateFromTheInjectedClock() async throws {
        let session = ExperienceSession()
        let instant = Date(timeIntervalSince1970: SimulatedDate.j2000UnixSeconds + 9_000.5 * SimulatedDate.secondsPerDay)
        let shell = try await open(session, now: { instant })
        let presenter = shell.presenter
        XCTAssertTrue(presenter.setNow(shell.port).isAccepted)
        let state = try SolarTest.core(shell).state
        XCTAssertEqual(state.dayOffset, 9_000.5, accuracy: 1e-9)
        XCTAssertEqual(presenter.mirror.dateTimeLabel, state.date.labelWithTime)
        XCTAssertEqual(presenter.mirror.message, "")
        let far = Date(timeIntervalSince1970: SimulatedDate.j2000UnixSeconds + 1e6 * SimulatedDate.secondsPerDay)
        XCTAssertEqual(SolarPresenter.nowDays(far), SimulatedDate.range.upperBound, "clamped to the range")
        let early = Date(timeIntervalSince1970: SimulatedDate.j2000UnixSeconds - 1e6 * SimulatedDate.secondsPerDay)
        XCTAssertEqual(SolarPresenter.nowDays(early), SimulatedDate.range.lowerBound)
        XCTAssertEqual(SolarPresenter.nowDays(Date(timeIntervalSince1970: SimulatedDate.j2000UnixSeconds)), 0)
        session.close()
    }

    func testWhileSuspendedAndDrawingTheDateDoesNotMove() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "time.rate", values: [3]).isAccepted)
        XCTAssertTrue(shell.handle(control: "time.play", values: [1]).isAccepted)
        try SolarTest.frames(session, 5)
        let before = try SolarTest.core(shell).state
        XCTAssertGreaterThan(before.dayOffset, 0, "time plays while active")
        let label = presenter.mirror.dateTimeLabel
        let stepIndex = shell.engine.stepIndex
        let drawnBefore = presenter.framesDrawn

        try shell.suspend()
        XCTAssertEqual(shell.state, .suspended)
        try SolarTest.frames(session, 20)
        XCTAssertEqual(presenter.framesDrawn, drawnBefore + 20, "frames are drawn while suspended")
        XCTAssertEqual(try SolarTest.core(shell).state, before, "the date does not move while suspended")
        XCTAssertEqual(shell.engine.stepIndex, stepIndex)
        XCTAssertEqual(presenter.mirror.dateTimeLabel, label)
        XCTAssertEqual(presenter.lastDayOffset, before.dayOffset)

        try shell.resume()
        try SolarTest.frames(session, 5)
        XCTAssertGreaterThan(try SolarTest.core(shell).state.dayOffset, before.dayOffset, "it plays on after the resume")
        session.close()
    }

    func testTheLabelsFollowTheDrawnCameraOnTheOverlaysCanvas() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        try SolarTest.frames(session, 1)
        XCTAssertEqual(presenter.lastCanvasPoints, Vec2(240, 160), "laid out in the overlay's points")
        XCTAssertEqual(presenter.mirror.canvasSize, Vec2(240, 160))
        let labels = presenter.lastLabels
        XCTAssertEqual(presenter.mirror.labels, labels)
        XCTAssertGreaterThanOrEqual(labels.count, 2, "\(labels)")
        XCTAssertEqual(labels.first?.index, 0, "the focused Sun first")
        XCTAssertEqual(labels.first?.name, "Sun")
        let first = try XCTUnwrap(labels.first)
        XCTAssertEqual(first.point.x, 120 + LabelLayout.offsetRight, accuracy: 1e-6, "the Sun at the canvas centre")
        XCTAssertEqual(first.point.y, 80 - LabelLayout.offsetUp, accuracy: 1e-6)
        for i in labels.indices {
            for j in labels.indices where j > i {
                XCTAssertFalse(LabelLayout.overlaps(labels[i].box, labels[j].box))
            }
        }
        // The labels are recomputed from each drawn camera.
        XCTAssertTrue(shell.handle(control: "camera.orbit", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "camera.orbit", values: [1]).isAccepted)
        try SolarTest.frames(session, 1)
        XCTAssertNotEqual(presenter.lastLabels, labels, "a new camera moves the labels")
        session.close()
    }
}
