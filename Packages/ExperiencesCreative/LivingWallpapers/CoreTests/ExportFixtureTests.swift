// ExportFixtureTests — feature 138 (A19-P01) T-A19-108 (FR-A19-105; SC-A19-102; clarification Q3). The regression
// fixture: for every template and orientation that fits 4096, a solid image of the planned size is encoded through
// the real still encoder, read back through ImageIO and matches the plan (dimensions and kCGColorSpaceSRGB) with 0
// mismatches; a damaged file is unreadable; a wrong plan is reported.
import Foundation
import Testing
import VisualCoreRendering
@testable import LivingWallpapersCore

@Suite struct ExportFixtureTests {
    /// The PNG of a solid grey image of `plan`'s size (alpha is made opaque by the encoder).
    private static func png(for plan: ExportPlan) throws -> Data {
        let bytes = [UInt8](repeating: 0x80, count: plan.width * plan.height * 4)
        let image = try #require(StillImage(width: plan.width, height: plan.height, topDownRGBA: bytes))
        return try StillImageEncoder.pngData(image)
    }

    @Test func everyFittingTemplateReadsBackAsPlanned() throws {
        var checked = 0
        for template in CanvasTemplates.all {
            for orientation in Orientation.allCases {
                var project = WallpaperProject.default
                project.template = template.id
                project.orientation = orientation
                guard case let .success(plan) = ExportPlanner.plan(project: project, maxEdge: 4096) else {
                    Issue.record("\(template.id) \(orientation) does not fit 4096")
                    continue
                }
                let data = try Self.png(for: plan)
                #expect(ImageColorPipeline.verify(data, against: plan).isEmpty, "\(template.id) \(orientation)")
                let result = try #require(ImageColorPipeline.inspect(data))
                #expect(result.width == plan.width && result.height == plan.height, "\(template.id) \(orientation)")
                #expect(result.profileName == "kCGColorSpaceSRGB")
                #expect(result.bytes == data.count)
                checked += 1
            }
        }
        #expect(checked == 18)
    }

    @Test func aDamagedFileIsUnreadable() {
        let plan = ExportPlan(format: .png, width: 750, height: 1334, fallback: false)
        #expect(ImageColorPipeline.verify(Data("not an image".utf8), against: plan) == [.unreadable])
        #expect(ImageColorPipeline.inspect(Data()) == nil)
    }

    @Test func aWrongSizeIsReported() throws {
        let written = ExportPlan(format: .png, width: 8, height: 6, fallback: false)
        let data = try Self.png(for: written)
        let expected = ExportPlan(format: .png, width: 6, height: 8, fallback: false)
        let mismatches = ImageColorPipeline.verify(data, against: expected)
        #expect(mismatches == [.dimensions(expectedWidth: 6, expectedHeight: 8, width: 8, height: 6)])
    }

    @Test func theProfileNameIsTheSystemSRGBName() {
        #expect(ColorProfile.sRGB.name == "kCGColorSpaceSRGB")
    }
}
