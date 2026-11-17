// ImageColorPipeline — feature 138 (A19-P01) T-A19-107 (FR-A19-105; clarification Q3). Reads a written image file
// back through ImageIO (pixel width, height, colour space name and byte count) and compares it with its plan. This is
// the regression check that an exported file matches its template. No GPU and no interface code.
import CoreGraphics
import Foundation
import ImageIO

/// The colour profile an export is tagged with.
public enum ColorProfile: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// sRGB.
    case sRGB

    /// The colour space name as ImageIO reads it back: `kCGColorSpaceSRGB` (the value of `CGColorSpace.sRGB`).
    public var name: String {
        switch self {
        case .sRGB: return "kCGColorSpaceSRGB"
        }
    }
}

/// What a written file holds, read back through ImageIO.
public struct ExportResult: Equatable, Hashable, Sendable {
    /// The pixel width.
    public let width: Int
    /// The pixel height.
    public let height: Int
    /// The colour space name, or nil when the image has none with a name.
    public let profileName: String?
    /// The file size in bytes.
    public let bytes: Int

    /// Creates a result.
    public init(width: Int, height: Int, profileName: String?, bytes: Int) {
        self.width = width
        self.height = height
        self.profileName = profileName
        self.bytes = bytes
    }
}

/// One way a written file differs from its plan.
public enum ExportMismatch: Equatable, Hashable, Sendable {
    /// The pixel size differs from the plan.
    case dimensions(expectedWidth: Int, expectedHeight: Int, width: Int, height: Int)
    /// The colour space name differs from the plan's profile.
    case profile(expected: String, found: String?)
    /// The file could not be read as an image.
    case unreadable
}

/// Reads written files back and checks them against their plans.
public enum ImageColorPipeline {
    /// Inspects an image file: nil when ImageIO cannot read an image from it.
    public static func inspect(_ data: Data) -> ExportResult? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let name = image.colorSpace?.name.map { $0 as String }
        return ExportResult(width: image.width, height: image.height, profileName: name, bytes: data.count)
    }

    /// The mismatches between the file and `plan`; an empty array means the file matches.
    public static func verify(_ data: Data, against plan: ExportPlan) -> [ExportMismatch] {
        guard let result = inspect(data) else { return [.unreadable] }
        var mismatches: [ExportMismatch] = []
        if result.width != plan.width || result.height != plan.height {
            mismatches.append(.dimensions(expectedWidth: plan.width, expectedHeight: plan.height,
                                          width: result.width, height: result.height))
        }
        if result.profileName != plan.profile.name {
            mismatches.append(.profile(expected: plan.profile.name, found: result.profileName))
        }
        return mismatches
    }
}
