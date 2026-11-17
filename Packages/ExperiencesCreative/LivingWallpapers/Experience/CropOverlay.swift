// CropOverlay — feature 139 (A19-P02) T-A19-207 (FR-A19-204; SC-A19-203; clarification Q4; spec User Story 1). The
// native SwiftUI canvas overlay of Living Wallpapers: the chosen template's frame in its orientation, fitted inside
// the canvas with `CropFrame.fit(template:orientation:canvasWidth:canvasHeight:margin:)` (the canvas size from a
// `GeometryReader`, the default margin 0.06 of the short edge). Outside the frame the canvas is dimmed (black at 45 %
// opacity, an even-odd fill of the canvas and the frame), the frame is stroked in white, and the approximate
// safe-area guides (the top, bottom, leading and trailing bands) are tinted white at 14 % and outlined with a dashed
// line. A template far from the canvas aspect letterboxes inside it; the guides are never cropped.
//
// The host shows the overlay without touches and hides it from assistive technology (the canvas label speaks the
// state, `WallpaperPresenter.describe`); the overlay still carries its own label, "iPhone 16 Pro, portrait, 1206 by
// 2622 pixels" (`label(template:orientation:)`), which the canvas label repeats.
import LivingWallpapersCore
import SwiftUI

/// The crop frame and guides over the canvas (see the file header).
struct CropOverlay: View {
    /// What the overlay shows.
    let mirror: WallpaperMirror

    /// The dimming of the canvas outside the frame (black opacity).
    static let dimOpacity = 0.45
    /// The tint of the guide bands (white opacity).
    static let bandOpacity = 0.14
    /// The width of the frame's stroke, points.
    static let frameLineWidth = 2.0

    /// The words of a template in an orientation: "<device>, <portrait|landscape>, <width> by <height> pixels" with
    /// the oriented pixel size.
    static func label(template: CanvasTemplate, orientation: Orientation) -> String {
        let size = template.size(for: orientation)
        return template.device + ", " + orientation.rawValue + ", \(size.width) by \(size.height) pixels"
    }

    /// The crop frame of `template` in `orientation` over a canvas of `size` points (`CropFrame.fit` with the default
    /// margin); nil for an empty canvas.
    static func layout(template: CanvasTemplate, orientation: Orientation, size: CGSize) -> CropFrame? {
        CropFrame.fit(template: template, orientation: orientation, canvasWidth: Double(size.width),
                      canvasHeight: Double(size.height))
    }

    /// `rect` as a CoreGraphics rectangle.
    static func cgRect(_ rect: CropRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    /// The overlay.
    var body: some View {
        let template = mirror.templateDefinition
        let orientation = mirror.orientationValue
        return GeometryReader { geometry in
            if let crop = Self.layout(template: template, orientation: orientation, size: geometry.size) {
                Self.drawing(crop, canvas: geometry.size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.label(template: template, orientation: orientation)))
    }

    /// The dimming, the guide bands and the frame of `crop` over a canvas of `canvas` points.
    @ViewBuilder
    static func drawing(_ crop: CropFrame, canvas: CGSize) -> some View {
        let frame = cgRect(crop.frame)
        let bands = [crop.top, crop.bottom, crop.leading, crop.trailing].map(cgRect)
        ZStack {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: canvas))
                path.addRect(frame)
            }
            .fill(Color.black.opacity(dimOpacity), style: FillStyle(eoFill: true))
            Path { path in
                for band in bands { path.addRect(band) }
            }
            .fill(Color.white.opacity(bandOpacity))
            Path { path in
                for band in bands { path.addRect(band) }
            }
            .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            Path { path in path.addRect(frame) }
                .stroke(Color.white, lineWidth: frameLineWidth)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
    }
}
