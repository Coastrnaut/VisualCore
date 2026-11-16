// AnatomyLayerSign — feature 127 (A17-P04) T-A17-403 (FR-A17-402, FR-A17-404; SC-A17-403; clarification Q3;
// data-model "AnatomyLayerSign"; contracts/accessibility-pack.md). Each layer is shown by its material colour together
// with a sign that does not depend on colour: bones "●", cartilage and menisci "◆", ligaments and tendons "▲". The
// signs pass `stateSignProblems` (every sign present, none shared). A list row reads "<sign> <English name>" and is
// spoken "<English name>, <layer words>".
import Foundation
import VisualCoreSimulation

/// The colour-independent sign, spoken words and material colour of one layer.
public struct AnatomyLayerSign: Equatable, Sendable {
    /// The layer.
    public let layer: AnatomyLayer
    /// The glyph shown with the layer's colour.
    public let sign: String
    /// The words the layer is spoken as.
    public let words: String
    /// The material colour as a hex string.
    public let colorHex: String

    /// Creates a layer sign.
    public init(layer: AnatomyLayer, sign: String, words: String, colorHex: String) {
        self.layer = layer
        self.sign = sign
        self.words = words
        self.colorHex = colorHex
    }

    /// The signs of every layer, in `AnatomyLayer.allCases` order.
    public static let all: [AnatomyLayerSign] = [
        AnatomyLayerSign(layer: .bones, sign: "●", words: "bones", colorHex: "#E6DBC2"),
        AnatomyLayerSign(layer: .cartilage, sign: "◆", words: "cartilage and menisci", colorHex: "#8CB3D9"),
        AnatomyLayerSign(layer: .ligaments, sign: "▲", words: "ligaments and tendons", colorHex: "#CC7373"),
    ]

    /// The sign of `layer`.
    public static func of(_ layer: AnatomyLayer) -> AnatomyLayerSign {
        all.first { $0.layer == layer } ?? all[0]
    }

    /// The sign as a VisualCore state sign, identified by the layer's raw value.
    public var stateSign: StateSign {
        StateSign(id: layer.rawValue, colorHex: colorHex, sign: sign)
    }
}
