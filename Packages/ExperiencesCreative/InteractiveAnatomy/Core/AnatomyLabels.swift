// AnatomyLabels — feature 127 (A17-P04) T-A17-403 (FR-A17-402; SC-A17-403; clarification Q2; data-model
// "AnchoredLabelLayout.Candidate"; contracts/accessibility-pack.md). The label candidates of Interactive Anatomy for
// VisualCore's `AnchoredLabelLayout`: one per solid part, anchored at the part's sphere centre, with a box of 7 points
// per character plus 8, by 18, priority 0 for the selection and 1 + the inventory index for the others, and the part
// index as id. Ghosted and hidden parts get no label.
import Foundation
import VisualCoreMath

/// The label candidates of the anatomy scene (see the file header).
public enum AnatomyLabels {
    /// The box size of a label with `text`, in points: 7 per character plus 8 wide, 18 high.
    public static func boxSize(_ text: String) -> Vec2 {
        Vec2(7 * Double(text.count) + 8, 18)
    }

    /// One candidate per part index in `solid` that exists in `scene`, sorted by index; `selected` gets priority 0
    /// when it is solid, every other part 1 + its index.
    public static func candidates(scene: AnatomyScene, solid: Set<Int>, selected: Int?) -> [AnchoredLabelLayout.Candidate] {
        solid.filter { scene.parts.indices.contains($0) }.sorted().map { index in
            AnchoredLabelLayout.Candidate(id: index, anchor: scene.structureSphere(index).center,
                                          size: boxSize(scene.parts[index].englishName),
                                          priority: index == selected ? 0 : 1 + index)
        }
    }
}
