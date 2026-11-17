// CropOverlayTests — feature 139 (A19-P02) T-A19-208 (FR-A19-204; SC-A19-203; spec User Story 1; contracts/
// experience.md "Crop frame"). The native crop overlay: for every template in both orientations and three canvas
// sizes its layout is `CropFrame.fit` exactly, inside the canvas with the template's aspect within one point; its label
// names the device, the orientation and the oriented pixel size; the canvas label repeats it after a template or
// orientation action; and the drawn overlay dims outside the frame and leaves the frame's centre clear.
import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience

@MainActor
@Suite struct CropOverlayTests {
    /// Three canvases: a phone in portrait, a tablet in landscape and a square.
    static let canvases = [CGSize(width: 390, height: 844), CGSize(width: 1180, height: 820),
                           CGSize(width: 500, height: 500)]

    @Test func theFrameIsCropFrameFitForEveryTemplateAndOrientation() throws {
        for template in CanvasTemplates.all {
            for orientation in Orientation.allCases {
                for canvas in Self.canvases {
                    let name = "\(template.id) \(orientation.rawValue) \(canvas)"
                    let crop = try #require(CropOverlay.layout(template: template, orientation: orientation,
                                                               size: canvas), "\(name)")
                    let fitted = CropFrame.fit(template: template, orientation: orientation,
                                               canvasWidth: Double(canvas.width), canvasHeight: Double(canvas.height))
                    #expect(crop == fitted, "\(name)")
                    let frame = crop.frame
                    #expect(frame.x >= 0 && frame.y >= 0, "\(name)")
                    #expect(frame.maxX <= Double(canvas.width) + 1e-9 && frame.maxY <= Double(canvas.height) + 1e-9)
                    let size = template.size(for: orientation)
                    let expectedHeight = frame.width * Double(size.height) / Double(size.width)
                    #expect(abs(frame.height - expectedHeight) <= 1, "\(name): aspect within one point")
                    for band in [crop.top, crop.bottom, crop.leading, crop.trailing] {
                        #expect(band.x >= frame.x - 1e-9 && band.maxX <= frame.maxX + 1e-9, "\(name)")
                        #expect(band.y >= frame.y - 1e-9 && band.maxY <= frame.maxY + 1e-9, "\(name)")
                    }
                }
            }
        }
    }

    @Test func theLabelNamesTheDeviceTheOrientationAndThePixelSize() throws {
        let pro = try #require(CanvasTemplates.template(id: "iphone-16-pro"))
        #expect(CropOverlay.label(template: pro, orientation: .portrait)
                == "iPhone 16 Pro, portrait, 1206 by 2622 pixels")
        #expect(CropOverlay.label(template: pro, orientation: .landscape)
                == "iPhone 16 Pro, landscape, 2622 by 1206 pixels")
        for template in CanvasTemplates.all {
            let label = CropOverlay.label(template: template, orientation: .landscape)
            #expect(label.hasPrefix(template.device + ", landscape, \(template.portraitHeight) by "))
        }
    }

    @Test func theCanvasLabelFollowsTheTemplateAndOrientation() async throws {
        let shell = try await WallpaperTest.shell()
        #expect(shell.accessibilitySummary.contains("iPhone 16 Pro, portrait, 1206 by 2622 pixels"))
        #expect(shell.handle(control: "canvas.template", values: [5]) == .accepted)
        #expect(shell.handle(control: "canvas.orientation", values: [1]) == .accepted)
        #expect(shell.accessibilitySummary.contains("iPad Pro 13-inch (M4), landscape, 2752 by 2064 pixels"))
        #expect(shell.presenter.mirror.template == 5 && shell.presenter.mirror.orientation == 1)
    }

    @Test func theDrawnOverlayDimsOutsideTheFrameAndLeavesItsCentreClear() throws {
        let canvas = CGSize(width: 200, height: 300)
        let template = try #require(CanvasTemplates.template(id: "ipad-pro-13-m4"))
        let crop = try #require(CropOverlay.layout(template: template, orientation: .landscape, size: canvas))
        let renderer = ImageRenderer(content: CropOverlay.drawing(crop, canvas: canvas))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        #expect(drawn)
        func alpha(x: Double, y: Double) -> UInt8 {
            let column = min(width - 1, max(0, Int(x)))
            let row = min(height - 1, max(0, Int(y)))
            return pixels[(row * width + column) * 4 + 3]
        }
        let frame = crop.frame
        #expect(alpha(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2) == 0, "the centre is clear")
        #expect(alpha(x: 2, y: 2) > 0, "outside the frame is dimmed")
        #expect(alpha(x: frame.x + frame.width / 2, y: frame.y + frame.height * 0.05) > 0, "the top band is tinted")
    }
}
