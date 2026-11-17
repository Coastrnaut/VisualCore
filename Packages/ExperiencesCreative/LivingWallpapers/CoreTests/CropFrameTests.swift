// CropFrameTests — feature 139 (A19-P02) T-A19-206 (FR-A19-204; clarification Q4). The crop frame of every template
// in both orientations over three preview canvases: inside the canvas, the margin held, centred, the template's
// aspect within one point, the safe-area bands inside the frame at the documented fractions, and no frame for a
// canvas that is not positive and finite.
import Foundation
import Testing
@testable import LivingWallpapersCore

@Suite struct CropFrameTests {
    /// The three preview canvases: a portrait phone, a landscape phone and a portrait tablet, in points.
    private static let canvases: [(width: Double, height: Double)] = [(390, 844), (844, 390), (1024, 1366)]
    /// The tolerance for floating-point comparisons of edges.
    private static let epsilon = 1e-9

    /// Whether `inner` lies inside `outer` (within ``epsilon``).
    private static func contains(_ outer: CropRect, _ inner: CropRect) -> Bool {
        inner.x >= outer.x - epsilon && inner.y >= outer.y - epsilon
            && inner.maxX <= outer.maxX + epsilon && inner.maxY <= outer.maxY + epsilon
    }

    @Test func theFrameFitsEveryTemplateAndCanvas() throws {
        var checked = 0
        for template in CanvasTemplates.all {
            for orientation in Orientation.allCases {
                for canvas in Self.canvases {
                    let crop = try #require(CropFrame.fit(template: template, orientation: orientation,
                                                          canvasWidth: canvas.width, canvasHeight: canvas.height))
                    let frame = crop.frame
                    let inset = 0.06 * min(canvas.width, canvas.height)
                    let whole = CropRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
                    #expect(Self.contains(whole, frame))
                    #expect(frame.x >= inset - Self.epsilon && frame.y >= inset - Self.epsilon)
                    #expect(frame.maxX <= canvas.width - inset + Self.epsilon)
                    #expect(frame.maxY <= canvas.height - inset + Self.epsilon)
                    #expect(abs((frame.x + frame.maxX) / 2 - canvas.width / 2) <= Self.epsilon)
                    #expect(abs((frame.y + frame.maxY) / 2 - canvas.height / 2) <= Self.epsilon)
                    let size = template.size(for: orientation)
                    let aspect = Double(size.width) / Double(size.height)
                    #expect(abs(frame.width - frame.height * aspect) <= 1)
                    let touchesWidth = abs(frame.width - (canvas.width - 2 * inset)) <= Self.epsilon
                    let touchesHeight = abs(frame.height - (canvas.height - 2 * inset)) <= Self.epsilon
                    #expect(touchesWidth || touchesHeight)
                    checked += 1
                }
            }
        }
        #expect(checked == 54)
    }

    @Test func theBandsSitInsideTheFrameAtTheGuideFractions() throws {
        for template in CanvasTemplates.all {
            for orientation in Orientation.allCases {
                for canvas in Self.canvases {
                    let crop = try #require(CropFrame.fit(template: template, orientation: orientation,
                                                          canvasWidth: canvas.width, canvasHeight: canvas.height))
                    let frame = crop.frame
                    let guide = template.safeArea
                    for band in [crop.top, crop.bottom, crop.leading, crop.trailing] {
                        #expect(Self.contains(frame, band))
                    }
                    #expect(crop.top == CropRect(x: frame.x, y: frame.y, width: frame.width,
                                                 height: frame.height * guide.top))
                    #expect(abs(crop.bottom.height - frame.height * guide.bottom) <= Self.epsilon)
                    #expect(abs(crop.bottom.maxY - frame.maxY) <= Self.epsilon)
                    #expect(crop.bottom.width == frame.width)
                    #expect(abs(crop.leading.width - frame.width * guide.side) <= Self.epsilon)
                    #expect(crop.leading.x == frame.x && crop.leading.height == frame.height)
                    #expect(abs(crop.trailing.width - frame.width * guide.side) <= Self.epsilon)
                    #expect(abs(crop.trailing.maxX - frame.maxX) <= Self.epsilon)
                    #expect(crop.trailing.y == frame.y && crop.trailing.height == frame.height)
                }
            }
        }
    }

    @Test func aCanvasThatIsNotPositiveAndFiniteHasNoFrame() throws {
        let template = try #require(CanvasTemplates.template(id: "iphone-16-pro"))
        let bad: [(Double, Double)] = [(0, 844), (390, 0), (-390, 844), (390, -1), (.infinity, 844),
                                       (390, .infinity), (.nan, 844), (390, .nan)]
        for (width, height) in bad {
            #expect(CropFrame.fit(template: template, orientation: .portrait,
                                  canvasWidth: width, canvasHeight: height) == nil)
        }
        #expect(CropFrame.fit(template: template, orientation: .portrait, canvasWidth: 390, canvasHeight: 844) != nil)
    }

    @Test func theNewExportFormatsHaveTheirRawValues() {
        #expect(ExportFormat.jpeg.rawValue == "jpeg")
        #expect(ExportFormat.heic.rawValue == "heic")
        #expect(ExportFormat.allCases == [.png, .jpeg, .heic])
    }
}
