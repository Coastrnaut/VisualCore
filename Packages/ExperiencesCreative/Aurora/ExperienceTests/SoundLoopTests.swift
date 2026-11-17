// SoundLoopTests — feature 156 (A21-P05) T-A21-504 (FR-A21-501–504; SC-A21-501, SC-A21-505; contracts/sound.md).
// Fixture 3 of the manual: the sound belongs to the person, not to the drawing. Through the one app's session host
// with a fake player (``FakeLoop``: it counts plays and stops and keeps the volume; no audio plays): a fresh start has
// the sound off and makes no player; the loop plays while the sound is on, the controls are on screen and the scene is
// active, and stops when any of them ends; the volume is passed at once; the drawing lifecycle (setup, draw,
// teardown, setup again, a preset change, the still view, reduced flashing, a suspension) neither plays nor stops it;
// a loop that cannot start leaves the choice on and the sky drawing; the digest and the manifest are the same with
// the sound on and off; the choice is restored over the same storage and a damaged `prefs.v1` opens off. Short runs
// only.
import CoreGraphics
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// A player that plays nothing: it counts `play()` and `stop()` and keeps the volume.
@MainActor
final class FakeLoop: SkyLoopPlaying {
    /// Whether `play()` would play.
    var isEnabled = true
    /// The volume last given.
    var volume: Float = 1
    /// Whether the fake "plays".
    private(set) var isPlaying = false
    /// What `play()` returns (false: the output failed).
    var playResult = true
    /// How many times `play()` was called.
    private(set) var plays = 0
    /// How many times `stop()` was called.
    private(set) var stops = 0

    /// Counts the call and "plays" when ``playResult`` is true.
    func play() -> Bool {
        plays += 1
        isPlaying = playResult
        return playResult
    }

    /// Counts the call and stops.
    func stop() {
        stops += 1
        isPlaying = false
    }
}

/// Makes ``FakeLoop``s and keeps them.
@MainActor
final class FakeLoops {
    /// Every player made, in order.
    private(set) var made: [FakeLoop] = []
    /// What the next player's `play()` returns.
    var playResult = true

    /// The factory given to the presenter.
    var factory: () -> any SkyLoopPlaying {
        { [unowned self] in
            let loop = FakeLoop()
            loop.playResult = playResult
            made.append(loop)
            return loop
        }
    }
}

