// CalmTests — feature 149 (A20-P05) T-A20-504 (FR-A20-501, FR-A20-503; SC-A20-504; contracts/quiet.md "Defaults",
// "Sound and haptics"). The calm switches of Digital Zen Garden: off by default; kept across a reopen as the experience
// value `calm.v1`; damaged values ignored; the digest unchanged by them; tones and haptics requested only while their
// switch is on; the sound sink disabled while the sound is off; every tone stopped when the experience suspends. Short
// runs without a render host (no sleep, no wall-clock assertion); the haptic route has a clock that moves one second per
// reading, so the rate limit never drops a request.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation
import VisualCoreUI

/// A sound sink that records every request and every stop.
@MainActor
final class RecordingGardenSoundSink: GardenSoundSink {
    /// Whether a play would sound.
    var isEnabled = false
    /// The ids played while enabled, oldest first.
    private(set) var played: [String] = []
    /// The ids requested while disabled.
    private(set) var dropped: [String] = []
    /// How many times every tone was stopped.
    private(set) var stops = 0

    /// Records `id` as played (enabled) or dropped (disabled).
    func play(_ effect: SoundEffect, id: String) {
        if isEnabled { played.append(id) } else { dropped.append(id) }
    }

    /// Counts the stop.
    func stopAll() { stops += 1 }
}

/// Calm helpers.
@MainActor
enum CalmTest {
    /// A prepared, active shell (over `storage` when given) whose tones go to `sink` and whose haptics go to `haptics`.
    static func shell(storage: ExperienceStorage? = nil, sink: RecordingGardenSoundSink = RecordingGardenSoundSink(),
                      haptics: RecordingHapticSink = RecordingHapticSink()) async throws
        -> ExperienceShell<GardenPresenter> {
        let shell = DigitalZenGardenExperience.make(id: GardenTest.id, storage: storage)
        let ticker = GardenTicker()
        shell.presenter.soundSink = sink
        shell.presenter.feedback = ExperienceFeedback(hapticSink: haptics, announcementSink: RecordingAnnouncementSink(),
                                                      clock: { ticker.tick() }, voiceOverRunning: { false })
        try await shell.prepare(seed: 1)
        try shell.activate()
        return shell
    }

    /// Rakes the rows pattern, places a river pebble, deselects it, selects it and removes it, through the presenter.
    static func play(_ shell: ExperienceShell<GardenPresenter>) {
        let presenter = shell.presenter
        let port = shell.port
        presenter.rakePattern(0, port: port)
        let kind = GardenPalette.stones.firstIndex { $0.id == "river-pebble" } ?? 0
        presenter.placeStone(kind: kind, port: port)
        presenter.selectStone([0], port: port)
        presenter.selectStone([1], port: port)
        presenter.removeStone(port: port)
    }
}

@MainActor
@Suite(.serialized) struct CalmTests {
    @Test func theSwitchesAreOffByDefault() async throws {
        #expect(GardenCore().calm == .off && CalmSettings.off == CalmSettings(sound: false, drift: false, haptics: false))
        #expect(GardenCore.controls.suffix(3).map(\.id) == GardenCore.calmActionIDs)
        #expect(GardenCore.controls.suffix(3).allSatisfy { $0.ranges == [0...1] })
        let sink = RecordingGardenSoundSink()
        sink.isEnabled = true
        let shell = try await CalmTest.shell(sink: sink)
        #expect(try GardenTest.core(shell).calm == .off)
        #expect(shell.presenter.calm == .off && !sink.isEnabled, "the sink starts disabled")
        let labels = GardenControls.labels(shell.presenter.mirror, entries: nil, name: "", stillReady: false)
        let calm = labels.filter { $0.name.hasPrefix("calm-") }.map(\.text)
        #expect(calm == ["Sound, Off", "Sand drift, Off", "Haptics, Off"])
        for id in GardenCore.calmActionIDs {
            #expect(shell.presenter.nativeActions.contains(id), "\(id) is a native action")
        }
        #expect(shell.presenter.gestureActions.isSubset(of: shell.presenter.nativeActions))
        let player = GardenSoundPlayer()
        #expect(!player.isEnabled && player.player == nil, "the default player is off and not made yet")
    }

    @Test func aRefusedSwitchValueChangesNothing() {
        let fresh = GardenCore()
        for id in GardenCore.calmActionIDs {
            let (half, refused) = gardenApplied(fresh, id, [0.5])
            #expect(refused.code == "action.rule." + GardenRule.invalidChoice && half == fresh)
            let (_, out) = gardenApplied(fresh, id, [2])
            #expect(out.code == "action.out-of-range")
        }
    }

