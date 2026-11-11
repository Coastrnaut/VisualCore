// SceneGraphTests — feature 006 T-F511 (FR-F506, FR-F512; US3 AC3).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

private func near(_ a: Vec2, _ b: Vec2) -> Bool { abs(a.x - b.x) < 1e-12 && abs(a.y - b.y) < 1e-12 }

@Test func childOfRotatedParent() {
    // AC3: parent rotated 90°, child offset (1, 0) → world (0, 1).
    let parent = SceneNode(id: "p", rotation: .pi / 2)
    let child = SceneNode(id: "c", position: Vec2(1, 0))
    parent.add(child)
    #expect(near(child.worldTransform().apply(.zero), Vec2(0, 1)))
    let grand = SceneNode(position: Vec2(0, 2), scale: Vec2(3, 3))
    child.add(grand)
    #expect(near(grand.worldTransform().apply(Vec2(1, 0)), Vec2(-2, 4)), "rotation, translation and scale compose")
}

@Test func drawOrderUsesZThenInsertionAndSkipsHidden() {
    let root = SceneNode(id: "root")
    let a = SceneNode(id: "a", z: 1), b = SceneNode(id: "b", z: 0), c = SceneNode(id: "c", z: 1), d = SceneNode(id: "d", z: -1)
    [a, b, c, d].forEach(root.add)
    let hidden = SceneNode(id: "hidden"); hidden.isVisible = false
    hidden.add(SceneNode(id: "under-hidden"))
    root.add(hidden)
    a.add(SceneNode(id: "a.child"))
    #expect(root.drawList().map(\.node.id) == ["root", "d", "b", "a", "a.child", "c"])
}

@Test func hitTestFindsTopmostVisibleShape() {
    let root = SceneNode()
    let back = SceneNode(id: "back", primitive: .rect(Vec2(100, 100)))
    let front = SceneNode(id: "front", position: Vec2(20, 0), z: 5, primitive: .circle(10))
    let line = SceneNode(id: "line", position: Vec2(-40, -40), primitive: .line(.zero, Vec2(10, 0), width: 4))
    [back, front, line].forEach(root.add)
    #expect(root.hitTest(Vec2(22, 3))?.id == "front")
    #expect(root.hitTest(Vec2(-20, 0))?.id == "back")
    #expect(root.hitTest(Vec2(-35, -38.5))?.id == "line")
    #expect(root.hitTest(Vec2(500, 0)) == nil)
    front.isVisible = false
    #expect(root.hitTest(Vec2(22, 3))?.id == "back")
}

@Test func hitTestRespectsRotationAndScale() {
    let root = SceneNode()
    let bar = SceneNode(id: "bar", rotation: .pi / 2, scale: Vec2(2, 1), primitive: .rect(Vec2(10, 2)))
    root.add(bar)
    #expect(root.hitTest(Vec2(0, 9))?.id == "bar", "10×2 rect scaled 2× in x then rotated 90° is 2 wide, 20 tall")
    #expect(root.hitTest(Vec2(9, 0)) == nil)
}

@Test func polygonFillAndBounds() {
    let tri = Primitive.polygon([Vec2(0, 0), Vec2(10, 0), Vec2(0, 10)])
    #expect(tri.contains(Vec2(2, 2)))
    #expect(!tri.contains(Vec2(8, 8)))
    let many = (0..<300).map { Vec2(Double($0), 0) }
    let node = SceneNode(primitive: .polygon(many))
    if case .polygon(let p) = node.primitive { #expect(p.count == 256) } else { Issue.record("polygon kept") }
    node.primitive = .circle(-5)
    #expect(node.primitive == .circle(5))
    #expect(Primitive.rect(Vec2(.nan, -3)).bounded == .rect(Vec2(0, 3)))
}

@Test func reparentingMovesNode() {
    let a = SceneNode(id: "a"), b = SceneNode(id: "b"), n = SceneNode(id: "n")
    a.add(n)
    b.add(n)
    #expect(a.children.isEmpty && b.children.count == 1 && n.parent === b)
    n.removeFromParent()
    #expect(b.children.isEmpty && n.parent == nil)
}
