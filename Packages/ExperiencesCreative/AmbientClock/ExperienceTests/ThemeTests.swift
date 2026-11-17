// ThemeTests — feature 132 (A18-P02) T-A18-204 (FR-A18-204, FR-A18-207, FR-A18-208; SC-A18-203; research D3, D4;
// contracts/experience.md "Theme"). The "Noise gradient" theme without a GPU: white text reaches at least 4.5 : 1
// against every one of the four palette colours (`AccessibleColors.contrastRatio`, the rule of `minimumContrast()`),
// every colour is dark (the probe's class), the linear palette is the decoded one, the uniform time is 0 with motion
// off or Reduce Motion on and the frame time × the speed otherwise, and the tier sets octaves and pixel block.
import Foundation
import Testing
import UIKit
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreUI

@MainActor
@Suite struct ThemeTests {
    @Test func whiteTextReachesTheRequiredContrastAgainstEveryPaletteColour() {
        #expect(NoiseGradientTheme.requiredContrast == 4.5)
        #expect(NoiseGradientTheme.minimumContrast() >= 4.5)
        let colors = NoiseGradientTheme.paletteColors
        #expect(colors.count == 4)
        #expect(NoiseGradientTheme.paletteNames.count == 4)
        for (index, color) in colors.enumerated() {
            let ratio = AccessibleColors.contrastRatio(NoiseGradientTheme.textColor, color)
            #expect(ratio >= 4.5, "\(NoiseGradientTheme.paletteNames[index]): \(ratio)")
            #expect(ratio >= NoiseGradientTheme.minimumContrast() - 1e-12)
        }
    }

    @Test func theTextIsOpaqueWhite() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let read = NoiseGradientTheme.textColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(read)
        #expect(r == 1 && g == 1 && b == 1 && a == 1)
    }

    @Test func everyPaletteColourIsDark() {
        for (index, color) in NoiseGradientTheme.encodedPalette.enumerated() {
            let luma = FrameChecks.luma(r: UInt8((color.x * 255).rounded()), g: UInt8((color.y * 255).rounded()),
                                        b: UInt8((color.z * 255).rounded()))
            #expect(luma < FrameChecks.darkLuma, "\(NoiseGradientTheme.paletteNames[index]): \(luma)")
        }
    }

    @Test func theLinearPaletteIsTheDecodedPalette() {
        let linear = NoiseGradientTheme.palette
        #expect(linear.count == 4)
        for (index, encoded) in NoiseGradientTheme.encodedPalette.enumerated() {
            let channels = [encoded.x, encoded.y, encoded.z]
            let decoded = [linear[index].x, linear[index].y, linear[index].z]
            for channel in 0..<3 {
                let expected = NoiseGradientTheme.srgbDecode(channels[channel])
                #expect(abs(Double(decoded[channel]) - expected) < 1e-6, "colour \(index) channel \(channel)")
                #expect(Double(decoded[channel]) <= channels[channel] + 1e-9)
            }
        }
    }

    @Test func theUniformTimeIsZeroWithMotionOffOrReduceMotion() {
        for frameTime in [0.0, 1, 7, 123.5] {
            for speed in [0.25, 1, 2] {
                let off = NoiseGradientTheme.effectiveTime(frameTime: frameTime, speed: speed, motion: false,
                                                           reduceMotion: false)
                #expect(off == 0, "motion off at \(frameTime) × \(speed)")
                let reduced = NoiseGradientTheme.effectiveTime(frameTime: frameTime, speed: speed, motion: true,
                                                               reduceMotion: true)
                #expect(reduced == 0, "Reduce Motion at \(frameTime) × \(speed)")
                let both = NoiseGradientTheme.effectiveTime(frameTime: frameTime, speed: speed, motion: false,
                                                            reduceMotion: true)
                #expect(both == 0)
            }
        }
    }

    @Test func theUniformTimeIsTheFrameTimeTimesTheSpeedWithMotionOn() {
        for frameTime in [0.0, 1, 7, 123.5] {
            for speed in [0.25, 1, 1.5, 2] {
                let time = NoiseGradientTheme.effectiveTime(frameTime: frameTime, speed: speed, motion: true,
                                                            reduceMotion: false)
                #expect(time == frameTime * speed, "\(frameTime) × \(speed)")
            }
        }
        let infinite = NoiseGradientTheme.effectiveTime(frameTime: .infinity, speed: 1, motion: true,
                                                        reduceMotion: false)
        #expect(infinite == 0)
    }

    @Test func theTierSetsTheOctavesAndThePixelBlock() {
        #expect(NoiseGradientTheme.parameters(tier: 0) == ["octaves": 5, "block": 1])
        #expect(NoiseGradientTheme.parameters(tier: 1) == ["octaves": 3, "block": 2])
        #expect(NoiseGradientTheme.fragment.contains("#include \"vc/noise.glsl\""))
        #expect(NoiseGradientTheme.fragment.contains("#include \"vc/color.glsl\""))
        #expect(NoiseGradientTheme.fragment.contains("vc_fbm(uv, octaves, 2.0, 0.5)"))
    }
}