    @Test func theSwitchesAreKeptAcrossAReopen() async throws {
        let place = try GardenStoragePlace("calm-reopen")
        defer { place.remove() }
        let first = try await CalmTest.shell(storage: place.storage)
        first.presenter.setCalm("calm.sound", on: true, port: first.port)
        first.presenter.setCalm("calm.haptics", on: true, port: first.port)
        let stored = try #require(place.storage.value(for: CalmSettings.storageKey))
        #expect(String(decoding: stored, as: UTF8.self) == #"{"drift":0,"haptics":1,"sound":1}"#)
        let kept = CalmSettings(sound: true, drift: false, haptics: true)
        #expect(first.presenter.calm == kept)

        // A new experience over the same storage reads the switches and sends them to its fresh core.
        let second = try await CalmTest.shell(storage: place.storage)
        #expect(second.presenter.calm == kept)
        #expect(try GardenTest.core(second).calm == .off, "a fresh core starts off")
        let applied = second.presenter.applyKeptCalm()
        #expect(applied)
        #expect(try GardenTest.core(second).calm == kept)
        let again = second.presenter.applyKeptCalm()
        #expect(!again, "nothing more to send")

        // Opened in the one app's session, the first frame sends them.
        let session = ExperienceSession()
        let third = try await GardenTest.open(session, storage: place.storage)
        #expect(try GardenTest.core(third).calm == kept)

        // Opening a saved garden restores the document; the switches come back at the next draw.
        let saved = third.presenter.saveGarden(named: "Evening")
        let entry = try #require(GardenLibraryTest.saved(saved))
        let opened = third.presenter.openGarden(entry.file)
        #expect((try? opened.get()) != nil)
        try GardenTest.draw(session)
        #expect(try GardenTest.core(third).calm == kept)
        #expect(GardenPresenter.keptCalm(place.storage) == kept, "the restore did not overwrite the kept switches")

        // Turned off again, the stored value says so.
        third.presenter.setCalm("calm.sound", on: false, port: third.port)
        #expect(GardenPresenter.keptCalm(place.storage) == CalmSettings(sound: false, drift: false, haptics: true))
    }

