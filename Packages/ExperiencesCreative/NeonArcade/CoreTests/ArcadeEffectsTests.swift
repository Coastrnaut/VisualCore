// ArcadeEffectsTests — feature 077 (A10-P03) T-A10-303 (FR-A10-320; clarifications 3 and 4; research D4; SC-A10-301).
// The effect plans and sound shapes, host-free and short: a pickup cue at the orb's last known position (the player's
// centre when it is unknown) and a hit cue at the player's centre, each with its sound and haptic; a wave cue at the
// top centre when the wave increases; an over cue when the run becomes over, after the hit that ended it; cues in event
// order and capped at 3 visual and 2 sound cues (extra ones dropped); new events counted from the event-count
// difference even when the kept window of 256 is full; no cues for an unchanged run, without a previous run or for a
// new run; a real simulated pickup planned at the orb's place; plans are deterministic; the four sound shapes match
// clarification 4, carry the haptic kinds impactLight, impactHeavy, selection and error, and stay inside the
// data-model limits, and an out-of-range sound is reported.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct ArcadeEffectsTests {
    /// A run one step after `run` with `events` recorded (and the objects they name removed).
    private func after(_ run: GameRun, events kinds: [(Int, CollisionEvent.Kind)]) -> GameRun {
        var next = run
        for (objectId, kind) in kinds {
            next.events.append(CollisionEvent(step: run.step, objectId: objectId, kind: kind))
            next.objects.removeAll { $0.id == objectId }
        }
        if next.events.count > GameRun.maxEvents { next.events.removeFirst(next.events.count - GameRun.maxEvents) }
        next.eventCount += kinds.count
        next.step += 1
        return next
    }

    /// A run at step 10 holding an orb (id 3) at (2, 5) and a hazard (id 4) at (6, 3).
    private func base() -> GameRun {
        var run = GameRun.new()
        run.step = 10
        run.objects = [FallingObject(id: 3, contentId: "glow-orb", kind: .orb, position: Vec2(2, 5),
                                     velocity: Vec2(0, -4), radius: 0.25, value: 10),
                       FallingObject(id: 4, contentId: "spike-ball", kind: .hazard, position: Vec2(6, 3),
                                     velocity: Vec2(0, -4), radius: 0.4)]
        run.nextObjectId = 5
        return run
    }

    @Test func aPickupCueAtTheOrbsPlace() {
        let previous = base()
        let cues = ArcadeEffects.plan(previous: previous, current: after(previous, events: [(3, .pickup)]))
        #expect(cues == [EffectCue(kind: .pickup, position: Vec2(2, 5), visual: true, sound: .pickup)])
        #expect(cues.first?.haptic == .impactLight)
    }

    @Test func aPickupOfAnUnknownObjectIsAtThePlayer() {
        let previous = base()
        let cues = ArcadeEffects.plan(previous: previous, current: after(previous, events: [(99, .pickup)]))
        #expect(cues.map(\.position) == [previous.player.center])
    }

    @Test func aHitCueAtThePlayer() {
        let previous = base()
        let current = after(previous, events: [(4, .hit)])
        let cues = ArcadeEffects.plan(previous: previous, current: current)
        #expect(cues == [EffectCue(kind: .hit, position: current.player.center, visual: true, sound: .hit)])
        #expect(cues.first?.haptic == .impactHeavy)
    }

    @Test func aWaveCueWhenTheWaveIncreases() {
        let previous = base()
        var current = after(previous, events: [])
        current.wave = 2
        let cues = ArcadeEffects.plan(previous: previous, current: current)
        #expect(cues == [EffectCue(kind: .wave, position: Vec2(4.5, 16), visual: true, sound: .wave)])
        #expect(cues.first?.haptic == .selection)
    }

    @Test func anOverCueAfterTheLastHit() {
        var previous = base()
        previous.lives = 1
        var current = after(previous, events: [(4, .hit)])
        current.lives = 0
        current.over = true
        let cues = ArcadeEffects.plan(previous: previous, current: current)
        #expect(cues.map(\.kind) == [.hit, .over])
        #expect(cues.map(\.sound) == [.hit, .over])
        #expect(cues.last?.haptic == .error)
        #expect(cues.last?.position == current.player.center)
        #expect(ArcadeEffects.plan(previous: current, current: current).isEmpty)   // Over only once.
    }

    @Test func cuesAreInEventOrderAndCapped() {
        let previous = base()
        var current = after(previous, events: [(3, .pickup), (4, .hit), (7, .pickup), (8, .hit)])
        current.wave = 2
        current.lives = 0
        current.over = true
        let cues = ArcadeEffects.plan(previous: previous, current: current)
        #expect(ArcadeEffects.maxVisualCues == 3 && ArcadeEffects.maxSoundCues == 2)
        #expect(cues.map(\.kind) == [.pickup, .hit, .pickup])
        #expect(cues.map(\.visual) == [true, true, true])
        #expect(cues.map(\.sound) == [.pickup, .hit, nil])
        #expect(cues.map(\.haptic) == [.impactLight, .impactHeavy, nil])
        #expect(cues.filter(\.visual).count <= ArcadeEffects.maxVisualCues)
        #expect(cues.compactMap(\.sound).count <= ArcadeEffects.maxSoundCues)
    }

    @Test func newEventsComeFromTheCountWhenTheWindowIsFull() {
        var previous = base()
        previous.step = 500
        previous.events = (0..<GameRun.maxEvents).map { CollisionEvent(step: $0, objectId: 0, kind: .pickup) }
        previous.eventCount = 400
        let current = after(previous, events: [(4, .hit), (3, .pickup)])
        #expect(current.events.count == GameRun.maxEvents)
        let cues = ArcadeEffects.plan(previous: previous, current: current)
        #expect(cues.map(\.kind) == [.hit, .pickup])
        #expect(cues.last?.position == Vec2(2, 5))
    }

    @Test func noCuesForAnUnchangedRunWithoutAPreviousRunOrForANewRun() {
        let previous = base()
        #expect(ArcadeEffects.plan(previous: previous, current: previous).isEmpty)
        #expect(ArcadeEffects.plan(previous: nil, current: after(previous, events: [(3, .pickup)])).isEmpty)
        let played = after(previous, events: [(3, .pickup), (4, .hit)])
        #expect(ArcadeEffects.plan(previous: played, current: .new()).isEmpty)
        #expect(ArcadeEffects.plan(previous: previous, current: after(previous, events: [])).isEmpty)
    }

    @Test func aSimulatedPickupIsPlannedAtTheOrbsPlace() {
        var run = GameRun.new()
        let orbPosition = Vec2(GameRun.fieldWidth / 2, GameRun.playerY + 0.6)
        run.objects = [FallingObject(id: 0, contentId: "glow-orb", kind: .orb, position: orbPosition,
                                     velocity: Vec2(0, -4), radius: 0.25, value: 10)]
        run.nextObjectId = 1
        let previous = run
        var random = SeededRandom(seed: 3)
        GameSimulation.advance(&run, catalog: .bundled, random: &random)
        #expect(run.eventCount == 1)
        let cues = ArcadeEffects.plan(previous: previous, current: run)
        #expect(cues == [EffectCue(kind: .pickup, position: orbPosition, visual: true, sound: .pickup)])
    }

    @Test func plansAreDeterministic() {
        let previous = base()
        var current = after(previous, events: [(3, .pickup), (4, .hit)])
        current.wave = 3
        #expect(ArcadeEffects.plan(previous: previous, current: current)
                == ArcadeEffects.plan(previous: previous, current: current))
    }

    @Test func theFourSoundShapes() {
        #expect(ArcadeSound.all.map(\.id) == ["pickup", "hit", "wave", "over"])
        #expect(ArcadeSound.all.map(\.waveform) == ["sine", "triangle", "sine", "triangle"])
        #expect(ArcadeSound.all.map(\.startFrequency) == [880, 160, 300, 440])
        #expect(ArcadeSound.all.map(\.endFrequency) == [1_320, 60, 600, 220])
        #expect(ArcadeSound.all.map(\.duration) == [0.12, 0.25, 0.4, 0.5])
        #expect(ArcadeSound.all.map(\.noise) == [0, 0.3, 0, 0])
        #expect(ArcadeSound.all.map(\.gain) == [0.5, 0.7, 0.3, 0.5])
        #expect(ArcadeSound.all.map(\.haptic) == [.impactLight, .impactHeavy, .selection, .error])
        #expect(ArcadeSound.all.map(\.haptic.rawValue) == ["impactLight", "impactHeavy", "selection", "error"])
        #expect(ArcadeSound.all.allSatisfy { $0.attack == 0.005 && $0.release == 0.005 })
        #expect(EffectCue.Kind.allCases.map { EffectCue.sound(for: $0) } == ArcadeSound.all)
    }

    @Test func theSoundShapesStayInsideTheLimits() {
        for sound in ArcadeSound.all {
            #expect(sound.validate().isEmpty, "\(sound.id): \(sound.validate())")
            #expect(ArcadeSound.waveforms.contains(sound.waveform))
            #expect((40...4_000).contains(sound.startFrequency) && (40...4_000).contains(sound.endFrequency))
            #expect((0.02...1).contains(sound.duration))
            #expect(sound.attack >= 0.002 && sound.release >= 0.002)
            #expect((0...1).contains(sound.noise) && (0...0.9).contains(sound.gain))
        }
        var bad = ArcadeSound.hit
        bad.waveform = "saw"
        bad.startFrequency = 20
        bad.duration = 2
        bad.attack = 0.001
        bad.noise = 1.5
        bad.gain = 1
        #expect(bad.validate().count == 6)
    }
}
