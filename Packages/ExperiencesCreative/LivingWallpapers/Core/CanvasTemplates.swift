// CanvasTemplates — feature 138 (A19-P01) T-A19-106 (FR-A19-103; clarification Q3). The nine device canvas
// templates with their portrait pixel sizes from Apple's published specifications, both orientations, and the
// app's approximate safe-area design guides. Pure data.
import Foundation
import VisualCoreScenes

/// The orientation of a canvas.
public enum Orientation: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// Taller than wide: the template's portrait size.
    case portrait
    /// Wider than tall: the portrait size with its edges swapped.
    case landscape
}

/// The device family of a template.
public enum DeviceFamily: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// An iPhone.
    case iPhone
    /// An iPad.
    case iPad
}

/// The app's safe-area design guides, as fractions of the canvas edge they run along.
///
/// These are approximate design guides of this app, not system measurements: a top band where the lock screen time
/// may sit, a bottom band, and side margins. They help the user keep the focus of an image clear; nothing promises
/// what the system will cover.
public struct SafeAreaGuide: Codable, Equatable, Hashable, Sendable {
    /// The top band, as a fraction of the canvas height (approximate).
    public let top: Double
    /// The bottom band, as a fraction of the canvas height (approximate).
    public let bottom: Double
    /// Each side margin, as a fraction of the canvas width (approximate).
    public let side: Double

    /// Creates a guide from fractions of the canvas.
    public init(top: Double, bottom: Double, side: Double) {
        self.top = top
        self.bottom = bottom
        self.side = side
    }

    /// The guide every template uses: top 0.22, bottom 0.10, side 0.04 (approximate).
    public static let approximate = SafeAreaGuide(top: 0.22, bottom: 0.10, side: 0.04)
}

/// A device canvas: its id, device name, family and portrait pixel size, with the provenance of the numbers.
public struct CanvasTemplate: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// The stable kebab-case id (for example `iphone-16-pro`).
    public let id: String
    /// The device name (for example "iPhone 16 Pro").
    public let device: String
    /// The device family.
    public let family: DeviceFamily
    /// The portrait width in pixels.
    public let portraitWidth: Int
    /// The portrait height in pixels.
    public let portraitHeight: Int
    /// Where the pixel size comes from.
    public let provenance: String
    /// The approximate safe-area design guides.
    public let safeArea: SafeAreaGuide

    /// Creates a template; the provenance defaults to ``CanvasTemplates/provenance`` and the guide to
    /// ``SafeAreaGuide/approximate``.
    public init(id: String, device: String, family: DeviceFamily, portraitWidth: Int, portraitHeight: Int,
                provenance: String = CanvasTemplates.provenance, safeArea: SafeAreaGuide = .approximate) {
        self.id = id
        self.device = device
        self.family = family
        self.portraitWidth = portraitWidth
        self.portraitHeight = portraitHeight
        self.provenance = provenance
        self.safeArea = safeArea
    }

    /// The pixel size in `orientation`: the portrait size, or its edges swapped for landscape.
    public func size(for orientation: Orientation) -> ExportSize {
        switch orientation {
        case .portrait: return ExportSize(width: portraitWidth, height: portraitHeight)
        case .landscape: return ExportSize(width: portraitHeight, height: portraitWidth)
        }
    }
}

/// The nine canvas templates of version 0.1.
public enum CanvasTemplates {
    /// The provenance of every template size.
    public static let provenance = "Apple technical specifications, retrieved 2026-11-17"

    /// The nine templates: five iPhones, then four iPads.
    public static let all: [CanvasTemplate] = [
        CanvasTemplate(id: "iphone-16-pro-max", device: "iPhone 16 Pro Max", family: .iPhone,
                       portraitWidth: 1320, portraitHeight: 2868),
        CanvasTemplate(id: "iphone-16-pro", device: "iPhone 16 Pro", family: .iPhone,
                       portraitWidth: 1206, portraitHeight: 2622),
        CanvasTemplate(id: "iphone-16-plus", device: "iPhone 16 Plus", family: .iPhone,
                       portraitWidth: 1290, portraitHeight: 2796),
        CanvasTemplate(id: "iphone-16", device: "iPhone 16", family: .iPhone,
                       portraitWidth: 1179, portraitHeight: 2556),
        CanvasTemplate(id: "iphone-se-3", device: "iPhone SE (3rd generation)", family: .iPhone,
                       portraitWidth: 750, portraitHeight: 1334),
        CanvasTemplate(id: "ipad-pro-13-m4", device: "iPad Pro 13-inch (M4)", family: .iPad,
                       portraitWidth: 2064, portraitHeight: 2752),
        CanvasTemplate(id: "ipad-pro-11-m4", device: "iPad Pro 11-inch (M4)", family: .iPad,
                       portraitWidth: 1668, portraitHeight: 2420),
        CanvasTemplate(id: "ipad-air-11-m2", device: "iPad Air 11-inch (M2)", family: .iPad,
                       portraitWidth: 1640, portraitHeight: 2360),
        CanvasTemplate(id: "ipad-mini-a17-pro", device: "iPad mini (A17 Pro)", family: .iPad,
                       portraitWidth: 1488, portraitHeight: 2266),
    ]

    /// The template with `id`, or nil when there is none.
    public static func template(id: String) -> CanvasTemplate? {
        all.first { $0.id == id }
    }
}
