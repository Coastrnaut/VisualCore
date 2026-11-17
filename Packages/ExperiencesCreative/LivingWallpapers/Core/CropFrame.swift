// CropFrame — feature 139 (A19-P02) T-A19-206 (FR-A19-204; clarification Q4). The crop frame of a canvas template
// drawn over the preview: the template's oriented aspect fitted inside the preview canvas with a margin and centred,
// and the template's approximate safe-area bands placed inside that frame. Pure arithmetic.
import Foundation

/// An axis-aligned rectangle in preview points, origin at the top-leading corner.
public struct CropRect: Equatable, Sendable {
    /// The leading edge.
    public let x: Double
    /// The top edge.
    public let y: Double
    /// The width.
    public let width: Double
    /// The height.
    public let height: Double

    /// Creates a rectangle from its origin and size.
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The trailing edge, `x + width`.
    public var maxX: Double { x + width }
    /// The bottom edge, `y + height`.
    public var maxY: Double { y + height }
}

/// The crop frame of a template over the preview, with its four safe-area bands inside it.
public struct CropFrame: Equatable, Sendable {
    /// The frame: the template's oriented aspect, fitted inside the inset canvas and centred.
    public let frame: CropRect
    /// The top band: the frame's width, the frame's height × the guide's top fraction.
    public let top: CropRect
    /// The bottom band: the frame's width, the frame's height × the guide's bottom fraction.
    public let bottom: CropRect
    /// The leading band: the frame's width × the guide's side fraction, spanning the frame's height.
    public let leading: CropRect
    /// The trailing band: the frame's width × the guide's side fraction, spanning the frame's height.
    public let trailing: CropRect

    /// Creates a crop frame from its rectangles.
    public init(frame: CropRect, top: CropRect, bottom: CropRect, leading: CropRect, trailing: CropRect) {
        self.frame = frame
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
    }

    /// Fits the crop frame of `template` in `orientation` inside a canvas of `canvasWidth` × `canvasHeight` points.
    ///
    /// The canvas is inset by `margin × min(canvasWidth, canvasHeight)` on every side; the frame is the largest
    /// rectangle with the template's oriented pixel aspect inside that inset area, centred in the canvas. The bands
    /// come from the template's ``SafeAreaGuide``. Returns nil when either canvas edge is not positive and finite,
    /// when the margin is negative or not finite, or when the inset leaves no area.
    public static func fit(template: CanvasTemplate, orientation: Orientation, canvasWidth: Double,
                           canvasHeight: Double, margin: Double = 0.06) -> CropFrame? {
        guard canvasWidth.isFinite, canvasHeight.isFinite, canvasWidth > 0, canvasHeight > 0,
              margin.isFinite, margin >= 0 else { return nil }
        let size = template.size(for: orientation)
        guard size.width > 0, size.height > 0 else { return nil }
        let inset = margin * min(canvasWidth, canvasHeight)
        let availableWidth = canvasWidth - 2 * inset
        let availableHeight = canvasHeight - 2 * inset
        guard availableWidth > 0, availableHeight > 0 else { return nil }
        let aspect = Double(size.width) / Double(size.height)
        var width = availableWidth
        var height = width / aspect
        if height > availableHeight {
            height = availableHeight
            width = height * aspect
        }
        let frame = CropRect(x: (canvasWidth - width) / 2, y: (canvasHeight - height) / 2,
                             width: width, height: height)
        let guide = template.safeArea
        let topHeight = height * guide.top
        let bottomHeight = height * guide.bottom
        let sideWidth = width * guide.side
        return CropFrame(
            frame: frame,
            top: CropRect(x: frame.x, y: frame.y, width: width, height: topHeight),
            bottom: CropRect(x: frame.x, y: frame.maxY - bottomHeight, width: width, height: bottomHeight),
            leading: CropRect(x: frame.x, y: frame.y, width: sideWidth, height: height),
            trailing: CropRect(x: frame.maxX - sideWidth, y: frame.y, width: sideWidth, height: height))
    }
}
