// BlendTests — feature 153 (A21-P02) T-A21-204 (FR-A21-204; clarification Q3; contracts/experience.md "Blend"). The
// change between skies: `SkyBlend` takes 1.5 s of frame time, eased with smoothstep, and a new selection mid-way starts
// from the current blend; the five-stop inputs of a scene draw the same picture as the A21-P01 uniforms; the hue shift
// turns the palette's hue and a shift of 0 changes nothing. Through the session host: a preset change starts at the
// old picture, is half done after 0.75 s of frames and ends at the new preset's picture after 1.5 s; under Reduce Motion
// the change is immediate and the sky still. Short runs only (frames of 1/60 s at 32 × 24 points).
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct BlendTests {
    static let polar = SkyInputs(scene: SkyPresets.polarNight.scene, hue: 0)
    static let violet = SkyInputs(scene: SkyPresets.violetVeil.scene, hue: 0)
    static let dawn = SkyInputs(scene: SkyPresets.dawnHaze.scene, hue: 0)

    @Test func aChangeTakesOneAndAHalfSecondsEased() {
        #expect(SkyBlend.duration == 1.5)
        var blend = SkyBlend(Self.polar)
        #expect(!blend.isBlending && blend.current == Self.polar)
        blend.start(to: Self.violet)
        #expect(blend.isBlending && blend.progress == 0)
        #expect(blend.current.palette == Self.polar.palette, "the start shows the old sky")
        #expect(blend.current.ribbons == 3, "the larger ribbon count while changing")
        blend.advance(by: 0.75)
        #expect(abs(blend.progress - 0.5) < 1e-12 && abs(blend.eased - 0.5) < 1e-12)
        let middle = blend.current
        #expect(abs(middle.turbulence - (Self.polar.turbulence + Self.violet.turbulence) / 2) < 1e-6)
        blend.advance(by: 0.375)
        #expect(abs(blend.eased - 0.84375) < 1e-12, "smoothstep(0.75)")
        blend.advance(by: 0.375)
        #expect(!blend.isBlending && blend.current == Self.violet, "the end is the target")
        blend.advance(by: 5)
        #expect(blend.current == Self.violet)
        var frames = SkyBlend(Self.polar)
        frames.start(to: Self.dawn)
        var count = 0
        while frames.isBlending, count < 1_000 {
            frames.advance(by: 1.0 / 60)
            count += 1
        }
        #expect(count == 90, "1.5 s at 60 frames per second")
        frames.advance(by: -1)
        frames.advance(by: .nan)
        #expect(frames.current == Self.dawn)
    }

    @Test func aNewSelectionMidwayStartsFromTheCurrentBlend() {
        var blend = SkyBlend(Self.polar)
        blend.start(to: Self.violet)
        blend.advance(by: 0.6)
        let shown = blend.current
        blend.start(to: Self.dawn)
        #expect(blend.progress == 0)
        #expect(blend.current.palette == shown.palette, "nothing jumps")
        #expect(blend.current.turbulence == shown.turbulence && blend.current.stars == shown.stars)
        #expect(blend.from == shown)
        blend.advance(by: 1.5)
        #expect(blend.current == Self.dawn)
        var immediate = SkyBlend(Self.polar)
        immediate.start(to: Self.violet)
        immediate.jump(to: Self.dawn)
        #expect(!immediate.isBlending && immediate.current == Self.dawn)
        var retargeted = SkyBlend(Self.polar)
        retargeted.retarget(Self.violet)
        #expect(!retargeted.isBlending && retargeted.current == Self.violet, "without a change, at once")
    }

    @Test func fiveStopInputsDrawTheA21P01Picture() {
        for preset in SkyPresets.all {
            let inputs = SkyInputs(scene: preset.scene, hue: 0)
            #expect(inputs.palette.count == SkyInputs.stopCount)
            let mine = SkyReference.render(inputs.uniforms(phase: 0.37, level: 0, limit: 0.72), width: 32, height: 24)
            let theirs = SkyReference.render(SkyUniforms(scene: preset.scene, phase: 0.37, level: 0), width: 32,
                                             height: 24)
            #expect(AuroraTest.difference(mine, theirs).max == 0, "\(preset.id)")
        }
    }

    @Test func theHueShiftTurnsThePaletteAndZeroChangesNothing() {
        let green = SkyColor(red: 0.2, green: 0.85, blue: 0.45)
        #expect(SkyHue.shifted(green, turns: 0) == green)
        let grey = SkyColor(red: 0.4, green: 0.4, blue: 0.4)
        #expect(SkyHue.shifted(grey, turns: 0.3) == grey)
        let red = SkyColor(red: 1, green: 0, blue: 0)
        let third = SkyHue.shifted(red, turns: 1.0 / 3)
        #expect(abs(third.red) < 1e-9 && abs(third.green - 1) < 1e-9 && abs(third.blue) < 1e-9, "red → green")
        let back = SkyHue.shifted(SkyHue.shifted(green, turns: 0.2), turns: -0.2)
        #expect(abs(back.red - green.red) < 1e-9 && abs(back.green - green.green) < 1e-9
                && abs(back.blue - green.blue) < 1e-9)
        let half = SkyHue.shifted(green, turns: 0.5)
        #expect(abs(max(half.red, half.green, half.blue) - max(green.red, green.green, green.blue)) < 1e-12,
                "value kept")
        #expect(SkyInputs(scene: SkyPresets.polarNight.scene, hue: 0.25) != Self.polar)
    }

    @Test func aPresetChangeBlendsInTheSession() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        let before = try AuroraTest.still(session)
        AuroraTest.accept(shell, "preset.select", [1])
        #expect(presenter.blend.isBlending && presenter.blend.progress == 0)
        let start = try AuroraTest.still(session)
        #expect(AuroraTest.difference(start, before).max == 0, "the change starts at the old sky")
        try AuroraTest.draw(session, frames: 45)
        #expect(abs(presenter.blend.progress - 0.5) < 1e-9)
        try AuroraTest.draw(session, frames: 44)
        #expect(presenter.blend.isBlending)
        try AuroraTest.draw(session, frames: 1)
        #expect(!presenter.blend.isBlending, "done after 1.5 s of frames")
        let end = try AuroraTest.still(session)
        let uniforms = try #require(presenter.lastUniforms)
        let target = SkyInputs(scene: SkyPresets.violetVeil.scene, hue: 0)
        #expect(uniforms.palette == target.palette && uniforms.ribbons == 2)
        let reference = try AuroraTest.reference(shell)
        let diff = AuroraTest.difference(end, reference)
        #expect(diff.mean <= 2 && diff.max <= 8, "\(diff)")
        // A control moved during a change follows the target without restarting it.
        AuroraTest.accept(shell, "preset.select", [2])
        try AuroraTest.draw(session, frames: 30)
        AuroraTest.accept(shell, "sky.stars", [100])
        #expect(presenter.blend.isBlending && abs(presenter.blend.progress - 1.0 / 3) < 1e-9)
        try AuroraTest.draw(session, frames: 60)
        #expect(!presenter.blend.isBlending && presenter.lastUniforms?.stars == 100)
    }

    @Test func underReduceMotionAChangeIsImmediateAndTheSkyStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, reduceMotion: true)
        let presenter = shell.presenter
        AuroraTest.accept(shell, "preset.select", [2])
        #expect(!presenter.blend.isBlending)
        try AuroraTest.draw(session)
        let first = try AuroraTest.still(session)
        let uniforms = try #require(presenter.lastUniforms)
        #expect(uniforms.palette == Self.dawn.palette && uniforms.ribbons == Self.dawn.ribbons)
        #expect(presenter.clock.time == 0, "the clock holds")
        try AuroraTest.draw(session, frames: 10)
        let second = try AuroraTest.still(session)
        #expect(AuroraTest.difference(first, second).max == 0, "consecutive frames are identical")
        let reference = try AuroraTest.reference(shell)
        let diff = AuroraTest.difference(second, reference)
        #expect(diff.mean <= 2 && diff.max <= 8, "\(diff)")
    }
}
