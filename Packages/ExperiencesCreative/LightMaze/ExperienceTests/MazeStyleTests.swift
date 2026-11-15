// MazeStyleTests — feature 099 (A13-P04) T-A13-405 (FR-A13-430, FR-A13-431; clarification Q4; research D6). The state
// style of Light Maze, pure checks only (no frame drawn): the nine states pass the shared state-sign check with nine
// distinct ids; every state colour, composited over the board when translucent, keeps at least 3:1 contrast against
// the board; the glow stays within its reach limit; and the hex form of a colour.
import Foundation
import UIKit
import XCTest
@testable import LightMazeExperience
import VisualCoreMath
import VisualCoreSimulation
import VisualCoreUI

@MainActor
final class MazeStyleTests: XCTestCase {
    private func uiColor(_ color: Vec4) -> UIColor {
        UIColor(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: 1)
    }

    func testTheNineStatesHaveDistinctSigns() {
        let signs = MazeStyle.signs
        XCTAssertEqual(stateSignProblems(signs), [])
        XCTAssertEqual(signs.count, 9)
        var ids = Set<String>()
        for sign in signs {
            ids.insert(sign.id)
        }
        XCTAssertEqual(ids.count, 9)
    }

    func testEveryStateColourHasThreeToOneContrastAgainstTheBoard() {
        let board = MazePresenter.boardColor
        for state in MazeStyle.stateColors {
            var color = state.color
            if color.w < 1 {
                let a: Double = color.w
                let b: Double = 1 - a
                let red: Double = color.x * a + board.x * b
                let green: Double = color.y * a + board.y * b
                let blue: Double = color.z * a + board.z * b
                color = Vec4(red, green, blue, 1)
            }
            let ratio = AccessibleColors.contrastRatio(uiColor(color), uiColor(board))
            XCTAssertGreaterThanOrEqual(ratio, 3.0, "\(state.id) contrast \(ratio)")
        }
    }

    func testTheGlowStaysWithinItsReach() {
        XCTAssertLessThanOrEqual(MazePresenter.glowReach, 0.15)
    }

    func testHexOfPureRed() {
        XCTAssertEqual(MazeStyle.hex(Vec4(1, 0, 0, 1)), "#FF0000")
        XCTAssertEqual(MazeStyle.hex(Vec4(2, -1, 0, 1)), "#FF0000")
    }
}