@MainActor
@Suite(.serialized) struct SoundLoopTests {
    @Test func aFreshStartHasTheSoundOffAndMakesNoPlayer() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        let loops = FakeLoops()
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, storage: place.storage, loopFactory: loops.factory)
        let presenter = shell.presenter
        presenter.controlsAppeared()
        presenter.sceneActive(true)
        try AuroraTest.draw(session, frames: 10)
        #expect(!presenter.mirror.soundOn && !presenter.preferences.soundOn, "off on a first start")
        #expect(loops.made.isEmpty && presenter.sound.player == nil, "no player is made")
        #expect(!presenter.sound.shouldPlay)
    }

    @Test func theLoopPlaysOnlyWhileOnOnScreenAndActive() async throws {
        let loops = FakeLoops()
        let session = ExperienceSession()
        defer { session.close() }
        let presenter = try await AuroraTest.open(session, loopFactory: loops.factory).presenter
        presenter.setSound(on: true)
        #expect(loops.made.isEmpty, "not on screen yet: nothing is made")
        presenter.controlsAppeared()
        let loop = try #require(loops.made.first)
        #expect(loop.plays == 1 && loop.isPlaying && loop.isEnabled, "on, on screen and active: plays")
        presenter.setSound(on: false)
        #expect(loop.stops == 1 && !loop.isPlaying && !loop.isEnabled, "off: stops")
        presenter.setSound(on: true)
        #expect(loop.plays == 2 && loop.isPlaying, "on again: plays")
        presenter.controlsDisappeared()
        #expect(loop.stops == 2 && !loop.isPlaying, "off screen: stops")
        presenter.controlsAppeared()
        #expect(loop.plays == 3 && loop.isPlaying, "back on screen: plays")
        presenter.sceneActive(false)
        #expect(loop.stops == 3 && !loop.isPlaying, "inactive: stops")
        presenter.sceneActive(false)
        presenter.sceneActive(true)
        #expect(loop.plays == 4 && loop.stops == 3 && loop.isPlaying, "active again: plays once")
        #expect(loops.made.count == 1, "one player")
    }

    @Test func theVolumeIsPassedAtOnce() async throws {
        let loops = FakeLoops()
        let session = ExperienceSession()
        defer { session.close() }
        let presenter = try await AuroraTest.open(session, loopFactory: loops.factory).presenter
        presenter.setVolume(0.4)
        presenter.controlsAppeared()
        presenter.setSound(on: true)
        let loop = try #require(loops.made.first)
        #expect(loop.volume == Float(0.4), "the volume when it starts")
        presenter.setVolume(0.8)
        #expect(loop.volume == Float(0.8), "a change applies at once")
        presenter.setVolume(0)
        #expect(loop.volume == 0 && loop.isPlaying && loop.stops == 0, "0 plays silently")
        presenter.setVolume(0.4)
        #expect(loop.volume == Float(0.4) && presenter.mirror.volume == 0.4)
    }

    @Test func theDrawingNeverPlaysOrStopsTheLoop() async throws {
        let loops = FakeLoops()
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, loopFactory: loops.factory)
        let presenter = shell.presenter
        presenter.controlsAppeared()
        presenter.setSound(on: true)
        let loop = try #require(loops.made.first)
        let host = try #require(session.renderHost)
        func expectUntouched(_ event: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(loop.plays == 1 && loop.stops == 0 && loop.isPlaying, "\(event)", sourceLocation: sourceLocation)
        }
        try AuroraTest.draw(session, frames: 5)
        expectUntouched("draw")
        let setups = presenter.setupCount
        host.recreateContext()   // teardown, then a second setup
        try AuroraTest.draw(session)
        #expect(presenter.setupCount == setups + 1)
        expectUntouched("teardown and setup again")
        host.view.frame = CGRect(x: 0, y: 0, width: 48, height: 36)
        host.view.layoutIfNeeded()
        try AuroraTest.draw(session)
        expectUntouched("resize")
        AuroraTest.accept(shell, "preset.select", [1])
        try AuroraTest.draw(session, frames: 10)
        expectUntouched("a preset change")
        presenter.setStillView(true)
        try AuroraTest.draw(session, frames: 5)
        presenter.setStillView(false)
        expectUntouched("the still view")
        presenter.setReducedFlash(true)
        try AuroraTest.draw(session, frames: 5)
        presenter.setReducedFlash(false)
        expectUntouched("reduced flashing")
        session.setScenePhase(.background)
        session.setScenePhase(.active)
        try AuroraTest.draw(session)
        expectUntouched("the drawing paused and resumed")
        #expect(loops.made.count == 1)
    }

    @Test func aLoopThatCannotStartLeavesTheChoiceOnAndTheSkyDrawing() async throws {
        let loops = FakeLoops()
        loops.playResult = false
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, loopFactory: loops.factory)
        let presenter = shell.presenter
        presenter.controlsAppeared()
        presenter.setSound(on: true)
        let loop = try #require(loops.made.first)
        #expect(loop.plays == 1 && !loop.isPlaying)
        #expect(presenter.mirror.soundOn && presenter.preferences.soundOn, "the choice stays on")
        let drawn = presenter.skyDrawCount
        try AuroraTest.draw(session, frames: 5)
        #expect(presenter.skyDrawCount == drawn + 5, "the sky keeps drawing")
        let diff = AuroraTest.difference(try AuroraTest.still(session), try AuroraTest.reference(shell))
        #expect(diff.mean <= 2 && diff.max <= 8, "the sky as drawn: \(diff)")
    }

    @Test func theDigestAndTheManifestAreTheSameWithTheSoundOnAndOff() async throws {
        let loops = FakeLoops()
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, loopFactory: loops.factory)
        let presenter = shell.presenter
        let id = try #require(AuroraExperience.id)
        let digest = try shell.engine.digest()
        let snapshot = try shell.snapshot()
        let manifest = SkyCore.manifest(for: id)
        let revision = shell.port.revision
        presenter.controlsAppeared()
        presenter.setSound(on: true)
        presenter.setVolume(0.9)
        #expect(shell.port.revision == revision, "no action")
        try AuroraTest.draw(session)
        #expect(loops.made.first?.isPlaying == true)
        #expect(try shell.engine.digest() == digest, "the digest")
        #expect(try shell.snapshot().payload == snapshot.payload, "the snapshot")
        #expect(SkyCore.manifest(for: id) == manifest, "the manifest")
        presenter.setSound(on: false)
        #expect(try shell.engine.digest() == digest)
    }

    @Test func theChoiceIsRestoredAndADamagedValueOpensOff() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        let first = FakeLoops()
        let session = ExperienceSession()
        let presenter = try await AuroraTest.open(session, storage: place.storage, loopFactory: first.factory).presenter
        presenter.setSound(on: true)
        presenter.setVolume(0.4)
        session.close()
        #expect(first.made.isEmpty, "never on screen: nothing was made")

        let again = FakeLoops()
        let next = ExperienceSession()
        let reopened = try await AuroraTest.open(next, storage: place.storage, loopFactory: again.factory).presenter
        #expect(reopened.mirror.soundOn && reopened.mirror.volume == 0.4, "restored")
        #expect(again.made.isEmpty, "nothing plays before the controls are on screen")
        reopened.controlsAppeared()
        let loop = try #require(again.made.first)
        #expect(loop.plays == 1 && loop.isPlaying && loop.volume == Float(0.4), "plays at the restored volume")
        next.close()

        try place.storage.setValue(Data("{\"kind\":\"a21.prefer".utf8), for: SkyPreferences.storageKey)
        let damaged = FakeLoops()
        let third = ExperienceSession()
        defer { third.close() }
        let opened = try await AuroraTest.open(third, storage: place.storage, loopFactory: damaged.factory).presenter
        opened.controlsAppeared()
        #expect(!opened.mirror.soundOn && opened.preferencesRefusal != nil, "a damaged value opens off")
        #expect(damaged.made.isEmpty, "and makes no player")
    }
}