    @Test func aDamagedValueIsIgnored() async throws {
        let place = try GardenStoragePlace("calm-damaged")
        defer { place.remove() }
        let damaged = ["nonsense", "[]", #"{"sound":2,"drift":0,"haptics":0}"#, #"{"sound":1,"drift":0}"#,
                       #"{"sound":true,"drift":false,"haptics":false}"#, #"{"sound":"1","drift":0,"haptics":0}"#]
        for text in damaged {
            #expect(CalmSettings.decode(Data(text.utf8)) == nil, "\(text)")
            try place.storage.setValue(Data(text.utf8), for: CalmSettings.storageKey)
            let shell = try await CalmTest.shell(storage: place.storage)
            #expect(shell.presenter.calm == .off, "\(text)")
            let applied = shell.presenter.applyKeptCalm()
            let core = try GardenTest.core(shell)
            #expect(!applied && core.calm == .off, "\(text)")
        }
        let good = CalmSettings(sound: false, drift: true, haptics: false)
        #expect(CalmSettings.decode(good.encoded()) == good)
    }

    @Test func theDigestIsUnchangedByTheSwitches() async throws {
        let shell = try await CalmTest.shell()
        GardenTest.rake(shell, from: Vec2(0.2, 0.4), to: Vec2(0.8, 0.5))
        let before = try GardenTest.digest(shell)
        let core = try GardenTest.core(shell)
        let payload = try core.snapshotPayload()
        for id in GardenCore.calmActionIDs { GardenTest.accept(shell, id, [1]) }
        let on = try GardenTest.core(shell)
        #expect(on.calm == CalmSettings(sound: true, drift: true, haptics: true) && on != core)
        #expect(try GardenTest.digest(shell) == before, "the switches are not garden")
        #expect(try on.snapshotPayload() == payload, "nor in the snapshot")
        #expect(on.outcome == core.outcome && on.document == core.document)
        // A reset keeps the switches (a preference) and opens the empty garden.
        try shell.reset()
        let reset = try GardenTest.core(shell)
        #expect(reset.calm == on.calm && reset.document == .empty)
        let fresh = try gardenDigest(GardenCore())
        #expect(try GardenTest.digest(shell) == fresh)
    }

    @Test func tonesAndHapticsOnlyWhenOn() async throws {
        let sink = RecordingGardenSoundSink()
        let haptics = RecordingHapticSink()
        let quiet = try await CalmTest.shell(sink: sink, haptics: haptics)
        CalmTest.play(quiet)
        #expect(sink.played.isEmpty && sink.dropped.isEmpty, "no tone is requested while the sound is off")
        #expect(haptics.played.isEmpty, "no haptic is requested while the haptics are off")
        let quietDigest = try GardenTest.digest(quiet)

        let loudSink = RecordingGardenSoundSink()
        let loudHaptics = RecordingHapticSink()
        let loud = try await CalmTest.shell(sink: loudSink, haptics: loudHaptics)
        loud.presenter.setCalm("calm.sound", on: true, port: loud.port)
        loud.presenter.setCalm("calm.haptics", on: true, port: loud.port)
        CalmTest.play(loud)
        #expect(loudSink.played == ["a20.stroke", "a20.place", "a20.remove"])
        #expect(loudHaptics.played == [.impactLight, .selection])
        #expect(try GardenTest.digest(loud) == quietDigest, "neither sound nor haptics changes the garden")

        // Only the sound on: tones without haptics; a stone tap on the canvas selects with no haptic.
        let soundSink = RecordingGardenSoundSink()
        let soundHaptics = RecordingHapticSink()
        let sound = try await CalmTest.shell(sink: soundSink, haptics: soundHaptics)
        sound.presenter.setCalm("calm.sound", on: true, port: sound.port)
        CalmTest.play(sound)
        #expect(soundSink.played.count == 3 && soundHaptics.played.isEmpty)
    }

    @Test func aDraggedStrokeAndACanvasTapFollowTheSwitches() async throws {
        let sink = RecordingGardenSoundSink()
        let haptics = RecordingHapticSink()
        let shell = try await CalmTest.shell(sink: sink, haptics: haptics)
        GardenTest.accept(shell, "calm.sound", [1])
        GardenTest.accept(shell, "calm.haptics", [1])
        GardenTest.drag(shell, tray: [Vec2(0.2, 0.5), Vec2(0.5, 0.5), Vec2(0.8, 0.5)])
        #expect(sink.played == ["a20.stroke"], "a committed drag plays the stroke tone")
        GardenTest.accept(shell, "tool.mode", [1])
        GardenTest.accept(shell, "stone.place", [0, 0.5, 0.5])
        GardenTest.accept(shell, "stone.select", [0])
        GardenTest.drag(shell, tray: [Vec2(0.5, 0.5)])
        #expect(try GardenTest.core(shell).selectedStone == 1)
        #expect(haptics.played == [.selection], "a tap that selects a stone plays the selection haptic")
    }

    @Test func theSinkIsDisabledWhileTheSoundIsOff() async throws {
        let sink = RecordingGardenSoundSink()
        let shell = try await CalmTest.shell(sink: sink)
        #expect(!sink.isEnabled)
        shell.presenter.setCalm("calm.sound", on: true, port: shell.port)
        #expect(sink.isEnabled)
        shell.presenter.setCalm("calm.sound", on: false, port: shell.port)
        #expect(!sink.isEnabled)
        // A direct action through the shell is followed too.
        GardenTest.accept(shell, "calm.sound", [1])
        _ = shell.accessibilitySummary
        #expect(sink.isEnabled)
        GardenTest.accept(shell, "calm.sound", [0])
        _ = shell.accessibilitySummary
        #expect(!sink.isEnabled)
    }

    @Test func everyToneStopsWhenTheExperienceSuspends() async throws {
        let sink = RecordingGardenSoundSink()
        let shell = try await CalmTest.shell(sink: sink)
        shell.presenter.setCalm("calm.sound", on: true, port: shell.port)
        shell.presenter.rakePattern(1, port: shell.port)
        let stops = sink.stops
        try shell.suspend()
        #expect(sink.stops == stops + 1, "suspending stops every tone")
        try shell.resume()
        #expect(try GardenTest.core(shell).calm.sound, "the switch stays on")
    }

    @Test func theTonesAreQuietLowAndShort() {
        for sound in GardenSound.allCases {
            let effect = sound.effect
            #expect(effect.isValid, "\(sound)")
            #expect((GardenSound.shortest...GardenSound.longest).contains(effect.duration), "\(sound)")
            #expect(GardenSound.frequencies.contains(effect.startFrequency), "\(sound)")
            #expect(GardenSound.frequencies.contains(effect.endFrequency), "\(sound)")
            #expect(effect.gain <= GardenSound.maxGain, "\(sound)")
            let samples = SoundEffectSynth.render(effect)
            #expect(!samples.isEmpty && samples.allSatisfy { abs($0) <= Float(effect.gain) + 1e-6 }, "\(sound)")
        }
        #expect(GardenSound.shortest == 0.12 && GardenSound.longest == 0.25 && GardenSound.maxGain == 0.2)
        #expect(Set(GardenSound.allCases.map(\.id)) == ["a20.stroke", "a20.place", "a20.remove"])
    }
}
