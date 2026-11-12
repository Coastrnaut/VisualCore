// TileView — feature 190 T-U04-011 (FR-U04-021). One tile of the launcher: a native button with the identifier
// `vc.tile.<id>`, the label "<title>, <tier>", the tier as visible text and a picture drawn with SwiftUI shapes
// from the tile's two colours and its seed. The picture uses no image and no rendering context.
import SwiftUI
import VisualCoreExperience

/// The picture of a tile: a gradient of the two colours and three discs placed by the seed. Decorative.
struct TilePicture: View {
    let colors: [String]
    let seed: UInt32

    /// A colour written `#RRGGBB`; gray for any other text.
    static func color(_ text: String) -> Color {
        let digits = text.hasPrefix("#") ? String(text.dropFirst()) : ""
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return Color.gray }
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }

    /// The byte `index` (0 to 3) of the seed as a fraction 0…1.
    private func fraction(_ index: Int) -> CGFloat {
        CGFloat((seed >> (UInt32(index) * 8)) & 0xFF) / 255
    }

    var body: some View {
        let first = Self.color(colors.first ?? "")
        let second = Self.color(colors.count > 1 ? colors[1] : colors.first ?? "")
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [first, second], startPoint: UnitPoint(x: fraction(0), y: 0),
                               endPoint: UnitPoint(x: 1 - fraction(0), y: 1))
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.18 + 0.1 * Double(index)))
                        .frame(width: side * (0.25 + 0.35 * fraction(index + 1)))
                        .position(x: proxy.size.width * fraction((index + 2) % 4),
                                  y: proxy.size.height * fraction((index + 3) % 4))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// One launcher tile as a button.
struct TileView: View {
    let tile: LauncherTile
    let action: @MainActor () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    TilePicture(colors: tile.colors, seed: tile.seed)
                        .frame(height: 72)
                    texts
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    TilePicture(colors: tile.colors, seed: tile.seed)
                        .frame(width: 64, height: 64)
                    texts
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(AppStrings.text(.tileLabel, tile.title, tile.tierText))
        .accessibilityHint(tile.summary)
        .accessibilityIdentifier(tile.accessibilityIdentifier)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tile.title)
                .font(.headline)
            Text(tile.summary)
                .font(.subheadline)
            Label(tile.tierText, systemImage: tile.isPremium ? "lock.fill" : "checkmark.circle")
                .font(.footnote.weight(.semibold))
        }
        .multilineTextAlignment(.leading)
        .foregroundStyle(.primary)
    }
}
